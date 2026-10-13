extends SceneTree
## T1(상태표 단위 테스트) + T6(대상 좌표 ↔ levels.gd 일치) + T9(2장 회귀) — design/gdd/objective-marker.md §8.
## tests/fixtures/objective_states.json(= 표 §3)을 읽어 각 상태의 Story.objective_info 를 검사한다. tests/objective_targets.sh 가 실행한다.
##  T1: id/text/kind 일치 · 예외(E-n) 아닌데 문구 빔 금지 · 18자 이하 · 금칙어 · "오신다" · 입력 안내어(버튼/누른다/터치) · 플래그 전부 비운 디버그 진입
##  T6: target 이 해당 레벨의 NPC·interact·exit·gate·trigger·anchor 중 하나와 24px 이내 (옛 집 좌표 (96,130) 형 결함 검출)
##  T9: 2장 레벨 Story.objective() 가 리팩터 전 구현(아래 _ch2_oracle, 원문 그대로)과 같은 좌표
var fails := 0
const TOL := 24.0
const MAX_CHARS := 18
const BANNED := ["난영", "아내", "역신", "넋", "왕", "입궐", "어명", "퇴마어사", "어사", "오신다", "도깨비", "지리산", "두억시니", "버튼", "누른다", "누르", "터치"]


func _ck(name: String, ok: bool, extra := "") -> void:
	print(("PASS " if ok else "FAIL ") + name + (" :: " + extra if extra != "" else ""))
	if not ok: fails += 1


## levels.gd 정의에 실제로 존재하는 지점 모음 (footprint 좌표)
func _points(def: Dictionary) -> Array:
	var pts: Array = []
	for n in def.get("npcs", []):
		pts.append(Vector2(n[2], n[3]))
	for it in def.get("interact", []):
		pts.append(Vector2(it[1], it[2]))
	for ex in def.get("exits", []):
		pts.append((ex[0] as Rect2).get_center())
	for tr in def.get("triggers", []):
		pts.append((tr[0] as Rect2).get_center())
	for g in def.get("gates", {}).values():
		pts.append((g[0] as Rect2).get_center())
	for a in def.get("anchors", {}).values():
		if a is Vector2: pts.append(a)
		elif a is Rect2: pts.append((a as Rect2).get_center())
	return pts


func _stub_script(extra: String = "") -> GDScript:
	var s := GDScript.new()
	s.source_code = "extends Node\nvar def := {}\n" + extra
	s.reload()
	return s


func _stub(level_id: String, stubs: Array) -> Node:
	var n := Node.new()
	n.set_script(_stub_script())
	n.def = Levels.DATA[level_id]
	if "gaetgwi" in stubs:
		var g := Node.new(); g.name = "Gaetgwi"; n.add_child(g)
	var bstate := ""
	if "boss_wait" in stubs or "boss_wait_awake" in stubs: bstate = "wait"
	elif "boss_fight" in stubs: bstate = "idle"
	if bstate != "":
		var b := Node.new(); b.name = "Boss"
		b.set_script(_boss_script(bstate, "boss_wait_awake" in stubs or "boss_fight" in stubs))
		n.add_child(b)
	return n


func _boss_script(state: String, awake: bool) -> GDScript:
	var s := GDScript.new()
	s.source_code = "extends Node\nvar state := \"%s\"\nvar home_pos := %s\n" % [state, "Vector2(370, 190)" if awake else "Vector2.ZERO"]
	s.reload()
	return s


func _setup(G: Node, lid: String, flags: Array, tals: Array) -> void:
	G.flags.clear()
	for f in flags:
		G.flags[f] = 1
	G.tals = tals.duplicate()
	G.level_id = lid


func _check_text(tag: String, text: String, allow: Array) -> void:
	_ck("T1 %s 문구 %d자 이하" % [tag, MAX_CHARS], text.length() <= MAX_CHARS, "%d자 '%s'" % [text.length(), text])
	var bad: Array = []
	for w in BANNED:
		if w in text and not (w in allow):
			bad.append(w)
	_ck("T1 %s 금칙어 없음" % tag, bad.is_empty(), "'%s' 에 %s" % [text, bad])


func _initialize() -> void:
	var G = root.get_node("Game")
	var S = root.get_node("Story")
	var doc = JSON.parse_string(FileAccess.get_file_as_string(OS.get_environment("OBJ_FIXTURES") + "/objective_states.json"))
	var seen_levels := {}
	for st in doc["states"]:
		var lid: String = st["level"]
		_setup(G, lid, st["flags"], st.get("tals", []))
		var lv := _stub(lid, st.get("stub", []))
		root.add_child(lv)
		var info: Dictionary = S.objective_info(lv)
		lv.queue_free()
		var tag: String = st["id"]
		_ck("T1 %s id" % tag, info["id"] == st["id"], str(info["id"]))
		_ck("T1 %s text" % tag, info["text"] == st["text"], "'%s'" % info["text"])
		_ck("T1 %s kind" % tag, info["kind"] == st["kind"], str(info["kind"]))
		_ck("T1 %s show" % tag, info["show"] == st.get("show", "normal"), str(info["show"]))
		if info["text"] == "":
			_ck("T1 %s 문구 없음은 예외 목록(E-n)만" % tag, st.has("exempt"), "exempt=%s" % st.get("exempt", "없음"))
		else:
			_check_text(tag, info["text"], st.get("allow", []))
		# T6: 마커 대상
		var goal = info["target"]
		if st["kind"] == "none":
			_ck("T6 %s 대상 없음(null)" % tag, goal == null)
		elif goal == null:
			_ck("T6 %s 대상 있음" % tag, false, "target==null")
		else:
			var best := 1e9
			var at := Vector2.ZERO
			for p in _points(Levels.DATA[lid]):
				var d: float = (p as Vector2).distance_to(goal)
				if d < best:
					best = d; at = p
			_ck("T6 %s 대상 %s 가 levels.gd 지점과 %dpx 이내" % [tag, goal, int(TOL)], best <= TOL, "최근접 %s %.1fpx" % [at, best])
		# 래퍼는 같은 footprint 를 돌려준다
		_setup(G, lid, st["flags"], st.get("tals", []))
		var lv2 := _stub(lid, st.get("stub", []))
		root.add_child(lv2)
		var w = S.objective(lv2)
		lv2.queue_free()
		_ck("T1 %s objective() 래퍼 == target" % tag, w == goal, "%s vs %s" % [w, goal])
		seen_levels[lid] = true
	# 디버그 진입(플래그 전부 없음): 1장 레벨마다 문구가 비지 않는다
	for lid in ["beach", "gyeongju", "gwana", "pyega1", "pyega2", "palace"]:
		_setup(G, lid, [], [])
		var lv := _stub(lid, ["boss_wait"] if lid == "pyega2" else [])
		root.add_child(lv)
		var info: Dictionary = S.objective_info(lv)
		lv.queue_free()
		_ck("T1 디버그 진입(플래그 없음) %s 문구 비지 않음" % lid, info["text"] != "", str(info["id"]))
	# T9: 2장 회귀 — 리팩터 전 objective() 와 같은 좌표
	_t9(G, S)
	print("OBJECTIVE_TARGETS ", "PASS" if fails == 0 else "FAIL %d" % fails)
	quit(1 if fails > 0 else 0)


## 리팩터 전 Story.objective() 의 2장 분기 원문(origin/main 69f45b9)
func _ch2_oracle(G: Node, level: Node, lid: String):
	var f := func(k): return G.flag(k)
	match lid:
		"hwagae":
			if not f.call("raided"): return Vector2(345, 250) if f.call("ch2_start") else null
			if not f.call("ch2_old_man"): return Vector2(385, 173)
			return level.def["anchors"]["exit"]
		"jiri_path":
			return Vector2(1100, 100)
		"old_village":
			if not f.call("girl_heard"): return Vector2(748, 160)
			if f.call("q_b") < 2: return level.def["anchors"]["doll"]
			if f.call("q_b") < 3: return level.def["anchors"]["grave"]
			return level.def["anchors"]["exit"]
		"den1":
			return level.def["anchors"]["exit"]
		"den2":
			return level.def["anchors"]["exit"] if f.call("den2_gate_cleared") else Vector2(320, 200)
		"den3":
			return Vector2(90, 200) if not f.call("boss2_intro_seen") else level.def["anchors"]["hall"]
	return null


func _t9(G: Node, S: Node) -> void:
	var cases := [
		["hwagae", {}], ["hwagae", {"ch2_start": 1}], ["hwagae", {"ch2_start": 1, "raided": 1}], ["hwagae", {"raided": 1, "ch2_old_man": 1}],
		["jiri_path", {}],
		["old_village", {}], ["old_village", {"girl_heard": 1}], ["old_village", {"girl_heard": 1, "q_b": 1}], ["old_village", {"girl_heard": 1, "q_b": 2}], ["old_village", {"girl_heard": 1, "q_b": 3}],
		["den1", {}], ["den2", {}], ["den2", {"den2_gate_cleared": 1}], ["den3", {}], ["den3", {"boss2_intro_seen": 1}],
	]
	for c in cases:
		var lid: String = c[0]
		G.flags.clear()
		for k in c[1]:
			G.flags[k] = c[1][k]
		G.level_id = lid
		var lv := _stub(lid, [])
		root.add_child(lv)
		var got = S.objective(lv)
		var want = _ch2_oracle(G, lv, lid)
		lv.queue_free()
		_ck("T9 2장 %s %s 좌표 불변" % [lid, c[1]], got == want, "%s vs %s" % [got, want])
