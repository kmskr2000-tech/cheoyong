extends SceneTree
## 전투 신호 이펙트 캡처 하네스 (아트팀). 게임 코드를 수정하지 않는다. 전/후 비교용으로 같은 스크립트를 두 체크아웃에서 돌린다.
##   xvfb-run -a godot --rendering-driver opengl3 --fixed-fps 60 --path <src> -s <이 파일> -- --out=<디렉터리> --tag=before|after [--only=parry,charge,...]
## 장면: parry · charge · guard · open · boss_open · bindfire · purify. 각 장면은 시점별 PNG(480x270)와 플레이어 주변 3배 확대 크롭을 남긴다.
var out := "/tmp/fxshots"
var tag := "after"
var only := []
var G: Node
var level_id := ""


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="): out = a.get_slice("=", 1)
		elif a.begins_with("--tag="): tag = a.get_slice("=", 1)
		elif a.begins_with("--only="): only = a.get_slice("=", 1).split(",")
		elif a.begins_with("--level="): level_id = a.get_slice("=", 1)
	DirAccess.make_dir_recursive_absolute(out)
	G = root.get_node("Game")
	_main.call_deferred()


func tick(n := 1) -> void:
	for i in n:
		await process_frame


func lvl() -> Node:
	var s := current_scene
	if s != null and s.get("def") != null and s.get_node_or_null("Player") != null and s.get("hud") != null:
		return s
	return null


func player() -> Node:
	return lvl().get_node("Player")


func boot() -> void:
	await process_frame
	if level_id != "":
		G.level_id = level_id
	change_scene_to_file("res://scenes/level.tscn")
	var n := 0
	while lvl() == null and n < 600:
		await process_frame
		n += 1
	await tick(3)
	var p := player()
	p.locked = false
	for g in ["enemy", "downed"]:
		for e in get_nodes_in_group(g):
			e.remove_from_group("enemy"); e.remove_from_group("downed"); e.queue_free()
	G.skills = []
	p.hp = p.max_hp; p.ki = p.max_ki; p.hurt_t = 0.0; p.gentle_hits = 0
	p.position = lvl().lift(lvl().def["spawns"]["start"])
	p.facing = "right"
	await tick(30)


func spawn(kind: String, at: Vector2, state := "idle"):
	var e = load("res://scripts/enemy.gd").new()
	e.kind = kind
	e.position = at
	lvl().add_child(e)
	e.state = state
	return e


func dummy(kind: String, at: Vector2):
	var e = spawn(kind, at)
	e.set_physics_process(false)
	return e


func shot(name: String, zoom := true) -> void:
	await RenderingServer.frame_post_draw
	var img: Image = root.get_viewport().get_texture().get_image()
	img.save_png("%s/%s_%s.png" % [out, name, tag])
	if zoom:
		var sp: Vector2 = player().get_global_transform_with_canvas().origin
		var vs := img.get_size()
		var r := Rect2i(clampi(int(sp.x) - 80, 0, vs.x - 160), clampi(int(sp.y) - 80, 0, vs.y - 110), 160, 110)
		var crop := img.get_region(r)
		crop.resize(r.size.x * 4, r.size.y * 4, Image.INTERPOLATE_NEAREST)
		crop.save_png("%s/%s_%s_zoom.png" % [out, name, tag])


func want(n: String) -> bool:
	return only.is_empty() or n in only


func _main() -> void:
	Engine.time_scale = 1.0
	if want("parry"): await sc_parry()
	if want("charge"): await sc_charge()
	if want("guard"): await sc_guard()
	if want("open"): await sc_open()
	if want("boss_open"): await sc_boss_open()
	if want("bindfire"): await sc_bindfire()
	if want("purify"): await sc_purify()
	if want("tell"): await sc_tell()
	if want("dark"): await sc_dark()
	if want("nametag"): await sc_nametag()
	if want("alley"): await sc_alley()
	print("FXSHOTS DONE ", tag)
	quit(0)


func sc_parry() -> void:
	await boot()
	var p := player()
	p.ki = 40.0
	var foe = dummy("ghoul", p.position + Vector2(30, 0))
	Input.action_press("roll")
	await tick(1)
	Input.action_release("roll")
	await tick(3)
	p.hurt(8, Vector2.LEFT, true)
	for i in [1, 3, 6, 10, 18]:
		await tick(i if i == 1 else 2 if i == 3 else 3 if i == 6 else 4 if i == 10 else 8)
		await shot("parry_%02d" % i)
	await tick(120)


func sc_charge() -> void:
	await boot()
	var p := player()
	var foe = dummy("mama", p.position + Vector2(34, 0))
	foe.hp = 9999
	Input.action_press("attack")
	await until_state(p, "charge", 200)
	await tick(10)
	await shot("charge_a_low")
	await until_c(p, 0.38, 200)
	await tick(6)
	await shot("charge_b_ready")
	await until_c(p, 0.92, 400)
	await tick(2)
	await shot("charge_c_full_flash")
	await tick(14)
	await shot("charge_d_full_hold")
	Input.action_release("attack")
	for i in [1, 2, 3, 5, 8]:
		await tick(1 if i == 1 else 1 if i == 2 else 1 if i == 3 else 2 if i == 5 else 3)
		await shot("charge_e_hit_%02d" % i)
	await tick(100)


func until_state(p, s: String, maxn: int) -> void:
	var n := 0
	while p.state != s and n < maxn:
		await process_frame
		n += 1


func until_c(p, c: float, maxn: int) -> void:
	var n := 0
	while p._charge_c < c and n < maxn:
		await process_frame
		n += 1


func sc_guard() -> void:
	await boot()
	var p := player()
	p.shield = 2
	p.shield_t = 10.0
	p.ki = 30.0
	p.hurt(8, Vector2.LEFT, true)
	await tick(3)
	await shot("guard_a_block_03")
	await tick(5)
	await shot("guard_a_block_08")
	await tick(40)
	p.hurt_t = 0.0
	p.hurt(8, Vector2.LEFT, true)
	for i in [2, 5, 8, 14]:
		await tick(2 if i == 2 else 3 if i == 5 else 3 if i == 8 else 6)
		await shot("guard_b_break_%02d" % i)
	await tick(100)


func sc_open() -> void:
	await boot()
	var p := player()
	var a = dummy("dog", p.position + Vector2(36, 0))
	var b = dummy("mama", p.position + Vector2(-40, 6))
	a._stagger(1.6)
	b._stagger(1.6)
	for i in [2, 6, 14, 30]:
		await tick(2 if i == 2 else 4 if i == 6 else 8 if i == 14 else 16)
		await shot("open_%02d" % i)
	await tick(120)


func sc_boss_open() -> void:
	await boot()
	var p := player()
	var boss = load("res://scripts/boss.gd").new()
	boss.name = "Boss"
	boss.position = p.position + Vector2(70, -10)
	lvl().add_child(boss)
	await tick(3)
	boss.set_physics_process(false)
	boss.state = "idle"
	if boss.has_method("_open"):
		boss._open(1.2)
	for i in [2, 8, 20]:
		await tick(2 if i == 2 else 6 if i == 8 else 12)
		await shot("boss_open_%02d" % i)
	await tick(120)


func sc_bindfire() -> void:
	await boot()
	var p := player()
	var a = dummy("ghoul", p.position + Vector2(36, -6))
	var b = dummy("dog", p.position + Vector2(52, 14))
	var zs = load("res://scripts/fx/talisman_zone.gd")
	var bz = zs.new()
	bz.kind = "bind"; bz.position = p.position + Vector2(44, 4); bz.life = 6.0
	lvl().add_child(bz)
	await tick(40)
	await shot("bindfire_a_bind_only")
	var fz = zs.new()
	fz.kind = "fire"; fz.position = p.position + Vector2(10, 4); fz.angle = 0.0; fz.half = 0.9; fz.radius = 70.0; fz.life = 5.0
	lvl().add_child(fz)
	for i in [20, 12, 14]:
		await tick(i)
		await shot("bindfire_b_%d" % Engine.get_physics_frames())
	await tick(150)


func sc_purify() -> void:
	await boot()
	var p := player()
	var e = spawn("dog", p.position + Vector2(34, 4))
	e.set_physics_process(false)
	e.hp = 1
	e.take_hit(50, Vector2.RIGHT)
	await tick(30)
	await shot("purify_a_downed")
	e.purify()
	for i in [2, 5, 9, 14, 20]:
		await tick(2 if i == 2 else 3 if i == 5 else 4 if i == 9 else 5 if i == 14 else 6)
		await shot("purify_b_%02d" % i)
	await tick(60)


func sc_tell() -> void:
	await boot()
	var p := player()
	var e = dummy("ghoul", p.position + Vector2(34, 0))
	await tick(4)
	await shot("tell_a_before_lock")
	if e.has_signal("tell_lock"):
		e.tell_lock.emit()
	for i in [1, 2, 4, 7]:
		await tick(1 if i == 1 else 1 if i == 2 else 2 if i == 4 else 3)
		await shot("tell_b_lock_%02d" % i)
	await tick(30)


func sc_dark() -> void:
	await boot()
	await tick(20)
	await shot("dark_hero")


func sc_nametag() -> void:
	await boot()
	var p := player()
	var cam: Camera2D = p.get_node_or_null("Camera")
	var kind := "mama"
	var e = dummy(kind, p.position + Vector2(-228, 0))
	e._bar.visible = true
	await tick(20)
	await shot("nametag_edge")
	var e2 = dummy(kind, p.position + Vector2(0, -140))
	e2._bar.visible = true
	e.position = p.position + Vector2(90, 0)
	await tick(20)
	await shot("nametag_top", false)
	e.position = p.position + Vector2(228, 0)
	e2.position = p.position + Vector2(-60, -150)
	await tick(20)
	await shot("nametag_right_top", false)


func sc_alley() -> void:
	level_id = "gyeongju"
	await boot()
	var p := player()
	for pos in [Vector2(345, 256), Vector2(200, 330), Vector2(450, 150)]:
		p.position = lvl().lift(pos)
		await tick(40)
		await shot("alley_%d_%d" % [int(pos.x), int(pos.y)], false)
