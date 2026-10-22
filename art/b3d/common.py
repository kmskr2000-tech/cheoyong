"""Shared Blender setup for the chibi cast made from primitives (no AI credits).

A model is a tree of rigid parts hung on pivot empties; a pose function sets pivot rotations per frame,
and render_all() renders every (animation, direction, frame) with an orthographic high top-down camera.
Run inside Blender: blender -b -P art/b3d/<name>.py -- <out_dir> [--only south] [--res 512]
"""
import math, os, sys
import bpy
from mathutils import Vector

DIRS8 = ["south", "south-east", "east", "north-east", "north", "north-west", "west", "south-west"]
D5 = ["south", "south-east", "east", "north-east", "north"]
D3 = ["south", "east", "north"]
# the model faces -Y (toward the camera); yaw turns it to face each screen direction
YAW = {"south": 0, "south-east": 45, "east": 90, "north-east": 135, "north": 180, "north-west": -135, "west": -90, "south-west": -45}
ELEV = 38  # camera pitch above the horizon, matching the PixelLab "high top-down" cast


def args():
    a = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    out = a[0] if a and not a[0].startswith("--") else "b3d_out"
    only = a[a.index("--only") + 1].split(",") if "--only" in a else None
    res = int(a[a.index("--res") + 1]) if "--res" in a else 512
    return out, only, res


def reset():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    return bpy.context.scene


def empty(name, loc=(0, 0, 0), parent=None):
    e = bpy.data.objects.new(name, None)
    bpy.context.scene.collection.objects.link(e)
    e.location = loc
    if parent:
        e.parent = parent
    return e


def part(prim, name, loc, scale, mat, parent=None, rot=(0, 0, 0), bevel=0.0, smooth=False, **kw):
    """primitive mesh part; loc is relative to parent"""
    getattr(bpy.ops.mesh, "primitive_" + prim + "_add")(location=(0, 0, 0), **kw)
    ob = bpy.context.object
    ob.name = name
    ob.scale = scale
    ob.rotation_euler = [math.radians(r) for r in rot]
    with bpy.context.temp_override(object=ob, active_object=ob, selected_objects=[ob], selected_editable_objects=[ob]):
        bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
    if bevel:
        m = ob.modifiers.new("bevel", "BEVEL")
        m.width = bevel
        m.segments = 3
        m.limit_method = "ANGLE"
    if smooth:
        for p in ob.data.polygons:
            p.use_smooth = True
    ob.data.materials.append(mat)
    if parent:
        ob.parent = parent
    ob.location = loc
    return ob


def material(name, color, rough=0.75, emit=None, strength=0.0, nodes=None):
    m = bpy.data.materials.new(name)
    nt = m.node_tree
    bsdf = next(n for n in nt.nodes if n.type == "BSDF_PRINCIPLED")
    bsdf.inputs["Base Color"].default_value = (*color, 1)
    bsdf.inputs["Roughness"].default_value = rough
    bsdf.inputs["Specular IOR Level"].default_value = 0.25
    if emit:
        bsdf.inputs["Emission Color"].default_value = (*emit, 1)
        bsdf.inputs["Emission Strength"].default_value = strength
    if nodes:
        nodes(nt, bsdf)
    return m


def setup_render(res, ortho):
    s = bpy.context.scene
    s.render.engine = "CYCLES"
    s.cycles.device = "CPU"
    s.cycles.samples = 48
    try:
        s.cycles.use_denoising = True
    except Exception:
        pass
    s.render.resolution_x = s.render.resolution_y = res
    s.render.film_transparent = True
    s.view_settings.view_transform = "Standard"
    s.view_settings.look = "None"
    s.render.image_settings.file_format = "PNG"
    s.render.image_settings.color_mode = "RGBA"
    w = bpy.data.worlds.new("w")
    s.world = w
    bg = next(n for n in w.node_tree.nodes if n.type == "BACKGROUND")
    bg.inputs["Color"].default_value = (0.55, 0.5, 0.45, 1)
    bg.inputs["Strength"].default_value = 0.18
    cam = bpy.data.cameras.new("cam")
    cam.type = "ORTHO"
    cam.ortho_scale = ortho
    co = bpy.data.objects.new("cam", cam)
    s.collection.objects.link(co)
    e = math.radians(ELEV)
    target = Vector((0, 0, ortho * 0.4))
    co.location = target + Vector((0, -math.cos(e), math.sin(e))) * 20
    co.rotation_euler = (math.radians(90 - ELEV), 0, 0)
    s.camera = co
    # warm key from the upper left-front, cool rim from behind, soft fill
    for name, rot, energy, col in (("key", (45, 0, -50), 3.4, (1.0, 0.88, 0.72)), ("rim", (-55, 0, 150), 2.2, (0.65, 0.75, 1.0)),
                                   ("fill", (70, 0, 70), 0.25, (1.0, 0.95, 0.9))):
        l = bpy.data.lights.new(name, "SUN")
        l.energy = energy
        l.color = col
        l.angle = math.radians(8)
        lo = bpy.data.objects.new(name, l)
        s.collection.objects.link(lo)
        lo.rotation_euler = [math.radians(v) for v in rot]


def frame(root, pose, height_px=100, foot_px=122):
    """fit the orthographic camera so the standing south pose is height_px tall with its feet at row foot_px"""
    from bpy_extras.object_utils import world_to_camera_view
    s = bpy.context.scene
    cam = s.camera
    root.rotation_euler = (0, 0, 0)
    pose("idle", 0, 1)
    bpy.context.view_layer.update()
    dg = bpy.context.evaluated_depsgraph_get()
    ys = []
    for ob in s.objects:
        if ob.type != "MESH":
            continue
        ev = ob.evaluated_get(dg)
        me = ev.to_mesh()
        ys += [world_to_camera_view(s, cam, ob.matrix_world @ v.co).y for v in me.vertices]
        ev.to_mesh_clear()
    lo, hi = min(ys), max(ys)  # 0..1 from the bottom of the frame
    res = s.render.resolution_y
    k = (hi - lo) * res / height_px * (128 / res)  # fraction of the frame per 128-px canvas
    cam.data.ortho_scale *= k
    shift = (lo - 0.5) * cam.data.ortho_scale / k - (0.5 - foot_px / 128) * cam.data.ortho_scale
    up = cam.matrix_world.to_3x3().col[1]
    cam.location += up * shift
    bpy.context.view_layer.update()


def render_all(root, pose, anims, out, only=None):
    """anims: {anim: (frames, dirs)}; 'idle' renders the 8 rotations. pose(anim, i, n) poses the model."""
    s = bpy.context.scene
    for anim, (n, dirs) in anims.items():
        for d in dirs:
            if only and d not in only:
                continue
            root.rotation_euler = (0, 0, math.radians(YAW[d]))
            for i in range(n):
                pose(anim, i, n)
                bpy.context.view_layer.update()
                path = os.path.join(out, anim, d, f"frame_{i:03d}.png")
                os.makedirs(os.path.dirname(path), exist_ok=True)
                s.render.filepath = os.path.abspath(path)
                bpy.ops.render.render(write_still=True)
            print("rendered", anim, d, n, flush=True)
