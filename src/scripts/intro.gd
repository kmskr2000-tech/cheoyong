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
var overlay := false   # 회상 from the 행낭: plays over the paused level and hands back to it
signal finished


func _ready() -> void:
	if overlay:
		Audio.override("title")
	else:
		Audio.music("title")
	Audio.ambience("waves")
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
		if s.texture.get_width() >= 96:   # NPC sheets: front, then 3/4 stances — stand turned
			s.hframes = s.texture.get_width() / (s.texture.get_height() * 2 / 3)
			s.frame = 1
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
	ramp.colors = PackedColorArray([Color(0.16, 0.03, 0.26, 0.0), Color(0.2, 0.04, 0.32, 0.5), Color(0.08, 0.01, 0.14, 0.0)])
	ramp.offsets = PackedFloat32Array([0.0, 0.4, 1.0])
	p.color_ramp = ramp
	parent.add_child(p)


## soft additive glow (pearl lamps, moon, village windows) — pulses gently when `pulse` > 0
func _glow(at: Vector2, color: Color, size := 48.0, pulse := 0.0) -> Sprite2D:
	var g := Gradient.new()
	g.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0)])
	var tex := GradientTexture2D.new()
	tex.gradient = g
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	tex.width = 64
	tex.height = 64
	var s := Sprite2D.new()
	s.texture = tex
	s.position = at
	s.scale = Vector2.ONE * size / 64.0
	s.modulate = color
	var add := CanvasItemMaterial.new()
	add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	s.material = add
	_shot.add_child(s)
	if pulse > 0.0:
		var tw := s.create_tween().set_loops()
		tw.tween_property(s, "modulate:a", color.a * (1.0 - pulse), 1.6 + randf() * 1.2).set_trans(Tween.TRANS_SINE)
		tw.tween_property(s, "modulate:a", color.a, 1.6 + randf() * 1.2).set_trans(Tween.TRANS_SINE)
	return s


## drifting motes / bubbles / 귀화 sparks: tiny additive particles, no new texture needed
func _motes(parent: Node, rect: Vector2, at: Vector2, color: Color, amount := 30, up := -1.0, speed := 8.0) -> CPUParticles2D:
	var p := CPUParticles2D.new()
	p.amount = amount
	p.lifetime = 9.0
	p.preprocess = 9.0
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.emission_rect_extents = rect
	p.position = at
	p.direction = Vector2(0.2, up)
	p.spread = 30.0
	p.gravity = Vector2(0, 0)
	p.initial_velocity_min = speed * 0.4
	p.initial_velocity_max = speed
	p.scale_amount_min = 1.0
	p.scale_amount_max = 2.0
	var ramp := Gradient.new()
	ramp.colors = PackedColorArray([Color(color, 0.0), Color(color, color.a), Color(color, 0.0)])
	ramp.offsets = PackedFloat32Array([0.0, 0.35, 1.0])
	p.color_ramp = ramp
	var add := CanvasItemMaterial.new()
	add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	p.material = add
	parent.add_child(p)
	return p


## slow push-in on the whole shot (tied to the shot node: it dies with it, and never changes the timing)
func _push(sec: float, to := 1.05, drift := Vector2.ZERO) -> void:
	_shot.pivot_offset = Vector2.ZERO
	var c := Vector2(240, 135)
	var tw := _shot.create_tween().set_parallel()
	tw.tween_property(_shot, "scale", Vector2.ONE * to, sec).set_trans(Tween.TRANS_SINE)
	tw.tween_property(_shot, "position", c * (1.0 - to) + drift, sec).set_trans(Tween.TRANS_SINE)


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
	_glow(Vector2(318, 150), Color(0.25, 0.55, 0.7, 0.5), 230.0, 0.3)   # pearl-light pooled around the drowned palace
	_glow(Vector2(300, 98), Color(1.0, 0.75, 0.4, 0.45), 40.0, 0.5)      # the bell finial's lamp
	var mid := _layer("res://assets/intro/intro_sea_mid.png", Vector2(-20, 0))
	mid.scale = Vector2(1.08, 1.0)
	_shafts(_shot)
	_taki(_shot, Vector2(260, 60))
	_motes(_shot, Vector2(250, 8), Vector2(240, 250), Color(0.5, 0.8, 0.95, 0.5), 28, -1.0, 7.0)   # plankton drifting up
	_motes(_shot, Vector2(260, 30), Vector2(240, 80), Color(0.65, 0.3, 0.85, 0.55), 10, -0.3, 5.0)  # 귀화 sparks in the tainted water
	var fg := _layer("res://assets/intro/intro_sea_fg.png", Vector2(-30, 0))
	fg.scale = Vector2(1.15, 1.0)
	var tw := create_tween().set_parallel()
	tw.tween_property(far, "position:x", 6.0, 9.0)
	tw.tween_property(mid, "position:x", 2.0, 9.0)
	tw.tween_property(fg, "position:x", 10.0, 9.0)
	_push(9.0, 1.05, Vector2(-4, 0))
	await _fade_in(1.6)
	await _narrate("바다가 탁해지면, 용왕도 탁해진다.", 3.0)
	await _fade_out()


## 2–3: 병석의 용왕. 세 아들. 맏형의 봉쇄론. 용왕의 유언과 용패.
func _shot_hall() -> void:
	_new_shot()
	_layer("res://assets/intro/intro_hall.png")
	var king := _sprite("res://assets/sprites/npc_dragonking.png", Vector2(240, 114))   # on the canopied bed
	king.rotation = -PI / 2
	king.offset = Vector2(0, -12)
	king.modulate = Color(0.82, 0.86, 0.92)
	var b1 := _sprite("res://assets/sprites/npc_brother1.png", Vector2(200, 168))   # 맏형 해강
	var b2 := _sprite("res://assets/sprites/npc_brother2.png", Vector2(280, 168))   # 둘째 해명
	b2.frame = 3   # the brothers turn in toward the bed
	var me := _sprite("res://assets/sprites/cheoyong.png", Vector2(240, 226), Rect2(64, 0, 64, 64))  # back view (up_idle)
	for pg in [Vector2(164, 117), Vector2(316, 117)]:
		_glow(pg, Color(0.45, 0.75, 0.85, 0.55), 70.0, 0.35)     # the great pearls on their pedestals
	for pg in [Vector2(160, 33), Vector2(320, 33), Vector2(176, 40), Vector2(300, 40)]:
		_glow(pg, Color(0.4, 0.7, 0.85, 0.5), 40.0, 0.4)
	_glow(Vector2(240, 120), Color(1.0, 0.7, 0.35, 0.28), 120.0, 0.25)   # lamplight over the sick-bed
	_motes(_shot, Vector2(240, 10), Vector2(240, 270), Color(0.6, 0.85, 1.0, 0.5), 34, -1.0, 9.0)   # bubbles rising through the hall
	_motes(_shot, Vector2(30, 6), Vector2(240, 108), Color(0.62, 0.3, 0.82, 0.6), 12, -1.0, 6.0)    # 탁기 curling off the king's bed
	_push(24.0, 1.06)
	await _fade_in()
	await dialog.say([
		{"name": "맏형 해강", "text": "용궁의 문을 닫읍시다."},
		{"name": "둘째 해명", "text": "형의 말이 맞습니다. 아버지를 위해서라도."},
		{"name": "용왕", "text": "…문을 닫으면 썩는 건 안쪽이다."},
	])
	if _done: return
	# the king turns his head; 처용 steps up to the bed
	var tw := create_tween()
	tw.tween_property(me, "position", Vector2(240, 176), 1.4)
	await tw.finished
	await dialog.say([
		{"name": "용왕", "text": "인간 세상의 액이 깊어진다."},
		{"name": "용왕", "text": "해강은 힘이 세고, 해명은 지혜롭다."},
		{"name": "용왕", "text": "그러나 인간을 가엾게 여기는 건 너뿐이다."},
	])
	if _done: return
	# 용패: a single glowing scale passes from the king's hand into his
	var scale_ := Sprite2D.new()
	scale_.texture = load("res://assets/ui/icons/item_dragonseal.png")   # 용인: the dragon's teardrop seal
	scale_.scale = Vector2(0.7, 0.7)
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
	var me := _sprite("res://assets/sprites/cheoyong.png", Vector2(240, 294), Rect2(64, 0, 64, 64))
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
	_motes(_shot, Vector2(240, 6), Vector2(240, 280), Color(0.7, 0.9, 1.0, 0.55), 30, -1.0, 24.0)   # a rush of bubbles on the way up
	await _fade_in(0.8)
	var tw := create_tween().set_parallel()
	tw.tween_property(me, "position:y", -40.0, 4.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tw.tween_property(sea, "position:y", 0.0, 4.2)
	tw.tween_property(sea, "modulate", Color(1.6, 1.7, 2.0), 4.2)
	await tw.finished
	await Game.fade(1.0, 0.25)
	_new_shot()
	_layer("res://assets/intro/intro_night.png")
	var head := _sprite("res://assets/sprites/cheoyong.png", Vector2(250, 197), Rect2(64, 20, 64, 28))  # head and shoulders above the swell
	head.modulate = Color(0.18, 0.22, 0.35)
	_glow(Vector2(340, 52), Color(0.55, 0.65, 0.9, 0.45), 130.0, 0.2)     # moon bloom
	for vx in [Vector2(40, 145), Vector2(63, 146), Vector2(104, 147), Vector2(128, 147)]:
		_glow(vx, Color(1.0, 0.62, 0.28, 0.5), 14.0, 0.6)               # village windows breathing
	_motes(_shot, Vector2(60, 3), Vector2(340, 190), Color(0.8, 0.9, 1.0, 0.7), 14, -0.2, 3.0)    # glints on the moon-path
	_push(7.5, 1.05, Vector2(-3, 0))
	var bob := head.create_tween().set_loops()
	bob.tween_property(head, "position:y", head.position.y + 1.5, 1.4).set_trans(Tween.TRANS_SINE)
	bob.tween_property(head, "position:y", head.position.y, 1.4).set_trans(Tween.TRANS_SINE)
	await _fade_in(1.0)
	await _narrate("셋째 아들은 노래를 안고 물 위로 올랐다.", 3.2)
	await _fade_out(1.4)


func _finish() -> void:
	if _done:
		return
	_done = true
	Game.set_setting("intro_seen", true)
	dialog.queue_free()
	if overlay:
		await Game.fade(1.0, 0.6)
		finished.emit()
		return
	# the autoload does the hand-off (this node is freed with the scene)
	if Game.replaying:
		Game.replaying = false
		Game.to_title()
	else:
		Game.change_level("beach", "start")
