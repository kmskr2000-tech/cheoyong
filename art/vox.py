"""Voxel → pixel-art renderer for props, so every building shares one true 3/4 camera.

World: X right, Y toward the viewer (south), Z up; 1 voxel = 1 px. Oblique top-down projection
matching the ground tiles: a voxel's top face lands on screen row y-z-1, its front face on row y-z,
so top planes keep their full depth and walls keep their full height (the Zelda / Sea of Stars view).
Per pixel we find the nearest visible face, shade it with a smooth normal (from blurred occupancy),
ambient occlusion and the upper-left key light, quantise to the material's hue-shifted ramp, then add
ink outlines on the silhouette and wherever depth jumps (eaves, door frames).
Outputs <name>.png, <name>_n.png (screen-space normals from the real geometry) and <name>_glow.png.
"""
import math, pathlib
import numpy as np
from PIL import Image

OUT = pathlib.Path(__file__).parent.parent / 'godot' / 'assets' / 'props'


def hx(h):
    h = h.lstrip('#')
    return [int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16)]


INK = hx('#07060b')
L = np.array([-0.55, -0.35, 0.76]); L = L / np.linalg.norm(L)  # key light: upper left, high


class Mat:
    def __init__(self, ramp, glow=False, rough=0.0, base=0.0):
        self.ramp = [hx(c) for c in ramp]
        self.glow, self.rough, self.base = glow, rough, base


class Vox:
    def __init__(self, X, Y, Z):
        self.X, self.Y, self.Z = X, Y, Z
        self.m = np.zeros((X, Y, Z), np.int16)  # 0 = empty, else material index
        self.mats = [None]
        self.tone = np.zeros((X, Y, Z), np.float32)  # per-voxel tone offset (texture, carving)

    def mat(self, m):
        self.mats.append(m)
        return len(self.mats) - 1

    def grid(self):
        return np.meshgrid(np.arange(self.X), np.arange(self.Y), np.arange(self.Z), indexing='ij')

    def fill(self, mask, mi, tone=None):
        self.m[mask] = mi
        if tone is not None:
            self.tone[mask] = tone[mask] if isinstance(tone, np.ndarray) else tone

    def box(self, x0, y0, z0, x1, y1, z1, mi):
        self.m[x0:x1, y0:y1, z0:z1] = mi

    def render(self, name, anchor_y=None):
        X, Y, Z = self.X, self.Y, self.Z
        f = self.m > 0
        top_vis = f & ~np.concatenate([f[:, :, 1:], np.zeros((X, Y, 1), bool)], axis=2)
        front_vis = f & ~np.concatenate([f[:, 1:, :], np.zeros((X, 1, Z), bool)], axis=1)
        # smooth normals from blurred occupancy
        occ = f.astype(np.float32)
        for _ in range(5):
            o = occ.copy()
            for ax in range(3):
                o = (np.roll(o, 1, ax) + o * 2 + np.roll(o, -1, ax)) / 4
            occ = o
        gx = np.roll(occ, -1, 0) - np.roll(occ, 1, 0)
        gy = np.roll(occ, -1, 1) - np.roll(occ, 1, 1)
        gz = np.roll(occ, -1, 2) - np.roll(occ, 1, 2)
        # top surfaces: clean normals from the (smoothed) height field of each column
        hm = np.where(f.any(axis=2), Z - np.argmax(f[:, :, ::-1], axis=2), 0).astype(np.float32)
        for _ in range(2):
            hm = (np.roll(hm, 1, 0) + np.roll(hm, -1, 0) + np.roll(hm, 1, 1) + np.roll(hm, -1, 1) + hm * 4) / 8
        hdx = (np.roll(hm, -1, 0) - np.roll(hm, 1, 0)) * 0.5
        hdy = (np.roll(hm, -1, 1) - np.roll(hm, 1, 1)) * 0.5
        H = Y + Z
        img = np.zeros((H, X, 4), np.uint8)
        nimg = np.zeros((H, X, 4), np.uint8)
        gimg = np.zeros((H, X, 4), np.uint8)
        close = np.full((H, X), -1, np.int32)
        hit = [[None] * X for _ in range(H)]
        for r in range(-Z, Y):
            row = r + Z  # screen row
            for x in range(X):
                for z in range(Z - 1, -1, -1):
                    yt = r + z + 1
                    if 0 <= yt < Y and top_vis[x, yt, z]:
                        hit[row][x] = (x, yt, z, 0); close[row, x] = yt + z; break
                    yf = r + z
                    if 0 <= yf < Y and front_vis[x, yf, z]:
                        hit[row][x] = (x, yf, z, 1); close[row, x] = yf + z; break
        for row in range(H):
            for x in range(X):
                h = hit[row][x]
                if h is None:
                    continue
                vx, vy, vz, face = h
                mat = self.mats[self.m[vx, vy, vz]]
                if face == 0:
                    n = np.array([-hdx[vx, vy], -hdy[vx, vy], 1.0])
                else:
                    n = -np.array([gx[vx, vy, vz], gy[vx, vy, vz], gz[vx, vy, vz]])
                    n = n / (np.linalg.norm(n) + 1e-6) * 0.6 + np.array([0, 0.4, 0])
                n = n / np.linalg.norm(n)
                lam = float(np.dot(n, L))
                # ambient occlusion: crowded neighbourhood above / in front darkens
                ao = 0.0
                for dx, dy, dz in ((0, 0, 1), (0, 1, 0), (0, 0, 2), (0, 2, 0)):
                    ax_, ay_, az_ = vx + dx, vy + dy, vz + dz
                    if 0 <= ax_ < X and 0 <= ay_ < Y and 0 <= az_ < Z and f[ax_, ay_, az_]:
                        ao += 1
                tone = 1.9 + lam * 3.4 - ao * 0.45 + (1.1 if face == 1 else 0) + self.tone[vx, vy, vz] + mat.base
                tone += (vz / Z) * 0.6  # higher parts catch more moonlight
                col = mat.ramp[max(0, min(len(mat.ramp) - 1, int(round(tone))))]
                img[row, x] = col + [255]
                # screen-space normal: right = +X, up = (0,-1,1)/√2, out = (0,1,1)/√2
                sn = np.array([n[0], (n[2] - n[1]) * 0.7071, (n[1] + n[2]) * 0.7071])
                sn = sn / np.linalg.norm(sn)
                nimg[row, x] = [int((sn[0] * 0.5 + 0.5) * 255), int((sn[1] * 0.5 + 0.5) * 255), int((sn[2] * 0.5 + 0.5) * 255), 255]
                if mat.glow:
                    gimg[row, x] = mat.ramp[min(len(mat.ramp) - 1, 2 + int(self.tone[vx, vy, vz]))] + [255]
                    img[row, x] = gimg[row, x]
        # ink: silhouette, and the far side of every depth jump (separates eaves, posts, steps)
        out = img.copy()
        for row in range(H):
            for x in range(X):
                c = close[row, x]
                for dr, dc in ((-1, 0), (1, 0), (0, -1), (0, 1)):
                    rr, cc = row + dr, x + dc
                    if not (0 <= rr < H and 0 <= cc < X):
                        continue
                    c2 = close[rr, cc]
                    if c < 0 and c2 >= 0:
                        out[row, x] = INK + [255]; break
                    if c >= 0 and c2 >= 0 and c2 - c > 4 and not np.any(gimg[row, x]):
                        out[row, x] = INK + [255]; break
        # trim empty rows at the top
        rows = np.where(out[:, :, 3].max(axis=1) > 0)[0]
        r0 = rows.min()
        r1 = anchor_y if anchor_y is not None else rows.max() + 1
        Image.fromarray(out[r0:r1]).save(OUT / f'{name}.png')
        Image.fromarray(nimg[r0:r1]).save(OUT / f'{name}_n.png')
        if gimg[:, :, 3].any():
            Image.fromarray(gimg[r0:r1]).save(OUT / f'{name}_glow.png')
        print(f'{name}: {X}x{r1 - r0}')


def noise3(shape, seed, scale):
    rng = np.random.default_rng(seed)
    small = rng.random(tuple(max(2, s // scale + 2) for s in shape))
    idx = [np.linspace(0, small.shape[i] - 1.001, shape[i]) for i in range(3)]
    I = np.meshgrid(*idx, indexing='ij')
    i0 = [np.floor(a).astype(int) for a in I]
    t = [a - b for a, b in zip(I, i0)]
    out = np.zeros(shape, np.float32)
    for dx in (0, 1):
        for dy in (0, 1):
            for dz in (0, 1):
                w = (t[0] if dx else 1 - t[0]) * (t[1] if dy else 1 - t[1]) * (t[2] if dz else 1 - t[2])
                out += w * small[i0[0] + dx, i0[1] + dy, i0[2] + dz]
    return out


# ---------------------------------------------------------------- models
THATCH = Mat(['#17120d', '#251d13', '#382c19', '#4e3f22', '#66542c', '#82703c', '#9a8650'])
MUD = Mat(['#1c1618', '#2a2224', '#3a2f2c', '#4c3f36', '#605042', '#766450'])
WOOD = Mat(['#140e0d', '#22181a', '#33241f', '#4a3528', '#644a35', '#7e6244'])
STONE = Mat(['#0f0f16', '#1a1b25', '#262836', '#353849', '#474b5e', '#5e6378', '#7a8094'])
GLOW = Mat(['#6a3a1a', '#b86a2a', '#e8a048', '#ffd27a', '#fff2c0'], glow=True)
PAPER = Mat(['#5a5868', '#86848e', '#aeaaa8', '#d0cabc', '#ece6d6'])
RED = Mat(['#2a0a0e', '#4e1218', '#7a1e20', '#a32e28', '#c8483a'])


def house():
    """초가집 at human scale: walls taller than a person (처용 is 44px), a deep low straw roof."""
    X, Y, Z = 128, 88, 76
    v = Vox(X, Y, Z)
    th, mud, wood, stone, glow, paper, red = (v.mat(m) for m in (THATCH, MUD, WOOD, STONE, GLOW, PAPER, RED))
    gx, gy, gz = v.grid()
    cx = X / 2
    # 기단: dressed-stone plinth with a slightly worn top
    v.box(14, 24, 0, X - 14, Y - 6, 6, stone)
    v.tone[14:X - 14, 24:Y - 6, 0:6] = noise3((X - 28, Y - 30, 6), 3, 3) * 1.2 - 0.6
    # 흙벽 body with timber posts proud of the wall
    y0, y1 = 32, Y - 14
    wall_top = 44
    v.box(20, y0, 6, X - 20, y1, wall_top, mud)
    v.tone[20:X - 20, y0:y1, 6:wall_top] = noise3((X - 40, y1 - y0, wall_top - 6), 5, 5) * 1.4 - 0.7
    for px in (20, 44, 82, X - 24):
        v.box(px, y1 - 1, 6, px + 4, y1 + 1, wall_top, wood)
    v.box(20, y1 - 1, 36, X - 20, y1 + 1, 40, wood)  # lintel beam
    v.box(20, y1 - 1, 6, X - 20, y1 + 1, 9, wood)    # sill
    # 창호지 double door (glowing paper between lattice) and a side window
    for x in range(52, 76):
        for z in range(9, 34):
            lattice = (x - 52) % 4 == 0 or (z - 9) % 6 == 0 or x in (63, 64, 75)
            v.m[x, y1, z] = wood if lattice else glow
            v.tone[x, y1, z] = 0 if lattice else (-1 if z < 15 else 0)
    for x in range(88, 100):
        for z in range(20, 30):
            v.m[x, y1, z] = wood if (x - 88) % 4 == 0 or z in (20, 29) else glow
            v.tone[x, y1, z] = -1
    # 부적 by the door
    v.box(46, y1, 18, 49, y1 + 1, 30, paper)
    v.m[46:49, y1, 22:25] = red
    # 초가지붕: thick rounded straw roof, low eaves overhanging the walls, ropes binding it
    rx, ry = 52, 30
    rcy = (y0 + y1) / 2 + 1
    r = (np.abs((gx + 0.5 - cx) / rx) ** 3 + np.abs((gy + 0.5 - rcy) / ry) ** 3) ** (1 / 3)
    top = 40 + 32 * np.clip(1 - r ** 2.6, 0, 1) ** 0.7
    bottom = np.where(r > 0.8, 37 + (r - 0.8) * 6, 41)
    roof = (r <= 1) & (gz >= bottom) & (gz <= top)
    straw = noise3((X, Y, Z), 11, 3) * 0.9 - 0.45
    layers = np.where((gz % 6) == 0, -0.6, 0)  # straw courses
    v.fill(roof, th, straw + layers)
    ropes = roof & (np.abs(gz - top) < 1.5) & ((np.abs(gx + 0.5 - cx - 17) < 0.7) | (np.abs(gx + 0.5 - cx + 17) < 0.7) | (np.abs(gy + 0.5 - rcy) < 0.7))
    v.tone[ropes] = 1.0
    # ragged eave fringe hanging below the lip
    rnd = np.random.default_rng(4)
    edge = (r > 0.94) & (r <= 1.0)
    hang = edge & (gz >= bottom - rnd.integers(1, 5, edge.shape)) & (gz < bottom)
    v.fill(hang, th, -0.5)
    v.render('house')


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    house()


if __name__ == '__main__':
    main()
