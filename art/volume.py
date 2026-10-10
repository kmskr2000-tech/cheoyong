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
Materials (from the palette keys the pixel grid was drawn with, when the frame carries them):
  * cloth   — soft draped folds and a fine weave, so a robe reads as fabric, not a paper cut-out
  * silk    — the shawl/trim: smoother, with a brighter sheen on the lit side
  * hair    — a sheen band where the light crosses it; skin — warm shadows (blood under the skin)
  * metal   — gold catches a hard glint
  * outline — sel-out: the outline takes a dark shade of the colour beside it instead of black,
              and the inner lines go softer still (only the eyes stay ink)
  * grade   — muted HD-2D palette: saturation eased, crushed darks lifted a little
The light is baked, so these sheets get no normal map
(art/normals.py skips them): a normal map darkened the figures under the night's low lights.
"""
import math
from PIL import Image

INK_MAX = 34
L = (-0.55, 0.55, 0.63)                       # light: left, up (toward the top of the image), front
_ln = math.sqrt(sum(c * c for c in L)); L = tuple(c / _ln for c in L)
STEPS = (0.64, 0.84, 1.02, 1.2)              # posterized light levels
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


MATERIAL = {}
for _k in 'defgG': MATERIAL[_k] = 'cloth'
for _k in 'tTuUrRqQ': MATERIAL[_k] = 'silk'
for _k in 'hijJ': MATERIAL[_k] = 'hair'
for _k in '1234': MATERIAL[_k] = 'skin'
for _k in 'yYZ': MATERIAL[_k] = 'metal'
for _k in 'bB': MATERIAL[_k] = 'leather'
for _k in 'pP': MATERIAL[_k] = 'wood'
MATERIAL['o'] = 'ink'
MATERIAL['k'] = 'eye'


def _hash(x, y):
    return ((x * 73856093) ^ (y * 19349663)) % 1000 / 1000.0


def _grade(r, g, b, sat=0.82, lift=10):
    """Muted HD-2D palette: ease saturation toward the pixel's own grey, lift the crushed darks."""
    l = 0.3 * r + 0.59 * g + 0.11 * b
    r, g, b = (l + (v - l) * sat for v in (r, g, b))
    return tuple(max(0, min(255, int(v * (1 - lift / 255) + lift))) for v in (r, g, b))


def _material_light(mat, x, y, f, lam, top):
    """Extra light from the surface: folds and weave on cloth, sheen on silk and hair, glint on gold."""
    if mat == 'cloth':
        # broad drapes falling from the shoulders and swinging out at the hem, plus a 1px weave
        fold = math.sin(x * 0.78 + y * 0.2 + math.sin(y * 0.15) * 1.8)
        if fold > 0.82:
            f *= 0.84                                   # a crease: the cloth turns away from the light
        elif fold < -0.88:
            f *= 1.10                                   # the ridge of a fold catches it
        f *= 1.0 + (0.025 if (x + y) % 2 == 0 else -0.025)   # weave, barely there
    elif mat == 'silk':
        f *= 1.0 + 0.06 * math.sin(x * 0.6 + y * 0.5)
        if lam > 0.72:
            f *= 1.12                                   # silk shines where the light lands
    elif mat == 'hair':
        if 0.55 < lam < 0.8 and top:
            f *= 1.22                                   # sheen band
        f *= 1.0 + ((x + y * 2) % 3 == 0) * 0.06        # strands
    elif mat == 'metal':
        f = 1.35 if lam > 0.7 else 0.75                 # hard metal: bright or dark, little between
    elif mat == 'leather':
        f *= 1.0 + (_hash(x, y) - 0.5) * 0.1
    return f


def _sel_out(src, op, mat, x, y, w, h):
    """Colour for an outline pixel: a dark shade of the lightest material it borders."""
    best = None
    outer = False
    for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
        xx, yy = x + dx, y + dy
        if xx < 0 or yy < 0 or xx >= w or yy >= h or not op[yy][xx]:
            outer = True
            continue
        if mat.get((xx, yy)) in ('ink', 'eye'):
            continue
        c = src[xx, yy]
        if best is None or sum(c[:3]) > sum(best[:3]):
            best = c
    if best is None:
        return None
    k = 0.26 if outer else 0.5                        # the silhouette stays strong, inner lines soften
    return (int(best[0] * k * 0.95 + 4), int(best[1] * k * 0.9 + 3), int(best[2] * k * 1.1 + 8))


def shade(frame):
    """Return a shaded copy of one sprite frame (RGBA)."""
    keys = frame.info.get('rows')
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
    mat = {}
    if keys:
        for y, r in enumerate(keys):
            for x, ch in enumerate(r):
                if ch != '.':
                    mat[(x, y)] = MATERIAL.get(ch, 'other')
    for (x, y), (nx, ny, nz) in n.items():
        c = src[x, y]
        m = mat.get((x, y))
        if m == 'ink':
            sc = _sel_out(src, op, mat, x, y, w, h)
            if sc:
                px[x, y] = sc + (c[3],)
            continue
        if _ink(c) or m == 'eye':
            continue
        lam = max(0.0, nx * L[0] + ny * L[1] + nz * L[2])
        f = 0.50 + 0.80 * lam
        f = min(STEPS, key=lambda s: abs(s - f))
        top = _edge(src, op, x, y, 0, -1, w, h) or (y > 0 and mat.get((x, y - 1)) not in (m, None))
        f = _material_light(m, x, y, f, lam, top)
        # layer shadows: whatever lies over this pixel up and to the left (belt, collar, shawl, hat
        # brim, the arm) casts a short shadow down-right onto it — layers instead of one flat sheet
        if m in ('cloth', 'silk', 'skin', 'leather'):
            for dx, dy, k in ((0, -1, 0.80), (-1, -1, 0.86), (0, -2, 0.90), (-1, 0, 0.88)):
                o = mat.get((x + dx, y + dy))
                if o is not None and o != m and o not in ('eye',) and not (o == 'ink' and _edge(src, op, x + dx, y + dy, dx or -1, dy, w, h)):
                    f *= k
                    break
        if m == 'cloth':                                # the robe darkens from chest to hem
            f *= 1.06 - 0.16 * max(0.0, (y - 16) / max(1, bottom - 16))
        tint = SHADE_TINT if f < 0.95 else LIT_TINT if f > 1.05 else (1, 1, 1)
        if m == 'skin' and f < 0.95:
            tint = (1.02, 0.9, 0.9)                     # warm shadow: blood under the skin
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
        r, g, b = _grade(r, g, b, sat=0.95 if m in ('skin', 'metal') else 0.88, lift=7)
        px[x, y] = (r, g, b, c[3])
    return out
