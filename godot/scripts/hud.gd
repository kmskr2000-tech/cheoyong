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
var _sin_w := 56.0
var _sin_fill: TextureRect
var _tal_label: Label
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
	_lv = Label.new()
	_lv.add_theme_font_override("font", DialogBox._pixel_font("res://assets/fonts/Galmuri11.ttf"))
	_lv.add_theme_font_size_override("font_size", 12)
	_lv.add_theme_color_override("font_color", Color(0.95, 0.85, 0.6))
	_lv.add_theme_color_override("font_outline_color", Color(0.02, 0.02, 0.05))
	_lv.add_theme_constant_override("outline_size", 4)
	_lv.position = Vector2(30, 40)
	root.add_child(_lv)
	_refresh_lv()
	Game.leveled.connect(func(_l): _refresh_lv())
	_ki_fill = _gauge(root, Vector2(30, 19), _ki_w, "res://assets/ui/gauge_ki.png")
	_sin_fill = _gauge(root, Vector2(30, 30), _sin_w, "res://assets/ui/gauge_sin.png")   # 신명
	_sin_fill.size.x = 0.0
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
			["dance", "dance", Vector2(396, 150), 22.0], ["swap", "swap", Vector2(360, 186), 13.0],
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
	_tal_label = Label.new()   # which talisman the button will draw
	_tal_label.add_theme_font_override("font", DialogBox._pixel_font("res://assets/fonts/Galmuri11.ttf"))
	_tal_label.add_theme_font_size_override("font_size", 12)
	_tal_label.add_theme_color_override("font_color", Color(0.94, 0.88, 0.7))
	_tal_label.add_theme_color_override("font_outline_color", Color(0.02, 0.02, 0.05))
	_tal_label.add_theme_constant_override("outline_size", 4)
	_tal_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_tal_label.position = Vector2(364, 208)
	_tal_label.size = Vector2(60, 14)
	_touch_root.add_child(_tal_label)
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
	process_mode = Node.PROCESS_MODE_ALWAYS
	_touch_root.visible = DisplayServer.is_touchscreen_available() or "--touch" in OS.get_cmdline_user_args()
	if _touch_root.visible:
		_show_stick(Vector2(70, 214))  # resting position hint


var _buttons := {}
var _lv: Label


func _refresh_lv() -> void:
	_lv.text = "Lv.%d" % Game.lv
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
	elif lit == "" and player and player.can_dance():
		lit = "dance"
	_buttons["dance"].visible = player != null and player.can_dance()
	_buttons["swap"].visible = Game.flag("flute") == 1
	_tal_label.visible = _buttons["swap"].visible
	if player:
		_tal_label.text = player.TAL_NAME[player.current_talisman()]
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


## the 용패 emblem flushes a colour and settles (it "rings")
func pulse_emblem(col: Color) -> void:
	var em: CanvasItem = get_child(0).get_child(0)
	var tw := create_tween()
	for i in 3:
		tw.tween_property(em, "modulate", col, 0.08)
		tw.tween_property(em, "modulate", Color.WHITE, 0.22)


func show_toast(text: String, color: Color) -> void:
	_toast.text = text
	_toast.add_theme_color_override("font_color", color)
	if _toast_tw:
		_toast_tw.kill()
	_toast_tw = create_tween()
	_toast_tw.tween_property(_toast, "modulate:a", 1.0, 0.2)
	_toast_tw.tween_interval(1.8)
	_toast_tw.tween_property(_toast, "modulate:a", 0.0, 0.5)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause") and not get_tree().paused and not player.locked:
		get_viewport().set_input_as_handled()
		_open_bag()


## 행낭: the pause menu is a list of what he carries; picking a remedy uses it
func _open_bag() -> void:
	var dialog: DialogBox = get_parent().dialog
	get_tree().paused = true
	while true:
		var status := "Lv.%d  덕망 %d/%d · 정기 %d · 엽전 %d냥" % [Game.lv, Game.deok, Game.need(Game.lv), Game.jeonggi, Game.money]
		var i: int = await dialog.choose({"name": "행낭", "text": status},
			["약 꺼내기", "수련 (%d점)" % Game.skill_points, "요괴 도감 (%d/%d)" % [Game.dogam_count(), Bestiary.ENTRIES.size()], "지닌 것", "회상", "닫기"])
		if i == 0:
			if await _bag_items(dialog):
				break
		elif i == 1:
			await _bag_skills(dialog)
		elif i == 2:
			await _bag_dogam(dialog)
		elif i == 3:
			await _bag_kept(dialog)
		elif i == 4:
			await _recall()
			break
		else:
			break
	get_tree().paused = false


## 회상: the intro 「떠나는 자」 again, played over the paused level; the level is left exactly as it was
func _recall() -> void:
	var level := get_parent()
	var prev_override: String = Audio._override
	await Game.fade(1.0, 0.6)
	var cl := CanvasLayer.new()
	cl.layer = 18
	cl.process_mode = Node.PROCESS_MODE_ALWAYS
	var bg := ColorRect.new()  # the level must not show through between shots
	bg.color = Color.BLACK
	bg.size = Vector2(480, 270)
	cl.add_child(bg)
	var intro: Node = load("res://scenes/intro.tscn").instantiate()
	intro.overlay = true
	cl.add_child(intro)
	level.add_child(cl)
	await intro.finished
	cl.queue_free()
	Audio.override(prev_override)
	Audio.ambience(Levels.DATA[Game.level_id].get("amb", ""))
	await Game.fade(0.0, 0.6)


## returns true when the bag should close (a 정화부 was used)
func _bag_items(dialog: DialogBox) -> bool:
	while true:
		var opts := []
		var ids := []
		for it in Game.SHOP:
			opts.append("%s ×%d" % [it["name"], int(Game.items.get(it["id"], 0))])
			ids.append(it["id"])
		opts.append("돌아가기")
		var i: int = await dialog.choose({"name": "행낭", "text": "무엇을 꺼내겠소?"}, opts)
		if i >= ids.size():
			return false
		if player.use_item(ids[i]):
			Game.say_toast("%s을(를) 썼다." % Game.SHOP[i]["name"])
			if ids[i] == "jeonghwa":
				return true
		else:
			Game.say_toast("지금은 쓸 수 없다.", Color(0.7, 0.72, 0.8))
	return false


## 요괴 도감: six to a page; unknown ones stay hidden
func _bag_dogam(dialog: DialogBox) -> void:
	var keys: Array = Bestiary.ENTRIES.keys()
	var page := 0
	var per := 5
	while true:
		var opts := []
		var shown := keys.slice(page * per, page * per + per)
		for k in shown:
			var e: Dictionary = Bestiary.ENTRIES[k]
			opts.append(("%s%s" % ["★ " if e["tier"] != "normal" else "", e["name"]]) if Game.dogam.has(k) else "？？？")
		var has_next := (page + 1) * per < keys.size()
		opts.append("다음 쪽" if has_next else "첫 쪽")
		opts.append("돌아가기")
		var i: int = await dialog.choose({"name": "요괴 도감", "text": "정화한 요괴 %d / %d  (%d쪽)" % [Game.dogam_count(), keys.size(), page + 1]}, opts)
		if i == shown.size():
			page = page + 1 if has_next else 0
		elif i > shown.size():
			return
		elif Game.dogam.has(shown[i]):
			var e: Dictionary = Bestiary.ENTRIES[shown[i]]
			var tier: String = {"normal": "", "elite": " · 정예", "boss": " · 보스"}[e["tier"]]
			await dialog.choose({"name": e["name"], "text": "%s 계열%s · 정화 %d번\n%s" % [e["family"], tier, int(Game.dogam[shown[i]]), e["lore"]]}, ["닫기"])


## 수련: 소리 · 춤 · 가호 — pick a line, then a 수 to read or learn (docs/growth-system.md §4)
func _bag_skills(dialog: DialogBox) -> void:
	var trees: Array = Skills.TREES.keys()
	while true:
		var opts := []
		for k in trees:
			var tr: Dictionary = Skills.TREES[k]
			var n := Skills.of_tree(k).filter(func(x): return x["id"] in Game.skills).size()
			opts.append("%s — %s  %d/%d%s" % [tr["name"], tr["desc"], n, Skills.of_tree(k).size(), "" if Skills.tree_open(k) else " (잠김)"])
		opts.append("돌아가기")
		var i: int = await dialog.choose({"name": "수련", "text": "수련 점수 %d점. 1·2단 1점, 3단 2점, 비전 3점." % Game.skill_points}, opts)
		if i >= trees.size():
			return
		await _bag_tree(dialog, trees[i])


func _bag_tree(dialog: DialogBox, tree: String) -> void:
	var list := Skills.of_tree(tree)
	var page := 0
	var per := 5
	while true:
		var shown := list.slice(page * per, page * per + per)
		var opts := []
		for sk in shown:
			var mark := "● " if sk["id"] in Game.skills else ("○ " if Skills.why_not(sk["id"]) == "" else "· ")
			opts.append("%s%s %s" % [mark, Skills.TIER_NAME[sk["tier"]], sk["name"]])
		var has_next := (page + 1) * per < list.size()
		opts.append("다음 쪽" if has_next else "첫 쪽")
		opts.append("돌아가기")
		var i: int = await dialog.choose({"name": Skills.TREES[tree]["name"], "text": "● 익힘  ○ 익힐 수 있음  · 아직\n수련 점수 %d점" % Game.skill_points}, opts)
		if i == shown.size():
			page = page + 1 if has_next else 0
			continue
		if i > shown.size():
			return
		var sk: Dictionary = shown[i]
		var why := Skills.why_not(sk["id"])
		var head := "%s · %d점\n%s" % [Skills.TIER_NAME[sk["tier"]], Skills.COST[sk["tier"]], sk["desc"]]
		if why == "":
			var c: int = await dialog.choose({"name": sk["name"], "text": head}, ["익힌다", "그만둔다"])
			if c == 0 and Skills.learn(sk["id"]):
				Audio.sfx("levelup", -6.0, 0.0)
				Game.say_toast("%s — 몸에 익었다" % sk["name"], Color(1.0, 0.85, 0.45))
		else:
			await dialog.choose({"name": sk["name"], "text": head + "\n" + why}, ["닫기"])


func _bag_kept(dialog: DialogBox) -> void:
	var lines := []
	lines.append("탈: %s" % (Game.TALS[Game.tal]["name"] + " (" + Game.TALS[Game.tal]["desc"] + ")" if Game.tal != "" else "무탈"))
	if not Game.accessories.is_empty():
		lines.append("장신구: " + ", ".join(Game.accessories))
	var m := []
	for k in Game.mats:
		m.append("%s ×%d" % [k, int(Game.mats[k])])
	lines.append("재료: " + (", ".join(m) if not m.is_empty() else "없음"))
	if not Game.titles.is_empty():
		lines.append("칭호: " + ", ".join(Game.titles))
	await dialog.choose({"name": "지닌 것", "text": "\n".join(lines)}, ["닫기"])


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
	p.sin_changed.connect(_on_sin)
	_on_sin(p.shinmyeong)


func _on_sin(v: float) -> void:
	_sin_fill.size.x = roundf(_sin_w * clampf(v / 100.0, 0, 1))
	_sin_fill.modulate = Color(1.4, 1.3, 1.0) if v >= 100.0 else Color.WHITE


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
