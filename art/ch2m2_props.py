"""2장 M2 소품 — art/vox.py 복셀 렌더러(같은 카메라 K=0.75·같은 외곽선/노멀맵)로 굽는다.
  rockwall      : M1 개선판. 이끼 덤불처럼 보이던 둥근 바위더미 → 각진 층리 바위 절벽(회청색, 수직 균열, 들쭉날쭉한 윗선)
  hut_ruin(_b)  : 무너진 초가(돌 기단·부러진 흙벽·드러난 서까래·내려앉은 이엉) / _b 는 불탄 초가(숯·재·잉걸불)
  old_tools_*   : 도깨비의 '원래 물건' 변형 4종(절구·빗자루·솥·짚신) + old_tools(모아 둔 더미)
  dok_torch     : 귀화색(보라) 횃불 + glow
  mortar_altar  : 보스방 중앙 낡은 절구 제단(엄폐 대상) + glow
  doll          : 짚인형(의뢰 B)
사용: python3 art/ch2m2_props.py [이름...]   → src/assets/props/<이름>.png/_n.png(/_glow.png)
"""
import sys, pathlib
import numpy as np
sys.path.insert(0, str(pathlib.Path(__file__).parent))
import vox
from vox import Vox, Mat, STONE, WOOD, THATCH, MUD, noise3, courses

ROCK2 = Mat(['#0b0d12', '#161920', '#232731', '#343a47', '#495161', '#636c7e', '#808a9c'])
MOSS2 = Mat(['#0b140f', '#12211a', '#1c3225', '#2b4a35', '#3f6a45'])
CHAR = Mat(['#050405', '#0c0a0b', '#161213', '#221c1c', '#312828', '#433737'])
ASH = Mat(['#0d0c0e', '#171518', '#232024', '#322d31', '#443d42'])
EMBER = Mat(['#4a1408', '#8a2a10', '#c8481a', '#ee7a2a', '#ffb050'], glow=True)
VFIRE = Mat(['#2a0e5a', '#5a24b0', '#9048e8', '#c890ff', '#f0d8ff'], glow=True)
IRON = Mat(['#08090d', '#12151c', '#1e232d', '#2c3340', '#3e4757', '#566174'])
STRAW = Mat(['#1c160d', '#30260f', '#4a3c18', '#6a5826', '#8c7636', '#b09a50'])
ROPE = Mat(['#1a0d0b', '#32160f', '#5a2418', '#8a3a24', '#b45a3a'])
PAPER2 = Mat(['#3a3640', '#6a6672', '#98949a', '#c4bcb0', '#e6dfcf'])


def rockwall():
    """바위 절벽: 층리(가로 켜)가 보이는 각진 회청색 바위 덩어리를 쌓고 수직 균열·들쭉날쭉한 윗선. 64 x 36 x 44."""
    X, Y, Z = 64, 36, 44
    v = Vox(X, Y, Z)
    rk, ms = v.mat(ROCK2), v.mat(MOSS2)
    gx, gy, gz = v.grid()
    rng = np.random.default_rng(21)
    # 높이 지도: 큰 덩어리(각진) = 최대 노름 대신 박스형 가우시안 + 능선 노이즈
    hmap = np.zeros((X, Y), np.float32)
    xs, ys = np.mgrid[0:X, 0:Y]
    for _ in range(9):
        cx, cy = rng.uniform(4, X - 4), rng.uniform(14, Y - 8)
        rx, ry = rng.uniform(8, 16), rng.uniform(6, 11)
        hh = rng.uniform(22, 40)
        d = np.maximum(np.abs(xs - cx) / rx, np.abs(ys - cy) / ry)           # 사각 기둥형(각진 덩어리)
        hmap = np.maximum(hmap, hh * np.clip(1.25 - d, 0, 1) ** 0.6)
    ridge = (noise3((X, Y, 1), 3, 4)[:, :, 0] - 0.5) * 8
    hmap = np.clip(hmap + ridge, 0, Z - 2)
    hmap[:, Y - 4:] = np.minimum(hmap[:, Y - 4:], 8)                          # 앞쪽은 낮게 흘러내린 잔돌
    solid = gz < hmap[:, :, None]
    solid &= ~((gx < 2) & (gz > 14)) & ~((gx > X - 3) & (gz > 16))              # 양 끝 둥글리지 않고 깎임
    v.fill(solid, rk)
    # 층리: 가로 켜마다 톤이 갈리고 켜 경계는 어둡다
    strata = (gz // 5)
    sh = rng.random(int(strata.max()) + 2).astype(np.float32) * 1.5 - 0.75
    tone = sh[strata] + np.where(gz % 5 == 0, -0.7, 0.0)
    # 면(facet)마다 톤: 8x6x6 셀 단위로 흔들어 각진 면이 읽히게
    cell = ((gx // 8) * 31 + (gy // 6) * 17 + (gz // 6) * 7)
    ct = (np.sin(cell * 12.9898) * 43758.5453) % 1.0
    tone = tone + (ct - 0.5) * 1.1
    v.tone[solid] = tone[solid]
    # 수직 균열(가늘게 비움)
    for _ in range(3):
        cx = rng.integers(6, X - 6); cy = rng.integers(14, Y - 6)
        for z in range(Z):
            cx += rng.integers(-1, 2)
            crack = (gx == cx) & (gy >= cy - 2) & (gy <= cy + 2) & (gz == z)
            v.m[crack & (gz > 14)] = 0
            v.tone[crack] -= 1.5
    # 이끼는 아주 조금: 바닥 쪽 틈과 윗면 가운데 몇 점 (덤불로 읽히지 않게 면적을 작게)
    base = (gz < 5) & (noise3((X, Y, Z), 8, 3) > 0.62) & (v.m > 0)
    top = (v.m > 0) & ~np.concatenate([(v.m > 0)[:, :, 1:], np.zeros((X, Y, 1), bool)], axis=2) & (noise3((X, Y, Z), 6, 3) > 0.74)
    v.fill(base | top, ms, 0.3)
    v.render('rockwall', contrast=3.6)


def hut_ruin(burnt=False):
    """무너진 초가. 1장 house 와 같은 초가 지붕 공식(둥글고 두꺼운 이엉)을 쓰되 한쪽이 푹 꺼져 어두운 속이 드러나고 서까래가 삐져나오며,
    흙벽은 윗선이 부러졌고 문짝이 없다. burnt=True 는 지붕이 거의 타 없어져 숯 서까래 뼈대만, 재·잉걸불. 104 x 70 x 66."""
    X, Y, Z = 104, 70, 66
    v = Vox(X, Y, Z)
    TH = THATCH if not burnt else CHAR
    th, mud, wd, st = v.mat(TH), v.mat(MUD if not burnt else ASH), v.mat(WOOD if not burnt else CHAR), v.mat(STONE)
    ms, em, ash = v.mat(MOSS2), v.mat(EMBER), v.mat(ASH)
    dark = v.mat(Mat(['#050406', '#0a080c', '#120f15']))
    gx, gy, gz = v.grid()
    rng = np.random.default_rng(5 if not burnt else 9)
    cx = X / 2
    # 기단(돌): 모서리가 군데군데 빠짐
    pl = (gx >= 8) & (gx < X - 8) & (gy >= 18) & (gy < Y - 6) & (gz < 6)
    pl &= ~((noise3((X, Y, Z), 4, 6) > 0.7) & (gz > 2))
    courses(v, pl, st, 3, block=(11, 5))
    # 안쪽 바닥(어두운 흙) — 지붕이 뚫린 곳으로 보이는 속이 어둡게
    v.fill((gx >= 14) & (gx < X - 14) & (gy >= 24) & (gy < Y - 12) & (gz == 6), dark, -0.5)
    # 흙벽: 사방, 윗선이 들쭉날쭉 (앞벽 가운데는 문이 없어 뚫림)
    y0, y1 = 24, Y - 12
    base_h = 38 if not burnt else 22
    jag = (noise3((X, Y, 1), 3, 4)[:, :, 0] * 22).astype(int)[:, :, None]
    wallz = (gz >= 6) & (gz < base_h - jag)
    ring = ((gx >= 14) & (gx < X - 14) & (gy >= y0) & (gy < y1)) & ~((gx >= 20) & (gx < X - 20) & (gy >= y0 + 5) & (gy < y1 - 5))
    door = (gx >= 44) & (gx < 62) & (gy >= y1 - 5)
    wallm = ring & wallz & ~door & ~(noise3((X, Y, Z), 12, 4) > 0.84)
    v.fill(wallm, mud, (noise3((X, Y, Z), 6, 5) * 1.4 - 0.7).astype(np.float32))
    # 문틀: 왼쪽 기둥은 서 있고 오른쪽은 부러졌으며 인방이 비스듬히 떨어져 있다
    v.box(42, y1 - 3, 6, 46, y1 + 1, 40 if not burnt else 24, wd)
    v.box(62, y1 - 3, 6, 66, y1 + 1, 14, wd)
    for t in range(0, 22):
        z = 38 - t
        if z > 6: v.box(46 + t, y1 - 3, z, 49 + t, y1 + 1, z + 3, wd)
    rx, ry = 56, 30
    rcy = (y0 + y1) / 2 + 1
    r = (np.abs((gx + 0.5 - cx) / rx) ** 3 + np.abs((gy + 0.5 - rcy) / ry) ** 3) ** (1 / 3)
    top = 40 + 24 * np.clip(1 - r ** 1.7, 0, 1) ** 0.85
    sag = np.clip(((gx + 0.5 - cx) / rx + 0.15) * 1.6, 0, 1) * 18 * np.clip(1 - r, 0, 1) ** 0.3
    top = top - sag
    bottom = np.where(r > 0.8, 37 + (r - 0.8) * 6, 41)
    roof = (r <= 1) & (gz >= bottom) & (gz <= top)
    hole = (((gx + 0.5 - (cx + 12)) / 14) ** 2 + ((gy + 0.5 - (rcy - 2)) / 9) ** 2) < 1
    roof &= ~(hole & (gz > 30))
    roof &= ~(noise3((X, Y, Z), 13, 5) > 0.86)
    if burnt:
        shred = noise3((X, Y, Z), 7, 3) > 0.66
        roof &= ((gx < cx - 4) | ((gx < cx + 10) & shred))          # 오른쪽 절반은 타 없어짐, 경계는 너덜
    straw = noise3((X, Y, Z), 11, 3) * 0.9 - 0.45
    v.fill(roof, th, straw + np.where((gz % 6) == 0, -0.6, 0.0))
    if burnt:
        # 타 없어진 쪽: 숯 서까래 갈비뼈(앞뒤로 걸친 보가 중간중간 꺾임) + 마룻대
        for k in range(0, 6):
            x = int(cx + 4 + k * 8)
            for t in range(0, 44):
                u = (t - 22) / 22.0
                z = int(40 - 4 * k * 0.8 + 18 * (1 - u * u) - 20)
                yy = int(y0 + 4 + t * 1.0)
                if 2 < x < X - 3 and yy < Y - 5 and not (k % 2 == 1 and 18 < t < 26):
                    v.box(x, yy, max(7, z), x + 3, yy + 2, max(9, z + 2), wd)
        v.box(int(cx + 4), y0 + 4, 30, X - 30, y0 + 7, 33, wd)
        ashm = (noise3((X, Y, Z), 5, 6) > 0.5) & (gz < 8) & (gx > 14) & (gx < X - 14) & (gy > y0) & (gy < y1) & (v.m == 0)
        v.fill(ashm, ash, 0.0)
        for (ex, ey) in ((40, 40), (60, 34), (50, 48), (74, 42), (30, 36)):
            v.box(ex, ey, 6, ex + 3, ey + 3, 9, em)
    else:
        for k in range(9):
            a = rng.uniform(0, 6.28)
            hx0, hy0 = cx + 12 + np.cos(a) * 11, rcy - 2 + np.sin(a) * 7
            ln = int(rng.integers(9, 18))
            for t in range(ln):
                xx, yy, z_ = int(hx0 - np.cos(a) * t * 0.5), int(hy0 - np.sin(a) * t * 0.35), 34 + t // 2 + int(rng.integers(0, 3))
                if 1 < xx < X - 2 and 1 < yy < Y - 2 and z_ < Z - 1:
                    v.box(xx, yy, z_, xx + 2, yy + 2, z_ + 2, wd)
        pile = ((((gx + 0.5 - (cx + 12)) / 12) ** 2 + ((gy + 0.5 - rcy) / 8) ** 2 + ((gz - 8) / 6) ** 2) < 1) & (v.m == 0)
        v.fill(pile, th, 0.1)
        v.fill(roof & (gz > top - 3) & (noise3((X, Y, Z), 9, 3) > 0.8), ms, 0.4)
    v.fill((gz < 5) & (noise3((X, Y, Z), 8, 3) > 0.72) & (v.m > 0) & (v.m != dark), ms, 0.2)
    v.render('hut_ruin_b' if burnt else 'hut_ruin', contrast=3.3)


def old_tools_mortar():
    """절구(돌확) + 공이: 도깨비의 원래 물건. 28 x 22 x 24"""
    X, Y, Z = 28, 22, 26
    v = Vox(X, Y, Z)
    st, wd, ms = v.mat(STONE), v.mat(WOOD), v.mat(MOSS2)
    gx, gy, gz = v.grid()
    d = np.sqrt((gx + .5 - 12) ** 2 + (gy + .5 - 12) ** 2)
    prof = np.where(gz < 3, 9, np.where(gz < 10, 8 + (gz - 3) * 0.6, 12.5 - (gz - 10) * 0.35))
    body = (d < prof) & (gz < 17)
    inner = (d < prof - 4) & (gz >= 8) & (gz < 17)
    v.fill(body & ~inner, st, (noise3((X, Y, Z), 4, 3) * 1.0 - 0.5).astype(np.float32))
    v.fill(inner & (gz < 9), st, -0.9)
    v.fill(body & (gz > 15) & ~inner, st, 0.8)
    # 공이: 비스듬히 기대어 있음
    for t in range(0, 22):
        x = 14 + int(t * 0.55); y = 11 + int(t * 0.15); z = 9 + t
        if z < Z - 1 and x < X - 3:
            v.box(x, y, z, x + 3, y + 3, z + 1, wd)
    v.fill((gz < 4) & (noise3((X, Y, Z), 6, 3) > 0.6) & (v.m > 0), ms, 0.2)
    v.render('old_tools_mortar', contrast=3.2)


def old_tools_broom():
    """빗자루: 싸리 묶음, 끈으로 묶고 벽에 기대 선 모양. 14 x 12 x 40"""
    X, Y, Z = 16, 14, 42
    v = Vox(X, Y, Z)
    sw, rp, wd = v.mat(STRAW), v.mat(ROPE), v.mat(WOOD)
    gx, gy, gz = v.grid()
    cx, cy = 8, 7
    lean = (gz * 0.10)
    d = np.sqrt((gx + .5 - cx - lean) ** 2 + (gy + .5 - cy) ** 2)
    v.fill((d < 1.6) & (gz >= 14), wd, (np.sin(gz * 0.8) * 0.3).astype(np.float32))      # 자루
    spread = 1.6 + (14 - gz) * 0.42
    brush = (d < spread) & (gz < 15) & (gz >= 0)
    v.fill(brush & (noise3((X, Y, Z), 3, 2) > 0.3), sw, (noise3((X, Y, Z), 5, 2) * 1.2 - 0.6).astype(np.float32))
    v.fill((np.abs(d - 2.4) < 0.9) & (gz >= 10) & (gz < 12), rp, 0.5)                    # 묶은 끈
    v.render('old_tools_broom', contrast=3.2)


def old_tools_pot():
    """솥: 세 발 쇠솥, 뚜껑은 비뚤게 걸쳐 있고 한쪽이 깨짐. 30 x 24 x 22"""
    X, Y, Z = 30, 24, 24
    v = Vox(X, Y, Z)
    ir, st = v.mat(IRON), v.mat(STONE)
    gx, gy, gz = v.grid()
    cx, cy = 15, 13
    d = np.sqrt((gx + .5 - cx) ** 2 + ((gy + .5 - cy)) ** 2)
    belly = np.where(gz < 4, 0, 11.5 - np.abs(gz - 11) * 0.6)
    pot = (d < belly) & (gz >= 4) & (gz < 17)
    inner = (d < belly - 2.5) & (gz >= 8)
    v.fill(pot & ~inner, ir, (noise3((X, Y, Z), 4, 3) * 0.8 - 0.4).astype(np.float32))
    v.fill(inner & (gz < 9), ir, -1.2)
    for ang in (0, 120, 240):                                                           # 세 발
        lx, ly = cx + int(np.cos(np.radians(ang)) * 7), cy + int(np.sin(np.radians(ang)) * 5)
        v.box(lx - 1, ly - 1, 0, lx + 2, ly + 2, 5, ir)
    # 귀(손잡이 고리) 둘
    v.box(cx - 13, cy - 1, 13, cx - 10, cy + 1, 16, ir); v.box(cx + 10, cy - 1, 13, cx + 13, cy + 1, 16, ir)
    # 비뚤게 걸친 뚜껑 반쪽
    lid = (np.sqrt((gx + .5 - cx - 2) ** 2 + (gy + .5 - cy) ** 2) < 10) & (gz >= 17 + (gx - cx) * 0.12) & (gz < 19 + (gx - cx) * 0.12) & (gx > cx - 4)
    v.fill(lid, ir, 0.5)
    v.render('old_tools_pot', contrast=3.2)


def old_tools_sandals():
    """짚신 한 켤레: 한 짝은 뒤집힘. 26 x 14 x 8"""
    X, Y, Z = 26, 16, 10
    v = Vox(X, Y, Z)
    sw, rp = v.mat(STRAW), v.mat(ROPE)
    gx, gy, gz = v.grid()
    for (cx, cy, ang, flip) in ((8, 6, 8, False), (18, 10, -14, True)):
        c, s_ = np.cos(np.radians(ang)), np.sin(np.radians(ang))
        u = (gx + .5 - cx) * c + (gy + .5 - cy) * s_
        w = -(gx + .5 - cx) * s_ + (gy + .5 - cy) * c
        sole = ((u / 8.5) ** 2 + (w / 3.6) ** 2 < 1) & (gz < 2)
        v.fill(sole, sw, (noise3((X, Y, Z), 4, 2) * 1.0 - 0.5).astype(np.float32))
        if not flip:
            wall = ((u / 8.5) ** 2 + (w / 3.6) ** 2 < 1) & ((u / 6.6) ** 2 + (w / 2.4) ** 2 >= 1) & (gz >= 2) & (gz < 4) & (u < 4)
            v.fill(wall, sw, 0.3)
            v.fill((np.abs(u + 1.0) < 1.0) & (np.abs(w) < 3.6) & (gz >= 3) & (gz < 5), rp, 0.3)
    v.render('old_tools_sandals', contrast=3.0)


def old_tools():
    """모아 둔 옛 물건 더미: 절구 조각·빗자루·짚신·깨진 솥뚜껑이 한 덩이. 40 x 24 x 22"""
    X, Y, Z = 40, 26, 24
    v = Vox(X, Y, Z)
    st, sw, wd, ir, rp = v.mat(STONE), v.mat(STRAW), v.mat(WOOD), v.mat(IRON), v.mat(ROPE)
    gx, gy, gz = v.grid()
    d = np.sqrt((gx + .5 - 12) ** 2 + (gy + .5 - 12) ** 2)
    body = (d < 8 + np.clip((gz - 2) * 0.3, 0, 2)) & (gz < 11)
    v.fill(body & ~((d < 5) & (gz >= 6)), st, (noise3((X, Y, Z), 4, 3) - 0.5).astype(np.float32))
    for t in range(0, 24):                                                    # 눕힌 공이
        v.box(10 + t, 18 + t // 12, 2 + t // 8, 13 + t, 21 + t // 12, 5 + t // 8, wd)
    for t in range(0, 17):                                                    # 눕힌 빗자루
        v.box(18 + t, 5 + t // 5, 1, 20 + t, 7 + t // 5, 3, wd)
    v.fill((((gx + .5 - 34) / 4.5) ** 2 + ((gy + .5 - 8) / 5.5) ** 2 + ((gz - 2) / 3.2) ** 2) < 1, sw, 0.1)
    v.fill((np.abs(gx - 31) < 1) & (gy >= 5) & (gy < 12) & (gz == 3), rp, 0.5)
    lid = (np.sqrt((gx + .5 - 28) ** 2 + (gy + .5 - 18) ** 2) < 7.5) & (gz >= 1 + (gx - 24) * 0.1) & (gz < 3 + (gx - 24) * 0.1)
    v.fill(lid, ir, 0.4)
    v.render('old_tools', contrast=3.0)


def dok_torch():
    """도깨비 횃불: 쇠 기둥 + 접시 모양 화로에 보랏빛 귀화가 탄다. 20 x 20 x 58 (+ glow)"""
    X, Y, Z = 22, 22, 60
    v = Vox(X, Y, Z)
    ir, wd, vf, st = v.mat(IRON), v.mat(WOOD), v.mat(VFIRE), v.mat(STONE)
    gx, gy, gz = v.grid()
    cx, cy = 11, 11
    d = np.sqrt((gx + .5 - cx) ** 2 + (gy + .5 - cy) ** 2)
    v.fill((np.abs(gx + .5 - cx) < 8) & (np.abs(gy + .5 - cy) < 7) & (gz < 4), st, -0.3)       # 돌 받침(네모, 구슬처럼 보이지 않게)
    v.fill((d < 2.2) & (gz >= 4) & (gz < 36), wd, (np.sin(gz * 1.1) * 0.35).astype(np.float32))   # 기둥(나무, 쇠띠)
    for z in (10, 22, 33):
        v.fill((d < 3.0) & (gz >= z) & (gz < z + 2), ir, 0.4)
    bowl = (d < 7.0) & (gz >= 36) & (gz < 39) & (d >= np.where(gz < 37, 0, 5.2))
    v.fill(bowl, ir, np.where(gz > 38, 0.8, 0.0))
    for ang in (0, 90, 180, 270):                                                # 화로 발톱
        lx, ly = cx + int(np.cos(np.radians(ang)) * 6), cy + int(np.sin(np.radians(ang)) * 6)
        v.box(lx - 1, ly - 1, 33, lx + 1, ly + 1, 37, ir)
    # 불꽃: 아래 넓고 위로 뾰족, 흔들리는 비대칭
    fz = gz - 38
    fr = np.clip(5.2 - fz * 0.34, 0, 6)
    wob = np.sin(fz * 0.7) * 1.4
    fl = (np.sqrt((gx + .5 - cx - wob) ** 2 + ((gy + .5 - cy) * 1.2) ** 2) < fr) & (gz >= 38) & (gz < 58)
    t = np.clip(((fz / 18) * 3.2).astype(np.int8), 0, 4)        # 램프는 glow 모드에서 tone 정수로 고른다
    v.fill(fl, vf, (np.clip(1.0 - fz * 0.10, -1, 1.6)).astype(np.float32))        # glow 램프: 2+tone → 보라(1~3), 흰 끝은 아주 위만
    v.render('dok_torch', contrast=3.2)


def mortar_altar():
    """보스방 중앙 절구 제단: 둥근 돌 단 위에 낡은 큰 절구, 안에서 귀화가 피어오르고 공이가 비스듬히 꽂혀 있다. 70 x 62 x 54 (+ glow)"""
    X, Y, Z = 72, 62, 58
    v = Vox(X, Y, Z)
    st, wd, vf, ms, ir = v.mat(STONE), v.mat(WOOD), v.mat(VFIRE), v.mat(MOSS2), v.mat(IRON)
    gx, gy, gz = v.grid()
    cx, cy = 36, 34
    d = np.sqrt((gx + .5 - cx) ** 2 + ((gy + .5 - cy) * 1.0) ** 2)
    # 3단 둥근 기단(층층)
    for k, (r, h) in enumerate(((31, 4), (26, 8), (22, 11))):
        m = (d < r) & (gz < h)
        courses(v, m, st, 2 + k, block=(10, 4))
        v.tone[m & (gz == h - 1)] += 0.8
    # 절구 몸통: 아래 좁고 위가 넓다. 목 부분 허리 + 가로 새김 띠
    prof = np.where(gz < 11, 0, np.interp(gz, [11, 16, 24, 34, 40], [10, 14, 17, 19, 20.5]))
    body = (d < prof) & (gz >= 11) & (gz < 41)
    inner = (d < prof - 5.5) & (gz >= 31)
    v.fill(body & ~inner, st, (noise3((X, Y, Z), 5, 3) * 1.2 - 0.6).astype(np.float32))
    v.fill(inner & (gz < 36), st, -1.4)
    band = body & ~inner & ((gz == 22) | (gz == 23) | (gz == 30))
    v.tone[band] -= 1.4
    rim = (d < 21) & (d > 14.5) & (gz >= 40) & (gz < 42)
    v.fill(rim, st, 0.9)
    # 귀화(절구 안쪽에서 피어오름)
    fz = gz - 36
    fr = np.clip(11 - fz * 0.55, 0, 12)
    wob = np.sin(fz * 0.5) * 1.6
    fl = (np.sqrt((gx + .5 - cx - wob) ** 2 + (gy + .5 - cy) ** 2) < fr) & (gz >= 35) & (gz < 54)
    v.fill(fl, vf, np.clip(1.0 - fz * 0.09, -1, 1.6).astype(np.float32))
    # 공이: 비스듬히 꽂힘(불 옆)
    for t in range(0, 30):
        x = cx + 8 + int(t * 0.45); y = cy - 4 + int(t * 0.1); z = 34 + t
        if z < Z - 1 and x < X - 4:
            v.box(x, y, z, x + 4, y + 4, z + 1, wd)
    # 이끼
    v.fill((v.m == st) & (gz < 8) & (noise3((X, Y, Z), 9, 3) > 0.66), ms, 0.3)
    v.render('mortar_altar', contrast=3.3)


def doll():
    """짚인형(의뢰 B): 두 발로 서 있는 작은 짚 사람. 머리·몸통·가로로 벌린 두 팔·두 다리, 목에 붉은 끈, 가슴에 부적 조각, 한쪽 눈 자리에 매듭. 22 x 12 x 40"""
    X, Y, Z = 24, 14, 42
    v = Vox(X, Y, Z)
    sw, rp, pp, ink = v.mat(STRAW), v.mat(ROPE), v.mat(PAPER2), v.mat(Mat(['#07060b', '#0c0a10', '#14101a']))
    gx, gy, gz = v.grid()
    cx, cy = 12, 7
    n = (noise3((X, Y, Z), 3, 2) * 1.2 - 0.6).astype(np.float32)
    dx, dy = gx + .5 - cx, gy + .5 - cy
    head = ((dx / 5.2) ** 2 + (dy / 4.4) ** 2 + ((gz - 33) / 5.6) ** 2) < 1
    v.fill(head, sw, n + 0.2)
    torso = ((dx / 4.4) ** 2 + (dy / 3.2) ** 2 < 1) & (gz >= 13) & (gz < 28)
    v.fill(torso, sw, n)
    for sgn in (-1, 1):                                                          # 다리 둘(벌어짐)
        leg = (((dx - sgn * 3.0) / 2.0) ** 2 + (dy / 2.4) ** 2 < 1) & (gz >= 0) & (gz < 14)
        v.fill(leg, sw, n - 0.2)
        arm = (np.abs(gz - (25 - np.abs(dx) * 0.75)) < 2.0) & (np.abs(dx) < 9) & (np.abs(dx) > 3) & (np.abs(dy) < 2.2)
        v.fill(arm & (np.sign(dx) == sgn), sw, n)
    v.fill((np.abs(gz - 28.5) < 1.1) & (((dx) / 3.4) ** 2 + (dy / 2.8) ** 2 < 1.25) & (v.m > 0), rp, 0.8)   # 목끈
    v.fill((np.abs(gz - 15) < 1.0) & (((dx) / 4.6) ** 2 + (dy / 3.4) ** 2 < 1.1) & (v.m > 0), rp, 0.5)      # 허리끈
    v.box(cx + 3, cy + 1, 17, cx + 5, cy + 2, 20, pp)                            # 옆구리에 꽂은 작은 쪽지
    v.m[cx - 3:cx - 1, cy + 3:cy + 5, 33:35] = ink                              # 눈 한 점(점 두 개 중 왼쪽만 — 한쪽 눈)
    v.m[cx + 1:cx + 3, cy + 3:cy + 5, 33:34] = ink
    v.render('doll', contrast=3.2)


ALL = {'rockwall': rockwall, 'hut_ruin': lambda: hut_ruin(False), 'hut_ruin_b': lambda: hut_ruin(True),
       'old_tools_mortar': old_tools_mortar, 'old_tools_broom': old_tools_broom, 'old_tools_pot': old_tools_pot,
       'old_tools_sandals': old_tools_sandals, 'old_tools': old_tools, 'dok_torch': dok_torch, 'mortar_altar': mortar_altar, 'doll': doll}

if __name__ == '__main__':
    vox.OUT.mkdir(parents=True, exist_ok=True)
    for n in (sys.argv[1:] or list(ALL)):
        ALL[n]()
