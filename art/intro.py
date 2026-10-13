"""Painted backgrounds for the intro cinematic and title (480x270, the game's viewport).

intro_sea.png      shot 1: the dark sea floor; 용궁 far away as a silhouette, kelp in front (separate layers)
intro_sea_far.png  the palace silhouette layer (alpha) for parallax
intro_sea_fg.png   foreground kelp / rock silhouettes (alpha)
intro_hall.png     shots 2–3: inside 용궁 — pearl light, coral pillars, the sick-bed dais
intro_night.png    shot 4: the surface at night — moon, swell, far village lights on the shore
title_bg.png       the title screen: moon over the sea, the beach of 개운포 below
Dithered ramps keep it pixel art. Output: src/assets/intro/
"""
import math, pathlib
import numpy as np
from PIL import Image

OUT = pathlib.Path(__file__).parent.parent / 'src' / 'assets' / 'intro'
W, H = 480, 270
BAYER = np.array([[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5]]) / 16.0


def hx(h):
    h = h.lstrip('#'); return np.array([int(h[i:i + 2], 16) for i in (0, 2, 4)], np.float32)


def ramp(*cs):
    return np.stack([hx(c) for c in cs])


def dither(t, pal):
    """t: float field in [0, len(pal)-1] → palette colours with ordered dithering."""
    yy, xx = np.mgrid[0:t.shape[0], 0:t.shape[1]]
    tt = np.clip(t + (BAYER[yy % 4, xx % 4] - 0.5) * 0.9, 0, len(pal) - 1)
    return pal[np.round(tt).astype(int)]


def noise(shape, cell, seed):
    rng = np.random.default_rng(seed)
    gh, gw = shape[0] // cell + 2, shape[1] // cell + 2
    lat = rng.random((gh, gw))
    y = np.arange(shape[0])[:, None] / cell; x = np.arange(shape[1])[None, :] / cell
    y0, x0 = np.floor(y).astype(int), np.floor(x).astype(int)
    ty, tx = y - y0, x - x0
    ty, tx = ty * ty * (3 - 2 * ty), tx * tx * (3 - 2 * tx)
    a = lat[y0, x0]; b = lat[y0, x0 + 1]; c = lat[y0 + 1, x0]; d = lat[y0 + 1, x0 + 1]
    return a + (b - a) * tx + (c - a) * ty + (a - b - c + d) * tx * ty


def save(name, rgb, alpha=None):
    img = np.zeros((rgb.shape[0], rgb.shape[1], 4), np.uint8)
    img[..., :3] = np.clip(rgb, 0, 255)
    img[..., 3] = 255 if alpha is None else alpha
    OUT.mkdir(parents=True, exist_ok=True)
    Image.fromarray(img).save(OUT / f'{name}.png')


yy, xx = np.mgrid[0:H, 0:W]
DEEP = ramp('#010208', '#02050e', '#040a18', '#071226', '#0b1c36', '#122a4a', '#1c3c60')


def _hall(m, win, cx, base, bw, bh, rw, rh):
    """one hall: body, windows, and a hip roof whose eaves curl up at the ends."""
    X = np.arange(m.shape[1])[None, :]; Y = np.arange(m.shape[0])[:, None]
    m |= (np.abs(X - cx) < bw) & (Y > base - bh) & (Y <= base)
    u = np.abs(X - cx) / rw
    top = base - bh - rh
    y_top = top + rh * 0.85 * np.clip((u - 0.3) / 0.7, 0, 1) ** 1.2
    y_eave = base - bh + 2 - 6 * u ** 4
    m |= (u <= 1) & (Y >= y_top) & (Y <= y_eave)
    for k in range(int(-bw + 6), int(bw - 4), 7):          # a row of dim windows
        win |= (X >= cx + k) & (X < cx + k + 3) & (Y > base - bh + 4) & (Y < base - bh + 9)


def palace_silhouette(w, h):
    m = np.zeros((h, w), bool); win = np.zeros((h, w), bool)
    X = np.arange(w)[None, :]; Y = np.arange(h)[:, None]
    base = 178
    m |= Y > base + 14 - 22 * np.exp(-((X - 300) / 150.0) ** 2) + np.sin(X * 0.035) * 5 + np.sin(X * 0.11) * 2  # seabed mound
    _hall(m, win, 300, base - 8, 46, 22, 66, 26)
    _hall(m, win, 300, base - 56, 28, 12, 42, 18)                       # upper storey of the main hall
    _hall(m, win, 210, base - 2, 26, 14, 38, 16)
    _hall(m, win, 390, base - 2, 26, 14, 38, 16)
    _hall(m, win, 150, base + 2, 16, 10, 24, 10)
    _hall(m, win, 450, base + 2, 16, 10, 24, 10)
    return m, win & m


def shot_sea():
    # water: lit from the surface far above, a pearl-glow pooled around the drowned palace
    glow = np.exp(-(((xx - 300) / 150.0) ** 2 + ((yy - 150) / 70.0) ** 2))
    g = (1 - yy / H) * 3.2 + noise((H, W), 40, 1) * 0.8 + glow * 2.6
    g += (np.sin(xx * 0.05 + noise((H, W), 30, 2) * 6) * 0.5 + 0.5) * np.clip(1 - yy / 130.0, 0, 1) * 0.5   # caustic bands near the top
    rgb = dither(g, DEEP)
    rng = np.random.default_rng(31)
    for _ in range(90):                               # marine snow / plankton glints
        px, py = rng.integers(0, W), rng.integers(0, H - 30)
        rgb[py, px] = hx('#2c4e70') if rng.random() > 0.3 else hx('#4a7a98')
    save('intro_sea', rgb)
    far, win = palace_silhouette(W, H)
    # edge light: roofs catch the pearl glow on their upper rims, walls fall into the dark below
    up = far & ~np.roll(far, 1, 0)
    up2 = far & ~np.roll(far, 2, 0) & ~up
    tone = np.clip((1 - (yy - 100) / 120.0), 0, 1)
    col = np.zeros((H, W, 3)) + hx('#0a1c34') * (0.55 + 0.45 * tone[..., None])
    col[up] = hx('#3a7a9c')
    col[up2] = hx('#1e4c70')
    lit = win & (noise((H, W), 9, 3) > 0.3)
    col[lit] = np.where((noise((H, W), 4, 8)[lit] > 0.55)[:, None], hx('#e8b868'), hx('#6ab4c8'))   # warm lamps and pearl-light in the windows
    spire = np.zeros((H, W), bool)                      # a hanging-bell finial on the great roof
    spire |= (np.abs(xx - 300) < 1) & (yy > 92) & (yy < 112)
    spire |= (np.hypot(xx - 300, yy - 90) < 3)
    col[spire] = hx('#c8a050')
    save('intro_sea_far', col, ((far | spire) * 235).astype(np.uint8))
    # mid layer: coral reef and tall sea-fans lit by bioluminescent pearls, between the palace and the kelp
    mid = np.zeros((H, W), bool)
    rng = np.random.default_rng(12)
    for k in range(9):
        x0 = rng.integers(10, W - 10); hgt = rng.integers(22, 62); ph = rng.random() * 6
        for y in range(H - 52 - hgt, H - 52):
            t = (y - (H - 52 - hgt)) / hgt
            for br in (-1, 1):                          # fan-shaped branching
                x = int(x0 + br * (1 - t) * (hgt * 0.35) * math.sin(0.5 + t) + math.sin(y * 0.09 + ph) * 2)
                mid[y, max(0, x - 1):max(0, min(W, x + 2))] = True
            mid[y, max(0, x0 - 2):max(0, min(W, x0 + 3))] = True
    mid |= (yy > H - 52 + np.sin(xx * 0.03 + 1) * 9 - noise((H, W), 18, 17) * 12)
    mcol = np.zeros((H, W, 3)) + hx('#06101e')
    mup = mid & ~np.roll(mid, 1, 0)
    gr = dither(noise((H, W), 6, 40) * 2.2 + (1 - np.clip((yy - (H - 60)) / 60.0, 0, 1)) * 1.2, ramp('#040a14', '#07121f', '#0b1a2c', '#10243a'))
    mcol = np.where(mid[..., None], gr, mcol)
    mcol[mup] = hx('#1c4a66')
    for _ in range(26):                                # glowing sea-pearls and anemone tips
        px, py = rng.integers(0, W), rng.integers(H - 70, H - 20)
        if mid[py, px]:
            mcol[py, px] = hx('#8ad0d8'); mcol[py, min(W - 1, px + 1)] = hx('#3a8aa0'); mcol[max(0, py - 1), px] = hx('#3a8aa0')
    save('intro_sea_mid', mcol, (mid * 255).astype(np.uint8))
    fg = np.zeros((H, W), bool)
    rng = np.random.default_rng(5)
    for k in range(14):                              # kelp fronds rising from the floor
        x0 = rng.integers(0, W); hgt = rng.integers(60, 150); ph = rng.random() * 6
        for y in range(H - hgt, H):
            t = (H - y) / hgt
            x = int(x0 + math.sin(y * 0.05 + ph) * 8 * t)
            wdt = int(3 + (1 - t) * 3)
            fg[y, max(0, x - wdt):max(0, min(W, x + wdt))] = True
    fg |= (yy > H - 8 + np.sin(xx * 0.018) * 6 - noise((H, W), 12, 7) * 26)
    fcol = np.zeros((H, W, 3)) + hx('#010306')
    fup = fg & ~np.roll(fg, 1, 0) | (fg & ~np.roll(fg, 1, 1))
    fcol[fup] = hx('#0c2a40')                          # a thin rim of palace-light on the kelp edges
    save('intro_sea_fg', fcol, (fg * 255).astype(np.uint8))


def shot_hall():
    """Shots 2–3: the 용궁 main hall, a small perspective 3D scene (art/intro_hall3d.py)."""
    import importlib.util
    spec = importlib.util.spec_from_file_location('intro_hall3d', pathlib.Path(__file__).parent / 'intro_hall3d.py')
    mod = importlib.util.module_from_spec(spec); spec.loader.exec_module(mod)
    save('intro_hall', mod.render())


def shot_night(name='intro_night', shore=True):
    SKY = ramp('#020308', '#04060e', '#070b18', '#0c1224', '#141c34', '#202a48')
    horizon = 150
    g = 1.0 + (yy / horizon) * 3.0 + noise((H, W), 50, 4) * 0.5
    moon_d = np.hypot(xx - 340, yy - 52)
    g += np.clip(1 - moon_d / 120, 0, 1) * 1.5
    rgb = dither(g, SKY)
    stars = (np.random.default_rng(9).random((H, W)) > 0.9975) & (yy < horizon - 10)
    rgb[stars] = hx('#8a9ac0')
    moon = moon_d < 13
    rgb[moon] = dither(5.6 - (moon_d / 13) * 1.4 - ((xx - 336) ** 2 + (yy - 48) ** 2 < 30) * 0.6, ramp('#3a4a6a', '#6a7a9a', '#9aa8c0', '#c8d0e0', '#e8ecf4', '#f8faff', '#ffffff'))[moon]
    SEA = ramp('#010206', '#03060e', '#060c1a', '#0a1428', '#12203a', '#1e3252', '#4a6a90', '#9ab0d0')
    sea = yy >= horizon
    d = np.clip((yy - horizon) / (H - horizon), 0, 1)
    swell = np.sin(xx * 0.09 + yy * 0.7) * 0.5 + np.sin(xx * 0.031 - yy * 0.4) * 0.6
    path = np.exp(-((xx - 340) ** 2) / (300 + d * 4000)) * (np.sin(yy * 1.7 + xx * 0.05) > 0.2)
    t = 1.2 + d * 1.8 + swell * 0.5 + path * 4.2
    rgb[sea] = dither(t, SEA)[sea]
    if shore:                                          # the far shore: dark hills, a few village lights
        rise = np.clip((200 - xx) / 200.0, 0, 1) ** 1.6
        hill = horizon - 1 - rise * (16 + noise((H, W), 30, 11) * 10)
        land = (yy > hill) & (yy < horizon)
        rgb[land] = hx('#020306')
        # a fishing village on the far shore: thatched roofs, warm lit windows, and their reflections in the swell
        houses = ((22, 144, 7), (40, 146, 9), (63, 147, 8), (78, 145, 6), (104, 148, 9), (128, 148, 8), (150, 149, 6))
        for (hx_, hy_, hw_) in houses:
            for dy in range(0, 5):                         # roof: a stepped triangle
                w_ = hw_ // 2 + 1 - dy // 2 + 1
                rgb[hy_ - 6 + dy, max(0, hx_ - w_):hx_ + w_ + 1] = hx('#05070d')
            rgb[hy_ - 1:hy_ + 1, hx_ - hw_ // 2:hx_ + hw_ // 2 + 1] = hx('#04060a')
            rgb[hy_ - 1, hx_] = hx('#ffb060'); rgb[hy_ - 1, hx_ + 1] = hx('#c06a28'); rgb[hy_, hx_] = hx('#8a4a1c')
            for k in range(1, 9):                          # reflection streak, broken by the swell
                yy_ = horizon + 2 + k * 2
                if yy_ < H and ((k + hx_) % 3) != 0:
                    rgb[yy_, hx_ - (k % 2): hx_ + 1 + (k % 2)] = hx('#a05a24') if k < 5 else hx('#5a3418')
    save(name, rgb)


def title_bg():
    shot_night('title_bg', shore=False)
    im = np.array(Image.open(OUT / 'title_bg.png'))[..., :3].astype(np.float32)
    beach = yy > 222 - noise((H, W), 40, 13) * 10
    SAND = ramp('#06060a', '#0e0e14', '#18181f', '#24232b', '#33313a')
    im[beach] = dither(1.4 + (yy - 222) / 30.0 + noise((H, W), 5, 14) * 0.8, SAND)[beach]
    foam = (~beach) & (np.roll(beach, 2, 0)) & (noise((H, W), 4, 15) > 0.35)
    im[foam] = hx('#5a7090')
    save('title_bg', im)


if __name__ == '__main__':
    shot_sea(); shot_hall(); shot_night(); title_bg()
    print('intro:', ', '.join(p.name for p in sorted(OUT.glob('*.png'))))
