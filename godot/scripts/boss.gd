# Boss patterns. Every attack is telegraphed (ground marks, flashes); a defeated boss kneels instead of dying.
class_name Boss
extends RefCounted

static func update(b, dt: float) -> void:
	b.cool -= dt
	if b.state in ["idle", "wander", "chase"]: b.state = "move"
	match b.type:
		"dokchief": dokchief(b, dt)
		"gumiho": gumiho(b, dt)
		"imugi": imugi(b, dt)
		"yeoksin": yeoksin(b, dt)

static func chase_to(b, dt: float, min_d: float, mul := 1.0) -> void:
	if b.dist() > min_d: b.walk(b.ang_to(), b.def.spd * mul, dt)
	else: b.face_to(b.ang_to()); b.set_anim("idle")

# weighted pick of the next move, avoiding a repeat
static func pick(b, opts: Array) -> String:
	var list = opts.filter(func(o): return o[0] != b.last_move or opts.size() == 1)
	var total = 0.0
	for o in list: total += o[1]
	var s = randf() * total
	for o in list:
		s -= o[1]
		if s <= 0: b.last_move = o[0]; return o[0]
	b.last_move = list[0][0]
	return list[0][0]

static func begin(b, move: String) -> void:
	b.state = move; b.state_t = 0; b.step = 0; Sfx.sfx("tell")

static func phase2(b) -> bool: return b.hp < b.max_hp * 0.5

static func hazard(x, y, r, o := {}) -> void:
	G.game.hazards.append(Ent.Hazard.new(x, y, r, o))

static func orb(x, y, a, sp, dmg, kind, o := {}) -> void:
	G.game.projectiles.append(Ent.Orb.new(x, y, cos(a) * sp, sin(a) * sp, dmg, kind, o))

# 도깨비 대장: club swing, ground slam rings, charge, summons imps at half health
static func dokchief(b, dt: float) -> void:
	var p = G.game.player; var d: float = b.dist(); var fx: Fx = G.game.fx
	match b.state:
		"move":
			chase_to(b, dt, 70)
			if phase2(b) and not b.flagged.has("summon"): b.flagged.summon = true; begin(b, "summon"); return
			if b.cool <= 0: begin(b, pick(b, [["swing", 3], ["slam", 2]]) if d < 110 else pick(b, [["charge", 3], ["slam", 2], ["swing", 1]]))
		"swing":
			b.set_anim("idle")
			if b.state_t < 0.5: b.face_to(b.ang_to())
			if b.state_t > 0.55 and b.step == 0:
				b.step = 1; b.set_anim("attack"); b.anim_t = 0; Sfx.sfx("slam")
				if d < 130 and abs(G.angdiff(b.face, b.ang_to())) < 1.4: p.hurt(b.atk_v * 1.3, b.x, b.y)
				fx.screen_shake(5)
				fx.burst(b.x + cos(b.face) * 80, b.y + sin(b.face) * 50, 16, {"color": Color("#d9c4a0"), "speed": 160.0, "life": 0.5})
			if b.state_t > 1.1: b.state = "move"; b.cool = 0.6 if phase2(b) else 1.1
		"slam":
			b.set_anim("idle")
			var n = 3 if phase2(b) else 2
			if b.step < n and b.state_t > 0.2 + b.step * 0.5:
				hazard(b.x, b.y, 90 + b.step * 70, {"warn": 0.8, "dmg": b.atk_v, "color": Color("#ff8040")})
				b.step += 1
			if b.state_t > 0.2 + n * 0.5 + 0.9: b.state = "move"; b.cool = 1.2
		"charge":
			if b.state_t < 0.7:
				b.face_to(b.ang_to()); b.set_anim("idle")
				if randf() < 0.4: fx.add({"x": b.x, "y": b.y, "z": 4.0, "vz": 30.0, "vx": (randf() - 0.5) * 60, "life": 0.4, "size": 4.0, "color": Color("#a08a6a"), "g": 100.0})
			elif b.state_t < 1.4:
				b.walk(b.face, 380, dt)
				if b.step == 0 and d < b.r + p.r + 20: b.step = 1; p.hurt(b.atk_v * 1.2, b.x, b.y)
			else: b.state = "move"; b.cool = 1.0
		"summon":
			b.set_anim("attack")
			if b.state_t > 0.5 and b.step == 0:
				b.step = 1; Sfx.sfx("roar"); fx.screen_shake(8)
				for i in 3:
					var a = i / 3.0 * TAU
					G.game.spawn_enemy("imp", b.x + cos(a) * 110, b.y + sin(a) * 70, {"level": 2, "summoned": true})
			if b.state_t > 1.2: b.state = "move"; b.cool = 1

# 구미호: fox-fire volleys, dash slashes, fire rings, illusion copies at half health
static func gumiho(b, dt: float) -> void:
	var p = G.game.player; var d: float = b.dist(); var fx: Fx = G.game.fx
	match b.state:
		"move":
			var a: float = b.ang_to()
			if d < 150: b.walk(a + PI * 0.75, b.def.spd, dt)
			elif d > 280: b.walk(a, b.def.spd, dt)
			else: b.walk(a + PI / 2, b.def.spd * 0.6, dt)
			if phase2(b) and not b.flagged.has("clone"): b.flagged.clone = true; begin(b, "clone"); return
			if b.cool <= 0: begin(b, pick(b, [["volley", 3], ["dash", 2], ["ring", 2 if phase2(b) else 1]]))
		"volley":
			b.face_to(b.ang_to()); b.set_anim("attack")
			var n = 3 if phase2(b) else 2
			if b.step < n and b.state_t > 0.45 + b.step * 0.45:
				b.step += 1; Sfx.sfx("fire")
				var base: float = b.ang_to(); var k = 7 if phase2(b) else 5
				for i in k: orb(b.x, b.y - 10, base + (i - (k - 1) / 2.0) * 0.2, 190, b.atk_v * 0.8, "fire", {"homing": 0.6})
			if b.state_t > 0.45 + n * 0.45 + 0.4: b.state = "move"; b.cool = 1.2
		"dash":
			if b.state_t < 0.55: b.face_to(b.ang_to()); b.set_anim("idle"); b.dash_a = b.face
			elif b.state_t < 0.95:
				b.walk(b.dash_a, 520, dt); b.set_anim("attack")
				if b.step == 0 and d < b.r + p.r + 24: b.step = 1; p.hurt(b.atk_v * 1.1, b.x, b.y)
				fx.add({"x": b.x, "y": b.y, "z": 20.0, "life": 0.3, "size": 4.0, "color": Color("#9fe0ff"), "glow": true})
			else: b.state = "move"; b.cool = 0.9
		"ring":
			b.set_anim("attack")
			if b.state_t > 0.6 and b.step == 0:
				b.step = 1; Sfx.sfx("fire")
				for i in 14: orb(b.x, b.y - 10, i / 14.0 * TAU, 150, b.atk_v * 0.8, "fire", {"life": 3.5})
			if b.state_t > 1.3: b.state = "move"; b.cool = 1.3
		"clone":
			b.set_anim("attack"); b.invuln = true
			if b.state_t > 0.6 and b.step == 0:
				b.step = 1; Sfx.sfx("roar"); fx.screen_flash(0.4, Color("#9fe0ff"))
				for i in 2:
					var a = randf() * TAU
					var c = G.game.spawn_enemy("gumiho", b.x + cos(a) * 160, b.y + sin(a) * 100, {"level": 1, "summoned": true})
					c.max_hp = 60; c.hp = 60; c.illusion = true
					c.def = c.def.duplicate(); c.def.boss = false; c.def.name = "여우 환영"; c.def.exp = 5; c.def.coin = [1, 2]; c.def.ai = "ranged"; c.def.range = 210
					c.atk_v = b.atk_v * 0.6; c.r = 18; c.alpha = 0.6
			if b.state_t > 1.0: b.invuln = false; b.state = "move"; b.cool = 0.8

# 이무기: water spit, tail sweep, dive and resurface, rain of water, snakes at half health
static func imugi(b, dt: float) -> void:
	var p = G.game.player; var d: float = b.dist(); var fx: Fx = G.game.fx
	match b.state:
		"move":
			chase_to(b, dt, 140)
			if phase2(b) and not b.flagged.has("summon"): b.flagged.summon = true; begin(b, "summon"); return
			if b.cool <= 0: begin(b, pick(b, [["sweep", 3], ["dive", 1]]) if d < 140 else pick(b, [["spit", 3], ["dive", 2], ["rain", 2 if phase2(b) else 1]]))
		"spit":
			b.face_to(b.ang_to()); b.set_anim("attack")
			var n = 5 if phase2(b) else 4
			if b.step < n and b.state_t > 0.5 + b.step * 0.22:
				b.step += 1; Sfx.sfx("fire")
				orb(b.x, b.y - 20, b.ang_to() + (randf() - 0.5) * 0.25, 260, b.atk_v * 0.8, "water", {"r": 11.0, "life": 2.5})
			if b.state_t > 0.5 + n * 0.22 + 0.5: b.state = "move"; b.cool = 1.2
		"sweep":
			b.set_anim("idle")
			if b.step == 0: b.step = 1; hazard(b.x, b.y, 150, {"warn": 0.9, "dmg": b.atk_v * 1.2, "color": Color("#40a0ff")})
			if b.state_t > 0.9 and b.step == 1: b.step = 2; b.set_anim("attack"); b.anim_t = 0
			if b.state_t > 1.6: b.state = "move"; b.cool = 1.0
		"dive":
			if b.state_t < 0.6:
				b.alpha = 1 - b.state_t / 0.6
				if randf() < 0.6: fx.burst(b.x, b.y, 2, {"color": Color("#7fc8ff"), "speed": 80.0, "up": 120.0, "life": 0.6})
			elif b.state_t < 1.4:
				b.alpha = 0; b.invuln = true
				if b.step == 0:
					b.step = 1
					var a = randf() * TAU
					b.tx = p.x + cos(a) * 60; b.ty = p.y + sin(a) * 40
					if G.world.blocked(b.tx, b.ty, b.r): b.tx = p.x; b.ty = p.y
					hazard(b.tx, b.ty, 110, {"warn": 0.8, "dmg": b.atk_v * 1.3, "color": Color("#40a0ff")})
			elif b.step == 1:
				b.step = 2; b.x = b.tx; b.y = b.ty; b.alpha = 1; b.invuln = false
				fx.burst(b.x, b.y, 30, {"color": Color("#9fd8ff"), "speed": 200.0, "up": 260.0, "life": 0.8, "size": 3.0}); fx.screen_shake(8); Sfx.sfx("roar")
			elif b.state_t > 2.0: b.state = "move"; b.cool = 1.0
		"rain":
			b.set_anim("attack")
			if b.step < 6 and b.state_t > 0.4 + b.step * 0.25:
				b.step += 1
				hazard(p.x + (randf() - 0.5) * 120, p.y + (randf() - 0.5) * 80, 54, {"warn": 0.8, "dmg": b.atk_v * 0.8, "color": Color("#40a0ff")})
			if b.state_t > 2.4: b.state = "move"; b.cool = 1.2
		"summon":
			b.set_anim("attack")
			if b.state_t > 0.5 and b.step == 0:
				b.step = 1; Sfx.sfx("roar")
				for i in 3:
					var a = i / 3.0 * TAU + 0.5
					G.game.spawn_enemy("snake", b.x + cos(a) * 140, b.y + sin(a) * 90 + 40, {"level": 3, "summoned": true})
			if b.state_t > 1.2: b.state = "move"; b.cool = 1

static func ghosts() -> int:
	var n = 0
	for e in G.game.enemies:
		if e.type == "ghost" and not e.dead and e.state != "kneel": n += 1
	return n

# 역신: plague clouds, shadow bolts, ghost summons, blinks. At 30% the song completes (story) and only 처용가 ends it.
static func yeoksin(b, dt: float) -> void:
	var p = G.game.player; var d: float = b.dist(); var fx: Fx = G.game.fx
	if not b.flagged.has("turned") and b.hp <= b.max_hp * 0.3:
		b.flagged.turned = true; b.hp = ceil(b.max_hp * 0.3); b.invuln = true; b.state = "hold"; b.state_t = 0
		for h in G.game.hazards: h.dead = true
		for pr in G.game.projectiles:
			if pr.owner == "enemy": pr.dead = true
		G.game.story.yeoksin_turn(b)
		return
	if b.ult_vulnerable:
		b.invuln = false
		b.hp = max(b.hp, ceil(b.max_hp * 0.05))
	match b.state:
		"hold":
			b.set_anim("idle")
			if b.ult_vulnerable: b.state = "move"; b.cool = 1.5
		"move":
			var a: float = b.ang_to()
			if d < 160: b.walk(a + PI * 0.8, b.def.spd, dt)
			elif d > 300: b.walk(a, b.def.spd, dt)
			else: b.walk(a - PI / 2, b.def.spd * 0.5, dt)
			if b.cool <= 0: begin(b, pick(b, [["bolts", 3], ["cloud", 3], ["blink", 2], ["summon", 2 if ghosts() < 2 else 0.01]]))
		"bolts":
			b.face_to(b.ang_to()); b.set_anim("attack")
			var n = 2 if b.ult_vulnerable else 4
			if b.step < n and b.state_t > 0.5 + b.step * 0.3:
				b.step += 1; Sfx.sfx("fire")
				for off in [-0.35, 0.0, 0.35]: orb(b.x, b.y - 30, b.ang_to() + off, 200, b.atk_v * 0.75, "shadow", {"homing": 0.4})
			if b.state_t > 0.5 + n * 0.3 + 0.4: b.state = "move"; b.cool = 1.1
		"cloud":
			b.set_anim("attack")
			if b.step < 3 and b.state_t > 0.4 + b.step * 0.35:
				b.step += 1
				hazard(p.x + (randf() - 0.5) * 140, p.y + (randf() - 0.5) * 90, 70, {"warn": 0.9, "life": 3.2, "dmg": b.atk_v * 0.5, "color": Color("#5aff3a"), "kind": "cloud"})
			if b.state_t > 1.8: b.state = "move"; b.cool = 1.2
		"blink":
			if b.state_t < 0.4: b.alpha = 1 - b.state_t / 0.4; fx.smoke(b.x, b.y - 30, 1, Color("#5a2a8a"))
			elif b.step == 0:
				b.step = 1
				var ar = G.game.arena
				var a = randf() * TAU; var rr = 120 + randf() * 120
				var nx: float = ar.x + cos(a) * rr; var ny: float = ar.y + sin(a) * rr * 0.6
				if G.world.blocked(nx, ny, b.r): nx = ar.x; ny = ar.y
				b.x = nx; b.y = ny
			elif b.state_t < 0.8: b.alpha = (b.state_t - 0.4) / 0.4
			else: b.alpha = 1; b.state = "move"; b.cool = 0.4
		"summon":
			b.set_anim("attack")
			if b.state_t > 0.6 and b.step == 0:
				b.step = 1; Sfx.sfx("roar")
				for i in 2:
					var a = randf() * TAU
					G.game.spawn_enemy("ghost", b.x + cos(a) * 120, b.y + sin(a) * 80, {"level": 4, "summoned": true})
			if b.state_t > 1.2: b.state = "move"; b.cool = 1.2
