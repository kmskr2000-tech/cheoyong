"""Tileable pixel textures for the 3D buildings (64 px per metre), palette taken from the building sprites.

Usage: python3 art/gen_textures.py  -> godot/assets/tex/*.png
"""
import os
import numpy as np
from PIL import Image

OUT = os.path.join(os.path.dirname(__file__), "..", "godot", "assets", "tex")
rng = np.random.default_rng(7)


def hexc(h):
    return np.array([int(h[i:i + 2], 16) for i in (1, 3, 5)], float)


def noise(w, h, cell, seed):
    """tileable value noise"""
    r = np.random.default_rng(seed)
    gw, gh = w // cell, h // cell
    g = r.random((gh, gw))
    ys, xs = np.mgrid[0:h, 0:w]
    fx, fy = xs / cell, ys / cell
    x0, y0 = fx.astype(int), fy.astype(int)
    tx, ty = fx - x0, fy - y0
    tx, ty = tx * tx * (3 - 2 * tx), ty * ty * (3 - 2 * ty)
    a = g[y0 % gh, x0 % gw]; b = g[y0 % gh, (x0 + 1) % gw]
    c = g[(y0 + 1) % gh, x0 % gw]; d = g[(y0 + 1) % gh, (x0 + 1) % gw]
    return (a * (1 - tx) + b * tx) * (1 - ty) + (c * (1 - tx) + d * tx) * ty


def fbm(w, h, seed):
    return noise(w, h, 16, seed) * 0.5 + noise(w, h, 8, seed + 1) * 0.3 + noise(w, h, 4, seed + 2) * 0.2


def ramp(t, cols):
    """map 0..1 to a list of colours (posterised like pixel art)"""
    cols = [hexc(c) for c in cols]
    n = len(cols)
    i = np.clip((t * n).astype(int), 0, n - 1)
    return np.stack(cols)[i]


def save(name, rgb):
    Image.fromarray(np.clip(rgb, 0, 255).astype(np.uint8), "RGB").save(os.path.join(OUT, name + ".png"))


def roof_giwa():
    # u along the eave, v down the slope: convex cover tiles (sugiwa) in columns, row joints every 16 px
    w = h = 64
    ys, xs = np.mgrid[0:h, 0:w]
    col = (xs % 16) / 16.0
    bulge = np.sin(col * np.pi)                 # round tile cross-section
    row = (ys % 16) / 16.0
    lip = (row > 0.82).astype(float)            # tile ends catch the light
    t = 0.18 + bulge * 0.55 + lip * 0.2 + (fbm(w, h, 3) - 0.5) * 0.15
    gap = (col < 0.12) | (col > 0.9)
    t[gap] = 0.05
    t[(ys % 16) < 2] *= 0.35                   # dark seam under each tile row
    return ramp(np.clip(t, 0, 0.999), ["#1a1f30", "#262d42", "#343c56", "#46506c", "#5c6886", "#7a86a4"])


def roof_thatch():
    w = h = 64
    ys, xs = np.mgrid[0:h, 0:w]
    strands = noise(w, h, 2, 11)[:, :] * 0.5 + np.sin(xs * 1.7 + noise(w, h, 8, 12) * 6) * 0.25 + 0.25
    layer = ((ys % 21) / 21.0)
    t = strands * 0.7 + layer * 0.35 - 0.05
    return ramp(np.clip(t, 0, 0.999), ["#5e3e1a", "#7a5426", "#966c34", "#ad8444", "#c49c58"])


def wall_hanok(red=False):
    # 2 bays (128 px = 2 m) x full wall height: pillar, top beam, sill, plaster bay and a lattice door bay
    w, h = 128, 128
    ys, xs = np.mgrid[0:h, 0:w]
    plaster = ramp(np.clip(0.55 + (fbm(w, h, 21) - 0.5) * 0.5, 0, .999), ["#cfc4ac", "#ddd3bc", "#e8dfca", "#f1ead8"])
    img = plaster.copy()
    wood = ["#4a2a18", "#5e3820", "#74472a", "#8a5834"] if not red else ["#5a1414", "#7a1e1e", "#932a26", "#a83a30"]
    grain = ramp(np.clip(0.4 + (noise(w, h, 4, 22) - 0.5) * 0.6 + (xs % 3 == 0) * 0.1, 0, .999), wood)
    pillar = (xs % 64) < 8
    beam = (ys < 14) | ((ys > 106) & (ys < 116))
    img[pillar | beam] = grain[pillar | beam]
    # lattice door in the second bay
    door = (xs >= 72) & (xs < 120) & (ys >= 24) & (ys < 104)
    paper = ramp(np.clip(0.6 + (fbm(w, h, 23) - 0.5) * 0.3, 0, .999), ["#d8ccb0", "#e6dcc4", "#f0e8d6"])
    img[door] = paper[door]
    lat = door & ((((xs - 72) % 8) < 2) | (((ys - 24) % 10) < 2) | (xs < 74) | (xs > 117) | (ys < 26) | (ys > 101))
    img[lat] = grain[lat]
    # small window in the plaster bay
    win = (xs >= 22) & (xs < 50) & (ys >= 34) & (ys < 62)
    img[win] = paper[win]
    lw = win & ((((xs - 22) % 7) < 2) | (((ys - 34) % 7) < 2) | (xs > 47) | (ys > 59))
    img[lw] = grain[lw]
    # ground dirt at the foot of the wall
    img[ys > 116] = img[ys > 116] * 0.82
    return img


def wall_mud():
    w, h = 128, 128
    ys, xs = np.mgrid[0:h, 0:w]
    mud = ramp(np.clip(0.5 + (fbm(w, h, 31) - 0.5) * 0.8, 0, .999), ["#8a6440", "#a07650", "#b48a62", "#c49c74"])
    grain = ramp(np.clip(0.4 + (noise(w, h, 4, 32) - 0.5) * 0.6, 0, .999), ["#3e2616", "#54341e", "#6a4428"])
    img = mud
    frame = ((xs % 64) < 7) | (ys < 10) | ((ys > 108) & (ys < 116))
    img[frame] = grain[frame]
    door = (xs >= 76) & (xs < 112) & (ys >= 30) & (ys < 108)
    planks = ramp(np.clip(0.45 + ((xs - 76) % 9 < 1) * -0.3 + (noise(w, h, 3, 33) - 0.5) * 0.4, 0, .999), ["#3a2414", "#5a3a22", "#6e4a2c", "#80583a"])
    img[door] = planks[door]
    return img


def stone_block():
    w = h = 64
    ys, xs = np.mgrid[0:h, 0:w]
    row = ys // 16
    off = (row % 2) * 16
    joint = ((ys % 16) < 2) | (((xs + off) % 32) < 2)
    t = 0.45 + (fbm(w, h, 41) - 0.5) * 0.6 + (noise(w, h, 2, 42) - 0.5) * 0.2
    img = ramp(np.clip(t, 0, .999), ["#6a6a70", "#7e7e86", "#94949a", "#a8a8ae", "#bcbcc0"])
    img[joint] = hexc("#4a4a52")
    return img


def wood():
    w = h = 64
    ys, xs = np.mgrid[0:h, 0:w]
    t = 0.45 + (noise(w, h, 4, 51) - 0.5) * 0.5 + np.sin(ys * 0.9 + noise(w, h, 16, 52) * 8) * 0.12
    img = ramp(np.clip(t, 0, .999), ["#3e2414", "#55331d", "#6c4428", "#825634", "#966a42"])
    img[(xs % 16) == 0] = hexc("#2e1a0e")
    return img


def red_wood():
    w = h = 64
    ys, xs = np.mgrid[0:h, 0:w]
    t = 0.5 + (noise(w, h, 4, 61) - 0.5) * 0.4 + np.sin(ys * 0.8) * 0.06
    return ramp(np.clip(t, 0, .999), ["#601414", "#7a1c1c", "#90281f", "#a43a2a"])


def cloth():
    w = h = 64
    ys, xs = np.mgrid[0:h, 0:w]
    t = 0.55 + (fbm(w, h, 71) - 0.5) * 0.3 + ((xs % 32) < 4) * -0.25
    return ramp(np.clip(t, 0, .999), ["#8a6a40", "#a4845a", "#b89a6c", "#c8ac80"])


def brick():
    w = h = 64
    ys, xs = np.mgrid[0:h, 0:w]
    row = ys // 8
    off = (row % 2) * 8
    joint = ((ys % 8) < 1) | (((xs + off) % 16) < 1)
    t = 0.5 + (fbm(w, h, 81) - 0.5) * 0.5 + (noise(w, h, 8, 82) - 0.5) * 0.3
    img = ramp(np.clip(t, 0, .999), ["#a8582e", "#c06a38", "#d07c44", "#de9052"])
    img[joint] = hexc("#e8d8b8")
    # stone base band
    base = ys > 46
    st = stone_block()
    img[base] = st[base]
    return img


def stone_smooth():
    w = h = 64
    t = 0.5 + (fbm(w, h, 91) - 0.5) * 0.7
    return ramp(np.clip(t, 0, .999), ["#7c7c80", "#909096", "#a4a4a8", "#b6b6b8", "#c6c6c6"])


if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    for name, fn in [("roof_giwa", roof_giwa), ("roof_thatch", roof_thatch), ("wall_hanok", wall_hanok),
                     ("wall_shrine", lambda: wall_hanok(True)), ("wall_mud", wall_mud), ("stone_block", stone_block),
                     ("wood", wood), ("red_wood", red_wood), ("cloth", cloth), ("brick", brick), ("stone_smooth", stone_smooth)]:
        save(name, fn())
    print("ok")
