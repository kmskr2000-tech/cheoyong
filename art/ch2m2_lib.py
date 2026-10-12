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


# ---------------------------------------------------------------- 코드로 그리는 판석 바닥 (최종 해상도, 도트 단위)
SLAB = [(40, 50, 54), (50, 62, 66), (60, 74, 80), (72, 88, 96), (86, 102, 108)]   # dungeon 일러스트 판석에서 뽑은 램프
GROUT = (13, 18, 24)
MOSS = [(40, 56, 40), (62, 82, 46), (92, 112, 60)]


def _speckle(tile, rng, base):
    h, w = tile.shape[:2]
    for _ in range(max(1, h * w // 70)):
        x, y = int(rng.integers(0, w)), int(rng.integers(0, h))
        d = int(rng.choice([-14, -10, 8, 12]))
        tile[y, x] = np.clip(np.array(base) + d, 0, 255)
        if rng.random() < 0.4 and x + 1 < w:
            tile[y, x + 1] = tile[y, x]


def flagstones(w, h, seed=1, row_h=(24, 34), slab_w=(26, 50), pal=None, moss=0.55, cracks=0.45, hole=0.0):
    """달리기 쌓기 판석 바닥. 판석마다: 위·왼쪽 하이라이트, 아래·오른쪽 그림자, 얼룩 톤, 모서리 깨짐, 잔금, 이끼 덩이, 파편.
    줄눈 굵기·위치에 ±1px 흔들림. 반투명 없음."""
    rng = np.random.default_rng(seed)
    pal = pal or SLAB
    img = np.zeros((h, w, 3), np.uint8)
    img[:] = GROUT
    y = -int(rng.integers(0, row_h[0]))
    while y < h:
        rh = int(rng.integers(row_h[0], row_h[1] + 1))
        x = -int(rng.integers(0, slab_w[0]))
        while x < w:
            sw = int(rng.integers(slab_w[0], slab_w[1] + 1))
            jx0, jy0 = int(rng.integers(0, 2)), int(rng.integers(0, 2))
            jx1, jy1 = int(rng.integers(0, 2)), int(rng.integers(0, 2))
            x0, x1, y0, y1 = max(x + 1 + jx0, 0), min(x + sw - jx1, w), max(y + 1 + jy0, 0), min(y + rh - jy1, h)
            if x1 > x0 + 3 and y1 > y0 + 3 and rng.random() < hole:
                th, tw = y1 - y0, x1 - x0
                earth = np.tile(np.array((26, 22, 24), np.uint8), (th, tw, 1))
                n = noise(th, tw, 4, int(rng.integers(0, 10 ** 6)))
                earth[n > 0.62] = (40, 34, 34)
                earth[n < 0.28] = (18, 15, 18)
                img[y0:y1, x0:x1] = earth
            elif x1 > x0 + 3 and y1 > y0 + 3:
                t = int(rng.choice([0, 1, 1, 2, 2, 2, 3, 3, 4]))
                base = pal[t]
                th, tw = y1 - y0, x1 - x0
                tile = np.tile(np.array(base, np.float32), (th, tw, 1))
                n = noise(th, tw, 6, int(rng.integers(0, 10 ** 6)))
                tile = np.clip(tile + (np.digitize(n, [0.30, 0.62]) - 1)[..., None] * 8, 0, 255)
                # 윗면 빛: 위에서 아래로 살짝 어두워지는 단계(두 단)
                tile[th * 2 // 3:] = np.clip(tile[th * 2 // 3:] - 6, 0, 255)
                tile[0, :] = np.clip(tile[0, :] + 28, 0, 255)
                tile[1, : tw // 2] = np.clip(tile[1, : tw // 2] + 12, 0, 255)
                tile[:, 0] = np.clip(tile[:, 0] + 14, 0, 255)
                tile[-1, :] = np.clip(tile[-1, :] - 26, 0, 255)
                tile[:, -1] = np.clip(tile[:, -1] - 18, 0, 255)
                tile = tile.astype(np.uint8)
                _speckle(tile, rng, base)
                # 모서리 깨짐(삼각)
                if rng.random() < 0.25:
                    cw = int(min(rng.integers(3, 7), th - 1, tw - 1))
                    corner = int(rng.integers(0, 4))
                    for k in range(cw):
                        if corner == 0: tile[k, : cw - k] = GROUT
                        elif corner == 1: tile[k, tw - (cw - k):] = GROUT
                        elif corner == 2: tile[th - 1 - k, : cw - k] = GROUT
                        else: tile[th - 1 - k, tw - (cw - k):] = GROUT
                # 잔금(꺾이는 선)
                if rng.random() < cracks:
                    cx, cy = int(rng.integers(3, max(4, tw - 3))), int(rng.integers(0, max(1, th // 3)))
                    for _ in range(int(rng.integers(8, th + 6))):
                        if 0 <= cy < th and 0 <= cx < tw:
                            tile[cy, cx] = (28, 36, 42)
                        cy += 1
                        if rng.random() < 0.55: cx += int(rng.integers(-1, 2))
                        if rng.random() < 0.12 and 0 <= cy < th and 0 <= cx + 1 < tw: tile[cy, cx + 1] = (28, 36, 42)
                # 이끼 덩이(모서리·줄눈 쪽)
                if rng.random() < moss:
                    for _ in range(int(rng.integers(1, 4))):
                        mw, mh = int(rng.integers(4, 12)), int(rng.integers(2, 5))
                        mx = int(rng.choice([0, max(0, tw - mw)])); my = int(rng.choice([0, max(0, th - mh)]))
                        for yy in range(mh):
                            for xx in range(mw):
                                if rng.random() < 0.85 - 0.12 * yy and my + yy < th and mx + xx < tw:
                                    tile[my + yy, mx + xx] = MOSS[min(2, int(rng.integers(0, 3)) + (1 if yy == 0 else 0))]
                img[y0:y1, x0:x1] = tile
            x += sw
        y += rh
    return img


def grime(img, seed=2, strength=0.35, scale=34):
    """저주파 얼룩(어둡게)과 밝은 자국을 곱해 판석 바닥이 평평해 보이지 않게. 단계는 양자화(디더 아님)."""
    a = img.astype(np.float32)
    n = noise(img.shape[0], img.shape[1], scale, seed)
    st = (np.digitize(n, [0.30, 0.50, 0.72]) - 1.2)          # -1.2 .. 1.8 의 4단계
    return np.clip(a * (1 + st[..., None] * strength * 0.18), 0, 255)


def rubble(cv, rng, pts, cols=None):
    """작은 돌·기와 조각(외곽선 1px, 위쪽 밝은 면). pts: [(x,y)]  — 최종 해상도 캔버스 cv(float RGB)"""
    cols = cols or [(76, 92, 100), (58, 72, 80), (92, 108, 112)]
    h, w = cv.shape[:2]
    for (x, y) in pts:
        x, y = int(x), int(y)
        rw, rh = int(rng.integers(3, 8)), int(rng.integers(2, 5))
        if x < 1 or y < 1 or x + rw + 1 >= w or y + rh + 1 >= h:
            continue
        cv[y - 1:y + rh + 1, x - 1:x + rw + 1] = (12, 16, 22)
        c = cols[int(rng.integers(0, len(cols)))]
        cv[y:y + rh, x:x + rw] = c
        cv[y, x:x + rw] = np.clip(np.array(c) + 30, 0, 255)
        cv[y + rh - 1, x:x + rw] = np.clip(np.array(c) - 24, 0, 255)


def glow_pools(cv, pts, radii=(26, 52, 84), adds=((16, 8, 30), (14, 7, 26), (12, 6, 22)), sq=0.75):
    """귀화 불빛이 판석에 번진 자국: 반지름이 다른 세 겹의 타원(가로 r, 세로 r*sq)을 단계적으로 더한다(부드러운 그라데이션이 아니라 3단 — 도트 규율)."""
    h, w = cv.shape[:2]
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
    for (cx, cy) in pts:
        for r, a in zip(radii, adds):
            m = ((xx - cx) / r) ** 2 + ((yy - cy) / (r * sq)) ** 2 < 1
            cv[m] = np.clip(cv[m] + np.array(a, np.float32), 0, 255)


def roots(cv, rng, starts, n=40, col=(30, 40, 28), hi=(52, 66, 40), width=2):
    """담 바깥 돌덩이를 파고든 나무뿌리(랜덤 워크). 어둡게 2px + 위쪽 한 줄 하이라이트."""
    h, w = cv.shape[:2]
    for (x, y, ang) in starts:
        cx, cy, a = float(x), float(y), ang
        for i in range(n):
            a += rng.normal(0, 0.35)
            cx += np.cos(a) * 2.2; cy += np.sin(a) * 1.6
            ix, iy = int(cx), int(cy)
            if 0 <= ix < w - width and 1 <= iy < h - width:
                cv[iy:iy + width, ix:ix + width] = col
                cv[iy - 1, ix:ix + width] = hi
