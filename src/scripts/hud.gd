class_name Hud
extends CanvasLayer
## Combat HUD and touch controls (landscape phone). Same lacquer / brass / pearl language as the
## dialogue box. Touch controls appear on touchscreens (or with --touch): a floating joystick on the
## left half (it appears where the thumb lands) and lacquer buttons on the right.

const STICK_R := 20.0
const CT := preload("res://scripts/combat_tuning.gd")

var player: Node
var _hp_fill: TextureRect
var _ki_fill: TextureRect
var _hp_w := 96.0
var _ki_w := 72.0
var _sin_w := 56.0
var _sin_fill: TextureRect
var _tal_label: Label
var _tal_icon: TextureRect   # 고른 부적 아이콘 (Drive 도트)
var _mask_icon: TextureRect  # 쓰고 있는 탈
var _flute_icon: TextureRect # 피리를 가졌다
var _tal_shown := ""
var _charge_ring: Line2D     # CS-08: 베기 버튼 둘레 충전 링 (0.35 지점 표식, 만충 번쩍임)
var _charge_mark: Line2D
var _sin_last := 0.0
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
	# carried things, under the level number: the talisman he will draw, the mask he wears, the flute
	_tal_icon = _item_icon(root, Vector2(8, 54), "res://assets/ui/icons/tal_fire.png")
	_mask_icon = _item_icon(root, Vector2(30, 56), "res://assets/ui/icons/item_mask.png")
	_flute_icon = _item_icon(root, Vector2(52, 56), "res://assets/ui/icons/key_flute.png")
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
	# touch radii are chosen so no two circles overlap (centre distance >= r1 + r2): the old 30/22 pairs
	# overlapped by up to 7.6px, so a thumb on one button could fire its neighbour too
	for b in [["attack", "attack", Vector2(430, 222), 24.0], ["roll", "roll", Vector2(384, 244), 22.0],
			["talisman", "talisman", Vector2(394, 196), 20.0], ["song", "song", Vector2(438, 172), 22.0],
			["dance", "dance", Vector2(396, 150), 22.0], ["swap", "swap", Vector2(360, 186), 14.0],
			["menu", "pause", Vector2(462, 16), 18.0]]:
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
	_charge_ring = Line2D.new()
	_charge_ring.width = 2.0
	_charge_ring.visible = false
	_charge_ring.position = Vector2(430, 222)
	_touch_root.add_child(_charge_ring)
	_charge_mark = Line2D.new()   # CHARGE_MIN 표식: 이 선을 넘기면 놓았을 때 발동한다
	_charge_mark.width = 2.0
	_charge_mark.default_color = Color(1.0, 1.0, 1.0, 0.9)
	var ma := -PI / 2 + TAU * (CT.CHARGE_MIN / CT.CHARGE_FULL)
	_charge_mark.points = PackedVector2Array([Vector2.from_angle(ma) * 25.0, Vector2.from_angle(ma) * 32.0])
	_charge_mark.visible = false
	_charge_mark.position = Vector2(430, 222)
	_touch_root.add_child(_charge_mark)
	_tal_label = Label.new()   # which talisman the button will draw
	_tal_label.add_theme_font_override("font", DialogBox._pixel_font("res://assets/fonts/Galmuri11.ttf"))
	_tal_label.add_theme_font_size_override("font_size", 12)
	_tal_label.add_theme_color_override("font_color", Color(0.94, 0.88, 0.7))
	_tal_label.add_theme_color_override("font_outline_color", Color(0.02, 0.02, 0.05))
	_tal_label.add_theme_constant_override("outline_size", 4)
	# right-aligned in the gap left of the 교체 button: the old spot (below it) sat on the 부적/구르기 buttons
	_tal_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_tal_label.position = Vector2(290, 179)
	_tal_label.size = Vector2(56, 14)
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
	_make_objective_label(root)
	Game.toast.connect(show_toast)
	process_mode = Node.PROCESS_MODE_ALWAYS
	_touch_root.visible = DisplayServer.is_touchscreen_available() or "--touch" in OS.get_cmdline_user_args()
	if _touch_root.visible:
		_show_stick(Vector2(70, 214))  # resting position hint
	_release_dirs()   # a Hud rebuilt mid-drag (level change) must not inherit a held direction


func _item_icon(parent: Node, at: Vector2, path: String) -> TextureRect:
	var r := TextureRect.new()
	r.texture = load(path)
	r.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	r.position = at
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.visible = false
	parent.add_child(r)
	return r


func _exit_tree() -> void:
	_release_dirs()


func _release_dirs() -> void:
	if not _touch_root.visible:   # keyboard/gamepad players: don't drop a held key across a level change
		return
	for a in ["move_left", "move_right", "move_up", "move_down"]:
		Input.action_release(a)


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


func _update_icons() -> void:
	var has_flute := Game.flag("flute") == 1
	if player and player.has_method("current_talisman"):
		var tk: String = player.current_talisman()
		if tk != _tal_shown:
			_tal_shown = tk
			_tal_icon.texture = load("res://assets/ui/icons/tal_%s.png" % tk)
	_tal_icon.visible = has_flute and player != null
	_mask_icon.visible = Game.tal != ""
	_flute_icon.visible = has_flute


func _process(_d: float) -> void:
	_update_icons()
	_update_charge_ring()
	_objective_process(_d)
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
			["약 꺼내기", "수련 (%d점)" % Game.skill_points, "요괴 도감 (%d/%d)" % [Game.dogam_count(), Bestiary.ENTRIES.size()], "지닌 것", "회상", "안내 설정", "닫기"])
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
		elif i == 5:
			await _bag_guide_settings(dialog)
		else:
			break
	get_tree().paused = false


const OBJ_MODE_NAMES := {"always": "항상", "brief": "잠깐", "off": "끔"}


## 안내 설정 (design/gdd/objective-marker.md §3.6): 목표 문구 항상/잠깐/끔 · 길잡이 빛 켜짐/끔. user://settings.json 에 저장(세이브와 분리)
func _bag_guide_settings(dialog: DialogBox) -> void:
	while true:
		var light_on = Game.setting("obj_light")
		light_on = true if light_on == null else bool(light_on)
		var i: int = await dialog.choose({"name": "안내 설정", "text": "목표 문구는 화면 위, 길잡이 빛은 용패에서 흐른다."},
			["목표 문구: %s" % OBJ_MODE_NAMES[objective_mode()], "길잡이 빛: %s" % ("켜짐" if light_on else "끔"), "돌아가기"])
		if i == 0:
			var order := ["always", "brief", "off"]
			Game.set_setting("obj_text", order[(order.find(objective_mode()) + 1) % order.size()])
		elif i == 1:
			Game.set_setting("obj_light", not light_on)
		else:
			break


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
		var acc := []
		for a in Game.accessories:
			acc.append(a + (" (%s)" % Game.tear_desc() if a == Game.TEAR_NAME else ""))
		lines.append("장신구: " + ", ".join(acc))
	var m := []
	for k in Game.mats:
		m.append("%s ×%d" % [k, int(Game.mats[k])])
	lines.append("재료: " + (", ".join(m) if not m.is_empty() else "없음"))
	if not Game.titles.is_empty():
		lines.append("칭호: " + ", ".join(Game.titles))
	# icons of what he carries, laid over the pause screen above the dialog
	var cl := CanvasLayer.new()
	cl.layer = 30
	cl.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(cl)
	var shown: Array = []
	if Game.tal != "":
		shown.append("item_mask")
	if Game.flag("flute") == 1:
		shown.append("key_flute")
		for k in player.talismans():
			shown.append("tal_" + k)
	for i in shown.size():
		_item_icon(cl, Vector2(150 + i * 26, 26), "res://assets/ui/icons/%s.png" % shown[i]).visible = true
	await dialog.choose({"name": "지닌 것", "text": "\n".join(lines)}, ["닫기"])
	cl.queue_free()


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


## CS-08: 충전 중에만 보이는 링. 눈이 전투에 있어도 캐릭터 발치 링(player.gd)이 같은 값을 보여 준다.
func _update_charge_ring() -> void:
	if _charge_ring == null:
		return
	var k: float = player.charge_ratio() if player and player.has_method("charge_ratio") else 0.0
	var on := k > 0.0 and _touch_root.visible
	_charge_ring.visible = on
	_charge_mark.visible = on
	if not on:
		return
	var n := maxi(2, int(k * 40.0))
	var pts := PackedVector2Array()
	for i in n + 1:
		pts.append(Vector2.from_angle(-PI / 2 + TAU * k * float(i) / float(n)) * 28.0)
	_charge_ring.points = pts
	var full := k >= 1.0
	var ready: bool = player.get("_charge_c") != null and player._charge_c >= CT.CHARGE_MIN
	_charge_ring.default_color = Color(1.0, 1.0, 0.8, 0.7 + 0.3 * sin(Time.get_ticks_msec() / 40.0)) if full else (Color(1.0, 0.9, 0.5, 0.95) if ready else Color(0.7, 0.8, 1.0, 0.6))


func _on_sin(v: float) -> void:
	if v < _sin_last - 0.5:   # 신명이 깎이면 짧게 붉게 점멸
		var tw := create_tween()
		tw.tween_property(_sin_fill, "self_modulate", Color(2.0, 0.3, 0.3), 0.06)
		tw.tween_property(_sin_fill, "self_modulate", Color.WHITE, 0.2)
	_sin_last = v
	_sin_fill.size.x = roundf(_sin_w * clampf(v / 100.0, 0, 1))
	_sin_fill.modulate = Color(1.4, 1.3, 1.0) if v >= 100.0 else Color.WHITE


func _on_stats(hp: float, max_hp: float, ki: float, max_ki: float) -> void:
	_hp_fill.size.x = roundf(_hp_w * clampf(hp / max_hp, 0, 1))
	_ki_fill.size.x = roundf(_ki_w * clampf(ki / max_ki, 0, 1))


# ---------------------------------------------------------------- 목표 문구 (design/gdd/objective-marker.md §3.6~3.7)
## 상단 중앙 한 줄. 새 TouchScreenButton 이 아니라 Label 하나다(tests/hud_layout.gd h0 = 버튼 7개 유지).
## 시점/카메라 설계가 뷰포트를 바꾸면 아래 상수(레이아웃)만 고친다 — 코드 안에 480/270 을 새로 박지 않는다.
const OBJ_RECT := Rect2(136, 3, 308, 14)        # 좌상단 상태(~x126)·메뉴(x450~)·보스 체력바(y14~)·토스트(y54~)를 피하는 유일한 가로 띠
const OBJ_PREFIX := "◇ "
const OBJ_ALPHA := 0.9                          # 상시 알파
const OBJ_FLASH := 1.5                          # 새 목표 때 알파 1.0 + 밝은 번쩍임 유지
const OBJ_FADE := 0.25                          # 아웃/인
const OBJ_FALLBACK_IDLE := 20.0                 # SC1-01 무음 폴백: 조작 가능 무입력 N초 → 폴백 문구
const OBJ_FALLBACK_SHOW := 5.0
const OBJ_BRIEF_SHOW := 5.0                     # "잠깐" 모드: 새 목표 때 노출
const OBJ_BRIEF_IDLE := 25.0                    # "잠깐" 모드: 무입력 N초 → 재노출
const OBJ_BRIEF_RESHOW := 4.0
const OBJ_COLOR := Color(0.93, 0.90, 0.78)      # 진주빛
const OBJ_COLOR_FLASH := Color(1.0, 1.0, 0.92)
var _obj_label: Label
var _obj_pending := {}         # level 이 계산한 최신 목표 (objective_info)
var _obj_id := ""              # 지금 라벨이 말하는 목표
var _obj_show := "normal"
var _obj_alpha := 0.0
var _obj_swap := false         # 이전 문구를 내리는 중 (다 내려가면 새 문구로 교체)
var _obj_flash_t := 0.0
var _obj_brief_t := 0.0
var _obj_fb_t := 0.0
var _obj_idle := 0.0           # 마지막 입력 후 경과 (조작 가능 상태에서만 쌓인다)
var _obj_idle_brief := 0.0
var _obj_force_gate = null     # 테스트 훅: true/false 로 표시 확정 조건을 덮어쓴다


func _make_objective_label(parent: Node) -> void:
	_obj_label = Label.new()
	_obj_label.add_theme_font_override("font", DialogBox._pixel_font("res://assets/fonts/Galmuri11.ttf"))
	_obj_label.add_theme_font_size_override("font_size", 14)
	_obj_label.add_theme_color_override("font_color", OBJ_COLOR)
	_obj_label.add_theme_color_override("font_outline_color", Color(0.02, 0.02, 0.06))
	_obj_label.add_theme_constant_override("outline_size", 4)
	_obj_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_obj_label.clip_text = true
	_obj_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_obj_label.position = OBJ_RECT.position
	_obj_label.size = OBJ_RECT.size
	_obj_label.modulate.a = 0.0
	parent.add_child(_obj_label)


## level.gd 가 0.25초마다·진행도 변화 때 부른다
func set_objective(info: Dictionary) -> void:
	_obj_pending = info


## 노출 모드 설정 ("always" 기본 / "brief" / "off")
static func objective_mode() -> String:
	var m = Game.setting("obj_text")
	return m if m in ["always", "brief", "off"] else "always"


## 표시 확정 조건 (§3.7) + 숨김 규칙 (R-숨김): 조작 가능하고 연출·대화·카드·페이드·일시정지·튜토리얼 점등·보스 체력바가 없을 때만 true
func objective_gate() -> bool:
	if _obj_force_gate != null:
		return _obj_force_gate
	if player == null or player.locked or get_tree().paused:
		return false
	var lv := get_parent()
	if lv != null and lv.get("_talking") != null and int(lv.get("_talking")) > 0:
		return false
	if Game._busy or Game._fade.color.a > 0.05 or Game._card.modulate.a > 0.05:
		return false
	if _guide != "":                         # 튜토리얼 점등 중: "빛나는 버튼 하나" 원칙 — 글 금지
		return false
	if _boss_root != null and is_instance_valid(_boss_root) and not _boss_root.is_queued_for_deletion():
		return false
	return true


func objective_alpha() -> float:
	return _obj_alpha


func objective_text() -> String:
	return _obj_label.text if _obj_label else ""


func _objective_input(event: InputEvent) -> void:
	if (event is InputEventKey and event.pressed) or event is InputEventScreenTouch or event is InputEventScreenDrag \
			or (event is InputEventMouseButton and event.pressed) or event is InputEventJoypadButton \
			or (event is InputEventJoypadMotion and absf(event.axis_value) > 0.4):
		_obj_idle = 0.0
		_obj_idle_brief = 0.0


func _objective_process(d: float) -> void:
	if _obj_label == null:
		return
	var gate := objective_gate()
	var mode := objective_mode()
	if gate:
		_obj_idle += d
		_obj_idle_brief += d
		_obj_flash_t = maxf(0.0, _obj_flash_t - d)
	# 1) 바뀐 목표는 조작이 돌아온 순간 적용 — 이전 문구를 먼저 내린다
	if gate and not _obj_pending.is_empty() and (_obj_pending["id"] != _obj_id or _obj_swap):
		if _obj_alpha > 0.02 and _obj_label.text != "":
			_obj_swap = true
		else:
			_apply_objective(_obj_pending)
	# 2) 보이려는 알파
	var want := 0.0
	var txt := _obj_label.text
	if gate and not _obj_swap and txt != "" and mode != "off":
		if _obj_show == "fallback":           # 바이블 SC1-01 무음: 20초 무입력일 때만
			if _obj_fb_t <= 0.0 and _obj_idle >= OBJ_FALLBACK_IDLE:
				_obj_fb_t = OBJ_FALLBACK_SHOW
				_obj_idle = 0.0
			if _obj_fb_t > 0.0:
				_obj_fb_t -= d
				want = OBJ_ALPHA
		elif mode == "always":
			want = 1.0 if _obj_flash_t > 0.0 else OBJ_ALPHA
		else:                                  # brief
			if _obj_brief_t <= 0.0 and _obj_idle_brief >= OBJ_BRIEF_IDLE:
				_obj_brief_t = OBJ_BRIEF_RESHOW
				_obj_idle_brief = 0.0
			if _obj_brief_t > 0.0:
				_obj_brief_t -= d
				want = 1.0 if _obj_flash_t > 0.0 else OBJ_ALPHA
	elif _obj_swap:
		want = 0.0
	var rate := (1.0 / OBJ_FADE) if gate else (1.0 / (OBJ_FADE * 0.5))
	_obj_alpha = move_toward(_obj_alpha, want, rate * d)
	_obj_label.modulate.a = _obj_alpha
	var fl := clampf(_obj_flash_t / OBJ_FLASH, 0.0, 1.0)
	_obj_label.add_theme_color_override("font_color", OBJ_COLOR.lerp(OBJ_COLOR_FLASH, fl))


func _apply_objective(info: Dictionary) -> void:
	var first := _obj_id == ""
	_obj_swap = false
	_obj_id = info["id"]
	_obj_show = info.get("show", "normal")
	var t: String = info["text"]
	_obj_label.text = (OBJ_PREFIX + t) if t != "" else ""
	_obj_flash_t = OBJ_FLASH
	_obj_brief_t = OBJ_BRIEF_SHOW
	_obj_fb_t = 0.0
	_obj_idle = 0.0
	if t != "" and not first and _obj_show == "normal":
		Audio.sfx("pickup", -18.0, 0.0)   # 아주 작게 — 새 목표 알림


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
	_objective_input(event)
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
