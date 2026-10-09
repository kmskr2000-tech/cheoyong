extends Node2D
## A playable level built from Levels.DATA[Game.level_id]: baked tiered ground (art/ground3d.py),
## voxel and hand-drawn props, NPCs, enemies, exits, lighting and the HD-2D finishing pass.
## Story beats hook in through Story (story.gd).

## occluder half-width / height for props that cast lantern shadows
const OCCLUDE := {"pillar": Vector2(7, 5), "irworobong": Vector2(50, 4), "chotdae": Vector2(4, 3), "tal": Vector2(3, 3), "hall": Vector2(80, 24), "jars": Vector2(16, 6), "beam": Vector2(24, 6), "altar": Vector2(20, 6), "boat": Vector2(28, 8), "netrack": Vector2(30, 3), "house": Vector2(50, 28), "pine": Vector2(5, 6), "seonang": Vector2(8, 6), "jangseung_m": Vector2(5, 4), "jangseung_f": Vector2(5, 4), "lantern": Vector2(8, 6), "dodam": Vector2(32, 6)}

var light_tex: Texture2D


var meta := {}
var def := {}
var dialog: DialogBox
var hud: Hud
var npcs: Array[Npc] = []
var interact_points: Array = [] # [{pos, id, label}]


func _ready() -> void:
	def = Levels.DATA[Game.level_id]
	meta = JSON.parse_string(FileAccess.get_file_as_string("res://assets/levels/%s.json" % def["ground"]))
	light_tex = _radial(256)
	_ground()
	for p in def.get("props", []):
		if p.size() > 4 and not Game.flag(p[4]):
			continue  # story-gated prop
		_prop(p[0], lift(Vector2(p[1], p[2])), p[3])
	_atmosphere()
	var size: Array = meta["size"]
	var tier: float = meta["tier"]
	var player: Node2D = $Player
	var sp: Vector2 = def["spawns"].get(Game.spawn_name, def["spawns"].values()[0])
	player.position = lift(sp)
	player.spawn = player.position
	var cam: Camera2D = $Player/Camera
	cam.limit_left = 0
	cam.limit_top = int(-tier * 2)
	cam.limit_right = int(size[0])
	cam.limit_bottom = int(size[1] - tier)
	cam.reset_smoothing()
	if def.has("wisps"):
		for i in 4:
			_wisp(lift(def["wisps"]) + Vector2(cos(i * 1.7), sin(i * 2.3)) * 46, i)
	_blob(player, 10)
	for n in def.get("npcs", []):
		var npc := Npc.new()
		npc.setup(n[0], n[1], n[4])
		npc.position = lift(Vector2(n[2], n[3]))
		add_child(npc)
		npcs.append(npc)
		_blob(npc, 9)
		if n.size() > 5 and n[5] == "hidden":
			npc.set_present(false)
	for it in def.get("interact", []):
		var ip := {"pos": lift(Vector2(it[1], it[2])), "id": it[0], "label": it[3]}
		if it.size() > 4 and it[4] == "glint":
			ip["node"] = _glint(ip["pos"])
		interact_points.append(ip)
	for c in def.get("crabs", []):
		var crab := Crab.new()
		crab.position = lift(c)
		add_child(crab)
	for vp in def.get("vents", []):
		var vent := MiasmaVent.new()
		vent.position = lift(vp)
		vent.phase_off = fmod(vp.x * 0.013 + vp.y * 0.007, 4.4)
		add_child(vent)
	for tr in def.get("triggers", []):
		add_trigger(tr[0], tr[1])
	var enemies: Array = def.get("enemies", [])
	for a in OS.get_cmdline_user_args():
		if a == "--test-enemies":
			enemies = [["dog", 260, 270], ["ghoul", 330, 300]]
		elif a.begins_with("--test-enemies="):  # e.g. --test-enemies=mama,egg_ghost (lined up in front of the spawn)
			enemies = []
			var ks := a.get_slice("=", 1).split(",")
			var at: Vector2 = def["spawns"].get(Game.spawn_name, def["spawns"].values()[0])
			for i in ks.size():
				enemies.append([ks[i], at.x - (ks.size() - 1) * 30 + i * 60, at.y + 70])
	for e in enemies:
		spawn_enemy(e[0], Vector2(e[1], e[2]))
	for ex in def.get("exits", []):
		_exit(ex)
	hud = Hud.new()
	add_child(hud)
	hud.bind(player)
	dialog = DialogBox.new()
	add_child(dialog)
	player.interact = _try_interact
	if "--boss" in OS.get_cmdline_user_args():
		var boss := PlagueGod.new()
		boss.position = lift(Vector2(370, 190))
		add_child(boss)
		hud.show_boss(boss, "역신(疫神)")
		if "--boss-weak" in OS.get_cmdline_user_args():  # test hook: verify the defeat sequence
			boss.hp = 20.0
	Audio.music(def.get("music", "night"))
	Audio.ambience(def.get("amb", ""))
	Story.on_enter(self)
	_make_guide()


# ---------------------------------------------------------------- interaction ("다가가면 버튼이 빛난다")
const TALK_RANGE := 26.0


func nearest_interactable() -> Dictionary:
	var p: Vector2 = $Player.global_position
	var best := {}
	var bd := TALK_RANGE
	for n in npcs:
		if n.visible and n.talkable and n.global_position.distance_to(p) < bd:
			bd = n.global_position.distance_to(p)
			best = {"id": n.id, "label": n.display_name, "node": n}
	for it in interact_points:
		if it["pos"].distance_to(p) < bd:
			bd = it["pos"].distance_to(p)
			best = it
	return best


func _physics_process(_d: float) -> void:
	var target := nearest_interactable()
	hud.set_talk(not target.is_empty() and not $Player.locked)


func _try_interact() -> bool:
	var target := nearest_interactable()
	if target.is_empty():
		return false
	Story.interact(self, target["id"])
	return true


func spawn_enemy(kind: String, footprint: Vector2) -> Enemy:
	var en := Enemy.new()
	en.kind = kind
	en.position = lift(footprint)
	add_child(en)
	_blob(en, 10)
	return en


func npc(id: String) -> Npc:
	for n in npcs:
		if n.id == id:
			return n
	return null


## an invisible wall (plus a curtain of 탁기) — used to seal the boss room
func add_barrier(r: Rect2) -> Node2D:
	var b := StaticBody2D.new()
	b.position = lift(r.get_center())
	var col := CollisionShape2D.new()
	var sh := RectangleShape2D.new()
	sh.size = r.size
	col.shape = sh
	b.add_child(col)
	var p := CPUParticles2D.new()
	p.amount = 30
	p.lifetime = 1.4
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.emission_rect_extents = r.size / 2.0
	p.direction = Vector2(0, -1)
	p.gravity = Vector2(0, -10)
	p.initial_velocity_min = 4.0
	p.initial_velocity_max = 10.0
	p.scale_amount_min = 3.0
	p.scale_amount_max = 5.0
	p.color = Color(0.3, 0.1, 0.4, 0.7)
	p.z_index = 30
	b.add_child(p)
	add_child(b)
	return b


func remove_interact(id: String) -> void:
	for it in interact_points.duplicate():
		if it["id"] == id:
			if it.has("node"):
				it["node"].queue_free()
			interact_points.erase(it)


## a twinkle over something worth picking up
func _glint(at: Vector2) -> Node2D:
	var n := Node2D.new()
	n.position = at + Vector2(0, -3)
	n.z_index = 40
	var p := CPUParticles2D.new()
	p.amount = 6
	p.lifetime = 0.9
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.emission_rect_extents = Vector2(5, 2)
	p.direction = Vector2(0, -1)
	p.gravity = Vector2.ZERO
	p.initial_velocity_min = 2.0
	p.initial_velocity_max = 6.0
	p.scale_amount_min = 1.0
	p.scale_amount_max = 2.0
	var ramp := Gradient.new()
	ramp.colors = PackedColorArray([Color(1, 0.95, 0.7, 0), Color(1, 0.95, 0.75, 1), Color(0.7, 0.85, 1, 0)])
	ramp.offsets = PackedFloat32Array([0.0, 0.3, 1.0])
	p.color_ramp = ramp
	var um := CanvasItemMaterial.new()
	um.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	um.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	p.material = um
	n.add_child(p)
	var l := PointLight2D.new()
	l.texture = light_tex
	l.texture_scale = 0.12
	l.energy = 0.9
	l.color = Color(0.85, 0.9, 1.0)
	n.add_child(l)
	add_child(n)
	return n


## true when a screen position lies over open water
func is_water(p: Vector2) -> bool:
	var rows: Array = meta["heights"]
	var cy := clampi(int(p.y / meta["ts"]), 0, rows.size() - 1)
	var cx := clampi(int(p.x / meta["ts"]), 0, String(rows[0]).length() - 1)
	return String(rows[cy])[cx] == "0"


## story trigger zone (footprint rect): fires Story.trigger once when the hero walks in
func add_trigger(r: Rect2, id: String) -> void:
	var a := Area2D.new()
	var col := CollisionShape2D.new()
	var sh := RectangleShape2D.new()
	sh.size = r.size
	col.shape = sh
	a.position = lift(r.get_center())
	a.add_child(col)
	a.body_entered.connect(func(b):
		if b == $Player and is_instance_valid(a) and not a.is_queued_for_deletion():
			a.queue_free()
			Story.trigger(self, id))
	add_child.call_deferred(a)


func _exit(ex: Array) -> void:
	var r: Rect2 = ex[0]
	var a := Area2D.new()
	var col := CollisionShape2D.new()
	var sh := RectangleShape2D.new()
	sh.size = r.size
	col.shape = sh
	a.position = lift(r.get_center())
	a.add_child(col)
	a.body_entered.connect(func(b):
		if b == $Player and not $Player.locked:
			Game.change_level(ex[1], ex[2]))
	add_child.call_deferred(a)


# ---------------------------------------------------------------- 용패 guide + wet feet
var _guide: Sprite2D
var _guide_t := 0.0
var _splash_cd := 0.0


# ---------------------------------------------------------------- 한풀이: every 원혼 here sung clean
var _earned_j := 0
var _earned_d := 0
var _purified_n := 0


func on_purified(r: Dictionary, where: Vector2) -> void:
	_earned_j += r["jeonggi"]
	_earned_d += r["deok"]
	_purified_n += 1
	var left := get_tree().get_nodes_in_group("enemy").filter(func(e): return not e.get("is_clone")).size() \
		+ get_tree().get_nodes_in_group("downed").size()
	var key := "hanpuri_" + Game.level_id
	if left == 0 and _purified_n >= 3 and not Game.flag(key):
		Game.set_flag(key)
		Game.say_toast("한풀이 — 이곳의 원혼이 모두 풀렸다", Color(0.75, 0.9, 1.0))
		Game.reward_bonus(_earned_j / 2, _earned_d / 2, where, self)   # 정화율 100%: ×1.5 in total


# ---------------------------------------------------------------- 전투 음악: 요괴가 쫓아오면 자진모리
var _calm_t := 0.0


func _update_combat_music(d: float) -> void:
	var p: Node2D = $Player
	var hunting := false
	for e in get_tree().get_nodes_in_group("enemy"):
		if e.get("state") in ["chase", "tell", "strike", "vanish", "lure"] and e.global_position.distance_to(p.global_position) < 200.0:
			hunting = true
			break
	_calm_t = 0.0 if hunting else _calm_t + d
	if hunting:
		Audio.combat(true)
	elif _calm_t > 4.0:
		Audio.combat(false)


# ---------------------------------------------------------------- darkness (어둑시니, 불개의 일식)
var _dark: ColorRect
var _dark_req := {}


## enemies ask for the screen to darken (each frame); the strongest request wins, eased in and out
func request_darkness(key, amount: float) -> void:
	_dark_req[key] = clampf(maxf(amount, _dark_req.get(key, 0.0)), 0.0, 0.9)   # never fully black


func _update_darkness(d: float) -> void:
	if _dark == null:
		var layer := CanvasLayer.new()
		layer.layer = 11
		_dark = ColorRect.new()
		_dark.color = Color(0.0, 0.0, 0.02, 0.0)
		_dark.set_anchors_preset(Control.PRESET_FULL_RECT)
		_dark.mouse_filter = Control.MOUSE_FILTER_IGNORE
		layer.add_child(_dark)
		add_child(layer)
	var want := 0.0
	for v in _dark_req.values():
		want = maxf(want, v)
	_dark_req.clear()
	_dark.color.a = move_toward(_dark.color.a, want, d * 1.6)


func _make_guide() -> void:
	_guide = Sprite2D.new()
	var img := Image.create(5, 5, false, Image.FORMAT_RGBA8)
	for y in 5:
		for x in 5:
			var d := Vector2(x - 2, y - 2).length()
			if d < 2.6:
				img.set_pixel(x, y, Color(0.8, 0.95, 1.0, 1.0 if d < 1.2 else 0.45))
	_guide.texture = ImageTexture.create_from_image(img)
	var add := CanvasItemMaterial.new()
	add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	add.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	_guide.material = add
	_guide.z_index = 45
	_guide.z_as_relative = false
	_guide.visible = false
	add_child(_guide)


func _update_guide(d: float) -> void:
	_guide_t += d
	var p: Node2D = $Player
	var goal = Story.objective(self)
	if goal == null or p.locked:
		_guide.visible = false
		return
	var to: Vector2 = lift(goal) - p.global_position
	if to.length() < 40.0:
		_guide.visible = false
		return
	_guide.visible = true
	# a mote that drifts out from the 용패 at his chest toward where the 탁기 is thick, then fades
	var k := fmod(_guide_t, 1.6) / 1.6
	_guide.global_position = p.global_position + Vector2(0, -22) + to.normalized() * (10.0 + k * 22.0)
	_guide.modulate.a = sin(k * PI) * 0.8


func _wet_feet(d: float) -> void:
	_splash_cd -= d
	var p: CharacterBody2D = $Player
	if _splash_cd > 0.0 or p.velocity.length() < 10.0 or not is_water(p.global_position + Vector2(0, 30)):  # screen → roughly the footprint just ahead
		return
	_splash_cd = 0.22
	Audio.sfx("splash", -16.0, 0.15)
	var sp := CPUParticles2D.new()
	sp.one_shot = true
	sp.amount = 6
	sp.lifetime = 0.45
	sp.explosiveness = 0.9
	sp.direction = Vector2(0, -1)
	sp.spread = 70.0
	sp.gravity = Vector2(0, 160)
	sp.initial_velocity_min = 20.0
	sp.initial_velocity_max = 40.0
	sp.color = Color(0.6, 0.75, 0.95, 0.8)
	sp.global_position = p.global_position
	sp.z_index = 40
	sp.z_as_relative = false
	add_child(sp)
	sp.emitting = true
	sp.finished.connect(sp.queue_free)


## run a dialogue with the hero frozen
func talk(lines: Array) -> void:
	$Player.locked = true
	# the world holds its breath while someone speaks: 요괴 don't get free hits during dialogue
	var frozen: Array = []
	for e in get_tree().get_nodes_in_group("enemy") + get_tree().get_nodes_in_group("downed"):
		if e.is_physics_processing():
			e.set_physics_process(false)
			frozen.append(e)
	await dialog.say(lines)
	for e in frozen:
		if is_instance_valid(e):
			e.set_physics_process(true)
	$Player.locked = false


## footprint → screen: ground on tier k is drawn k*TIER px higher (oblique camera)
func lift(p: Vector2) -> Vector2:
	var rows: Array = meta["heights"]
	var cy := clampi(int(p.y / meta["ts"]), 0, rows.size() - 1)
	var cx := clampi(int(p.x / meta["ts"]), 0, String(rows[0]).length() - 1)
	var c := String(rows[cy])[cx]
	var t := 1.0 if not c.is_valid_int() else float(c)
	return Vector2(p.x, p.y - t * meta["tier"])


## the baked ground: one lit sprite with geometric normals, an animated water overlay, cliff collision
func _ground() -> void:
	var off: float = meta["offset"]
	var g := Sprite2D.new()
	g.texture = Tex.lit("res://assets/levels/%s.png" % def["ground"])
	g.centered = false
	g.position = Vector2(0, -off)
	g.z_index = -20
	g.z_as_relative = false
	add_child(g)
	var w := Sprite2D.new()
	w.texture = load("res://assets/levels/%s_water.png" % def["ground"])
	w.centered = false
	w.position = g.position
	w.z_index = -19
	w.z_as_relative = false
	var wm := ShaderMaterial.new()
	wm.shader = load("res://shaders/water_overlay.gdshader")
	w.material = wm
	add_child(w)
	var body := StaticBody2D.new()
	add_child(body)
	# the world's edge (exits are areas just inside it)
	var sz: Array = meta["size"]
	var top: float = -float(meta["offset"])
	for r in [Rect2(-16, top - 16, sz[0] + 32, 16), Rect2(-16, sz[1] - meta["tier"], sz[0] + 32, 16),
			Rect2(-16, top, 16, sz[1] - top), Rect2(sz[0], top, 16, sz[1] - top)]:
		var ec := CollisionShape2D.new()
		var es := RectangleShape2D.new()
		es.size = r.size
		ec.shape = es
		ec.position = r.get_center()
		body.add_child(ec)
	for r in meta["collision"]:
		var col := CollisionShape2D.new()
		var sh := RectangleShape2D.new()
		sh.size = Vector2(r[2], r[3])
		col.shape = sh
		col.position = Vector2(r[0] + r[2] / 2.0, r[1] + r[3] / 2.0)
		body.add_child(col)


func _prop(name: String, at: Vector2, light) -> void:
	var tex: Texture2D = Tex.lit("res://assets/props/%s.png" % name)
	var body := StaticBody2D.new()
	body.position = at
	add_child(body)
	var spr := Sprite2D.new()
	spr.texture = tex
	spr.centered = false
	spr.offset = Vector2(-tex.get_width() / 2.0, -tex.get_height() + 1)
	body.add_child(spr)
	if tex.get_height() > 40:
		fade_props.append([body, spr, Rect2(spr.offset, tex.get_size())])
	var half: Vector2 = OCCLUDE.get(name, Vector2(3, 3))
	_blob(body, maxf(half.x + 4, 6))
	_cast_shadow(body, tex)
	var col := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(half.x * 2, half.y * 2)
	col.shape = shape
	col.position = Vector2(0, -half.y)
	body.add_child(col)
	var glow_path := "res://assets/props/%s_glow.png" % name
	if ResourceLoader.exists(glow_path):
		var g := Sprite2D.new()
		g.texture = load(glow_path)
		g.centered = false
		g.offset = spr.offset
		var um := CanvasItemMaterial.new()
		um.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
		g.material = um
		body.add_child(g)
	# light sources do not occlude their own light
	if OCCLUDE.has(name) and light == null:
		var occ := LightOccluder2D.new()
		var poly := OccluderPolygon2D.new()
		poly.polygon = PackedVector2Array([Vector2(-half.x, -half.y * 2), Vector2(half.x, -half.y * 2), Vector2(half.x, 0), Vector2(-half.x, 0)])
		occ.occluder = poly
		body.add_child(occ)
	if light != null:
		var l := PointLight2D.new()
		l.texture = light_tex
		l.position = Vector2(0, light[0])
		l.color = light[1]
		l.energy = light[2]
		l.texture_scale = light[3]
		l.height = 24.0
		l.shadow_enabled = true
		l.shadow_color = Color(0, 0, 0, 0.75)
		l.shadow_filter = PointLight2D.SHADOW_FILTER_PCF5
		l.set_meta("base", light[2])
		body.add_child(l)
		flicker.append(l)


var flicker: Array[PointLight2D] = []
var fade_props: Array = []   # [body, sprite, local rect] — tall props turn see-through when the hero is behind


var wisps: Array[Node2D] = []


## 귀화(鬼火): drifting violet ghost-fires that are real light sources
func _wisp(home: Vector2, i: int) -> void:
	var n := Node2D.new()
	n.position = home
	n.set_meta("home", home)
	n.set_meta("ph", i * 1.9)
	n.z_index = 40
	var core := Sprite2D.new()
	var img := Image.create(5, 7, false, Image.FORMAT_RGBA8)
	for y in 7:
		for x in 5:
			var d := Vector2(x - 2, (y - 4) * 0.8).length()
			if d < 2.6 - (0.0 if y > 2 else 0.8):
				img.set_pixel(x, y, Color(1.0, 0.85, 1.0) if d < 1.2 else Color(0.75, 0.35, 1.0, 0.9))
	core.texture = ImageTexture.create_from_image(img)
	var um := CanvasItemMaterial.new()
	um.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	core.material = um
	n.add_child(core)
	var l := PointLight2D.new()
	l.texture = light_tex
	l.color = Color(0.7, 0.35, 1.0)
	l.energy = 1.3
	l.texture_scale = 0.55
	l.height = 16.0
	n.add_child(l)
	add_child(n)
	wisps.append(n)


## moon shadow: the silhouette laid flat on the ground, falling to the lower right (moon is upper left)
func _cast_shadow(parent: Node2D, tex: Texture2D) -> void:
	var s := Sprite2D.new()
	s.texture = tex.diffuse_texture if tex is CanvasTexture else tex
	s.centered = false
	s.offset = Vector2(-tex.get_width() / 2.0, -tex.get_height() + 1)
	s.scale = Vector2(1, -0.42)
	s.skew = deg_to_rad(-38)
	s.modulate = Color(0, 0, 0.03, 0.42)
	s.z_index = -6
	s.z_as_relative = false
	parent.add_child(s)
	parent.move_child(s, 0)


## soft contact shadow under anything standing on the ground
func _blob(parent: Node2D, half_w: float) -> void:
	var img := Image.create(int(half_w * 2), int(maxf(4, half_w * 0.7)), false, Image.FORMAT_RGBA8)
	var w := img.get_width()
	var h := img.get_height()
	for y in h:
		for x in w:
			var d := Vector2((x + 0.5 - w / 2.0) / (w / 2.0), (y + 0.5 - h / 2.0) / (h / 2.0)).length()
			if d < 1.0:
				img.set_pixel(x, y, Color(0, 0, 0, 0.5 if d < 0.7 else 0.3))
	var s := Sprite2D.new()
	s.texture = ImageTexture.create_from_image(img)
	s.position = Vector2(0, -1)
	s.z_index = -5
	s.z_as_relative = false
	parent.add_child(s)
	parent.move_child(s, 0)


func _process(d: float) -> void:
	if _guide:
		_update_guide(d)
		_wet_feet(d)
	_update_darkness(d)
	_update_combat_music(d)
	var pp: Vector2 = $Player.global_position + Vector2(0, -16)
	for fp in fade_props:
		var body: Node2D = fp[0]
		var behind: bool = pp.y < body.global_position.y and (fp[2] as Rect2).grow(-2).has_point(pp - body.global_position)
		var spr: Sprite2D = fp[1]
		spr.modulate.a = move_toward(spr.modulate.a, 0.45 if behind else 1.0, d * 4.0)
	var t := Time.get_ticks_msec() / 1000.0
	for w in wisps:
		var ph: float = w.get_meta("ph")
		w.position = w.get_meta("home") + Vector2(sin(t * 0.7 + ph) * 18, sin(t * 1.1 + ph * 2) * 8 + sin(t * 3 + ph) * 2)
		w.modulate.a = 0.75 + sin(t * 5 + ph) * 0.25
	for i in flicker.size():
		var l := flicker[i]
		l.energy = l.get_meta("base") * (1.0 + sin(t * 9.0 + i * 3.1) * 0.05 + sin(t * 23.0 + i) * 0.035)


func _atmosphere() -> void:
	# moonlit night: everything unlit sinks into cold violet-blue
	# 해질녘 (dusk) for daily life in 경주; full night otherwise
	var dusk: bool = def.get("time", "night") == "dusk" and not Game.flag("night")
	var cm := CanvasModulate.new()
	var night_col := Color(0.27, 0.3, 0.47) if Game.flag("rescued") else Color(0.2, 0.26, 0.42)  # 새벽 after the rescue
	cm.color = def.get("ambient", Color(0.34, 0.37, 0.52) if dusk else night_col)
	add_child(cm)
	# the moon: a cold key light from the upper left that rakes across every normal map and casts
	# long diagonal shadows from houses and trees
	var moon := DirectionalLight2D.new()
	moon.color = Color(0.6, 0.74, 1.0) # cold moon
	moon.energy = 0.75
	moon.height = 0.45
	moon.rotation = deg_to_rad(35)
	add_child(moon)
	# a faint cold aura around the hero so he never vanishes in the dark
	var pl := PointLight2D.new()
	pl.texture = light_tex
	pl.color = Color(0.6, 0.7, 0.95)
	pl.energy = 0.55
	pl.texture_scale = 0.55
	pl.position = Vector2(0, -16)
	pl.height = 30.0
	$Player.add_child(pl)
	# fog over the ground, lit by the lanterns it drifts through
	var fog := ColorRect.new()
	var w: float = meta["size"][0]
	var h: float = meta["size"][1] + meta["offset"]
	fog.size = Vector2(w, h)
	fog.position = Vector2(0, -meta["offset"])
	fog.z_index = 50
	fog.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var fm := ShaderMaterial.new()
	fm.shader = load("res://shaders/fog.gdshader")
	fm.set_shader_parameter("world_size", Vector2(w, h))
	fm.set_shader_parameter("tint", Color(0.36, 0.46, 0.66))
	fm.set_shader_parameter("sick", Color(0.42, 0.3, 0.7))
	fog.material = fm
	add_child(fog)
	# ash / spores drifting down across the view
	var ash := CPUParticles2D.new()
	# cold spirit motes rising through the haze (warm embers only near the lanterns' light)
	ash.amount = 60
	ash.lifetime = 7.0
	ash.preprocess = 7.0
	ash.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	ash.emission_rect_extents = Vector2(280, 20)
	ash.position = Vector2(0, 150)
	ash.direction = Vector2(0.15, -1)
	ash.spread = 20.0
	ash.gravity = Vector2(0, -3)
	ash.initial_velocity_min = 10.0
	ash.initial_velocity_max = 26.0
	var ramp := Gradient.new()
	ramp.offsets = PackedFloat32Array([0.0, 0.15, 0.7, 1.0])
	ramp.colors = PackedColorArray([Color(0.6, 0.8, 1, 0), Color(0.7, 0.85, 1, 1), Color(0.5, 0.6, 1, 0.7), Color(0.4, 0.3, 0.9, 0)])
	ash.color_ramp = ramp
	ash.z_index = 60
	var am := CanvasItemMaterial.new()
	am.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	am.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	ash.material = am
	ash.local_coords = false
	$Player/Camera.add_child(ash)
	# light shafts through the haze, then the HD-2D finishing pass (DoF, bloom, grade, haze, vignette)
	var shafts_layer := CanvasLayer.new()
	shafts_layer.layer = 5
	var shafts := ColorRect.new()
	shafts.set_anchors_preset(Control.PRESET_FULL_RECT)
	shafts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sm := ShaderMaterial.new()
	sm.shader = load("res://shaders/shafts.gdshader")
	shafts.material = sm
	shafts_layer.add_child(shafts)
	add_child(shafts_layer)
	var post_layer := CanvasLayer.new()
	post_layer.layer = 10
	var post := ColorRect.new()
	post.set_anchors_preset(Control.PRESET_FULL_RECT)
	post.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var pm := ShaderMaterial.new()
	pm.shader = load("res://shaders/post.gdshader")
	post.material = pm
	post_layer.add_child(post)
	add_child(post_layer)


static func _radial(size: int) -> Texture2D:
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.35, 0.7, 1.0])
	g.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0.55), Color(1, 1, 1, 0.15), Color(1, 1, 1, 0)])
	var t := GradientTexture2D.new()
	t.gradient = g
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.5)
	t.fill_to = Vector2(1.0, 0.5)
	t.width = size
	t.height = size
	return t
