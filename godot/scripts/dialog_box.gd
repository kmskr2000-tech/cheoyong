class_name DialogBox
extends CanvasLayer
## 옻칠 자개 dialogue box: black-lacquer panel with mother-of-pearl corners, the speaker's name on a
## vermilion seal that stamps in, typewriter text and a swaying 매듭 tassel when a line is complete.
## Sits above the HD-2D post layer so text stays crisp and ungraded.
##   await dialog.say([{"name": "처용", "text": "..."}, "narration without a speaker"])

signal finished

const CHARS_PER_SEC := 38.0
const FONT_SIZE := 12
const CREAM := Color(0.93, 0.88, 0.76)

var _lines: Array = []
var _i := 0
var _shown := 0.0
var _t := 0.0
var _active := false

var _root: Control
var _panel: NinePatchRect
var _seal: NinePatchRect
var _name: Label
var _body: Label
var _knot: TextureRect
var _knot_frames: Array[AtlasTexture] = []


func _ready() -> void:
	layer = 20
	process_mode = Node.PROCESS_MODE_ALWAYS  # the 행낭 menu runs while the game is paused
	var font := _pixel_font("res://assets/fonts/Galmuri11.ttf")
	var bold := _pixel_font("res://assets/fonts/Galmuri11-Bold.ttf")
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.visible = false
	add_child(_root)
	_panel = NinePatchRect.new()
	_panel.texture = load("res://assets/ui/panel.png")
	_panel.patch_margin_left = 14; _panel.patch_margin_right = 14
	_panel.patch_margin_top = 14; _panel.patch_margin_bottom = 14
	_panel.axis_stretch_horizontal = NinePatchRect.AXIS_STRETCH_MODE_TILE
	_panel.axis_stretch_vertical = NinePatchRect.AXIS_STRETCH_MODE_TILE
	_panel.position = Vector2(20, 188)
	_panel.size = Vector2(440, 74)
	_root.add_child(_panel)
	_body = Label.new()
	_body.add_theme_font_override("font", font)
	_body.add_theme_font_size_override("font_size", FONT_SIZE)
	_body.add_theme_color_override("font_color", CREAM)
	_body.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	_body.add_theme_constant_override("shadow_offset_x", 1)
	_body.add_theme_constant_override("shadow_offset_y", 1)
	_body.add_theme_constant_override("line_spacing", 3)
	_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body.position = Vector2(20, 18)
	_body.size = Vector2(396, 46)
	_panel.add_child(_body)
	_seal = NinePatchRect.new()
	_seal.texture = load("res://assets/ui/seal.png")
	_seal.patch_margin_left = 6; _seal.patch_margin_right = 6
	_seal.patch_margin_top = 6; _seal.patch_margin_bottom = 6
	_seal.position = Vector2(30, 177)
	_root.add_child(_seal)
	_name = Label.new()
	_name.add_theme_font_override("font", bold)
	_name.add_theme_font_size_override("font_size", FONT_SIZE)
	_name.add_theme_color_override("font_color", CREAM)
	_name.position = Vector2(8, 3)
	_seal.add_child(_name)
	var ktex: Texture2D = load("res://assets/ui/knot.png")
	for f in 2:
		var at := AtlasTexture.new()
		at.atlas = ktex
		at.region = Rect2(f * 9, 0, 9, 14)
		_knot_frames.append(at)
	_knot = TextureRect.new()
	_knot.texture = _knot_frames[0]
	_knot.position = Vector2(_panel.size.x - 20, _panel.size.y - 16)
	_panel.add_child(_knot)


static func _pixel_font(path: String) -> FontFile:
	var f: FontFile = load(path).duplicate()
	f.antialiasing = TextServer.FONT_ANTIALIASING_NONE
	f.hinting = TextServer.HINTING_NONE
	f.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_DISABLED
	return f


func say(lines: Array) -> void:
	_lines = lines
	_i = 0
	_active = true
	_root.visible = true
	_show_line()
	# slide up and fade in
	_panel.modulate.a = 0.0
	_panel.position.y = 194
	var tw := create_tween().set_parallel()
	tw.tween_property(_panel, "modulate:a", 1.0, 0.15)
	tw.tween_property(_panel, "position:y", 188.0, 0.15).set_ease(Tween.EASE_OUT)
	await finished


func _show_line() -> void:
	var line = _lines[_i]
	var who: String = line.get("name", "") if line is Dictionary else ""
	_body.text = line["text"] if line is Dictionary else String(line)
	_body.visible_characters = 0
	_shown = 0.0
	_seal.visible = who != ""
	if who != "":
		_name.text = who
		var w := _name.get_minimum_size().x
		_seal.size = Vector2(w + 16, 20)
		# stamp: drops in slightly large and settles with a tiny ink shake
		_seal.pivot_offset = _seal.size / 2.0
		_seal.scale = Vector2(1.35, 1.35)
		_seal.modulate.a = 0.0
		var tw := create_tween().set_parallel()
		tw.tween_property(_seal, "scale", Vector2.ONE, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(_seal, "modulate:a", 1.0, 0.08)


func _process(delta: float) -> void:
	if not _active:
		return
	_t += delta
	var total := _body.get_total_character_count()
	if _shown < total:
		_shown = minf(total, _shown + delta * CHARS_PER_SEC)
		_body.visible_characters = int(_shown)
	var done := _shown >= total
	_knot.visible = done
	if done:
		_knot.texture = _knot_frames[int(_t * 3.0) % 2]
		_knot.position.y = _panel.size.y - 16 + roundf(sin(_t * 4.0))


# ---------------------------------------------------------------- choices (상점, 예/아니오)
signal chosen(index: int)
var _menu: NinePatchRect
var _opts: Array[Label] = []
var _sel := 0
var _choosing := false


## show a prompt line and a list of options above the box; returns the picked index
##   var i := await dialog.choose({"name": "약방 주인", "text": "무엇을 드릴까?"}, ["인삼정기탕 30냥", "그만두겠소"])
func choose(line, options: Array) -> int:
	_lines = [line]
	_i = 0
	_active = false
	_root.visible = true
	_show_line()
	_shown = _body.get_total_character_count()
	_body.visible_characters = -1
	_knot.visible = false
	if _menu:
		_menu.queue_free()
	_opts.clear()
	_menu = NinePatchRect.new()
	_menu.texture = _panel.texture
	_menu.patch_margin_left = 14; _menu.patch_margin_right = 14; _menu.patch_margin_top = 14; _menu.patch_margin_bottom = 14
	_menu.axis_stretch_horizontal = NinePatchRect.AXIS_STRETCH_MODE_TILE
	_menu.axis_stretch_vertical = NinePatchRect.AXIS_STRETCH_MODE_TILE
	var font := _pixel_font("res://assets/fonts/Galmuri11.ttf")
	var w := 0.0
	for i in options.size():
		var l := Label.new()
		l.text = options[i]
		l.add_theme_font_override("font", font)
		l.add_theme_font_size_override("font_size", FONT_SIZE)
		l.position = Vector2(16, 12 + i * 18)
		l.mouse_filter = Control.MOUSE_FILTER_STOP
		l.gui_input.connect(func(ev):
			if (ev is InputEventScreenTouch or ev is InputEventMouseButton) and ev.pressed:
				_sel = i
				_pick())
		_menu.add_child(l)
		_opts.append(l)
		w = maxf(w, l.get_minimum_size().x)
	_menu.size = Vector2(w + 44, options.size() * 18 + 24)
	_menu.position = Vector2(460 - _menu.size.x, 184 - _menu.size.y)
	_root.add_child(_menu)
	_sel = 0
	_paint_menu()
	_choosing = true
	var idx: int = await chosen
	return idx


func _paint_menu() -> void:
	for i in _opts.size():
		var on := i == _sel
		_opts[i].add_theme_color_override("font_color", CREAM if on else Color(0.6, 0.6, 0.66))
		_opts[i].text = ("▶ " if on else "   ") + _opts[i].text.trim_prefix("▶ ").trim_prefix("   ")


func _pick() -> void:
	if not _choosing:
		return
	_choosing = false
	_menu.queue_free()
	_menu = null
	_root.visible = false
	chosen.emit(_sel)


func _unhandled_input(event: InputEvent) -> void:
	if _choosing:
		if event.is_action_pressed("move_up"):
			_sel = (_sel - 1 + _opts.size()) % _opts.size(); _paint_menu()
		elif event.is_action_pressed("move_down"):
			_sel = (_sel + 1) % _opts.size(); _paint_menu()
		elif event.is_action_pressed("confirm"):
			_pick()
		else:
			return
		get_viewport().set_input_as_handled()
		return
	if not _active:
		return
	var press: bool = event.is_action_pressed("confirm") or (event is InputEventScreenTouch and event.pressed) \
		or (event is InputEventMouseButton and event.pressed)
	if not press:
		return
	get_viewport().set_input_as_handled()
	if _shown < _body.get_total_character_count():
		_shown = _body.get_total_character_count()  # first press completes the line
		_body.visible_characters = -1
		return
	_i += 1
	if _i >= _lines.size():
		_active = false
		_root.visible = false
		finished.emit()
	else:
		_show_line()
