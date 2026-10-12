extends Node2D
## 타이틀: moon over the sea at 개운포, the 「신 처용가」 logo and a short lacquer menu.
##   처음부터 → intro cinematic → the beach   이어하기 → last checkpoint   회상 → replay the intro

const CREAM := Color(0.93, 0.88, 0.76)
var _opts: Array[Label] = []
var _actions: Array[String] = []
var _sel := 0
var _ready_t := 0.0


func _ready() -> void:
	# test runs (--level=…, captures of levels) go straight into the game
	var args := Array(OS.get_cmdline_user_args())
	if "--intro" in args:  # test hook
		Game.new_game()
		get_tree().change_scene_to_file.call_deferred("res://scenes/intro.tscn")
		return
	if not "--title" in args and args.any(func(a): return a.begins_with("--capture") or a.begins_with("--level") or a.begins_with("--beach")):
		get_tree().change_scene_to_file.call_deferred("res://scenes/level.tscn")
		return
	Audio.music("title")
	Audio.ambience("waves")
	var bg := Sprite2D.new()
	bg.texture = load("res://assets/intro/title_bg.png")
	bg.centered = false
	add_child(bg)
	_motes()
	var layer := CanvasLayer.new()
	add_child(layer)
	var logo := Label.new()
	logo.text = "신 처용가"
	logo.add_theme_font_override("font", DialogBox._pixel_font("res://assets/fonts/Galmuri11-Bold.ttf"))
	logo.add_theme_font_size_override("font_size", 36)
	logo.add_theme_color_override("font_color", CREAM)
	logo.add_theme_color_override("font_outline_color", Color(0.02, 0.02, 0.05))
	logo.add_theme_constant_override("outline_size", 6)
	logo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	logo.position = Vector2(0, 58)
	logo.size = Vector2(480, 44)
	layer.add_child(logo)
	var han := Label.new()
	han.text = "新 處容歌"
	han.add_theme_font_override("font", DialogBox._pixel_font("res://assets/fonts/Galmuri11.ttf"))
	han.add_theme_font_size_override("font_size", 12)
	han.add_theme_color_override("font_color", Color(0.75, 0.32, 0.26))
	han.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	han.position = Vector2(0, 102)
	han.size = Vector2(480, 16)
	layer.add_child(han)
	var items := [["처음부터", "new"]]
	if Game.has_save():
		items.append(["이어하기", "continue"])
	if Game.setting("intro_seen"):
		items.append(["회상", "replay"])
	var font := DialogBox._pixel_font("res://assets/fonts/Galmuri11.ttf")
	for i in items.size():
		var l := Label.new()
		l.text = items[i][0]
		l.add_theme_font_override("font", font)
		l.add_theme_font_size_override("font_size", 12)
		l.add_theme_color_override("font_outline_color", Color(0.02, 0.02, 0.05))
		l.add_theme_constant_override("outline_size", 4)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.position = Vector2(180, 168 + i * 20)
		l.size = Vector2(120, 18)
		l.mouse_filter = Control.MOUSE_FILTER_STOP
		l.gui_input.connect(func(ev):
			if (ev is InputEventScreenTouch or ev is InputEventMouseButton) and ev.pressed:
				_sel = i
				_go())
		layer.add_child(l)
		_opts.append(l)
		_actions.append(items[i][1])
	_paint()
	for c in layer.get_children():
		c.modulate.a = 0.0
		create_tween().tween_property(c, "modulate:a", 1.0, 1.6)


func _motes() -> void:
	var p := CPUParticles2D.new()
	p.amount = 40
	p.lifetime = 8.0
	p.preprocess = 8.0
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.emission_rect_extents = Vector2(260, 10)
	p.position = Vector2(240, 280)
	p.direction = Vector2(0.1, -1)
	p.spread = 15.0
	p.gravity = Vector2(0, -2)
	p.initial_velocity_min = 6.0
	p.initial_velocity_max = 16.0
	var ramp := Gradient.new()
	ramp.colors = PackedColorArray([Color(0.6, 0.8, 1, 0), Color(0.7, 0.85, 1, 0.9), Color(0.5, 0.5, 1, 0)])
	ramp.offsets = PackedFloat32Array([0.0, 0.3, 1.0])
	p.color_ramp = ramp
	add_child(p)


func _paint() -> void:
	for i in _opts.size():
		_opts[i].add_theme_color_override("font_color", CREAM if i == _sel else Color(0.5, 0.54, 0.64))
		_opts[i].text = ("· %s ·" if i == _sel else "%s") % _opts[i].text.trim_prefix("· ").trim_suffix(" ·")


func _process(d: float) -> void:
	_ready_t += d


func _unhandled_input(event: InputEvent) -> void:
	if _opts.is_empty() or _ready_t < 0.8:
		return
	if event.is_action_pressed("move_up"):
		_sel = (_sel - 1 + _opts.size()) % _opts.size(); _paint()
	elif event.is_action_pressed("move_down"):
		_sel = (_sel + 1) % _opts.size(); _paint()
	elif event.is_action_pressed("confirm") or event.is_action_pressed("attack"):
		_go()


func _go() -> void:
	if _ready_t < 0.8:
		return
	_ready_t = -99.0
	match _actions[_sel]:
		"new":
			Game.new_game()
			await Game.fade(1.0, 1.0)
			get_tree().change_scene_to_file("res://scenes/intro.tscn")
		"continue":
			Game.load_save()
			var cp: Array = Game.checkpoint_spawn()
			Game.change_level(cp[0], cp[1])
		"replay":
			Game.replaying = true
			await Game.fade(1.0, 1.0)
			get_tree().change_scene_to_file("res://scenes/intro.tscn")
