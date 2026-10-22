"""Parametric chibi humanoid for toon 3D (big head, short limbs, hanbok). Rigid parts on pivots, like seokjang.

spec keys: skin, hair, jeogori, trim, sash, pants, shoe, hat ('gat' | 'topknot' | None), hat_color, flower,
prop ('flute' | None). build(spec) -> rig dict; pose(R) -> pose(anim, i, n) for idle/walk/attack/cast/kneel.
"""
import math
import common as C

P = C.part


def mats(spec):
    m = {}
    for k in ("skin", "hair", "jeogori", "trim", "sash", "pants", "shoe", "hat_color"):
        if k in spec:
            m[k] = C.material(k, spec[k], 0.7)
    m["eye"] = C.material("eye", (0.03, 0.025, 0.03), 0.3)
    m["shine"] = C.material("shine", (1, 1, 1), 0.3, emit=(1, 1, 1), strength=1.0)
    m["blush"] = C.material("blush", (0.95, 0.45, 0.4), 0.8)
    m["mouth"] = C.material("mouth", (0.45, 0.12, 0.12), 0.8)
    return m


def build(spec):
    M = mats(spec)
    root = C.empty("root")
    hips = C.empty("hips", (0, 0, 0.36), root)
    legs = {}
    for side, x in (("L", 0.11), ("R", -0.11)):
        piv = C.empty("leg" + side, (x, 0, 0), hips)
        P("cylinder", "leg" + side, (0, 0, -0.14), (0.085, 0.085, 0.14), M["pants"], piv, vertices=12, smooth=True)
        P("uv_sphere", "shoe" + side, (0, -0.04, -0.3), (0.09, 0.13, 0.06), M["shoe"], piv, segments=14, ring_count=8, smooth=True)
        legs[side] = piv
    torso = C.empty("torso", (0, 0, 0.02), hips)
    # baggy pants top + jeogori (short jacket) + sash
    P("uv_sphere", "pants_top", (0, 0, 0.0), (0.22, 0.18, 0.12), M["pants"], torso, segments=16, ring_count=8, smooth=True)
    P("cone", "robe", (0, 0, 0.2), (0.27, 0.22, 0.24), M["jeogori"], torso, vertices=20, smooth=True, radius1=1.0, radius2=0.68, depth=1.0)
    P("cylinder", "collar", (0, -0.06, 0.39), (0.17, 0.14, 0.03), M["trim"], torso, vertices=20, smooth=True, rot=(-12, 0, 0))
    P("cube", "lapel", (0.03, -0.205, 0.26), (0.07, 0.012, 0.12), M["trim"], torso, rot=(0, -28, 0), bevel=0.01)
    P("cylinder", "sash", (0, 0, 0.06), (0.25, 0.21, 0.035), M["sash"], torso, vertices=20, smooth=True)
    P("cube", "sash_tail", (0.08, -0.2, -0.04), (0.035, 0.015, 0.11), M["sash"], torso, rot=(0, 10, 0), bevel=0.01)
    head = C.empty("head", (0, 0, 0.42), torso)
    P("uv_sphere", "skull", (0, 0, 0.36), (0.36, 0.33, 0.35), M["skin"], head, segments=24, ring_count=14, smooth=True)
    P("uv_sphere", "hair", (0, 0.04, 0.42), (0.37, 0.33, 0.33), M["hair"], head, segments=24, ring_count=14, smooth=True)
    P("uv_sphere", "bang", (0, -0.2, 0.55), (0.28, 0.12, 0.1), M["hair"], head, segments=16, ring_count=8, smooth=True)
    for side, x in (("L", 0.13), ("R", -0.13)):
        P("uv_sphere", "eye" + side, (x, -0.31, 0.33), (0.055, 0.03, 0.075), M["eye"], head, segments=12, ring_count=8, smooth=True)
        P("uv_sphere", "shine" + side, (x + 0.015, -0.335, 0.36), (0.018, 0.01, 0.02), M["shine"], head, segments=8, ring_count=4, smooth=True)
        P("cube", "brow" + side, (x, -0.31, 0.44), (0.06, 0.012, 0.012), M["hair"], head, rot=(0, 10 if side == "L" else -10, 0))
        P("uv_sphere", "blush" + side, (x * 1.45, -0.28, 0.24), (0.05, 0.015, 0.03), M["blush"], head, segments=10, ring_count=6, smooth=True)
        P("uv_sphere", "ear" + side, (x * 2.7, 0.0, 0.32), (0.04, 0.06, 0.07), M["skin"], head, segments=10, ring_count=6, smooth=True)
    P("uv_sphere", "mouth", (0, -0.325, 0.2), (0.04, 0.01, 0.015), M["mouth"], head, segments=10, ring_count=6, smooth=True)
    hat = spec.get("hat")
    if hat == "gat":
        hc = M["hat_color"]
        # small and tipped back so the camera, looking down at 55 degrees, still sees the face
        P("cylinder", "gat_brim", (0, 0.1, 0.66), (0.44, 0.42, 0.012), hc, head, vertices=32, smooth=True, rot=(-24, 0, 0))
        P("cylinder", "gat_crown", (0, 0.16, 0.8), (0.16, 0.15, 0.14), hc, head, vertices=24, smooth=True, rot=(-24, 0, 0))
        P("cylinder", "gat_band", (0, 0.135, 0.7), (0.165, 0.155, 0.025), M["trim"], head, vertices=24, smooth=True, rot=(-24, 0, 0))
        if spec.get("flower"):
            fl = C.material("peony", spec["flower"], 0.6)
            leaf = C.material("leaf", (0.2, 0.45, 0.2), 0.7)
            for k in range(6):
                a = k * math.pi / 3
                P("uv_sphere", f"petal{k}", (0.2 + 0.06 * math.cos(a), -0.02 + 0.03 * math.sin(a), 0.78 + 0.06 * math.sin(a)),
                  (0.06, 0.04, 0.05), fl, head, segments=10, ring_count=6, smooth=True)
            P("uv_sphere", "peony_c", (0.2, -0.05, 0.78), (0.045, 0.03, 0.04), C.material("peony_c", (1.0, 0.85, 0.4), 0.6), head, segments=10, ring_count=6, smooth=True)
            P("uv_sphere", "leaf", (0.28, 0.02, 0.74), (0.07, 0.03, 0.03), leaf, head, segments=10, ring_count=6, smooth=True, rot=(0, -20, 30))
    elif hat == "topknot":
        P("uv_sphere", "knot", (0, 0.05, 0.74), (0.11, 0.11, 0.1), M["hair"], head, segments=14, ring_count=8, smooth=True)
    arms = {}
    for side, x in (("L", 0.27), ("R", -0.27)):
        sh = C.empty("arm" + side, (x, 0, 0.36), torso)
        # wide hanbok sleeve hanging from the shoulder, hand peeking out
        P("cone", "sleeve" + side, (0, 0, -0.13), (0.1, 0.1, 0.15), M["jeogori"], sh, vertices=14, smooth=True, radius1=1.0, radius2=0.6, depth=1.0, rot=(180, 0, 0))
        P("cylinder", "cuff" + side, (0, 0, -0.27), (0.1, 0.1, 0.02), M["trim"], sh, vertices=14, smooth=True)
        P("uv_sphere", "hand" + side, (0, 0, -0.32), (0.065, 0.065, 0.065), M["skin"], sh, segments=12, ring_count=8, smooth=True)
        arms[side] = sh
    grip = C.empty("grip", (0, -0.02, -0.32), arms["R"])
    if spec.get("prop") == "flute":
        bam = C.material("bamboo", (0.55, 0.62, 0.25), 0.6)
        tas = C.material("tassel", (0.8, 0.12, 0.15), 0.8)
        P("cylinder", "flute", (0, 0, 0), (0.025, 0.025, 0.26), bam, grip, vertices=10, smooth=True)
        for k in (-0.15, 0.0, 0.15):
            P("cylinder", f"node{k}", (0, 0, k), (0.03, 0.03, 0.012), C.material("bamboo_node", (0.4, 0.45, 0.15), 0.6), grip, vertices=10, smooth=True)
        P("cone", "tassel", (0, 0, -0.33), (0.04, 0.04, 0.08), tas, grip, vertices=8, smooth=True, rot=(180, 0, 0))
    grip.rotation_euler = (math.radians(-80), 0, math.radians(20))
    return dict(root=root, hips=hips, torso=torso, head=head, legs=legs, arms=arms, grip=grip)


def make_pose(R):
    def rot(ob, x=0.0, y=0.0, z=0.0):
        ob.rotation_euler = (math.radians(x), math.radians(y), math.radians(z))

    def pose(anim, i, n):
        t = i / n
        for o in (R["torso"], R["head"], R["legs"]["L"], R["legs"]["R"], R["arms"]["L"], R["arms"]["R"]):
            rot(o)
        R["hips"].location.z = 0.36
        rot(R["head"], -14)
        rot(R["grip"], -80, 0, 20)
        rot(R["arms"]["L"], 0, -8)
        rot(R["arms"]["R"], 0, 8)
        s = math.sin(t * 2 * math.pi)
        if anim == "idle":
            R["hips"].location.z = 0.36 - 0.01 * (1 - math.cos(t * 2 * math.pi))
            rot(R["head"], -14 + 2 * s)
            rot(R["arms"]["L"], 0, -8 - 3 * s)
            rot(R["arms"]["R"], 0, 8 + 3 * s)
        elif anim == "walk":
            rot(R["legs"]["L"], 35 * s)
            rot(R["legs"]["R"], -35 * s)
            rot(R["arms"]["L"], -30 * s, 0, 0)
            rot(R["arms"]["R"], 30 * s, 0, 0)
            R["hips"].location.z = 0.36 + 0.035 * abs(math.cos(t * 2 * math.pi))
            rot(R["torso"], 5, 0, 6 * s)
            rot(R["head"], -17)
        elif anim == "attack":
            # sleeve snap: wind back, sweep the flute across in an arc, follow through
            e = [0.0, 0.25, 0.75, 1.0, 1.0, 0.6][min(i, 5)]
            back = [1.0, 0.6, 0.0, 0.0, 0.0, 0.3][min(i, 5)]
            rot(R["arms"]["R"], -60 * back - 95 * e, 0, 40 * back - 70 * e)
            rot(R["arms"]["L"], 20 * e, 0, 10 * e)
            rot(R["torso"], 8 * e, 0, 25 * back - 30 * e)
            rot(R["legs"]["L"], -15 * e)
            rot(R["legs"]["R"], 15 * e)
        elif anim == "cast":
            # cheoyongmu: arms raised and opened, sleeves sweeping, slow turn and dip
            rot(R["arms"]["L"], -150 + 20 * s, -30, 0)
            rot(R["arms"]["R"], -150 - 20 * s, 30, 0)
            rot(R["torso"], 0, 6 * s, 30 * s)
            R["hips"].location.z = 0.36 - 0.04 * (1 - math.cos(t * 2 * math.pi)) * 0.5
            rot(R["legs"]["L"], -20 * max(0, s))
            rot(R["legs"]["R"], 20 * max(0, -s))
            rot(R["head"], -24)
        elif anim == "kneel":
            k = min(1.0, i / max(1, n - 2))
            e = k * k * (3 - 2 * k)
            R["hips"].location.z = 0.36 - 0.16 * e
            rot(R["legs"]["L"], -80 * e)
            rot(R["legs"]["R"], 75 * e)
            rot(R["torso"], 20 * e)
            rot(R["head"], -14 + 39 * e)
            rot(R["arms"]["L"], -25 * e, 0, 15 * e)
            rot(R["arms"]["R"], -25 * e, 0, -15 * e)
    return pose


CLIPS = {"idle": (8, 6, True), "walk": (6, 10, True), "attack": (6, 20, False), "cast": (8, 8, True), "kneel": (8, 9, False)}
