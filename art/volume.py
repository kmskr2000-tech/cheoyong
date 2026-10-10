"""HD-2D volume pass for character sprites (옥토패스식 입체감).

Flat pixel sprites read as cut paper; HD-2D sprites read as little figures because every part is
shaded as a rounded form under one key light, with a cool rim of moonlight on the far edge.
This pass does that automatically for each frame, after the pixel grid is drawn:

  * form    — each horizontal run of opaque pixels is treated as a cylinder (robe, sleeve, leg),
              the top few pixels of every part tilt up toward the light (shoulders, hat, head)
  * key     — light from the upper left, in front: lit side warmer, shade side cooler (hue shift)
  * steps   — the light is posterized to four steps so it stays pixel art, not airbrush
  * AO      — the lowest rows (hems, feet) sink a little into the ground
  * rim     — a cool 1px rim on the right/upper silhouette (moon behind), a warm glint on the left
Ink (outline) pixels are left alone. The light is baked, so these sheets get no normal map
(art/normals.py skips them): a normal map darkened the figures under the night's low lights.
"""
import math
from PIL import Image

INK_MAX = 34
L = (-0.55, 0.55, 0.63)                       # light: left, up (toward the top of the image), front
_ln = math.sqrt(sum(c * c for c in L)); L = tuple(c / _ln for c in L)
STEPS = (0.68, 0.86, 1.02, 1.18)              # posterized light levels
SHADE_TINT = (0.90, 0.93, 1.08)              # shadows lean blue-violet (the night)
LIT_TINT = (1.06, 1.02, 0.94)                # light leans warm (lanterns)
RIM = (150, 175, 235)                        # moonlight rim
GLINT = (255, 236, 200)


def _ink(c):
    return max(c[:3]) <= INK_MAX


def _normals(im):
    """Per-pixel (nx, ny, nz) from row spans (cylinders) and distance to the top/bottom edge."""
    w, h = im.size
    px = im.load()
    op = [[px[x, y][3] > 0 for x in range(w)] for y in range(h)]
    n = {}
    for y in range(h):
        x = 0
        while x < w:
            if not op[y][x]:
                x += 1
                continue
            x0 = x
            while x < w and op[y][x]:
                x += 1
            x1 = x - 1
            half = max(1.0, (x1 - x0 + 1) / 2.0)
            cx = (x0 + x1) / 2.0
            for xx in range(x0, x1 + 1):
                u = max(-0.95, min(0.95, (xx - cx) / half))
                # distance to open air above / below in this column
                up = 0
                while y - up - 1 >= 0 and op[y - up - 1][xx] and up < 4:
                    up += 1
                dn = 0
                while y + dn + 1 < h and op[y + dn + 1][xx] and dn < 3:
                    dn += 1
                ny = 0.75 * (1 - up / 4.0) if up < 4 else 0.0
                if dn < 2:
                    ny -= 0.35 * (1 - dn / 2.0)
                nx = u
                nz = math.sqrt(max(0.05, 1 - u * u))
                k = math.sqrt(nx * nx + ny * ny + nz * nz)
                n[(xx, y)] = (nx / k, ny / k, nz / k)
    return n, op


def _edge(src, op, x, y, dx, dy, w, h):
    """True when open air lies in direction (dx, dy), past at most one ink outline pixel."""
    for k in (1, 2):
        xx, yy = x + dx * k, y + dy * k
        if xx < 0 or yy < 0 or xx >= w or yy >= h or not op[yy][xx]:
            return True
        if not _ink(src[xx, yy]):
            return False
    return False


def shade(frame):
    """Return a shaded copy of one sprite frame (RGBA)."""
    im = frame.convert('RGBA')
    w, h = im.size
    src = im.load()
    out = im.copy()
    px = out.load()
    n, op = _normals(im)
    rows = [y for y in range(h) if any(op[y])]
    if not rows:
        return out
    bottom = rows[-1]
    for (x, y), (nx, ny, nz) in n.items():
        c = src[x, y]
        if _ink(c):
            continue
        lam = max(0.0, nx * L[0] + ny * L[1] + nz * L[2])
        f = 0.50 + 0.80 * lam
        f = min(STEPS, key=lambda s: abs(s - f))
        tint = SHADE_TINT if f < 0.95 else LIT_TINT if f > 1.05 else (1, 1, 1)
        if y >= bottom - 3:                       # sinks into the ground
            f *= 0.88
        r, g, b = (min(255, int(c[i] * f * tint[i])) for i in range(3))
        # rim: open air to the right / above-right = the far edge, caught by the moon
        right_open = _edge(src, op, x, y, 1, 0, w, h)
        left_open = _edge(src, op, x, y, -1, 0, w, h)
        top_open = _edge(src, op, x, y, 0, -1, w, h)
        if right_open and y < bottom - 2:
            r, g, b = (int(v * 0.55 + rc * 0.45) for v, rc in zip((r, g, b), RIM))
        elif (left_open or top_open) and lam > 0.6 and y < bottom - 4:
            r, g, b = (int(v * 0.75 + gc * 0.25) for v, gc in zip((r, g, b), GLINT))
        px[x, y] = (r, g, b, c[3])
    return out
