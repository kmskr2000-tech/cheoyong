"""석장승 (seokjang): corrupted stone guardian statue warrior — jangseung face, tall hat, glowing purple eyes, stone sword.
blender -b -P art/b3d/seokjang.py -- <out_dir> [--only south]   then: python3 art/b3d/post.py seokjang <out_dir>
"""
import math, os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import common as C


def granite(nt, bsdf, base=(0.34, 0.33, 0.32), dark=(0.15, 0.145, 0.15)):
    N = nt.nodes
    tc = N.new("ShaderNodeTexCoord")
    noise = N.new("ShaderNodeTexNoise")
    noise.inputs["Scale"].default_value = 9.0
    noise.inputs["Detail"].default_value = 6.0
    ramp = N.new("ShaderNodeValToRGB")
    ramp.color_ramp.elements[0].color = (*dark, 1)
    ramp.color_ramp.elements[1].color = (*base, 1)
    ramp.color_ramp.elements[0].position = 0.3
    ramp.color_ramp.elements[1].position = 0.62
    vor = N.new("ShaderNodeTexVoronoi")
    vor.feature = "DISTANCE_TO_EDGE"
    vor.inputs["Scale"].default_value = 3.2
    crack = N.new("ShaderNodeMapRange")
    crack.inputs["From Min"].default_value = 0.0
    crack.inputs["From Max"].default_value = 0.02
    mix = N.new("ShaderNodeMix")
    mix.data_type = "RGBA"
    mix.inputs["B"].default_value = (0.08, 0.05, 0.1, 1)
    L = nt.links
    L.new(tc.outputs["Object"], noise.inputs["Vector"])
    L.new(tc.outputs["Object"], vor.inputs["Vector"])
    L.new(noise.outputs["Fac"], ramp.inputs["Fac"])
    L.new(vor.outputs["Distance"], crack.inputs["Value"])
    inv = N.new("ShaderNodeMath")
    inv.operation = "SUBTRACT"
    inv.inputs[0].default_value = 1.0
    L.new(crack.outputs["Result"], inv.inputs[1])
    L.new(inv.outputs["Value"], mix.inputs["Factor"])
    L.new(ramp.outputs["Color"], mix.inputs["A"])
    L.new(mix.outputs["Result"], bsdf.inputs["Base Color"])
    # a faint purple glow seeps out of the cracks (corruption)
    glow = N.new("ShaderNodeMath")
    glow.operation = "MULTIPLY"
    glow.inputs[1].default_value = 0.35
    L.new(inv.outputs["Value"], glow.inputs[0])
    L.new(glow.outputs["Value"], bsdf.inputs["Emission Strength"])
    bsdf.inputs["Emission Color"].default_value = (0.55, 0.15, 0.9, 1)


def build():
    stone = C.material("stone", (0.42, 0.4, 0.38), 0.85, nodes=granite)
    stone_d = C.material("stone_dark", (0.3, 0.28, 0.27), 0.85, nodes=lambda nt, b: granite(nt, b, (0.24, 0.23, 0.23), (0.1, 0.1, 0.11)))
    moss = C.material("moss", (0.22, 0.3, 0.16), 0.9)
    eye_w = C.material("eye_white", (0.55, 0.52, 0.47), 0.6)
    eye_p = C.material("eye_purple", (0.6, 0.2, 1.0), 0.4, emit=(0.6, 0.15, 1.0), strength=2.5)
    mouth = C.material("mouth", (0.06, 0.04, 0.06), 0.9)
    tooth = C.material("tooth", (0.8, 0.76, 0.68), 0.6)
    cloth = C.material("sash", (0.55, 0.12, 0.12), 0.9)

    root = C.empty("root")
    hips = C.empty("hips", (0, 0, 0.42), root)
    P = C.part
    # legs: short stone pillars with blocky feet
    legs = {}
    for side, x in (("L", 0.17), ("R", -0.17)):
        piv = C.empty("leg" + side, (x, 0, 0.0), hips)
        P("cube", "thigh" + side, (0, 0, -0.17), (0.13, 0.14, 0.17), stone_d, piv, bevel=0.03)
        P("cube", "foot" + side, (0, -0.05, -0.37), (0.15, 0.2, 0.07), stone_d, piv, bevel=0.03)
        legs[side] = piv
    torso = C.empty("torso", (0, 0, 0.02), hips)
    P("cube", "belly", (0, 0, 0.2), (0.33, 0.24, 0.22), stone, torso, bevel=0.06)
    P("cube", "chest", (0, 0, 0.44), (0.38, 0.26, 0.14), stone, torso, bevel=0.06)
    P("cube", "sash", (0, 0, 0.06), (0.35, 0.26, 0.05), cloth, torso, bevel=0.02)
    P("cube", "skirt", (0, 0, -0.06), (0.36, 0.27, 0.1), stone_d, torso, bevel=0.03)
    P("cube", "plaque", (0, -0.25, 0.26), (0.08, 0.02, 0.2), stone_d, torso, bevel=0.01)  # carved title strip
    head = C.empty("head", (0, 0, 0.58), torso)
    P("cube", "skull", (0, 0, 0.3), (0.36, 0.3, 0.33), stone, head, bevel=0.12)
    P("cylinder", "hat", (0, 0.02, 0.78), (0.27, 0.25, 0.2), stone_d, head, vertices=12, rot=(-6, 0, 0))
    P("cylinder", "hat_brim", (0, 0.0, 0.6), (0.42, 0.38, 0.03), stone_d, head, vertices=16)
    P("cylinder", "hat_top", (0, 0.04, 0.99), (0.2, 0.18, 0.04), moss, head, vertices=12)
    for side, x in (("L", 0.15), ("R", -0.15)):
        P("uv_sphere", "eye" + side, (x, -0.27, 0.36), (0.12, 0.08, 0.12), eye_w, head, smooth=True, segments=16, ring_count=8)
        P("uv_sphere", "pupil" + side, (x, -0.33, 0.36), (0.06, 0.04, 0.06), eye_p, head, smooth=True, segments=12, ring_count=6)
        P("cube", "brow" + side, (x, -0.29, 0.5), (0.14, 0.04, 0.035), stone_d, head, rot=(0, 18 if side == "L" else -18, 0), bevel=0.01)
        P("uv_sphere", "ear" + side, (x * 2.55, 0, 0.3), (0.05, 0.08, 0.12), stone, head, smooth=True, segments=10, ring_count=6)
    P("cube", "nose", (0, -0.32, 0.24), (0.07, 0.07, 0.1), stone, head, rot=(-12, 0, 0), bevel=0.03)
    P("cube", "mouth", (0, -0.29, 0.1), (0.2, 0.03, 0.05), mouth, head, bevel=0.01)
    for i, x in enumerate((-0.14, -0.05, 0.05, 0.14)):
        P("cube", f"tooth{i}", (x, -0.315, 0.12), (0.035, 0.015, 0.03), tooth, head)
    for side, x in (("L", 0.24), ("R", -0.24)):
        P("cube", "tusk" + side, (x * 0.62, -0.3, 0.06), (0.03, 0.02, 0.07), tooth, head, rot=(0, -20 if side == "L" else 20, 0))
    # arms: shoulder pivots, rigid upper+lower, big fists
    arms = {}
    for side, x in (("L", 0.45), ("R", -0.45)):
        sh = C.empty("arm" + side, (x, 0, 0.46), torso)
        P("uv_sphere", "pauldron" + side, (0, 0, 0.02), (0.14, 0.15, 0.12), stone_d, sh, smooth=True, segments=12, ring_count=6)
        P("cube", "upper" + side, (0, 0, -0.16), (0.09, 0.1, 0.14), stone, sh, bevel=0.03)
        P("cube", "fist" + side, (0, 0, -0.34), (0.11, 0.12, 0.09), stone_d, sh, bevel=0.04)
        arms[side] = sh
    # stone sword in the right fist, blade pointing forward-down
    grip = C.empty("grip", (0, -0.02, -0.34), arms["R"])
    P("cube", "hilt", (0, 0, 0), (0.035, 0.035, 0.12), stone_d, grip)
    P("cube", "guard", (0, 0, -0.13), (0.15, 0.05, 0.035), stone_d, grip, bevel=0.01)
    P("cube", "blade", (0, 0, -0.55), (0.08, 0.025, 0.4), stone, grip, bevel=0.01)
    P("cone", "tip", (0, 0, -1.02), (0.08, 0.025, 0.08), stone, grip, vertices=4, rot=(180, 0, 45))
    grip.rotation_euler = (math.radians(-70), 0, 0)  # rest: blade angled forward
    return dict(root=root, hips=hips, torso=torso, head=head, legs=legs, arms=arms, grip=grip)


def make_pose(R):
    def rot(ob, x=0.0, y=0.0, z=0.0):
        ob.rotation_euler = (math.radians(x), math.radians(y), math.radians(z))

    def pose(anim, i, n):
        t = i / n
        for o in (R["torso"], R["head"], R["legs"]["L"], R["legs"]["R"], R["arms"]["L"], R["arms"]["R"]):
            rot(o)
        R["hips"].location.z = 0.42
        rot(R["grip"], -70)
        if anim == "walking":
            s = math.sin(t * 2 * math.pi)
            rot(R["legs"]["L"], 28 * s)
            rot(R["legs"]["R"], -28 * s)
            rot(R["arms"]["L"], -22 * s, 0, 0)
            rot(R["arms"]["R"], 14 * s - 10)
            R["hips"].location.z = 0.42 + 0.04 * abs(math.cos(t * 2 * math.pi))
            rot(R["torso"], 4, -5 * s, 6 * s)  # heavy side-to-side waddle
            rot(R["head"], 0, 3 * s)
        elif anim == "attack":
            # 0 ready, 1-3 heave the sword overhead, 4 slam, 5 impact, 6 recover
            key = [(-20, 0, 5, -70), (-110, -8, -10, -40), (-165, -14, -18, -20), (-175, -16, -20, -15),
                   (-40, 18, 22, -95), (-15, 22, 26, -100), (-25, 8, 8, -80)][i]
            arm, lean, head, g = key
            rot(R["arms"]["R"], arm, 0, -8)
            rot(R["arms"]["L"], arm * 0.7, 0, 10)
            rot(R["torso"], lean)
            rot(R["head"], -head * 0.4)
            rot(R["grip"], g)
            R["hips"].location.z = 0.42 + (0.06 if i in (2, 3) else -0.05 if i in (4, 5) else 0)
            rot(R["legs"]["L"], -12 if i in (4, 5) else 0)
            rot(R["legs"]["R"], 14 if i in (4, 5) else 0)
        elif anim == "kneel":
            # purified: drops to one knee, sword planted, head bowed
            k = min(1.0, i / max(1, n - 2))
            e = k * k * (3 - 2 * k)
            R["hips"].location.z = 0.42 - 0.2 * e
            rot(R["legs"]["L"], -75 * e)
            rot(R["legs"]["R"], 70 * e)
            rot(R["torso"], 18 * e)
            rot(R["head"], 22 * e)
            rot(R["arms"]["R"], -35 * e, 0, -6 * e)
            rot(R["arms"]["L"], -10 * e, 0, 12 * e)
            rot(R["grip"], -70 + 60 * e)
    return pose


if __name__ == "__main__":
    out, only, res = C.args()
    C.reset()
    R = build()
    if out.endswith(".glb"):
        C.export_glb(R["root"], make_pose(R), {"idle": (1, 10, True), "walk": (6, 9, True), "attack": (7, 14, False), "kneel": (8, 9, False)}, out)
        raise SystemExit
    C.setup_render(res, ortho=2.35)
    C.frame(R["root"], make_pose(R))
    C.render_all(R["root"], make_pose(R), {"idle": (1, C.DIRS8), "walking": (6, C.D5), "attack": (7, C.D3)}, out, only)
