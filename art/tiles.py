"""Terrain tiles for the Godot project (16px, dual-grid autotiling).

Every terrain layer is a 1024x256 atlas: row = corner mask (bit0 TL, bit1 TR, bit2 BL, bit3 BR),
column = texture window (the material is a seamless 128x128 texture cut into 8x8 windows, so the
pattern only repeats every 128px). A cell's tile is picked from its four corner vertices.
Hand-dotted stamps (tufts, pebbles, cracks) are scattered over a two-tone base so ground reads
as clusters, not noise. Edges: grass lips cast a shadow, banks get a wet dark rim and foam.

Usage: python3 art/tiles.py -> art/out/tiles/*.png. ground3d.py imports the textures and palettes.
"""
import math, pathlib, random
from PIL import Image

ROOT = pathlib.Path(__file__).parent
OUT = ROOT / 'out' / 'tiles'  # atlases for reference; levels bake ground via ground3d.py
TS, TEX = 16, 128
WIN = TEX // TS  # texture windows per side


def hx(h):
    h = h.lstrip('#')
    return (int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16))


INK = hx('#07060b')
PAL = {  # dark → light; night-time, cold, desaturated, with violet shadows
    'grass': [hx(c) for c in ('#0b1416', '#112022', '#18302e', '#22423a', '#355a46', '#4f7656')],
    'dirt':  [hx(c) for c in ('#120d10', '#1c1519', '#281e21', '#352829', '#46362f', '#5a4636')],
    'stone': [hx(c) for c in ('#0d0e15', '#171a25', '#222636', '#2f3448', '#41475e', '#59607a')],
    'water': [hx(c) for c in ('#04070e', '#070d18', '#0b1526', '#112036', '#1a2f4c', '#2a4668')],
    'wood':  [hx(c) for c in ('#151012', '#211819', '#2e2222', '#3c2e2a', '#4c3a32', '#5e4a3e')],
    'sand':  [hx(c) for c in ('#1a1b24', '#272832', '#363642', '#474652', '#5a5862', '#706c74')],
    'moss':  [hx(c) for c in ('#0c1610', '#132418', '#1d3422', '#2a4a2c')],
    'foam':  hx('#7d93ad'),
}


# ---------------------------------------------------------------- periodic noise
def pnoise(seed, period, cells):
    """Smooth value noise that tiles every `period` px, built on a `cells`x`cells` lattice."""
    rnd = random.Random(seed)
    lat = [[rnd.random() for _ in range(cells)] for _ in range(cells)]
    k = cells / period

    def f(x, y):
        gx, gy = x * k, y * k
        x0, y0 = int(math.floor(gx)), int(math.floor(gy))
        tx, ty = gx - x0, gy - y0
        tx, ty = tx * tx * (3 - 2 * tx), ty * ty * (3 - 2 * ty)
        a = lat[y0 % cells][x0 % cells]; b = lat[y0 % cells][(x0 + 1) % cells]
        c = lat[(y0 + 1) % cells][x0 % cells]; d = lat[(y0 + 1) % cells][(x0 + 1) % cells]
        return a + (b - a) * tx + (c - a) * ty + (a - b - c + d) * tx * ty
    return f


BAYER = [0, 8, 2, 10, 12, 4, 14, 6, 3, 11, 1, 9, 15, 7, 13, 5]


def bay(x, y):
    return BAYER[(y & 3) * 4 + (x & 3)] / 16 - 0.47


# ---------------------------------------------------------------- hand-dotted stamps
# digits are tone offsets added to the local base (+ lighter, - via letters a/b = -1/-2); '.' skip
STAMPS = {
    'clump': [  # leafy clump: lit crown, shadowed skirt
        '....5...5....',
        '...454.454...',
        '..45444544...',
        '.4443443444..',
        '.33433343343.',
        '.2232222322..',
        '..aaaaaaaaa..',
    ],
    'clump_s': [
        '..5..5..',
        '.45445..',
        '4443444.',
        '3333333.',
        '.22222..',
        '..aaaa..',
    ],
    'tuft': [  # night grass blades, lit tips
        '..3....3.',
        '..2.3..2.',
        '.2.22.2..',
        '.1212121.',
        '..11111..',
    ],
    'tuft2': [
        '.3...',
        '.22.3',
        '2122.',
        '1111.',
    ],
    'clover': [
        '.2.2.',
        '23132',
        '.212.',
        '..a..',
    ],
    'pebble': [  # seen at an angle: wide and flat, its shadow falling toward us
        '.233.',
        '12221',
        '.abba',
    ],
    'pebble_s': [
        '23.',
        'aba',
    ],
    'crack': [
        'b....',
        '.bb..',
        '...b.',
        '...bb',
    ],
    'root': [
        'aa....',
        '.1aa..',
        '...1aa',
    ],
}


def stamp(img, name, x, y, size=TEX, base=None):
    """Add tone offsets; with `base`, paint over (later clumps overlap earlier ones like foliage)."""
    rows = STAMPS[name]
    for j, r in enumerate(rows):
        for i, ch in enumerate(r):
            if ch == '.':
                continue
            d = {'a': -1, 'b': -2}.get(ch)
            d = int(ch) - 1 if d is None else d
            px, py = (x + i) % size, (y + j) % size
            img[py][px] = (base + d) if base is not None else img[py][px] + d


def scatter(rnd, n, size=TEX):
    """Jittered grid positions (keeps clusters evenly spread, wraps around)."""
    g = int(math.ceil(math.sqrt(n)))
    cell = size / g
    pts = []
    for gy in range(g):
        for gx in range(g):
            if len(pts) >= n:
                break
            pts.append((int(gx * cell + rnd.random() * cell), int(gy * cell + rnd.random() * cell)))
    return pts


# ---------------------------------------------------------------- materials (128x128 tone maps)
def tone_texture(kind, seed):
    rnd = random.Random(seed)
    big = pnoise(seed, TEX, 4)
    mid = pnoise(seed + 1, TEX, 8)
    t = [[0.0] * TEX for _ in range(TEX)]
    for y in range(TEX):
        for x in range(TEX):
            if kind == 'grass':
                v = 0.6 + big(x, y) * 0.8 + mid(x, y) * 0.4
            elif kind == 'dirt':
                v = 1.7 + big(x, y) * 1.2 + mid(x, y) * 0.9
            elif kind == 'wood':  # 마루 planks: 6px boards with staggered butt joints, grain, rot
                board = y // 6
                v = 2.6 + math.sin(board * 2.7) * 0.35 + mid(x, y) * 0.5
                if y % 6 == 0:
                    v = -9
                elif (x + board * 37) % 64 == 0:
                    v = -9
                elif y % 6 == 1:
                    v += 0.8
                v += math.sin(x * 0.7 + board) * 0.18 + big(x, y) * 0.5
            elif kind == 'sand':  # wind ripples
                v = 2.3 + big(x, y) * 0.9 + math.sin((y + mid(x, y) * 10) * 0.9) * 0.45
            elif kind == 'water':
                v = 1.2 + big(x, y) * 1.0 + mid(x, y * 2) * 0.6
            else:
                v = 2.0
            t[y][x] = v
    if kind == 'grass':
        pts = scatter(rnd, 150)
        pts.sort(key=lambda p: p[1])  # paint back to front so lower clumps overlap upper ones
        for (x, y) in pts:
            b = 0.6 + big(x, y) * 1.0
            stamp(t, rnd.choice(['clump', 'clump_s', 'clump_s', 'tuft']), x, y, base=b)
        for (x, y) in scatter(rnd, 16):
            stamp(t, 'clover', x, y, base=1.2)
    elif kind == 'dirt':
        for (x, y) in scatter(rnd, 36):
            stamp(t, rnd.choice(['pebble', 'pebble_s', 'pebble_s']), x, y)
        for (x, y) in scatter(rnd, 16):
            stamp(t, rnd.choice(['crack', 'root']), x, y)
    elif kind == 'sand':
        for (x, y) in scatter(rnd, 22):
            stamp(t, rnd.choice(['pebble_s', 'pebble_s', 'pebble']), x, y)
    elif kind == 'water':
        for (x, y) in scatter(rnd, 28):  # faint ripple dashes
            L = rnd.randint(3, 6)
            for i in range(L):
                t[y % TEX][(x + i) % TEX] += 1.2 if 0 < i < L - 1 else 0.6
    elif kind == 'stone':
        t = flagstones(seed)
    return t


def flagstones(seed):
    """박석: irregular flat paving stones from a periodic Voronoi, beveled, with mossy joints."""
    rnd = random.Random(seed)
    pts = [(rnd.random() * TEX, rnd.random() * TEX) for _ in range(90)]
    shade = [rnd.random() for _ in pts]
    t = [[0.0] * TEX for _ in range(TEX)]
    owner = [[0] * TEX for _ in range(TEX)]
    for y in range(TEX):
        for x in range(TEX):
            best, second, bi = 1e9, 1e9, 0
            for i, (px, py) in enumerate(pts):
                dx = min(abs(x + 0.5 - px), TEX - abs(x + 0.5 - px))
                dy = min(abs(y + 0.5 - py), TEX - abs(y + 0.5 - py))
                d = math.hypot(dx, dy * 1.2)   # (the ground bake foreshortens depth by ground3d.K)
                if d < best:
                    second, best, bi = best, d, i
                elif d < second:
                    second = d
            owner[y][x] = bi
            edge = second - best
            px_, py_ = pts[bi]
            ddx = ((x + 0.5 - px_ + TEX / 2) % TEX) - TEX / 2
            ddy = ((y + 0.5 - py_ + TEX / 2) % TEX) - TEX / 2
            v = 2.0 + shade[bi] * 1.4
            t[y][x] = v if edge > 1.4 else -9  # -9 marks a joint
    for y in range(TEX):
        for x in range(TEX):
            if t[y][x] == -9:
                continue
            up = t[(y - 1) % TEX][x] == -9
            left = t[y][(x - 1) % TEX] == -9
            dn = t[(y + 1) % TEX][x] == -9
            dn2 = t[(y + 2) % TEX][x] == -9
            right = t[y][(x + 1) % TEX] == -9
            if dn: t[y][x] -= 1.7          # the near edge: each stone's thickness shows as a dark lip
            elif dn2: t[y][x] -= 0.9
            elif up: t[y][x] += 1.2        # the far edge catches the light (thin: it faces away)
            elif left: t[y][x] += 0.6
            elif right: t[y][x] -= 0.6
    return t


def material_rgb(kind, t, x, y):
    v = t[y % TEX][x % TEX]
    pal = PAL[kind]
    if kind == 'stone' and v == -9:
        return PAL['moss'][1] if (x * 7 + y * 13) % 11 == 0 else pal[0]
    i = int(round(v))
    return pal[max(0, min(len(pal) - 1, i))]


# ---------------------------------------------------------------- corner masks
EDGE_N = pnoise(77, TS, 2)  # periodic over one tile → seamless boundaries between tiles


def field(mask, x, y):
    x = min(max(x, 0), TS - 1); y = min(max(y, 0), TS - 1)
    tl, tr, bl, br = (mask >> 0) & 1, (mask >> 1) & 1, (mask >> 2) & 1, (mask >> 3) & 1
    u, v = (x + 0.5) / TS, (y + 0.5) / TS
    f = tl * (1 - u) * (1 - v) + tr * u * (1 - v) + bl * (1 - u) * v + br * u * v
    return f + (EDGE_N(x, y) - 0.5) * 0.3


def inside(mask, x, y):
    if mask == 15: return True
    if mask == 0: return False
    return field(mask, x, y) >= 0.5


def layer_atlas(kind, seed, edge):
    t = tone_texture(kind, seed)
    img = Image.new('RGBA', (TS * WIN * WIN, TS * 16), (0, 0, 0, 0))
    px = img.load()
    for mask in range(16):
        for var in range(WIN * WIN):
            ox, oy = (var % WIN) * TS, (var // WIN) * TS  # texture window
            for y in range(TS):
                for x in range(TS):
                    c = edge(mask, x, y, lambda: material_rgb(kind, t, ox + x, oy + y), t, ox, oy)
                    if c is not None:
                        px[var * TS + x, mask * TS + y] = c + (255,) if len(c) == 3 else c
    return img


def darken(c, k):
    return tuple(int(v * k) for v in c[:3])


def edge_grass(mask, x, y, base, t, ox, oy):
    if inside(mask, x, y):
        if not inside(mask, x, y + 1):  # lit lip blades hanging over the edge
            return PAL['grass'][4] if (x + ox) % 3 else PAL['grass'][3]
        if not inside(mask, x, y - 1) or not inside(mask, x - 1, y) or not inside(mask, x + 1, y):
            return PAL['grass'][1]
        return base()
    # outside: 1px ink, then a soft cast shadow below the grass
    if inside(mask, x, y - 1) or inside(mask, x - 1, y) or inside(mask, x + 1, y):
        if (x * 5 + y) % 4 == 0 and inside(mask, x, y - 1):  # stray blade tips
            return PAL['grass'][3]
        return INK
    if inside(mask, x, y - 2) or inside(mask, x, y - 3):
        return (0, 0, 0, 120)
    return None


def edge_dirt(mask, x, y, base, t, ox, oy):  # land over water
    if inside(mask, x, y):
        if not inside(mask, x, y + 1) or not inside(mask, x, y + 2):  # wet dark bank face
            return darken(PAL['dirt'][1], 0.9) if inside(mask, x, y + 1) else PAL['dirt'][0]
        if not inside(mask, x, y - 1) or not inside(mask, x - 1, y) or not inside(mask, x + 1, y):
            return PAL['dirt'][3]
        return base()
    near = inside(mask, x, y - 1) or inside(mask, x - 1, y) or inside(mask, x + 1, y) or inside(mask, x, y + 1)
    if near:
        return INK
    near2 = inside(mask, x, y - 2) or inside(mask, x - 2, y) or inside(mask, x + 2, y) or inside(mask, x, y + 2)
    if near2 and (x + y * 3) % 4 != 0:  # broken foam ring
        return PAL['foam'] + (170,)
    if inside(mask, x, y - 3) and (x + y) % 3 == 0:
        return PAL['foam'] + (70,)
    return None


def edge_stone(mask, x, y, base, t, ox, oy):
    if inside(mask, x, y):
        border = not inside(mask, x, y + 1) or not inside(mask, x, y - 1) or not inside(mask, x - 1, y) or not inside(mask, x + 1, y)
        if border:
            return PAL['stone'][1] if not inside(mask, x, y + 1) else PAL['stone'][4]
        return base()
    if inside(mask, x, y - 1) or inside(mask, x - 1, y) or inside(mask, x + 1, y) or inside(mask, x, y + 1):
        return INK
    if inside(mask, x, y - 2):
        return (0, 0, 0, 100)
    return None


def edge_full(mask, x, y, base, t, ox, oy):
    return base()


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    layers = {
        'water': layer_atlas('water', 5, edge_full),
        'dirt': layer_atlas('dirt', 11, edge_dirt),
        'stone': layer_atlas('stone', 23, edge_stone),
        'grass': layer_atlas('grass', 31, edge_grass),
    }
    for k, im in layers.items():
        im.save(OUT / f'{k}.png')
    print('tiles:', ', '.join(layers))


if __name__ == '__main__':
    main()
