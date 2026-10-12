"""2장 M1 소품 4종 — art/vox.py 의 복셀 렌더러(같은 카메라 K=0.75, 같은 팔레트·외곽선·노멀맵)로 굽는다.
  rockwall  : 좁은 길목 양옆 바위벽(엄폐·충돌 대상, T9)
  tent      : 화개 저자 장사치 천막
  burnt_stall: 습격 후 불탄 좌판(raided 플래그 후) — 잉걸불 glow 포함
  sansingak : 산신각(맞배지붕 한 칸) — 지리산 산길 땅그림에는 이미 한 채가 그려져 있어 jiri 에는 놓지 않는다(예비·다른 산신 터용)
사용: python3 art/ch2_props.py [rockwall tent burnt_stall sansingak]  → src/assets/props/<name>.png/_n.png(/_glow.png)
"""
import sys, pathlib
import numpy as np
sys.path.insert(0, str(pathlib.Path(__file__).parent))
import vox
from vox import Vox, Mat, STONE, WOOD, GRASS, GLOW, GIWA, PAPER, REDWOOD, noise3

ROCK = Mat(['#0e0b10', '#1a1519', '#282024', '#382c2e', '#4a3c3a', '#5e4e48', '#76645a'])
MOSS = Mat(['#0a1210', '#101c18', '#18291f', '#233a2a', '#34503a'])
HEMP = Mat(['#14110e', '#221d17', '#352d23', '#4d4234', '#665845', '#80705a'])
CHAR = Mat(['#0a0808', '#161111', '#241b18', '#352823', '#4a3a31', '#5e4b3e'])
ASH = Mat(['#0d0c0e', '#171518', '#232024', '#322d31', '#443d42'])
EMBER = Mat(['#4a1408', '#8a2a10', '#c8481a', '#ee7a2a', '#ffb050'], glow=True)
INDIGO = Mat(['#0c1026', '#141a3a', '#1e2854', '#2c3a74', '#3e4e92'])


def rockwall():
    """바위벽: 이끼 낀 둥근 바위를 쌓은 낮은 능선. 가로 64 x 깊이 36(footprint) x 높이 40."""
    X, Y, Z = 64, 36, 40
    v = Vox(X, Y, Z)
    rk, ms = v.mat(ROCK), v.mat(MOSS)
    gx, gy, gz = v.grid()
    rng = np.random.default_rng(7)
    for _ in range(46):                                           # 아래 큰 바위 → 위 작은 바위
        zc = rng.uniform(4, 30) ** 0.9
        r = np.interp(zc, [0, 34], [11, 5]) * rng.uniform(0.8, 1.2)
        cx, cy = rng.uniform(r * 0.6, X - r * 0.6), rng.uniform(11, Y - 11)
        blob = (((gx + 0.5 - cx) / (r * 1.15)) ** 2 + ((gy + 0.5 - cy) / (r * 0.95)) ** 2 + ((gz + 0.5 - zc) / (r * 0.9)) ** 2) < 1
        v.fill(blob, rk, float(rng.random() * 1.6 - 0.8))
    # 윗면 이끼 + 갈라진 결
    top = (v.m > 0) & ~np.concatenate([(v.m > 0)[:, :, 1:], np.zeros((X, Y, 1), bool)], axis=2)
    v.fill(top & (noise3((X, Y, Z), 5, 4) > 0.46), ms, 0.4)
    crack = (v.m == rk) & (noise3((X, Y, Z), 9, 3) > 0.74)
    v.tone[crack] -= 1.5
    # 바닥 모서리 둥글게: 가장자리 복셀 깎기
    edge = (gx < 3) | (gx > X - 4)
    v.m[edge & (gz > 26)] = 0
    v.render('rockwall', contrast=3.4)


def tent():
    """장사치 천막: 삼베 천 A자 지붕(마루가 앞뒤로), 앞은 열려 짐 자루와 항아리가 보인다. 56 x 40 x 42."""
    X, Y, Z = 56, 40, 42
    v = Vox(X, Y, Z)
    hp, wd, ind, st = v.mat(HEMP), v.mat(WOOD), v.mat(INDIGO), v.mat(STONE)
    gx, gy, gz = v.grid()
    cx = X / 2
    for (px, py) in ((6, 6), (X - 9, 6), (6, Y - 9), (X - 9, Y - 9)):
        v.box(px, py, 0, px + 3, py + 3, 24, wd)
    v.box(cx - 1.5, 4, 36, cx + 1.5, Y - 4, 39, wd) if False else v.box(int(cx) - 1, 4, 36, int(cx) + 2, Y - 3, 39, wd)   # 마룻대
    v.box(int(cx) - 1, 5, 24, int(cx) + 2, 8, 37, wd); v.box(int(cx) - 1, Y - 8, 24, int(cx) + 2, Y - 5, 37, wd)
    u = np.abs(gx + 0.5 - cx) / (X / 2 - 1)
    roof_z = 37 - u * 15                                         # 마루에서 처마로 처짐
    sag = np.sin(gy / (Y - 1) * np.pi) * 1.6
    shell = (np.abs(gz + 0.5 - (roof_z - sag)) < 1.6) & (gy >= 2) & (gy < Y - 1) & (u <= 1)
    v.fill(shell, hp, np.where((gx // 6) % 2 == 0, 0.35, -0.3))
    band = shell & (gy >= Y - 5)                                 # 앞 처마 남빛 띠
    v.m[band] = ind
    for x in range(2, X - 2, 5):                                 # 처마 끝 물결
        v.box(x, Y - 2, 14 if abs(x - cx) > 18 else 20, x + 3, Y - 1, 22 if abs(x - cx) > 18 else 27, ind)
    # 앞쪽 바닥: 짐 자루·항아리
    for (sx, sy, sw, sh) in ((14, 24, 10, 9), (28, 26, 9, 7), (40, 22, 8, 11)):
        sack = ((gx + .5 - sx - sw / 2) / (sw / 2)) ** 2 + ((gy + .5 - sy) / 5.5) ** 2 + ((gz + .5 - sh / 2) / (sh / 2)) ** 2 < 1
        v.fill(sack & (v.m == 0), hp, 0.9)
    v.box(8, 14, 0, 12, 18, 7, st)
    v.render('tent', contrast=3.2)


def burnt_stall():
    """불탄 좌판: 숯이 된 기둥 둘은 꺾이고, 천막은 찢어져 한쪽만 늘어졌다. 바닥에 재 무더기와 잉걸불. 56 x 22 x 40."""
    X, Y, Z = 56, 22, 40
    v = Vox(X, Y, Z)
    ch, cl, ash, st = v.mat(CHAR), v.mat(Mat(['#0a0c18', '#10142a', '#181e3c', '#222c56'])), v.mat(ASH), v.mat(STONE)
    em = v.mat(EMBER)
    gx, gy, gz = v.grid()
    rng = np.random.default_rng(11)
    for (px, py, h) in ((4, 4, 34), (50, 4, 14), (4, 16, 26), (50, 16, 9)):     # 기둥: 둘은 부러짐
        v.box(px, py, 0, px + 3, py + 3, h, ch)
        v.tone[px:px + 3, py:py + 3, 0:h] = rng.random((3, 3, h)) * 1.2 - 0.8
    v.box(3, 3, 12, 30, 20, 15, ch)                                              # 내려앉은 상판 반쪽
    v.tone[3:30, 3:20, 12:15] = -0.5
    v.box(30, 8, 3, 54, 19, 6, ch)                                               # 쓰러진 판자
    hole = noise3((X, Y, Z), 4, 3) > 0.52
    for y in range(0, 14):                                                       # 찢어진 천막: 왼쪽 위만 구멍 난 채 걸려 있다
        z = 33 - int(y * 0.9)
        seg = np.zeros((X, Y, Z), bool); seg[0:24, y + 4, z] = True
        v.fill(seg & ~hole, cl, -0.6)
    for x in range(1, 24, 5):                                                    # 너덜한 끝
        v.box(x, 17, 17 + (x * 7) % 8, x + 2, 18, 24, cl)
    for (cx, cy, r) in ((34, 11, 7), (14, 15, 5), (44, 6, 4)):                    # 재 무더기
        d = np.sqrt((gx + .5 - cx) ** 2 + ((gy + .5 - cy) * 1.4) ** 2 + (gz * 1.6) ** 2)
        v.fill((d < r) & (v.m == 0), ash, rng.random() * 0.8 - 0.3)
    for (cx, cy) in ((33, 10), (36, 12), (15, 15), (44, 6), (38, 15), (9, 11), (47, 16)):   # 잉걸불
        v.box(cx, cy, 3, cx + 2, cy + 2, 6, em)
    v.box(48, 17, 14, 52, 20, 18, ch)                                            # 꺾인 기둥 윗토막(바닥에 걸쳐)
    v.fill((np.sqrt((gx - 22) ** 2 + (gy - 12) ** 2) < 3.4) & (gz < 7) & (gz > 1), st, 0.2)      # 깨진 항아리
    v.render('burnt_stall', contrast=3.0)


def sansingak():
    """산신각: 돌 기단 위 한 칸 맞배지붕. 판문 안쪽에서 촛불이 새어 나온다. 88 x 52 x 64."""
    X, Y, Z = 88, 52, 64
    v = Vox(X, Y, Z)
    st, wd, red, tile, paper, glow = v.mat(STONE), v.mat(WOOD), v.mat(REDWOOD), v.mat(GIWA), v.mat(PAPER), v.mat(GLOW)
    gx, gy, gz = v.grid()
    cx = X / 2
    v.box(6, 10, 0, X - 6, Y - 2, 7, st)                                          # 기단
    v.tone[6:X - 6, 10:Y - 2, 0:7] = noise3((X - 12, Y - 12, 7), 4, 3) * 0.3 + np.where((np.arange(X - 12) % 12 == 0)[:, None, None], -0.7, 0.2)
    v.box(int(cx) - 8, Y - 2, 0, int(cx) + 8, Y + 0, 7, st) if False else None
    yw = 24
    v.box(14, yw, 7, X - 14, yw + 3, 36, wd)                                      # 뒷벽/문벽
    v.tone[14:X - 14, yw:yw + 3, 7:36] = -0.5
    d0, d1 = int(cx) - 9, int(cx) + 9
    for x in range(d0, d1):                                                       # 판문 + 촛불 틈
        for z in range(9, 33):
            slit = (z in range(15, 25)) and (d0 + 7 <= x <= d0 + 10)
            v.m[x, yw + 3, z] = glow if slit else wd
            v.tone[x, yw + 3, z] = -1.0 if slit else (0.3 if (x - d0) % 6 == 0 else -0.2)
    for px in (14, X - 18):                                                       # 붉은 기둥(앞)
        v.box(px, Y - 14, 7, px + 4, Y - 10, 37, red)
    v.box(10, Y - 15, 35, X - 10, Y - 9, 40, red)                                  # 창방
    v.tone[10:X - 10, Y - 15:Y - 9, 35:40] = np.where((np.arange(X - 20) // 5 % 3 == 0)[:, None, None], 0.8, -0.3)
    # 맞배지붕: 마루가 가로(x), 앞뒤로 흘러내림, 처마 끝이 살짝 들림
    ridge_y = 30.0
    dy = np.abs(gy + 0.5 - ridge_y) / (ridge_y - 2)
    ux = np.abs(gx + 0.5 - cx) / (X / 2 - 1)
    eave = 38 + 3 * ux ** 3
    top = eave + (52 - eave) * np.clip(1 - dy, 0, 1) ** 0.85
    inside = (gy >= 2) & (gy < Y - 2) & (ux <= 1) & (gz >= eave - 3) & (gz <= top)
    shell = inside & (gz >= top - 3.5)
    v.fill(shell, tile, np.where((gx // 4) % 2 == 0, 0.35, -0.35))
    v.fill(inside & (np.abs(gy + 0.5 - ridge_y) < 2.2) & (gz >= top - 2), st, 0.8)   # 용마루
    v.render('sansingak', contrast=3.2)


ALL = {'rockwall': rockwall, 'tent': tent, 'burnt_stall': burnt_stall, 'sansingak': sansingak}

if __name__ == '__main__':
    vox.OUT.mkdir(parents=True, exist_ok=True)
    for n in (sys.argv[1:] or list(ALL)):
        ALL[n]()
