# 3D models (GLB from art/b3d or other sources) drawn instead of billboards when assets/models/<name>.glb exists.
# Every clip is a time range inside one exported animation (<name>.glb.json); each frame a pooled instance
# is posed by seeking to the actor's anim time, so the game logic stays exactly as with sprites.
class_name Models
extends RefCounted

const T := 32.0
static var defs := {}     # name -> {scene, clips, h} or {} when missing
static var hulls := {}    # mesh -> outline mesh with position-averaged normals (flat-shaded parts would split the hull)
var pools := {}           # name -> {"list": [...], "used": int}
var parent: Node3D
var toon: Shader
var outline: Shader

func _init(p: Node3D) -> void:
	parent = p
	toon = load("res://shaders/toon.gdshader")
	outline = load("res://shaders/outline.gdshader")

static func has(name: String) -> bool:
	if not defs.has(name):
		var p := "res://assets/models/%s.glb" % name
		if ResourceLoader.exists(p):
			var clips = JSON.parse_string(FileAccess.get_file_as_string(p + ".json"))
			if not clips: clips = {}
			var k: float = clips.get("_scale", 1.0)  # chibi heads read smaller than the sprite they replace
			clips.erase("_scale")
			defs[name] = {"scene": load(p), "clips": clips, "k": k}
		else:
			defs[name] = {}
	return not defs[name].is_empty()

func begin_frame() -> void:
	for k in pools: pools[k].used = 0

func end_frame() -> void:
	for k in pools:
		var P: Dictionary = pools[k]
		for i in range(P.used, P.list.size()): P.list[i].node.visible = false

func _make(name: String) -> Dictionary:
	var d: Dictionary = defs[name]
	var node: Node3D = d.scene.instantiate()
	parent.add_child(node)
	var mats := []
	var meshes := node.find_children("*", "MeshInstance3D", true, false)
	var ap: AnimationPlayer = null
	var aps := node.find_children("*", "AnimationPlayer", true, false)
	if aps.size() > 0:
		ap = aps[0]
		var an: String = ap.get_animation_list()[0]
		ap.play(an); ap.pause()
		ap.seek(d.clips.get("idle", {"start": 0.0}).start, true)  # the GLB rest pose is whatever was posed last
	var aabb := AABB()
	var first := true
	for mi in meshes:
		var m3: MeshInstance3D = mi
		for s in m3.mesh.get_surface_count():
			var src = m3.get_active_material(s)
			var sm := ShaderMaterial.new(); sm.shader = toon
			if src is StandardMaterial3D:
				sm.set_shader_parameter("albedo", src.albedo_color)
				if src.albedo_texture: sm.set_shader_parameter("albedo_tex", src.albedo_texture)
				if src.emission_enabled:
					sm.set_shader_parameter("emission", src.emission)
					sm.set_shader_parameter("emission_energy", src.emission_energy_multiplier)
			m3.set_surface_override_material(s, sm)
			mats.append(sm)
		var b: AABB = m3.global_transform * m3.get_aabb()
		aabb = b if first else aabb.merge(b)
		first = false
		if m3.get_aabb().get_longest_axis_size() < 0.16:  # eyes, mouth, blush: an ink hull would swamp them
			continue
		var hull := MeshInstance3D.new()
		hull.mesh = _hull(m3.mesh)
		var ol := ShaderMaterial.new(); ol.shader = outline
		hull.material_override = ol
		hull.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		m3.add_child(hull)
		mats.append(ol)
	if not d.has("h"): d.h = max(0.1, aabb.end.y - node.global_position.y)
	return {"node": node, "mats": mats, "ap": ap, "meshes": meshes}

static func _hull(mesh: Mesh) -> Mesh:
	if hulls.has(mesh): return hulls[mesh]
	var out := ArrayMesh.new()
	for s in mesh.get_surface_count():
		var arr := mesh.surface_get_arrays(s)
		var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		var nrm: PackedVector3Array = arr[Mesh.ARRAY_NORMAL]
		var acc := {}
		for i in v.size():
			var key := Vector3i((v[i] * 1000.0).round())
			acc[key] = acc.get(key, Vector3.ZERO) + nrm[i]
		var sm := PackedVector3Array(); sm.resize(v.size())
		for i in v.size(): sm[i] = acc[Vector3i((v[i] * 1000.0).round())].normalized()
		var a2 := []; a2.resize(Mesh.ARRAY_MAX)
		a2[Mesh.ARRAY_VERTEX] = v; a2[Mesh.ARRAY_NORMAL] = sm; a2[Mesh.ARRAY_INDEX] = arr[Mesh.ARRAY_INDEX]
		out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, a2)
	hulls[mesh] = out
	return out

# x, y: ground position in game pixels; height_px: the sprite's standing height the model is scaled to
func draw(view, name: String, anim: String, dir: String, t: float, x: float, y: float, height_px: float, o := {}) -> void:
	var a: float = o.get("alpha", 1.0)
	if o.get("flash", 0.0) >= 1.0 and a < 1.0: return  # the sprite path's white overlay copy
	if not pools.has(name): pools[name] = {"list": [], "used": 0}
	var P: Dictionary = pools[name]
	if P.used >= P.list.size(): P.list.append(_make(name))
	var e: Dictionary = P.list[P.used]
	P.used += 1
	var d: Dictionary = defs[name]
	var node: Node3D = e.node
	node.visible = a > 0.02
	var k: float = height_px / T / d.h * o.get("scale", 1.0) * d.k
	node.scale = Vector3(k, k * o.get("squash", 1.0), k)
	node.position = view.to3(x, y, o.get("z", 0.0))
	var ang: float = G.DIR8.find(dir) * PI / 4.0
	node.rotation = Vector3(0, PI / 2.0 - ang, 0)
	var shadow := GeometryInstance3D.SHADOW_CASTING_SETTING_OFF if a < 0.5 else GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	for mi in e.meshes: mi.cast_shadow = shadow
	for m in e.mats:
		m.set_shader_parameter("alpha", a)
		if m.shader == outline: continue
		m.set_shader_parameter("flash", o.get("flash", 0.0))
		m.set_shader_parameter("dark", o.get("dark", 0.0))
		m.set_shader_parameter("tint", o.get("tint", Color.WHITE))
	if e.ap:
		var clips: Dictionary = d.clips
		var c = clips.get(anim, clips.get("attack" if anim == "cast" else "idle", null))
		if c:
			# progress through the clip in the caller's frame terms: t * fps frames over the sprite's frame count
			var n: float = c.get("n", 1)
			if anim != "idle" and Assets.chars.has(name):
				var sn: int = Assets.anim_len(name, anim, dir)
				if sn > 0: n = sn
			var p: float = t * o.get("fps", c.get("fps", 10.0)) / max(1.0, n)
			p = fposmod(p, 1.0) if c.loop else clampf(p, 0.0, 1.0)
			e.ap.seek(c.start + p * c.len, true)
