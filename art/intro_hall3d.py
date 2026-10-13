"""용궁 정전(正殿) — 인트로 샷 2~3의 배경을 작은 원근 3D 장면으로 그린다 (480x270).

A tiny ray tracer in numpy: the camera stands behind the three sons and looks down the hall to
the sick-bed dais. Receding rows of lacquered pillars with gold bands and a coiling dragon, a
coffered ceiling in muted 단청, a polished jade floor that mirrors the pillars and carries the
water's caustics, a painted screen of waves and the pearl behind the dais, lattice windows glowing
sea-blue on both sides, pearl lanterns, light shafts from the water far above, depth fog.
Each material is shaded then dithered onto its own ramp, so it stays pixel art.
"""
import math
import numpy as np

W, H = 480, 270
BAYER = np.array([[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5]]) / 16.0


def hx(h):
    h = h.lstrip('#'); return np.array([int(h[i:i + 2], 16) for i in (0, 2, 4)], np.float32)


def ramp(*cs):
    return np.stack([hx(c) for c in cs])


RAMPS = {
    'floor':   ramp('#03080c', '#06121a', '#0a1e26', '#102c34', '#183c44', '#245058', '#36686e'),
    'inlay':   ramp('#1a1408', '#33260e', '#5a4418', '#86682a', '#b4924a'),
    'pillar':  ramp('#10060a', '#1c0a10', '#2c1016', '#3e181c', '#522424', '#683430', '#7c463e'),
    'gold':    ramp('#2a1e0a', '#4a3612', '#6e5220', '#967434', '#bc984e', '#dcbc72'),
    'ceil':    ramp('#03060c', '#081018', '#0e1a26', '#162636', '#203448'),
    'dan_g':   ramp('#061612', '#0c2620', '#163a30', '#225242'),
    'dan_r':   ramp('#14080a', '#261012', '#3a1a1a', '#522624'),
    'wall':    ramp('#04070e', '#08101c', '#0e1a2c', '#16263e', '#203450'),
    'screen':  ramp('#050c16', '#0a1828', '#12283e', '#1c3a56', '#2a5272', '#3e6e8e', '#5a8eaa'),
    'lattice': ramp('#04080e', '#0a1824', '#12304a', '#1e4c6c', '#2e6a8c', '#4a8cae', '#74b2cc'),
    'dais':    ramp('#06080e', '#0e121c', '#181e2c', '#242c3e', '#323c52', '#465068'),
    'bed':     ramp('#0e0a12', '#1c1424', '#2c2038', '#3e304e', '#544466', '#6e5c80'),
    'drape':   ramp('#061416', '#0c2224', '#143436', '#1e4a4a', '#2a6260'),
    'coral':   ramp('#14060c', '#2a0e16', '#4a1a22', '#74302c', '#a0503a', '#c87a4c'),
    'coral2':  ramp('#04100e', '#0a2420', '#123c36', '#1e5a4e', '#34806c', '#5aa890'),
    'carpet':  ramp('#0c0614', '#180a26', '#2a1238', '#401c50', '#5a2a66', '#7a4082'),
    'stone':   ramp('#05080e', '#0c121c', '#161e2c', '#222c3e', '#323e54', '#46546c'),
    'flame':   ramp('#5a2a10', '#a8541c', '#e8902c', '#ffd070', '#fff0b0'),
    'board':   ramp('#0c0610', '#1c0c18', '#2c1420', '#40202c', '#583040'),
    'pearl':   ramp('#1e2c38', '#344e5e', '#527684', '#7a9ea6', '#a6c6c8', '#cce4e0'),
}
FOG = hx('#071426')


def _sph(o, d, c, r):
    oc = o - c
    b = (oc * d).sum(-1)
    cc = (oc * oc).sum(-1) - r * r
    disc = b * b - cc
    t = np.where(disc >= 0, -b - np.sqrt(np.maximum(disc, 0)), np.inf)
    return np.where(t > 1e-3, t, np.inf)


def _cyl(o, d, cx, cz, r, y0, y1):
    ox, oz = o[:, 0] - cx, o[:, 2] - cz
    a = d[:, 0] ** 2 + d[:, 2] ** 2
    b = ox * d[:, 0] + oz * d[:, 2]
    c = ox * ox + oz * oz - r * r
    disc = b * b - a * c
    t = np.where(disc >= 0, (-b - np.sqrt(np.maximum(disc, 0))) / np.maximum(a, 1e-9), np.inf)
    y = o[:, 1] + d[:, 1] * t
    return np.where((t > 1e-3) & (y >= y0) & (y <= y1), t, np.inf)


def _box(o, d, lo, hi):
    inv = 1.0 / np.where(np.abs(d) < 1e-9, 1e-9, d)
    t0 = (np.array(lo) - o) * inv
    t1 = (np.array(hi) - o) * inv
    tmin = np.minimum(t0, t1).max(-1)
    tmax = np.maximum(t0, t1).min(-1)
    return np.where((tmax >= tmin) & (tmax > 1e-3), np.where(tmin > 1e-3, tmin, np.inf), np.inf)


def _plane(o, d, axis, v, sign):
    t = (v - o[:, axis]) / np.where(np.abs(d[:, axis]) < 1e-9, 1e-9, d[:, axis])
    return np.where((t > 1e-3) & (d[:, axis] * sign < 0), t, np.inf)


PILLARS = [(sx * 3.3, z) for z in (4.8, 7.6, 10.4, 13.2) for sx in (-1, 1)] + [(sx * 5.6, z) for z in (5.0, 9.0, 13.0) for sx in (-1, 1)]
CORALS = [(sx * 4.4, z, int(z * 3)) for z in (6.2, 9.0, 12.0) for sx in (-1, 1)] + [(sx * 6.4, z, int(z * 5)) for z in (7.0, 11.0) for sx in (-1, 1)]
BRAZIERS = [(sx * 2.0, z) for z in (6.4, 8.0) for sx in (-1, 1)]
LANTERNS = [(sx * 2.1, 3.9, z) for z in (5.0, 8.0, 11.0) for sx in (-1, 1)]


def scene(o, d, depth=0):
    """Nearest hit → (t, material, point, normal). Materials are strings; 'none' = far fog."""
    n = len(o)
    best = np.full(n, np.inf)
    mat = np.full(n, 'none', object)
    nrm = np.zeros((n, 3))

    def take(t, m, normal_fn):
        nonlocal best
        win = t < best
        if win.any():
            best = np.where(win, t, best)
            mat[win] = m
            p = o[win] + d[win] * t[win, None]
            nrm[win] = normal_fn(p)

    take(_plane(o, d, 1, 0.0, 1), 'floor', lambda p: np.tile([0, 1.0, 0], (len(p), 1)))
    take(_plane(o, d, 1, 6.2, -1), 'ceil', lambda p: np.tile([0, -1.0, 0], (len(p), 1)))
    take(_plane(o, d, 2, 16.0, -1), 'screen', lambda p: np.tile([0, 0, -1.0], (len(p), 1)))
    for sx in (-1, 1):
        take(_plane(o, d, 0, sx * 7.2, -sx), 'lattice', lambda p, sx=sx: np.tile([-sx, 0, 0], (len(p), 1)))
    for (cx, cz) in PILLARS:
        take(_cyl(o, d, cx, cz, 0.3, 0, 6.2), 'pillar', lambda p, cx=cx, cz=cz: np.stack([p[:, 0] - cx, np.zeros(len(p)), p[:, 2] - cz], -1) / 0.3)
    # dais: three steps, then the bed with its canopy
    for k, (hw, z0, y) in enumerate(((3.6, 8.6, 0.22), (3.2, 9.0, 0.44), (2.8, 9.4, 0.66))):
        lo, hi = (-hw, 0.0, z0), (hw, y, 14.6)
        t = _box(o, d, lo, hi)
        take(t, 'dais', lambda p, lo=lo, hi=hi: _box_normal(p, lo, hi))
    lo, hi = (-1.62, 0.66, 10.6), (1.62, 1.0, 12.8)           # lacquered bed frame
    take(_box(o, d, lo, hi), 'pillar', lambda p: _box_normal(p, lo, hi))
    lo, hi = (-1.66, 0.94, 10.56), (1.66, 1.04, 12.84)       # gold trim round the frame
    take(_box(o, d, lo, hi), 'gold', lambda p: _box_normal(p, lo, hi))
    lo, hi = (-1.54, 1.0, 10.7), (1.54, 1.25, 12.7)          # mattress
    take(_box(o, d, lo, hi), 'bed', lambda p: _box_normal(p, lo, hi))
    lo, hi = (-1.62, 1.04, 12.7), (1.62, 2.5, 12.86)           # carved head-board: gives the lying king a lit backdrop
    take(_box(o, d, lo, hi), 'board', lambda p: _box_normal(p, lo, hi))
    for (px, pz) in ((-1.7, 10.4), (1.7, 10.4), (-1.7, 13.0), (1.7, 13.0)):
        take(_cyl(o, d, px, pz, 0.07, 0.66, 3.4), 'gold', lambda p, px=px, pz=pz: np.stack([p[:, 0] - px, np.zeros(len(p)), p[:, 2] - pz], -1) / 0.07)
    lo, hi = (-1.9, 3.35, 10.2), (1.9, 3.6, 13.2)
    take(_box(o, d, lo, hi), 'gold', lambda p: _box_normal(p, lo, hi))
    for sx in (-1, 1):   # drapes gathered at the canopy posts
        lo, hi = (sx * 1.7 - 0.22, 1.0, 10.25), (sx * 1.7 + 0.22, 3.35, 10.55)
        take(_box(o, d, lo, hi), 'drape', lambda p, lo=lo, hi=hi: _box_normal(p, lo, hi))
    for (cx, cz, k) in CORALS:      # coral clusters between the pillars: branching trunks with round crowns
        for j in range(4):
            bx, bz = cx + math.cos(j * 1.9 + k) * 0.28, cz + math.sin(j * 1.9 + k) * 0.28
            h = 0.9 + 0.5 * ((j * 7 + k) % 3)
            nm = 'coral' if (k + j) % 2 == 0 else 'coral2'
            take(_cyl(o, d, bx, bz, 0.07, 0, h), nm, lambda p, bx=bx, bz=bz: np.stack([p[:, 0] - bx, np.zeros(len(p)), p[:, 2] - bz], -1) / 0.07)
            c = np.array([bx, h + 0.05, bz])
            take(_sph(o, d, c, 0.2 + 0.04 * j), nm, lambda p, c=c, r=0.2 + 0.04 * j: (p - c) / r)
    for sx in (-1, 1):             # pearl on a stone pedestal beside the dais
        lo, hi = (sx * 2.7 - 0.35, 0.0, 7.5), (sx * 2.7 + 0.35, 0.9, 8.2)
        take(_box(o, d, lo, hi), 'stone', lambda p, lo=lo, hi=hi: _box_normal(p, lo, hi))
        c = np.array([sx * 2.7, 1.3, 7.85])
        take(_sph(o, d, c, 0.42), 'pearl', lambda p, c=c: (p - c) / 0.42)
    for (sx, z) in ((-1.1, 6.0), (1.1, 6.0), (-1.1, 9.4), (1.1, 9.4)):   # strings of pearls hanging from the beams
        for j in range(6):
            c = np.array([sx, 5.9 - j * 0.28, z])
            take(_sph(o, d, c, 0.09), 'pearl', lambda p, c=c: (p - c) / 0.09)
    for (bx, bz) in BRAZIERS:      # bronze braziers burning pearl-oil: the warm accents flanking the way to the bed
        take(_cyl(o, d, bx, bz, 0.09, 0, 0.8), 'gold', lambda p, bx=bx, bz=bz: np.stack([p[:, 0] - bx, np.zeros(len(p)), p[:, 2] - bz], -1) / 0.09)
        take(_cyl(o, d, bx, bz, 0.3, 0.8, 0.95), 'gold', lambda p, bx=bx, bz=bz: np.stack([p[:, 0] - bx, np.zeros(len(p)), p[:, 2] - bz], -1) / 0.3)
        take(_sph(o, d, np.array([bx, 1.12, bz]), 0.22), 'flame', lambda p, c=np.array([bx, 1.12, bz]): (p - c) / 0.22)
    for (cx, cz) in PILLARS:       # bracket sets under the eaves
        take(_cyl(o, d, cx, cz, 0.44, 5.35, 5.8), 'dan_r', lambda p, cx=cx, cz=cz: np.stack([p[:, 0] - cx, np.zeros(len(p)), p[:, 2] - cz], -1) / 0.44)
    for (lx, ly, lz) in LANTERNS:
        take(_sph(o, d, np.array([lx, ly, lz]), 0.18), 'pearl', lambda p, c=np.array([lx, ly, lz]): (p - c) / 0.18)
    return best, mat, nrm


def _box_normal(p, lo, hi):
    lo, hi = np.array(lo), np.array(hi)
    c = (lo + hi) / 2; h = (hi - lo) / 2
    q = (p - c) / h
    k = np.argmax(np.abs(q), -1)
    n = np.zeros_like(p)
    n[np.arange(len(p)), k] = np.sign(q[np.arange(len(p)), k])
    return n


def _noise(x, y, s):
    return (np.sin(x * 1.7 + s) * np.sin(y * 1.3 - s * 0.7) + np.sin(x * 0.6 - y * 0.9 + s * 2.1)) * 0.25 + 0.5


def shade(mat, p, nrm, d):
    """Material tone in ramp units (before dithering)."""
    x, y, z = p[:, 0], p[:, 1], p[:, 2]
    L = np.array([-0.35, 0.85, -0.4]); L /= np.linalg.norm(L)
    lam = np.clip((nrm * L).sum(-1), 0, 1)
    glow = np.zeros(len(p))
    for (lx, ly, lz) in LANTERNS:   # pearl lanterns light their surroundings
        dd = np.sqrt((x - lx) ** 2 + (y - ly) ** 2 + (z - lz) ** 2)
        glow += 1.6 / (1.0 + dd * dd * 0.35)
    tone = np.zeros(len(p))
    m = mat
    f = m == 'floor'
    if f.any():
        caust = _noise(x[f] * 2.2, z[f] * 2.2, 1.0) * _noise(x[f] * 3.1 + 4, z[f] * 2.7, 2.0)
        # seigaiha: staggered rings of overlapping scales (용궁 비늘 바닥)
        sc_ = 0.9
        row = np.floor(z[f] / (sc_ * 0.5))
        xo = x[f] / sc_ + (row % 2) * 0.5
        fx = np.mod(xo, 1.0) - 0.5
        fz = np.mod(z[f] / (sc_ * 0.5), 1.0)
        rr = np.sqrt(fx ** 2 + (fz * 0.5) ** 2) * 2.0
        ring = (np.abs(np.mod(rr * 3.0, 1.0) - 0.5) < 0.12) * 0.55
        tile = ring + (rr < 0.55) * 0.25
        tone[f] = 1.4 + tile + caust * 1.6 + glow[f] * 0.9 - z[f] * 0.05
        run = np.abs(x[f]) < 1.15   # the carpet runner to the dais, gold-edged
        edge = run & (np.abs(np.abs(x[f]) - 1.0) < 0.07)
        tone[f] = np.where(run, 1.6 + glow[f] * 1.0 + caust * 0.8 + ((np.mod(z[f], 0.9) < 0.1) * 0.8), tone[f])
        mm = m[f]; mm[run] = 'carpet'; mm[edge] = 'gold'; m[f] = mm
        tone[np.where(f)[0][edge]] = 3.2
    f = m == 'floor'
    for name, base, k in (('pillar', 2.0, 3.0), ('coral', 1.4, 3.4), ('coral2', 1.4, 3.4), ('stone', 1.4, 2.6), ('dan_r', 1.4, 2.4), ('dais', 1.4, 2.4), ('bed', 1.6, 2.8), ('drape', 1.2, 2.4), ('gold', 1.6, 3.2), ('board', 1.0, 1.0)):
        s = m == name
        tone[s] = base + lam[s] * k + glow[s] * 0.9
    s = m == 'pillar'
    if s.any():   # gold bands top and foot, a dragon coiling up the shaft
        ang = np.arctan2(p[s, 2] - np.round(p[s, 2] * 2) / 2, p[s, 0])
        band = (np.abs(y[s] - 0.35) < 0.22) | (np.abs(y[s] - 5.7) < 0.3) | (np.abs(y[s] - 5.2) < 0.08)
        coil = np.abs(np.mod(y[s] * 0.9 + np.arctan2(nrm[s, 2], nrm[s, 0]) / math.pi, 2.0) - 1.0) < 0.06
        m_s = np.where(band | (coil & (y[s] > 1.2) & (y[s] < 4.8)), 'gold', 'pillar')
        mat_s = m[s]; mat_s[:] = m_s; m[s] = mat_s
    c = m == 'ceil'
    if c.any():   # coffers: beams in muted 단청 green and red, gold at the crossings
        bx = np.abs(np.mod(x[c], 2.0) - 1.0) > 0.82
        bz = np.abs(np.mod(z[c], 2.0) - 1.0) > 0.82
        sub = np.where(bx & bz, 'gold', np.where(bx, 'dan_g', np.where(bz, 'dan_r', 'ceil')))
        mm = m[c]; mm[:] = sub; m[c] = mm
        tone[c] = 1.2 + glow[c] * 1.4 + _noise(x[c], z[c], 3.0) * 0.6
    sc = m == 'screen'
    if sc.any():   # the painted screen: rolling waves and the pearl above them
        wave = np.sin(x[sc] * 2.2 + np.sin(y[sc] * 3.0) * 1.2) * 0.5 + np.sin(y[sc] * 6.0 + x[sc]) * 0.4
        pearl = np.exp(-((x[sc]) ** 2 + (y[sc] - 4.4) ** 2) / 0.6) * 4.0
        tone[sc] = 1.6 + wave * 0.8 + (y[sc] < 2.8) * 0.6 + pearl
        frame = (np.abs(x[sc]) > 3.6) | (y[sc] > 5.6) | (y[sc] < 0.4)
        mm = m[sc]; mm[frame] = 'gold'; m[sc] = mm
        tone[sc] = np.where(frame, 2.0, tone[sc])
    la = m == 'lattice'
    if la.any():   # lattice windows lit from the sea outside
        grid = (np.abs(np.mod(z[la], 0.5) - 0.25) < 0.04) | (np.abs(np.mod(y[la], 0.5) - 0.25) < 0.04)
        win = (np.mod(z[la], 3.0) > 0.6) & (y[la] > 1.0) & (y[la] < 4.8)
        tone[la] = np.where(win & ~grid, 3.4 + _noise(z[la], y[la], 5.0) * 2.0, 0.8 + glow[la] * 0.5)
        for fz_, fy_ in ((4.0, 2.4), (8.5, 3.6), (11.5, 2.0), (14.5, 3.9)):   # fish gliding past the windows
            fsh = ((z[la] - fz_) / 0.9) ** 2 + ((y[la] - fy_) / 0.22) ** 2 < 1
            tone[la] = np.where(fsh & win, 0.8, tone[la])
        mm = m[la]; mm[~win] = 'wall'; m[la] = mm
    bd = m == 'board'
    if bd.any():   # head-board: gold frame, a lacquer panel with a coiling-cloud lattice and a pearl in the middle
        fr = (np.abs(x[bd]) > 1.5) | (y[bd] > 2.38) | (y[bd] < 1.14)
        cloud = np.sin(x[bd] * 9.0 + np.sin(y[bd] * 7.0) * 1.3) * np.sin(y[bd] * 8.0 + 1.0)
        pr = np.exp(-(x[bd] ** 2 + (y[bd] - 1.85) ** 2) / 0.05) * 4.0
        tone[bd] = 1.2 + np.clip(cloud, 0, 1) * 1.1 + pr + glow[bd] * 0.9
        mm = m[bd]; mm[fr] = 'gold'; mm[pr > 1.5] = 'pearl'; m[bd] = mm
        tone[np.where(bd)[0][fr]] = 3.0
    fl = m == 'flame'
    tone[fl] = 2.2 + lam[fl] * 1.8
    pe = m == 'pearl'
    tone[pe] = 2.8 + lam[pe] * 1.6
    g = m == 'gold'
    tone[g] = np.maximum(tone[g], 1.8 + lam[g] * 3.0 + glow[g])
    return tone, m


def render():
    # camera behind the sons, eye height 2.4m, looking down the hall
    eye = np.array([0.0, 3.0, -5.5])
    pitch = math.radians(-10)
    fov = math.radians(64)
    ys, xs = np.mgrid[0:H, 0:W]
    u = (xs + 0.5 - W / 2) / (W / 2) * math.tan(fov / 2)
    v = -(ys + 0.5 - H / 2) / (W / 2) * math.tan(fov / 2)
    dcam = np.stack([u, v, np.ones_like(u)], -1).reshape(-1, 3)
    cp, sp = math.cos(pitch), math.sin(pitch)
    d = np.stack([dcam[:, 0], dcam[:, 1] * cp + dcam[:, 2] * sp, -dcam[:, 1] * sp + dcam[:, 2] * cp], -1)
    d /= np.linalg.norm(d, axis=1, keepdims=True)
    o = np.tile(eye, (len(d), 1))
    t, mat, nrm = scene(o, d)
    p = o + d * np.where(np.isfinite(t), t, 30)[:, None]
    tone, mat = shade(mat, p, nrm, d)
    # floor reflection: polished jade mirrors the pillars and lanterns faintly
    f = mat == 'floor'
    if f.any():
        rd = d[f].copy(); rd[:, 1] *= -1
        rt, rm, rn = scene(p[f] + rd * 1e-3, rd)
        rp = p[f] + rd * np.where(np.isfinite(rt), rt, 30)[:, None]
        rtone, rm = shade(rm, rp, rn, rd)
        refl = np.isin(rm, ['pillar', 'gold', 'pearl', 'bed', 'dais', 'coral', 'coral2'])
        tone_f = tone[f]
        tone_f[refl] = tone_f[refl] * 0.65 + rtone[refl] * 0.35
        tone[f] = tone_f
    # paint
    yy, xx = ys.ravel(), xs.ravel()
    jitter = (BAYER[yy % 4, xx % 4] - 0.5) * 0.9
    rgb = np.zeros((len(d), 3), np.float32)
    for name, rmp in RAMPS.items():
        s = mat == name
        if s.any():
            rgb[s] = rmp[np.clip(np.round(tone[s] + jitter[s]), 0, len(rmp) - 1).astype(int)]
    rgb[mat == 'wall'] = RAMPS['wall'][np.clip(np.round(tone[mat == 'wall'] + jitter[mat == 'wall']), 0, 4).astype(int)]
    # depth fog toward the sea-dark, and light shafts from the water far above
    dist = np.where(np.isfinite(t), t, 30)
    fog = 1 - np.exp(-dist * 0.055)
    shafts = np.zeros(len(d))
    for k, sx in enumerate((-2.6, -0.4, 1.8, 3.4)):
        lx = xx - (240 + sx * 38 + yy * (0.25 + k * 0.04))
        shafts += np.exp(-(lx ** 2) / (60 + k * 30)) * np.clip(1.2 - yy / 220, 0, 1)
    rgb = rgb * (1 - fog[:, None] * 0.75) + FOG * fog[:, None] * 0.75
    rgb += np.array([40, 70, 90]) * (shafts * 0.28)[:, None]
    c0 = np.array([0.0, 1.6, 11.0])    # warm lamplight over the sick-bed (the one warm note in the cold hall)
    dd2 = ((p - c0) ** 2).sum(-1)
    rgb += np.array([70, 40, 12]) * np.exp(-dd2 / 12.0)[:, None] * 0.95
    for (bx, bz) in BRAZIERS:          # brazier firelight spilling on pillars and floor
        db = ((p - np.array([bx, 1.1, bz])) ** 2).sum(-1)
        rgb += np.array([90, 46, 12]) * np.exp(-db / 5.0)[:, None] * 0.8
    rng = np.random.default_rng(21)    # drifting motes baked as single bright pixels, brighter when nearer
    for _ in range(170):
        mx, my = rng.integers(0, W), rng.integers(0, H)
        k = rng.random()
        rgb.reshape(H, W, 3)[my, mx] = np.maximum(rgb.reshape(H, W, 3)[my, mx], np.array([90, 150, 170]) * (0.5 + k * 0.5))
    q = np.floor(rgb / 6) * 6   # keep the palette tight after fog
    return np.clip(q, 0, 255).reshape(H, W, 3)
