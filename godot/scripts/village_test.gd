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
	["house", 150, 136, [-30, Color(1.0, 0.62, 0.3), 1.1, 0.9]],
	["house", 520, 116, [-30, Color(1.0, 0.62, 0.3), 0.9, 0.8]],
	["lantern", 278, 140, [-26, Color(1.0, 0.7, 0.38), 1.05, 1.1]],
	["lantern", 436, 196, [-26, Color(1.0, 0.7, 0.38), 1.05, 1.1]],
	["jangseung_m", 592, 156, null], ["jangseung_f", 592, 196, null],
	["geumjul", 296, 300, null],
	["seonang", 470, 300, [-60, Color(0.55, 1.0, 0.45), 0.55, 1.4]],
	["cairn", 432, 312, null],
	["sotdae", 252, 52, null], ["sotdae_s", 264, 58, null], ["sotdae", 276, 50, null],
	["pine", 40, 96, null], ["pine", 86, 330, null], ["pine", 612, 334, null], ["pine", 620, 70, null],
	["pine", 390, 44, null], ["pine", 20, 230, null], ["pine", 360, 350, null],
]
## occluder half-width / height for props that cast lantern shadows
const OCCLUDE := {"house": Vector2(36, 26), "pine": Vector2(5, 6), "seonang": Vector2(8, 6), "jangseung_m": Vector2(4, 4), "jangseung_f": Vector2(4, 4), "lantern": Vector2(5, 4)}

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
	_atmosphere()
	for i in 4:
		_wisp(Vector2(470, 260) + Vector2(cos(i * 1.7), sin(i * 2.3)) * 46, i)
	_blob($Player, 10)


func _prop(name: String, at: Vector2, light) -> void:
	var tex: Texture2D = load("res://assets/props/%s.png" % name)
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
		l.shadow_enabled = true
		l.shadow_color = Color(0, 0, 0, 0.75)
		l.shadow_filter = PointLight2D.SHADOW_FILTER_PCF5
		l.set_meta("base", light[2])
		body.add_child(l)
		flicker.append(l)


var flicker: Array[PointLight2D] = []


var wisps: Array[Node2D] = []


## 도깨비불: drifting blue-green will-o'-the-wisps that are real light sources
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
				img.set_pixel(x, y, Color(0.75, 1.0, 0.95) if d < 1.2 else Color(0.3, 0.85, 0.8, 0.85))
	core.texture = ImageTexture.create_from_image(img)
	var um := CanvasItemMaterial.new()
	um.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	core.material = um
	n.add_child(core)
	var l := PointLight2D.new()
	l.texture = light_tex
	l.color = Color(0.35, 0.95, 0.85)
	l.energy = 0.9
	l.texture_scale = 0.45
	n.add_child(l)
	add_child(n)
	wisps.append(n)


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
	cm.color = Color(0.25, 0.28, 0.43)
	add_child(cm)
	# a faint cold aura around the hero so he never vanishes in the dark
	var pl := PointLight2D.new()
	pl.texture = light_tex
	pl.color = Color(0.55, 0.62, 0.9)
	pl.energy = 0.55
	pl.texture_scale = 0.55
	pl.position = Vector2(0, -16)
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
	fog.material = fm
	add_child(fog)
	# ash / spores drifting down across the view
	var ash := CPUParticles2D.new()
	ash.amount = 70
	ash.lifetime = 9.0
	ash.preprocess = 9.0
	ash.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	ash.emission_rect_extents = Vector2(300, 10)
	ash.position = Vector2(0, -170)
	ash.direction = Vector2(0.3, 1)
	ash.spread = 25.0
	ash.gravity = Vector2(0, 4)
	ash.initial_velocity_min = 8.0
	ash.initial_velocity_max = 18.0
	ash.color = Color(0.55, 0.6, 0.68, 0.7)
	ash.z_index = 60
	var am := CanvasItemMaterial.new()
	am.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	ash.material = am
	ash.local_coords = false
	$Player/Camera.add_child(ash)
	# vignette on its own screen layer
	var layer := CanvasLayer.new()
	var vig := ColorRect.new()
	vig.set_anchors_preset(Control.PRESET_FULL_RECT)
	vig.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var vm := ShaderMaterial.new()
	vm.shader = load("res://shaders/vignette.gdshader")
	vig.material = vm
	layer.add_child(vig)
	add_child(layer)


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
