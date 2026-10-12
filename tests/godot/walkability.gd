extends SceneTree
## 지형 충돌 검증 (아트팀): 헤드리스 Godot 에서 실제 물리 충돌로 '걸어갈 수 있는지'를 확인한다.
##   godot --headless --fixed-fps 60 --path src -s ../tests/godot/walkability.gd -- --map=<레벨 id> [--spawn=<이름>] [--flags=a,b]
## 1) 시작 위치에서 발판(10x6) 모양 충돌 질의로 4px 격자 BFS → 도달 가능 영역
## 2) NPC·상호작용·출구·트리거·적·ROUTE 지점이 전부 도달 가능한지 (막히면 FAIL)
## 3) 시작 위치 → 목적지(ROUTE 의 마지막 / 출구)까지 BFS 경로를 따라 입력 액션으로 직접 걸어서 도착하는지
## 성공하면 "WALK_RESULT <map> PASS" 를 찍고 0 으로 종료, 실패는 "FAIL:" 줄 + 비-0.

const CELL := 4
const FOOT := Vector2(10, 6)
# 맵별 반드시 갈 수 있어야 하는 footprint 지점 (levels.gd 와 같은 좌표계). 마지막 지점까지는 실제로 걸어간다.
const ROUTES := {
	"beach": [Vector2(205, 427), Vector2(380, 405), Vector2(492, 443), Vector2(300, 132), Vector2(120, 155)],
}
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
	q.transform = Transform2D(0.0, p + Vector2(0, -3))
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
		q.transform = Transform2D(0.0, p + Vector2(0, -3))
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
