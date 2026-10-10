"""처용 — HD-2D (옥토패스식) 주인공 스프라이트를 작은 3D 인형에서 바로 도트로 뽑는다.

He is modelled as a little figure of primitives (ellipsoids and tapered cylinders on any axis), each
with a material. Every pixel of the 32x48 cell casts an orthographic ray through a camera that looks
down ~18 degrees; the nearest hit gives material, surface normal and a surface position. Light is
one key from the upper left (+ a cool moon rim from behind-right), posterized onto 6-tone ramps, so
it stays pixel art. Details live on the surfaces (eyes, brows, the 용비늘 shawl, 철릭 pleats, the
동정 collar) and therefore turn with him: front, 3/4, side and back are the same figure.
Outlines are sel-out: a dark shade of the colour beside them, softer on inner overlaps.

Palette: muted, dusty and cool, warm only in skin and brass (the brief: "지금 너무 쨍함").
Writes godot/assets/sprites/cheoyong.png in the frame order player.gd expects (feet on row 44).
Usage: python3 art/hero.py [--preview N]
"""
import math, pathlib, sys
import numpy as np
from PIL import Image

ROOT = pathlib.Path(__file__).parent
GODOT = ROOT.parent / 'godot' / 'assets' / 'sprites'
W, H, FEET = 32, 48, 44


def hx(h):
    h = h.lstrip('#')
    return (int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16))


def R(*cs):
    return np.array([hx(c) for c in cs], np.float32)


# ---------------------------------------------------------------- muted palette (6 tones, dark → light)
RAMPS = {
    'skin':    R('#3e2a28', '#6a4638', '#8e6250', '#ad8066', '#c89e80', '#dcbc9e'),
    'hair':    R('#121117', '#1b1a22', '#25242e', '#32313d', '#43424f', '#595869'),
    'robe':    R('#171a26', '#21263a', '#2d3349', '#3b4259', '#4d546b', '#636a80'),
    'robe_in': R('#1a1622', '#262030', '#332b3e', '#40364a', '#4e4456', '#5e5466'),
    'shawl':   R('#172422', '#20322f', '#2b413c', '#38524b', '#4a665c', '#617d71'),
    'red':     R('#261618', '#3a2023', '#4f2c2c', '#663a36', '#7c4c42', '#925f52'),
    'brass':   R('#33281a', '#4c3c24', '#695330', '#866c40', '#a18856', '#bba372'),
    'collar':  R('#4c4b52', '#64636a', '#7c7b82', '#94939a', '#aaa9ae', '#c0bfc2'),
    'cuff':    R('#15151b', '#1f1f27', '#2a2a34', '#363642', '#454552', '#575764'),
    'boot':    R('#141116', '#1d181e', '#272027', '#322a31', '#3f363d', '#4f454b'),
    'wood':    R('#261c14', '#382a1c', '#4c3a26', '#614c32', '#775f40', '#8c7350'),
    'eye':     R('#0e0c12', '#0e0c12', '#16131c', '#16131c', '#e8e2d6', '#e8e2d6'),
    'hat':     R('#0c0b10', '#141219', '#1c1a23', '#26232f', '#322f3c', '#413d4c'),
    'beard':   R('#4a4a50', '#68686e', '#86868c', '#a2a2a6', '#bcbcbe', '#d2d2d2'),
    'gold':    R('#3e2e16', '#5e4620', '#82632e', '#a5833f', '#c2a258', '#d8bc78'),
    'coral':   R('#3a1416', '#5a1f20', '#7a2e2a', '#9a4036', '#b45646', '#c87060'),
    'gourd':   R('#3a2a12', '#5a421c', '#7a5c28', '#987636', '#b29048', '#c8a860'),
}
RAMPS['top'] = RAMPS['robe_in']
L_KEY = np.array([-0.55, 0.62, 0.56]); L_KEY /= np.linalg.norm(L_KEY)    # camera space: left, up, front
L_RIM = np.array([0.8, 0.35, -0.5]); L_RIM /= np.linalg.norm(L_RIM)      # moon from behind-right
RIM_COL = np.array([118, 136, 178], np.float32)
PITCH = math.radians(18)


# ---------------------------------------------------------------- primitives (model space: +x right, +y up, +z front)
class Ell:
    def __init__(self, c, r, mat, tag=''):
        self.c, self.r, self.mat, self.tag = np.array(c, float), np.array(r, float), mat, tag

    def hit(self, o, d):
        oc = (o - self.c) / self.r
        dd = d / self.r
        a = (dd * dd).sum(-1)
        b = 2 * (oc * dd).sum(-1)
        c = (oc * oc).sum(-1) - 1
        disc = b * b - 4 * a * c
        t = np.where(disc >= 0, (-b - np.sqrt(np.maximum(disc, 0))) / (2 * a), np.inf)
        p = o + d * t[:, None]
        n = (p - self.c) / (self.r ** 2)
        return t, p, n


class Cone:
    """Tapered cylinder from a to b with radii r0 → r1; kz flattens the cross-section front-back."""
    def __init__(self, a, b, r0, r1, mat, kz=1.0, tag='', caps=True):
        self.a, self.b = np.array(a, float), np.array(b, float)
        self.r0, self.r1, self.mat, self.kz, self.tag, self.caps = r0, r1, mat, kz, tag, caps
        w = self.b - self.a
        self.L = np.linalg.norm(w)
        self.w = w / self.L
        ref = np.array([0, 0, 1.0]) if abs(self.w[2]) < 0.9 else np.array([1.0, 0, 0])
        self.v = ref - self.w * (ref @ self.w); self.v /= np.linalg.norm(self.v)    # front-back
        self.u = np.cross(self.w, self.v)                                             # side-side

    def hit(self, o, d):
        po = o - self.a
        A1, B1 = po @ self.u, d @ self.u
        A2, B2 = (po @ self.v) / self.kz, (d @ self.v) / self.kz
        A3, B3 = po @ self.w, d @ self.w
        k = (self.r1 - self.r0) / self.L
        # (A1+B1t)^2 + (A2+B2t)^2 = (r0 + k(A3+B3t))^2
        R0 = self.r0 + k * A3
        a = B1 * B1 + B2 * B2 - (k * B3) ** 2
        b = 2 * (A1 * B1 + A2 * B2 - R0 * k * B3)
        c = A1 * A1 + A2 * A2 - R0 * R0
        disc = b * b - 4 * a * c
        sq = np.sqrt(np.maximum(disc, 0))
        best = np.full(len(o), np.inf)
        for sgn in (-1, 1):
            t = np.where((disc >= 0) & (np.abs(a) > 1e-9), (-b + sgn * sq) / (2 * a + 1e-12), np.inf)
            s = A3 + B3 * t
            ok = (s >= 0) & (s <= self.L) & (t > 0)
            best = np.where(ok & (t < best), t, best)
        n_side = None
        if self.caps:
            for s0, rr in ((self.L, self.r1), (0.0, self.r0)):
                t = np.where(np.abs(B3) > 1e-9, (s0 - A3) / (B3 + 1e-12), np.inf)
                q1, q2 = A1 + B1 * t, A2 + B2 * t
                ok = (q1 * q1 + q2 * q2 <= rr * rr) & (t > 0)
                best = np.where(ok & (t < best), t, best)
        p = o + d * best[:, None]
        pl = p - self.a
        q1, q2, s = pl @ self.u, (pl @ self.v) / self.kz, pl @ self.w
        r = self.r0 + k * s
        n = (q1[:, None] * self.u + (q2 / self.kz)[:, None] * self.v - (r * k)[:, None] * self.w)
        cap_top = np.abs(s - self.L) < 0.05
        cap_bot = np.abs(s) < 0.05
        n = np.where(cap_top[:, None], self.w, np.where(cap_bot[:, None], -self.w, n))
        return best, p, n


# ---------------------------------------------------------------- the figure
HERO = {'shawl': True, 'flute': True, 'ribbon': True}


def figure(pose, sp=HERO):
    """pose: walk (0-3 or None), breath (bool), armless (None | 'L' | 'R'), flute (bool).
    sp: the character (art/people.py) — hat, hair, beard, chima, badge, staff, shawl, flute, ribbon."""
    walk, breath = pose.get('walk'), pose.get('breath', False)
    lf = lz = rz = rf = 0.0
    bob = 0.0
    if walk is not None:
        sw = (1, 0, -1, 0)[walk]
        lz, rz = 2.6 * sw, -2.6 * sw
        lf = 0.9 if sw < 0 else 0.0     # the back foot lifts a little
        rf = 0.9 if sw > 0 else 0.0
        bob = 0.7 if sw == 0 else 0.0
    up = bob - (0.6 if breath else 0.0)   # everything above the hem
    P = []
    # boots
    for side, z, f in ((-1, lz, lf), (1, rz, rf)):
        x = side * 2.7
        P.append(Cone((x, f, z - 0.3), (x, 6 + f, z - 0.3), 1.9, 1.7, 'boot', kz=1.1))
        P.append(Ell((x, 0.9 + f, z + 1.1), (1.8, 1.0, 2.2), 'boot'))
    # 철릭 skirt (pleated), its red hem, the belt and brass buckle
    sway = (lz - rz) * 0.12
    if sp.get('chima'):   # 치마 from high under the arms, a short 저고리 above
        P.append(Cone((sway, 4.2 + up * 0.3, 0), (0, 22.0 + up, 0), 9.6, 6.0, 'robe', kz=0.8, tag='skirt'))
        P.append(Cone((0, 21.5 + up, 0), (0, 26.2 + up, 0), 6.0, 6.7, 'top', kz=0.62, tag='jeogori'))
        for side in (-1, 1):
            P.append(Ell((side * 5.7, 25.2 + up, 0), (2.8, 2.1, 2.5), 'top', tag='jeogori'))
    else:
        P.append(Cone((sway, 4.5 + up * 0.3, 0), (0, 17.5 + up, 0), 8.6, 6.4, 'robe', kz=0.78, tag='skirt'))
        P.append(Cone((0, 16.6 + up, 0), (0, 18.8 + up, 0), 6.7, 6.7, 'red', kz=0.72, tag='belt'))
        # torso and shoulders
        P.append(Cone((0, 18.5 + up, 0), (0, 26.2 + up, 0), 6.2, 6.9, 'robe', kz=0.62, tag='torso'))
        for side in (-1, 1):
            P.append(Ell((side * 5.9, 25.2 + up, 0), (2.9, 2.2, 2.6), 'robe', tag='torso'))
    sleeve = 'top' if sp.get('chima') else 'robe'
    # arms: wide 도포 sleeves, dark 토시 cuffs, hands
    for side, swing in ((-1, -lz * 0.6), (1, -rz * 0.6)):
        if pose.get('armless') == ('L' if side < 0 else 'R'):
            continue
        sh = np.array([side * 7.4, 25.0 + up, 0.0])
        wr = np.array([side * 8.6, 16.2 + up, 0.6 + swing])
        P.append(Cone(sh, wr, 2.0, 2.7, sleeve, kz=1.0, tag='sleeve'))
        cf = wr + (wr - sh) / np.linalg.norm(wr - sh) * 1.4
        P.append(Cone(wr, cf, 1.5, 1.5, 'cuff', caps=True))
        P.append(Ell(cf + np.array([0, -1.0, 0.2]), (1.4, 1.5, 1.3), 'skin', tag='hand'))
    # neck, head, ears, hair knot and ribbon
    P.append(Cone((0, 25.5 + up, -0.2), (0, 28.6 + up, -0.2), 1.9, 1.8, 'skin'))
    hc = (0, 33.4 + up, 0.0)
    P.append(Ell(hc, (6.3, 6.4, 6.0), 'skin', tag='head'))
    for side in (-1, 1):
        P.append(Ell((side * 6.1, 32.6 + up, -0.6), (0.9, 1.4, 1.1), 'skin'))
    P.append(Ell((0, 31.6 + up, 5.7), (0.8, 1.1, 0.9), 'skin'))                                   # nose (the profile needs it)
    hat = sp.get('hat')
    if sp.get('long_hair'):   # 쪽진 머리: a low bun, the hair drawn smooth to the back
        P.append(Ell((0, 31.5 + up, -5.6), (2.6, 2.2, 2.0), 'hair', tag='knot'))
        P.append(Ell((2.6, 31.8 + up, -5.4), (1.6, 0.5, 0.5), 'gold'))                              # 비녀
    elif hat not in ('samo', 'ikseon', 'kerchief'):
        P.append(Ell((0, 40.4 + up, -0.9), (2.2, 2.3, 2.1), 'hair', tag='knot'))
    if sp.get('ribbon'):
        P.append(Cone((0, 38.3 + up, -0.9), (0, 39.3 + up, -0.9), 2.5, 2.4, 'red'))
        P.append(Cone((1.4, 39.4 + up, -2.0), (6.2, 35.0 + up, -3.0), 0.7, 0.9, 'red', caps=True))   # 댕기 tails
        P.append(Cone((1.0, 39.2 + up, -2.2), (5.0, 33.8 + up, -3.6), 0.6, 0.8, 'red', caps=True))
    if hat in ('samo', 'ikseon'):   # 사모 / 익선관: a black gauze crown, a raised back, two wings
        P.append(Cone((0, 37.0 + up, -0.4), (0, 41.0 + up, -0.6), 5.6, 4.6, 'hat', kz=0.95))
        P.append(Ell((0, 41.6 + up, -2.0), (3.6, 2.6, 2.4), 'hat'))
        if hat == 'samo':
            for side in (-1, 1):
                P.append(Ell((side * 6.6, 40.2 + up, -2.2), (2.6, 1.0, 0.45), 'hat'))
        else:
            for side in (-1, 1):
                P.append(Ell((side * 2.6, 44.0 + up, -3.0), (1.6, 2.3, 0.5), 'hat'))
    elif hat == 'crown':            # 용왕의 관: gold band, coral points
        P.append(Cone((0, 38.0 + up, -0.5), (0, 40.6 + up, -0.5), 5.3, 5.6, 'gold', kz=0.95, caps=False))
        for k in range(5):
            a = (k - 2) * 0.55
            P.append(Ell((math.sin(a) * 5.0, 41.4 + up, math.cos(a) * 4.6 - 0.5), (0.7, 1.3, 0.7), 'coral'))
    elif hat == 'kerchief':         # 머릿수건
        P.append(Ell((0, 35.6 + up, -0.6), (6.8, 5.6, 6.4), 'hat', tag='kerchief'))
    elif hat == 'headband':         # 머리띠 / 짚 띠
        P.append(Cone((0, 35.4 + up, 0), (0, 36.8 + up, 0), 6.55, 6.45, 'hat', kz=0.96, caps=False))
    beard = sp.get('beard')
    if beard == 'long':
        P.append(Ell((0, 28.6 + up, 4.6), (3.4, 4.4, 2.0), 'beard'))
        P.append(Ell((0, 25.2 + up, 5.0), (2.0, 3.0, 1.4), 'beard'))
    elif beard == 'short':
        P.append(Ell((0, 29.6 + up, 4.7), (2.8, 1.9, 1.6), 'beard'))
    if sp.get('staff'):             # 산신의 지팡이, 끝에 호리병
        P.append(Cone((10.2, 0, 1.2), (10.2, 39.0, 1.2), 0.7, 0.6, 'wood'))
        P.append(Ell((10.2, 40.6, 1.2), (1.5, 1.9, 1.5), 'gourd'))
    # the 대금 slung across his back
    if sp.get('flute') and pose.get('flute', True):
        P.append(Cone((-8.2, 36.0 + up, -3.6), (5.4, 13.5 + up, -3.9), 0.9, 0.9, 'wood', tag='flute'))
    return P


def render(facing_deg, pose, sp=HERO):
    th, ph = math.radians(facing_deg), PITCH
    # camera = pitch · yaw · model;   yaw turns his front (+z) toward screen right as the angle grows
    Ry = np.array([[math.cos(th), 0, math.sin(th)], [0, 1, 0], [-math.sin(th), 0, math.cos(th)]])
    Rx = np.array([[1, 0, 0], [0, math.cos(ph), -math.sin(ph)], [0, math.sin(ph), math.cos(ph)]])
    M = Rx @ Ry
    Minv = M.T
    ys, xs = np.mgrid[0:H, 0:W]
    xc = (xs + 0.5 - W / 2).ravel().astype(float)
    yc = (FEET - ys - 0.5).ravel().astype(float) + 1.0
    oc = np.stack([xc, yc, np.full_like(xc, 80.0)], -1)
    o = oc @ Minv.T / sp.get('scale', 1.0)       # a child is the same figure, smaller
    d = np.tile(np.array([0, 0, -1.0]) @ Minv.T, (len(xc), 1))
    best = np.full(len(xc), np.inf)
    hitp = np.zeros((len(xc), 3)); hitn = np.zeros((len(xc), 3))
    owner = np.full(len(xc), -1)
    parts = figure(pose, sp)
    ramps = dict(RAMPS)
    ramps.update(sp.get('ramps', {}))
    for i, pr in enumerate(parts):
        t, p, n = pr.hit(o, d)
        win = t < best
        best[win] = t[win]; hitp[win] = p[win]; hitn[win] = n[win]; owner[win] = i
    img = np.zeros((H * W, 4), np.float32)
    depth = np.where(np.isfinite(best), best, 1e9).reshape(H, W)
    for i, pr in enumerate(parts):
        m = owner == i
        if not m.any():
            continue
        p, n = hitp[m], hitn[m]
        n = n / (np.linalg.norm(n, axis=1, keepdims=True) + 1e-9)
        nc = n @ M.T
        lam = np.clip(nc @ L_KEY, 0, 1)
        rim = np.clip(nc @ L_RIM, 0, 1)
        tone = 0.9 + lam * 4.2 + {'skin': 0.8, 'hair': -1.4}.get(pr.mat, 0.0)
        mat = np.full(len(p), pr.mat, object)
        tone, mat = details(pr, p, n, tone, mat, lam, sp)
        idx = np.clip(np.round(tone), 0, 5).astype(int)
        col = np.zeros((len(p), 3), np.float32)
        for mname in set(mat):
            s = mat == mname
            col[s] = ramps[mname][idx[s]]
        rimk = (rim > 0.55) & (mat != 'eye')
        col[rimk] = col[rimk] * 0.62 + RIM_COL * 0.38 * (rim[rimk, None] + 0.2)
        img[m, :3] = col
        img[m, 3] = 255
    img = img.reshape(H, W, 4)
    return outline(img, depth)


def details(pr, p, n, tone, mat, lam, sp=HERO):
    """Surface details in model space, so they turn with him."""
    x, y, z = p[:, 0], p[:, 1], p[:, 2]
    if pr.tag == 'head':
        c = pr.c
        v = (p - c) / pr.r
        az = np.arctan2(v[:, 0], v[:, 2])                       # 0 = straight ahead
        el = v[:, 1]
        hair = (el > 0.36 + 0.07 * np.cos(az * 7)) | (np.abs(az) > 1.6) | ((np.abs(az) > 1.2) & (el > 0.08))
        mat = np.where(hair, 'hair', mat)
        tone = np.where(hair, tone - 2.2, tone)      # hair is blue-black; only the sheen lifts it
        tone = np.where(hair & (lam > 0.6) & (el > 0.45) & (el < 0.8), tone + 1.6, tone)          # sheen band
        eye = (np.abs(np.abs(az) - 0.33) < 0.14) & (el > -0.16) & (el < 0.15) & ~hair
        mat = np.where(eye, 'eye', mat)
        tone = np.where(eye, np.where((el > 0.07) & (np.abs(np.abs(az) - 0.3) < 0.04), 5, 1), tone)   # one small catchlight
        brow = (np.abs(np.abs(az) - 0.34) < 0.16) & (np.abs(el - 0.25) < 0.05) & ~hair
        mat = np.where(brow, 'hair', mat); tone = np.where(brow, 1, tone)
        mouth = (np.abs(az) < 0.1) & (np.abs(el + 0.46) < 0.05)
        mat = np.where(mouth, 'red', mat); tone = np.where(mouth, 1.5, tone)
        cheek = (np.abs(np.abs(az) - 0.5) < 0.14) & (np.abs(el + 0.22) < 0.1) & ~hair
        tone = np.where(cheek, tone - 0.5, tone)
        nose = (np.abs(az) < 0.06) & (el > -0.36) & (el < -0.18)
        tone = np.where(nose & (v[:, 0] > 0), tone - 0.8, tone)
    elif pr.tag == 'skirt':
        az = np.arctan2(x, z)
        pleat = np.floor((az + np.pi) / (2 * np.pi) * 22).astype(int) % 2
        tone = tone + np.where(pleat == 0, 0.35, -0.45)
        hem = (y < 6.4) & (not sp.get('chima'))
        mat = np.where(hem, 'red', mat)
        tone = np.where(hem & (y < 5.4), tone - 0.6, tone)
        tone = tone - np.clip((17 - y) / 12, 0, 1) * 0.6                            # darker toward the hem
    elif pr.tag == 'belt':
        buckle = (np.abs(x) < 1.3) & (z > 0)
        mat = np.where(buckle, 'brass', mat)
    elif pr.tag == 'torso':
        # 동정 collar: a pale V opening from the neck
        vy = y - (pr.a[1] if hasattr(pr, 'a') else 18.5)
        collar = (z > 0) & (np.abs(np.abs(x) - (7.2 - vy) * 0.55) < 0.75) & (y > 21.5)
        mat = np.where(collar, 'collar', mat)
        inner = (z > 0) & (np.abs(x) < (y - 21.5) * 0.55 - 0.7) & (y > 21.5)
        mat = np.where(inner, 'robe_in', mat)
        if sp.get('badge'):   # 흉배: the rank square on the chest
            badge = (z > 0) & (np.abs(x) < 2.4) & (y > 19.6) & (y < 23.6)
            mat = np.where(badge, sp['badge'], mat)
        # 용비늘 shawl: a band from his left shoulder down across the chest to the right hip
        band = np.abs((x - 0.5) - (y - 22.0) * 0.95) < 2.4
        shawl = band & (y > 18.5) & bool(sp.get('shawl'))
        mat = np.where(shawl, 'shawl', mat)
        scale = shawl & (((np.floor(y * 1.0) + np.floor(x * 0.7)) % 2) == 0)          # scales
        tone = np.where(scale, tone + 0.5, tone)
    elif pr.tag == 'jeogori':   # 저고리: pale collar line and the 고름 ribbon
        collar = (z > 0) & (np.abs(np.abs(x) - (26.4 - y) * 0.55) < 0.7) & (y > 22.5)
        mat = np.where(collar, 'collar', mat)
        goreum = (z > 0) & (x > 0.3) & (x < 1.8) & (y > 20.0) & (y < 23.2)
        mat = np.where(goreum, 'red', mat)
    elif pr.tag == 'kerchief':
        tone = tone + np.where(((np.floor(x) + np.floor(y)) % 3) == 0, -0.4, 0.0)
    elif pr.tag == 'sleeve':
        tone = tone - np.clip((26 - y) / 9, 0, 1) * 0.4
    elif pr.tag == 'flute':
        band = (np.abs(np.mod(y, 5.5) - 0.5) < 0.6)
        mat = np.where(band, 'brass', mat)
    return tone, mat


def outline(img, depth):
    """Sel-out: the silhouette's outline is a dark shade of the colour inside it; where a nearer part
    overlaps a farther one, the farther pixel darkens into a soft inner line."""
    a = img[..., 3] > 0
    out = img.copy()
    H_, W_ = a.shape
    for y in range(H_):
        for x in range(W_):
            if a[y, x]:
                d0 = depth[y, x]
                for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                    xx, yy = x + dx, y + dy
                    if 0 <= xx < W_ and 0 <= yy < H_ and a[yy, xx] and depth[yy, xx] < d0 - 2.2:
                        out[y, x, :3] = img[y, x, :3] * 0.62
                        break
                continue
            nb = []
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                xx, yy = x + dx, y + dy
                if 0 <= xx < W_ and 0 <= yy < H_ and a[yy, xx]:
                    nb.append(img[yy, xx, :3])
            if nb:
                c = min(nb, key=lambda c: c.sum())
                out[y, x, :3] = c * 0.32 + np.array([6, 4, 10])
                out[y, x, 3] = 255
    return out.clip(0, 255).astype(np.uint8)


# ---------------------------------------------------------------- the sheet (order = player.gd SHEET)
DOWN, UP, RIGHT, DIAG = 0, 180, 90, 38


def main():
    frames = []
    frames.append(render(DOWN, {}))
    frames.append(render(UP, {}))
    frames.append(render(RIGHT, {}))
    for ang in (DOWN, UP, RIGHT):
        for i in range(4):
            frames.append(render(ang, {'walk': i}))
    # attack: the weapon arm is a separate cut-out (cheoyong_arm.png) and the 대금 is in hand
    frames.append(render(DOWN, {'armless': 'L', 'flute': False}))
    frames.append(render(UP, {'armless': 'L', 'flute': False}))
    frames.append(render(RIGHT, {'armless': 'L', 'flute': False}))  # the near arm
    frames.append(render(DIAG, {}))
    frames.append(render(DIAG, {'breath': True}))
    frames.append(render(-DIAG, {}))
    frames.append(render(-DIAG, {'breath': True}))
    sheet = Image.new('RGBA', (W * len(frames), H), (0, 0, 0, 0))
    for i, f in enumerate(frames):
        sheet.paste(Image.fromarray(f, 'RGBA'), (i * W, 0))
    sheet.save(GODOT / 'cheoyong.png')
    print(f'cheoyong.png  {len(frames)} frames (3D figure → HD-2D pixels)')
    if '--preview' in sys.argv:
        k = int(sys.argv[sys.argv.index('--preview') + 1])
        bg = Image.new('RGBA', sheet.size, (38, 44, 58, 255))
        bg.alpha_composite(sheet)
        bg.resize((sheet.width * k, sheet.height * k), Image.NEAREST).save(ROOT / 'out' / 'cheoyong_hero_preview.png')


if __name__ == '__main__':
    main()
