# Game: world state, spawning, bosses, cutscenes, saving, and the world layers (2.5D y-sort + dusk lighting).
extends Node

signal dialog_done

const T := 32
const SAVE_PATH := "user://save.json"
const CHECKPOINTS := {"beach": [100, 70], "town": [61, 53], "ruin": [90, 36], "pond": [61, 25], "forest": [36, 57], "house": [24, 33]}
const GATE_DIM := Color(0.47, 0.17, 1.0)

var world: World
var fx = Fx.new()
var story: Story
var ui
var player
var flags = {}
var enemies = []
var npcs = []
var projectiles = []
var hazards = []
var pickups = []
var time = 0.0
var hitstop = 0.0
var frozen = false
var cinema = false
var cinema_t = 0.0
var cam = Vector2.ZERO
var cam_focus = null
var cam_pan_speed = 2.0
var arena = null
var boss = null
var zone = null
var zone_banner = null
var spawn_dead = {}
var music_stack = []
var interact_target = null
var death_t = null
var spawn_tick = 0.0
var music_switch_t = 0.0
var attack_hits = 0
var rolled = false
var ult_used = false
var dot: Texture2D
var dissolved = {}

# nodes
var camera: Camera2D
var world_root: Node2D
var light_rect: ColorRect
var light_mat: ShaderMaterial
var overlay  # draw layer on the light canvas (screen flash, death fade)

func _ready() -> void:
	G.game = self
	world = World.new()
	world.flags = flags
	G.world = world
	world.init()
	story = Story.new(self)
	dot = _make_dot()
	_build_nodes()

func _make_dot() -> Texture2D:
	var gt = GradientTexture2D.new()
	gt.width = 64; gt.height = 64
	gt.fill = GradientTexture2D.FILL_RADIAL
	gt.fill_from = Vector2(0.5, 0.5); gt.fill_to = Vector2(1.0, 0.5)
	var gr = Gradient.new()
	gr.set_color(0, Color(1, 1, 1, 1)); gr.set_color(1, Color(1, 1, 1, 0))
	gr.add_point(0.4, Color(1, 1, 1, 0.45))
	gt.gradient = gr
	return gt

func _layer(parent: Node, fn: Callable, add := false) -> Node2D:
	var n = Node2D.new()
	n.set_script(load("res://scripts/draw_layer.gd"))
	n.fn = fn
	if add:
		var m = CanvasItemMaterial.new(); m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		n.material = m
	parent.add_child(n)
	return n

func _build_nodes() -> void:
	world_root = Node2D.new()
	add_child(world_root)
	world_root.add_child(world.build_tilemap())
	_layer(world_root, _draw_water)
	_layer(world_root, _draw_flat)
	_layer(world_root, _draw_ground_add, true)
	_layer(world_root, _draw_sprites)
	_layer(world_root, func(ci): fx.draw_parts(ci, false, dot))
	_layer(world_root, _draw_glow_add, true)
	_layer(world_root, func(ci): fx.draw_texts(ci, Assets.font_dmg))
	_layer(world_root, _draw_guide)
	camera = Camera2D.new()
	camera.anchor_mode = Camera2D.ANCHOR_MODE_FIXED_TOP_LEFT
	world_root.add_child(camera)
	camera.make_current()
	var lc = CanvasLayer.new(); lc.layer = 5
	add_child(lc)
	light_rect = ColorRect.new()
	light_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	light_mat = ShaderMaterial.new(); light_mat.shader = load("res://shaders/light.gdshader")
	light_rect.material = light_mat
	lc.add_child(light_rect)
	overlay = _layer(lc, _draw_overlay)
	var uc = CanvasLayer.new(); uc.layer = 10
	add_child(uc)
	ui = Control.new()
	ui.set_script(load("res://scripts/ui.gd"))
	ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.g = self
	uc.add_child(ui)

# ---------- lifecycle ----------
func new_game() -> void:
	flags.clear()
	player = Ent.Player.new(100 * T, 70.5 * T)
	player.face_to(0)
	reset()

func reset() -> void:
	enemies = []; projectiles = []; hazards = []; pickups = []
	arena = null; boss = null; frozen = false; cinema = false; zone = null; spawn_dead = {}; music_stack = []; death_t = null
	ui.dialog = null; ui.shop = null; ui.menu = false; ui.banner = null
	fx.clear()
	dissolved = {}
	build_npcs()
	snap_cam()

func has_save() -> bool: return FileAccess.file_exists(SAVE_PATH)

func save_game() -> void:
	var p = player
	var data = {"flags": flags, "p": {"x": p.x, "y": p.y, "lvl": p.lvl, "xp": p.xp, "coins": p.coins, "hp": p.hp, "max_hp": p.max_hp,
		"max_gi": p.max_gi, "items": p.items, "masks": p.masks, "mask": p.mask, "skills": p.skills}}
	var f = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f: f.store_string(JSON.stringify(data))

func load_game() -> void:
	var f = FileAccess.open(SAVE_PATH, FileAccess.READ)
	var data = JSON.parse_string(f.get_as_text()) if f else null
	if data == null: new_game(); return
	flags.clear(); flags.merge(data.flags)
	var d: Dictionary = data.p
	player = Ent.Player.new(d.x, d.y)
	for k in ["lvl", "coins", "max_hp", "max_gi"]: player.set(k, int(d[k]))
	for k in ["xp", "hp"]: player.set(k, float(d[k]))
	player.items = {"yakgwa": int(d.items.yakgwa), "sikhye": int(d.items.sikhye)}
	player.masks = d.masks; player.mask = d.mask; player.skills = d.skills
	player.gi = player.max_gi
	if flags.get("yeoksin_started", false) and not flags.get("yeoksin_done", false):
		flags.yeoksin_started = false; player.x = 40 * T; player.y = 31 * T
	reset()

# command-line / URL test hooks: quest=n flags=a,b at=x,y lvl=n heung
func apply_debug() -> void:
	var p = player; var f = flags
	var q = int(G.param("quest", "0"))
	if q >= 1: f.q1 = true; f.has_attack = true; p.masks = ["cheoyong"]; p.mask = "cheoyong"; f.verse1 = true
	if q >= 2: f.kills_beach = 6; f.q2 = true; f.gate_open = true; f.has_ult = true; p.skills.skill1 = true
	if q >= 3: f.king_event = true; f.king_met = true
	if q >= 4: f.q3 = true; f.paths_open = true
	if q >= 5:
		f.kills_ruin = 6; f.kills_forest = 6; f.kills_pond = 6; f.kills_total = 20
		f.boss_dok = true; f.boss_fox = true; f.boss_imugi = true; f.dosa_done = true
		p.skills.skill2 = true; p.skills.skill3 = true; p.masks = ["cheoyong", "gwimyeon", "yongwang"]
		for i in [2, 3, 4, 5]: f["verse%d" % i] = true
		p.lvl = 8; p.max_hp = 200; p.hp = 200; p.max_gi = 130
	if q >= 6: f.q4 = true; f.q5 = true; f.house_open = true; f.verse6 = true
	if G.param("flags") != "":
		for k in G.param("flags").split(","): f[k] = true
	if G.param("at") != "":
		var a = G.param("at").split(","); p.x = float(a[0]) * T; p.y = float(a[1]) * T
	if G.param("lvl") != "":
		p.lvl = int(G.param("lvl")); p.max_hp = 100 + (p.lvl - 1) * 14; p.hp = p.max_hp
	if G.has("heung"): p.heung = 100.0
	build_npcs(); snap_cam()

# ---------- NPCs ----------
func build_npcs() -> void:
	npcs = []
	for s in story.NPCS:
		var vis: Callable = s[6] if s[6] is Callable else Callable()
		var n = Ent.Npc.new(s[0], s[1], s[2] * T, s[3] * T, s[4], s[5], vis)
		if s[0] == "yongwang":
			# stand ankle-deep at the waterline east of the start point
			var x = 98.0 * T
			while x < 118 * T and not world.solid_at(x, n.y): x += 8
			n.x = x + 34
		npcs.append(n)
	refresh_npcs()

func refresh_npcs() -> void:
	for n in npcs: n.hidden = (not n.visible_if.call(flags)) if n.visible_if.is_valid() else false
	var hw = npc("hwarang")
	if hw and flags.get("gate_open", false): hw.x = 69.5 * T; hw.y = 68.6 * T; hw.dir_home = "west"

func npc(id: String):
	for n in npcs:
		if n.id == id: return n
	return null

# ---------- spawning ----------
func spawn_enemy(type: String, x: float, y: float, o := {}):
	var e = Ent.Enemy.new(type, x, y, o)
	e.spawn_key = o.get("key"); e.summoned = o.get("summoned", false)
	if world.blocked(x, y, e.r): e.x = player.x + (randf() - 0.5) * 60; e.y = player.y + (randf() - 0.5) * 40
	enemies.append(e)
	fx.smoke(e.x, e.y, 6, Color("#6a2aff"))
	return e

func spawn_zone(zid: String) -> void:
	if not story.SPAWNS.has(zid): return
	if zid == "house" and (not flags.get("house_open", false) or flags.get("yeoksin_done", false)): return
	if zid == "beach" and not flags.get("q1", false): return
	var sp: Dictionary = story.SPAWNS[zid]
	for i in sp.list.size():
		var key = "%s%d" % [zid, i]
		var alive = false
		for e in enemies:
			if e.spawn_key == key and not e.dead: alive = true; break
		if alive: continue
		if spawn_dead.has(key) and time - spawn_dead[key] < 75: continue
		var s: Array = sp.list[i]
		var e = spawn_enemy(s[0], s[1] * T, s[2] * T, {"level": sp.lvl, "zone": zid, "key": key})
		e.spawn_t = 0

func despawn_far() -> void:
	enemies = enemies.filter(func(e):
		if e.dead: return false
		if e.def.get("boss", false) or e.summoned: return true
		return Vector2(e.x - player.x, e.y - player.y).length() <= 1500 or e.state == "kneel")

func on_purify(e) -> void:
	var p = player
	if e.spawn_key != null: spawn_dead[e.spawn_key] = time
	if not e.illusion:
		flags.kills_total = int(flags.get("kills_total", 0)) + 1
		if e.zone != null: flags["kills_" + e.zone] = int(flags.get("kills_" + e.zone, 0)) + 1
	p.gain_exp(e.def.exp * (1 + (e.lvl - 1) * 0.2))
	var c: Array = e.def.coin
	var n: int = c[0] + randi() % (c[1] - c[0] + 1)
	var pieces: int = min(n, 8)
	for i in pieces: pickups.append(Ent.Coin.new(e.x, e.y, int(ceil(float(n) / pieces))))
	if randf() < 0.06: p.items.yakgwa += 1; ui.toast("약과를 주웠소")
	p.add_heung(5)
	if e.zone != null and int(flags.get("kills_" + e.zone, 0)) == 6:
		if e.zone == "beach": ui.toast("개운포의 요괴를 모두 정화했소 — 용왕에게")
		elif story.BOSSES.has(e.zone): ui.toast("탁기가 한곳으로 모인다… 우두머리가 깨어났소")
		Sfx.sfx("quest")
	if flags.get("q3", false) and not flags.get("dosa_done", false) and int(flags.get("kills_total", 0)) == 12: ui.toast("도사에게 가 보시오")

func spawn_boss(type: String, x: float, y: float, z):
	var b = Ent.Enemy.new(type, x, y, {"level": 1, "zone": z})
	b.cool = 1.5
	b.on_defeat = func():
		b.kneeling = true; b.state = "kneel"; b.state_t = 0; b.invuln = true; b.calm = true
		for h in hazards: h.dead = true
		for pr in projectiles:
			if pr.owner == "enemy": pr.dead = true
		for e in enemies:
			if e != b and e.summoned and e.state != "kneel": e.state = "kneel"; e.state_t = 0
		Sfx.sfx("purify"); fx.screen_flash(0.6, Color("#e8f6ff")); fx.ring(b.x, b.y, 10, 200, 1.2, Color("#9fe0ff"), 4)
		for i in 4: fx.soul(b.x + (randf() - 0.5) * 60, b.y)
		player.gain_exp(b.def.exp)
		var c: Array = b.def.coin
		for i in 8: pickups.append(Ent.Coin.new(b.x, b.y, int(ceil((c[0] + randf() * (c[1] - c[0])) / 8.0))))
		if b.type == "yeoksin": story.yeoksin_kneel(b)
		else: story.boss_defeated(b)
	enemies.append(b)
	return b

func start_boss_fight(b, cx: float, cy: float) -> void:
	boss = b
	arena = {"x": cx, "y": cy, "r": 360.0}
	push_music("boss")

func end_boss_fight() -> void:
	arena = null
	var b = boss
	boss = null
	pop_music()
	if b is Object:
		get_tree().create_timer(6.0).timeout.connect(func(): b.dead = true)

# ---------- cutscenes ----------
func cutscene(fn: Callable, done = null) -> void:
	frozen = true; cinema = true; cinema_t = 0
	await fn.call()
	frozen = false; cinema = false; cam_focus = null
	if done is Callable: done.call()

func cutscene_say(lines: Array, done = null) -> void:
	cutscene(func(): await say_async(lines), done)

func pan(pos, dur: float) -> void:
	cam_focus = pos
	cam_pan_speed = 2.2 / max(0.2, dur)
	await get_tree().create_timer(dur).timeout

func wait(s: float) -> void:
	await get_tree().create_timer(s).timeout

func say_async(lines: Array) -> void:
	ui.say(lines, func(): dialog_done.emit())
	await dialog_done

func dissolve_gates() -> void:
	for gt in world.GATES:
		if not flags.get(gt.flag, false) or dissolved.has(gt.id): continue
		dissolved[gt.id] = true
		var c = Vector2((gt.x0 + gt.x1) / 2.0, (gt.y0 + gt.y1) / 2.0) * T
		for i in 30: fx.smoke(c.x + (randf() - 0.5) * 160, c.y + (randf() - 0.5) * 120, 1, Color("#8a4cff"))

# ---------- tutorial: exactly one glowing button ----------
func tutorial(key: String) -> void: flags["tut_" + key] = "pending"

func update_tutorial() -> void:
	var f = flags; var p = player
	var gl = null
	if interact_target and ui.dialog == null: gl = "interact"
	elif f.get("tut_attack") == "pending": gl = "attack"
	elif f.get("tut_roll") == "pending": gl = "roll"
	elif f.get("tut_skill1") == "pending" and p.gi >= 12: gl = "skill1"
	elif f.get("tut_skill2") == "pending" and p.gi >= 18: gl = "skill2"
	elif f.get("tut_skill3") == "pending" and p.gi >= 20: gl = "skill3"
	elif f.get("has_ult", false) and p.heung >= 100 and f.get("tut_ult") != "done": gl = "ult"
	elif f.get("tut_mask") == "pending": gl = "mask"
	ui.glow = gl
	if f.get("tut_attack") == "pending" and attack_hits >= 1: f.tut_attack = "done"; f.tut_roll = "pending"
	if f.get("tut_roll") == "pending" and rolled: f.tut_roll = "done"
	for k in ["skill1", "skill2", "skill3", "mask"]:
		if f.get("tut_" + k) == "pending" and Inp.hit(k): f["tut_" + k] = "done"
	if ult_used: f.tut_ult = "done"

func on_player_attack(hits: int) -> void:
	if hits > 0: attack_hits += 1

func verse_count() -> int:
	var n = 0
	for i in range(1, 9):
		if flags.get("verse%d" % i, false): n += 1
	return n

func push_music(m: String) -> void:
	music_stack.append(m); Sfx.music(m)

func pop_music() -> void:
	if music_stack.size() > 0: music_stack.pop_back()
	Sfx.music(music_stack.back() if music_stack.size() > 0 else (zone.music if zone else "sea"))

func on_player_death() -> void:
	Sfx.sfx("death")
	death_t = 0.0

func respawn() -> void:
	var p = player
	var z: String = zone.id if zone else "beach"
	var cp: Array = CHECKPOINTS.get(z, CHECKPOINTS.beach)
	if z == "town" and not flags.get("king_met", false): cp = [66, 62]
	if z == "house": cp = [40, 31]
	p.x = cp[0] * T; p.y = cp[1] * T
	p.hp = p.max_hp; p.gi = p.max_gi; p.state = "move"; p.iframe = 2; p.kbx = 0; p.kby = 0
	var lost = int(p.coins * 0.1); p.coins -= lost
	if boss is Object:
		var b = boss
		if b.type == "yeoksin": flags.yeoksin_started = false
		enemies = enemies.filter(func(e): return e != b and not e.summoned)
		boss = null; arena = null; music_stack = []
	projectiles = []; hazards = []
	death_t = null
	ui.toast("넋을 추슬렀소 (엽전 %d냥을 잃었다)" % lost if lost > 0 else "넋을 추슬렀소")
	snap_cam()
	save_game()

func start_ending() -> void:
	get_parent().set_state("ending")

# ---------- update ----------
func tick(dt: float) -> void:
	time += dt
	if cinema: cinema_t += dt
	ui.tick(dt)
	if ui.menu: ui.update_menu(); return
	if ui.shop: ui.update_shop(dt); return
	if ui.dialog or ui.banner:
		ui.update_dialog(dt)
		if ui.dialog or ui.banner:
			update_cam(dt); fx.update(dt); return
	if Inp.hit("menu") and not frozen: ui.menu = true; Sfx.sfx("ui"); return
	if hitstop > 0: hitstop -= dt; return
	var p = player
	if death_t != null:
		death_t += dt
		if death_t > 2.2: respawn()
	p.update(dt)
	var z = world.zone_at(p.x, p.y)
	if z and z != zone:
		zone = z
		zone_banner = {"name": z.name, "t": 0.0}
		if not (boss is Object): music_stack = []; Sfx.music(z.music)
		Sfx.ambient(z.amb)
		spawn_zone(z.id)
		save_game()
	if zone_banner: zone_banner.t += dt
	spawn_tick -= dt
	if spawn_tick <= 0 and zone and not boss:
		spawn_tick = 5; spawn_zone(zone.id); despawn_far()
	for n in npcs:
		if not n.hidden: n.update(dt)
	for e in enemies.duplicate(): e.update(dt)
	# body push between the player and npcs/yokai
	for e in enemies + npcs:
		if e.hidden or e.dead or e.alpha == 0: continue
		if e is Ent.Enemy and e.state == "kneel": continue
		var d = Vector2(p.x - e.x, p.y - e.y); var dl = d.length(); var m: float = p.r + e.r * 0.8
		if dl < m and dl > 0.01:
			var push = (m - dl)
			if e is Ent.Npc or e.def.get("boss", false): world.move_circle(p, d.x / dl * push, d.y / dl * push)
			else:
				world.move_circle(p, d.x / dl * push * 0.5, d.y / dl * push * 0.5)
				world.move_circle(e, -d.x / dl * push * 0.5, -d.y / dl * push * 0.5)
	enemies = enemies.filter(func(e): return not e.dead)
	for pr in projectiles: pr.update(dt)
	projectiles = projectiles.filter(func(x): return not x.dead)
	for h in hazards: h.update(dt)
	hazards = hazards.filter(func(x): return not x.dead)
	for c in pickups: c.update(dt)
	pickups = pickups.filter(func(x): return not x.dead)
	# battle music while yokai chase the player
	if not boss and zone:
		var fighting = false
		for e in enemies:
			if e.state in ["chase", "windup", "strike"] and e.dist() < 400: fighting = true; break
		var want: String = "battle" if fighting else zone.music
		if Sfx.current != want and p.state != "ult":
			music_switch_t += dt
			if music_switch_t > (0.3 if fighting else 3.0): Sfx.music(want); music_switch_t = 0
		else: music_switch_t = 0
	interact_target = null
	if not frozen and p.state == "move":
		var best = null; var bd = 84.0
		for n in npcs:
			if n.hidden: continue
			var d: float = p.dist_to(n)
			if d < bd: bd = d; best = n
		if best: interact_target = {"npc": best, "label": "사기" if best.id == "merchant" else "말걸기"}
	if interact_target and Inp.hit("interact"):
		Sfx.sfx("ui")
		story.interact(interact_target.npc)
	story.update(dt)
	update_tutorial()
	update_cam(dt)
	fx.update(dt)
	dissolve_gates()

func view_size() -> Vector2: return get_viewport().get_visible_rect().size

func snap_cam() -> void:
	if player == null: return
	var vs = view_size()
	cam = Vector2(player.x - vs.x / 2, player.y - 50 - vs.y / 2)
	clamp_cam()

func clamp_cam() -> void:
	var vs = view_size()
	cam.x = clampf(cam.x, 0, world.pw - vs.x); cam.y = clampf(cam.y, 0, world.ph - vs.y)

func update_cam(dt: float) -> void:
	var p = player; var vs = view_size()
	var t: Vector2; var k = 6.0
	if cam_focus != null: t = cam_focus; k = cam_pan_speed
	elif boss is Object and arena: t = Vector2((p.x * 2 + boss.x) / 3, (p.y * 2 + boss.y) / 3 - 40)
	else: t = Vector2(p.x + cos(p.face) * 30, p.y - 50 + sin(p.face) * 20)
	var w = t - vs / 2
	cam += (w - cam) * (1 - exp(-k * dt))
	clamp_cam()

func _process(_dt: float) -> void:
	if player == null: return
	var sh = fx.shake
	camera.position = (cam + Vector2((randf() - 0.5) * sh, (randf() - 0.5) * sh)).round()
	_update_lights()

# ---------- drawing (world coordinates; the camera handles the view) ----------
func _in_view(x: float, y: float, m := 260.0) -> bool:
	var vs = view_size()
	return x > cam.x - m and x < cam.x + vs.x + m and y > cam.y - 40 and y < cam.y + vs.y + m

func _draw_water(ci: CanvasItem) -> void:
	var vs = view_size()
	var tx0 = maxi(0, int(cam.x / T)); var ty0 = maxi(0, int(cam.y / T))
	var tx1 = mini(World.W - 1, int((cam.x + vs.x) / T)); var ty1 = mini(World.H - 1, int((cam.y + vs.y) / T))
	for ty in range(ty0, ty1 + 1):
		for tx in range(tx0, tx1 + 1):
			if not world.is_water(tx, ty): continue
			var h = G.hash2(tx, ty, 5)
			var ph = fmod(time * 0.6 + h * 10, 4.0)
			if ph < 1.4:
				var a = sin(ph / 1.4 * PI)
				ci.draw_rect(Rect2(tx * T + int(h * 20) + 2, ty * T + int(G.hash2(tx, ty, 6) * 26) + 3, 6 + int(ph * 3), 1), Color(0.75, 0.86, 1, a * 0.5))

func draw_prop(ci: CanvasItem, pr: Dictionary, alpha := 1.0) -> void:
	if not Assets.props.has(pr.kind): return
	if pr.get("gate", "") == "south" and flags.get("gate_open", false): return
	var A: Dictionary = Assets.props[pr.kind]
	var sh: float = pr.k.get("shadow", 0)
	if sh > 0: Fx.ellipse(ci, Vector2(pr.x, pr.y - 2), sh, sh * 0.32, Color(0, 0, 0.04, 0.3))
	var k: float = A.scale
	ci.draw_set_transform(Vector2(pr.x, pr.y), 0, Vector2(-k if pr.flip else k, k))
	ci.draw_texture(A.tex, Vector2(-A.ax, -A.ay), Color(1, 1, 1, alpha))
	ci.draw_set_transform_matrix(Transform2D.IDENTITY)

func _draw_flat(ci: CanvasItem) -> void:
	for pr in world.props:
		if pr.k.get("flat", false) and _in_view(pr.x, pr.y): draw_prop(ci, pr)
	# miasma on locked paths
	for gt in world.GATES:
		if flags.get(gt.flag, false) or gt.id == "south": continue
		var r = Rect2(gt.x0 * T, gt.y0 * T, (gt.x1 - gt.x0 + 1) * T, (gt.y1 - gt.y0 + 1) * T)
		if not _in_view(r.get_center().x, r.get_center().y, 400): continue
		if randf() < 0.5: fx.smoke(r.position.x + randf() * r.size.x, r.position.y + randf() * r.size.y, 1, Color("#7a2cff"))
		ci.draw_texture_rect(dot, r.grow(r.size.length() * 0.4), false, Color(GATE_DIM, 0.35))
	if arena:
		var pts = PackedVector2Array()
		for i in 64:
			var a = i / 64.0 * TAU
			pts.append(Vector2(arena.x + cos(a) * (arena.r + 12), arena.y + sin(a) * (arena.r + 12) * 0.7))
		for i in range(0, 64, 2): ci.draw_line(pts[i], pts[(i + 1) % 64], Color(0.63, 0.31, 1, 0.4), 3)

func _draw_ground_add(ci: CanvasItem) -> void:
	for h in hazards: h.draw_ground(ci)
	fx.draw_ground(ci)

func _draw_sprites(ci: CanvasItem) -> void:
	if player == null: return
	var list = []
	for pr in world.props:
		if not pr.k.get("flat", false) and _in_view(pr.x, pr.y): list.append(pr)
	for n in npcs:
		if not n.hidden and _in_view(n.x, n.y): list.append(n)
	for e in enemies:
		if _in_view(e.x, e.y): list.append(e)
	list.append_array(pickups)
	list.append_array(projectiles)
	list.append(player)
	list.sort_custom(func(a, b): return a.y < b.y)
	var p = player
	for o in list:
		if o is Dictionary:
			var alpha = 1.0
			if Assets.props.has(o.kind):
				var A: Dictionary = Assets.props[o.kind]
				var ks: float = A.scale
				if o.y > p.y and o.y - p.y < A.h * ks - 10 and abs(o.x - p.x) < A.bw * ks / 2 + 10 and A.h * ks > 70: alpha = 0.55
			draw_prop(ci, o, alpha)
		else: o.draw(ci)

func _draw_glow_add(ci: CanvasItem) -> void:
	fx.draw_parts(ci, true, dot)
	for e in enemies:
		if _in_view(e.x, e.y): e.draw_glow(ci)
	for pr in projectiles:
		if pr.has_method("draw_glow"): pr.draw_glow(ci)
	# coloured light pools (lanterns, spirits)
	for l in _lights():
		if l[3] != null: ci.draw_texture_rect(dot, Rect2(l[0] - l[2] * 0.8, l[1] - l[2] * 0.8, l[2] * 1.6, l[2] * 1.6), false, Color(l[3], 0.22 * l[4]))

func _lights() -> Array:
	var out = []
	var p = player
	out.append([p.x, p.y - 30, 190.0, null, 0.85])
	for pr in world.props:
		if pr.has("light") and _in_view(pr.x, pr.y, 200):
			var l: Array = pr.light
			out.append([pr.x + l[0], pr.y + l[1], l[2] * (1 + sin(time * 7 + pr.x) * 0.03), l[3], l[4]])
	for n in npcs:
		if not n.hidden and n.id in ["yongwang", "sansin"]: out.append([n.x, n.y - 40, 130.0, Color("#7fd0ff"), 0.6])
	for pr in projectiles:
		if pr is Ent.Orb: out.append([pr.x, pr.y - pr.z, 70.0, null, 0.6])
	if p.state == "ult": out.append([p.x, p.y - 30, 200 + p.state_t * 300, Color("#fff0c0"), 1.0])
	return out

func _update_lights() -> void:
	var vs = view_size()
	light_rect.size = vs
	var zid: String = zone.id if zone else "beach"
	var dark: float = {"beach": 0.08, "town": 0.12, "ruin": 0.34, "pond": 0.26, "forest": 0.36, "house": 0.3}.get(zid, 0.15)
	var arr = []
	for l in _lights():
		if arr.size() >= 48: break
		arr.append(Vector4(l[0] - camera.position.x, l[1] - camera.position.y, l[2], l[4]))
	light_mat.set_shader_parameter("view_size", vs)
	light_mat.set_shader_parameter("darkness", dark)
	light_mat.set_shader_parameter("light_count", arr.size())
	while arr.size() < 48: arr.append(Vector4.ZERO)
	light_mat.set_shader_parameter("lights", arr)

func _draw_guide(ci: CanvasItem) -> void:
	if ui.dialog != null or cinema or G.state != "play": return
	var ob: Dictionary = story.objective()
	if ob.target == null or boss: return
	var vs = view_size()
	var t: Vector2 = ob.target
	var pp = Vector2(player.x, player.y - 40)
	var on = t.x > cam.x + 30 and t.x < cam.x + vs.x - 30 and t.y > cam.y + 30 and t.y < cam.y + vs.y - 30
	var col = Color("#ffd27a")
	if on:
		var y = t.y - 70 + sin(time * 4) * 5
		ci.draw_colored_polygon(PackedVector2Array([Vector2(t.x, y + 12), Vector2(t.x - 9, y), Vector2(t.x + 9, y)]), col)
		return
	var a = (t - pp).angle()
	var R: float = min(vs.x, vs.y) * 0.32
	var c = pp + Vector2(cos(a) * R, sin(a) * R * 0.8)
	col.a = 0.6 + 0.3 * sin(time * 5)
	var tri = PackedVector2Array([Vector2(16, 0), Vector2(-6, -10), Vector2(-2, 0), Vector2(-6, 10)])
	for i in tri.size(): tri[i] = c + tri[i].rotated(a)
	ci.draw_colored_polygon(tri, col)

func _draw_overlay(ci: CanvasItem) -> void:
	var vs = view_size()
	if player and G.state == "play" and player.hp < player.max_hp * 0.3 and player.state != "dead":
		ci.draw_rect(Rect2(Vector2.ZERO, vs), Color(0.63, 0, 0.08, 0.12 + sin(time * 5) * 0.06))
	if fx.flash > 0: ci.draw_rect(Rect2(Vector2.ZERO, vs), Color(fx.flash_color, min(1.0, fx.flash)))
	if death_t != null:
		var k: float = min(1.0, death_t / 1.5)
		ci.draw_rect(Rect2(Vector2.ZERO, vs), Color(0, 0, 0, k * 0.9))
		var f: Font = Assets.font_black
		var s = "넋이 흐려진다…"
		var w = f.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, 28).x
		ci.draw_string(f, Vector2(vs.x / 2 - w / 2, vs.y / 2), s, HORIZONTAL_ALIGNMENT_LEFT, -1, 28, Color(0.78, 0.72, 0.91, k))
