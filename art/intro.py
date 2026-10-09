"""Painted backgrounds for the intro cinematic and title (480x270, the game's viewport).

intro_sea.png      shot 1: the dark sea floor; 용궁 far away as a silhouette, kelp in front (separate layers)
intro_sea_far.png  the palace silhouette layer (alpha) for parallax
intro_sea_fg.png   foreground kelp / rock silhouettes (alpha)
intro_hall.png     shots 2–3: inside 용궁 — pearl light, coral pillars, the sick-bed dais
intro_night.png    shot 4: the surface at night — moon, swell, far village lights on the shore
title_bg.png       the title screen: moon over the sea, the beach of 개운포 below
Dithered ramps keep it pixel art. Output: godot/assets/intro/
"""
import math, pathlib
import numpy as np
from PIL import Image

OUT = pathlib.Path(__file__).parent.parent / 'godot' / 'assets' / 'intro'
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
    g = (1 - yy / H) * 3.2 + noise((H, W), 40, 1) * 0.8 + np.exp(-((xx - 300) ** 2) / 9000.0) * (1 - yy / H) * 1.5
    rgb = dither(g, DEEP)
    save('intro_sea', rgb)
    far, win = palace_silhouette(W, H)
    col = np.zeros((H, W, 3)) + hx('#08162a')
    col[win & (noise((H, W), 9, 3) > 0.35)] = hx('#4a7a98')   # faint lit windows in the drowned palace
    save('intro_sea_far', col, (far * 210).astype(np.uint8))
    fg = np.zeros((H, W), bool)
    rng = np.random.default_rng(5)
    for k in range(14):                              # kelp fronds rising from the floor
        x0 = rng.integers(0, W); hgt = rng.integers(60, 150); ph = rng.random() * 6
        for y in range(H - hgt, H):
            t = (H - y) / hgt
            x = int(x0 + math.sin(y * 0.05 + ph) * 8 * t)
            wdt = int(3 + (1 - t) * 3)
            fg[y, max(0, x - wdt):min(W, x + wdt)] = True
    fg |= (yy > H - 26 + np.sin(xx * 0.018) * 8 - noise((H, W), 24, 7) * 14)
    save('intro_sea_fg', np.zeros((H, W, 3)) + hx('#010306'), (fg * 255).astype(np.uint8))


def shot_hall():
    PEARL = ramp('#03060c', '#081020', '#0e1c34', '#18304e', '#244668', '#3a6488', '#5a88a8', '#8ab4c8')
    g = 2.2 + np.exp(-((xx - 240) ** 2 + (yy - 90) ** 2 * 2) / 14000.0) * 3.5 + noise((H, W), 30, 2) * 0.6
    floor = yy > 182
    g = np.where(floor, 1.6 + ((xx + (yy - 182) * 2) // 24 + (yy - 182) // 10) % 2 * 0.5 + np.exp(-((xx - 240) ** 2) / 9000.0) * 1.5 - (yy - 182) * 0.012, g)
    rgb = dither(g, PEARL)
    CORAL = ramp('#12060c', '#2a0e18', '#4a1824', '#6e2830', '#94403a')
    for cx in (52, 128, 352, 428):                    # coral-red pillars with a pearl band
        u = (xx - cx) / 11.0
        m = (np.abs(u) < 1) & (yy < 190)
        t = 2.6 - u * 1.6 + np.where(np.abs(yy - 40) < 4, 1.5, 0) - (yy > 170) * 0.8
        rgb[m] = dither(t, CORAL)[m]
    dais = (yy > 150) & (yy < 196) & (np.abs(xx - 240) < 120 - (196 - yy) * 0.6)
    rgb[dais] = dither(1.8 + (yy - 150) / 46.0 + (np.abs(xx - 240) < 90) * 0.5, ramp('#0a0c14', '#161a28', '#242a40', '#343c58'))[dais]
    bed = (yy > 132) & (yy < 158) & (np.abs(xx - 240) < 70)
    rgb[bed] = dither(2.0 + (yy < 136) * 1.6 - np.abs(xx - 240) / 70.0, ramp('#1a1420', '#2e2438', '#4a3c58', '#6e5c80', '#9a88a8'))[bed]
    for side in (-1, 1):                              # drapes falling either side of the bed
        dr = (np.abs(xx - (240 + side * 92)) < 16 - (yy - 40) * 0.02) & (yy > 30) & (yy < 160)
        rgb[dr] = dither(2.2 + np.sin(xx * 0.5) * 0.6, ramp('#0c1a24', '#142c3a', '#1e4250', '#2c5a66'))[dr]
    save('intro_hall', rgb)


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
        for (lx, ly) in ((40, 146), (62, 147), (75, 145), (108, 148), (130, 147)):
            rgb[ly, lx] = hx('#ffb060'); rgb[ly, lx + 1] = hx('#c06a28')
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
