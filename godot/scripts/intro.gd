extends Node2D
## 인트로 「떠나는 자」 (docs/story-bible.md 제4부 PART 1). Four painted shots, then shot 5 is the
## beach level itself (same angle as the first playable screen) where the title logo appears.
##   1 어두운 바닷속, 탁기, 멀리 용궁  2 병석의 용왕과 세 아들  3 용패를 쥐여 주는 유언  4 수면 위로
## Never shows 난영, 역신, 왕 or the appointment. Skippable (건너뛰기 / menu).

const CREAM := Color(0.93, 0.88, 0.76)
var dialog: DialogBox
var _sub: Label
var _skip: Label
var _shot: Node2D
var _done := false


func _ready() -> void:
	dialog = DialogBox.new()
	add_child(dialog)
	var ui := CanvasLayer.new()
	ui.layer = 25
	add_child(ui)
	_sub = Label.new()
	_sub.add_theme_font_override("font", DialogBox._pixel_font("res://assets/fonts/Galmuri11.ttf"))
	_sub.add_theme_font_size_override("font_size", 12)
	_sub.add_theme_color_override("font_color", CREAM)
	_sub.add_theme_color_override("font_outline_color", Color(0.01, 0.01, 0.03))
	_sub.add_theme_constant_override("outline_size", 4)
	_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_sub.position = Vector2(0, 226)
	_sub.size = Vector2(480, 20)
	_sub.modulate.a = 0.0
	ui.add_child(_sub)
	_skip = Label.new()
	_skip.text = "건너뛰기 ▶"
	_skip.add_theme_font_override("font", DialogBox._pixel_font("res://assets/fonts/Galmuri11.ttf"))
	_skip.add_theme_font_size_override("font_size", 12)
	_skip.add_theme_color_override("font_color", Color(0.6, 0.64, 0.74))
	_skip.position = Vector2(400, 6)
	_skip.mouse_filter = Control.MOUSE_FILTER_STOP
	_skip.gui_input.connect(func(ev):
		if (ev is InputEventScreenTouch or ev is InputEventMouseButton) and ev.pressed:
			_finish())
	ui.add_child(_skip)
	_play()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		_finish()


# ---------------------------------------------------------------- the shots
func _play() -> void:
	await _shot_sea()
	if _done: return
	await _shot_hall()
	if _done: return
	await _shot_rise()
	if _done: return
	_finish()


## narration: a centred subtitle that fades in and out by itself
func _narrate(text: String, hold := 2.6) -> void:
	_sub.text = text
	var tw := create_tween()
	tw.tween_property(_sub, "modulate:a", 1.0, 0.8)
	tw.tween_interval(hold)
	tw.tween_property(_sub, "modulate:a", 0.0, 0.8)
	await tw.finished


func _new_shot() -> Node2D:
	if _shot:
		_shot.queue_free()
	_shot = Node2D.new()
	add_child(_shot)
	move_child(_shot, 0)
	return _shot


func _layer(path: String, at := Vector2.ZERO) -> Sprite2D:
	var s := Sprite2D.new()
	s.texture = load(path)
	s.centered = false
	s.position = at
	_shot.add_child(s)
	return s


func _sprite(path: String, at: Vector2, region := Rect2()) -> Sprite2D:
	var s := Sprite2D.new()
	if region.size != Vector2.ZERO:
		var at_ := AtlasTexture.new()
		at_.atlas = load(path)
		at_.region = region
		s.texture = at_
	else:
		s.texture = load(path)
	s.position = at
	s.offset = Vector2(0, -20)
	_shot.add_child(s)
	return s


func _taki(parent: Node2D, rect: Vector2, amount := 26) -> void:
	# black 탁기 seeping through the water like ink
	var p := CPUParticles2D.new()
	p.amount = amount
	p.lifetime = 7.0
	p.preprocess = 7.0
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.emission_rect_extents = rect
	p.position = Vector2(240, 60)
	p.direction = Vector2(0.4, 1)
	p.spread = 25.0
	p.gravity = Vector2(0, 2)
	p.initial_velocity_min = 3.0
	p.initial_velocity_max = 10.0
	var g := Gradient.new()
	g.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0)])
	var soft := GradientTexture2D.new()
	soft.gradient = g
	soft.fill = GradientTexture2D.FILL_RADIAL
	soft.fill_from = Vector2(0.5, 0.5)
	soft.fill_to = Vector2(1.0, 0.5)
	soft.width = 32
	soft.height = 32
	p.texture = soft
	p.scale_amount_min = 0.6
	p.scale_amount_max = 1.6
	var ramp := Gradient.new()
	ramp.colors = PackedColorArray([Color(0.02, 0.0, 0.04, 0.0), Color(0.03, 0.0, 0.06, 0.55), Color(0.05, 0.01, 0.08, 0.0)])
	ramp.offsets = PackedFloat32Array([0.0, 0.4, 1.0])
	p.color_ramp = ramp
	parent.add_child(p)


func _shafts(parent: Node2D) -> void:
	var r := ColorRect.new()
	r.size = Vector2(480, 270)
	var m := ShaderMaterial.new()
	m.shader = load("res://shaders/shafts.gdshader")
	r.material = m
	parent.add_child(r)


func _fade_in(t := 1.2) -> void:
	await Game.fade(0.0, t)


func _fade_out(t := 1.0) -> void:
	await Game.fade(1.0, t)


## 1: 어두운 바닷속. 검은 탁기가 물결처럼 스며든다. 멀리 용궁의 실루엣.
func _shot_sea() -> void:
	_new_shot()
	_layer("res://assets/intro/intro_sea.png")
	var far := _layer("res://assets/intro/intro_sea_far.png", Vector2(-10, 0))
	_shafts(_shot)
	_taki(_shot, Vector2(260, 60))
	var fg := _layer("res://assets/intro/intro_sea_fg.png", Vector2(-30, 0))
	fg.scale = Vector2(1.15, 1.0)
	var tw := create_tween().set_parallel()
	tw.tween_property(far, "position:x", 6.0, 9.0)
	tw.tween_property(fg, "position:x", 10.0, 9.0)
	await _fade_in(1.6)
	await _narrate("바다가 탁해지면, 용왕도 탁해진다.", 3.0)
	await _fade_out()


## 2–3: 병석의 용왕. 세 아들. 맏형의 봉쇄론. 용왕의 유언과 용패.
func _shot_hall() -> void:
	_new_shot()
	_layer("res://assets/intro/intro_hall.png")
	var king := _sprite("res://assets/sprites/npc_dragonking.png", Vector2(240, 150))
	king.rotation = -PI / 2
	king.offset = Vector2(0, -12)
	king.modulate = Color(0.82, 0.86, 0.92)
	var b1 := _sprite("res://assets/sprites/npc_brother1.png", Vector2(176, 196))
	var b2 := _sprite("res://assets/sprites/npc_brother2.png", Vector2(304, 196))
	var me := _sprite("res://assets/sprites/cheoyong.png", Vector2(240, 214), Rect2(32, 0, 32, 48))  # back view (up_idle)
	await _fade_in()
	await dialog.say([
		{"name": "맏형", "text": "용궁의 문을 닫읍시다."},
		{"name": "용왕", "text": "…문을 닫으면 썩는 건 안쪽이다."},
	])
	if _done: return
	# the king turns his head; 처용 steps up to the bed
	var tw := create_tween()
	tw.tween_property(me, "position", Vector2(240, 178), 1.4)
	await tw.finished
	await dialog.say([
		{"name": "용왕", "text": "인간 세상의 액이 깊어진다."},
		{"name": "용왕", "text": "인간을 가엾게 여기는 건 너뿐이다."},
	])
	if _done: return
	# 용패: a single glowing scale passes from the king's hand into his
	var scale_ := Sprite2D.new()
	var img := Image.create(5, 7, false, Image.FORMAT_RGBA8)
	for y in 7:
		for x in 5:
			if Vector2((x - 2) / 2.5, (y - 3) / 3.5).length() < 1.0:
				img.set_pixel(x, y, Color(0.75, 0.95, 1.0) if y < 3 else Color(0.35, 0.7, 0.85))
	scale_.texture = ImageTexture.create_from_image(img)
	scale_.position = king.position + Vector2(-8, -10)
	var add := CanvasItemMaterial.new()
	add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	scale_.material = add
	_shot.add_child(scale_)
	tw = create_tween()
	tw.tween_property(scale_, "position", me.position + Vector2(0, -28), 1.6).set_trans(Tween.TRANS_SINE)
	tw.tween_property(scale_, "modulate:a", 0.0, 0.5)
	await tw.finished
	# 대답 없이 고개 숙임
	tw = create_tween()
	tw.tween_property(me, "position:y", me.position.y + 2, 0.4)
	tw.tween_interval(1.0)
	await tw.finished
	await _fade_out()


## 4: 수면으로 올라간다. 파도와 달빛. 먼 곳 인간 마을의 불빛들.
func _shot_rise() -> void:
	_new_shot()
	var sea := _layer("res://assets/intro/intro_sea.png", Vector2(0, -90))
	sea.scale = Vector2(1, 1.34)
	_shafts(_shot)
	var me := _sprite("res://assets/sprites/cheoyong.png", Vector2(240, 300), Rect2(32, 0, 32, 48))
	me.modulate = Color(0.25, 0.32, 0.5)
	var bub := CPUParticles2D.new()
	bub.amount = 20
	bub.lifetime = 3.0
	bub.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	bub.emission_rect_extents = Vector2(8, 4)
	bub.direction = Vector2(0, -1)
	bub.gravity = Vector2(0, -20)
	bub.initial_velocity_min = 10.0
	bub.initial_velocity_max = 30.0
	bub.color = Color(0.6, 0.8, 1.0, 0.6)
	me.add_child(bub)
	await _fade_in(0.8)
	var tw := create_tween().set_parallel()
	tw.tween_property(me, "position:y", -40.0, 4.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tw.tween_property(sea, "position:y", 0.0, 4.2)
	tw.tween_property(sea, "modulate", Color(1.6, 1.7, 2.0), 4.2)
	await tw.finished
	await Game.fade(1.0, 0.25)
	_new_shot()
	_layer("res://assets/intro/intro_night.png")
	var head := _sprite("res://assets/sprites/cheoyong.png", Vector2(250, 196), Rect2(32, 0, 32, 26))  # head and shoulders above the swell
	head.modulate = Color(0.18, 0.22, 0.35)
	await _fade_in(1.0)
	await _narrate("셋째 아들은 노래를 안고 물 위로 올랐다.", 3.2)
	await _fade_out(1.4)


func _finish() -> void:
	if _done:
		return
	_done = true
	Game.set_setting("intro_seen", true)
	dialog.queue_free()
	# the autoload does the hand-off (this node is freed with the scene)
	if Game.replaying:
		Game.replaying = false
		Game.to_title()
	else:
		Game.change_level("beach", "start")
