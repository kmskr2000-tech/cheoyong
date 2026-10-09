extends Node2D
## Test corner of the village: baked tiered ground (art/ground3d.py), voxel and hand-drawn props,
## cold moonlit night, fog, spirit motes, ghost-fires and the HD-2D finishing pass.

const LEVEL := "village"

## [prop, x, y, light] — x,y = ground contact point in *footprint* coordinates (before the tier lift); light = [offset_y, colour, energy, scale] or null
const PROPS := [
	["house", 72, 108, [-6, Color(1.0, 0.62, 0.3), 1.1, 0.9]],
	["lantern", 160, 100, [-34, Color(1.0, 0.52, 0.18), 1.2, 1.0]],
	["house", 560, 300, [-6, Color(1.0, 0.62, 0.3), 1.0, 0.9]],
	["lantern", 282, 138, [-34, Color(1.0, 0.52, 0.18), 1.3, 1.1]],
	["lantern", 440, 214, [-34, Color(1.0, 0.52, 0.18), 1.3, 1.1]],
	["jangseung_m", 606, 154, null], ["jangseung_f", 606, 200, null],
	["dodam", 470, 250, null], ["dodam", 400, 250, null],
	["geumjul", 320, 330, null],
	["seonang", 470, 330, [-60, Color(0.75, 0.35, 1.0), 0.7, 1.5]],
	["cairn", 432, 344, null],
	["sotdae", 580, 40, null], ["sotdae_s", 594, 36, null], ["sotdae", 608, 42, null],
	["pine", 18, 60, null], ["pine", 236, 30, null], ["pine", 630, 60, null], ["pine", 520, 26, null],
	["pine", 60, 340, null], ["pine", 630, 350, null], ["pine", 380, 356, null], ["pine", 220, 300, null],
]
## occluder half-width / height for props that cast lantern shadows
const OCCLUDE := {"house": Vector2(50, 28), "pine": Vector2(5, 6), "seonang": Vector2(8, 6), "jangseung_m": Vector2(5, 4), "jangseung_f": Vector2(5, 4), "lantern": Vector2(8, 6), "dodam": Vector2(32, 6)}

var light_tex: Texture2D


var meta := {}


func _ready() -> void:
	meta = JSON.parse_string(FileAccess.get_file_as_string("res://assets/levels/%s.json" % LEVEL))
	light_tex = _radial(256)
	_ground()
	for p in PROPS:
		_prop(p[0], lift(Vector2(p[1], p[2])), p[3])
	_atmosphere()
	var size: Array = meta["size"]
	var tier: float = meta["tier"]
	var cam: Camera2D = $Player/Camera
	cam.limit_left = 0
	cam.limit_top = int(-tier * 2)
	cam.limit_right = int(size[0])
	cam.limit_bottom = int(size[1] - tier)
	for i in 4:
		_wisp(lift(Vector2(470, 290)) + Vector2(cos(i * 1.7), sin(i * 2.3)) * 46, i)
	_blob($Player, 10)
	var boss_fight := "--boss" in OS.get_cmdline_user_args()
	for e in ([] if boss_fight else [["dog", Vector2(260, 270)], ["dog", Vector2(540, 250)], ["ghoul", Vector2(330, 300)], ["ghoul", Vector2(150, 230)]]):
		var en := Enemy.new()
		en.kind = e[0]
		en.position = lift(e[1])
		add_child(en)
	hud = Hud.new()
	add_child(hud)
	hud.bind($Player)
	dialog = DialogBox.new()
	add_child(dialog)
	if boss_fight:
		var boss := PlagueGod.new()
		boss.position = lift(Vector2(370, 190))
		add_child(boss)
		hud.show_boss(boss, "역신(疫神)")
		if "--boss-weak" in OS.get_cmdline_user_args():  # test hook: verify the defeat sequence
			boss.hp = 20.0
	if "--dialog" in OS.get_cmdline_user_args():
		_demo_dialog.call_deferred()


var dialog: DialogBox
var hud: Hud


func _demo_dialog() -> void:
	$Player.locked = true
	await dialog.say([
		{"name": "처용", "text": "바람에 비린내가 섞였다. 역병이 지나간 자리는 언제나 이렇게 조용하지."},
		{"name": "촌주 박노인", "text": "나리, 동쪽 폐가에서 밤마다 아이 우는 소리가 납니다. 장승도 그 뒤로 눈을 감지 못합니다."},
		"멀리서 보랏빛 귀화가 서낭나무 가지 사이를 맴돈다.",
	])
	$Player.locked = false


## footprint → screen: ground on tier k is drawn k*TIER px higher (oblique camera)
func lift(p: Vector2) -> Vector2:
	var rows: Array = meta["heights"]
	var cy := clampi(int(p.y / meta["ts"]), 0, rows.size() - 1)
	var cx := clampi(int(p.x / meta["ts"]), 0, String(rows[0]).length() - 1)
	var c := String(rows[cy])[cx]
	var t := 1.0 if not c.is_valid_int() else float(c)
	return Vector2(p.x, p.y - t * meta["tier"])


## the baked ground: one lit sprite with geometric normals, an animated water overlay, cliff collision
func _ground() -> void:
	var off: float = meta["offset"]
	var g := Sprite2D.new()
	g.texture = Tex.lit("res://assets/levels/%s.png" % LEVEL)
	g.centered = false
	g.position = Vector2(0, -off)
	g.z_index = -20
	g.z_as_relative = false
	add_child(g)
	var w := Sprite2D.new()
	w.texture = load("res://assets/levels/%s_water.png" % LEVEL)
	w.centered = false
	w.position = g.position
	w.z_index = -19
	w.z_as_relative = false
	var wm := ShaderMaterial.new()
	wm.shader = load("res://shaders/water_overlay.gdshader")
	w.material = wm
	add_child(w)
	var body := StaticBody2D.new()
	add_child(body)
	for r in meta["collision"]:
		var col := CollisionShape2D.new()
		var sh := RectangleShape2D.new()
		sh.size = Vector2(r[2], r[3])
		col.shape = sh
		col.position = Vector2(r[0] + r[2] / 2.0, r[1] + r[3] / 2.0)
		body.add_child(col)


func _prop(name: String, at: Vector2, light) -> void:
	var tex: Texture2D = Tex.lit("res://assets/props/%s.png" % name)
	var body := StaticBody2D.new()
	body.position = at
	add_child(body)
	var spr := Sprite2D.new()
	spr.texture = tex
	spr.centered = false
	spr.offset = Vector2(-tex.get_width() / 2.0, -tex.get_height() + 1)
	body.add_child(spr)
	var half: Vector2 = OCCLUDE.get(name, Vector2(3, 3))
	_blob(body, maxf(half.x + 4, 6))
	_cast_shadow(body, tex)
	var col := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(half.x * 2, half.y * 2)
	col.shape = shape
	col.position = Vector2(0, -half.y)
	body.add_child(col)
	var glow_path := "res://assets/props/%s_glow.png" % name
	if ResourceLoader.exists(glow_path):
		var g := Sprite2D.new()
		g.texture = load(glow_path)
		g.centered = false
		g.offset = spr.offset
		var um := CanvasItemMaterial.new()
		um.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
		g.material = um
		body.add_child(g)
	# light sources do not occlude their own light
	if OCCLUDE.has(name) and light == null:
		var occ := LightOccluder2D.new()
		var poly := OccluderPolygon2D.new()
		poly.polygon = PackedVector2Array([Vector2(-half.x, -half.y * 2), Vector2(half.x, -half.y * 2), Vector2(half.x, 0), Vector2(-half.x, 0)])
		occ.occluder = poly
		body.add_child(occ)
	if light != null:
		var l := PointLight2D.new()
		l.texture = light_tex
		l.position = Vector2(0, light[0])
		l.color = light[1]
		l.energy = light[2]
		l.texture_scale = light[3]
		l.height = 24.0
		l.shadow_enabled = true
		l.shadow_color = Color(0, 0, 0, 0.75)
		l.shadow_filter = PointLight2D.SHADOW_FILTER_PCF5
		l.set_meta("base", light[2])
		body.add_child(l)
		flicker.append(l)


var flicker: Array[PointLight2D] = []


var wisps: Array[Node2D] = []


## 귀화(鬼火): drifting violet ghost-fires that are real light sources
func _wisp(home: Vector2, i: int) -> void:
	var n := Node2D.new()
	n.position = home
	n.set_meta("home", home)
	n.set_meta("ph", i * 1.9)
	n.z_index = 40
	var core := Sprite2D.new()
	var img := Image.create(5, 7, false, Image.FORMAT_RGBA8)
	for y in 7:
		for x in 5:
			var d := Vector2(x - 2, (y - 4) * 0.8).length()
			if d < 2.6 - (0.0 if y > 2 else 0.8):
				img.set_pixel(x, y, Color(1.0, 0.85, 1.0) if d < 1.2 else Color(0.75, 0.35, 1.0, 0.9))
	core.texture = ImageTexture.create_from_image(img)
	var um := CanvasItemMaterial.new()
	um.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	core.material = um
	n.add_child(core)
	var l := PointLight2D.new()
	l.texture = light_tex
	l.color = Color(0.7, 0.35, 1.0)
	l.energy = 1.3
	l.texture_scale = 0.55
	l.height = 16.0
	n.add_child(l)
	add_child(n)
	wisps.append(n)


## moon shadow: the silhouette laid flat on the ground, falling to the lower right (moon is upper left)
func _cast_shadow(parent: Node2D, tex: Texture2D) -> void:
	var s := Sprite2D.new()
	s.texture = tex.diffuse_texture if tex is CanvasTexture else tex
	s.centered = false
	s.offset = Vector2(-tex.get_width() / 2.0, -tex.get_height() + 1)
	s.scale = Vector2(1, -0.42)
	s.skew = deg_to_rad(-38)
	s.modulate = Color(0, 0, 0.03, 0.42)
	s.z_index = -6
	s.z_as_relative = false
	parent.add_child(s)
	parent.move_child(s, 0)


## soft contact shadow under anything standing on the ground
func _blob(parent: Node2D, half_w: float) -> void:
	var img := Image.create(int(half_w * 2), int(maxf(4, half_w * 0.7)), false, Image.FORMAT_RGBA8)
	var w := img.get_width()
	var h := img.get_height()
	for y in h:
		for x in w:
			var d := Vector2((x + 0.5 - w / 2.0) / (w / 2.0), (y + 0.5 - h / 2.0) / (h / 2.0)).length()
			if d < 1.0:
				img.set_pixel(x, y, Color(0, 0, 0, 0.5 if d < 0.7 else 0.3))
	var s := Sprite2D.new()
	s.texture = ImageTexture.create_from_image(img)
	s.position = Vector2(0, -1)
	s.z_index = -5
	s.z_as_relative = false
	parent.add_child(s)
	parent.move_child(s, 0)


func _process(_d: float) -> void:
	var t := Time.get_ticks_msec() / 1000.0
	for w in wisps:
		var ph: float = w.get_meta("ph")
		w.position = w.get_meta("home") + Vector2(sin(t * 0.7 + ph) * 18, sin(t * 1.1 + ph * 2) * 8 + sin(t * 3 + ph) * 2)
		w.modulate.a = 0.75 + sin(t * 5 + ph) * 0.25
	for i in flicker.size():
		var l := flicker[i]
		l.energy = l.get_meta("base") * (1.0 + sin(t * 9.0 + i * 3.1) * 0.05 + sin(t * 23.0 + i) * 0.035)


func _atmosphere() -> void:
	# moonlit night: everything unlit sinks into cold violet-blue
	var cm := CanvasModulate.new()
	cm.color = Color(0.2, 0.26, 0.42)
	add_child(cm)
	# the moon: a cold key light from the upper left that rakes across every normal map and casts
	# long diagonal shadows from houses and trees
	var moon := DirectionalLight2D.new()
	moon.color = Color(0.6, 0.74, 1.0) # cold moon
	moon.energy = 0.75
	moon.height = 0.45
	moon.rotation = deg_to_rad(35)
	add_child(moon)
	# a faint cold aura around the hero so he never vanishes in the dark
	var pl := PointLight2D.new()
	pl.texture = light_tex
	pl.color = Color(0.6, 0.7, 0.95)
	pl.energy = 0.55
	pl.texture_scale = 0.55
	pl.position = Vector2(0, -16)
	pl.height = 30.0
	$Player.add_child(pl)
	# fog over the ground, lit by the lanterns it drifts through
	var fog := ColorRect.new()
	var w: float = meta["size"][0]
	var h: float = meta["size"][1] + meta["offset"]
	fog.size = Vector2(w, h)
	fog.position = Vector2(0, -meta["offset"])
	fog.z_index = 50
	fog.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var fm := ShaderMaterial.new()
	fm.shader = load("res://shaders/fog.gdshader")
	fm.set_shader_parameter("world_size", Vector2(w, h))
	fm.set_shader_parameter("tint", Color(0.36, 0.46, 0.66))
	fm.set_shader_parameter("sick", Color(0.42, 0.3, 0.7))
	fog.material = fm
	add_child(fog)
	# ash / spores drifting down across the view
	var ash := CPUParticles2D.new()
	# cold spirit motes rising through the haze (warm embers only near the lanterns' light)
	ash.amount = 60
	ash.lifetime = 7.0
	ash.preprocess = 7.0
	ash.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	ash.emission_rect_extents = Vector2(280, 20)
	ash.position = Vector2(0, 150)
	ash.direction = Vector2(0.15, -1)
	ash.spread = 20.0
	ash.gravity = Vector2(0, -3)
	ash.initial_velocity_min = 10.0
	ash.initial_velocity_max = 26.0
	var ramp := Gradient.new()
	ramp.offsets = PackedFloat32Array([0.0, 0.15, 0.7, 1.0])
	ramp.colors = PackedColorArray([Color(0.6, 0.8, 1, 0), Color(0.7, 0.85, 1, 1), Color(0.5, 0.6, 1, 0.7), Color(0.4, 0.3, 0.9, 0)])
	ash.color_ramp = ramp
	ash.z_index = 60
	var am := CanvasItemMaterial.new()
	am.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	am.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	ash.material = am
	ash.local_coords = false
	$Player/Camera.add_child(ash)
	# light shafts through the haze, then the HD-2D finishing pass (DoF, bloom, grade, haze, vignette)
	var shafts_layer := CanvasLayer.new()
	shafts_layer.layer = 5
	var shafts := ColorRect.new()
	shafts.set_anchors_preset(Control.PRESET_FULL_RECT)
	shafts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sm := ShaderMaterial.new()
	sm.shader = load("res://shaders/shafts.gdshader")
	shafts.material = sm
	shafts_layer.add_child(shafts)
	add_child(shafts_layer)
	var post_layer := CanvasLayer.new()
	post_layer.layer = 10
	var post := ColorRect.new()
	post.set_anchors_preset(Control.PRESET_FULL_RECT)
	post.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var pm := ShaderMaterial.new()
	pm.shader = load("res://shaders/post.gdshader")
	post.material = pm
	post_layer.add_child(post)
	add_child(post_layer)


static func _radial(size: int) -> Texture2D:
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.35, 0.7, 1.0])
	g.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0.55), Color(1, 1, 1, 0.15), Color(1, 1, 1, 0)])
	var t := GradientTexture2D.new()
	t.gradient = g
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.5)
	t.fill_to = Vector2(1.0, 0.5)
	t.width = size
	t.height = size
	return t
