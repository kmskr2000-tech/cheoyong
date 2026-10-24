"""Turn Blender renders into a PixelLab-style export: art/raw/chibi/<name>/Idle/{rotations,animations}/ + metadata.json.

Renders (<render_dir>/<anim>/<dir>/frame_NNN.png, 'idle' = rotations) are shrunk to the cast's canvas,
alpha is hardened to pixel edges, and a 1px dark outline is drawn like the PixelLab chibi sprites.
Usage: python3 art/b3d/post.py <name> <render_dir> [--size 128] [--prompt "..."]
"""
import glob, json, os, shutil, sys
from PIL import Image, ImageEnhance, ImageFilter

RAW = os.path.join(os.path.dirname(__file__), "..", "raw", "chibi")
DIRS8 = ["south", "south-east", "east", "north-east", "north", "north-west", "west", "south-west"]


def pixelize(im, size):
    im = im.convert("RGBA").resize((size, size), Image.LANCZOS)
    im = ImageEnhance.Contrast(im).enhance(1.08)
    im = im.filter(ImageFilter.UnsharpMask(radius=1, percent=60, threshold=2))
    px = im.load()
    w, h = im.size
    for y in range(h):
        for x in range(w):
            r, g, b, a = px[x, y]
            px[x, y] = (r, g, b, 255) if a >= 110 else (0, 0, 0, 0)
    alpha = im.getchannel("A")
    im = im.convert("RGB").quantize(40, method=Image.Quantize.MEDIANCUT).convert("RGBA")
    im.putalpha(alpha)
    px = im.load()
    out = im.copy()
    po = out.load()
    for y in range(h):
        for x in range(w):
            if px[x, y][3]:
                continue
            nb = [px[x + dx, y + dy] for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)) if 0 <= x + dx < w and 0 <= y + dy < h]
            nb = [p for p in nb if p[3]]
            if nb:
                r = sum(p[0] for p in nb) // len(nb)
                g = sum(p[1] for p in nb) // len(nb)
                b = sum(p[2] for p in nb) // len(nb)
                po[x, y] = (r * 30 // 100 + 8, g * 28 // 100 + 6, b * 32 // 100 + 12, 255)
    return out


def main():
    a = sys.argv[1:]
    name, src = a[0], a[1]
    size = int(a[a.index("--size") + 1]) if "--size" in a else 128
    prompt = a[a.index("--prompt") + 1] if "--prompt" in a else name
    base = os.path.join(RAW, name)
    shutil.rmtree(os.path.join(base, "Idle"), ignore_errors=True)
    rot, anims = {}, {}
    for d in DIRS8:
        p = os.path.join(src, "idle", d, "frame_000.png")
        if os.path.exists(p):
            rel = f"Idle/rotations/{d}.png"
            os.makedirs(os.path.join(base, "Idle", "rotations"), exist_ok=True)
            pixelize(Image.open(p), size).save(os.path.join(base, rel))
            rot[d] = rel
    for adir in sorted(glob.glob(os.path.join(src, "*"))):
        anim = os.path.basename(adir)
        if anim == "idle":
            continue
        for d in DIRS8:
            frames = sorted(glob.glob(os.path.join(adir, d, "frame_*.png")))
            if not frames:
                continue
            paths = []
            for i, f in enumerate(frames):
                rel = f"Idle/animations/{anim}/{d}/frame_{i:03d}.png"
                os.makedirs(os.path.dirname(os.path.join(base, rel)), exist_ok=True)
                pixelize(Image.open(f), size).save(os.path.join(base, rel))
                paths.append(rel)
            anims.setdefault(anim, {})[d] = paths
    meta = {"states": [{"character": {"name": "Idle", "prompt": prompt, "size": {"width": size, "height": size},
                                      "directions": len(rot), "view": "high top-down", "source": "blender (art/b3d)"},
                        "folder": "Idle", "frames": {"rotations": rot, "animations": anims}}]}
    json.dump(meta, open(os.path.join(base, "metadata.json"), "w"), indent=1)
    print(name, len(rot), "rotations,", {k: len(v) for k, v in anims.items()})


if __name__ == "__main__":
    main()
