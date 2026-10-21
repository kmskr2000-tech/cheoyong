"""Procedural walk/attack/kneel frames made from a chibi character's 8 idle rotations (no API credits).

Each frame is the standing pose bent around its feet (bob, sway, squash, lean). Rough, but it moves;
a later gen_chibi.py run with credits replaces these with real animations.
Usage: python3 art/anim_proc.py <name> ...   (writes art/raw/chibi/<name>/Idle/animations + metadata.json)
"""
import json, math, os, sys
from PIL import Image

RAW = os.path.join(os.path.dirname(__file__), "raw", "chibi")
D5 = ["south", "south-east", "east", "north-east", "north"]
D3 = ["south", "east", "north"]
# facing direction on screen (x right, y down) for leaning into an attack
FACE = {"south": (0, 1), "east": (1, 0), "north": (0, -1)}


def bend(im, pivot, sx=1.0, sy=1.0, rot=0.0, dx=0.0, dy=0.0):
    """scale by (sx, sy) and rotate by rot degrees around pivot (the feet), then shift by (dx, dy)"""
    px, py = pivot
    c, s = math.cos(math.radians(rot)), math.sin(math.radians(rot))
    # forward: p' = R·S·(p - pivot) + pivot + d ; PIL wants the inverse map
    a, b, d, e = c * sx, -s * sy, s * sx, c * sy
    det = a * e - b * d
    ia, ib, id_, ie = e / det, -b / det, -d / det, a / det
    tx, ty = px + dx, py + dy
    coef = (ia, ib, px - ia * tx - ib * ty, id_, ie, py - id_ * tx - ie * ty)
    return im.transform(im.size, Image.AFFINE, coef, resample=Image.BICUBIC)


def pad(im, m=0.2):
    """room around the pose so stretching and leaning never leave the frame"""
    e = round(im.height * m)
    out = Image.new("RGBA", (im.width + 2 * e, im.height + 2 * e))
    out.alpha_composite(im, (e, e))
    return out


def feet(im):
    b = im.getbbox()
    return ((b[0] + b[2]) / 2, b[3]) if b else (im.width / 2, im.height)


def body_h(im):
    b = im.getbbox()
    return (b[3] - b[1]) if b else im.height


# --- motion styles: each returns a list of bend() kwargs per frame ---

def walk_puppet(h):
    # jerky string-pulled hop: up on the beat, a stiff tilt that flips side to side
    out = []
    for i in range(6):
        t = i / 6
        hop = abs(math.sin(t * 2 * math.pi)) * h * 0.07
        out.append(dict(rot=7 if i < 3 else -7, dy=-hop, sy=1 + hop / h * 0.6, sx=1 - hop / h * 0.4))
    return out


def walk_shadow(h):
    # long smooth drift: a slow sway and the body stretching taller and thinner
    out = []
    for i in range(6):
        t = i / 6 * 2 * math.pi
        out.append(dict(rot=math.sin(t) * 4, sy=1 + math.sin(t * 2) * 0.04, sx=1 - math.sin(t * 2) * 0.03, dy=-math.sin(t * 2) * h * 0.02))
    return out


def attack_slash(h, d):
    # puppet: wind back, snap forward with a spin-like over-tilt, recover
    fx, fy = FACE[d]
    side = 1 if fx >= 0 else -1
    keys = [(0.0, 0, 1.0, 1.0), (-0.06, -10, 1.04, 0.95), (-0.08, -14, 1.06, 0.93),
            (0.14, 16, 0.94, 1.08), (0.12, 12, 0.96, 1.05), (0.05, 5, 0.99, 1.02), (0.0, 0, 1.0, 1.0)]
    out = []
    for lunge, rot, sy, sx in keys:
        k = dict(sx=sx, sy=sy, dx=fx * lunge * h, dy=fy * lunge * h * 0.5)
        k["rot"] = rot * side if fx else rot * 0.5
        if fy:  # toward/away from the camera: grow or shrink instead of tilting
            g = 1 + fy * lunge * 0.6
            k["sx"] *= g; k["sy"] *= g
        out.append(k)
    return out


def attack_slam(h, d):
    # shadow: rise up tall, then crash down and squash, like an arm slamming the ground
    fx, fy = FACE[d]
    keys = [(1.0, 1.0, 0, 0.0), (1.12, 0.92, -4, -0.02), (1.22, 0.86, -7, -0.04),
            (0.78, 1.16, 9, 0.10), (0.84, 1.12, 6, 0.08), (0.94, 1.04, 2, 0.03), (1.0, 1.0, 0, 0.0)]
    out = []
    for sy, sx, rot, lunge in keys:
        k = dict(sx=sx, sy=sy, rot=rot * (1 if fx >= 0 else -1) if fx else 0, dx=fx * lunge * h, dy=fy * lunge * h * 0.5)
        if fy:
            g = 1 + fy * lunge * 0.8
            k["sx"] *= g; k["sy"] *= g
        out.append(k)
    return out


def kneel(h):
    # sink to the knees and bow forward
    out = []
    for i in range(7):
        t = min(1.0, i / 4)
        e = 1 - (1 - t) ** 2
        out.append(dict(sy=1 - 0.3 * e, sx=1 + 0.08 * e, rot=0, dy=0))
    return out


STYLES = {
    "kkoktu": {"walk": walk_puppet, "attack": attack_slash},
    "geuseundae": {"walk": walk_shadow, "attack": attack_slam, "kneel": kneel},
}


def save_seq(base, folder, d, frames):
    rel = []
    os.makedirs(os.path.join(base, "Idle", "animations", folder, d), exist_ok=True)
    for i, im in enumerate(frames):
        p = f"Idle/animations/{folder}/{d}/frame_{i:03d}.png"
        im.save(os.path.join(base, p))
        rel.append(p)
    return rel


def main(name):
    base = os.path.join(RAW, name)
    meta_p = os.path.join(base, "metadata.json")
    meta = json.load(open(meta_p))
    fr = meta["states"][0]["frames"]
    anims = fr.setdefault("animations", {}) or {}
    fr["animations"] = anims
    rot = {d: Image.open(os.path.join(base, p)).convert("RGBA") for d, p in fr["rotations"].items()}
    style = STYLES[name]
    for key, dirs, folder in (("walk", D5, "walking"), ("attack", D3, "attack"), ("kneel", ["south"], "kneel")):
        if key not in style:
            continue
        anims[folder] = {}
        for d in dirs:
            im = pad(rot[d])
            h = body_h(im)
            ks = style[key](h) if key != "attack" else style[key](h, d)
            anims[folder][d] = save_seq(base, folder, d, [bend(im, feet(im), **k) for k in ks])
        print(name, folder, {d: len(v) for d, v in anims[folder].items()}, flush=True)
    meta["procedural"] = sorted(style)
    json.dump(meta, open(meta_p, "w"), indent=2, ensure_ascii=False)


if __name__ == "__main__":
    for n in sys.argv[1:]:
        main(n)
