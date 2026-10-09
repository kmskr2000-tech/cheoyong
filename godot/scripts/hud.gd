class_name Hud
extends CanvasLayer
## Combat HUD and touch controls (landscape phone). Same lacquer / brass / pearl language as the
## dialogue box. Touch controls appear on touchscreens (or with --touch): a floating joystick on the
## left half (it appears where the thumb lands) and lacquer buttons on the right.

const STICK_R := 20.0

var player: Node
var _hp_fill: TextureRect
var _ki_fill: TextureRect
var _hp_w := 96.0
var _ki_w := 72.0
var _touch_root: Control
var _base: TextureRect
var _knob: TextureRect
var _stick_id := -1
var _stick_origin := Vector2.ZERO


func _ready() -> void:
	layer = 15
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	var em := TextureRect.new()
	em.texture = load("res://assets/ui/emblem.png")
	em.position = Vector2(6, 5)
	root.add_child(em)
	_hp_fill = _gauge(root, Vector2(30, 8), _hp_w, "res://assets/ui/gauge_hp.png")
	_ki_fill = _gauge(root, Vector2(30, 19), _ki_w, "res://assets/ui/gauge_ki.png")
	_touch_root = Control.new()
	_touch_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_touch_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_touch_root)
	_base = TextureRect.new()
	_base.texture = load("res://assets/ui/stick_base.png")
	_base.visible = false
	_touch_root.add_child(_base)
	_knob = TextureRect.new()
	_knob.texture = load("res://assets/ui/stick_knob.png")
	_knob.visible = false
	_touch_root.add_child(_knob)
	# buttons: [texture, action, centre, touch radius]
	for b in [["attack", "attack", Vector2(430, 222), 30.0], ["roll", "roll", Vector2(384, 244), 22.0],
			["talisman", "talisman", Vector2(394, 196), 22.0], ["song", "song", Vector2(438, 172), 22.0],
			["menu", "pause", Vector2(462, 16), 16.0]]:
		var ring := Sprite2D.new()  # glow behind the button, shown when it is the one to press
		ring.texture = load("res://assets/ui/glow_ring.png")
		ring.position = b[2]
		ring.visible = false
		var rm := CanvasItemMaterial.new()
		rm.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		ring.material = rm
		_touch_root.add_child(ring)
		_rings[b[0]] = ring
		var tb := TouchScreenButton.new()
		var tex: Texture2D = load("res://assets/ui/btn_%s.png" % b[0])
		tb.texture_normal = tex
		tb.action = b[1]
		var shape := CircleShape2D.new()
		shape.radius = b[3]
		tb.shape = shape
		tb.shape_centered = true
		tb.position = b[2] - tex.get_size() / 2.0
		tb.passby_press = true
		_touch_root.add_child(tb)
		_buttons[b[0]] = tb
	# the 말하기 face laid over the attack button while something can be talked to
	_talk = Sprite2D.new()
	_talk.texture = load("res://assets/ui/btn_talk.png")
	_talk.position = Vector2(430, 222)
	_talk.visible = false
	_touch_root.add_child(_talk)
	_toast = Label.new()
	_toast.add_theme_font_override("font", DialogBox._pixel_font("res://assets/fonts/Galmuri11.ttf"))
	_toast.add_theme_font_size_override("font_size", 12)
	_toast.add_theme_color_override("font_outline_color", Color(0.02, 0.02, 0.06))
	_toast.add_theme_constant_override("outline_size", 4)
	_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast.position = Vector2(0, 54)
	_toast.size = Vector2(480, 20)
	_toast.modulate.a = 0.0
	root.add_child(_toast)
	Game.toast.connect(show_toast)
	_pause_panel = _make_pause()
	add_child(_pause_panel)
	process_mode = Node.PROCESS_MODE_ALWAYS
	_touch_root.visible = DisplayServer.is_touchscreen_available() or "--touch" in OS.get_cmdline_user_args()
	if _touch_root.visible:
		_show_stick(Vector2(70, 214))  # resting position hint


var _pause_panel: Control
var _buttons := {}
var _rings := {}
var _talk: Sprite2D
var _talk_on := false
var _guide := ""
var _toast: Label
var _toast_tw: Tween


# ---------------------------------------------------------------- button guidance (BotW: 빛나는 버튼 하나)
## light up one button and dim the rest ("" clears); the tutorial's only voice
func guide(name: String) -> void:
	_guide = name


## something talkable is near: the attack button turns into 말하기 and glows
func set_talk(on: bool) -> void:
	_talk_on = on


func _process(_d: float) -> void:
	if not _touch_root.visible or _buttons.is_empty():
		return
	var t := Time.get_ticks_msec() / 1000.0
	var lit := _guide
	if lit == "" and _talk_on:
		lit = "attack"
	elif lit == "" and player and player.has_method("can_sing") and player.can_sing():
		lit = "song"
	_talk.visible = _talk_on
	_buttons["song"].visible = Game.flag("flute") == 1
	_buttons["attack"].modulate.a = 0.0 if _talk_on else 1.0
	for k in _buttons:
		var on: bool = k == lit and _buttons[k].visible
		_rings[k].visible = on
		if on:
			var s := 1.0 + sin(t * 5.0) * 0.08
			_rings[k].scale = Vector2(s, s) * (1.0 if k == "attack" else 0.8)
			_rings[k].modulate.a = 0.65 + sin(t * 5.0) * 0.3
		if k != "attack" or not _talk_on:
			_buttons[k].modulate.a = 1.0 if (_guide == "" or on or k == "menu") else 0.35


## fade the whole HUD in (after a cutscene that hid it)
func reveal(time := 0.8) -> void:
	visible = true
	for c in get_children():
		if c is CanvasItem:
			c.modulate.a = 0.0
			c.create_tween().tween_property(c, "modulate:a", 1.0, time)


func show_toast(text: String, color: Color) -> void:
	_toast.text = text
	_toast.add_theme_color_override("font_color", color)
	if _toast_tw:
		_toast_tw.kill()
	_toast_tw = create_tween()
	_toast_tw.tween_property(_toast, "modulate:a", 1.0, 0.2)
	_toast_tw.tween_interval(1.8)
	_toast_tw.tween_property(_toast, "modulate:a", 0.0, 0.5)


func _make_pause() -> Control:
	var c := Control.new()
	c.set_anchors_preset(Control.PRESET_FULL_RECT)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.visible = false
	var dim := ColorRect.new()
	dim.color = Color(0.01, 0.02, 0.06, 0.6)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.add_child(dim)
	var p := NinePatchRect.new()
	p.texture = load("res://assets/ui/panel.png")
	p.patch_margin_left = 14; p.patch_margin_right = 14; p.patch_margin_top = 14; p.patch_margin_bottom = 14
	p.axis_stretch_horizontal = NinePatchRect.AXIS_STRETCH_MODE_TILE
	p.axis_stretch_vertical = NinePatchRect.AXIS_STRETCH_MODE_TILE
	p.position = Vector2(160, 100)
	p.size = Vector2(160, 64)
	c.add_child(p)
	var l := Label.new()
	l.text = "일시정지\n메뉴를 다시 누르면 계속"
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_override("font", DialogBox._pixel_font("res://assets/fonts/Galmuri11.ttf"))
	l.add_theme_font_size_override("font_size", 12)
	l.add_theme_color_override("font_color", Color(0.93, 0.88, 0.76))
	l.position = Vector2(0, 16)
	l.size = Vector2(160, 40)
	p.add_child(l)
	return c


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		get_tree().paused = not get_tree().paused
		_pause_panel.visible = get_tree().paused
		get_viewport().set_input_as_handled()


func _gauge(root: Control, at: Vector2, w: float, fill: String) -> TextureRect:
	var fr := NinePatchRect.new()
	fr.texture = load("res://assets/ui/gauge_frame.png")
	fr.patch_margin_left = 3; fr.patch_margin_right = 3; fr.patch_margin_top = 3; fr.patch_margin_bottom = 3
	fr.position = at
	fr.size = Vector2(w + 4, 10)
	root.add_child(fr)
	var f := TextureRect.new()
	f.texture = load(fill)
	f.stretch_mode = TextureRect.STRETCH_TILE
	f.position = at + Vector2(2, 2)
	f.size = Vector2(w, 6)
	root.add_child(f)
	return f


func bind(p: Node) -> void:
	player = p
	p.stats_changed.connect(_on_stats)
	_on_stats(p.hp, p.max_hp, p.ki, p.max_ki)


func _on_stats(hp: float, max_hp: float, ki: float, max_ki: float) -> void:
	_hp_fill.size.x = roundf(_hp_w * clampf(hp / max_hp, 0, 1))
	_ki_fill.size.x = roundf(_ki_w * clampf(ki / max_ki, 0, 1))


# ---------------------------------------------------------------- boss gauge
var _boss_fill: TextureRect
var _boss_root: Control
const BOSS_W := 200.0


func show_boss(boss: Node, title: String) -> void:
	_boss_root = Control.new()
	_boss_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_boss_root)
	_boss_fill = _gauge(_boss_root, Vector2(140, 34), BOSS_W, "res://assets/ui/gauge_hp.png")
	var seal := NinePatchRect.new()
	seal.texture = load("res://assets/ui/seal.png")
	seal.patch_margin_left = 6; seal.patch_margin_right = 6; seal.patch_margin_top = 6; seal.patch_margin_bottom = 6
	var name := Label.new()
	name.text = title
	name.add_theme_font_override("font", DialogBox._pixel_font("res://assets/fonts/Galmuri11-Bold.ttf"))
	name.add_theme_font_size_override("font_size", 12)
	name.add_theme_color_override("font_color", Color(0.93, 0.88, 0.76))
	name.position = Vector2(8, 3)
	seal.add_child(name)
	seal.size = Vector2(name.get_minimum_size().x + 16, 20)
	seal.position = Vector2(240 - seal.size.x / 2.0, 14)
	_boss_root.add_child(seal)
	boss.hp_changed.connect(func(hp, mx): _boss_fill.size.x = roundf(BOSS_W * clampf(hp / mx, 0, 1)))
	boss.defeated.connect(func(): _boss_root.queue_free())


# ---------------------------------------------------------------- floating joystick
func _show_stick(at: Vector2) -> void:
	_stick_origin = at
	_base.position = at - _base.texture.get_size() / 2.0
	_knob.position = at - _knob.texture.get_size() / 2.0
	_base.visible = true
	_knob.visible = true
	_base.modulate.a = 0.5
	_knob.modulate.a = 0.5


func _input(event: InputEvent) -> void:
	if not _touch_root.visible:
		return
	if event is InputEventScreenTouch:
		var pos := _to_ui(event.position)
		if event.pressed and _stick_id == -1 and pos.x < 220:
			_stick_id = event.index
			_show_stick(pos)
			_base.modulate.a = 1.0
			_knob.modulate.a = 1.0
		elif not event.pressed and event.index == _stick_id:
			_stick_id = -1
			_set_dir(Vector2.ZERO)
			_show_stick(Vector2(70, 214))
	elif event is InputEventScreenDrag and event.index == _stick_id:
		var off := _to_ui(event.position) - _stick_origin
		if off.length() > STICK_R:
			off = off.normalized() * STICK_R
		_knob.position = _stick_origin + off - _knob.texture.get_size() / 2.0
		_set_dir(off / STICK_R)


## screen (window) pixels → the 480x270 UI space
func _to_ui(p: Vector2) -> Vector2:
	return get_viewport().get_screen_transform().affine_inverse() * p


func _set_dir(v: Vector2) -> void:
	for a in ["move_left", "move_right", "move_up", "move_down"]:
		Input.action_release(a)
	if v.length() < 0.2:
		return
	if v.x < 0: Input.action_press("move_left", -v.x)
	if v.x > 0: Input.action_press("move_right", v.x)
	if v.y < 0: Input.action_press("move_up", -v.y)
	if v.y > 0: Input.action_press("move_down", v.y)
