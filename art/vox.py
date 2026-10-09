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
L = np.array([-0.68, -0.38, 0.62]); L = L / np.linalg.norm(L)  # key light: upper left, high


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

    def render(self, name, contrast=3.6):
        """Vectorised: march every screen pixel's diagonal ray one z-slice at a time."""
        X, Y, Z = self.X, self.Y, self.Z
        f = self.m > 0
        top_vis = f & ~np.concatenate([f[:, :, 1:], np.zeros((X, Y, 1), bool)], axis=2)
        front_vis = f & ~np.concatenate([f[:, 1:, :], np.zeros((X, 1, Z), bool)], axis=1)
        # smooth occupancy for wall / side normals
        occ = f.astype(np.float32)
        for _ in range(4):
            o = occ * 2
            for ax in range(3):
                o = o + np.roll(occ, 1, ax) + np.roll(occ, -1, ax)
            occ = o / 8
        gx = np.roll(occ, -1, 0) - np.roll(occ, 1, 0)
        gy = np.roll(occ, -1, 1) - np.roll(occ, 1, 1)
        gz = np.roll(occ, -1, 2) - np.roll(occ, 1, 2)
        # top surfaces: clean normals from the smoothed height field of each column
        hm = np.where(f.any(axis=2), Z - np.argmax(f[:, :, ::-1], axis=2), 0).astype(np.float32)
        for _ in range(5):
            hm = (np.roll(hm, 1, 0) + np.roll(hm, -1, 0) + np.roll(hm, 1, 1) + np.roll(hm, -1, 1) + hm * 4) / 8
        hdx = (np.roll(hm, -1, 0) - np.roll(hm, 1, 0)) * 0.5
        hdy = (np.roll(hm, -1, 1) - np.roll(hm, 1, 1)) * 0.5

        H = Y + Z
        R = np.arange(H)[:, None] - Z           # world row r = y - z for each screen row
        XX = np.broadcast_to(np.arange(X)[None, :], (H, X))
        hx_ = np.full((H, X), -1); hy_ = np.full((H, X), -1); hz_ = np.full((H, X), -1)
        face = np.zeros((H, X), np.int8)
        done = np.zeros((H, X), bool)
        for z in range(Z - 1, -1, -1):
            for fc, yy, vis in ((0, R + z + 1, top_vis), (1, R + z, front_vis)):
                yy = np.broadcast_to(yy, (H, X))
                ok = (~done) & (yy >= 0) & (yy < Y)
                hitm = np.zeros((H, X), bool)
                hitm[ok] = vis[XX[ok], yy[ok], z]
                hx_[hitm] = XX[hitm]; hy_[hitm] = yy[hitm]; hz_[hitm] = z; face[hitm] = fc
                done |= hitm
        sel = done
        vx, vy, vz = hx_[sel], hy_[sel], hz_[sel]
        fc = face[sel]
        # normals
        nt = np.stack([-hdx[vx, vy], -hdy[vx, vy], np.ones_like(vx, np.float32)], 1)
        nf = -np.stack([gx[vx, vy, vz], gy[vx, vy, vz], gz[vx, vy, vz]], 1)
        nf = nf / (np.linalg.norm(nf, axis=1, keepdims=True) + 1e-6) * 0.6 + np.array([0, 0.4, 0])
        n = np.where(fc[:, None] == 0, nt, nf)
        n = n / np.linalg.norm(n, axis=1, keepdims=True)
        lam = n @ L
        # ambient occlusion from voxels just above / in front
        ao = np.zeros(len(vx), np.float32)
        for dx, dy, dz in ((0, 0, 1), (0, 1, 0), (0, 0, 2), (0, 2, 0), (0, 0, 3)):
            ax_, ay_, az_ = vx + dx, vy + dy, vz + dz
            ok = (ax_ < X) & (ay_ < Y) & (az_ < Z)
            v = np.zeros(len(vx), bool)
            v[ok] = f[ax_[ok], ay_[ok], az_[ok]]
            ao += v
        mi = self.m[vx, vy, vz]
        base = np.array([0.0] + [m.base for m in self.mats[1:]], np.float32)[mi]
        tone = 1.6 + lam * contrast - ao * 0.4 + np.where(fc == 1, 1.0, 0.0) + self.tone[vx, vy, vz] + base + (vz / Z) * 0.7
        img = np.zeros((H, X, 4), np.uint8)
        nimg = np.zeros((H, X, 4), np.uint8)
        gimg = np.zeros((H, X, 4), np.uint8)
        cols = np.zeros((len(vx), 4), np.uint8); cols[:, 3] = 255
        glows = np.zeros((len(vx), 4), np.uint8)
        for k, m in enumerate(self.mats):
            if m is None:
                continue
            idx = mi == k
            if not idx.any():
                continue
            ramp = np.array(m.ramp, np.uint8)
            t = np.clip(np.round(tone[idx]), 0, len(ramp) - 1).astype(int)
            if m.glow:
                t = np.clip(2 + self.tone[vx[idx], vy[idx], vz[idx]].astype(int), 0, len(ramp) - 1)
                glows[idx, :3] = ramp[t]; glows[idx, 3] = 255
            cols[idx, :3] = ramp[t]
        img[sel] = cols
        gimg[sel] = glows
        # screen-space normal: right = +X, up = (0,-1,1)/sqrt2, out = (0,1,1)/sqrt2
        sn = np.stack([n[:, 0], (n[:, 2] - n[:, 1]) * 0.7071, (n[:, 1] + n[:, 2]) * 0.7071], 1)
        sn = sn / np.linalg.norm(sn, axis=1, keepdims=True)
        nimg[sel, :3] = ((sn * 0.5 + 0.5) * 255).astype(np.uint8); nimg[sel, 3] = 255
        # ink: silhouette, and the far side of every depth jump (eaves, posts, steps)
        close = np.full((H, X), -1, np.int32)
        close[sel] = vy + vz
        out = img.copy()
        ink = np.zeros((H, X), bool)
        for dr, dc in ((-1, 0), (1, 0), (0, -1), (0, 1)):
            nb = np.full((H, X), -1, np.int32)
            ys = slice(max(0, dr), H + min(0, dr)); yd = slice(max(0, -dr), H + min(0, -dr))
            xs = slice(max(0, dc), X + min(0, dc)); xd = slice(max(0, -dc), X + min(0, -dc))
            nb[yd, xd] = close[ys, xs]
            ink |= (close < 0) & (nb >= 0)
            ink |= (close >= 0) & (nb >= 0) & (nb - close > 4) & (gimg[:, :, 3] == 0)
        out[ink] = INK + [255]
        rows = np.where(out[:, :, 3].max(axis=1) > 0)[0]
        r0, r1 = rows.min(), rows.max() + 1
        Image.fromarray(out[r0:r1]).save(OUT / f'{name}.png')
        Image.fromarray(nimg[r0:r1]).save(OUT / f'{name}_n.png')
        if gimg[:, :, 3].any():
            Image.fromarray(gimg[r0:r1]).save(OUT / f'{name}_glow.png')
        print(f'{name}: {X}x{r1 - r0}')
        return r1 - r0


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
    top = 40 + 34 * np.clip(1 - r ** 1.7, 0, 1) ** 0.85
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


GRASS = Mat(['#0b1416', '#112022', '#18302e', '#22423a', '#355a46', '#4f7656'])
PINEM = Mat(['#08100e', '#0e1a16', '#152620', '#1e352a', '#2a4836', '#3c5e44'])
REDWOOD = Mat(['#2a0a0e', '#4e1218', '#7a1e20', '#a32e28', '#c8483a', '#e0644a'])


def courses(v, mask, mi, seed, block=(14, 8), relief=True):
    """Dress a solid mask as dry-stone courses: staggered blocks, dark joints, per-block shade,
    and a few blocks pushed out a voxel so the wall face has real relief."""
    rng = np.random.default_rng(seed)
    gx, gy, gz = v.grid()
    row = gz // block[1]
    off = (row * 7) % block[0]
    col = (gx + off) // block[0] + (gy // block[0]) * 101
    bid = row * 1000 + col
    shade = rng.random(int(bid.max()) + 1) * 1.3 - 0.65
    joint = ((gz % block[1]) == 0) | (((gx + off) % block[0]) == 0)
    v.fill(mask, mi)
    v.tone[mask] = shade[bid[mask]] + np.where(joint[mask], -1.8, 0)
    v.tone[mask & ((gz % block[1]) == 1)] += 0.7  # lit upper lip of each course
    return bid


def terrace():
    """석축 terrace: front wall with a stair cut into it, plus the east wall running back."""
    FOOT, W, HGT, T = 150, 250, 36, 8
    X, Y, Z = W, FOOT + 2, HGT + 6
    v = Vox(X, Y, Z)
    st, gr = v.mat(STONE), v.mat(GRASS)
    gx, gy, gz = v.grid()
    front = (gx < 248) & (gy >= FOOT - T) & (gy < FOOT) & (gz < HGT)
    east = (gx >= 240) & (gx < 248) & (gy >= HGT) & (gy < FOOT) & (gz < HGT)
    bid = courses(v, front | east, st, 7)
    rng = np.random.default_rng(3)
    push = rng.random(int(bid.max()) + 1) > 0.8
    out_front = (gx < 248) & (gy == FOOT) & (gz < HGT - 2) & push[np.clip(bid, 0, len(push) - 1)] & ((gz % 8) != 0)
    v.fill(out_front, st, 0.4)
    # grass lip spilling over the coping
    lip = (front | east) & (gz >= HGT - 2)
    v.fill(lip, gr, (np.random.default_rng(5).random((X, Y, Z)) * 1.2).astype(np.float32))
    hang = (gx < 248) & (gy == FOOT - 1 + 1) & (gz >= HGT - 4) & (gz < HGT - 2) & (np.random.default_rng(6).random((X, Y, Z)) > 0.55)
    v.fill(hang, gr, -0.5)
    # stone stair cut into the wall
    v.m[152:184, FOOT - 48:FOOT + 1, :] = 0
    for k in range(6):
        y1 = FOOT + 1 - k * 7
        v.box(152, y1 - 7, 0, 184, y1, (k + 1) * 6, st)
        v.tone[152:184, y1 - 7:y1, (k + 1) * 6 - 1] = 1.0
    v.render('terrace', contrast=3.0)


def lantern():
    """석등: plinth, lotus base, shaft, fire chamber with glowing windows, flared roof, jewel finial."""
    X, Y, Z = 24, 24, 50
    v = Vox(X, Y, Z)
    st, gl = v.mat(STONE), v.mat(GLOW)
    gx, gy, gz = v.grid()
    cx, cy = 12, 12
    d = np.sqrt((gx + 0.5 - cx) ** 2 + (gy + 0.5 - cy) ** 2)
    v.fill((np.abs(gx + 0.5 - cx) < 9) & (np.abs(gy + 0.5 - cy) < 8) & (gz < 4), st, -0.2)
    v.fill((d < 6.5 - (gz - 4) * 0.5) & (gz >= 4) & (gz < 8), st, 0.3)   # lotus base
    v.fill((d < 2.6) & (gz >= 8) & (gz < 24), st)                       # shaft
    v.fill((d < 6) & (gz >= 24) & (gz < 26), st, 0.4)                  # chamber floor
    box = (np.abs(gx + 0.5 - cx) < 5.5) & (np.abs(gy + 0.5 - cy) < 4.5) & (gz >= 26) & (gz < 36)
    v.fill(box, st)
    win = box & (np.abs(gx + 0.5 - cx) < 4) & (gz >= 27) & (gz < 35)
    v.fill(win & (gy >= cy + 3), gl, 1)                                 # front window
    v.fill(win & (np.abs(gx + 0.5 - cx) < 0.6), st)                    # mullion
    for zz in range(36, 44):                                            # flared roof
        half = 9 - (zz - 36) * 1.1 + (1.2 if zz < 38 else 0)
        v.fill((np.abs(gx + 0.5 - cx) < half) & (np.abs(gy + 0.5 - cy) < half * 0.85) & (gz == zz), st, 0.3 if zz < 38 else 0)
    v.fill((d < 1.8) & (gz >= 44) & (gz < 48), st, 0.6)
    v.render('lantern', contrast=3.4)


def jangseung(name, red):
    """장승: a carved pole taller than a man; the top third is one huge fierce face under a tall 관모."""
    X, Y, Z = 22, 22, 84
    v = Vox(X, Y, Z)
    wd = v.mat(REDWOOD if red else WOOD)
    pole = v.mat(WOOD)
    hat = v.mat(Mat(['#0c0a10', '#17141e', '#24202e', '#353044', '#4a4560']))
    pw, ink = v.mat(PAPER), v.mat(Mat(['#07060b', '#07060b', '#0e0a10']))
    gx, gy, gz = v.grid()
    cx, cy = 11, 11
    d = np.sqrt((gx + 0.5 - cx) ** 2 + (gy + 0.5 - cy) ** 2)
    v.fill((d < 5) & (gz < 50), pole, (np.sin(gz * 0.9 + gx) * 0.4).astype(np.float32))
    head = (d < 7.2) & (gz >= 46) & (gz < 72)
    v.fill(head, wd)
    v.fill((d < 8.5) & (gz >= 72) & (gz < 74), hat)          # brim
    v.fill((d < 5.2) & (gz >= 74) & (gz < 79), hat, 0.5)     # 관모 crown

    def face(x0, x1, z0, z1, m, t=0.0):
        # carve onto the frontmost surface voxel of each (x, z) column of the round head
        for x in range(x0, x1):
            for z in range(z0, z1):
                ys = np.nonzero(v.m[x, :, z])[0]
                if len(ys):
                    v.m[x, ys.max(), z] = m
                    v.tone[x, ys.max(), z] = t
    face(4, 10, 62, 67, pw, 1); face(12, 18, 62, 67, pw, 1)   # huge staring eyes
    face(6, 9, 63, 66, ink); face(13, 16, 63, 66, ink)
    face(3, 10, 68, 70, ink); face(12, 19, 68, 70, ink)       # brows slashing up
    face(10, 12, 56, 62, wd, 1.4)                             # long nose ridge
    face(9, 13, 55, 57, wd, 0.6)
    face(4, 18, 50, 53, ink)                                  # wide grimace
    face(4, 6, 48, 54, pw, 1.2); face(16, 18, 48, 54, pw, 1.2)  # fangs
    face(8, 14, 52, 53, pw, 0.6)                              # teeth
    groove = (gy >= cy + 4) & (d < 5) & (gz < 44) & (gz > 6) & ((gz % 5) < 2) & (np.abs(gx + 0.5 - cx) < 1.6)
    v.tone[groove] -= 1.6
    v.render(name, contrast=3.2)


def dodam(name, length):
    """돌담: rounded field stones stacked dry, grass growing along the top."""
    X, Y, Z = length + 4, 16, 24
    v = Vox(X, Y, Z)
    st, gr = v.mat(STONE), v.mat(GRASS)
    gx, gy, gz = v.grid()
    rng = np.random.default_rng(length)
    z = 0
    while z < 18:
        x = -rng.integers(0, 6)
        while x < length:
            rx, rz = rng.integers(4, 7), rng.integers(3, 5)
            cxs, czs = x + rx + 2, z + rz
            blob = (((gx + 0.5 - cxs) / rx) ** 2 + ((gy + 0.5 - 8) / 5.5) ** 2 + ((gz + 0.5 - czs) / rz) ** 2) < 1
            v.fill(blob & (v.m == 0), st, float(rng.random() * 1.2 - 0.4))
            x += rx * 2 - 1
        z += 6
    top = (v.m > 0) & (gz >= 17)
    v.fill(top & (np.random.default_rng(2).random((X, Y, Z)) > 0.35), gr, 0.5)
    v.render(name, contrast=3.4)


def board():
    """의뢰 게시판: two posts, a little tiled roof, a board pinned with paper notices and red seals."""
    X, Y, Z = 40, 14, 44
    v = Vox(X, Y, Z)
    wd, pp, rd, st = v.mat(WOOD), v.mat(PAPER), v.mat(RED), v.mat(STONE)
    v.box(5, 6, 0, 9, 10, 40, wd); v.box(31, 6, 0, 35, 10, 40, wd)
    v.box(4, 7, 14, 36, 10, 36, wd)
    v.tone[4:36, 7:10, 14:36] = -0.4
    for (x0, z0, w, h) in ((7, 18, 8, 12), (17, 20, 7, 10), (26, 17, 8, 13)):
        v.box(x0, 10, z0, x0 + w, 11, z0 + h, pp)
        v.tone[x0:x0 + w, 10, z0:z0 + h] = np.where((np.arange(z0, z0 + h) % 3 == 0)[None, :], -1.2, 0.3)
        v.box(x0 + w - 3, 10, z0 + 1, x0 + w - 1, 11, z0 + 3, rd)
    v.box(2, 4, 38, 38, 12, 41, st)   # roof slab
    v.box(4, 6, 41, 36, 10, 43, st)
    v.tone[2:38, 4:12, 38:41] = 0.5
    v.render('board', contrast=3.2)


def stall():
    """약방 노점: a low table under an indigo cloth awning, jars and herb bundles on top."""
    X, Y, Z = 56, 22, 46
    v = Vox(X, Y, Z)
    wd = v.mat(WOOD)
    cloth = v.mat(Mat(['#0c1026', '#141a3a', '#1e2854', '#2c3a74', '#3e4e92', '#56669e']))
    jar, herb, gold = v.mat(STONE), v.mat(GRASS), v.mat(Mat(['#4a3418', '#8a6a30', '#c9a24a', '#f0d488']))
    gx, gy, gz = v.grid()
    for (px, py) in ((4, 4), (50, 4), (4, 16), (50, 16)):
        v.box(px, py, 0, px + 3, py + 3, 36 if py == 4 else 30, wd)
    v.box(3, 3, 14, 53, 20, 18, wd)                              # table top
    v.tone[3:53, 3:20, 17] = 0.8
    for (cx, cy) in ((10, 10), (20, 12), (40, 10)):              # jars
        d = np.sqrt((gx + 0.5 - cx) ** 2 + (gy + 0.5 - cy) ** 2)
        v.fill((d < 3.4 - np.abs(gz - 22) * 0.15) & (gz >= 18) & (gz < 26), jar)
    v.box(28, 8, 18, 34, 13, 22, herb); v.box(45, 12, 18, 49, 16, 21, gold)
    # sagging awning: higher at the back
    for y in range(0, 22):
        z = 38 - int(y * 0.35)
        v.box(0, y, z, 56, y + 1, z + 2, cloth)
        v.tone[0:56, y, z:z + 2] = np.where((np.arange(56) // 7) % 2 == 0, 0.4, -0.3)[:, None]
    for x in range(0, 56, 4):                                    # scalloped front edge
        v.box(x, 21, 29, x + 2, 22, 31, cloth)
    v.render('stall', contrast=3.2)


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    house(); terrace(); lantern(); jangseung('jangseung_m', False); jangseung('jangseung_f', True)
    dodam('dodam', 64); board(); stall()


if __name__ == '__main__':
    main()
