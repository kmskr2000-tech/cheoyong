# HD-2D view: 3D terrain (hills, slopes, water) with upright sprites, sun shadows, fog and an orthographic tilted camera.
# Game logic stays in 2D pixels (x, y on the ground). 1 tile (32 px) = 1 metre; the ground height comes from height_px().
class_name View3D
extends Node3D

const T := 32.0
const PITCH := deg_to_rad(55.0)
const ORTHO := 16.5            # metres visible vertically
var W: int
var H: int
var hv := PackedFloat32Array() # vertex heights in metres, (W+1) x (H+1)
var cam3: Camera3D
var sun: DirectionalLight3D
var env: Environment
var lamps: Array[OmniLight3D] = []
var sprite_shader: Shader
var quad: QuadMesh
var pool: Array = []
var used_n := 0
var blob_pool: Array = []
var blob_n := 0
var blob_mat: ShaderMaterial
var tall := []                 # tall props that fade when the player walks behind them
var gates := {}                # gate id -> nodes hidden once the gate opens
var ppx := 1.0                 # screen pixels per game pixel
var target := Vector3.ZERO     # camera focus (metres)
var world: World
var models: Models
var grade: ShaderMaterial      # film grade pass (game.gd); eased per zone in set_mood
var grade_t := 0.0
var motes: CPUParticles3D       # sunlit dust drifting through the air (day)
var flies: CPUParticles3D       # fireflies / cursed embers (dusk and dread places)

func setup(w: World) -> void:
	world = w; W = World.W; H = World.H
	sprite_shader = load("res://shaders/billboard.gdshader")
	models = Models.new(self)
	quad = QuadMesh.new(); quad.size = Vector2(1, 1)
	_heights()
	add_child(_terrain())
	add_child(_water())
	_props()
	_camera_and_light()
	_ambient()

# ---------- height field ----------
func vh(x: int, y: int) -> float: return hv[clampi(y, 0, H) * (W + 1) + clampi(x, 0, W)]

func _heights() -> void:
	hv.resize((W + 1) * (H + 1))
	var base := {"beach": 0.25, "town": 1.1, "ruin": 2.3, "pond": 1.7, "forest": 0.9, "house": 2.0}
	var fixed := PackedByteArray(); fixed.resize(hv.size())
	# walkable vertices: zone base height (+ gentle undulation); sea and pond lower; roads relax between zones
	var walk_v := PackedByteArray(); walk_v.resize(hv.size())
	for y in H + 1:
		for x in W + 1:
			var i := y * (W + 1) + x
			var t := world.getv(x, y)
			var z = world.zone_cell(min(x, W - 1), min(y, H - 1))
			var cell_walk := false
			for d in [[0, 0], [-1, 0], [0, -1], [-1, -1]]:
				var cx: int = x + d[0]; var cy: int = y + d[1]
				if cx >= 0 and cy >= 0 and cx < W and cy < H and world.walkable[cy * W + cx]: cell_walk = true
			walk_v[i] = 1 if cell_walk else 0
			if t == World.SEA: hv[i] = -0.7; fixed[i] = 1
			elif t == World.POND: hv[i] = base.pond - 0.6; fixed[i] = 1
			elif z and cell_walk:
				hv[i] = z.get("h", base.get(z.id, 1.0)) + (G.noise(x * 0.35, y * 0.35, 21) - 0.5) * 0.35
				if t == World.SAND: hv[i] = 0.08 + (G.noise(x * 0.3, y * 0.3, 22)) * 0.15
				fixed[i] = 1
			else: hv[i] = 1.0
	# relax unfixed walkable vertices (roads) so they slope smoothly between zones
	for it in 120:
		for y in H + 1:
			for x in W + 1:
				var i := y * (W + 1) + x
				if fixed[i] or not walk_v[i]: continue
				var s := 0.0; var n := 0
				for d in [[1, 0], [-1, 0], [0, 1], [0, -1]]:
					var xx: int = x + d[0]; var yy: int = y + d[1]
					if xx < 0 or yy < 0 or xx > W or yy > H: continue
					var j := yy * (W + 1) + xx
					if walk_v[j] or fixed[j]: s += hv[j]; n += 1
				if n > 0: hv[i] = s / n
	# hills: unwalkable ground rises with the distance to the nearest walkable vertex
	var dist := PackedFloat32Array(); dist.resize(hv.size()); dist.fill(1e9)
	var near_h := PackedFloat32Array(); near_h.resize(hv.size())
	var q := []
	for i in hv.size():
		if walk_v[i] or fixed[i]: dist[i] = 0; near_h[i] = hv[i]; q.append(i)
	var head := 0
	while head < q.size():
		var i: int = q[head]; head += 1
		var x := i % (W + 1); var y := i / (W + 1)
		for d in [[1, 0], [-1, 0], [0, 1], [0, -1]]:
			var xx: int = x + d[0]; var yy: int = y + d[1]
			if xx < 0 or yy < 0 or xx > W or yy > H: continue
			var j := yy * (W + 1) + xx
			if dist[j] > dist[i] + 1:
				dist[j] = dist[i] + 1; near_h[j] = near_h[i]; q.append(j)
	for i in hv.size():
		if walk_v[i] or fixed[i]: continue
		var x := i % (W + 1); var y := i / (W + 1)
		var d := dist[i]
		# a short steep bank next to the walkable ground, then rolling hills
		hv[i] = max(near_h[i], 0.2) + min(d, 2.0) * 0.8 + clampf(d - 2.0, 0.0, 8.0) * 0.35 + G.fbm(x * 0.12, y * 0.12, 31) * 2.4 * min(1.0, d / 3.0)

# ground height in pixels at a 2D game position (bilinear)
func height_px(px: float, py: float) -> float:
	var fx := clampf(px / T, 0, W - 0.001); var fy := clampf(py / T, 0, H - 0.001)
	var x0 := int(fx); var y0 := int(fy); var tx := fx - x0; var ty := fy - y0
	var h := lerpf(lerpf(vh(x0, y0), vh(x0 + 1, y0), tx), lerpf(vh(x0, y0 + 1), vh(x0 + 1, y0 + 1), tx), ty)
	return h * T

func to3(px: float, py: float, z := 0.0) -> Vector3:
	return Vector3(px / T, (height_px(px, py) + z) / T, py / T)

# ---------- terrain mesh with a padded tile atlas ----------
func _atlas() -> Dictionary:
	var names: Array = Assets.tiles.keys()
	var S := 64; var P := 2; var C := S + P * 2
	var per_row := 16
	var count := names.size() * 16
	var rows := int(ceil(count / float(per_row)))
	var img := Image.create(per_row * C, rows * C, false, Image.FORMAT_RGBA8)
	var slot := {}
	var k := 0
	for n in names:
		var t: Dictionary = Assets.tiles[n]
		var src: Image = t.tex.get_image()
		if src.is_compressed(): src.decompress()
		src.convert(Image.FORMAT_RGBA8)
		var sz: int = t.size
		if sz != S: src.resize(src.get_width() * S / sz, src.get_height() * S / sz, Image.INTERPOLATE_LANCZOS)
		for i in 16:
			var tile := src.get_region(Rect2i((i % 4) * S, (i / 4) * S, S, S))
			var ox := (k % per_row) * C; var oy := (k / per_row) * C
			img.blit_rect(tile, Rect2i(0, 0, S, S), Vector2i(ox + P, oy + P))
			for e in P: # extrude edges so mipmaps do not bleed
				img.blit_rect(tile, Rect2i(0, 0, S, 1), Vector2i(ox + P, oy + e))
				img.blit_rect(tile, Rect2i(0, S - 1, S, 1), Vector2i(ox + P, oy + P + S + e))
				img.blit_rect(img, Rect2i(ox + P, oy, 1, C), Vector2i(ox + e, oy))
				img.blit_rect(img, Rect2i(ox + P + S - 1, oy, 1, C), Vector2i(ox + P + S + e, oy))
			slot["%s:%d" % [n, i]] = Rect2((ox + P) / float(img.get_width()), (oy + P) / float(img.get_height()), S / float(img.get_width()), S / float(img.get_height()))
			k += 1
	img.generate_mipmaps()
	return {"tex": ImageTexture.create_from_image(img), "slot": slot}

func _normal(x: int, y: int) -> Vector3:
	return Vector3(vh(x - 1, y) - vh(x + 1, y), 2.0, vh(x, y - 1) - vh(x, y + 1)).normalized()

func _terrain() -> MeshInstance3D:
	var at := _atlas()
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for y in H:
		for x in W:
			var c: Dictionary = world.cells[y * W + x]
			var r: Rect2 = at.slot.get("%s:%d" % [c.set, c.idx], Rect2())
			var u0 := r.position.x; var u1 := r.end.x; var v0 := r.position.y; var v1 := r.end.y
			if c.flip: var tmp := u0; u0 = u1; u1 = tmp
			var corners := [[x, y, u0, v0], [x + 1, y, u1, v0], [x + 1, y + 1, u1, v1], [x, y + 1, u0, v1]]
			for idx in [0, 1, 2, 0, 2, 3]:
				var p: Array = corners[idx]
				st.set_normal(_normal(p[0], p[1]))
				st.set_uv(Vector2(p[2], p[3]))
				st.add_vertex(Vector3(p[0], vh(p[0], p[1]), p[1]))
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	var m := StandardMaterial3D.new()
	m.albedo_texture = at.tex
	m.albedo_color = world.spec.get("tint", Color.WHITE)
	m.roughness = 1.0
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	mi.material_override = m
	return mi

func _water() -> MeshInstance3D:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for y in H:
		for x in W:
			var c: Dictionary = world.cells[y * W + x]
			var lvl := -INF
			for t in c.t:
				if t == World.SEA: lvl = max(lvl, -0.05)
				elif t == World.POND: lvl = max(lvl, 1.45)
			if lvl == -INF: continue
			for p in [[x, y], [x + 1, y], [x + 1, y + 1], [x, y], [x + 1, y + 1], [x, y + 1]]:
				st.add_vertex(Vector3(p[0], lvl, p[1]))
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	var m := ShaderMaterial.new(); m.shader = load("res://shaders/water.gdshader")
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi

# ---------- props: one MultiMesh per kind ----------
func _props() -> void:
	var by := {}
	for p in world.props:
		if Buildings.has(p.kind):
			var b := Buildings.make(p.kind)
			var n: Node3D = b.node
			n.position = to3(p.x, p.y)
			if p.kind == "gate": n.position.z -= 0.1
			add_child(n)
			if b.doors and p.get("gate", "") != "":  # doors vanish once their gate flag is set
				if not gates.has(p.gate): gates[p.gate] = []
				gates[p.gate].append(b.doors)
			continue
		if Assets.props.has(p.kind) and not p.k.get("flat", false):
			var key: String = p.kind + "|" + p.get("gate", "")
			if not by.has(key): by[key] = []
			by[key].append(p)
	for key in by:
		var kind: String = key.split("|")[0]; var gate: String = key.split("|")[1]
		var A: Dictionary = Assets.props[kind]
		var list: Array = by[key]
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_custom_data = true
		var q := QuadMesh.new()
		var k: float = A.scale / T
		q.size = Vector2(A.w * k, A.h * k)
		q.center_offset = Vector3(0, (A.ay - A.h / 2.0) * k, 0)
		mm.mesh = q
		mm.instance_count = list.size()
		for i in list.size():
			var p: Dictionary = list[i]
			mm.set_instance_transform(i, Transform3D(Basis(), to3(p.x, p.y)))
			mm.set_instance_custom_data(i, Color(1.0 if p.flip else 0.0, 1.0, 0, 1))
			if A.h * A.scale > 70: tall.append({"p": p, "A": A, "mm": mm, "i": i, "a": 1.0})
		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = mm
		var m := ShaderMaterial.new(); m.shader = sprite_shader
		m.set_shader_parameter("tex", A.tex); m.set_shader_parameter("white", A.tex)
		mmi.material_override = m
		add_child(mmi)
		if gate != "":
			if not gates.has(gate): gates[gate] = []
			gates[gate].append(mmi)
	# soft contact shadows under the billboard props
	var blobs := []
	for p in world.props:
		var sh: float = p.k.get("shadow", 0)
		if sh > 0 and not Buildings.has(p.kind) and Assets.props.has(p.kind): blobs.append(p)
	var bm := MultiMesh.new()
	bm.transform_format = MultiMesh.TRANSFORM_3D
	bm.use_colors = true
	var pm0 := PlaneMesh.new(); pm0.size = Vector2(1, 1)
	bm.mesh = pm0
	bm.instance_count = blobs.size()
	for i in blobs.size():
		var p: Dictionary = blobs[i]
		var sh: float = p.k.shadow * 2.4 / T
		bm.set_instance_transform(i, Transform3D(Basis().scaled(Vector3(sh, 1, sh * 0.7)), to3(p.x, p.y - 3) + Vector3(0, 0.04, 0)))
		bm.set_instance_color(i, Color(1, 1, 1, 1))
	var bmi := MultiMeshInstance3D.new()
	bmi.multimesh = bm
	var bmat := ShaderMaterial.new(); bmat.shader = load("res://shaders/blob.gdshader")
	bmi.material_override = bmat
	bmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(bmi)
	# flat props (lotus, bones, flowers) lie on the ground as decals
	for p in world.props:
		if not (Assets.props.has(p.kind) and p.k.get("flat", false)): continue
		var A: Dictionary = Assets.props[p.kind]
		var mi := MeshInstance3D.new()
		var pm := PlaneMesh.new(); var k: float = A.scale / T
		pm.size = Vector2(A.w * k, A.h * k)
		mi.mesh = pm
		var m := StandardMaterial3D.new()
		m.albedo_texture = A.tex; m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR; m.alpha_scissor_threshold = 0.4
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mi.material_override = m
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.position = to3(p.x, p.y, 1.5)
		add_child(mi)

# ---------- camera, sun, environment ----------
func _camera_and_light() -> void:
	cam3 = Camera3D.new()
	cam3.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam3.size = ORTHO
	cam3.near = 0.1; cam3.far = 200
	cam3.rotation = Vector3(-PITCH, 0, 0)
	add_child(cam3)
	cam3.make_current()
	sun = DirectionalLight3D.new()
	sun.rotation = Vector3(deg_to_rad(-36), deg_to_rad(-80), 0)  # low western sun: long shadows fall east, fronts stay lit
	sun.light_color = Color(1.0, 0.92, 0.8)
	sun.light_energy = 1.25
	sun.shadow_enabled = true
	sun.shadow_opacity = 0.88
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	sun.directional_shadow_max_distance = 60
	add_child(sun)
	env = Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.32, 0.36, 0.5)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.62, 0.64, 0.8)
	env.ambient_light_energy = 0.45
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	env.fog_enabled = true
	env.fog_light_color = Color(0.5, 0.52, 0.66)
	env.fog_density = 0.002
	env.glow_enabled = true
	env.glow_intensity = 0.5
	env.glow_bloom = 0.0
	env.glow_hdr_threshold = 0.9
	var we := WorldEnvironment.new(); we.environment = env
	add_child(we)
	for i in 6:
		var l := OmniLight3D.new(); l.omni_range = 5; l.light_energy = 0; l.shadow_enabled = false
		add_child(l); lamps.append(l)
	RenderingServer.global_shader_parameter_set("sprite_tint", Color(1, 1, 1))

# ambient air: two particle fields that follow the camera focus
func _air(col: Color, size: float, amount: int, life: float, vel: float) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	var qm := QuadMesh.new(); qm.size = Vector2(size, size)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	m.vertex_color_use_as_albedo = true
	m.albedo_texture = _dot_tex()
	qm.material = m
	p.mesh = qm
	p.amount = amount
	p.lifetime = life
	p.preprocess = life
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	p.emission_box_extents = Vector3(15, 2.2, 11)
	p.direction = Vector3(0.4, 0.3, 0.1)
	p.spread = 180
	p.gravity = Vector3.ZERO
	p.initial_velocity_min = vel * 0.3; p.initial_velocity_max = vel
	p.local_coords = false
	var g := Gradient.new()
	g.set_color(0, Color(col, 0.0)); g.set_color(1, Color(col, 0.0))
	g.add_point(0.25, col); g.add_point(0.75, col)
	p.color_ramp = g
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(p)
	return p

func _dot_tex() -> Texture2D:
	var img := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	for y in 16:
		for x in 16:
			var d := Vector2(x - 7.5, y - 7.5).length() / 7.5
			var a := clampf(1.0 - d, 0.0, 1.0)
			img.set_pixel(x, y, Color(1, 1, 1, a * a))
	return ImageTexture.create_from_image(img)

func _ambient() -> void:
	motes = _air(Color(1.0, 0.86, 0.6, 0.55), 0.09, 110, 7.0, 0.25)
	flies = _air(Color(0.75, 1.0, 0.55, 0.9), 0.16, 46, 5.0, 0.45)

# zone mood: brighter day in the town and on the beach, dusk in the cursed places
func set_mood(z, dt: float) -> void:
	var zid: String = z.id if z else "beach"
	var dark: float = z.get("dark", 0.2) if z and z.has("dark") else {"beach": 0.0, "town": 0.1, "ruin": 0.55, "pond": 0.4, "forest": 0.6, "house": 0.5}.get(zid, 0.2)
	var k := 1 - exp(-2.0 * dt)
	sun.light_energy = lerpf(sun.light_energy, 1.12 - dark * 0.72, k)
	env.ambient_light_energy = lerpf(env.ambient_light_energy, 0.36 - dark * 0.14, k)
	env.fog_density = lerpf(env.fog_density, 0.002 + dark * 0.01, k)
	var tint := Color(1, 1, 1).lerp(Color(0.78, 0.74, 0.92), dark)
	RenderingServer.global_shader_parameter_set("sprite_tint", tint)
	if motes:
		var mm := motes.mesh.material as StandardMaterial3D
		var fm := flies.mesh.material as StandardMaterial3D
		var ma := lerpf(mm.albedo_color.a, clampf(1.0 - dark * 1.6, 0.0, 1.0), k)
		var fa := lerpf(fm.albedo_color.a, clampf((dark - 0.25) * 2.0, 0.0, 1.0), k)
		mm.albedo_color = Color(1, 1, 1, ma)
		# dread places breed violet embers instead of green fireflies
		var fc := Color(1, 1, 1).lerp(Color(0.95, 0.5, 1.3), clampf((dark - 0.45) * 3.0, 0.0, 1.0))
		fm.albedo_color = Color(fc, fa)
		motes.emitting = ma > 0.02
		flies.emitting = fa > 0.02
	if grade:
		grade_t += dt
		grade.set_shader_parameter("time", grade_t)
		var g := {"exposure": 0.96 - dark * 0.14, "contrast": 1.1 + dark * 0.12, "saturation": 0.8 - dark * 0.26,
			"shadow_tint": Vector3(0.9, 0.93, 1.08).lerp(Vector3(0.76, 0.8, 1.16), dark),
			"highlight_tint": Vector3(1.06, 1.0, 0.9).lerp(Vector3(1.0, 0.94, 1.04), dark),
			"vignette": 0.34 + dark * 0.26}
		for key in g:
			var cur = grade.get_shader_parameter(key)
			if cur == null: cur = g[key]
			grade.set_shader_parameter(key, lerp(cur, g[key], k) if typeof(cur) == typeof(g[key]) else g[key])

# place the nearest coloured lights (lanterns, spirits) on the omni light pool
func set_lamps(lights: Array) -> void:
	var c := Vector2(target.x * T, target.z * T)
	var near := lights.filter(func(l): return l[3] != null)
	near.sort_custom(func(a, b): return c.distance_squared_to(Vector2(a[0], a[1])) < c.distance_squared_to(Vector2(b[0], b[1])))
	for i in lamps.size():
		var l := lamps[i]
		if i < near.size():
			var L: Array = near[i]
			l.position = to3(L[0], L[1] + 20, 40)
			l.light_color = L[3]; l.light_energy = 0.8 * L[4]; l.omni_range = L[2] / T * 1.2
		else: l.light_energy = 0

func follow(px: float, py: float, shake := 0.0) -> void:
	ppx = get_viewport().get_visible_rect().size.y / ORTHO / T
	target = Vector3(px / T, height_px(px, py) / T, py / T)
	if motes:
		motes.position = target + Vector3(0, 1.4, 0)
		flies.position = target + Vector3(0, 0.9, 0)
	var off := Vector3(0, sin(PITCH), cos(PITCH)) * 40.0
	cam3.position = target + off + Vector3(randf() - 0.5, randf() - 0.5, 0) * shake / T

# screen position of a ground point (or z pixels above it)
func project(px: float, py: float, z := 0.0) -> Vector2:
	return cam3.unproject_position(to3(px, py, z))

# ---------- dynamic sprites (a pool of billboards refilled every frame) ----------
func begin_frame() -> void:
	used_n = 0; blob_n = 0
	models.begin_frame()

# contact shadow under a character (radius in game pixels)
func blob(x: float, y: float, r: float, a := 1.0) -> void:
	if blob_mat == null:
		blob_mat = ShaderMaterial.new(); blob_mat.shader = load("res://shaders/blob.gdshader")
	if blob_n >= blob_pool.size():
		var n := MeshInstance3D.new()
		var pm := PlaneMesh.new(); pm.size = Vector2(1, 1)
		n.mesh = pm; n.material_override = blob_mat
		n.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(n); blob_pool.append(n)
	var mi: MeshInstance3D = blob_pool[blob_n]
	blob_n += 1
	mi.visible = a > 0.05
	mi.position = to3(x, y) + Vector3(0, 0.05, 0)
	mi.scale = Vector3(r * 2.4 / T, 1, r * 1.5 / T)

func sprite(name: String, anim: String, dir: String, t: float, x: float, y: float, o := {}) -> void:
	if Models.has(name):
		models.draw(self, name, anim, dir, t, x, y, Ent.head_y(name), o)
		return
	var f := Assets.frame(name, anim, dir, t, o.get("fps", 10.0), o.get("loop", true))
	if f.is_empty(): return
	if used_n >= pool.size():
		var n := MeshInstance3D.new()
		n.mesh = quad
		var mat := ShaderMaterial.new(); mat.shader = sprite_shader
		n.material_override = mat
		add_child(n)
		pool.append(n)
	var mi: MeshInstance3D = pool[used_n]
	used_n += 1
	mi.visible = true
	var c: Dictionary = f.c
	var m: ShaderMaterial = mi.material_override
	var tw: float = c.tex.get_width(); var th: float = c.tex.get_height()
	m.set_shader_parameter("tex", c.tex); m.set_shader_parameter("white", c.white)
	m.set_shader_parameter("region", Vector4(f.src.position.x / tw, f.src.position.y / th, f.src.size.x / tw, f.src.size.y / th))
	m.set_shader_parameter("flip", 1.0 if f.mirror else 0.0)
	m.set_shader_parameter("flash", o.get("flash", 0.0))
	var a: float = o.get("alpha", 1.0)
	m.set_shader_parameter("alpha", a)
	m.set_shader_parameter("dark", o.get("dark", 0.0))
	m.set_shader_parameter("tint", o.get("tint", Color.WHITE))
	var k: float = o.get("scale", 1.0) * c.scale / T
	var sq: float = o.get("squash", 1.0)
	mi.scale = Vector3(c.w * k, c.h * k * sq, 1)
	# the quad is centred on the cell: lift it along the camera's up axis so the feet row sits on the ground (plus z hover)
	var up := cam3.global_transform.basis.y
	mi.position = to3(x, y) + up * ((c.foot - c.h / 2.0) * k * sq + o.get("z", 0.0) / T)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF if a < 0.5 else GeometryInstance3D.SHADOW_CASTING_SETTING_ON

func end_frame() -> void:
	models.end_frame()
	for i in range(used_n, pool.size()):
		pool[i].visible = false
	for i in range(blob_n, blob_pool.size()):
		blob_pool[i].visible = false

# tall props near the player fade (dithered) so the hero stays visible behind trees and roofs
func fade_props(px: float, py: float) -> void:
	for e in tall:
		var p: Dictionary = e.p; var A: Dictionary = e.A; var ks: float = A.scale
		var a := 1.0
		if p.y > py and p.y - py < A.h * ks - 10 and abs(p.x - px) < A.bw * ks / 2 + 10: a = 0.5
		if a != e.a:
			e.a = a
			e.mm.set_instance_custom_data(e.i, Color(1.0 if p.flip else 0.0, a, 0, 1))
