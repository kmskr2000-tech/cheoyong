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
var depth_k := 1.0          # the current level's depth foreshortening (art/ground3d.py K): vertical moves scale by it
var spawn_name := "start"
var _fade: ColorRect
var _busy := false
var _card: VBoxContainer
var replaying := false   # 회상: the intro was opened from the title and returns there
var _settings := {}
var deaths := {}             # CS-07: 구역(level id, 보스전은 "pyega2_boss")별 사망 횟수 — 난이도 측정용
var death_zone := ""         # 비어 있지 않으면 사망을 level_id 대신 이 키로 센다 (역신전)


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for a in OS.get_cmdline_user_args():  # test hooks: --level=gyeongju --spawn=home --flags=met_nanyeong,night
		if a.begins_with("--level="): level_id = a.get_slice("=", 1)
		elif a.begins_with("--spawn="): spawn_name = a.get_slice("=", 1)
		elif a.begins_with("--deok="): deok = int(a.get_slice("=", 1))   # test hook
		elif a.begins_with("--tal="): tal = a.get_slice("=", 1)   # test hook: 쓰고 있는 탈
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
	death_zone = ""
	get_tree().change_scene_to_file("res://scenes/level.tscn")
	await get_tree().process_frame
	await get_tree().process_frame
	await fade(0.0, 0.45)
	_busy = false


## 2장 진입 스위치. 기본은 꺼짐 — 1장 엔딩(작별 → 1절 → 타이틀)은 그대로다.
## 켜는 법: 테스트 인자 --ch2, 또는 플래그 ch2_unlocked(디렉터 승인 후 통합배포가 켠다).
func ch2_enabled() -> bool:
	return "--ch2" in OS.get_cmdline_user_args() or flag("ch2_unlocked") == 1


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


## 장신구 「역신의 눈물」: 독기·역병 장판(역신 독안개, 독기 함정)의 지속 피해만 줄인다. 직격(기침·펄스 등)은 그대로.
const TEAR_NAME := "역신의 눈물"
const TEAR_MIASMA_CUT := 0.4   # 조정은 이 값 하나로 (0.4 → 안개 5→3, 독기 함정 6→4)


func has_tear() -> bool:
	return TEAR_NAME in accessories


func tear_desc() -> String:
	return "독기 지속 피해 약 %d%% 감소" % roundi(TEAR_MIASMA_CUT * 100.0)


func miasma_dmg(base: int) -> int:
	return maxi(1, int(round(base * (1.0 - TEAR_MIASMA_CUT)))) if has_tear() else base


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
## Save format (user://save.json, JSON object). `save_version`: absent = v1 (legacy), 2 = adds the field.
## Rules: never rename/remove an existing key; new fields get defaults in _migrate(). Unknown keys
## (e.g. written by a newer build) are kept in _save_extra and written back, so they are not lost.
## Corrupt files (bad JSON / not an object / missing "flags") are moved to save.json.bad and has_save() is false; a wrongly typed key just falls back to its default. Unreadable (I/O) files are never touched.
const SAVE_VERSION := 2
const SAVE_BAD_PATH := "user://save.json.bad"
const SAVE_TMP_PATH := "user://save.json.tmp"
const SAVE_DEFAULTS := {
	"flags": {}, "money": 50, "items": {"insam": 2, "gugija": 1, "jeonghwa": 0}, "checkpoint": "beach",
	"jeonggi": 0, "deok": 0, "lv": 1, "skill_points": 0, "skills": [], "mats": {}, "dogam": {},
	"tal": "", "tals": [], "accessories": [], "titles": [],
}
## 선택 키: SAVE_VERSION 을 올리지 않고 덧붙인 필드(없으면 로드 시 기본값). SAVE_DEFAULTS 는 v1 키 집합으로 고정(tests/save_check.sh).
const SAVE_OPTIONAL := {"deaths": {}}
const _SAVE_TYPES := {
	"flags": TYPE_DICTIONARY, "money": TYPE_FLOAT, "items": TYPE_DICTIONARY, "checkpoint": TYPE_STRING,
	"jeonggi": TYPE_FLOAT, "deok": TYPE_FLOAT, "lv": TYPE_FLOAT, "skill_points": TYPE_FLOAT,
	"skills": TYPE_ARRAY, "mats": TYPE_DICTIONARY, "dogam": TYPE_DICTIONARY, "tal": TYPE_STRING,
	"tals": TYPE_ARRAY, "accessories": TYPE_ARRAY, "titles": TYPE_ARRAY, "deaths": TYPE_DICTIONARY,
}
var _save_extra := {}     # unknown keys from the loaded file, preserved on save
var _save_version := 0    # version of the last loaded file
var _read_failed := false
var _save_protected := false   # true: existing file unreadable / unbacked-up, save() must not overwrite
var _future_backed_up := false


func save() -> void:
	if _save_protected:   # the existing file could not be read/quarantined: never overwrite it
		push_warning("save: skipped, existing save.json is unreadable and could not be backed up")
		return
	var data: Dictionary = _save_extra.duplicate(true)
	data.merge({"flags": flags, "money": money, "items": items, "checkpoint": checkpoint,
		"jeonggi": jeonggi, "deok": deok, "lv": lv, "skill_points": skill_points, "skills": skills, "mats": mats,
		"dogam": dogam, "tal": tal, "tals": tals, "accessories": accessories, "titles": titles, "deaths": deaths}, true)
	# A file from a newer build keeps its version label (and unknown keys); we only update fields we know.
	# Before the first overwrite of such a file, keep a one-time backup of it.
	data["save_version"] = maxi(SAVE_VERSION, _save_version)
	if _save_version > SAVE_VERSION and not _future_backed_up and FileAccess.file_exists(SAVE_PATH):
		var bak := "user://save.json.v%d.bak" % _save_version
		var orig := FileAccess.get_file_as_string(SAVE_PATH)
		if orig != "" and _write_text(bak, orig):
			_future_backed_up = true
		else:
			push_warning("save: could not back up newer-version save; not overwriting")
			return
	_write_atomic(JSON.stringify(data))


func _write_text(path: String, text: String) -> bool:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(text)
	f.flush()
	f.close()
	return FileAccess.get_file_as_string(path) == text


## Web builds persist user:// (IndexedDB) after file *writes*; a bare rename may not trigger a sync.
func _web_sync() -> void:
	if OS.has_feature("web"):
		_write_text("user://.sync", str(Time.get_ticks_msec()))


## Write to a temp file, verify it re-parses, then rename over the real file (rename overwrites on POSIX
## and Emscripten's FS; on platforms where it fails, remove the target and retry, last resort direct write).
func _write_atomic(text: String) -> bool:
	var f := FileAccess.open(SAVE_TMP_PATH, FileAccess.WRITE)
	if f == null:
		push_warning("save: cannot open temp file (%d)" % FileAccess.get_open_error())
		return false
	f.store_string(text)
	f.flush()
	f.close()
	if typeof(JSON.parse_string(FileAccess.get_file_as_string(SAVE_TMP_PATH))) != TYPE_DICTIONARY:
		push_warning("save: temp file failed verification; keeping the old save")
		DirAccess.remove_absolute(SAVE_TMP_PATH)
		return false
	var dir := DirAccess.open("user://")
	if dir == null:
		return false
	var err := dir.rename("save.json.tmp", "save.json")
	if err != OK:
		dir.remove("save.json")
		err = dir.rename("save.json.tmp", "save.json")
	if err != OK:
		push_warning("save: rename failed (%d); writing directly" % err)
		var g := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
		if g == null:
			return false
		g.store_string(text)
		g.close()
		dir.remove("save.json.tmp")
	_web_sync()
	return true


func _quarantine_save(reason: String) -> void:
	push_warning("save: corrupt save.json (%s) -> moved to save.json.bad" % reason)
	var dir := DirAccess.open("user://")
	if dir == null:
		_save_protected = true
		return
	var orig := FileAccess.get_file_as_string(SAVE_PATH)
	if dir.file_exists("save.json.bad"):   # keep the previous quarantined file instead of overwriting it
		dir.rename("save.json.bad", "save.json.bad.%d" % Time.get_unix_time_from_system())
	# copy by writing (works the same on web), verify, then remove the original
	if _write_text("user://save.json.bad", orig):
		dir.remove("save.json")
		_save_protected = dir.file_exists("save.json")
	else:
		_save_protected = true   # backup failed: keep the original and refuse to overwrite it
	_web_sync()


## Parse + validate + migrate. Returns the normalized dict, or {} if there is no usable save.
## Sets _read_failed when a file exists but could not be read (I/O problem: nothing is quarantined).
func _read_save() -> Dictionary:
	_read_failed = false
	if not FileAccess.file_exists(SAVE_PATH):
		# interrupted save: the verified temp file is the newest data -> promote it
		if FileAccess.file_exists(SAVE_TMP_PATH):
			var t := FileAccess.get_file_as_string(SAVE_TMP_PATH)
			if typeof(JSON.parse_string(t)) == TYPE_DICTIONARY and _write_text(SAVE_PATH, t):
				DirAccess.remove_absolute(SAVE_TMP_PATH)
				_web_sync()
		if not FileAccess.file_exists(SAVE_PATH):
			return {}
	var rf := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if rf == null:   # locked / unreadable is an I/O problem, not corruption: do not quarantine
		push_warning("save: cannot read save.json (%d)" % FileAccess.get_open_error())
		_read_failed = true
		_save_protected = true
		return {}
	_save_protected = false
	var parsed = JSON.parse_string(rf.get_as_text())
	rf.close()
	if typeof(parsed) != TYPE_DICTIONARY:
		_quarantine_save("not a JSON object")
		return {}
	var data: Dictionary = parsed
	if not data.has("flags"):
		_quarantine_save("missing required key 'flags'")
		return {}
	var repaired := false
	for k in _SAVE_TYPES:   # a wrongly typed key is reset to its default; the rest of the save survives
		if data.has(k):
			var t := typeof(data[k])
			var want: int = _SAVE_TYPES[k]
			if t != want and not (want == TYPE_FLOAT and t == TYPE_INT):
				push_warning("save: key '%s' has wrong type; using default" % k)
				var dflt = SAVE_DEFAULTS[k] if SAVE_DEFAULTS.has(k) else SAVE_OPTIONAL[k]
				data[k] = dflt.duplicate(true) if dflt is Array or dflt is Dictionary else dflt
				repaired = true
	var ver = data.get("save_version", 1)   # no version field = legacy v1
	if typeof(ver) != TYPE_FLOAT and typeof(ver) != TYPE_INT:
		push_warning("save: bad save_version; treating as v1")
		ver = 1
	if repaired and not FileAccess.file_exists("user://save.json.bad"):
		_write_text("user://save.json.bad", FileAccess.get_file_as_string(SAVE_PATH))   # keep original of repaired save
	return _migrate(data, int(ver))


## Bring `data` up to SAVE_VERSION. Add one `if from_version < N:` block per format bump; only fill
## defaults / convert, never drop keys.
func _migrate(data: Dictionary, from_version: int) -> Dictionary:
	if from_version > SAVE_VERSION:
		push_warning("save: written by a newer build (v%d > v%d); loading best-effort" % [from_version, SAVE_VERSION])
	if from_version < 2:   # v1 -> v2: fill keys older builds did not write
		for k in SAVE_DEFAULTS:
			if not data.has(k):
				data[k] = SAVE_DEFAULTS[k].duplicate(true) if SAVE_DEFAULTS[k] is Array or SAVE_DEFAULTS[k] is Dictionary else SAVE_DEFAULTS[k]
	data["save_version"] = maxi(from_version, SAVE_VERSION)
	return data


func _intify(d: Dictionary) -> Dictionary:
	var out := {}
	for k in d:
		var v = d[k]
		out[k] = int(v) if typeof(v) == TYPE_FLOAT and v == floorf(v) else v
	return out


func has_save() -> bool:
	var d := _read_save()
	return not d.is_empty() or _read_failed   # unreadable-but-present counts as "a save exists"


## a flag as stored on disk, without loading the save (title screen uses it for the "1장 완료" mark)
func peek_flag(k: String) -> bool:
	var f = _read_save().get("flags", {})
	return typeof(f) == TYPE_DICTIONARY and int(f.get(k, 0)) != 0


func load_save() -> bool:
	var data := _read_save()
	if data.is_empty():
		return false
	_save_version = int(data["save_version"])
	_save_extra = {}
	for k in data:
		if not SAVE_DEFAULTS.has(k) and not SAVE_OPTIONAL.has(k) and k != "save_version":
			_save_extra[k] = data[k]
	var def := SAVE_DEFAULTS
	flags = _intify(data.get("flags", {}))
	money = int(data.get("money", 50))
	items = _intify(data.get("items", def["items"]))
	checkpoint = data.get("checkpoint", "beach")
	jeonggi = int(data.get("jeonggi", 0))
	deok = int(data.get("deok", 0))
	lv = int(data.get("lv", 1))
	skill_points = int(data.get("skill_points", 0))
	skills = data.get("skills", [])
	mats = _intify(data.get("mats", {}))
	dogam = _intify(data.get("dogam", {}))
	tal = data.get("tal", "")
	tals = data.get("tals", [])
	accessories = data.get("accessories", [])
	titles = data.get("titles", [])
	deaths = _intify(data.get("deaths", {}))
	return true


func new_game() -> void:
	flags = {}
	money = 50
	items = {"insam": 2, "gugija": 1, "jeonghwa": 0}
	checkpoint = "beach"
	level_id = "beach"
	spawn_name = "start"
	jeonggi = 0; deok = 0; lv = 1; skill_points = 0; skills = []
	mats = {}; dogam = {}; tal = ""; tals = []; accessories = []; titles = []; deaths = {}; death_zone = ""
	_save_extra = {}; _save_version = 0; _future_backed_up = false


## CS-07: 사망 1회 기록 (Player._die)
func record_death() -> void:
	var k := death_zone if death_zone != "" else level_id
	deaths[k] = int(deaths.get(k, 0)) + 1
	if "--stats" in OS.get_cmdline_user_args():
		print("DEATHS ", death_report())


func death_report() -> String:
	var parts := []
	for k in deaths:
		parts.append("%s=%d" % [k, deaths[k]])
	return ", ".join(parts)


## where a fresh start / continue / death puts you
func checkpoint_spawn() -> Array:
	if flag("ch2_start") and checkpoint in ["hwagae", "jiri_path"]:   # 2장(챕터2 M1): 1장 분기보다 먼저 본다
		return [checkpoint, "start"]
	if checkpoint == "gyeongju" or flag("arrived"):
		return ["gyeongju", "home" if flag("night") else "start"]
	return ["beach", "start"]
