extends Node2D
## Test corner of the village: terrain, props, moonlit lighting, fog and drifting ash.

const MAP := [
	",,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,",
	",,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,",
	",,,,,,,,,,,,,,,,,,..,,,,,,,,,,,,,,,,,,,,,",
	",,,,,,,,,,,,,,,,,....,,,,,,,,,,,,,,,,,,,,",
	",,,,,,,,,,,,,,,,,....,,,,,,,,,,,,,,,,,,,,",
	",,,,,,,,,,,,,,,,,.....,,,,,,,,,,,,,,,,,,,",
	",,,,,,,,,,,,,,,,,,....,,,,,,,,,,,,,,,,,,,",
	",,,,,,,,,,,,,,,,,,.....,,,,,,,,,,,,,,,,,,",
	",,,,,,,,,,,,,,,,,,..#####,,,,,,,,,,,,,,,,",
	",,,,,,,,,,,,,,,,,,.#######.,,,,,,,,,,,,,,",
	",,,,,,,,,,,,,,,,,..#######...............",
	",,,,,,,,,,,,,,,,...#######...............",
	",,,,,,,,,,,,,,......#####....,,,,,,,,,,,,",
	",,,,,,,,,,,,,,.....,,,,,,,,,,,,,,,,,,,,,,",
	",,,,,,~~~~,,,....,,,,,,,,,,,,,,,,,,,,,,,,",
	",,,,~~~~~~~~,...,,,,,,,,,,,,,,,,,,,,,,,,,",
	",,,~~~~~~~~~~,..,,,,,,,,,,,,,,,,,,,,,,,,,",
	",,,~~~~~~~~~~~,..,,,,,,,,,,,,,,,,,,,,,,,,",
	",,,,~~~~~~~~~~,,..,,,,,,,,,,,,,,,,,,,,,,,",
	",,,,,~~~~~~~~,,,..,,,,,,,,,,,,,,,,,,,,,,,",
	",,,,,,,~~~~,,,,,,..,,,,,,,,,,,,,,,,,,,,,,",
	",,,,,,,,,,,,,,,,,,..,,,,,,,,,,,,,,,,,,,,,",
	",,,,,,,,,,,,,,,,,,,..,,,,,,,,,,,,,,,,,,,,",
	",,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,",
]


## [prop, x, y, light] — x,y = ground contact point; light = [offset_y, colour, energy, scale] or null
const PROPS := [
	["house", 120, 108, [-6, Color(1.0, 0.62, 0.3), 1.1, 0.9]],
	["house", 540, 140, [-6, Color(1.0, 0.62, 0.3), 1.0, 0.9]],
	["lantern", 284, 150, [-34, Color(1.0, 0.7, 0.38), 1.05, 1.1]],
	["lantern", 436, 196, [-34, Color(1.0, 0.7, 0.38), 1.05, 1.1]],
	["jangseung_m", 590, 150, null], ["jangseung_f", 590, 200, null],
	["dodam", 470, 236, null], ["dodam", 540, 236, null], ["dodam", 90, 290, null],
	["geumjul", 296, 300, null],
	["seonang", 470, 300, [-60, Color(0.75, 0.35, 1.0), 0.7, 1.5]],
	["cairn", 432, 312, null],
	["sotdae", 252, 52, null], ["sotdae_s", 264, 58, null], ["sotdae", 276, 50, null],
	["pine", 210, 64, null], ["pine", 86, 330, null], ["pine", 612, 334, null], ["pine", 620, 70, null],
	["pine", 390, 44, null], ["pine", 20, 230, null], ["pine", 360, 350, null],
]
## occluder half-width / height for props that cast lantern shadows
const OCCLUDE := {"house": Vector2(50, 28), "pine": Vector2(5, 6), "seonang": Vector2(8, 6), "jangseung_m": Vector2(5, 4), "jangseung_f": Vector2(5, 4), "lantern": Vector2(8, 6), "dodam": Vector2(32, 6)}

var light_tex: Texture2D


func _ready() -> void:
	$Terrain.build(PackedStringArray(MAP))
	var water: TileMapLayer = $Terrain.layers["water"]
	var wm := ShaderMaterial.new()
	wm.shader = load("res://shaders/water.gdshader")
	water.material = wm
	light_tex = _radial(256)
	for p in PROPS:
		_prop(p[0], Vector2(p[1], p[2]), p[3])
	_terrace()
	_atmosphere()
	var cam: Camera2D = $Player/Camera
	cam.limit_left = 0
	cam.limit_top = 0
	cam.limit_right = (MAP[0].length() - 1) * 16
	cam.limit_bottom = (MAP.size() - 1) * 16
	for i in 4:
		_wisp(Vector2(470, 260) + Vector2(cos(i * 1.7), sin(i * 2.3)) * 46, i)
	_blob($Player, 10)


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


## 석축 terrace: the north-west corner sits a storey higher, held up by a dry-stone wall with steps.
const TERRACE_FOOT := 150.0 # y where the wall meets the lower ground
const STAIR := Vector2(152, 184)


func _terrace() -> void:
	# one voxel-rendered piece (art/vox.py terrace): front wall, stair, east wall running back
	var wall_tex := Tex.lit("res://assets/props/terrace.png")
	var body := StaticBody2D.new()
	body.position = Vector2(0, TERRACE_FOOT)
	add_child(body)
	var spr := Sprite2D.new()
	spr.texture = wall_tex
	spr.centered = false
	spr.offset = Vector2(0, -wall_tex.get_height() + 2)
	body.add_child(spr)
	# walls block everywhere except the stair gap; the east wall blocks the terrace's side
	for r in [Rect2(0, -44, STAIR.x, 42), Rect2(STAIR.y, -44, 248 - STAIR.y, 42), Rect2(240, -TERRACE_FOOT, 8, TERRACE_FOOT - 2)]:
		var col := CollisionShape2D.new()
		var sh := RectangleShape2D.new()
		sh.size = r.size
		col.shape = sh
		col.position = r.position + r.size / 2.0
		body.add_child(col)
	# the raised top catches more moonlight than the ground below: a soft rectangular light over it
	var top := PointLight2D.new()
	var gi := Image.create(64, 64, false, Image.FORMAT_RGBA8)
	for y in 64:
		for x in 64:
			var e := minf(minf(x, 63 - x), minf(y, 63 - y)) / 10.0
			gi.set_pixel(x, y, Color(1, 1, 1, clampf(e, 0, 1)))
	top.texture = ImageTexture.create_from_image(gi)
	top.position = Vector2(124, -TERRACE_FOOT / 2.0 - 18)
	top.scale = Vector2(250 / 64.0, (TERRACE_FOOT - 20) / 64.0)
	top.color = Color(1.0, 0.5, 0.55)
	top.energy = 0.2
	top.height = 40.0
	body.add_child(top)
	# the lower ground at the wall foot sits in the terrace's shadow
	var ao := Sprite2D.new()
	var img := Image.create(250, 10, false, Image.FORMAT_RGBA8)
	for y in 10:
		for x in 250:
			img.set_pixel(x, y, Color(0, 0, 0.02, 0.55 * (1.0 - y / 10.0)))
	ao.texture = ImageTexture.create_from_image(img)
	ao.centered = false
	ao.z_index = -6
	ao.z_as_relative = false
	body.add_child(ao)


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
	cm.color = Color(0.46, 0.25, 0.33)
	add_child(cm)
	# the moon: a cold key light from the upper left that rakes across every normal map and casts
	# long diagonal shadows from houses and trees
	var moon := DirectionalLight2D.new()
	moon.color = Color(1.0, 0.42, 0.45) # blood moon
	moon.energy = 0.7
	moon.height = 0.45
	moon.rotation = deg_to_rad(35)
	add_child(moon)
	# a faint cold aura around the hero so he never vanishes in the dark
	var pl := PointLight2D.new()
	pl.texture = light_tex
	pl.color = Color(0.85, 0.6, 0.75)
	pl.energy = 0.55
	pl.texture_scale = 0.55
	pl.position = Vector2(0, -16)
	pl.height = 30.0
	$Player.add_child(pl)
	# fog over the ground, lit by the lanterns it drifts through
	var fog := ColorRect.new()
	var w := (MAP[0].length() - 1) * 16.0
	var h := (MAP.size() - 1) * 16.0
	fog.size = Vector2(w, h)
	fog.z_index = 50
	fog.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var fm := ShaderMaterial.new()
	fm.shader = load("res://shaders/fog.gdshader")
	fm.set_shader_parameter("world_size", Vector2(w, h))
	fm.set_shader_parameter("tint", Color(0.7, 0.25, 0.32))
	fm.set_shader_parameter("sick", Color(0.55, 0.3, 0.75))
	fog.material = fm
	add_child(fog)
	# ash / spores drifting down across the view
	var ash := CPUParticles2D.new()
	# embers rising through the red haze
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
	ramp.colors = PackedColorArray([Color(1, 0.6, 0.3, 0), Color(1, 0.55, 0.3, 1), Color(1, 0.25, 0.3, 0.8), Color(0.6, 0.1, 0.3, 0)])
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
