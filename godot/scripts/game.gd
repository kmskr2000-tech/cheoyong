extends Node
## Global game state (autoload "Game"): story flags, purse and medicine, checkpoint, save/load,
## and level transitions behind a fade. Saves go to user://save.json.

signal toast(text: String, color: Color)
signal skills_changed
signal leveled(lv: int)
signal progress_changed

const SAVE_PATH := "user://save.json"
const SETTINGS_PATH := "user://settings.json"
const SHOP := [
	{"id": "insam", "name": "인삼정기탕", "desc": "기력(체력) 60 회복", "price": 30},
	{"id": "gugija", "name": "구기자환", "desc": "소리(기력) 50 회복", "price": 25},
	{"id": "jeonghwa", "name": "정화부", "desc": "주변 요괴에게 큰 정화 피해", "price": 40},
]

var flags := {}
var money := 50              # 엽전: 상점 구매 전용
# ---- 성장 (docs/growth-system.md)
var jeonggi := 0             # 정기: 강화·부적·퇴치향 제작
var deok := 0                # 덕망: 다음 레벨까지 모은 양
var lv := 1
var skill_points := 0
var skills: Array = []       # 익힌 수 (Skills.LIST id)
var tal_idx := 0             # 고른 부적
var mats := {}               # 재료 이름 → 개수
var dogam := {}              # 요괴 키 → 정화한 횟수
var tal := ""                # 쓰고 있는 탈 ("" 무탈, "cheoyong" 처용탈 …)
var tals: Array = []         # 가진 탈
var accessories: Array = []  # 장신구 (보스·정예 드롭)
var titles: Array = []
const MAX_LV := 30
const TALS := {"cheoyong": {"name": "처용탈", "desc": "받는 피해 10% 감소"}}
var items := {"insam": 2, "gugija": 1, "jeonghwa": 0}
var checkpoint := "beach"
var level_id := "beach"
var spawn_name := "start"
var _fade: ColorRect
var _busy := false
var _card: VBoxContainer
var replaying := false   # 회상: the intro was opened from the title and returns there
var _settings := {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for a in OS.get_cmdline_user_args():  # test hooks: --level=gyeongju --spawn=home --flags=met_nanyeong,night
		if a.begins_with("--level="): level_id = a.get_slice("=", 1)
		elif a.begins_with("--spawn="): spawn_name = a.get_slice("=", 1)
		elif a.begins_with("--deok="): deok = int(a.get_slice("=", 1))   # test hook
		elif a.begins_with("--sp="): skill_points = int(a.get_slice("=", 1))   # test hook: 수련 점수
		elif a.begins_with("--skills="): skills = Array(a.get_slice("=", 1).split(","))   # test hook: 익힌 수
		elif a.begins_with("--flags="):
			for f in a.get_slice("=", 1).split(","):
				flags[f] = 1
	var layer := CanvasLayer.new()
	layer.layer = 30
	_fade = ColorRect.new()
	_fade.color = Color(0.0, 0.0, 0.02, 0.0)
	_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_fade)
	_card = VBoxContainer.new()
	_card.set_anchors_preset(Control.PRESET_FULL_RECT)
	_card.alignment = BoxContainer.ALIGNMENT_CENTER
	_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card.modulate.a = 0.0
	for i in 2:
		var l := Label.new()
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.add_theme_font_override("font", DialogBox._pixel_font("res://assets/fonts/Galmuri11-Bold.ttf" if i == 0 else "res://assets/fonts/Galmuri11.ttf"))
		l.add_theme_font_size_override("font_size", 24 if i == 0 else 12)
		l.add_theme_color_override("font_color", Color(0.93, 0.88, 0.76) if i == 0 else Color(0.62, 0.7, 0.86))
		_card.add_child(l)
	layer.add_child(_card)
	add_child(layer)


func flag(k: String) -> int:
	return int(flags.get(k, 0))


func set_flag(k: String, v := 1) -> void:
	flags[k] = v


func say_toast(text: String, color := Color(0.94, 0.85, 0.55)) -> void:
	toast.emit(text, color)


# ---------------------------------------------------------------- fades and level changes
func fade(to: float, time := 0.4) -> void:
	var tw := create_tween()
	tw.tween_property(_fade, "color:a", to, time)
	await tw.finished


## a place / chapter card over black (call with the screen already faded out); awaitable
func card(title: String, sub := "", hold := 1.6) -> void:
	_card.get_child(0).text = title
	_card.get_child(1).text = sub
	var tw := create_tween()
	tw.tween_property(_card, "modulate:a", 1.0, 0.6)
	tw.tween_interval(hold)
	tw.tween_property(_card, "modulate:a", 0.0, 0.6)
	await tw.finished


func change_level(id: String, spawn: String, title := "", sub := "") -> void:
	if _busy:
		return
	_busy = true
	Audio.sfx("door", -8.0)
	await fade(1.0, 0.35 if title == "" else 1.2)
	if title != "":
		await card(title, sub)
	level_id = id
	spawn_name = spawn
	get_tree().change_scene_to_file("res://scenes/level.tscn")
	await get_tree().process_frame
	await get_tree().process_frame
	await fade(0.0, 0.45)
	_busy = false


## back to the title screen (after the chapter ends, or from the menu)
func to_title() -> void:
	await fade(1.0, 0.8)
	get_tree().change_scene_to_file("res://scenes/title.tscn")
	await get_tree().process_frame
	await get_tree().process_frame
	await fade(0.0, 0.8)


# ---------------------------------------------------------------- 성장: 정화 보상, 레벨, 도감
## 덕망 needed to go from level n to n+1
func need(n: int) -> int:
	return n * 120


## 위쳐식 자동 성장: stats follow the level, no manual allocation
func max_hp() -> float:
	return 100.0 + (lv - 1) * 6.0 + (40.0 if has_skill("simhae") else 0.0)


func attack_mult() -> float:
	return 1.0 + (lv - 1) * 0.05


func damage_taken_mult() -> float:
	var m := 0.9 if tal == "cheoyong" else 1.0
	if has_skill("bigeul"):
		m *= 0.88
	return m


func has_skill(id: String) -> bool:
	return id in skills


func add_deok(n: int) -> void:
	deok += n
	while lv < MAX_LV and deok >= need(lv):
		deok -= need(lv)
		lv += 1
		skill_points += 1
		say_toast("덕망이 쌓였다 — Lv.%d · 수련 +1점" % lv, Color(1.0, 0.85, 0.45))
		leveled.emit(lv)
	progress_changed.emit()


## a 요괴 has been sung clean: its 탁기 condenses into 정기, people's regard grows, sometimes material remains
func reward_purify(kind: String, where: Vector2, parent: Node, mult := 1.0) -> Dictionary:
	var e := Bestiary.entry(kind)
	var t: Dictionary = Bestiary.TIERS[e["tier"]]
	var r := {
		"jeonggi": int(randi_range(t["jeonggi"][0], t["jeonggi"][1]) * mult),
		"deok": int(randi_range(t["deok"][0], t["deok"][1]) * mult),
		"money": int(randi_range(t["money"][0], t["money"][1]) * mult),
		"mat": "",
	}
	if has_skill("yeouiju"):  # 여의주 공명
		r["jeonggi"] = int(r["jeonggi"] * 1.2)
	if randf() < t["mat"] * (1.2 if has_skill("yeouiju") else 1.0):
		r["mat"] = Bestiary.MATERIALS.get(e["family"], "")
		mats[r["mat"]] = int(mats.get(r["mat"], 0)) + (2 if e["tier"] != "normal" else 1)
	jeonggi += r["jeonggi"]
	money += r["money"]
	var first := not dogam.has(kind)
	dogam[kind] = int(dogam.get(kind, 0)) + 1
	var lines := ["+%d 정기" % r["jeonggi"]]
	if r["mat"] != "":
		lines.append(r["mat"])
	float_text(parent, where, lines)
	if first:
		say_toast("요괴 도감에 올랐다 — %s" % e["name"], Color(0.75, 0.85, 1.0))
		_dogam_milestones()
	add_deok(r["deok"])
	return r


## bonus grant (한풀이) without registering anything
func reward_bonus(jg: int, dk: int, where: Vector2, parent: Node) -> void:
	jeonggi += jg
	float_text(parent, where, ["한풀이 +%d 정기" % jg])
	add_deok(dk)


func dogam_count() -> int:
	var n := 0
	for k in Bestiary.ENTRIES:
		if dogam.has(k):
			n += 1
	return n


func _dogam_milestones() -> void:
	var total := Bestiary.ENTRIES.size()
	var n := dogam_count()
	if n * 2 >= total and not flag("dogam_half"):
		set_flag("dogam_half")
		jeonggi += 500
		say_toast("도감 절반 — 정기 500", Color(0.75, 0.85, 1.0))
	if n >= total and not flag("dogam_full"):
		set_flag("dogam_full")
		titles.append("요괴의 벗")
		say_toast("도감 완성 — 칭호 「요괴의 벗」", Color(1.0, 0.85, 0.45))


func give_tal(id: String) -> void:
	Audio.sfx("pickup", -4.0, 0.0)
	if not id in tals:
		tals.append(id)
	tal = id
	say_toast("%s을 얻었다 — %s" % [TALS[id]["name"], TALS[id]["desc"]], Color(1.0, 0.7, 0.55))
	progress_changed.emit()


## little rising numbers where a 요괴 was purified
func float_text(parent: Node, where: Vector2, lines: Array) -> void:
	for i in lines.size():
		var l := Label.new()
		l.text = lines[i]
		l.add_theme_font_override("font", DialogBox._pixel_font("res://assets/fonts/Galmuri11.ttf"))
		l.add_theme_font_size_override("font_size", 12)
		l.add_theme_color_override("font_color", Color(0.75, 0.9, 1.0) if i == 0 else Color(0.95, 0.85, 0.6))
		l.add_theme_color_override("font_outline_color", Color(0.02, 0.02, 0.05))
		l.add_theme_constant_override("outline_size", 4)
		l.position = where + Vector2(-30, -48 - i * 13)
		l.size = Vector2(60, 14)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.z_index = 48
		l.z_as_relative = false
		parent.add_child(l)
		var tw := l.create_tween().set_parallel()
		tw.tween_property(l, "position:y", l.position.y - 18, 1.4).set_delay(i * 0.12)
		tw.tween_property(l, "modulate:a", 0.0, 0.6).set_delay(0.9 + i * 0.12)
		tw.chain().tween_callback(l.queue_free)


# ---------------------------------------------------------------- settings (persist across saves)
func setting(k: String):
	if _settings.is_empty() and FileAccess.file_exists(SETTINGS_PATH):
		var d = JSON.parse_string(FileAccess.get_file_as_string(SETTINGS_PATH))
		_settings = d if typeof(d) == TYPE_DICTIONARY else {}
	return _settings.get(k, null)


func set_setting(k: String, v) -> void:
	setting(k)
	_settings[k] = v
	var f := FileAccess.open(SETTINGS_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(_settings))


# ---------------------------------------------------------------- save / load
func save() -> void:
	var data := {"flags": flags, "money": money, "items": items, "checkpoint": checkpoint,
		"jeonggi": jeonggi, "deok": deok, "lv": lv, "skill_points": skill_points, "skills": skills, "mats": mats,
		"dogam": dogam, "tal": tal, "tals": tals, "accessories": accessories, "titles": titles}
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(data))


func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)


func load_save() -> bool:
	if not has_save():
		return false
	var data = JSON.parse_string(FileAccess.get_file_as_string(SAVE_PATH))
	if typeof(data) != TYPE_DICTIONARY:
		return false
	flags = data.get("flags", {})
	money = int(data.get("money", 50))
	items = data.get("items", items)
	checkpoint = data.get("checkpoint", "beach")
	jeonggi = int(data.get("jeonggi", 0))
	deok = int(data.get("deok", 0))
	lv = int(data.get("lv", 1))
	skill_points = int(data.get("skill_points", 0))
	skills = data.get("skills", [])
	mats = data.get("mats", {})
	dogam = data.get("dogam", {})
	tal = data.get("tal", "")
	tals = data.get("tals", [])
	accessories = data.get("accessories", [])
	titles = data.get("titles", [])
	return true


func new_game() -> void:
	flags = {}
	money = 50
	items = {"insam": 2, "gugija": 1, "jeonghwa": 0}
	checkpoint = "beach"
	level_id = "beach"
	spawn_name = "start"
	jeonggi = 0; deok = 0; lv = 1; skill_points = 0; skills = []
	mats = {}; dogam = {}; tal = ""; tals = []; accessories = []; titles = []


## where a fresh start / continue / death puts you
func checkpoint_spawn() -> Array:
	if checkpoint == "gyeongju" or flag("arrived"):
		return ["gyeongju", "home" if flag("night") else "start"]
	return ["beach", "start"]
