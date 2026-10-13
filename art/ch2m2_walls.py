"""2장 M2 소굴(den2·den3) 지형에 직접 굽는 돌담 — vox.py 렌더러(같은 카메라 K=0.75·같은 외곽선·팔레트 규칙)로 석축을 쌓아
RGBA 로 뽑아 지형 캔버스에 얹는다. 벽이 지형 그림 위에 얹힌 소품처럼 보이지 않도록 바닥(z=0)은 그리지 않는다.
좌표: 복셀 (x,y)=footprint (fx0+x, fy0+y). 스프라이트 행 r ↔ 그림 y = r + r0 - Z + 0.75*fy0 + 30.
"""
import sys, pathlib, tempfile
import numpy as np
from PIL import Image

HERE = pathlib.Path(__file__).parent
sys.path.insert(0, str(HERE))
import vox
from vox import Vox, Mat, courses, noise3

# 소굴 석재: dungeon 일러스트 판석(푸른 회색)과 같은 계열. 위로 갈수록 밝다
DSTONE = Mat(['#0a0e15', '#121824', '#1c2634', '#2a3748', '#3b4c62', '#52667f', '#72879e'])
DMOSS = Mat(['#0c140f', '#142219', '#1f3324', '#2e4a30', '#456a3e'])


def _render(v, contrast=3.0):
    tmp = pathlib.Path(tempfile.mkdtemp(prefix='ch2m2_vox_'))
    old = vox.OUT
    vox.OUT = tmp
    try:
        v.render('w', contrast=contrast)
    finally:
        vox.OUT = old
    rgba = np.asarray(Image.open(tmp / 'w.png').convert('RGBA'))
    return rgba, v.last_r0


def ring_wall(cx, cy, r, thick, h, gaps, pad=8, ry_scale=1.0, seed=3):
    """원형 담. 중심 (cx,cy) footprint, 안쪽 반경 r(footprint, 가로·세로 같음 — 화면에선 세로가 K 배로 눌린다).
    gaps: [(각도(도), 반폭(footprint px))] 이 방향에 터진 문. 반환 (rgba, x_left, y_top) — 지형 캔버스에 paste."""
    R = r + thick
    X = Y = int(2 * (R + pad))
    Z = h + 12
    v = Vox(X, Y, Z)
    st, ms = v.mat(DSTONE), v.mat(DMOSS)
    gx, gy, gz = v.grid()
    d = np.sqrt((gx + 0.5 - X / 2) ** 2 + (gy + 0.5 - Y / 2) ** 2)
    ang = np.degrees(np.arctan2(gy + 0.5 - Y / 2, gx + 0.5 - X / 2))
    wall = (d >= r) & (d < R) & (gz < h)
    gap = np.zeros_like(wall)
    for a, hw in gaps:
        da = (ang - a + 180) % 360 - 180
        arc = np.radians(np.abs(da)) * (r + thick / 2)           # 호 길이 거리
        gap |= arc < hw
    wall &= ~gap
    courses(v, wall, st, seed, block=(13, 6))
    # 윗돌(갓돌): 한 단 더 두껍게 + 가장자리 하이라이트
    cap = (d >= r - 2) & (d < R + 2) & (gz >= h) & (gz < h + 3) & ~gap
    v.fill(cap, st, 0.9)
    # 이끼가 윗면과 안쪽 모서리로 번진다
    top = wall | cap
    rng = np.random.default_rng(seed)
    mm = (noise3((X, Y, Z), seed + 5, 5) > 0.60) & top & (gz >= h - 3)
    v.fill(mm, ms, 0.2)
    # 문 양옆 기둥(문설주): 문 쪽 끝을 한 칸 더 높인다
    for a, hw in gaps:
        da = (ang - a + 180) % 360 - 180
        arc = np.radians(np.abs(da)) * (r + thick / 2)
        post = (d >= r - 3) & (d < R + 3) & (arc >= hw) & (arc < hw + 9) & (gz < h + 12)
        v.fill(post, st, 0.4)
        v.fill(post & (gz >= h + 9), st, 1.0)
    # 무너진 곳: 담 일부를 낮춘다(소굴이 오래 버려졌다)
    for _ in range(3):
        a0 = rng.uniform(0, 360)
        da = (ang - a0 + 180) % 360 - 180
        br = (np.abs(da) < 5) & (gz > rng.integers(5, 10)) & (d >= r - 3) & (d < R + 3)
        v.m[br] = 0
    rgba, r0 = _render(v)
    fx0, fy0 = cx - X / 2, cy - Y / 2
    return rgba, int(round(fx0)), int(round(r0 - Z + 0.75 * fy0 + 30))


def rect_wall(x0, y0, x1, y1, thick, h, gaps_w=(), gaps_e=(), gaps_n=(), gaps_s=(), pad=6, seed=5):
    """사각 담(바깥 사각 x0..x1, y0..y1 footprint). gaps_*: [(중심 좌표(footprint), 반폭)] 해당 변에 터진 문."""
    X, Y = int(x1 - x0 + 2 * pad), int(y1 - y0 + 2 * pad)
    Z = h + 12
    v = Vox(X, Y, Z)
    st, ms = v.mat(DSTONE), v.mat(DMOSS)
    gx, gy, gz = v.grid()
    px, py = gx + 0.5 - pad, gy + 0.5 - pad            # 사각 안의 좌표
    W, Hh = x1 - x0, y1 - y0
    inside = (px >= 0) & (px < W) & (py >= 0) & (py < Hh)
    ring = inside & ((px < thick) | (px >= W - thick) | (py < thick) | (py >= Hh - thick))
    wall = ring & (gz < h)
    for c, hw in gaps_w:
        wall &= ~((px < thick) & (np.abs(py + y0 - c) < hw))
    for c, hw in gaps_e:
        wall &= ~((px >= W - thick) & (np.abs(py + y0 - c) < hw))
    for c, hw in gaps_n:
        wall &= ~((py < thick) & (np.abs(px + x0 - c) < hw))
    for c, hw in gaps_s:
        wall &= ~((py >= Hh - thick) & (np.abs(px + x0 - c) < hw))
    courses(v, wall, st, seed, block=(13, 6))
    cap = ring & (gz >= h) & (gz < h + 3)
    for c, hw in gaps_w:
        cap &= ~((px < thick) & (np.abs(py + y0 - c) < hw))
    for c, hw in gaps_e:
        cap &= ~((px >= W - thick) & (np.abs(py + y0 - c) < hw))
    v.fill(cap, st, 0.9)
    mm = (noise3((X, Y, Z), seed + 5, 5) > 0.62) & (wall | cap) & (gz >= h - 3)
    v.fill(mm, ms, 0.2)
    # 문설주
    for c, hw in gaps_w:
        post = (px < thick + 3) & (np.abs(py + y0 - c) >= hw) & (np.abs(py + y0 - c) < hw + 9) & inside & (gz < h + 12)
        v.fill(post, st, 0.4); v.fill(post & (gz >= h + 9), st, 1.0)
    rng = np.random.default_rng(seed)
    for _ in range(3):                                  # 무너진 곳
        cx_, cy_ = rng.uniform(0, W), rng.uniform(0, Hh)
        br = (np.abs(px - cx_) < 9) & (np.abs(py - cy_) < 9) & ring & (gz > rng.integers(5, 10))
        v.m[br] = 0
    rgba, r0 = _render(v)
    fx0, fy0 = x0 - pad, y0 - pad
    return rgba, int(round(fx0)), int(round(r0 - Z + 0.75 * fy0 + 30))


def paste_rgba(cv, rgba, x, y):
    """cv: float HxWx3. rgba 의 알파(0/255)로 덮어쓴다."""
    h, w = rgba.shape[:2]
    x0, y0, x1, y1 = max(0, x), max(0, y), min(cv.shape[1], x + w), min(cv.shape[0], y + h)
    if x1 <= x0 or y1 <= y0:
        return
    p = rgba[y0 - y:y1 - y, x0 - x:x1 - x]
    m = p[..., 3] > 0
    reg = cv[y0:y1, x0:x1]
    reg[m] = p[..., :3][m]


# =============================================================== 2D 석축 painter (곡선 담도 깨끗하게)
# 복셀 렌더는 휘어진 담의 앞면이 '말뚝'처럼 끊겨 보여서, 윗면(갓돌) 마스크를 화면에서 아래로 밀어 앞면을 만든다.
# 카메라가 남쪽에서 보므로 보이는 면은 (남쪽 담의 바깥면, 북쪽 담의 안쪽면) = 갓돌 아래쪽 띠.
INKC = np.array([8, 10, 16], np.float32)
FACE = [(22, 30, 42), (34, 46, 62), (48, 62, 80), (64, 80, 100), (82, 100, 120)]
CAP = [(52, 66, 84), (68, 84, 104), (84, 102, 122), (104, 124, 144), (130, 150, 168)]
MOSSC = [(36, 54, 36), (54, 76, 44), (78, 104, 54)]


def _shift_down(m, s):
    out = np.zeros_like(m)
    out[s:] = m[:-s] if s else m
    return out


def draw_wall(cv, cap, h, seed=1, block=13, bid=None, tall=None, tall_h=0):
    """cv: float HxWx3 지형 캔버스(최종 해상도). cap: bool 마스크(갓돌 윗면, 화면 좌표). h: 앞면 높이(px).
    bid: (H,W) int 배열 — 갓돌의 돌 구분(없으면 x//block). tall: 추가 마스크(문설주 갓돌) 와 tall_h(앞면 높이)."""
    H, W = cap.shape
    rng = np.random.default_rng(seed)
    cap = cap.copy()
    face = np.zeros_like(cap)
    depth = np.zeros(cap.shape, np.int16)
    for s in range(1, h + 1):
        sh = _shift_down(cap, s)
        new = sh & ~face & ~cap
        depth[new] = s
        face |= sh
    if tall is not None and tall_h:
        face_t = np.zeros_like(cap)
        for s in range(1, tall_h + 1):
            sh = _shift_down(tall, s)
            new = sh & ~face_t & ~tall
            depth[new & ~(cap | face)] = s
            face_t |= sh
        face |= face_t
        cap |= tall
        face &= ~cap
    yy, xx = np.mgrid[0:H, 0:W]
    # ---- 앞면: 단(course)마다 어긋난 이음, 돌마다 톤, 아래로 갈수록 어둡게
    row = (depth - 1) // 6
    off = (row * 7) % block
    col = (xx + off) // block
    hsh = ((row * 73856093) ^ (col * 19349663) ^ seed) % 1000 / 1000.0
    tone = 3.2 - depth / max(1, h) * 2.4 + (hsh - 0.5) * 1.1
    joint_h = ((depth - 1) % 6 == 5)
    joint_v = ((xx + off) % block == 0)
    ft = np.clip(np.round(tone), 0, 4).astype(int)
    facecol = np.array(FACE, np.float32)[ft]
    facecol[joint_h | joint_v] = np.array(FACE[0], np.float32) * 0.7
    top_lit = ((depth - 1) % 6 == 0) & ~joint_v
    facecol[top_lit] = np.clip(facecol[top_lit] + 14, 0, 255)
    # 아래쪽 접지 그림자
    bottom = depth >= h - 1
    facecol[bottom] *= 0.65
    # 이끼 흘림(앞면 위쪽에서 몇 줄)
    ys, xs = np.where(face & (depth <= 2))
    if len(ys):
        for k in rng.choice(len(ys), size=max(1, len(ys) // 40), replace=False):
            y, x = ys[k], xs[k]
            ln = int(rng.integers(2, 7))
            for j in range(ln):
                if y + j < H and face[y + j, x]:
                    facecol[y + j, x] = MOSSC[min(2, 1 + (j < 2))] if j < ln - 1 else MOSSC[0]
    cv[face] = facecol[face]
    # ---- 갓돌: 돌마다 톤, 줄눈, 윗가장자리 하이라이트
    b = (xx // block) if bid is None else bid
    ch = ((b * 2654435761 + seed * 97) % 1000) / 1000.0
    ci = np.clip(np.round(2.0 + (ch - 0.5) * 2.4), 0, 4).astype(int)
    capcol = np.array(CAP, np.float32)[ci]
    nb_up = np.zeros_like(cap); nb_up[1:] = cap[:-1]
    lit = cap & ~nb_up
    capcol[lit] = np.clip(capcol[lit] + 26, 0, 255)
    bl = np.zeros_like(b); bl[:, 1:] = b[:, :-1]
    jt = cap & (b != bl)
    capcol[jt] = np.array(CAP[0], np.float32) * 0.6
    cv[cap] = capcol[cap]
    # 이끼 덩이(갓돌 위)
    mm = L_noise(H, W, 5, seed + 3) > 0.74
    cm = cap & mm
    cv[cm] = np.array(MOSSC, np.float32)[(L_noise(H, W, 3, seed + 4)[cm] * 3).astype(int).clip(0, 2)]
    # ---- 외곽선: 실루엣 + 갓돌/앞면 경계
    allm = cap | face
    edge = np.zeros_like(allm)
    for dr, dc in ((-1, 0), (1, 0), (0, -1), (0, 1)):
        nb = np.zeros_like(allm)
        ys_ = slice(max(0, dr), H + min(0, dr)); yd = slice(max(0, -dr), H + min(0, -dr))
        xs_ = slice(max(0, dc), W + min(0, dc)); xd = slice(max(0, -dc), W + min(0, -dc))
        nb[yd, xd] = allm[ys_, xs_]
        edge |= allm & ~nb
    under = np.zeros_like(cap); under[1:] = cap[:-1]
    cap_bottom = cap & ~np.concatenate([cap[1:], np.zeros((1, W), bool)], 0) & face_below(cap, face)
    cv[edge] = INKC
    cv[cap_bottom] = np.array(CAP[0], np.float32) * 0.45
    return cap | face


def face_below(cap, face):
    below = np.zeros_like(face); below[:-1] = face[1:]
    return below


def L_noise(h, w, scale, seed):
    import ch2m2_lib as L
    return L.noise(h, w, scale, seed)


def ellipse_mask(W, H, cx, cy, rx, ry):
    yy, xx = np.mgrid[0:H, 0:W].astype(np.float32)
    return ((xx - cx) / rx) ** 2 + ((yy - cy) / ry) ** 2


def ring_cap(W, H, cx, cy, rx, ry, thick, gaps_deg):
    """원형 담 갓돌 마스크(화면 타원 고리). rx,ry: 안쪽 반지름(화면 px; ry = rx*0.75). thick: 가로 두께(px)(세로 두께는 *0.75).
    gaps_deg: [(각도, 반폭각도)] 터진 문. 반환 (cap bool, bid 돌 번호)"""
    d_in = ellipse_mask(W, H, cx, cy, rx, ry)
    d_out = ellipse_mask(W, H, cx, cy, rx + thick, ry + thick * 0.75)
    cap = (d_in >= 1) & (d_out < 1)
    yy, xx = np.mgrid[0:H, 0:W].astype(np.float32)
    ang = np.degrees(np.arctan2((yy - cy) / ry, (xx - cx) / rx))
    for a, hw in gaps_deg:
        da = (ang - a + 180) % 360 - 180
        cap &= ~(np.abs(da) < hw)
    bid = (np.floor((ang + 180) / (360 / 36))).astype(np.int64)
    return cap, bid
