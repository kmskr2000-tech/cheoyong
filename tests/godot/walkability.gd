extends SceneTree
## 지형 충돌 검증 (아트팀): 헤드리스 Godot 에서 실제 물리 충돌로 '걸어갈 수 있는지'를 확인한다.
##   godot --headless --fixed-fps 60 --path src -s ../tests/godot/walkability.gd -- --map=<레벨 id> [--spawn=<이름>] [--flags=a,b]
## 1) 시작 위치에서 발판(10x6) 모양 충돌 질의로 4px 격자 BFS → 도달 가능 영역
## 2) NPC·상호작용·출구·트리거·적·ROUTE 지점이 전부 도달 가능한지 (막히면 FAIL)
## 3) 시작 위치 → 목적지(ROUTE 의 마지막 / 출구)까지 BFS 경로를 따라 입력 액션으로 직접 걸어서 도착하는지
## 성공하면 "WALK_RESULT <map> PASS" 를 찍고 0 으로 종료, 실패는 "FAIL:" 줄 + 비-0.

const CELL := 4
const FOOT := Vector2(11, 7)   # 실제 발판(10x6)보다 여유를 둔 질의 모양
# 맵별 반드시 갈 수 있어야 하는 footprint 지점 (levels.gd 와 같은 좌표계). 마지막 지점까지는 실제로 걸어간다.
const ROUTES := {
	"gyeongju": [Vector2(270, 300), Vector2(405, 180), Vector2(430, 170), Vector2(562, 30), Vector2(140, 245), Vector2(192, 360), Vector2(6, 379)],
	"gwana": [Vector2(395, 165), Vector2(300, 240), Vector2(470, 100), Vector2(100, 410)],
	"pyega1": [Vector2(190, 330), Vector2(520, 380), Vector2(100, 400), Vector2(146, 200), Vector2(8, 387)],
	"pyega2": [Vector2(350, 200), Vector2(500, 213), Vector2(556, 192), Vector2(600, 213), Vector2(690, 240), Vector2(282, 405)],
	"palace": [Vector2(258, 300), Vector2(256, 228), Vector2(256, 240), Vector2(258, 376)],
	# 2장 M1 (전용 지형 hwagae/jiri, asset/ch2-m1 README 좌표)
	"hwagae": [Vector2(312, 342), Vector2(360, 320), Vector2(205, 275), Vector2(430, 255), Vector2(560, 135), Vector2(655, 60), Vector2(706, 14)],
	"jiri_path": [Vector2(200, 205), Vector2(300, 190), Vector2(440, 195), Vector2(470, 235), Vector2(580, 215), Vector2(625, 150), Vector2(640, 100), Vector2(665, 80), Vector2(765, 235), Vector2(940, 100), Vector2(960, 250), Vector2(10, 205)],
	# 2장 M2 (폴백 지형 village/pyega1/gwana/pyega2 — 걸을 수 있는 자리에 맞춘 좌표, 마지막 지점이 출구 안쪽)
	"old_village": [Vector2(650, 345), Vector2(722, 335), Vector2(736, 176), Vector2(728, 60), Vector2(752, 36)],
	"den1": [Vector2(30, 181), Vector2(225, 175), Vector2(225, 90), Vector2(420, 56), Vector2(500, 185), Vector2(772, 200)],
	"den2": [Vector2(24, 200), Vector2(215, 190), Vector2(320, 230), Vector2(430, 200), Vector2(452, 200)],
	"den3": [Vector2(40, 200), Vector2(320, 235), Vector2(320, 330), Vector2(460, 200)],
	"beach": [Vector2(205, 427), Vector2(380, 405), Vector2(492, 443), Vector2(300, 132), Vector2(120, 155)],
}
# --live: 요괴를 살려 둔 채 '실제 보행 경로'로 연출 지점·상호작용 지점까지 걸어가며 어그로(state != idle)가 한 번도 없는지 본다 (god/tp 로 가려지는 문제 방지).
# 키 "<맵>:<스폰>" → 걸어갈 footprint 지점들(빈 배열 = 스폰에서 2초 가만히). 마지막 지점에서도 2초 버틴다. 트리거·출구는 꺼 둔다(장면 전환·대사 없이 거리만 본다).
const LIVE := {
	"jiri_path:fromHwagae": [Vector2(240, 195)],
	"jiri_path:fromVillage": [Vector2(727, 112)],   # SC2-15 장승 트리거 중심까지 (북쪽 출구에서 걸어서)
	"jiri_path:fromDen": [],
	"old_village:start": [],
	"den1:start": [Vector2(80, 180)],   # sight 트리거 중심까지 (SC2-04 연출 전 어그로 금지)
	"den1:fromDen2": [],
	"den2:start": [],
	"den2:fromDen3": [],
	"den3:start": [],
}
var live := false
var G: Node
var level: Node
var space: PhysicsDirectSpaceState2D
var shape := RectangleShape2D.new()
var excl: Array[RID] = []
var x0 := 0
var y0 := 0
var gw := 0
var gh := 0
var cache := {}
var fails: Array[String] = []
var map_id := ""
var dump := ""


func _initialize() -> void:
	var spawn := "start"
	var flags := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--map="): map_id = a.get_slice("=", 1)
		elif a.begins_with("--spawn="): spawn = a.get_slice("=", 1)
		elif a.begins_with("--flags="): flags = a.get_slice("=", 1)
		elif a.begins_with("--dump="): dump = a.get_slice("=", 1)
		elif a == "--live": live = true
	G = root.get_node("Game")
	G.level_id = map_id
	G.spawn_name = spawn
	for f in flags.split(",", false):
		G.flags[f] = 1
	shape.size = FOOT
	_main.call_deferred()


func _fail(msg: String) -> void:
	print("FAIL: [%s] %s" % [map_id, msg])
	quit(1)


func _free(ix: int, iy: int) -> bool:
	var k := ix + iy * 100000
	if cache.has(k):
		return cache[k]
	var p := Vector2(x0 + ix * CELL, y0 + iy * CELL)
	var q := PhysicsShapeQueryParameters2D.new()
	q.shape = shape
	q.transform = Transform2D(0.0, p + Vector2(0, -3.0))
	q.collision_mask = 1
	q.exclude = excl
	var ok := space.intersect_shape(q, 1).is_empty()
	cache[k] = ok
	return ok


func _cell(p: Vector2) -> Vector2i:
	return Vector2i(roundi((p.x - x0) / CELL), roundi((p.y - y0) / CELL))


func _pos(c: Vector2i) -> Vector2:
	return Vector2(x0 + c.x * CELL, y0 + c.y * CELL)


func _line_free(a: Vector2, b: Vector2) -> bool:
	var n := int(a.distance_to(b) / 2.0) + 1
	for i in n + 1:
		var p := a.lerp(b, float(i) / n)
		var q := PhysicsShapeQueryParameters2D.new()
		q.shape = shape
		q.transform = Transform2D(0.0, p + Vector2(0, -3.0))
		q.collision_mask = 1
		q.exclude = excl
		if not space.intersect_shape(q, 1).is_empty():
			return false
	return true


func _bfs(start: Vector2i) -> Dictionary:
	var prev := {start: start}
	var queue: Array[Vector2i] = [start]
	var head := 0
	while head < queue.size():
		var c: Vector2i = queue[head]
		head += 1
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 1), Vector2i(-1, 1), Vector2i(1, -1), Vector2i(-1, -1)]:
			var n: Vector2i = c + d
			if n.x < 0 or n.y < 0 or n.x >= gw or n.y >= gh or prev.has(n):
				continue
			if not _free(n.x, n.y):
				continue
			prev[n] = c
			queue.append(n)
	return prev


## 도달 가능한 격자 중 목표 반경 안에 있는 가장 가까운 칸 (없으면 Vector2i(-9999, 0))
func _near(prev: Dictionary, goal: Vector2, radius: float) -> Vector2i:
	var best := Vector2i(-9999, 0)
	var bd := radius
	var gc := _cell(goal)
	var r := int(radius / CELL) + 1
	for dx in range(-r, r + 1):
		for dy in range(-r, r + 1):
			var c := gc + Vector2i(dx, dy)
			if prev.has(c):
				var d := _pos(c).distance_to(goal)
				if d <= bd:
					bd = d
					best = c
	return best


func _path(prev: Dictionary, goal: Vector2i) -> Array[Vector2]:
	var cells: Array[Vector2i] = [goal]
	var c := goal
	while prev[c] != c:
		c = prev[c]
		cells.append(c)
	cells.reverse()
	var pts: Array[Vector2] = []
	for cc in cells:
		pts.append(_pos(cc))
	# 시야 선분으로 단순화
	var out: Array[Vector2] = [pts[0]]
	var i := 0
	while i < pts.size() - 1:
		var j := pts.size() - 1
		while j > i + 1 and not _line_free(pts[i], pts[j]):
			j -= 1
		out.append(pts[j])
		i = j
	return out


func _walk(path: Array[Vector2], label: String) -> bool:
	var p: Node2D = level.get_node("Player")
	for wp_v in path.slice(1):
		var wp: Vector2 = wp_v
		var frames := 0
		while p.position.distance_to(wp) > 2.5:
			await physics_frame
			frames += 1
			if live and not _aggro_check(label):
				_release()
				return false
			var d := (wp - p.position)
			var dir := d.normalized()
			Input.action_press("move_right", maxf(dir.x, 0.0))
			Input.action_press("move_left", maxf(-dir.x, 0.0))
			Input.action_press("move_down", maxf(dir.y, 0.0))
			Input.action_press("move_up", maxf(-dir.y, 0.0))
			if frames > 60 * 12:
				_release()
				fails.append("%s: 걷다 막힘 (목표 %s, 현재 %s)" % [label, str(wp), str(p.position)])
				return false
		_release()
	await physics_frame
	return true


## --live 전용: 어그로가 걸린 요괴가 있으면 실패 기록
func _aggro_check(label: String) -> bool:
	for e in get_nodes_in_group("enemy"):
		if not is_instance_valid(e) or e.is_queued_for_deletion():
			continue
		if e.get("state") != "idle":
			fails.append("%s: 연출 전 어그로 — %s(%s) state=%s, 플레이어 %s" % [label, e.get("kind"), str(e.position), e.get("state"), str(level.get_node("Player").position)])
			return false
	return true


func _live_main(player: Node2D, prev: Dictionary) -> void:
	var key := "%s:%s" % [map_id, G.spawn_name]
	if not LIVE.has(key):
		_fail("LIVE 정의 없음: " + key)
		return
	var en := get_nodes_in_group("enemy")
	print("INFO live %s 요괴 %d체" % [key, en.size()])
	if not _aggro_check(key + " 시작"):
		pass
	var cur := player.position
	for pt in LIVE[key]:
		if not fails.is_empty():
			break
		var goal: Vector2 = level.lift(pt)
		var pv := _bfs(_cell(cur))
		var gc := _near(pv, goal, 4.0)
		if gc.x == -9999:
			fails.append("%s: 경로 없음 %s" % [key, str(pt)])
			break
		var path := _path(pv, gc)
		await _walk(path, key + " →" + str(pt))
		cur = player.position
		print("  walk ", "%s 도착 %s" % [str(pt), str(cur)])
	var md := 1.0e9
	for i in 120:
		await physics_frame
		if not _aggro_check(key + " 대기"):
			break
		for e in get_nodes_in_group("enemy"):
			if is_instance_valid(e) and not e.is_queued_for_deletion():
				md = minf(md, e.global_position.distance_to(player.global_position))
	print("INFO live %s 최소 요괴 거리 %.0f (어그로 130)" % [key, md])
	if fails.is_empty():
		print("LIVE_RESULT %s PASS" % key)
		quit(0)
	else:
		for f in fails:
			print("FAIL: [%s] %s" % [key, f])
		quit(1)


func _release() -> void:
	for a in ["move_right", "move_left", "move_down", "move_up"]:
		Input.action_release(a)


func _main() -> void:
	await process_frame
	change_scene_to_file("res://scenes/level.tscn")
	for i in 400:
		await process_frame
		if current_scene != null and current_scene.get("def") != null and current_scene.get_node_or_null("Player") != null and current_scene.get("hud") != null:
			break
	level = current_scene
	if level == null or level.get_node_or_null("Player") == null:
		_fail("레벨이 로드되지 않음")
		return
	var player: Node2D = level.get_node("Player")
	for e in get_nodes_in_group("enemy"):
		if live:
			break
		# 지형만 본다: 적은 막거나 때리지 않게 치운다 (적 위치는 아래 targets 에서 따로 확인)
		e.process_mode = Node.PROCESS_MODE_DISABLED
		e.collision_layer = 0
		e.collision_mask = 0
		e.visible = false
	excl = [player.get_rid()]
	for n in level.get_children():
		if n is CharacterBody2D:
			excl.append(n.get_rid())
	for i in 4:
		await physics_frame
	space = level.get_world_2d().direct_space_state
	var m: Dictionary = level.meta
	x0 = 0
	y0 = -int(m["offset"])
	gw = int(m["size"][0]) / CELL
	gh = (int(m["size"][1]) + int(m["offset"])) / CELL
	var start := _cell(player.position)
	if not _free(start.x, start.y):
		_fail("시작 위치가 막혀 있음 %s" % str(player.position))
		return
	var prev := _bfs(start)
	if live:
		for i in 3:
			await physics_frame   # 출구·트리거 Area 는 call_deferred 로 붙으므로 기다린 뒤에 끈다
	for ch in level.get_children():   # 장면 전환·대사 없이 걷게 (live 에서도 구역은 끈다)
		if live and ch is Area2D:
			ch.set_deferred("monitoring", false)
	if live:
		await physics_frame
		await _live_main(player, prev)
		return
	print("INFO %s 도달 가능 칸 %d (격자 %dx%d)" % [map_id, prev.size(), gw, gh])
	if dump != "":   # 디버그: 도달 가능한 발판 위치를 그림 좌표로 칠한 PNG
		var img := Image.create(gw * CELL, gh * CELL, false, Image.FORMAT_RGBA8)
		for c in prev:
			img.fill_rect(Rect2i(c.x * CELL - 1, c.y * CELL - 1, CELL, CELL), Color(0.2, 1, 0.3, 0.8))
		img.save_png(dump)
	var def: Dictionary = level.def
	var targets: Array = []   # [label, screen pos, radius]
	for n in level.npcs:
		targets.append(["NPC " + n.id, n.position, 26.0])
	for ip in level.interact_points:
		targets.append(["상호작용 " + str(ip["id"]), ip["pos"], 26.0])
	for e in def.get("enemies", []):
		targets.append(["적 %s" % e[0], level.lift(Vector2(e[1], e[2])), 3.0])
	for sp in def["spawns"]:
		targets.append(["spawn " + str(sp), level.lift(def["spawns"][sp]), 3.0])
	for ch in level.get_children():
		if ch is Area2D and ch.get_child_count() > 0 and ch.get_child(0) is CollisionShape2D:
			var half: Vector2 = (ch.get_child(0).shape as RectangleShape2D).size / 2.0
			targets.append(["구역 " + str(ch.position), ch.position, maxf(half.x, half.y) + 6.0])
	for key in def.get("gates", {}):
		var r: Rect2 = def["gates"][key][0]
		targets.append(["출구 " + str(key), level.lift(r.get_center()), maxf(r.size.x, r.size.y * 0.75) / 2.0 + 6.0])
	var route: Array = ROUTES.get(map_id, [])
	for i in route.size():
		targets.append(["ROUTE %d" % i, level.lift(route[i]), 4.0])
	for t in targets:
		var c := _near(prev, t[1], t[2])
		if c.x == -9999:
			fails.append("도달 불가: %s at %s" % [t[0], str(t[1])])
		else:
			print("  ok   ", t[0])
	for ch in level.get_children():   # 걷는 동안 출구·트리거가 장면을 바꾸지 않게 (도달성은 위에서 확인함)
		if ch is Area2D:
			ch.set_deferred("monitoring", false)
	await physics_frame
	# 실제로 걸어가기: 시작 → ROUTE 순서대로 (없으면 도달 가능한 마지막 대상)
	if fails.is_empty() and not route.is_empty():
		var cur := player.position
		for i in route.size():
			var goal: Vector2 = level.lift(route[i])
			var pv := _bfs(_cell(cur))
			var gc := _near(pv, goal, 4.0)
			if gc.x == -9999:
				fails.append("ROUTE %d 경로 없음" % i)
				break
			var path := _path(pv, gc)
			if not await _walk(path, "ROUTE %d" % i):
				break
			cur = player.position
			print("  walk ", "ROUTE %d 도착 %s" % [i, str(cur)])
	if fails.is_empty():
		print("WALK_RESULT %s PASS" % map_id)
		quit(0)
	else:
		for f in fails:
			print("FAIL: [%s] %s" % [map_id, f])
		quit(1)
