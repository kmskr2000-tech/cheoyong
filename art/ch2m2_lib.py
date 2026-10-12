"""2장 M2 지형 공용 도구: 이미지 퀼팅(Efros-Freeman 최소오차 경계)·스탬프·페더·장식 스프라이트.
M1(art/ch2_terrain.py)은 일러스트를 '그대로 잘라 붙인' 재가공이라 개성이 약했다. 이번엔
 (1) 소스에서 '빈 바닥'만 뽑아 퀼팅으로 원하는 크기의 바닥을 새로 만들고,
 (2) 구조물(초가·담·횃불·제단)은 vox 렌더러 소품으로 얹고,
 (3) 바닥 위 장식(그을음·깨진 기와·짚·이끼·귀화)은 코드로 직접 찍는다.
"""
import sys, pathlib
import numpy as np
from PIL import Image
from scipy import ndimage as ndi

ROOT = pathlib.Path(__file__).parent
sys.path.insert(0, str(ROOT))
import terrain_import as ti

SRC = ti.SRC


def load(name):
    return np.asarray(Image.open(SRC / f'{name}.png').convert('RGB'), np.float32)


def lum(a):
    return a @ np.array([.3, .59, .11], np.float32)


def soft_mask(h, w, kind='ellipse', feather=0.25):
    """0..1 마스크. ellipse: 중심 1 → 가장자리 0 / rect: 가장자리만 페더"""
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
    if kind == 'ellipse':
        d = np.sqrt(((xx - (w - 1) / 2) / (w / 2)) ** 2 + ((yy - (h - 1) / 2) / (h / 2)) ** 2)
        return np.clip((1 - d) / feather, 0, 1)
    fx, fy = max(1, feather * w), max(1, feather * h)
    return np.clip(np.minimum.reduce([xx / fx, (w - 1 - xx) / fx, yy / fy, (h - 1 - yy) / fy]), 0, 1)


def paste(cv, patch, x, y, mask=None):
    ph, pw = patch.shape[:2]
    x0, y0 = max(0, x), max(0, y)
    x1, y1 = min(cv.shape[1], x + pw), min(cv.shape[0], y + ph)
    if x1 <= x0 or y1 <= y0:
        return
    p = patch[y0 - y:y1 - y, x0 - x:x1 - x]
    m = np.ones(p.shape[:2], np.float32) if mask is None else mask[y0 - y:y1 - y, x0 - x:x1 - x]
    cv[y0:y1, x0:x1] = cv[y0:y1, x0:x1] * (1 - m[..., None]) + p * m[..., None]


def stamp(cv, src, box, at, kind='ellipse', feather=0.25, flip=False, tone=None):
    """src[box]를 at(왼쪽위)에 얹는다."""
    x0, y0, x1, y1 = box
    p = src[y0:y1, x0:x1].copy()
    if flip:
        p = p[:, ::-1]
    if tone is not None:
        p = np.clip(p * np.array(tone, np.float32), 0, 255)
    paste(cv, p, at[0], at[1], soft_mask(p.shape[0], p.shape[1], kind, feather))


def quilt(pool, out_hw, block=120, overlap=36, seed=1, tries=300):
    """Efros-Freeman 이미지 퀼팅. pool: HxWx3 float 소스(빈 바닥), out_hw=(H,W)."""
    rng = np.random.default_rng(seed)
    H, W = out_hw
    ph, pw = pool.shape[:2]
    step = block - overlap
    ny, nx = -(-(H - overlap) // step), -(-(W - overlap) // step)
    out = np.zeros((ny * step + overlap, nx * step + overlap, 3), np.float32)
    for j in range(ny):
        for i in range(nx):
            y, x = j * step, i * step
            best, bd = None, 1e30
            for _ in range(tries):
                sy, sx = rng.integers(0, ph - block), rng.integers(0, pw - block)
                c = pool[sy:sy + block, sx:sx + block]
                d = 0.0
                if i > 0:
                    d += ((c[:, :overlap] - out[y:y + block, x:x + overlap]) ** 2).sum()
                if j > 0:
                    d += ((c[:overlap] - out[y:y + overlap, x:x + block]) ** 2).sum()
                if d < bd:
                    bd, best = d, c
            c = best.copy()
            if i == 0 and j == 0:
                out[y:y + block, x:x + block] = c
                continue
            m = np.ones((block, block), np.float32)    # 1 = 새 패치 사용
            if i > 0:
                e = ((c[:, :overlap] - out[y:y + block, x:x + overlap]) ** 2).sum(2)
                m[:, :overlap] = np.minimum(m[:, :overlap], _cut_v(e))
            if j > 0:
                e = ((c[:overlap] - out[y:y + overlap, x:x + block]) ** 2).sum(2)
                m[:overlap] = np.minimum(m[:overlap], _cut_v(e.T).T)
            m = ndi.gaussian_filter(m, 0.8)
            out[y:y + block, x:x + block] = out[y:y + block, x:x + block] * (1 - m[..., None]) + c * m[..., None]
    return out[:H, :W]


def _cut_v(e):
    """세로 경계(오차 e: rows x ov)의 최소 비용 경로. 반환: 경로 오른쪽=1(새 패치), 왼쪽=0"""
    r, c = e.shape
    cost = e.copy()
    for y in range(1, r):
        l = np.concatenate([[1e30], cost[y - 1, :-1]]); m = cost[y - 1]; rr = np.concatenate([cost[y - 1, 1:], [1e30]])
        cost[y] += np.minimum(np.minimum(l, m), rr)
    x = int(np.argmin(cost[-1])); path = [x]
    for y in range(r - 2, -1, -1):
        cand = [(cost[y, xx], xx) for xx in (x - 1, x, x + 1) if 0 <= xx < c]
        x = min(cand)[1]; path.append(x)
    path = path[::-1]
    msk = np.zeros((r, c), np.float32)
    for y, x in enumerate(path):
        msk[y, x:] = 1
    return msk


def noise(h, w, scale, seed=0):
    rng = np.random.default_rng(seed)
    n = ndi.zoom(rng.random((h // scale + 3, w // scale + 3)).astype(np.float32), scale, order=3)[:h, :w]
    return (n - n.min()) / (n.max() - n.min() + 1e-6)


def blob(cv, cx, cy, rx, ry, col, alpha=0.6, seed=0, rough=0.35):
    """불규칙한 얼룩(그을음·이끼·핏자국 등)"""
    h, w = cv.shape[:2]
    x0, x1, y0, y1 = max(0, int(cx - rx * 1.3)), min(w, int(cx + rx * 1.3)), max(0, int(cy - ry * 1.3)), min(h, int(cy + ry * 1.3))
    if x1 <= x0 or y1 <= y0:
        return
    yy, xx = np.mgrid[y0:y1, x0:x1].astype(np.float32)
    n = noise(y1 - y0, x1 - x0, 6, seed) - 0.5
    d = np.sqrt(((xx - cx) / rx) ** 2 + ((yy - cy) / ry) ** 2) + n * rough * 2
    m = np.clip((1 - d) / 0.35, 0, 1) * alpha
    cv[y0:y1, x0:x1] = cv[y0:y1, x0:x1] * (1 - m[..., None]) + np.array(col, np.float32) * m[..., None]


def dots(cv, pts, cols, size=(2, 2)):
    """작은 파편(깨진 기와·짚·돌)을 소스 해상도로 찍는다."""
    for (x, y), c in zip(pts, cols):
        cv[int(y):int(y) + size[1], int(x):int(x) + size[0]] = c
