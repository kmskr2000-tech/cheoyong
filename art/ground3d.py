"""Bake a whole level's tiered ground with the same oblique camera as the voxel props.

The level is a height map of 16px cells (0 pond, 1 village floor, 2 raised terrace, 3 rocky ridge,
S/T stone stairs). Columns are drawn back to front (painter's algorithm): each column's top face lands
on screen row y-h and its front face fills the rows below it, so every tier shows a lit top plane and a
shaded cliff face — masonry (석축) for the terrace, rough strata for natural ridges and pond banks.
Top faces reuse the hand-dotted ground textures of tiles.py; lighting shifts the ramp index, so the
palette stays pixel-art. Outputs (godot/assets/levels/): <id>.png, <id>_n.png, <id>_water.png and
<id>.json (screen offset, tier size, height rows, collision rectangles in screen space).
"""
import importlib.util, json, pathlib
import numpy as np
from PIL import Image

ROOT = pathlib.Path(__file__).parent
OUT = ROOT.parent / 'godot' / 'assets' / 'levels'
spec = importlib.util.spec_from_file_location('tiles', ROOT / 'tiles.py')
tiles = importlib.util.module_from_spec(spec); spec.loader.exec_module(tiles)

TS, TIER = 16, 22
INK = np.array(tiles.INK, np.uint8)
L = np.array([-0.68, -0.38, 0.62]); L /= np.linalg.norm(L)

ROCK = np.array([tiles.hx(c) for c in ('#0e0b10', '#1a1519', '#282024', '#382c2e', '#4a3c3a', '#5e4e48')], np.uint8)
MASON = np.array([tiles.hx(c) for c in ('#0f0f16', '#1a1b25', '#262836', '#353849', '#474b5e', '#5e6378')], np.uint8)


def vnoise(shape, cell, seed):
    rng = np.random.default_rng(seed)
    gh, gw = shape[0] // cell + 2, shape[1] // cell + 2
    lat = rng.random((gh, gw))
    y = np.arange(shape[0])[:, None] / cell; x = np.arange(shape[1])[None, :] / cell
    y0, x0 = np.floor(y).astype(int), np.floor(x).astype(int)
    ty, tx = y - y0, x - x0
    ty, tx = ty * ty * (3 - 2 * ty), tx * tx * (3 - 2 * tx)
    a = lat[y0, x0]; b = lat[y0, x0 + 1]; c = lat[y0 + 1, x0]; d = lat[y0 + 1, x0 + 1]
    return a + (b - a) * tx + (c - a) * ty + (a - b - c + d) * tx * ty


def bake(level_id, hmap, vmap, stairs, water_z=TIER - 9, foam=False):
    """hmap: rows of cell chars; vmap: rows of vertex chars (',' grass '.' dirt '#' stone);
    stairs: {char: (low_tier, high_tier, y_top_px, y_bottom_px)} — stairs rise toward the north."""
    rows, cols = len(hmap), len(hmap[0])
    W, Hf = cols * TS, rows * TS
    cells = np.array([list(r) for r in hmap])
    yy, xx = np.mgrid[0:Hf, 0:W]
    # natural tiers get ragged edges; masonry and stairs stay straight
    jx = ((vnoise((Hf, W), 9, 1) - 0.5) * 14 + (vnoise((Hf, W), 3, 3) - 0.5) * 4).astype(int)
    jy = ((vnoise((Hf, W), 9, 2) - 0.5) * 14 + (vnoise((Hf, W), 3, 4) - 0.5) * 4).astype(int)
    straight = cells[yy // TS, xx // TS]
    jit = cells[np.clip((yy + jy) // TS, 0, rows - 1), np.clip((xx + jx) // TS, 0, cols - 1)]
    keep = np.isin(straight, list('2S' + ''.join(stairs))) | np.isin(jit, list('2S' + ''.join(stairs)))
    ch = np.where(keep, straight, jit)
    tier = np.zeros((Hf, W), np.float32)
    for c, t in (('0', 0), ('1', 1), ('2', 2), ('3', 3)):
        tier[ch == c] = t
    h = tier * TIER
    is_stair = np.zeros((Hf, W), bool)
    for c, (lo, hi, y0, y1) in stairs.items():
        m = ch == c
        steps = max(2, round((hi - lo) * TIER / 4))
        p = np.clip((y1 - yy) / (y1 - y0), 0, 0.999)
        h[m] = (lo + (hi - lo) * np.floor(p[m] * steps) / steps) * TIER + TIER * (hi - lo) / steps
        is_stair |= m
    water = ch == '0'
    h = np.round(h).astype(int)
    hs = np.where(water, water_z, h)  # rendered surface height
    OFF = int(hs.max()) + 4

    # ---- painter's pass: back to front
    Hs = Hf + OFF
    kind = np.zeros((Hs, W), np.int8)  # 1 top, 2 front, 3 water
    wx = np.zeros((Hs, W), np.int32); wy = np.zeros((Hs, W), np.int32); wz = np.zeros((Hs, W), np.int32)
    colh = np.zeros((Hs, W), np.int32)
    X = np.arange(W)
    for y in range(Hf):
        hrow = hs[y]
        for z in range(int(hrow.max())):  # front face rows of this column
            sel = hrow > z
            r = y - z + OFF
            kind[r, X[sel]] = 2; wx[r, X[sel]] = X[sel]; wy[r, X[sel]] = y; wz[r, X[sel]] = z; colh[r, X[sel]] = hrow[sel]
        r = y - hrow + OFF
        k = np.where(water[y], 3, 1)
        kind[r, X] = k; wx[r, X] = X; wy[r, X] = y; wz[r, X] = hrow; colh[r, X] = hrow

    # ---- top surface materials from the vertex map (same corner logic as tiles.py, per pixel)
    vm = np.array([list(r) for r in vmap])
    def layer(chars):
        cv = np.isin(vm, list(chars)).astype(np.float32)
        i0 = np.clip(yy // TS, 0, rows - 1); j0 = np.clip(xx // TS, 0, cols - 1)
        fu = (xx % TS + 0.5) / TS; fv = (yy % TS + 0.5) / TS
        f = (cv[i0, j0] * (1 - fu) * (1 - fv) + cv[i0, j0 + 1] * fu * (1 - fv) + cv[i0 + 1, j0] * (1 - fu) * fv + cv[i0 + 1, j0 + 1] * fu * fv)
        return f + (vnoise((Hf, W), 4, 9) - 0.5) * 0.36 >= 0.5
    grass = layer(','); stone = layer('#'); sand = layer('~')
    mat = np.where(stone, 2, np.where(grass, 1, np.where(sand, 3, 0)))  # 0 dirt, 1 grass, 2 stone, 3 sand
    texs = {k: np.array(tiles.tone_texture(k, s), np.float32) for k, s in (('dirt', 11), ('grass', 31), ('stone', 23), ('water', 5), ('sand', 41))}
    pals = {k: np.array(tiles.PAL[k], np.uint8) for k in ('dirt', 'grass', 'stone', 'water', 'sand')}
    MATS = ((0, 'dirt'), (1, 'grass'), (2, 'stone'), (3, 'sand'))

    # geometric normals of the top surface from the smoothed height field
    hb = h.astype(np.float32)
    for _ in range(3):
        hb = (np.roll(hb, 1, 0) + np.roll(hb, -1, 0) + np.roll(hb, 1, 1) + np.roll(hb, -1, 1) + hb * 4) / 8
    dhx = (np.roll(hb, -1, 1) - np.roll(hb, 1, 1)) * 0.5
    dhy = (np.roll(hb, -1, 0) - np.roll(hb, 1, 0)) * 0.5
    nt = np.stack([-dhx, -dhy, np.ones_like(dhx)], -1); nt /= np.linalg.norm(nt, axis=-1, keepdims=True)
    lam_top = nt @ L
    lam0 = L[2]

    img = np.zeros((Hs, W, 4), np.uint8); img[..., 3] = 255
    nimg = np.zeros((Hs, W, 4), np.uint8); nimg[..., 3] = 255
    wimg = np.zeros((Hs, W, 4), np.uint8)
    T = kind == 1
    tx_, ty_ = wx[T], wy[T]
    mt = mat[ty_, tx_]
    tone = np.zeros(len(tx_), np.float32)
    for mi, name in MATS:
        s = mt == mi
        tv = texs[name][ty_[s] % 128, tx_[s] % 128]
        tone[s] = np.where(tv == -9, -9, tv)
    light = (lam_top[ty_, tx_] - lam0) * 3.0
    # cliff-foot shadow: ground right below a higher column is in its shade; lit lip on top edges
    foot = np.zeros(len(tx_), np.float32)
    for k in range(1, 7):
        foot = np.maximum(foot, (h[np.clip(ty_ - k, 0, Hf - 1), tx_] > h[ty_, tx_] + 2) * (1.6 - k * 0.2))
    lip = (h[np.clip(ty_ + 1, 0, Hf - 1), tx_] < h[ty_, tx_] - 2) * 1.8 + (h[ty_, np.clip(tx_ - 1, 0, W - 1)] < h[ty_, tx_] - 2) * 0.8
    lip -= (h[ty_, np.clip(tx_ + 1, 0, W - 1)] < h[ty_, tx_] - 2) * 0.6
    stair = is_stair[ty_, tx_]
    if foam:
        wet = np.zeros(len(tx_), np.float32)
        for k in range(1, 12):
            wet = np.maximum(wet, water[np.clip(ty_ + k, 0, Hf - 1), tx_] * (1.4 - k * 0.11))
        light = light - wet
    cols = np.zeros((len(tx_), 3), np.uint8)
    for mi, name in MATS:
        s = (mt == mi) & ~stair
        t = np.clip(np.round(tone[s] + light[s] - foot[s] + lip[s]), 0, len(pals[name]) - 1).astype(int)
        joint = tone[s] == -9
        c = pals[name][t]
        c[joint] = tiles.PAL['moss'][1] if name == 'stone' else c[joint]
        cols[s] = c
    if stair.any():  # stair treads: dressed stone, lit
        s = stair
        t = np.clip(np.round(3.2 + light[s] - foot[s] * 0.5), 0, 5).astype(int)
        cols[s] = MASON[t]
    img[T, :3] = cols
    # grass edge: ink rim where grass meets bare ground, and the shadow it casts downward
    g = (kind == 1) & (mat[wy, wx] == 1)
    below = np.zeros_like(g); below[1:] = g[:-1]
    rim = (kind == 1) & ~g & below
    img[rim, :3] = INK

    # ---- cliff faces
    F = kind == 2
    fx, fy, fz, fh = wx[F], wy[F], wz[F], colh[F]
    fstair = is_stair[fy, fx]
    mason = (np.isin(ch[fy, fx], ['2'])) | fstair
    rel = fz.astype(np.float32) / np.maximum(fh, 1)
    # masonry: staggered courses; rock: horizontal strata with cracks
    course = fz // 7
    bid = course * 997 + (fx + (course * 7) % 13) // 15
    rng = np.random.default_rng(4)
    bsh = rng.random(int(bid.max()) + 1) * 1.2 - 0.6
    mjoint = ((fz % 7) == 0) | (((fx + (course * 7) % 13) % 15) == 0)
    strata = vnoise((Hs, W), 6, 13)[fz + OFF, fx] * 1.4 + np.sin(fz * 0.9 + vnoise((Hs, W), 9, 14)[fz, fx] * 6) * 0.4
    crack = vnoise((Hs, W), 3, 15)[fy % Hs, fx] > 0.78
    ftone = np.where(mason, 3.0 + bsh[bid] - mjoint * 1.8 + ((fz % 7) == 6) * 0.6, 2.7 + strata - crack * 1.4)
    ftone += rel * 0.9 - 0.4  # darker at the foot, catching light near the top
    fcol = np.where(mason[:, None], MASON[np.clip(np.round(ftone), 0, 5).astype(int)], ROCK[np.clip(np.round(ftone), 0, 5).astype(int)])
    # grass hanging over the lip of grassy tops
    hang = (mat[np.clip(fy, 0, Hf - 1), fx] == 1) & (fh - fz <= 1 + (vnoise((Hs, W), 2, 16)[fy % Hs, fx] * 4).astype(int)) & ~fstair
    fcol[hang] = np.array(tiles.PAL['grass'])[np.clip(3 - (fh - fz)[hang], 1, 4)]
    img[F, :3] = fcol

    # ---- water
    Wt = kind == 3
    wt = texs['water'][wy[Wt] % 128, wx[Wt] % 128]
    bank = np.zeros(Wt.sum(), np.float32)
    for k in range(1, 5):
        bank += (~water[np.clip(wy[Wt] - k, 0, Hf - 1), wx[Wt]]) * 0.5
    img[Wt, :3] = pals['water'][np.clip(np.round(wt - bank), 0, 5).astype(int)]
    if foam:  # surf line: broken foam just off the beach, a second fainter line further out
        wyy, wxx = wy[Wt], wx[Wt]
        dist = np.full(Wt.sum(), 99)
        for k in range(1, 14):
            land = ~water[np.clip(wyy - k, 0, Hf - 1), wxx]
            dist = np.where((dist == 99) & land, k, dist)
        brk = vnoise((Hf, W), 5, 21)[wyy, wxx]
        f1 = (dist <= 2) & (brk > 0.3)
        f2 = (dist >= 7) & (dist <= 8) & (brk > 0.55)
        fc = np.array(tiles.PAL['foam'], np.uint8)
        cur = img[Wt, :3]
        cur[f1] = fc
        cur[f2] = (fc.astype(int) * 2 // 3 + pals['water'][4].astype(int) // 3).astype(np.uint8)
        img[Wt, :3] = cur
    wimg[Wt] = [255, 255, 255, 255]

    # ---- ink where depth jumps (cliff tops against what lies behind/below them)
    close = np.where(kind > 0, wy + wz, -1)
    ink = np.zeros((Hs, W), bool)
    for dr, dc in ((-1, 0), (1, 0), (0, -1), (0, 1)):
        nb = np.roll(np.roll(close, dr, 0), dc, 1)
        ink |= (close >= 0) & (nb - close > 3)
    img[ink, :3] = INK

    # ---- normal map (screen space): tops from geometry + a little texture relief, faces look south
    lum = img[..., :3].astype(np.float32).mean(-1) / 255
    rx = (np.roll(lum, -1, 1) - np.roll(lum, 1, 1)) * 2.0
    ry = (np.roll(lum, -1, 0) - np.roll(lum, 1, 0)) * 2.0
    n = np.zeros((Hs, W, 3), np.float32)
    n[T] = nt[wy[T], wx[T]]
    n[F] = np.array([0, 1.0, 0])
    n[Wt] = np.array([0, 0, 1.0])
    sn = np.stack([n[..., 0] - rx * 0.5, (n[..., 2] - n[..., 1]) * 0.7071 + ry * 0.5, (n[..., 1] + n[..., 2]) * 0.7071], -1)
    sn /= np.linalg.norm(sn, axis=-1, keepdims=True) + 1e-6
    nimg[..., :3] = ((sn * 0.5 + 0.5) * 255).astype(np.uint8)

    # ---- collision: cliff faces (not stairs) and water, merged into rectangles on a 4px grid
    blocked = ((kind == 2) & ~is_stair[wy, wx]) | (kind == 3)
    G = 4
    gh, gw = Hs // G, W // G
    bg = blocked[:gh * G, :gw * G].reshape(gh, G, gw, G).mean((1, 3)) > 0.5
    rects = []
    open_runs = {}
    for r in range(gh):
        runs = []
        c = 0
        while c < gw:
            if bg[r, c]:
                c0 = c
                while c < gw and bg[r, c]:
                    c += 1
                runs.append((c0, c))
            c += 1
        new_open = {}
        for run in runs:
            if run in open_runs:
                new_open[run] = open_runs[run]
            else:
                new_open[run] = r
        for run, r0 in open_runs.items():
            if run not in new_open:
                rects.append([run[0] * G, r0 * G - OFF, (run[1] - run[0]) * G, (r - r0) * G])
        open_runs = new_open
    for run, r0 in open_runs.items():
        rects.append([run[0] * G, r0 * G - OFF, (run[1] - run[0]) * G, (gh - r0) * G])

    OUT.mkdir(parents=True, exist_ok=True)
    Image.fromarray(img).save(OUT / f'{level_id}.png')
    Image.fromarray(nimg).save(OUT / f'{level_id}_n.png')
    Image.fromarray(wimg).save(OUT / f'{level_id}_water.png')
    meta = {'offset': OFF, 'tier': TIER, 'ts': TS, 'size': [W, Hf], 'heights': [''.join(r) for r in hmap], 'collision': rects}
    (OUT / f'{level_id}.json').write_text(json.dumps(meta))
    print(f'{level_id}: {W}x{Hs}, {len(rects)} collision rects')


# ---------------------------------------------------------------- 경주 변두리 (test corner)
VILLAGE_H = [
    '2' * 29 + '3' * 11,                       # the north edge is a raised bank all along
    '2' * 29 + '3' * 11,
    '2222222222222222111111111111133333333333',
    '2222222222222222111111111111333333333333',
    '2222222222222222111111111111333333333333',
    '2222222222222222' + '1' * 17 + 'TT' + '1' * 5,
    '2222222222222222' + '1' * 17 + 'TT' + '1' * 5,
    '1' * 9 + 'SS' + '1' * 22 + 'TT' + '1' * 5,
    '1' * 9 + 'SS' + '1' * 29,
    '1' * 40, '1' * 40, '1' * 40, '1' * 40,
    '1110000111' + '1' * 30,
    '1100000011' + '1' * 30,
    '1000000001' + '1' * 30,
    '1000000001' + '1' * 30,
    '1100000011' + '1' * 30,
    '1110000111' + '1' * 30,
    '1' * 40, '1' * 40, '1' * 40, '1' * 40,
]


def village_vmap():
    vm = [[','] * 41 for _ in range(24)]
    def paint(x0, y0, x1, y1, c):
        for y in range(y0, y1 + 1):
            for x in range(x0, x1 + 1):
                vm[y][x] = c
    paint(9, 6, 11, 10, '.')     # from the terrace stair down to the plaza
    paint(4, 3, 12, 6, '.')      # yard in front of the house
    paint(11, 9, 18, 11, '.')
    paint(18, 8, 27, 14, '#')    # stone plaza (박석)
    paint(27, 10, 40, 12, '.')   # east road
    paint(32, 4, 35, 10, '.')    # up to the ridge stair
    paint(19, 14, 21, 23, '.')   # south road
    paint(30, 0, 40, 3, '.')     # bare rock on the ridge
    return [''.join(r) for r in vm]


# ---------------------------------------------------------------- 개운포 (백사장과 해안 마을) — SC1-01~07
def beach_hmap():
    import math
    rows = []
    for y in range(26):
        r = []
        for x in range(40):
            shore = 17.6 + math.sin(x * 0.31) * 1.3 + math.sin(x * 0.11 + 1.0) * 1.1 - (2 if x < 6 else 0)
            if y <= 7:
                c = '3' if x < 4 or (x > 35 and y < 4) else '2'
            elif y <= 9 and x in (20, 21):
                c = 'S'
            elif y >= shore:
                c = '0'
            elif (y, x) in {(11, 31), (11, 32), (12, 31), (12, 32), (12, 33), (14, 3), (14, 4), (15, 4), (9, 0), (10, 0), (9, 1)}:
                c = '3'  # 갯바위
            else:
                c = '1'
            r.append(c)
        rows.append(''.join(r))
    return rows


def beach_vmap(hm):
    vm = [['~'] * 41 for _ in range(27)]
    for y in range(27):
        for x in range(41):
            if y <= 8:
                vm[y][x] = ','
    def paint(x0, y0, x1, y1, c):
        for y in range(y0, y1 + 1):
            for x in range(x0, x1 + 1):
                vm[y][x] = c
    paint(4, 5, 36, 8, '.')       # 마을 길 along the terrace front
    paint(19, 2, 23, 8, '.')      # up from the stair into the village
    paint(14, 2, 28, 4, '.')      # 마당
    paint(19, 9, 22, 11, '.')     # trodden path down to the beach
    paint(0, 0, 4, 9, '.')
    return [''.join(r) for r in vm]


def main():
    hb = beach_hmap()
    bake('beach', hb, beach_vmap(hb), {'S': (1, 2, 8 * TS, 10 * TS)}, water_z=TIER - 3, foam=True)
    bake('village', VILLAGE_H, village_vmap(),
         {'S': (1, 2, 7 * TS, 9 * TS), 'T': (1, 3, 5 * TS, 8 * TS)})


if __name__ == '__main__':
    main()
