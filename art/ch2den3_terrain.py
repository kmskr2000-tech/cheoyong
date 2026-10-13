"""2장 두억시니의 방(den3) 전용 지형 — M2 의 '코드 판석' 바닥을 일러스트 소재로 갈아엎은 리페인트.
걷기 기하(ch2m2_maps.MAPS['den3'])·충돌 json·소품 좌표는 그대로다(그림만 새로 그린다): 걷는 면 png x44~598, y62~299, 서쪽 입구 복도.
 바닥 = dungeon 원본 일러스트의 '진짜 바닥'(금 간 큰 판석·이끼)을 뒤집기까지 섞어 퀼팅 + 보라회색으로 톤 이동
 중앙 의식대 = 타원 세 겹(r40 제단 석판 / r98 안쪽 판 / r130 바깥 띠) 섹터 석판 + 보라 상감선 + 소환점 8(45도, r130 — 설계서 §4.6)
 균열 = 제단에서 방사하는 검은 틈(검은 비가 스며든 곳) + 모서리 검은 물웅덩이
 북·남 벽 = dungeon 일러스트의 파도문 프리즈 띠(den1 에서 뜸), 서·동 벽 = 기존 석축 페인터
사용: python3 art/ch2den3_terrain.py   (den3 만 다시 만든다. den1.png 가 먼저 있어야 한다)
"""
import sys, pathlib
import numpy as np
from PIL import Image
from scipy import ndimage as ndi

ROOT = pathlib.Path(__file__).parent
sys.path.insert(0, str(ROOT))
import ch2m2_lib as L
import ch2m2_terrain as T
import ch2m2_walls as WL

W, H = 640, 326
CX, CY = 320, 180            # 의식 원 중심(그림 좌표) = footprint (320,200)
RX = 130                     # 소환진 반경(footprint 130 → 그림 가로 130 / 세로 97.5)
RY = RX * 0.75
S = T.S


# ------------------------------------------------------------------ 바닥 퀼팅
def floor_pools():
    v = L.load('dungeon')
    boxes = [(770, 270, 1015, 425), (515, 500, 660, 700), (770, 300, 1010, 420)]   # 원본 해상도의 '깨끗한' 바닥 두 곳
    return [v[y0:y1, x0:x1] for (x0, y0, x1, y1) in boxes[:2]]


def quilt_multi(pools, out_hw, block=112, overlap=28, seed=5, tries=260):
    """L.quilt 와 같은 Efros-Freeman 이지만 후보를 여러 풀에서, 뒤집어서도 뽑는다(반복 무늬 줄이기)."""
    rng = np.random.default_rng(seed)
    Ho, Wo = out_hw
    step = block - overlap
    ny, nx = -(-(Ho - overlap) // step), -(-(Wo - overlap) // step)
    out = np.zeros((ny * step + overlap, nx * step + overlap, 3), np.float32)
    for j in range(ny):
        for i in range(nx):
            y, x = j * step, i * step
            best, bd = None, 1e30
            for _ in range(tries):
                p = pools[int(rng.integers(0, len(pools)))]
                ph, pw = p.shape[:2]
                sy, sx = int(rng.integers(0, ph - block)), int(rng.integers(0, pw - block))
                c = p[sy:sy + block, sx:sx + block]
                if rng.random() < 0.5:
                    c = c[:, ::-1]
                if rng.random() < 0.5:
                    c = c[::-1]
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
            m = np.ones((block, block), np.float32)
            if i > 0:
                e = ((c[:, :overlap] - out[y:y + block, x:x + overlap]) ** 2).sum(2)
                m[:, :overlap] = np.minimum(m[:, :overlap], L._cut_v(e))
            if j > 0:
                e = ((c[:overlap] - out[y:y + overlap, x:x + block]) ** 2).sum(2)
                m[:overlap] = np.minimum(m[:overlap], L._cut_v(e.T).T)
            m = ndi.gaussian_filter(m, 0.8)
            out[y:y + block, x:x + block] = out[y:y + block, x:x + block] * (1 - m[..., None]) + c * m[..., None]
    return out[:Ho, :Wo]


def violet_gray(c):
    """청록 바닥을 보라회색으로: 채널을 섞어 푸른 기를 덜고 붉은 기를 얹는다(휘도는 거의 유지)."""
    R, G, B = c[..., 0], c[..., 1], c[..., 2]
    lum = (R * .3 + G * .59 + B * .11)
    out = np.stack([0.66 * R + 0.40 * B, 0.70 * G + 0.08 * B + 0.12 * R, 0.22 * R + 0.70 * B], -1)
    out = out * (lum / np.maximum(out @ np.array([.3, .59, .11], np.float32), 1))[..., None]
    return np.clip(out, 0, 255)


def base_floor():
    pools = [violet_gray(p) for p in floor_pools()]
    hi = quilt_multi(pools, (round(H * S), round(W * S)))
    img = Image.fromarray(np.clip(hi, 0, 255).astype(np.uint8)).resize((W, H), Image.BOX)
    return np.asarray(img, np.float32)


# ------------------------------------------------------------------ 의식대
def polar():
    yy, xx = np.mgrid[0:H, 0:W].astype(np.float32)
    dx, dy = (xx - CX), (yy - CY)
    r = np.sqrt((dx / RX) ** 2 + (dy / RY) ** 2)            # 1.0 = 소환진 원
    ang = np.degrees(np.arctan2(dy / RY, dx / RX)) % 360
    return r, ang


VIO = [(52, 24, 96), (96, 46, 170), (150, 86, 236), (200, 150, 255)]


def ritual(cv, wm, rng):
    r, ang = polar()
    walk = wm > 0.5
    # 1) 판 위에 섹터 석판: 안쪽 판(r<0.75) 12섹터 / 바깥 띠(0.75..1.0) 24섹터, 석판마다 톤 ±
    inner = (r < 0.75) & walk
    band = (r >= 0.75) & (r < 1.02) & walk
    sec_i = np.floor(ang / 30).astype(int)
    sec_b = np.floor(ang / 15).astype(int)
    ring_i = np.floor(r / 0.375).astype(int)               # 안쪽 판은 r 구간 2단(0.375 경계)
    cell = np.where(inner, ring_i * 100 + sec_i, 1000 + sec_b)
    h = ((cell * 2654435761) % 1000) / 1000.0
    tone = np.where(inner, 0.88 + (h - 0.5) * 0.30, 0.66 + (h - 0.5) * 0.24)       # 안쪽 판이 더 밝다, 띠는 어둡다
    sel = inner | band
    cv[sel] = cv[sel] * tone[sel][..., None] + np.array([6, 2, 14], np.float32) * 1.0
    # 석판 경계(어두운 줄눈): 셀 id 가 바뀌는 곳
    cid = cell.astype(np.int64)
    edge = np.zeros_like(sel)
    edge[:, 1:] |= (cid[:, 1:] != cid[:, :-1])
    edge[1:, :] |= (cid[1:, :] != cid[:-1, :])
    edge &= sel
    cv[edge] = (14, 12, 22)
    # 위쪽 하이라이트(각 석판의 윗 가장자리 1px)
    lit = np.zeros_like(sel)
    lit[1:, :] = edge[:-1, :] & ~edge[1:, :] & sel[1:, :]
    cv[lit] = np.clip(cv[lit] * 1.35 + 8, 0, 255)
    # 2) 보라 상감선: r=1.0(소환진 원) / r=0.75(안쪽 판 가장자리) / r=0.30(제단 둘레)
    for rr, wid, dim in ((1.0, 0.020, 0), (0.75, 0.016, 1), (0.30, 0.020, 1)):
        d = np.abs(r - rr)
        core = (d < wid) & walk
        halo = (d >= wid) & (d < wid + 0.024) & walk
        cv[halo] = cv[halo] * 0.38 + np.array((10, 6, 22), np.float32) * 0.62          # 상감 홈(어두운 테두리)
        cv[core] = (64, 34, 118) if dim else (96, 52, 170)
        top = core & ~np.roll(core, 1, axis=0)                                         # 윗줄 하이라이트
        cv[top] = VIO[1] if dim else (140, 84, 214)
    # 3) 소환점 8(45도): 보라 마름모 + 바깥 점 — 설계서 소환진 후보와 같은 8점(r=130 footprint)
    for k in range(8):
        a = np.radians(k * 45)
        x0, y0 = CX + np.cos(a) * RX, CY + np.sin(a) * RY
        for dy in range(-4, 5):
            for dx in range(-6, 7):
                if abs(dx) / 6 + abs(dy) / 4 <= 1.0:
                    px, py = int(round(x0 + dx)), int(round(y0 + dy))
                    if 0 <= px < W and 0 <= py < H and walk[py, px]:
                        e = abs(dx) / 6 + abs(dy) / 4
                        cv[py, px] = VIO[3] if e < 0.35 else (VIO[2] if e < 0.7 else VIO[1])
    # 4) 살(8방향) — 점선: 안쪽 판 가장자리(0.75)에서 소환점 쪽으로 곧게, 끊긴 상감
    for k in range(8):
        a = np.radians(k * 45 + 22.5)
        for t in np.arange(0.34, 0.74, 0.012):
            if int(t * 100) % 6 < 3:
                px, py = int(CX + np.cos(a) * RX * t), int(CY + np.sin(a) * RY * t)
                if walk[py, px]:
                    cv[py, px] = VIO[1]
    return r


# ------------------------------------------------------------------ 균열·검은 물·잔해
def fissures(cv, wm, rng, r):
    """제단에서 방사하는 틈. 어둡게 1~2px + 한쪽에 보라 점(검은 비가 스며 나온 자국)."""
    walk = wm > 0.5
    starts = [(8, 1.12), (38, 1.1), (75, 1.12), (118, 1.1), (158, 1.12), (200, 1.1), (245, 1.12), (298, 1.1), (335, 1.12)]
    for ad, r0 in starts:
        a = np.radians(ad + rng.uniform(-6, 6))
        x, y = CX + np.cos(a) * RX * r0, CY + np.sin(a) * RY * r0
        ln = int(rng.integers(26, 56))
        ang = a
        for i in range(ln):
            ang += rng.normal(0, 0.28)
            x += np.cos(ang) * 2.0; y += np.sin(ang) * 1.5
            ix, iy = int(x), int(y)
            if not (50 <= ix < 592 and 66 <= iy < 295) or not walk[iy, ix]:
                break
            if abs(((ix - CX) / RX) ** 2 + ((iy - CY) / RY) ** 2) < 1.05:
                continue
            wid = 2 if i < ln * 0.55 else 1
            cv[iy:iy + wid, ix:ix + wid + 1] = (9, 8, 16)
            if i % 5 == 2 and wid == 2:
                cv[iy, ix + wid + 1] = VIO[0]
    # 틈이 끝나는 곳의 작은 파편
    return cv


def black_pool(cv, wm, cx, cy, rx, ry, seed):
    """검은 비 웅덩이: 불규칙한 어두운 물 + 가장자리 1px 밝은 테 + 보라 반짝임. wm 걷기 밖은 건드리지 않는다."""
    rng = np.random.default_rng(seed)
    x0, x1, y0, y1 = int(cx - rx * 1.5), int(cx + rx * 1.5), int(cy - ry * 1.5), int(cy + ry * 1.5)
    yy, xx = np.mgrid[y0:y1, x0:x1].astype(np.float32)
    n = L.noise(y1 - y0, x1 - x0, 12, seed) - 0.5
    d = np.sqrt(((xx - cx) / rx) ** 2 + ((yy - cy) / ry) ** 2) + n * 0.55
    m = d < 1.0
    m &= wm[y0:y1, x0:x1] > 0.5
    rim = m & ~ndi.binary_erosion(m, iterations=1)
    inn = ndi.binary_erosion(m, iterations=2)
    sub = cv[y0:y1, x0:x1]
    sub[m] = (14, 16, 30)
    sub[inn] = (8, 10, 22)
    sub[rim] = (44, 52, 86)
    # 잔물결: 가로 한 줄짜리 밝은 선, 보라 반짝이
    for k in range(int(rx * ry / 55)):
        px, py = int(rng.integers(0, x1 - x0)), int(rng.integers(0, y1 - y0))
        if inn[py, px]:
            ln = int(rng.integers(3, 7))
            seg = inn[py, px:px + ln]
            sub[py, px:px + len(seg)][seg] = (34, 44, 82)
            if rng.random() < 0.35 and inn[py, min(px + 1, x1 - x0 - 1)]:
                sub[py, px] = VIO[1]


def real_puddle(cv, wm, box, at, flip=False):
    """dungeon 원본의 검은 물웅덩이(+항아리)를 어두운 픽셀 마스크로 떠서 보라 기운으로 얹는다. 걷기 밖은 건드리지 않는다."""
    v = L.load('dungeon')
    x0, y0, x1, y1 = box
    p = v[y0:y1, x0:x1]
    if flip:
        p = p[:, ::-1]
    img = Image.fromarray(np.clip(p, 0, 255).astype(np.uint8)).resize((round(p.shape[1] / S), round(p.shape[0] / S)), Image.BOX)
    q = violet_gray(np.asarray(img, np.float32))
    lum = q @ np.array([.3, .59, .11], np.float32)
    m = ndi.binary_closing(lum < 40, iterations=2)
    m = ndi.binary_fill_holes(m)
    m = ndi.binary_opening(m, iterations=1)
    lab, n = ndi.label(m)
    if n:
        sizes = ndi.sum(m, lab, range(1, n + 1))
        keep = np.isin(lab, [i + 1 for i, sz in enumerate(sizes) if sz > 60])
        m = keep
    ax, ay = at
    h, w = m.shape
    sub = wm[ay:ay + h, ax:ax + w] > 0.5
    if sub.shape != m.shape:
        return
    mm = m & sub
    cv[ay:ay + h, ax:ax + w][mm] = q[mm]


def den3_source():
    rng = np.random.default_rng(77)
    wm = T.walk_mask('den3', 1.0)
    outer = L.grime(L.flagstones(W, H, seed=31, pal=T.DARK_SLAB, moss=0.5), seed=17, strength=0.45)
    floor = base_floor()
    # 큰 얼룩: 벽 쪽 가장자리를 어둡게(그을음·습기), 중앙 의식대 둘레는 조금 밝게
    yy, xx = np.mgrid[0:H, 0:W].astype(np.float32)
    dn = np.minimum.reduce([xx - 44, 598 - xx, yy - 62, 299 - yy])
    edge_dark = np.clip(1 - dn / 46.0, 0, 1) * 0.28
    n = L.noise(H, W, 40, 11)
    floor = floor * (1 - edge_dark[..., None]) * (0.90 + 0.20 * n)[..., None]
    ww = np.asarray(Image.fromarray((wm * 255).astype(np.uint8)).filter(__import__('PIL.ImageFilter', fromlist=['x']).MaxFilter(9)))
    cv = np.where((ww > 127)[..., None], floor, outer).astype(np.float32)
    r = ritual(cv, wm, rng)
    # 제단 밑 문양 석판(den1 북서 문양 바닥) — 소품 mortar_altar 가 위에 앉는다
    d1 = T.den1_png()
    sl = d1[36:98, 20:132]
    L.paste(cv, sl, CX - 56, CY - 30, None)
    # 검은 웅덩이 4곳(소품·소환점과 겹치지 않는 모서리 쪽) + 일러스트 웅덩이 스탬프
    black_pool(cv, wm, 100, 118, 26, 11, 3)
    real_puddle(cv, wm, (510, 365, 705, 510), (480, 238), flip=True)            # 동쪽 아래: 깨진 항아리 + 검은 물
    black_pool(cv, wm, 232, 280, 18, 8, 5)
    black_pool(cv, wm, 540, 112, 16, 9, 6)
    T.decals(cv, rng, [('pots_b', 136, 262, False), ('pile', 500, 86, True)], d1)
    fissures(cv, wm, rng, r)
    L.rubble(cv, rng, [(rng.uniform(70, 570), rng.uniform(72, 292)) for _ in range(12)])
    L.glow_pools(cv, [(60, 120), (580, 120), (60, 260), (580, 260), (320, 70)], radii=(18, 40, 70), adds=((10, 4, 20), (8, 3, 14), (6, 2, 10)))
    walls(cv, rng)
    return cv, None, None


# ------------------------------------------------------------------ 벽
STRIP = None


def wall_strip():
    """den1 일러스트의 파도문 프리즈 벽(갓돌 + 프리즈 + 벽돌 단) 띠. (왼 문설주 19px | 몸 120px | 오른 문설주 10px)"""
    d1 = T.den1_png()
    rows = d1[188:244]
    return rows[:, 157:176], rows[:, 176:296], rows[:, 296:306]


def paste_strip(cv, y_top, x0, x1, flip_alt=True):
    lp, body, rp = wall_strip()
    x = x0
    cv[y_top:y_top + 56, x:x + lp.shape[1]] = lp[:cv.shape[0] - y_top]
    x += lp.shape[1]
    k = 0
    while x + body.shape[1] <= x1 - rp.shape[1]:
        b = body[:, ::-1] if (flip_alt and k % 2) else body
        cv[y_top:y_top + 56, x:x + b.shape[1]] = b[:cv.shape[0] - y_top]
        x += b.shape[1]; k += 1
    rest = x1 - rp.shape[1] - x
    if rest > 0:
        b = (body[:, ::-1] if (k % 2) else body)[:, :rest]
        cv[y_top:y_top + 56, x:x + rest] = b[:cv.shape[0] - y_top]
    cv[y_top:y_top + 56, x1 - rp.shape[1]:x1] = rp[:cv.shape[0] - y_top]


def walls(cv, rng):
    # 북벽: 앞면 아래 끝이 걷기 시작선(y=62)에 닿게
    cv[0:14, 20:620] = (14, 18, 26)
    paste_strip(cv, 62 - 56, 20, 620)
    # 남벽: 갓돌 윗면이 걷기 끝선(y=299)에서 시작(프리즈는 캔버스 아래로 잘림)
    paste_strip(cv, 299 - 2, 20, 620)
    # 서·동 벽: 같은 갓돌 줄을 90도 돌려 세로로 세운다(옆에서 본 벽 윗면). 서쪽은 입구 문(png y150~212)
    d1 = T.den1_png()
    cap_row = d1[191:211, 178:296]                      # 갓돌 한 줄(높이 20 x 길이 118)
    cap_row = cap_row * np.array([0.80, 0.78, 0.84], np.float32)      # 세로 벽은 윗벽보다 한 톤 어둡게(빛이 위에서)
    col = np.rot90(cap_row, 1)                          # 길이가 세로로
    def side(x0, flip):
        c = col[:, ::-1] if flip else col
        y = 56
        k = 0
        while y < 305:
            seg = (c if k % 2 == 0 else c[::-1])
            h = min(seg.shape[0], 305 - y)
            cv[y:y + h, x0:x0 + seg.shape[1]] = seg[:h]
            y += seg.shape[0]; k += 1
    side(24, False)
    side(598, True)
    # 입구 틈(png y150~212)은 갓돌을 지우고 문설주 돌 둘로 끝을 마감한다 — 바닥은 걷기 면이라 건드리지 않음
    gate = ndi.binary_dilation(np.pad(np.zeros((1, 1), bool), 0), iterations=0) if False else None
    fl = cv[150:212, 46:70].copy()
    cv[150:212, 20:46] = np.concatenate([fl[:, ::-1], fl[:, ::-1]], 1)[:, :26]
    post = np.rot90(cap_row[:, :24], 1)                  # 24 x 20
    for y0 in (128, 212):
        cv[y0:y0 + 24, 24:44] = post
    L.roots(cv, rng, [(x, y, a) for (x, y, a) in [(60, 12, 0.4), (500, 8, 1.8), (612, 60, 2.4), (14, 306, -0.4), (606, 318, -2.6)]], n=30)


DEN3_TONE = dict(bright=1.12, sat=1.0, tint=(66, 30, 84), mix=0.16)


def build():
    img, _, _ = den3_source()
    return T.finish('den3', Image.fromarray(np.clip(img, 0, 255).astype(np.uint8)), DEN3_TONE, W, H)


if __name__ == '__main__':
    build()
