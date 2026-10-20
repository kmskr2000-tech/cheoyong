# Autopilot (test only, "auto"): plays the whole story through the real input layer to prove it can be finished.
extends Node

const T := 32
var path = null
var path_t := 0.0
var goal = null
var stuck_t := 0.0
var last_pos = null
var cf := 0.0
var last_log := ""

func _ready() -> void:
	name = "Autopilot"

func say(s: String) -> void:
	if s != last_log: last_log = s; print("[auto] ", s)

func free_cell(x: int, y: int) -> bool:
	var W: World = G.world
	return x >= 0 and y >= 0 and x < W.W * 2 and y < W.H * 2 and not W.solid_at(x * 16 + 8, y * 16 + 8)

# A* on the 16px collision grid using Godot's AStarGrid2D
var astar: AStarGrid2D
var astar_flags := ""
func find_path(from: Vector2, to: Vector2):
	var W: World = G.world
	var key := str(W.flags.get("gate_open", false)) + str(W.flags.get("paths_open", false)) + str(W.flags.get("house_open", false))
	if astar == null or key != astar_flags:
		astar_flags = key
		astar = AStarGrid2D.new()
		astar.region = Rect2i(0, 0, W.W * 2, W.H * 2)
		astar.cell_size = Vector2(16, 16)
		astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
		astar.update()
		for y in W.H * 2:
			for x in W.W * 2:
				if not free_cell(x, y): astar.set_point_solid(Vector2i(x, y))
	var s := Vector2i(int(from.x / 16), int(from.y / 16))
	var g := Vector2i(int(to.x / 16), int(to.y / 16))
	if not free_cell(g.x, g.y):
		var best = null; var bd := 1e9
		for r in range(1, 8):
			for dy in range(-r, r + 1):
				for dx in range(-r, r + 1):
					if free_cell(g.x + dx, g.y + dy) and dx * dx + dy * dy < bd: bd = dx * dx + dy * dy; best = Vector2i(g.x + dx, g.y + dy)
			if best != null: break
		if best == null: return null
		g = best
	if astar.is_point_solid(s): astar.set_point_solid(s, false)
	var pts := astar.get_point_path(s, g)
	if pts.is_empty(): return null
	var out := []
	for p in pts: out.append(p + Vector2(8, 8))
	return out

func plan():
	var g = G.game; var f: Dictionary = g.flags
	var npc := func(id): var n = g.npc(id); return {"talk": n, "pos": Vector2(n.x, n.y)}
	var hunt := func(z):
		var p = g.player; var best = null; var bd := 1e9
		for e in g.enemies:
			if e.dead or e.state == "kneel" or (z and e.zone != z and not e.summoned): continue
			var d: float = p.dist_to(e)
			if d < bd: bd = d; best = e
		if best: return {"pos": Vector2(best.x, best.y)}
		var sp: Array = Story.SPAWNS[z].list
		var s: Array = sp[int(g.time / 6) % sp.size()]
		return {"pos": Vector2(s[1], s[2]) * T}
	if not f.get("q1", false): return npc.call("yongwang")
	if not f.get("q2", false): return hunt.call("beach") if int(f.get("kills_beach", 0)) < 6 else npc.call("yongwang")
	if not f.get("king_met", false): return {"pos": Vector2(61, 50) * T}
	if not f.get("q3", false): return npc.call("halmi")
	if not f.get("q4", false):
		for z in ["ruin", "forest", "pond"]:
			var b: Dictionary = Story.BOSSES[z]
			if f.get(b.flag, false): continue
			if int(f.get("kills_" + z, 0)) < 6: return hunt.call(z)
			return {"pos": Vector2(b.trigger[0], b.trigger[1]) * T}
		if not f.get("dosa_done", false) and int(f.get("kills_total", 0)) >= 12: return npc.call("dosa")
		return npc.call("halmi")
	if not f.get("yeoksin_done", false): return {"pos": Vector2(20, 26) * T}
	return npc.call("wife_home")

func tick(dt: float) -> void:
	Inp.bot = {"x": 0.0, "y": 0.0, "down": {}}
	match G.state:
		"title": Inp.press("confirm"); return
		"intro", "ending":
			if randf() < 0.05: Inp.press("confirm")
			return
		"play": pass
		_: return
	var g = G.game; var p = g.player
	if g.ui.shop or g.ui.menu: Inp.press("menu"); return
	if g.ui.dialog or g.ui.banner:
		cf += dt
		if cf > 0.25: cf = 0; Inp.press("confirm")
		return
	if g.frozen or p.state == "dead": return
	var foe = null; var fd := 260.0
	for e in g.enemies:
		if e.dead or e.state == "kneel" or e.kneeling or e.alpha == 0: continue
		var d: float = p.dist_to(e)
		if d < fd or e == g.boss: fd = min(fd, d); foe = e
		if e == g.boss: break
	if p.heung >= 100 and foe and (not (g.boss is Object) or g.boss.ult_vulnerable or g.boss.type != "yeoksin"): Inp.press("ult"); return
	var gl = plan()
	if foe:
		gl = {"pos": Vector2(foe.x, foe.y)}
		var d: float = p.dist_to(foe)
		if d < 70 + foe.r:
			p.face_to(atan2(foe.y - p.y, foe.x - p.x))
			Inp.bot.down["attack"] = true
			if p.skills.get("skill2", false) and p.gi > 60: Inp.press("skill2")
			return
		if d < 200 and p.skills.get("skill1", false) and p.gi > 40: p.face_to(atan2(foe.y - p.y, foe.x - p.x)); Inp.press("skill1")
	if gl.has("talk") and Vector2(p.x, p.y).distance_to(gl.pos) < 82: Inp.press("interact"); return
	path_t -= dt
	if path == null or path_t <= 0 or goal == null or goal.distance_to(gl.pos) > 64:
		path = find_path(Vector2(p.x, p.y), gl.pos); path_t = 1.0; goal = gl.pos
		if path == null: say("no path to %d,%d" % [gl.pos.x / T, gl.pos.y / T])
	if path and path.size() > 0:
		while path.size() > 1 and Vector2(p.x, p.y).distance_to(path[0]) < 14: path.pop_front()
		var dv: Vector2 = (path[0] - Vector2(p.x, p.y)).normalized()
		Inp.bot.x = dv.x; Inp.bot.y = dv.y
	stuck_t += dt
	if stuck_t > 2:
		if last_pos != null and last_pos.distance_to(Vector2(p.x, p.y)) < 10 and foe == null: path = null; Inp.press("roll")
		last_pos = Vector2(p.x, p.y); stuck_t = 0
