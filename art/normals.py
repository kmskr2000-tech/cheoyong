"""Normal maps for every sprite, prop and tile atlas, so Godot's 2D lights shade them with real volume.

Height model:
  * sprites / props: each part (pixels between ink outlines) is a rounded pillow — height grows with
    distance from the silhouette or an inner ink line, capped at RADIUS — plus a little relief from
    the painted luminance (lit tones sit higher). Ink outline pixels are creases (height 0).
  * tiles: luminance relief only, computed per 16px tile with clamped borders so tiles stay seamless.
Writes <name>_n.png next to each source PNG (OpenGL convention: +Y is up, as Godot expects).
"""
import math, pathlib
from PIL import Image

GODOT = pathlib.Path(__file__).parent.parent / 'godot' / 'assets'
INK_MAX = 34
VOXEL = {'house', 'terrace', 'lantern', 'jangseung_m', 'jangseung_f', 'dodam'}  # pixels darker than this (max channel) are treated as outline / crease


def lum(c):
    return (0.3 * c[0] + 0.59 * c[1] + 0.11 * c[2]) / 255


def chamfer(w, h, solid, radius):
    INF = 99.0
    d = [[0.0 if not solid(x, y) else INF for x in range(w)] for y in range(h)]
    for y in range(h):
        for x in range(w):
            if d[y][x]:
                v = d[y][x]
                if x > 0: v = min(v, d[y][x - 1] + 1)
                if y > 0: v = min(v, d[y - 1][x] + 1)
                if x > 0 and y > 0: v = min(v, d[y - 1][x - 1] + 1.41)
                if x < w - 1 and y > 0: v = min(v, d[y - 1][x + 1] + 1.41)
                d[y][x] = v
    for y in range(h - 1, -1, -1):
        for x in range(w - 1, -1, -1):
            if d[y][x]:
                v = d[y][x]
                if x < w - 1: v = min(v, d[y][x + 1] + 1)
                if y < h - 1: v = min(v, d[y + 1][x] + 1)
                if x < w - 1 and y < h - 1: v = min(v, d[y + 1][x + 1] + 1.41)
                if x > 0 and y < h - 1: v = min(v, d[y + 1][x - 1] + 1.41)
                d[y][x] = v
    out = [[0.0] * w for _ in range(h)]
    for y in range(h):
        for x in range(w):
            t = min(d[y][x], radius) / radius
            out[y][x] = math.sqrt(max(0.0, 1 - (1 - t) ** 2)) * radius
    return out


def encode(img_size, hgt, alpha, strength):
    w, h = img_size
    out = Image.new('RGBA', (w, h), (128, 128, 255, 0))
    p = out.load()
    for y in range(h):
        for x in range(w):
            if not alpha(x, y):
                continue
            hl = hgt[y][max(0, x - 1)]; hr = hgt[y][min(w - 1, x + 1)]
            hu = hgt[max(0, y - 1)][x]; hd = hgt[min(h - 1, y + 1)][x]
            nx = -(hr - hl) * 0.5 * strength
            ny = (hd - hu) * 0.5 * strength  # +Y up
            nz = 1.0
            n = math.sqrt(nx * nx + ny * ny + nz * nz)
            p[x, y] = (int((nx / n * 0.5 + 0.5) * 255), int((ny / n * 0.5 + 0.5) * 255), int((nz / n * 0.5 + 0.5) * 255), 255)
    return out


def sprite_normals(path, radius=3.5, strength=0.9, relief=1.4):
    im = Image.open(path).convert('RGBA')
    w, h = im.size
    px = im.load()
    opaque = lambda x, y: px[x, y][3] > 0
    inner = lambda x, y: px[x, y][3] > 0 and max(px[x, y][:3]) > INK_MAX
    base = chamfer(w, h, inner, radius)
    hgt = [[base[y][x] + (lum(px[x, y]) * relief if inner(x, y) else 0) for x in range(w)] for y in range(h)]
    encode((w, h), hgt, opaque, strength).save(path.with_name(path.stem + '_n.png'))


def tile_normals(path, relief=3.2, strength=1.0, ts=16):
    im = Image.open(path).convert('RGBA')
    w, h = im.size
    px = im.load()
    out = Image.new('RGBA', (w, h), (128, 128, 255, 0))
    for ty in range(0, h, ts):
        for tx in range(0, w, ts):
            hgt = [[lum(px[tx + x, ty + y]) * relief if px[tx + x, ty + y][3] else 0 for x in range(ts)] for y in range(ts)]
            tile = encode((ts, ts), hgt, lambda x, y: px[tx + x, ty + y][3] > 0, strength)
            out.paste(tile, (tx, ty))
    out.save(path.with_name(path.stem + '_n.png'))


def main():
    done = []
    for path in sorted((GODOT / 'sprites').glob('*.png')) + sorted((GODOT / 'props').glob('*.png')):
        if path.stem.endswith(('_n', '_glow')):
            continue
        if path.stem in VOXEL:  # art/vox.py writes true geometric normals for these
            continue
        big = path.parent.name == 'props'
        sprite_normals(path, radius=5.0 if big else 3.5)
        done.append(path.stem)
    for path in sorted((GODOT / 'tiles').glob('*.png')):
        if path.stem.endswith('_n'):
            continue
        tile_normals(path, relief=1.2 if path.stem == 'water' else 3.2)
        done.append(path.stem)
    print('normals:', ', '.join(done))


if __name__ == '__main__':
    main()
