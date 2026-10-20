# Entities: Cheoyong, yokai (bosses use boss.gd), NPCs, projectiles, ground hazards and coins. Combat rules live here.
class_name Ent
extends RefCounted

const MASKS := {
	"cheoyong": {"name": "처용탈", "desc": "균형 · 흥 +30%", "atk": 1.0, "taken": 1.0, "heung": 1.3, "gi": 1.0, "skill": 1.0, "color": Color("#ff6a5a")},
	"gwimyeon": {"name": "귀면탈", "desc": "공격 +35% · 받는 피해 +15%", "atk": 1.35, "taken": 1.15, "heung": 1.0, "gi": 1.0, "skill": 1.0, "color": Color("#c04cff")},
	"yongwang": {"name": "용왕탈", "desc": "기 회복 2배 · 스킬 피해 +20%", "atk": 1.0, "taken": 1.0, "heung": 1.0, "gi": 2.0, "skill": 1.2, "color": Color("#4cd6ff")},
}
const SKILLS := {
	"skill1": {"name": "소리결", "gi": 12, "cd": 0.6},
	"skill2": {"name": "탈춤 회오리", "gi": 18, "cd": 1.2},
	"skill3": {"name": "용왕 물결", "gi": 20, "cd": 1.0},
}
const ENEMIES := {
	"imp": {"name": "꼬마도깨비", "hp": 34, "atk": 6, "spd": 78, "r": 10, "ai": "melee", "range": 36, "exp": 8, "coin": [1, 3]},
	"snake": {"name": "구렁이", "hp": 48, "atk": 8, "spd": 55, "r": 12, "ai": "lunge", "range": 100, "exp": 10, "coin": [2, 4]},
	"dokkaebi": {"name": "도깨비", "hp": 80, "atk": 11, "spd": 62, "r": 13, "ai": "heavy", "range": 50, "exp": 16, "coin": [3, 6]},
	"ghoul": {"name": "두억시니", "hp": 100, "atk": 13, "spd": 48, "r": 14, "ai": "slam", "range": 60, "exp": 18, "coin": [3, 7]},
	"ghost": {"name": "원귀", "hp": 56, "atk": 9, "spd": 66, "r": 11, "ai": "ranged", "range": 210, "exp": 14, "coin": [2, 5], "float": true},
	"dokchief": {"name": "도깨비 대장", "hp": 650, "atk": 16, "spd": 70, "r": 26, "ai": "boss", "exp": 120, "coin": [40, 50], "boss": true},
	"gumiho": {"name": "구미호", "hp": 720, "atk": 15, "spd": 95, "r": 22, "ai": "boss", "exp": 140, "coin": [40, 50], "boss": true},
	"imugi": {"name": "이무기", "hp": 820, "atk": 17, "spd": 40, "r": 30, "ai": "boss", "exp": 160, "coin": [45, 60], "boss": true},
	"yeoksin": {"name": "역신", "hp": 1500, "atk": 18, "spd": 80, "r": 22, "ai": "boss", "exp": 300, "coin": [0, 0], "boss": true},
}
const ORB_COL := {"fire": [Color("#4cb8ff"), Color("#9fe0ff")], "plague": [Color("#8aff6a"), Color("#c0ff9a")], "water": [Color("#3a9cff"), Color("#bfe6ff")], "shadow": [Color("#b04cff"), Color("#e0a8ff")]}

static func game():
	return G.game

static func sfx(n: String) -> void:
	Sfx.sfx(n)

# ---------- drawing helpers ----------
# draws a character frame with its feet at (x, y) as an upright billboard in the 3D view (shadows come from the sun)
static func draw_sprite(name: String, anim: String, dir: String, t: float, x: float, y: float, o := {}) -> void:
	G.game.view.sprite(name, anim, dir, t, x, y, o)

# screen position of a ground point, z pixels above it (screen-aligned, like the sprites)
static func sp(x: float, y: float, z := 0.0) -> Vector2:
	return G.game.sp(x, y, z)

static func head_y(name: String) -> float:
	if not Assets.chars.has(name): return 60.0
	var c: Dictionary = Assets.chars[name]
	return (c.foot - c.top) * c.scale

# ---------- base actor ----------
class Actor:
	var x = 0.0
	var y = 0.0
	var r = 10.0
	var face = PI / 2
	var dir = "south"
	var anim = "idle"
	var anim_t = 0.0
	var flash = 0.0
	var kbx = 0.0
	var kby = 0.0
	var dead = false
	var alpha = 1.0
	var hidden = false

	func set_anim(a: String) -> void:
		if anim != a: anim = a; anim_t = 0.0

	func face_to(a: float) -> void:
		face = a; dir = G.dir_from_angle(a)

	func apply_knock(dt: float) -> void:
		if abs(kbx) + abs(kby) < 1: return
		G.world.move_circle(self, kbx * dt, kby * dt)
		var d = exp(-10 * dt); kbx *= d; kby *= d

	func dist_to(o) -> float:
		return Vector2(o.x - x, o.y - y).length()

# ---------- player ----------
class Player extends Actor:
	var lvl = 1
	var xp = 0.0
	var coins = 0
	var max_hp = 100
	var hp = 100.0
	var max_gi = 100
	var gi = 100.0
	var heung = 0.0
	var items = {"yakgwa": 1, "sikhye": 1}
	var masks: Array = []
	var mask = ""
	var skills = {}
	var state = "move"
	var state_t = 0.0
	var combo = 0
	var combo_window = 0.0
	var iframe = 0.0
	var cd = {"roll": 0.0, "skill1": 0.0, "skill2": 0.0, "skill3": 0.0}
	var speed = 150.0
	var swung = false
	var queued = false
	var roll_a = 0.0
	var skill = ""
	var skill_tick = 0.0
	var wave_hit = {}
	var ult_ring = false
	var ult_hit = false

	func _init(px: float, py: float) -> void:
		x = px; y = py; r = 11

	func m() -> Dictionary: return Ent.MASKS.get(mask, Ent.MASKS.cheoyong)
	func atk() -> float: return (10 + (lvl - 1) * 2.5) * (m().atk if mask != "" else 1.0)
	func exp_need() -> int: return 20 + lvl * 18
	func fx() -> Fx: return G.game.fx

	func gain_exp(n: float) -> void:
		xp += n
		while xp >= exp_need():
			xp -= exp_need(); lvl += 1
			max_hp += 14; hp = max_hp; gi = max_gi
			fx().text(x, y - 100, "레벨 %d!" % lvl, Color("#ffe27a"), 22)
			fx().ring(x, y, 10, 90, 0.8, Color("#ffe27a"), 3)
			Ent.sfx("level")

	func add_heung(n: float) -> void:
		if not G.game.flags.get("has_ult", false): return
		heung = min(100.0, heung + n * (m().heung if mask != "" else 1.0))

	func update(dt: float) -> void:
		var g = G.game
		anim_t += dt; state_t += dt
		flash = max(0.0, flash - dt * 5)
		iframe = max(0.0, iframe - dt)
		for k in cd: cd[k] = max(0.0, cd[k] - dt)
		combo_window = max(0.0, combo_window - dt)
		gi = min(float(max_gi), gi + dt * 4 * (m().gi if mask != "" else 1.0))
		apply_knock(dt)
		if state == "dead": return
		if g.frozen: set_anim("idle"); return
		var mv = Inp.move()
		var moving = mv.length() > 0.15
		match state:
			"move":
				if moving:
					face_to(mv.angle())
					var sp = speed * min(1.0, mv.length() * 1.2)
					G.world.move_circle(self, mv.x * sp * dt, mv.y * sp * dt)
					arena_clamp()
					set_anim("walk")
				else: set_anim("idle")
				if g.flags.get("has_attack", false) and (Inp.hit("attack") or Inp.down("attack")): start_attack()
				elif g.flags.get("has_attack", false) and Inp.hit("roll") and cd.roll <= 0: start_roll(mv.angle() if moving else face)
				else:
					for k in ["skill1", "skill2", "skill3"]:
						if Inp.hit(k): try_skill(k); break
				if state == "move" and Inp.hit("ult"): try_ult()
				if state == "move":
					if Inp.hit("item1"): use_item("yakgwa")
					if Inp.hit("item2"): use_item("sikhye")
					if Inp.hit("mask"): cycle_mask()
			"attack":
				var dur = 0.42 if combo == 2 else 0.3
				if state_t < 0.1: G.world.move_circle(self, cos(face) * 140 * dt, sin(face) * 140 * dt)
				if state_t >= 0.08 and not swung: swung = true; melee_hit()
				if Inp.hit("attack") or (Inp.down("attack") and state_t > 0.15): queued = true
				if Inp.hit("roll") and cd.roll <= 0 and state_t > 0.12:
					start_roll(mv.angle() if moving else face); return
				if state_t >= dur:
					state = "move"; combo_window = 0.35
					if queued:
						if moving: face_to(mv.angle())
						start_attack()
			"roll":
				var k = 1.0 - state_t / 0.32
				G.world.move_circle(self, cos(roll_a) * 360 * k * dt * 1.4, sin(roll_a) * 360 * k * dt * 1.4)
				arena_clamp()
				if randf() < 0.6: fx().add({"x": x, "y": y, "z": 2.0, "vx": (randf() - 0.5) * 30, "vz": 20.0, "life": 0.4, "size": 3.0, "color": Color("#c9b89a"), "g": 60.0})
				if state_t >= 0.32: state = "move"
			"skill": update_skill(dt)
			"hurt":
				if state_t >= 0.25: state = "move"
			"ult": update_ult(dt)

	func arena_clamp() -> void:
		var ar = G.game.arena
		if ar == null: return
		var dx: float = x - ar.x; var dy: float = (y - ar.y) / 0.7; var d = Vector2(dx, dy).length()
		if d > ar.r: x = ar.x + dx / d * ar.r; y = ar.y + dy / d * ar.r * 0.7

	func auto_aim(rng := 140.0) -> void:
		var best = null; var bd = rng
		for e in G.game.enemies:
			if e.dead or e.state == "kneel": continue
			var d: float = dist_to(e)
			var ad: float = abs(G.angdiff(face, atan2(e.y - y, e.x - x)))
			if d < bd and ad < 1.6: bd = d; best = e
		if best: face_to(atan2(best.y - y, best.x - x))

	func start_attack() -> void:
		combo = (combo + 1) % 3 if combo_window > 0 else 0
		state = "attack"; state_t = 0; swung = false; queued = false
		auto_aim()
		set_anim("attack"); anim_t = 0
		Ent.sfx("swing")
		for i in 7:
			var aa = face - 0.9 + (i / 6.0) * 1.8 * (-1 if combo == 1 else 1) + (1.8 if combo == 1 else 0.0)
			fx().add({"x": x + cos(aa) * 40, "y": y + sin(aa) * 28, "z": 30.0, "life": 0.18 + i * 0.015, "size": 3.0, "color": Color("#ffe9a8") if combo == 2 else Color("#e8f4ff"), "glow": true})

	func melee_hit() -> void:
		var R = 72.0 if combo == 2 else 60.0
		var arc = 1.5 if combo == 2 else 1.15
		var mult = 1.7 if combo == 2 else 1.0
		var kb = 320.0 if combo == 2 else 160.0
		var hits = 0
		for e in G.game.enemies:
			if e.dead or e.state == "kneel" or e.invuln: continue
			var d: float = dist_to(e) - e.r
			var ad: float = abs(G.angdiff(face, atan2(e.y - y, e.x - x)))
			if d < R and (ad < arc or d < 16):
				e.damage(atk() * mult, cos(face) * kb, sin(face) * kb); hits += 1
		if hits > 0:
			add_heung(4 * hits)
			G.game.hitstop = max(G.game.hitstop, 0.08 if combo == 2 else 0.045)
		G.game.on_player_attack(hits)

	func start_roll(a: float) -> void:
		state = "roll"; state_t = 0; roll_a = a; face_to(a); iframe = 0.3; cd.roll = 0.5
		set_anim("walk"); Ent.sfx("roll")
		G.game.rolled = true

	func try_skill(k: String) -> void:
		if not skills.get(k, false) or cd[k] > 0: return
		var s: Dictionary = Ent.SKILLS[k]
		if gi < s.gi: fx().text(x, y - 100, "기가 모자라오", Color("#9fd8ff"), 14); return
		gi -= s.gi; cd[k] = s.cd
		state = "skill"; state_t = 0; skill = k; skill_tick = 0
		auto_aim(220)
		if k == "skill1":
			set_anim("attack"); Ent.sfx("skill1")
			G.game.projectiles.append(Ent.SoundWave.new(x, y, face, atk() * 1.7 * skill_mult()))
			fx().circle(x, y, 46, Color("#7ff0ff"), 0.6)
		elif k == "skill2":
			set_anim("cast"); Ent.sfx("skill2"); fx().circle(x, y, 90, Color("#ff9ad0"), 1.2)
		else:
			set_anim("walk"); Ent.sfx("skill3"); wave_hit = {}; fx().circle(x, y, 50, Color("#5ab8ff"), 0.7)

	func skill_mult() -> float: return m().skill if mask != "" else 1.0

	func update_skill(dt: float) -> void:
		if skill == "skill1" and state_t > 0.3: state = "move"
		elif skill == "skill2":
			face += dt * 14; dir = G.dir_from_angle(face); set_anim("walk")
			var mv = Inp.move()
			G.world.move_circle(self, mv.x * 90 * dt, mv.y * 90 * dt)
			skill_tick -= dt
			if skill_tick <= 0:
				skill_tick = 0.18
				fx().ring(x, y, 30, 86, 0.3, Color("#ffd2f0"), 2)
				var hits = 0
				for e in G.game.enemies:
					if e.dead or e.state == "kneel" or e.invuln: continue
					if dist_to(e) - e.r < 84:
						var a = atan2(e.y - y, e.x - x)
						e.damage(atk() * 0.55 * skill_mult(), cos(a) * 120, sin(a) * 120); hits += 1
				if hits: add_heung(2 * hits)
			for i in 2:
				var a = randf() * TAU
				fx().add({"x": x + cos(a) * 60, "y": y + sin(a) * 40, "z": 10 + randf() * 40, "vx": -sin(a) * 120, "vy": cos(a) * 80, "life": 0.35, "size": 3.0, "color": [Color("#ff9ad0"), Color("#ffe9a8"), Color("#9fe0ff")][i % 3], "glow": true})
			if state_t > 1.1: state = "move"
		elif skill == "skill3":
			var t = state_t
			if t < 0.35:
				var sp = 520 * (1 - t / 0.35) + 120
				G.world.move_circle(self, cos(face) * sp * dt, sin(face) * sp * dt)
				arena_clamp()
				iframe = max(iframe, 0.05)
				for i in 3:
					fx().add({"x": x + (randf() - 0.5) * 40, "y": y + (randf() - 0.5) * 20, "z": randf() * 20, "vz": 80 + randf() * 80, "g": 300.0, "life": 0.5, "size": 3.0, "color": [Color("#4cd6ff"), Color("#bff2ff"), Color("#2a7cff")][i], "glow": true})
				for e in G.game.enemies:
					if e.dead or e.state == "kneel" or e.invuln or wave_hit.has(e): continue
					if dist_to(e) - e.r < 56:
						wave_hit[e] = true
						e.damage(atk() * 2.1 * skill_mult(), cos(face) * 300, sin(face) * 300)
						add_heung(4)
			elif t > 0.5: state = "move"

	func try_ult() -> void:
		if not G.game.flags.get("has_ult", false): return
		if heung < 100: fx().text(x, y - 100, "흥이 덜 찼소", Color("#ffb3d0"), 14); return
		heung = 0; state = "ult"; state_t = 0; iframe = 3; set_anim("cast")
		Ent.sfx("ult"); G.game.push_music("song")
		G.game.ult_used = true

	func update_ult(dt: float) -> void:
		var t = state_t
		if randf() < 0.7:
			var a = randf() * TAU; var rr = 40 + randf() * 300
			fx().add({"x": x + cos(a) * rr, "y": y + sin(a) * rr * 0.6, "vz": 40 + randf() * 60, "life": 1.2, "size": 3.0, "color": [Color("#ffe9a8"), Color("#9fe0ff"), Color("#ff9ad0")][randi() % 3], "glow": true})
		if t > 0.6 and not ult_ring:
			ult_ring = true; fx().ring(x, y, 20, 420, 1.2, Color("#ffe9a8"), 4); fx().circle(x, y, 160, Color("#ffe08a"), 2.2)
		if t > 1.6 and not ult_hit:
			ult_hit = true
			fx().ring(x, y, 20, 600, 1.4, Color("#9fe0ff"), 6); fx().screen_flash(0.8, Color("#fff6d8")); fx().screen_shake(8)
			var verses: int = G.game.verse_count()
			for e in G.game.enemies.duplicate():
				if e.dead or e.state == "kneel": continue
				if dist_to(e) < 620:
					var dmg = atk() * (3 + verses * 1.2)
					if e.def.get("boss", false): e.damage(99999.0 if e.ult_vulnerable else min(dmg, e.max_hp * 0.22), 0, 0, true)
					else: e.damage(99999.0, 0, 0, true)
		if t > 2.6:
			state = "move"; ult_ring = false; ult_hit = false; G.game.pop_music()

	func use_item(k: String) -> void:
		if items[k] <= 0:
			fx().text(x, y - 100, "약과가 없소" if k == "yakgwa" else "식혜가 없소", Color("#cccccc"), 14); return
		if k == "yakgwa":
			if hp >= max_hp: return
			hp = min(float(max_hp), hp + max_hp * 0.4); fx().text(x, y - 100, "+체력", Color("#7dff9a"), 16)
		else:
			if gi >= max_gi: return
			gi = min(float(max_gi), gi + 60); fx().text(x, y - 100, "+기", Color("#7fd0ff"), 16)
		items[k] -= 1; Ent.sfx("item")
		fx().burst(x, y - 40, 10, {"color": Color("#7dff9a") if k == "yakgwa" else Color("#7fd0ff"), "glow": true, "g": 0.0, "speed": 60.0, "life": 0.6})

	func cycle_mask() -> void:
		if masks.size() < 2: return
		mask = masks[(masks.find(mask) + 1) % masks.size()]
		fx().text(x, y - 104, m().name, m().color, 16)
		fx().ring(x, y, 10, 60, 0.5, m().color, 3)
		Ent.sfx("ui")

	func hurt(dmg: float, fx_: float, fy: float) -> bool:
		if iframe > 0 or state == "dead" or state == "ult" or G.game.frozen: return false
		if G.has("god"): flash = 1; iframe = 0.3; return true
		var d = int(round(dmg * (m().taken if mask != "" else 1.0) * (0.9 + randf() * 0.2)))
		hp -= d; flash = 1; iframe = 0.7
		var a = atan2(y - fy, x - fx_)
		kbx = cos(a) * 260; kby = sin(a) * 260
		fx().text(x, y - 90, "-%d" % d, Color("#ff7a7a"), 16); fx().screen_shake(5); Ent.sfx("hurt")
		add_heung(6)
		state = "hurt"; state_t = 0
		if hp <= 0:
			hp = 0; state = "dead"; state_t = 0; G.game.on_player_death()
		return true

	func draw(ci: CanvasItem) -> void:
		if mask != "":
			var c: Color = m().color; c.a = 0.35 + sin(G.game.time * 3) * 0.1
			Fx.gellipse(ci, Vector2(x, y), 20, 11, c, false, 2)

	func draw3d() -> void:
		var blink = iframe > 0 and state != "roll" and state != "ult" and int(iframe * 20) % 2 == 0
		var an = anim; var fps = 10.0; var loop = true; var d = dir
		if state == "attack":
			an = "attack"; fps = Assets.anim_len("cheoyong", "attack", d) / (0.42 if combo == 2 else 0.3); loop = false
		elif state == "roll": an = "walk"; fps = 22
		elif state == "ult": an = "cast"; d = "south"; fps = 8
		elif state == "dead": an = "idle"
		if an == "idle": fps = 6
		var squash = 0.82 if state == "roll" else (max(0.5, 1 - state_t) if state == "dead" else 1.0)
		Ent.draw_sprite("cheoyong", an, d, anim_t, x, y, {"fps": fps, "loop": loop, "flash": flash, "alpha": 0.45 if blink else 1.0, "squash": squash})

# ---------- projectiles ----------
class SoundWave:
	var x: float; var y: float; var a: float; var dmg: float
	var t = 0.0
	var hit = {}
	var dead = false
	var owner = "player"
	func _init(px, py, pa, pd) -> void:
		x = px; y = py; a = pa; dmg = pd
	func update(dt: float) -> void:
		t += dt
		var R = 40 + t * 520
		for e in G.game.enemies:
			if e.dead or e.state == "kneel" or e.invuln or hit.has(e): continue
			var d = Vector2(e.x - x, e.y - y).length()
			var ad: float = abs(G.angdiff(a, atan2(e.y - y, e.x - x)))
			if d - e.r < R and ad < 0.62:
				hit[e] = true; e.damage(dmg, cos(a) * 240, sin(a) * 240); G.game.player.add_heung(3)
		if t > 0.42: dead = true
	func draw(_ci: CanvasItem) -> void: pass
	func draw_glow(ci: CanvasItem) -> void:
		var R = 40 + t * 520; var k = t / 0.42
		for i in 3:
			var rr = R - i * 18
			if rr < 10: continue
			var pts = PackedVector2Array()
			for j in 17:
				var an = a - 0.6 + j / 16.0 * 1.2
				pts.append(Ent.sp(x + cos(an) * rr, y + sin(an) * rr * 0.65, 30))
			ci.draw_polyline(pts, Color(0.63, 0.88, 1.0, (1 - k) * (0.8 - i * 0.22)), 3 - i, true)

class Orb:
	var x: float; var y: float; var vx: float; var vy: float; var dmg: float
	var kind: String
	var t = 0.0
	var life = 3.0
	var r = 9.0
	var homing = 0.0
	var z = 30.0
	var dead = false
	var owner = "enemy"
	func _init(px, py, pvx, pvy, pd, k := "fire", o := {}) -> void:
		x = px; y = py; vx = pvx; vy = pvy; dmg = pd; kind = k
		life = o.get("life", 3.0); r = o.get("r", 9.0); homing = o.get("homing", 0.0)
	func update(dt: float) -> void:
		t += dt
		var p = G.game.player
		if homing > 0 and t < 1.4:
			var a = atan2(p.y - y, p.x - x); var sp = Vector2(vx, vy).length()
			var cur = atan2(vy, vx); var na = cur + clampf(G.angdiff(cur, a), -homing * dt, homing * dt)
			vx = cos(na) * sp; vy = sin(na) * sp
		x += vx * dt; y += vy * dt
		if randf() < 0.5: G.game.fx.add({"x": x, "y": y, "z": z, "life": 0.3, "size": 3.0, "color": Ent.ORB_COL[kind][1], "glow": true})
		if Vector2(p.x - x, p.y - y).length() < r + p.r:
			if p.hurt(dmg, x, y): dead = true
		if t > life or (G.world.solid_at(x, y) and kind != "shadow" and t > 0.2): dead = true
	func draw(ci: CanvasItem) -> void:
		Fx.gellipse(ci, Vector2(x, y), 7, 4, Color(0, 0, 0.04, 0.3))
	func draw_glow(ci: CanvasItem) -> void:
		var c: Color = Ent.ORB_COL[kind][0]
		var dot: Texture2D = G.game.dot
		var q = Ent.sp(x, y, z); var rr = r * G.game.view.ppx
		ci.draw_texture_rect(dot, Rect2(q.x - rr * 2.2, q.y - rr * 2.2, rr * 4.4, rr * 4.4), false, c)
		ci.draw_texture_rect(dot, Rect2(q.x - rr, q.y - rr, rr * 2, rr * 2), false, Color(1, 1, 1, 0.9))

class Hazard:
	var x: float; var y: float; var r: float
	var t = 0.0
	var warn = 0.8
	var life = 0.25
	var dmg = 10.0
	var color = Color("#ff5050")
	var kind = "slam"
	var tick = 0.0
	var fired = false
	var dead = false
	var owner = "enemy"
	func _init(px, py, pr, o := {}) -> void:
		x = px; y = py; r = pr
		warn = o.get("warn", 0.8); life = o.get("life", 0.25); dmg = o.get("dmg", 10.0)
		color = o.get("color", Color("#ff5050")); kind = o.get("kind", "slam")
	func update(dt: float) -> void:
		t += dt
		var p = G.game.player
		var fx: Fx = G.game.fx
		if t >= warn:
			if not fired:
				fired = true
				if kind == "slam":
					fx.ring(x, y, r * 0.3, r, 0.35, Color("#ffd0a0"), 4); fx.screen_shake(6); Ent.sfx("slam")
					fx.burst(x, y, 14, {"speed": 160, "up": 120, "color": Color("#8a7a6a"), "life": 0.6, "size": 3.0})
			tick -= dt
			if Vector2(p.x - x, (p.y - y) / 0.62).length() < r and tick <= 0:
				if p.hurt(dmg, x, y): tick = 0.6
			if kind == "cloud" and randf() < 0.3: fx.smoke(x + (randf() - 0.5) * r, y + (randf() - 0.5) * r * 0.5, 1, Color("#5aff3a"))
		if t > warn + life: dead = true
	func draw_ground(ci: CanvasItem) -> void:
		var k = min(1.0, t / warn)
		var c = color
		if t < warn:
			c.a = 0.15 + 0.15 * sin(t * 20)
			Fx.gellipse(ci, Vector2(x, y), r, r * 0.62, c)
			c.a = 0.6
			Fx.gellipse(ci, Vector2(x, y), r * k, r * k * 0.62, c, false, 2)
		elif kind == "cloud":
			c.a = 0.35 * min(1.0, (warn + life - t) / 0.5)
			Fx.gellipse(ci, Vector2(x, y), r, r * 0.62, c)

# ---------- yokai ----------
class Enemy extends Actor:
	var type: String
	var def: Dictionary
	var max_hp = 1
	var hp = 1.0
	var atk_v = 1.0
	var lvl = 1
	var home = Vector2.ZERO
	var zone = null
	var state = "idle"
	var state_t = 0.0
	var wander_t = 0.0
	var wa = 0.0
	var sprite = ""
	var aura = 0.0
	var spawn_t = 0.6
	var cool = 1.0
	var did_hit = false
	var souled = false
	var invuln = false
	var kneeling = false
	var calm = false
	var ult_vulnerable = false
	var illusion = false
	var summoned = false
	var spawn_key = null
	var on_defeat: Callable
	# boss scratch state
	var step = 0
	var last_move = ""
	var flagged = {}
	var tx = 0.0
	var ty = 0.0
	var dash_a = 0.0

	func _init(t: String, px: float, py: float, o := {}) -> void:
		type = t; def = Ent.ENEMIES[t].duplicate(); x = px; y = py
		lvl = o.get("level", 1)
		max_hp = int(round(def.hp * (1 + (lvl - 1) * 0.25) * (1.6 if def.get("boss", false) else 1.0))); hp = max_hp
		atk_v = def.atk * (1 + (lvl - 1) * 0.15) * 1.2
		r = def.r; home = Vector2(px, py); zone = o.get("zone"); state_t = randf()
		sprite = t; aura = randf() * 6; cool = 0.5 + randf()

	func fx() -> Fx: return G.game.fx
	func p(): return G.game.player
	func dist() -> float: return dist_to(G.game.player)
	func ang_to() -> float: return atan2(G.game.player.y - y, G.game.player.x - x)

	func damage(d: float, kx: float, ky: float, ult := false) -> void:
		if dead or state == "kneel" or invuln: return
		var n: int = max(1, int(round(d * (0.9 + randf() * 0.2))))
		hp -= n; flash = 1
		var kb = 0.15 if def.get("boss", false) else 1.0
		kbx += kx * kb; kby += ky * kb
		fx().hit(x, y - (60 if def.get("boss", false) else 20))
		fx().text(x + (randf() - 0.5) * 20, y - (120 if def.get("boss", false) else 70), str(n), Color("#ffe9a8") if ult else Color.WHITE, 22 if ult else 15)
		Ent.sfx("hit")
		if state == "idle" or state == "wander": state = "chase"
		if not def.get("boss", false) and state == "windup" and n > max_hp * 0.25: state = "recover"; state_t = 0
		if hp <= 0:
			hp = 0; purify_start()

	func purify_start() -> void:
		if def.get("boss", false) and on_defeat.is_valid(): on_defeat.call(); return
		state = "kneel"; state_t = 0
		Ent.sfx("purify")
		G.game.on_purify(self)

	func update(dt: float) -> void:
		anim_t += dt; state_t += dt; flash = max(0.0, flash - dt * 6); aura += dt
		spawn_t = max(0.0, spawn_t - dt)
		apply_knock(dt)
		if kneeling:
			state_t = min(state_t, 0.9); flash = 0; return
		if state == "kneel":
			if randf() < 0.5 and state_t < 1.0: fx().smoke(x, y - 20, 1)
			if state_t > 1.0 and not souled:
				souled = true; fx().soul(x, y); fx().circle(x, y, 40, Color("#9fe0ff"), 0.9); fx().ring(x, y, 5, 50, 0.6, Color("#9fe0ff"), 2)
			if state_t > 1.6: dead = true
			return
		if G.game.frozen or spawn_t > 0: return
		if def.ai == "boss": Boss.update(self, dt); return
		var pl = p(); var d = dist()
		var alive: bool = pl.state != "dead"
		cool -= dt
		match state:
			"idle", "wander":
				if alive and d < 240: state = "chase"; return
				wander_t -= dt
				if wander_t <= 0:
					wander_t = 1.5 + randf() * 2; wa = randf() * TAU; state = "wander" if randf() < 0.5 else "idle"
				if state == "wander":
					var h = home - Vector2(x, y)
					walk(h.angle() if h.length() > 90 else wa, def.spd * 0.4, dt)
				else: set_anim("idle")
			"chase":
				if not alive or home.distance_to(Vector2(x, y)) > 520: state = "return"; return
				var a = ang_to()
				if def.ai == "ranged":
					if d < 140: walk(a + PI, def.spd, dt)
					elif d > 230: walk(a, def.spd, dt)
					else: walk(a + PI / 2, def.spd * 0.5, dt); face_to(a)
					if d < 280 and cool <= 0: windup()
				else:
					if d > def.range * 0.8: walk(a + sep(), def.spd, dt)
					else: face_to(a); set_anim("idle")
					if d < def.range and cool <= 0: windup()
			"return":
				walk((home - Vector2(x, y)).angle(), def.spd, dt)
				hp = min(float(max_hp), hp + dt * 20)
				if home.distance_to(Vector2(x, y)) < 20: state = "idle"
				if alive and d < 160: state = "chase"
			"windup":
				var wt = {"slam": 0.75, "heavy": 0.55, "lunge": 0.5}.get(def.ai, 0.42) as float
				set_anim("idle")
				if def.ai != "slam": face_to(ang_to())
				if state_t >= wt: state = "strike"; state_t = 0; set_anim("attack")
			"strike":
				match def.ai:
					"lunge", "melee":
						var sp = 420.0 if def.ai == "lunge" else 200.0
						var dur = 0.26 if def.ai == "lunge" else 0.16
						if state_t < dur:
							G.world.move_circle(self, cos(face) * sp * dt, sin(face) * sp * dt)
							if not did_hit and d < r + pl.r + 16: did_hit = true; pl.hurt(atk_v, x, y)
						else: recover()
					"heavy":
						if not did_hit and state_t > 0.06:
							did_hit = true
							if d < 64 + pl.r and abs(G.angdiff(face, ang_to())) < 1.3: pl.hurt(atk_v * 1.3, x, y)
							fx().burst(x + cos(face) * 40, y + sin(face) * 26, 8, {"color": Color("#d9c4a0"), "speed": 90.0, "life": 0.4})
						if state_t > 0.25: recover()
					"ranged":
						if not did_hit:
							did_hit = true
							var a = ang_to()
							G.game.projectiles.append(Ent.Orb.new(x, y, cos(a) * 170, sin(a) * 170, atk_v, "shadow", {"homing": 0.8}))
							Ent.sfx("fire")
						if state_t > 0.2: recover()
					"slam":
						if state_t > 0.75: recover()
			"recover":
				set_anim("idle")
				if state_t > (0.9 if def.ai == "slam" else 0.6): state = "chase"

	func sep() -> float:
		var s = 0.0
		for o in G.game.enemies:
			if o == self or o.dead: continue
			var d = dist_to(o)
			if d < 40 and d > 0: s += 0.4 if G.angdiff(ang_to(), atan2(y - o.y, x - o.x)) > 0 else -0.4
		return clampf(s, -0.9, 0.9)

	func walk(a: float, sp: float, dt: float) -> void:
		face_to(a)
		var o = Vector2(x, y)
		G.world.move_circle(self, cos(a) * sp * dt, sin(a) * sp * dt)
		if o.distance_to(Vector2(x, y)) < sp * dt * 0.2:
			G.world.move_circle(self, cos(a + 1.4) * sp * dt, sin(a + 1.4) * sp * dt)
		set_anim("walk")

	func windup() -> void:
		state = "windup"; state_t = 0; did_hit = false; Ent.sfx("tell")
		if def.ai == "slam":
			G.game.hazards.append(Ent.Hazard.new(x + cos(ang_to()) * 30, y + sin(ang_to()) * 20, 74, {"warn": 0.75, "dmg": atk_v * 1.2}))

	func recover() -> void:
		state = "recover"; state_t = 0; cool = 0.8 + randf() * 0.8

	func draw3d() -> void:
		var k = state_t if state == "kneel" else 0.0
		var tell = state == "windup" and int(state_t * 14) % 2 == 0
		var an = anim; var fps = 9.0; var loop = true
		if state == "strike": an = "attack"; fps = 14; loop = false
		if state == "kneel" or kneeling: an = "kneel" if Assets.has_anim(sprite, "kneel") else "idle"
		var fl: float = (sin(aura * 2.5) * 4 + 8) if def.get("float", false) else 0.0
		var squash = (1 - min(0.28, k * 0.5)) if state == "kneel" else (1 - spawn_t if spawn_t > 0 else 1.0)
		var a = alpha * (max(0.0, 1 - max(0.0, k - 0.9) * 1.6) if state == "kneel" else (1 - min(1.0, spawn_t) if spawn_t > 0 else 1.0))
		Ent.draw_sprite(sprite, an, dir, anim_t, x, y, {"fps": fps, "loop": loop, "flash": max(flash, 0.55 if tell else 0.0), "squash": squash, "z": fl, "alpha": a, "dark": 0.0 if state == "kneel" or calm else 0.15})
		if state == "kneel" and k < 1:
			Ent.draw_sprite(sprite, an, dir, anim_t, x, y, {"flash": 1.0, "squash": squash, "alpha": sin(k * PI) * 0.7, "z": fl})

	func draw(ci: CanvasItem) -> void:
		var fl: float = (sin(aura * 2.5) * 4 + 8) if def.get("float", false) else 0.0
		if not def.get("boss", false) and hp < max_hp and state != "kneel":
			var q = Ent.sp(x, y, Ent.head_y(sprite) + 10 + fl)
			var w = 30.0
			ci.draw_rect(Rect2(q.x - w / 2 - 1, q.y - 1, w + 2, 5), Color(0, 0, 0, 0.6))
			ci.draw_rect(Rect2(q.x - w / 2, q.y, w * hp / max_hp, 3), Color("#e04848"))
	func draw_glow(ci: CanvasItem) -> void:
		if state == "kneel" or calm or kneeling: return
		var boss: bool = def.get("boss", false)
		var rad = (90.0 if boss else 40.0) * G.game.view.ppx
		var q = Ent.sp(x, y, 20)
		ci.draw_texture_rect(G.game.dot, Rect2(q.x - rad, q.y - rad * 0.8, rad * 2, rad * 1.6), false, Color(0.55, 0.24, 1.0, 0.16 + sin(aura * 3) * 0.05))

# ---------- NPC ----------
class Npc extends Actor:
	var id: String
	var sprite: String
	var name: String
	var dir_home: String
	var visible_if: Callable
	func _init(i: String, s: String, px: float, py: float, n: String, d: String, vis: Callable) -> void:
		id = i; sprite = s; x = px; y = py; name = n; dir_home = d; dir = d; visible_if = vis; r = 12
	func update(dt: float) -> void:
		anim_t += dt
		var p = G.game.player
		if dist_to(p) < 110: face_to(atan2(p.y - y, p.x - x))
		else: dir = dir_home
	func draw3d() -> void:
		Ent.draw_sprite(sprite, "idle", dir, anim_t, x, y, {"alpha": alpha})
	func draw(ci: CanvasItem) -> void:
		if id == "dog": return
		var f: Font = Assets.font_bold
		var q = Ent.sp(x, y, Ent.head_y(sprite) + 8)
		var w = f.get_string_size(name, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x + 12
		ci.draw_rect(Rect2(q.x - w / 2, q.y - 12, w, 16), Color(0.16, 0.09, 0.27, 0.72))
		ci.draw_string(f, Vector2(q.x - w / 2 + 6, q.y), name, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("#efe4ff"))

# ---------- pickups ----------
class Coin:
	var x: float; var y: float; var v: int
	var vx: float; var vy: float
	var z = 10.0
	var vz: float
	var t = 0.0
	var dead = false
	func _init(px, py, pv) -> void:
		x = px; y = py; v = pv
		var a = randf() * TAU; var s = 40 + randf() * 80
		vx = cos(a) * s; vy = sin(a) * s * 0.6; vz = 120 + randf() * 80
	func update(dt: float) -> void:
		t += dt
		vz -= 500 * dt; z += vz * dt
		if z < 0: z = 0; vz *= -0.4; vx *= 0.5; vy *= 0.5
		x += vx * dt; y += vy * dt
		var p = G.game.player
		var d = Vector2(p.x - x, p.y - y).length()
		if t > 0.5 and d < 120:
			var a = atan2(p.y - y, p.x - x); x += cos(a) * 360 * dt; y += sin(a) * 360 * dt
		if t > 0.4 and d < 20: dead = true; p.coins += v; Ent.sfx("coin")
		if t > 30: dead = true
	func draw(ci: CanvasItem) -> void:
		Fx.gellipse(ci, Vector2(x, y), 5, 3, Color(0, 0, 0.04, 0.3))
		var w: float = max(1.0, abs(cos(t * 6)) * 4)
		var q = Ent.sp(x, y, z + 4)
		ci.draw_rect(Rect2(q.x - w - 1, q.y - 5, w * 2 + 2, 10), Color("#7a5a10"))
		ci.draw_rect(Rect2(q.x - w, q.y - 4, w * 2, 8), Color("#ffd25a"))
