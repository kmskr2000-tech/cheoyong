# Chapter: the story of one map in chapters 2-6 (경주 순례). Subclasses fill in NPCs, spawns, bosses, steps and talk.
# Progress lives in game.flags with the chapter prefix (e.g. "c2_"). Story routes calls here for the chapter's map.
class_name Chapter
extends RefCounted

const T := 32
var g      # Game
var n := 2         # chapter number
var map := ""      # map id (maps.gd)
var title := ""    # shown when the chapter begins

func _init(game) -> void:
	g = game

static func at(tx: float, ty: float) -> Vector2: return Vector2(tx * T, ty * T)
func fl(k: String) -> bool: return g.flags.get(k, false)
func num(k: String) -> int: return int(g.flags.get(k, 0))
func setf(k: String, v = true) -> void: g.flags[k] = v
func p(): return g.player

# ---------- data (override) ----------
# [id, sprite, tile x, tile y, name, facing, visibility callable or null]
func npcs() -> Array: return []
# zone -> {"lvl": n, "list": [[type, tx, ty], ...], "elite": [type, tx, ty, name] (optional)}
func spawns() -> Dictionary: return {}
# zone -> {"type", "flag", "at": [tx, ty], "trigger": [tx, ty], "need": [[flag key, count], ...], "lines": [[speaker, text], ...]}
func bosses() -> Dictionary: return {}
# main steps in order: {"text", "done": Callable(), "talk": npc id, "pos": [tx, ty], "hunt": zone, "count": [flag, n]}
func steps() -> Array: return []
# side quests: {"id", "giver", "name", "text", "kind": "kill"|"collect"|"elite"|"talk", "zone", "count", "item", "reward": {...}}
func sides() -> Array: return []

# ---------- progress ----------
func started() -> bool: return fl("c%d_start" % n)
func done() -> bool: return fl("c%d_done" % n)

func current_step():
	for s in steps():
		if not s.done.call(): return s
	return null

# objective for the HUD and the autopilot; "map" says where the target is
func objective() -> Dictionary:
	var s = current_step()
	if s == null: return {"text": "", "target": null, "map": map}
	var o := {"text": s.text, "target": null, "map": map}
	if s.has("count"):
		var c: Array = s.count
		o.text = "%s (%d/%d)" % [s.text, min(num(c[0]), c[1]), c[1]]
	if s.has("talk"):
		var who = npc_pos(s.talk)
		if who != null: o.target = who
		o.talk = s.talk
	elif s.has("pos"): o.target = at(s.pos[0], s.pos[1])
	if s.has("hunt"): o.hunt = s.hunt
	return o

func npc_pos(id: String):
	for d in npcs():
		if d[0] == id: return at(d[2], d[3])
	return null

# ---------- talking (override interact; return true when handled) ----------
func interact(_npc) -> bool: return false

# the story step that points at this NPC comes first, then its side quest, then its usual talk
func talk(npc) -> bool:
	var s = current_step()
	if s != null and s.get("talk", "") == npc.id and interact(npc): return true
	if side_talk(npc): return true
	return interact(npc)

func say(lines: Array, done = null) -> void: g.ui.say(lines, done)

# ---------- side quests ----------
func side_state(q: Dictionary) -> String: return str(g.flags.get("sq_" + q.id, ""))  # "", "on", "done"

func side_progress(q: Dictionary) -> int:
	match q.kind:
		"kill": return num("sqk_" + q.id)
		"collect": return int(g.player.items.get(q.item, 0))
		"elite": return 1 if fl("sqe_" + q.id) else 0
		"talk": return 1 if fl("sqt_" + q.id) else 0
	return 0

# NPC side quest talk: offer, remind, or hand in. Returns true when this NPC has a side quest to talk about.
func side_talk(npc) -> bool:
	for q in sides():
		if q.kind == "talk" and q.target == npc.id and side_state(q) == "on" and not fl("sqt_" + q.id):
			say(q.found, func(): g.flags["sqt_" + q.id] = true; g.refresh_npcs(); g.ui.toast("[부탁] %s — 다 했소" % q.name))
			return true
	for q in sides():
		if q.giver != npc.id: continue
		var st := side_state(q)
		if st == "done": continue
		if st == "":
			say(q.offer, func():
				g.flags["sq_" + q.id] = "on"; g.flags["sqk_" + q.id] = 0
				g.ui.toast("[부탁] " + q.name); Sfx.sfx("quest"))
			return true
		if side_progress(q) >= q.count:
			say(q.thanks, func():
				g.flags["sq_" + q.id] = "done"
				if q.kind == "collect": g.player.items[q.item] = max(0, int(g.player.items.get(q.item, 0)) - q.count)
				g.give(q.reward)
				Sfx.sfx("quest"); g.save_game())
			return true
		say([[npc.name, q.remind + " (%d/%d)" % [side_progress(q), q.count]]])
		return true
	return false

# kills and drops for side quests (called by game.on_purify)
func on_purify(e) -> void:
	for q in sides():
		if side_state(q) != "on": continue
		if q.kind == "kill" and (q.zone == "" or e.zone == q.zone) and (not q.has("type") or e.type == q.type):
			g.flags["sqk_" + q.id] = num("sqk_" + q.id) + 1
			if num("sqk_" + q.id) == q.count: g.ui.toast("[부탁] %s — 다 했소" % q.name)
		elif q.kind == "collect" and (q.zone == "" or e.zone == q.zone) and side_progress(q) < q.count and randf() < q.get("chance", 0.45):
			g.player.items[q.item] = int(g.player.items.get(q.item, 0)) + 1
			g.ui.toast("%s (%d/%d)" % [q.item_name, side_progress(q), q.count])
		elif q.kind == "elite" and e.elite and e.type == q.type:
			g.flags["sqe_" + q.id] = true
			g.ui.toast("[부탁] %s — 다 했소" % q.name)

# ---------- triggers ----------
func update(_dt: float) -> void:
	var pl = p()
	if g.frozen or g.boss: return
	for zone in bosses():
		var b: Dictionary = bosses()[zone]
		if fl(b.flag) or not boss_ready(b): continue
		if Vector2(pl.x, pl.y).distance_to(at(b.trigger[0], b.trigger[1])) < 220: boss_intro(zone); return

func boss_ready(b: Dictionary) -> bool:
	for nd in b.get("need", []):
		if nd[1] is bool:
			if not fl(nd[0]): return false
		elif num(nd[0]) < nd[1]: return false
	return true

func boss_intro(zone: String) -> void:
	var b: Dictionary = bosses()[zone]
	var pos = at(b.at[0], b.at[1])
	g.boss = true
	g.cutscene(func():
		var boss = g.spawn_boss(b.type, pos.x, pos.y, zone, b.get("lvl", 1), {"mini": b.get("mini", false), "name": b.get("name", "")})
		boss.spawn_t = 1.2
		Sfx.sfx("roar"); g.fx.screen_shake(10)
		await g.pan(pos + Vector2(0, -40), 1.0)
		await g.wait(0.6)
		await g.say_async(b.lines)
		await g.pan(null, 0.6)
		g.start_boss_fight(boss, pos.x, pos.y + 40))

# override: what the boss says and gives when it kneels; return true when handled
func boss_defeated(_b) -> bool: return false

# helper for chapter rewards
func hyangga(key: String) -> Array:
	return ["@hyangga", key]
