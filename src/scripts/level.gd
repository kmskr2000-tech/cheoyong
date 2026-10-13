extends Node2D
const CT := preload("res://scripts/combat_tuning.gd")
## A playable level built from Levels.DATA[Game.level_id]: baked tiered ground (art/ground3d.py),
## voxel and hand-drawn props, NPCs, enemies, exits, lighting and the HD-2D finishing pass.
## Story beats hook in through Story (story.gd).

## occluder half-width / height for props that cast lantern shadows
const OCCLUDE := {"pillar": Vector2(7, 5), "irworobong": Vector2(50, 4), "chotdae": Vector2(4, 3), "tal": Vector2(3, 3), "hall": Vector2(80, 24), "jars": Vector2(16, 6), "beam": Vector2(24, 6), "altar": Vector2(20, 6), "boat": Vector2(28, 8), "netrack": Vector2(30, 3), "house": Vector2(50, 28), "pine": Vector2(5, 6), "seonang": Vector2(8, 6), "jangseung_m": Vector2(5, 4), "jangseung_f": Vector2(5, 4), "lantern": Vector2(8, 6), "dodam": Vector2(32, 6), "board": Vector2(18, 8), "hut_ruin": Vector2(40, 16), "hut_ruin_b": Vector2(40, 16), "old_tools": Vector2(14, 5), "old_tools_mortar": Vector2(10, 4), "old_tools_broom": Vector2(3, 2), "old_tools_pot": Vector2(11, 4), "old_tools_sandals": Vector2(8, 3), "dok_torch": Vector2(4, 3), "mortar_altar": Vector2(30, 12), "doll": Vector2(3, 3), "rockwall": Vector2(32, 20), "tent": Vector2(26, 12), "burnt_stall": Vector2(26, 8), "sansingak": Vector2(40, 18)}

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
	for L in def.get("lights", []):   # [x, y, colour, energy, scale] — a lit window / painted lamp on the ground picture
		_glow_light(lift(Vector2(L[0], L[1])), L[2], L[3], L[4])
	_prune_shadows()
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
			var icon_path := "res://assets/ui/icons/key_%s.png" % it[0]   # e.g. the 피리 lying on the sand
			if ResourceLoader.exists(icon_path):
				var ic := Sprite2D.new()
				ic.texture = load(icon_path)
				ic.position = Vector2(0, -9)
				ic.z_index = 1
				ip["node"].add_child(ic)
				var bob := ic.create_tween().set_loops()
				bob.tween_property(ic, "position:y", -11.0, 0.9).set_trans(Tween.TRANS_SINE)
				bob.tween_property(ic, "position:y", -8.0, 0.9).set_trans(Tween.TRANS_SINE)
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
			for b in OS.get_cmdline_user_args():  # with --at, line them up in front of that spot instead
				if b.begins_with("--at="):
					var xy := b.get_slice("=", 1).split(",")
					at = Vector2(float(xy[0]), float(xy[1]) - 70)
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
		boss.name = "Boss"
		boss.position = lift(Vector2(370, 190))
		add_child(boss)
		hud.show_boss(boss, "역신(疫神)")
		if "--boss-weak" in OS.get_cmdline_user_args():  # test hook: verify the defeat sequence
			boss.hp = 20.0
	Audio.music(def.get("music", "night"))
	Audio.ambience(def.get("amb", ""))
	Story.on_enter(self)
	_make_guide()
	Quality.tier_changed.connect(_on_quality)
	_cull_lights()
	if Quality.tier < Quality.TIER_MAX:
		_on_quality(Quality.tier, Quality.TIER_MAX)


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
	sh.size = lift_size(r.size)
	col.shape = sh
	b.add_child(col)
	var p := CPUParticles2D.new()
	p.amount = 30
	p.lifetime = 1.4
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.emission_rect_extents = lift_size(r.size) / 2.0
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


## 이야기가 도중에 켜는 상호작용 지점 (예: 의뢰 B 의 짚인형). footprint 좌표. glint=true 면 반짝임 표시. 같은 id 가 이미 있으면 무시.
func add_interact(id: String, at: Vector2, label: String, glint := false) -> void:
	for it in interact_points:
		if it["id"] == id:
			return
	var ip := {"pos": lift(at), "id": id, "label": label}
	if glint:
		ip["node"] = _glint(ip["pos"])
	interact_points.append(ip)


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
	# flat-baked maps ("land_tier"): the screen position sits land_tier*TIER px above its footprint row
	var lift_px: float = float(meta.get("land_tier", 0)) * float(meta["tier"])
	var cy := clampi(int((p.y + lift_px) / depth_k() / meta["ts"]), 0, rows.size() - 1)
	var cx := clampi(int(p.x / meta["ts"]), 0, String(rows[0]).length() - 1)
	return String(rows[cy])[cx] == "0"


## story trigger zone (footprint rect): fires Story.trigger once when the hero walks in
func add_trigger(r: Rect2, id: String) -> void:
	var a := Area2D.new()
	var col := CollisionShape2D.new()
	var sh := RectangleShape2D.new()
	sh.size = lift_size(r.size)
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
	sh.size = lift_size(r.size)
	col.shape = sh
	a.position = lift(r.get_center())
	a.add_child(col)
	a.body_entered.connect(func(b):
		if b == $Player and not $Player.locked:
			Game.change_level(ex[1], ex[2]))
	add_child.call_deferred(a)


# ---------------------------------------------------------------- 한풀이: every 원혼 here sung clean
var _earned_j := 0
var _earned_d := 0
var _purified_n := 0


func on_purified(r: Dictionary, where: Vector2) -> void:
	Story.purified(self, str(r.get("kind", "")))   # 2장 이야기 훅 (장산범 정화 → 동문, 의뢰 B 무전투 판정)
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
		var pl: Node = get_node_or_null("Player")   # CS-05: 한풀이 성립 시 체력 +15%
		if pl and pl.has_method("heal"):
			pl.heal(pl.max_hp * CT.HP_HANPURI)


# ---------------------------------------------------------------- 전투 음악: 요괴가 쫓아오면 자진모리
var _calm_t := 0.0


var _scan_t := 0.0
var _hunting := false


func _update_combat_music(d: float) -> void:
	# 성능: 적 순회(그룹 배열 할당)는 0.1초마다만. 평정 타이머(4초 히스테리시스)는 매 프레임 그대로 센다.
	_scan_t -= d
	if _scan_t <= 0.0:
		_scan_t = 0.1
		var p: Node2D = $Player
		_hunting = false
		for e in get_tree().get_nodes_in_group("enemy"):
			if e.get("state") in ["chase", "tell", "strike", "vanish", "lure"] and e.global_position.distance_to(p.global_position) < 200.0:
				_hunting = true
				break
	_calm_t = 0.0 if _hunting else _calm_t + d
	if _hunting:
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


# ---------------------------------------------------------------- 용패 길잡이 (design/gdd/objective-marker.md §3.4~3.5)
## 가슴에서 목표 쪽으로 흐르는 빛 조각 3개 + (목표가 화면 안이면) 대상 위 빛기둥. 가까우면 말하기 점등이 이어받는다.
const GUIDE_HANDOFF := TALK_RANGE + 6.0     # H: 이 안이면 빛 조각·빛기둥을 끄고 말하기 점등에 맡긴다 (26px 점등 시작 + 6px 여유 → 빈 구간 없음)
const GUIDE_MOTES := 3
const GUIDE_PERIOD := 1.6
const GUIDE_FAR := 240.0                    # 이 거리 이상이면 크고(1.4) 밝게(0.95)
const GUIDE_VIEW := Vector2(240, 135)       # 빛기둥 시야 절반 크기. 뷰포트가 바뀌면 여기만 고친다 (시점/카메라 설계 대비)
const BEACON_PERIOD := 1.4
const OBJ_EVAL_EVERY := 0.25
var _motes: Array = []
var _beacon: Sprite2D
var _guide_t := 0.0
var _splash_cd := 0.0
var _obj: Dictionary = {}                   # 현재 목표 (Story.objective_info). 0.25초마다·progress_changed 때 갱신
var _obj_eval_t := 0.0
var _via_i := 0                             # 경유점 진행 (목표가 바뀌면 0으로)
var _via_id := ""
var _beacon_fade := 0.0


func _make_guide() -> void:
	var img := Image.create(5, 5, false, Image.FORMAT_RGBA8)
	for y in 5:
		for x in 5:
			var d := Vector2(x - 2, y - 2).length()
			if d < 2.6:
				img.set_pixel(x, y, Color(1.0, 1.0, 1.0, 1.0) if d < 1.2 else Color(0.62, 0.88, 1.0, 0.85))   # 폰 야외에서도 보이도록 중심은 흰색·테두리도 진하게
	var tex := ImageTexture.create_from_image(img)
	var add := CanvasItemMaterial.new()
	add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	add.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	for i in GUIDE_MOTES:
		var m := Sprite2D.new()
		m.texture = tex
		m.material = add
		m.z_index = 45
		m.z_as_relative = false
		m.visible = false
		add_child(m)
		_motes.append(m)
	# 빛기둥: 3x22 세로 그라데이션 (위로 갈수록 옅다). 같은 색(0.8,0.95,1.0), ADD
	var bi := Image.create(3, 22, false, Image.FORMAT_RGBA8)
	for y in 22:
		var a := pow(float(y) / 21.0, 1.5)
		bi.set_pixel(0, y, Color(0.8, 0.95, 1.0, a * 0.45))
		bi.set_pixel(1, y, Color(0.8, 0.95, 1.0, a))
		bi.set_pixel(2, y, Color(0.8, 0.95, 1.0, a * 0.45))
	_beacon = Sprite2D.new()
	_beacon.texture = ImageTexture.create_from_image(bi)
	_beacon.material = add
	_beacon.z_index = 44
	_beacon.z_as_relative = false
	_beacon.visible = false
	add_child(_beacon)
	Game.progress_changed.connect(func(): _obj_eval_t = 0.0)
	_refresh_objective()


func _refresh_objective() -> void:
	_obj = Story.objective_info(self)
	if hud:
		hud.set_objective(_obj)
	if _obj.get("id", "") != _via_id:
		_via_id = _obj.get("id", "")
		_via_i = 0


## 목표 대상의 화면 좌표(발밑). 움직이는 대상(npc/node)은 노드를 따라가고, 숨었거나 없으면 표의 좌표로 폴백
func goal_screen_pos(info: Dictionary) -> Variant:
	var tgt = info.get("target")
	if tgt == null:
		return null
	var follow: String = info.get("follow", "")
	if follow.begins_with("npc:"):
		var n := npc(follow.substr(4))
		if n != null and n.visible:
			return n.global_position
	elif follow.begins_with("node:"):
		var nd := get_node_or_null(follow.substr(5))
		if nd is Node2D and is_instance_valid(nd) and (nd as Node2D).visible:
			return (nd as Node2D).global_position
	return lift(tgt)


## 빛기둥을 세울 높이(대상 발밑 위 px) — 종류별
func _beacon_lift(kind: String) -> float:
	match kind:
		"npc": return 30.0
		"node": return 34.0
		_: return 18.0


## 출구 빔 폭: 목표 좌표를 중심으로 가진 출구/게이트 사각형의 폭(최대 48), 없으면 기둥 폭 그대로
func _beam_width(tgt: Vector2) -> float:
	var rects: Array = []
	for ex in def.get("exits", []):
		rects.append(ex[0])
	for g in def.get("gates", {}).values():
		rects.append(g[0])
	for r in rects:
		if (r as Rect2).get_center().distance_to(tgt) <= 3.0:
			return minf((r as Rect2).size.x, 48.0)
	return 3.0


func _update_guide(d: float) -> void:
	_guide_t += d
	_obj_eval_t -= d
	if _obj_eval_t <= 0.0:
		_obj_eval_t = OBJ_EVAL_EVERY
		_refresh_objective()
	var p: Node2D = $Player
	var goal = goal_screen_pos(_obj)
	var light_on = Game.setting("obj_light")
	if light_on == null:
		light_on = true
	for m in _motes:
		m.visible = false
	if goal == null or p.locked or not light_on:
		_beacon.visible = false
		return
	var to: Vector2 = goal - p.global_position
	var dist := to.length()
	if dist <= GUIDE_HANDOFF:
		_beacon_fade = move_toward(_beacon_fade, 0.0, d / 0.25)
		_beacon.visible = false
		return
	# 직선이 막히는 곳은 경유점을 먼저 따라간다 (경유점 32px 안이면 다음으로)
	var aim: Vector2 = goal
	var via: Array = _obj.get("via", [])
	while _via_i < via.size() and p.global_position.distance_to(lift(via[_via_i])) <= GUIDE_HANDOFF:
		_via_i += 1
	if _via_i < via.size():
		aim = lift(via[_via_i])
	var ato: Vector2 = aim - p.global_position
	var far := dist >= GUIDE_FAR
	var reach := 12.0 + clampf((dist - GUIDE_HANDOFF) / 12.0, 0.0, 34.0)   # r(d)
	for i in GUIDE_MOTES:
		var k := fmod(_guide_t / GUIDE_PERIOD + float(i) / GUIDE_MOTES, 1.0)
		var m: Sprite2D = _motes[i]
		m.visible = true
		m.scale = Vector2.ONE * (1.4 if far else 1.0)
		m.global_position = p.global_position + Vector2(0, -22) + ato.normalized() * (10.0 + k * reach)
		m.modulate.a = sin(k * PI) * (0.95 if far else 0.8)
	# 빛기둥: 대상이 카메라 시야 안일 때만, 문구와 같은 숨김 규칙(튜토리얼 점등·보스 체력바·대화…)을 따른다
	var cam: Camera2D = p.get_node_or_null("Camera")
	var center: Vector2 = cam.get_screen_center_position() if cam else p.global_position
	var in_view := absf(goal.x - center.x) < GUIDE_VIEW.x and absf(goal.y - center.y) < GUIDE_VIEW.y
	var show_beacon: bool = in_view and hud != null and hud.objective_gate() and Hud.objective_mode() != "off"   # 설정 "끔" 이면 문구도 빛기둥도 없다 (§5-16)
	_beacon_fade = move_toward(_beacon_fade, 1.0 if show_beacon else 0.0, d / 0.25)
	if _beacon_fade <= 0.01:
		_beacon.visible = false
		return
	_beacon.visible = true
	var kind: String = _obj.get("kind", "")
	_beacon.global_position = goal + Vector2(0, -_beacon_lift(kind) - 11.0)
	_beacon.scale = Vector2(1.0, 1.0)
	if kind == "exit":
		_beacon.scale.x = _beam_width(_obj["target"]) / 3.0
	_beacon.modulate.a = (0.35 + 0.35 * sin(TAU * _guide_t / BEACON_PERIOD)) * _beacon_fade


func _wet_feet(d: float) -> void:
	_splash_cd -= d
	var p: CharacterBody2D = $Player
	if _splash_cd > 0.0 or p.velocity.length() < 10.0 or not is_water(p.global_position + Vector2(0, 12)):  # screen → roughly the footprint just ahead
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
var _talking := 0          # dialogues running or queued; the hero/enemies stay frozen until the last one ends
var _talk_frozen: Array = []

func talk(lines: Array) -> void:
	$Player.locked = true
	_talking += 1
	# the world holds its breath while someone speaks: 요괴 don't get free hits during dialogue
	for e in get_tree().get_nodes_in_group("enemy") + get_tree().get_nodes_in_group("downed"):
		if e.is_physics_processing():
			e.set_physics_process(false)
			_talk_frozen.append(e)
	await dialog.say(lines)
	_talking -= 1
	if _talking > 0:
		return
	for e in _talk_frozen:
		if is_instance_valid(e):
			e.set_physics_process(true)
	_talk_frozen.clear()
	$Player.locked = false


## footprint → screen: depth is foreshortened by K (the camera looks down at an angle, HD-2D) and
## ground on tier t is drawn t*TIER px higher (art/ground3d.py bakes the same projection)
func lift(p: Vector2) -> Vector2:
	var rows: Array = meta["heights"]
	var cy := clampi(int(p.y / meta["ts"]), 0, rows.size() - 1)
	var cx := clampi(int(p.x / meta["ts"]), 0, String(rows[0]).length() - 1)
	var c := String(rows[cy])[cx]
	var t := 1.0 if not c.is_valid_int() else float(c)
	return Vector2(p.x, p.y * depth_k() - t * meta["tier"])


func depth_k() -> float:
	Game.depth_k = float(meta.get("k", 1.0))
	return Game.depth_k


## a footprint rect's size on screen
func lift_size(sz: Vector2) -> Vector2:
	return Vector2(sz.x, sz.y * depth_k())


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
	var extra: Array = []
	for wr in def.get("walls", []):   # hand-placed seals for holes in the baked cliff collision (lifted px)
		extra.append([wr.position.x, wr.position.y, wr.size.x, wr.size.y])
	for r in meta["collision"] + extra:
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
	shape.size = Vector2(half.x * 2, maxf(2.0, round(half.y * 2 * depth_k())))   # footprint depth is foreshortened
	col.shape = shape
	col.position = Vector2(0, -shape.size.y / 2.0)
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


## 성능: 그림자를 켠 등불 중 반경 안에 가림막(LightOccluder2D)이 하나도 없는 것은 그림자 패스를 끈다.
## 가림막이 없으면 그림자 결과가 같으므로 화면은 그대로이고, 등불마다 쓰이던 그림자 렌더(+PCF5 표본)만 사라진다.
## 소품은 레벨 생성 때 한 번만 놓이므로(_prop 호출처 하나) 생성 직후 한 번 계산하면 된다.
func _prune_shadows() -> void:
	if "--no-shadow-prune" in OS.get_cmdline_user_args():   # 측정용 훅: 최적화 전/후 비교
		return
	var occ_rects: Array[Rect2] = []
	for n in find_children("*", "LightOccluder2D", true, false):
		var o := n as LightOccluder2D
		var pts := o.occluder.polygon
		var lo := Vector2(INF, INF)
		var hi := Vector2(-INF, -INF)
		for v in pts:
			lo = lo.min(v)
			hi = hi.max(v)
		occ_rects.append(Rect2(o.global_position + lo, hi - lo))
	for l in flicker:
		if not l.shadow_enabled:
			continue
		var r: float = l.texture.get_width() * l.texture_scale * 0.5
		var box := Rect2(l.global_position - Vector2(r, r), Vector2(r, r) * 2.0)
		var hit := false
		for rc in occ_rects:
			if box.intersects(rc):
				hit = true
				break
		if not hit:
			l.shadow_enabled = false


## a light with no sprite: warms a window or lamp that is already painted into the ground picture
func _glow_light(at: Vector2, col: Color, energy: float, scl: float) -> void:
	var l := PointLight2D.new()
	l.texture = light_tex
	l.position = at
	l.color = col
	l.energy = energy
	l.texture_scale = scl
	l.height = 24.0
	l.set_meta("base", energy)
	add_child(l)
	flicker.append(l)


var flicker: Array[PointLight2D] = []
var _ash: CPUParticles2D
var _shafts_layer: CanvasLayer
var _post_mat: ShaderMaterial
var _cull_t := 0.0
var _cull_n := 0
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
## soft contact shadow: a smooth dark ellipse that grounds the figure (HD-2D 접지 그림자)
func _blob(parent: Node2D, half_w: float) -> void:
	var w := int(half_w * 2.6)
	var h := int(maxf(5, half_w * 0.9))
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	for y in h:
		for x in w:
			var d := Vector2((x + 0.5 - w / 2.0) / (w / 2.0), (y + 0.5 - h / 2.0) / (h / 2.0)).length()
			if d < 1.0:
				var a := 0.62 * pow(1.0 - d, 0.8)
				img.set_pixel(x, y, Color(0.02, 0.02, 0.06, snappedf(a, 0.1)))   # stepped so it stays pixel art
	var s := Sprite2D.new()
	s.texture = ImageTexture.create_from_image(img)
	s.position = Vector2(1, -1)
	s.z_index = -5
	s.z_as_relative = false
	parent.add_child(s)
	parent.move_child(s, 0)


func _process(d: float) -> void:
	if _beacon:
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
	_cull_t -= d
	if _cull_t <= 0.0:
		_cull_t = 0.1
		_cull_lights()
	for i in flicker.size():
		var l := flicker[i]
		if not l.visible:
			continue   # 시야 밖·폴백으로 꺼진 라이트는 깜빡임 계산도 건너뜀
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
	var amb: Color = cm.color
	var dark_k := clampf((0.42 - (amb.r * 0.3 + amb.g * 0.59 + amb.b * 0.11)) / 0.16, 0.0, 1.0)   # 어두운 맵(폐가·보스전 등)일수록 1
	pl.energy += 1.5 * dark_k   # 처용 가독성: 어두운 맵에서만 외곽 빛을 약하게 키운다 (아트팀)
	pl.texture_scale = 0.55 + 0.3 * dark_k
	pl.position = Vector2(0, -16)
	pl.height = 30.0
	$Player.add_child(pl)
	if dark_k > 0.0:   # 어두운 맵: 발밑 따뜻한 바닥 림라이트로 처용 실루엣을 바닥에서 분리 (아트팀)
		var rim := PointLight2D.new()
		rim.texture = light_tex
		rim.color = Color(1.0, 0.8, 0.55)
		rim.energy = 1.4 * dark_k
		rim.texture_scale = 0.4
		rim.position = Vector2(0, -4)
		rim.height = 12.0
		$Player.add_child(rim)
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
	_ash = ash
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
	_shafts_layer = shafts_layer
	add_child(shafts_layer)
	var post_layer := CanvasLayer.new()
	post_layer.layer = 10
	var post := ColorRect.new()
	post.set_anchors_preset(Control.PRESET_FULL_RECT)
	post.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var pm := ShaderMaterial.new()
	pm.shader = load("res://shaders/post.gdshader")
	post.material = pm
	_post_mat = pm
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


# ---------------------------------------------------------------- 화질 폴백 (Quality) · 라이트 시야 컬링
## 등급별 동시 활성 라이트 상한(시야 안). 상(2)은 상한 없음 — 화면이 절대 바뀌지 않는다.
const LIGHT_CAP := {2: 9999, 1: 6, 0: 3}
const ASH_KEEP := {2: 1.0, 1: 0.5, 0: 0.25}
var _ash_full := 0


func _on_quality(t: int, _old: int) -> void:
	# 순서: 라이트 상한 → 후처리 블룸 → 노멀맵 라이트 → 파티클 밀도 → 그림자 (+ 하 등급에선 빛줄기 끔)
	_cull_lights()
	if _post_mat != null:
		_post_mat.set_shader_parameter("bloom", 0.9 if t >= 2 else 0.0)
	_set_normal_maps(t >= 1)
	if _ash != null:
		if _ash_full == 0:
			_ash_full = _ash.amount
		_ash.amount = maxi(4, int(_ash_full * ASH_KEEP[t]))
	for l in flicker:
		if not l.has_meta("sh0"):
			l.set_meta("sh0", l.shadow_enabled)
		l.shadow_enabled = l.get_meta("sh0") and t >= 2
	if _shafts_layer != null:
		_shafts_layer.visible = t >= 1


## 노멀맵이 있는 스프라이트(CanvasTexture)를 라이트마다 노멀을 읽지 않는 평면 텍스처로 바꾸거나 되돌린다.
func _set_normal_maps(on: bool) -> void:
	for n in find_children("*", "Sprite2D", true, false):
		var s := n as Sprite2D
		if on:
			if s.has_meta("lit_tex"):
				s.texture = s.get_meta("lit_tex")
				s.remove_meta("lit_tex")
		elif s.texture is CanvasTexture and not s.has_meta("lit_tex"):
			var ct := s.texture as CanvasTexture
			if ct.normal_texture != null:
				s.set_meta("lit_tex", ct)
				s.texture = ct.diffuse_texture


## 시야(+라이트 반경+여유) 밖 라이트는 끈다 — 화면에 닿지 않으므로 기본 화면은 변하지 않는다.
## 등급이 낮으면 시야 안에서도 화면 중심에서 가까운 순으로 상한까지만 켠다.
func _cull_lights() -> void:
	var cam := $Player/Camera as Camera2D
	var vs := get_viewport_rect().size / cam.zoom
	var view := Rect2(cam.get_screen_center_position() - vs * 0.5, vs)   # 카메라 변환이 한 프레임 늦어도 정확하도록 직접 계산
	var center := view.get_center()
	var cap: int = LIGHT_CAP[Quality.tier]
	var inside: Array = []
	for l in flicker:
		var rng: float = l.texture.get_width() * l.texture_scale * 0.5
		var reach := view.grow(rng + 48.0)   # 48px: 0.1초 간격 갱신 + 카메라 스무딩 여유
		if reach.has_point(l.global_position + l.offset):
			inside.append(l)
		elif l.visible:
			l.visible = false
	if inside.size() > cap:
		inside.sort_custom(func(a, b): return a.global_position.distance_squared_to(center) < b.global_position.distance_squared_to(center))
	for i in inside.size():
		var on: bool = i < cap
		if (inside[i] as Light2D).visible != on:
			(inside[i] as Light2D).visible = on
	_cull_n += 1
	if Quality.tier == 0 and _cull_n % 10 == 0:
		_set_normal_maps(false)   # 하 등급 중 새로 생긴 스프라이트(적 등)도 평면화
