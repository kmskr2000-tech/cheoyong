"""Combat effects (pixel art, additive in-game): slash crescents and hit sparks.

slash.png  4 frames of 64x64: a crescent of spirit-wind swept by the 대금, opening then thinning out,
           pointing right (+x) — Godot rotates it to the swing direction. Core white, cyan body, blue rim.
spark.png  3 frames of 16x16: a four-pointed star burst for hits.
Output: godot/assets/fx/
"""
import math, pathlib
from PIL import Image

OUT = pathlib.Path(__file__).parent.parent / 'godot' / 'assets' / 'fx'
CORE, BODY, RIM, DEEP = (255, 255, 255, 255), (170, 235, 255, 255), (80, 150, 255, 230), (40, 70, 200, 170)


def slash():
    S = 64
    im = Image.new('RGBA', (S * 4, S), (0, 0, 0, 0))
    p = im.load()
    for f in range(4):
        spread = (0.55, 1.0, 1.25, 1.35)[f]   # how far round the arc has swept (radians each side)
        thick = (4.5, 6.5, 4.5, 2.0)[f]
        r0 = (20, 22, 24, 26)[f]
        for y in range(S):
            for x in range(S):
                dx, dy = x + 0.5 - S / 2, y + 0.5 - S / 2
                a = math.atan2(dy, dx)
                if abs(a) > spread:
                    continue
                r = math.hypot(dx, dy)
                taper = 1 - (abs(a) / spread) ** 2       # thick in the middle, pointed tips
                w = thick * taper
                d = r - r0
                if d < -w * 0.4 or d > w:
                    continue
                t = (d + w * 0.4) / (w * 1.4)          # 0 inner edge → 1 outer edge
                col = CORE if t > 0.55 and taper > 0.5 else BODY if t > 0.3 else RIM if t > 0.12 else DEEP
                if f == 3 and (x + y) % 2:
                    continue                            # dissolving
                p[f * S + x, y] = col
    im.save(OUT / 'slash.png')


def spark():
    S = 16
    im = Image.new('RGBA', (S * 3, S), (0, 0, 0, 0))
    p = im.load()
    for f in range(3):
        L = (4, 7, 5)[f]
        for i in range(-L, L + 1):
            for (x, y) in ((8 + i, 8), (8, 8 + i)):
                c = CORE if abs(i) < 2 else BODY if abs(i) < L - 1 else RIM
                if f == 2 and abs(i) < 2:
                    c = BODY
                p[f * S + x, y] = c
        if f == 1:
            for (x, y) in ((6, 6), (10, 6), (6, 10), (10, 10)):
                p[f * S + x, y] = BODY
    im.save(OUT / 'spark.png')


if __name__ == '__main__':
    OUT.mkdir(parents=True, exist_ok=True)
    slash(); spark()
    print('fx: slash, spark')
