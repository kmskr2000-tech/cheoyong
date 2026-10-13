extends SceneTree
## T6 (design/gdd/objective-marker.md §8): 용패 길잡이/목표 마커의 대상 좌표가 levels.gd 의 실제 NPC·상호작용·출구·게이트·트리거·앵커 중
## 하나와 24px 안에서 일치해야 한다. 옛 집 좌표 (96,130) 형 결함(story.gd rumor 분기) 재발 방지. tests/objective_targets.sh 가 실행한다.
var fails := 0
const TOL := 24.0

# [레벨, 플래그들, 설명, (선택) 스텁 노드]  — 1장 SC1-01~25 의 목표 상태(표 §3)
const STATES := [
	["beach", [], "beach.flute"],
	["beach", ["flute"], "beach.yokai", "gaetgwi"],
	["gyeongju", [], "gyeongju.apothecary"],
	["gyeongju", ["met_nanyeong"], "gyeongju.child"],
	["gyeongju", ["met_nanyeong", "sang_child"], "gyeongju.rest"],
	["gyeongju", ["met_nanyeong", "sang_child", "night", "summoned"], "gyeongju.summoned"],
	["gyeongju", ["met_nanyeong", "sang_child", "night", "summoned", "briefed"], "gyeongju.pyega_road"],
	["gyeongju", ["met_nanyeong", "sang_child", "night", "summoned", "briefed", "rescued", "rumor"], "gyeongju.rumor_rest"],
	["gwana", [], "gwana.officer"],
	["gwana", ["briefed"], "gwana.leave"],
	["pyega1", [], "pyega1.attic"],
	["pyega2", [], "pyega2.deep", "boss_wait"],
	["palace", [], "palace.audience"],
]

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

func _stub(level_id: String, kind: String) -> Node:
	var n := Node.new()
	n.set_script(_stub_script())
	n.def = Levels.DATA[level_id]
	if kind == "gaetgwi":
		var g := Node.new(); g.name = "Gaetgwi"; n.add_child(g)
	elif kind == "boss_wait":
		var b := Node.new(); b.name = "Boss"
		var bs := GDScript.new()
		bs.source_code = "extends Node\nvar state := \"wait\"\n"
		bs.reload()
		b.set_script(bs)
		n.add_child(b)
	return n

func _stub_script() -> GDScript:
	var s := GDScript.new()
	s.source_code = "extends Node\nvar def := {}\n"
	s.reload()
	return s

func _initialize() -> void:
	var G = root.get_node("Game")
	var S = root.get_node("Story")
	for st in STATES:
		var lid: String = st[0]
		G.flags.clear()
		for f in st[1]:
			G.flags[f] = 1
		G.level_id = lid
		var kind: String = st[3] if st.size() > 3 else ""
		var lv := _stub(lid, kind)
		root.add_child(lv)
		var goal = S.objective(lv)
		lv.queue_free()
		if goal == null:
			_ck("T6 %s 대상 있음" % st[2], false, "objective()==null")
			continue
		var best := 1e9
		var at := Vector2.ZERO
		for p in _points(Levels.DATA[lid]):
			var d: float = (p as Vector2).distance_to(goal)
			if d < best:
				best = d; at = p
		_ck("T6 %s 대상 %s 가 levels.gd 지점과 %dpx 이내" % [st[2], goal, int(TOL)], best <= TOL, "최근접 %s %.1fpx" % [at, best])
	print("OBJECTIVE_TARGETS ", "PASS" if fails == 0 else "FAIL %d" % fails)
	quit(1 if fails > 0 else 0)
