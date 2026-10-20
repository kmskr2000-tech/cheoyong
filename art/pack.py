"""Pack PixelLab exports into game atlases: src/assets/{chars,tiles,props}/*.png + manifest.json"""
import base64, glob, io, json, os
from PIL import Image

ROOT = os.path.join(os.path.dirname(__file__), "..")
RAW = os.path.join(ROOT, "art", "raw")
OUT = os.path.join(ROOT, "src", "assets")
DIRS = ["south", "south-east", "east", "north-east", "north", "north-west", "west", "south-west"]


def anim_key(folder):
    f = folder.lower()
    if f.startswith("walking") or f == "walk":
        return "walk"
    if f.startswith("breathing"):
        return "idle_anim"
    return f


def bbox_bottom(im):
    b = im.getbbox()
    return b[3] if b else im.height


# chibi cast is drawn at roughly half size, smoothed, like a prerendered 3D sprite
CHIBI_SCALE = {"dokchief": 0.62, "gumiho": 0.6, "imugi": 0.62, "yeoksin": 0.6, "dog": 0.42, "child": 0.5, "imp": 0.55}


def pack_char(name):
    chibi = os.path.isdir(os.path.join(RAW, "chibi", name))
    base = os.path.join(RAW, "chibi" if chibi else "chars", name)
    meta_p = os.path.join(base, "metadata.json")
    if not os.path.exists(meta_p):
        return None
    meta = json.load(open(meta_p))
    state = meta["states"][0]
    fr = state["frames"]
    seqs = {"idle": {d: [os.path.join(base, p)] for d, p in fr["rotations"].items()}}
    for folder, dirs in (fr.get("animations") or {}).items():
        k = anim_key(folder)
        if k == "taking_a_punch":
            continue
        seqs.setdefault(k, {})
        for d, paths in dirs.items():
            seqs[k][d] = [os.path.join(base, p) for p in paths]
    imgs = {k: {d: [Image.open(p).convert("RGBA") for p in ps] for d, ps in v.items()} for k, v in seqs.items()}
    # template animations come out ~5-15% smaller than the rotations: scale them back to the standing height
    def bh(im):
        b = im.getbbox()
        return (b[3] - b[1]) if b else im.height
    for k, v in imgs.items():
        if k == "idle":
            continue
        for d, ims in v.items():
            ref = imgs["idle"].get(d) or imgs["idle"]["south"]
            ratio = bh(ref[0]) / max(1, bh(ims[0]))
            if 1.04 < ratio < 1.4:
                v[d] = [im.resize((round(im.width * ratio), round(im.height * ratio)), Image.NEAREST) for im in ims]
    cell = max(im.width for v in imgs.values() for ps in v.values() for im in ps)
    cellh = max(im.height for v in imgs.values() for ps in v.values() for im in ps)
    cell = max(cell, cellh)
    idle_bottom = {d: bbox_bottom(ims[0]) + (cell - ims[0].height) // 2 for d, ims in imgs["idle"].items()}
    rows = [(k, d) for k in imgs for d in DIRS if d in imgs[k]]
    ncol = max(len(imgs[k][d]) for k, d in rows)
    sheet = Image.new("RGBA", (ncol * cell, len(rows) * cell))
    anims = {}
    for r, (k, d) in enumerate(rows):
        ims = imgs[k][d]
        ox = (cell - ims[0].width) // 2
        oy = (cell - ims[0].height) // 2
        if k != "idle":
            # keep the feet on the same line as the standing pose
            fb = bbox_bottom(ims[0]) + oy
            oy += idle_bottom.get(d, idle_bottom["south"]) - fb
        anims.setdefault(k, {})[d] = []
        for c, im in enumerate(ims):
            sheet.alpha_composite(im, (c * cell + ox, r * cell + oy))
            anims[k][d].append([c * cell, r * cell])
    os.makedirs(os.path.join(OUT, "chars"), exist_ok=True)
    sheet.save(os.path.join(OUT, "chars", name + ".png"), optimize=True)
    south = imgs["idle"]["south"][0]
    b = south.getbbox()
    off = (cell - south.width) // 2
    return {"file": f"chars/{name}.png", "w": cell, "h": cell, "foot": idle_bottom["south"],
            "scale": CHIBI_SCALE.get(name, 0.5) if chibi else 1,
            "top": b[1] + off, "cx": (b[0] + b[2]) // 2 + off, "bw": b[2] - b[0], "anims": anims}


def night_grade(img, sat=0.72, bright=0.8, tint=(0.92, 0.96, 1.12)):
    """Pull terrain toward a moonlit palette so characters and props read clearly on top."""
    from PIL import ImageEnhance
    a = img.getchannel("A")
    rgb = ImageEnhance.Color(img.convert("RGB")).enhance(sat)
    rgb = ImageEnhance.Brightness(rgb).enhance(bright)
    r, g, b = rgb.split()
    r = r.point(lambda v: min(255, int(v * tint[0])))
    g = g.point(lambda v: min(255, int(v * tint[1])))
    b = b.point(lambda v: min(255, int(v * tint[2])))
    out = Image.merge("RGB", (r, g, b)).convert("RGBA")
    out.putalpha(a)
    return out


def pack_tiles(name):
    p64 = os.path.join(RAW, "tiles64", name + ".json")
    painted = os.path.exists(p64)
    p = p64 if painted else os.path.join(RAW, "tiles", name + ".json")
    if not os.path.exists(p):
        return None
    t = json.load(open(p))["tileset"]
    tiles = t["tiles"]
    size = 64 if painted else 32
    sheet = Image.new("RGBA", (4 * size, ((len(tiles) + 3) // 4) * size))
    corners = []
    for i, tl in enumerate(tiles):
        im = tl["image"]
        b64 = im["base64"] if isinstance(im, dict) else im
        img = Image.open(io.BytesIO(base64.b64decode(b64))).convert("RGBA")
        sheet.alpha_composite(img, ((i % 4) * size, (i // 4) * size))
        c = tl["corners"]
        corners.append("".join("1" if c[k] == "upper" else "0" for k in ("NW", "NE", "SW", "SE")))
    sheet = night_grade(sheet) if not painted else night_grade(sheet, sat=0.85, bright=0.96, tint=(1.02, 1.0, 0.96))
    os.makedirs(os.path.join(OUT, "tiles"), exist_ok=True)
    sheet.save(os.path.join(OUT, "tiles", name + ".png"), optimize=True)
    return {"file": f"tiles/{name}.png", "tiles": corners, "size": size}


def clear_border_bg(im, tol=34):
    """flood-fill the flat background colour from the image border to transparent"""
    w, h = im.size
    px = im.load()
    bg = px[0, 0]
    near = lambda c: c[3] > 0 and sum(abs(c[i] - bg[i]) for i in range(3)) <= tol
    stack = [(x, y) for x in range(w) for y in (0, h - 1)] + [(x, y) for y in range(h) for x in (0, w - 1)]
    seen = set()
    while stack:
        x, y = stack.pop()
        if (x, y) in seen or not (0 <= x < w and 0 <= y < h):
            continue
        seen.add((x, y))
        if not near(px[x, y]):
            continue
        px[x, y] = (0, 0, 0, 0)
        stack += [(x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)]
    return im


def pack_prop(path):
    name = os.path.splitext(os.path.basename(path))[0]
    im = Image.open(path).convert("RGBA")
    if im.getpixel((0, 0))[3] > 0:
        im = clear_border_bg(im)
    b = im.getbbox()
    if not b:
        return name, None
    im = im.crop(b)
    os.makedirs(os.path.join(OUT, "props"), exist_ok=True)
    im.save(os.path.join(OUT, "props", name + ".png"), optimize=True)
    return name, {"file": f"props/{name}.png", "w": im.width, "h": im.height, "ax": im.width // 2, "ay": im.height - 2, "bw": im.width}


def main():
    man = {"chars": {}, "tiles": {}, "props": {}, "images": {}}
    names = {os.path.basename(d) for d in glob.glob(os.path.join(RAW, "chars", "*")) + glob.glob(os.path.join(RAW, "chibi", "*")) if os.path.isdir(d)}
    for n in sorted(names):
        c = pack_char(n)
        if c:
            man["chars"][n] = c
    for p in sorted(set(glob.glob(os.path.join(RAW, "tiles", "*.json")))):
        n = os.path.splitext(os.path.basename(p))[0]
        t = pack_tiles(n)
        if t:
            man["tiles"][n] = t
    props = {os.path.basename(p): p for p in glob.glob(os.path.join(RAW, "props", "*.png"))}
    props.update({os.path.basename(p): p for p in glob.glob(os.path.join(RAW, "props2", "*.png"))})
    for p in sorted(props.values()):
        n, v = pack_prop(p)
        if v and "props2" in p:
            v["scale"] = 0.36 if n in ("tuft", "tuft2", "flowers") else 0.5
        if v:
            man["props"][n] = v
    for p in sorted(glob.glob(os.path.join(RAW, "images", "*.png"))):
        n = os.path.splitext(os.path.basename(p))[0]
        os.makedirs(os.path.join(OUT, "images"), exist_ok=True)
        Image.open(p).save(os.path.join(OUT, "images", n + ".png"), optimize=True)
        man["images"][n] = f"images/{n}.png"
    json.dump(man, open(os.path.join(OUT, "manifest.json"), "w"), separators=(",", ":"))
    print("chars", list(man["chars"]), "\ntiles", list(man["tiles"]), "\nprops", len(man["props"]))


if __name__ == "__main__":
    main()
