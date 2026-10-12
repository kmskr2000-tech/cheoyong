extends CharacterBody2D
## 처용: 8-direction movement, 4-facing walk animation, a three-hit 대금 combo (cut-out arm swung
## around the shoulder + spirit-wind slash) and a spinning dodge roll with after-images.

signal hit_landed(target: Node2D)
signal stats_changed(hp: float, max_hp: float, ki: float, max_ki: float)
signal died
signal respawned
signal sang(purified: int)
signal sin_changed(value: float)
signal talisman_changed(kind: String)

const SPEED := 72.0
const FRAME := Vector2i(64, 64)   # Drive 도트 시트 임포트(art/import_hero.py): 64x64 셀, 공격 이펙트가 들어갈 여유
const FEET_ROW := 58 # feet row inside the 64px cell; the node origin sits on it

# Sheet order written by art/import_hero.py (Drive 주인공 시트 → 87프레임). 70-73 피격(↓↑→←), 74-77 사망, 78-86 달리기(구르기).
const SHEET := {
	"down_idle": [18, 18, 18, 18, 18, 18, 18, 18, 18, 18, 18, 19, 19, 19, 19, 19, 19, 19], "up_idle": [1], "right_idle": [2],  # 3/4 stance + breath
	"downl_idle": [20, 20, 20, 20, 20, 20, 20, 20, 20, 20, 20, 21, 21, 21, 21, 21, 21, 21],  # the same, facing left
	"down_walk": [3, 4, 5, 6], "up_walk": [7, 8, 9, 10], "right_walk": [11, 12, 13, 14],
	"down_attack": [15], "up_attack": [16], "right_attack": [17],
}
## shoulder pivot of the weapon arm per facing (relative to the feet), and whether the arm is in front
const SHOULDER := {"down": [Vector2(-9, -25), 1], "up": [Vector2(8, -25), -1], "right": [Vector2(-3, -26), 1], "left": [Vector2(3, -26), 1]}
const FACE_ANGLE := {"right": 0.0, "down": PI / 2, "left": PI, "up": -PI / 2}

## combo: [swing from, swing to] relative to facing (radians), duration, damage, reach
const COMBO := [
	{"from": -1.9, "to": 1.2, "time": 0.26, "dmg": 10, "reach": 34.0},
	{"from": 1.5, "to": -1.4, "time": 0.26, "dmg": 10, "reach": 34.0},
	{"from": 0.0, "to": 0.0, "time": 0.34, "dmg": 18, "reach": 42.0, "thrust": true},
]
const ROLL_TIME := 0.32
const ROLL_SPEED := 200.0
const CT := preload("res://scripts/combat_tuning.gd")   # 전투 상수 (CS-08)

@onready var sprite: AnimatedSprite2D = $Sprite
var arm: Sprite2D
var slash: Sprite2D
var facing := "down"
var locked := false # dialogue / cutscene
var _free_t := 0.0     # seconds since last unlocked (확인 키 상호작용 쿨다운)

var state := "move"
var t := 0.0
var combo := 0
var queued := false
var hit_done := false
var roll_dir := Vector2.ZERO
var ghost_t := 0.0
var invuln := false

var max_hp := 100.0
var hp := 100.0
var max_ki := 100.0
var ki := 100.0
var spawn := Vector2.ZERO
var interact: Callable          # level hook: returns true if something was talked to / examined
var gentle_hits := 0            # tutorial: the next N hits only knock back (no damage)
var stun_t := 0.0               # 처녀귀신의 울음: frozen in place
var slow_t := 0.0               # 손각시의 붉은 실 / 물귀신: half speed
var pull_t := 0.0               # dragged toward pull_to (물귀신, 붉은 실)
var pull_to := Vector2.ZERO
var _stun_fx: Label
var haste_t := 0.0              # 연풍
var _last_h := 1.0              # last horizontal direction (the 3/4 idle faces it)
var shinmyeong := 0.0                  # 신명: fills with landed blows and 받아넘기기; full → 처용무
const SIN_PER_HIT := 2.5
var parry_bonus := false        # 받아넘기기: the next blow lands double
var parry_chain := 0
var parry_chain_t := 0.0
var _parry_cd := 0.0
var height_t := 0.0             # 신명 고조 (받아넘기기 3연속): faster feet and swings
var shield := 0                 # 수호부: blows it will still turn aside
var shield_t := 0.0
var _guard_t := 0.0             # CS-03: 수호부가 막은 직후 GUARD_T 동안 같은 공격의 기절·끌림·둔화를 덮는다
var swap_cd := 0.0
var ult_t := 0.0                # 처용무
var _ult_tick := 0.0
var _burst_ready := true        # 신명폭발: once per filling
var _last_roll_end := -10.0
var _dash := false     # 학의 질주: a second roll right after the first
var _roll_lock_t := 0.0       # CS-01: 구르기 종료 후 재구르기 잠금 (delta 로 감소)
var _roll_queued := false     # CS-01: 잠금 끝 ROLL_BUFFER 전부터 저장된 선입력
var _charge_c := 0.0          # CS-02: 강 베기 충전 시간 (state "charge" 진입 후 경과)
var _charge_hold := false     # CS-02: 이 눌림이 베기를 시작시켰다(말 걸기에 쓰인 눌림은 충전하지 않는다)
var _hold_t := 0.0            # CS-02: 베기 버튼을 누르고 있는 시간
var _charge_full := false
var _charge_fx: Line2D
const ULT_TIME := 6.0
const TAL_COST := {"fire": 25.0, "bind": 30.0, "guard": 20.0, "wave": 20.0}
const TAL_NAME := {"fire": "화염부", "bind": "결박부", "guard": "수호부", "wave": "파동부"}
var rhythm := 0                 # 장단맞춤: presses that landed on the beat in this combo
const SONG_TIME := 1.1
const SONG_RANGE := 90.0


func _ready() -> void:
	max_hp = Game.max_hp()
	hp = max_hp
	for a in OS.get_cmdline_user_args():   # test hook: --sin=100
		if a.begins_with("--sin="):
			shinmyeong = float(a.get_slice("=", 1))
		if a == "--test-hurt":   # 스프라이트 확인용: 0.6초 뒤 맞는다(피해 0)
			_test_after_unlock(func(): gentle_hits = 1; hurt(5, Vector2.LEFT))
		if a == "--test-die":    # 스프라이트 확인용: 0.6초 뒤 쓰러진다
			_test_after_unlock(func(): _die())
		if a == "--test-charge":   # CS-13: 베기 버튼을 1.5초 눌러 충전(0.45 진입 + 0.9 만충) 후 놓아 강 베기를 쓴다
			_test_after_unlock(func():
				Input.action_press("attack")
				await get_tree().create_timer(1.5).timeout
				Input.action_release("attack"))
		if a == "--test-parry":    # CS-13: 구르기 시작 0.05초 뒤 인공 근접 접촉 → 받아넘기기
			_test_after_unlock(func():
				Input.action_press("roll")
				await get_tree().create_timer(0.05).timeout
				Input.action_release("roll")
				await get_tree().create_timer(0.05).timeout
				hurt(8, Vector2.LEFT, true))
	Game.leveled.connect(_on_leveled)
	Game.skills_changed.connect(func():  # 심해의 인내 raises the ceiling at once
		var gain := Game.max_hp() - max_hp
		max_hp = Game.max_hp()
		hp = minf(max_hp, hp + maxf(0.0, gain))
		stats_changed.emit(hp, max_hp, ki, max_ki))
	var tex: Texture2D = Tex.lit("res://assets/sprites/cheoyong.png")
	var frames := SpriteFrames.new()
	frames.remove_animation("default")
	for anim in SHEET:
		frames.add_animation(anim)
		frames.set_animation_loop(anim, true)
		frames.set_animation_speed(anim, 8.0)
		for i in SHEET[anim]:
			var at := AtlasTexture.new()
			at.atlas = tex
			at.region = Rect2(i * FRAME.x, 0, FRAME.x, FRAME.y)
			frames.add_frame(anim, at)
	# rendered motion (art/hero.py): attacks per facing and combo hit, the 춤 turn, the song
	var dirs := ["down", "up", "right", "left"]
	for d in 4:
		for c in 3:
			_add_anim(frames, tex, "%s_atk%d" % [dirs[d], c], [22 + d * 9 + c * 3, 23 + d * 9 + c * 3, 24 + d * 9 + c * 3])
		_add_anim(frames, tex, dirs[d] + "_song", [66 + d])
	_add_anim(frames, tex, "spin", [58, 59, 60, 61, 62, 63, 64, 65])
	for d in 4:
		_add_anim(frames, tex, dirs[d] + "_hurt", [70 + d])
	_add_anim(frames, tex, "die", [74, 75, 76, 77])
	for d in 3:
		_add_anim(frames, tex, dirs[d] + "_run", [78 + d * 3, 79 + d * 3, 80 + d * 3])
		_add_anim(frames, tex, dirs[d] + "_roll", [87 + d * 6, 88 + d * 6, 89 + d * 6, 90 + d * 6, 91 + d * 6, 92 + d * 6])  # 구르기 전용 컷(art/import_hero.py roll_cells)
	sprite.sprite_frames = frames
	sprite.offset = Vector2(0, FRAME.y / 2.0 - FEET_ROW)
	sprite.play("down_idle")
	spawn = position
	arm = Sprite2D.new()
	arm.texture = Tex.lit("res://assets/sprites/cheoyong_arm.png")
	arm.centered = false
	arm.offset = Vector2(-1, -4) # shoulder pivot inside the arm image
	arm.visible = false
	add_child(arm)
	slash = Sprite2D.new()
	slash.texture = load("res://assets/fx/slash.png")
	slash.hframes = 4
	var add := CanvasItemMaterial.new()
	add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	add.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	slash.material = add
	slash.modulate = Color(1, 1, 1, 0.55)   # 새 공격 컷에 검기가 이미 그려져 있다: 덧그림은 옅게
	slash.visible = false
	slash.z_index = 40 # effects draw over the y-sorted world
	slash.z_as_relative = false
	add_child(slash)


## 스프라이트 확인용 훅: 오프닝 잠금이 풀리고 0.6초 뒤에 실행
func _test_after_unlock(fn: Callable) -> void:
	while locked or not is_inside_tree():
		await get_tree().process_frame
	await get_tree().create_timer(0.6).timeout
	fn.call()


func _add_anim(frames: SpriteFrames, tex: Texture2D, anim: String, idx: Array) -> void:
	frames.add_animation(anim)
	frames.set_animation_loop(anim, false)
	for i in idx:
		var at := AtlasTexture.new()
		at.atlas = tex
		at.region = Rect2(i * FRAME.x, 0, FRAME.x, FRAME.y)
		frames.add_frame(anim, at)


## show one frame of a rendered pose (attack, turn, song) — no playback, the state machine drives it
func _pose(anim: String, f: int) -> void:
	if sprite.animation != anim:
		sprite.animation = anim
	sprite.pause()
	sprite.frame = f
	sprite.flip_h = false


func _physics_process(delta: float) -> void:
	t += delta
	var dir := Vector2.ZERO if locked else Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if state == "dead":
		return
	_free_t = 0.0 if locked else _free_t + delta   # 대사가 끝난 뒤 같은 확인 눌림이 곧바로 다시 말을 거는 일 방지
	slow_t = maxf(0.0, slow_t - delta)
	haste_t = maxf(0.0, haste_t - delta)
	height_t = maxf(0.0, height_t - delta)
	swap_cd = maxf(0.0, swap_cd - delta)
	_parry_cd = maxf(0.0, _parry_cd - delta)
	_guard_t = maxf(0.0, _guard_t - delta)
	parry_chain_t -= delta
	if parry_chain_t <= 0.0:
		parry_chain = 0
	if shield_t > 0.0:
		shield_t -= delta
		if shield_t <= 0.0:
			shield = 0
	if ult_t > 0.0:
		_ult(delta, dir)
		return
	pull_t = maxf(0.0, pull_t - delta)
	if stun_t > 0.0:
		stun_t -= delta
		sprite.position.x = sin(t * 60.0) * 0.8
		if _stun_fx:
			_stun_fx.visible = stun_t > 0.0
		if stun_t > 0.0:
			velocity = _pull_vel()
			_slide()
			return
		sprite.position.x = 0.0
	if not locked and Input.is_action_just_pressed("talisman") and state == "move":
		_talisman()
	if not locked and Input.is_action_just_pressed("swap"):
		swap_talisman()
	if not locked and Input.is_action_just_pressed("dance") and state in ["move", "attack", "charge", "slash"]:
		dance()
	if not locked and Input.is_action_just_pressed("song") and state == "move" and Game.flag("flute"):
		_start_song()
	_roll_lock_t = maxf(0.0, _roll_lock_t - delta)
	if not locked and Input.is_action_just_pressed("roll"):
		_roll_input(dir)
	elif not locked and _roll_queued and _roll_lock_t <= 0.0:
		_roll_queued = false
		_roll_input(dir)   # 선입력이 잠금이 끝나자마자 실행된다
	elif not locked and state == "move" and _free_t > 0.3 and Input.is_action_just_pressed("confirm") \
			and interact.is_valid() and interact.call():
		return   # 키보드 확인(Z/Enter/Space)으로도 말 걸기·휴식·조사 (공격 버튼 외)
	elif not locked and Input.is_action_just_pressed("attack"):
		if state == "attack":
			if not queued and Game.has_skill("jangdan") and t >= _swing_time() * 0.55:
				rhythm += 1  # 장단맞춤: pressed as the swing settles, not mashed
			queued = true
			_charge_hold = true   # 누르고 있으면 이 스윙이 끝난 뒤 충전 대기로 이어진다
			_hold_t = 0.0
		elif state == "move":
			if interact.is_valid() and interact.call():
				return   # 말 걸기에 쓰인 눌림: 공격도 충전도 일어나지 않는다
			combo = 0
			rhythm = 0
			_start_attack()
			_charge_hold = true
			_hold_t = 0.0
	_update_charge_hold(delta)
	match state:
		"move": _move(dir)
		"attack": _attack(delta)
		"charge": _charge(delta, dir)
		"slash": _slash(delta)
		"roll": _roll(delta)
		"song": _song(delta)


## CS-01: 구르기 입력. 구르기 잠금(ROLL_LOCK) 중이면 끝 ROLL_BUFFER 안의 입력만 선입력으로 저장하고 그보다 이른 입력은 버린다.
## 학의 질주(hak)의 연속 구르기는 잠금을 무시한다.
func _roll_input(dir: Vector2) -> void:
	if state == "roll":
		if Game.has_skill("hak") and not _dash and t > 0.1:
			_start_roll(dir, true)   # 학의 질주: a second tap mid-roll
		return
	var dash := Game.has_skill("hak") and t_now() - _last_roll_end < 0.3
	if state == "charge" and _charge_c >= CT.CHARGE_MIN:
		return   # CS-02: 힘을 모은 몸은 뜻대로 안 움직인다
	if dash or _roll_lock_t <= 0.0:
		_roll_queued = false
		_start_roll(dir, dash)
	else:
		_roll_queued = _roll_lock_t <= CT.ROLL_BUFFER


func _move(dir: Vector2) -> void:
	velocity = dir * SPEED * (0.5 if slow_t > 0.0 else 1.0) * (1.25 if haste_t > 0.0 else 1.0) * (1.2 if height_t > 0.0 else 1.0) + _pull_vel()
	_slide()
	if dir != Vector2.ZERO:
		_face(dir)
	if dir.x != 0.0:
		_last_h = signf(dir.x)
	if hurt_pose_t > 0.0:   # 피격 포즈: 드라이브 시트의 움켜쥔 가슴 컷
		_pose(facing + "_hurt", 0)
		return
	var row := "right" if facing == "left" else facing
	var anim := row + ("_walk" if dir != Vector2.ZERO else "_idle")
	if anim == "down_idle" and _last_h < 0.0:
		anim = "downl_idle"   # the 3/4 idle turns toward the side he last moved to
	sprite.flip_h = facing == "left"
	sprite.rotation = 0.0
	sprite.scale = Vector2.ONE
	if sprite.animation != anim:
		sprite.play(anim)


func _face(dir: Vector2) -> void:
	if absf(dir.x) > absf(dir.y) + 0.1:
		facing = "right" if dir.x > 0 else "left"
	else:
		facing = "down" if dir.y > 0 else "up"


# ---------------------------------------------------------------- attack
func _start_attack() -> void:
	Audio.sfx("slash", -4.0)
	var dir := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if dir != Vector2.ZERO:
		_face(dir)
	else:
		# auto-aim for touch play: without a stick direction, turn toward the nearest foe in reach
		var best: Node2D = null
		var bd := 70.0
		for e in get_tree().get_nodes_in_group("enemy"):
			var dd: float = (e.global_position - global_position).length()
			if dd < bd:
				bd = dd; best = e
		if best:
			_face(best.global_position - global_position)
	state = "attack"
	t = 0.0
	queued = false
	hit_done = false
	_pose("%s_atk%d" % [facing, combo], 0)
	arm.visible = false
	slash.visible = false


func _attack(delta: float) -> void:
	var c: Dictionary = COMBO[combo]
	var dur := _swing_time()
	var k := clampf(t / dur, 0.0, 1.0)
	var base: float = FACE_ANGLE[facing]
	var mirror := -1.0 if facing == "left" or facing == "up" else 1.0
	var lunge := 0.0
	# wind-up 0-25%, strike 25-55%, follow-through: rendered poses (art/hero.py ATTACK)
	_pose("%s_atk%d" % [facing, combo], 0 if k < 0.25 else (1 if k < 0.55 else 2))
	if c.get("thrust", false):
		lunge = 110.0 if k > 0.3 and k < 0.55 else 0.0
	velocity = Vector2.from_angle(base) * lunge
	_slide()
	# spirit-wind crescent during the sweep
	var swing := k > 0.25 and k < 0.8
	slash.visible = swing
	if swing:
		var fk := (k - 0.25) / 0.55
		slash.frame = mini(3, int(fk * 4.0))
		slash.position = Vector2(0, -16) + Vector2.from_angle(base) * (10.0 + (5.0 if c.get("thrust", false) else 0.0))
		slash.rotation = base
		slash.scale = Vector2(0.65, 0.4) if c.get("thrust", false) else Vector2(0.8, 0.8)   # sized to the ~36px figure
		slash.flip_v = (c["to"] < c["from"]) != (mirror < 0)
	if not hit_done and k > 0.4:
		hit_done = true
		_resolve_hit(c, base)
	if k >= 1.0:
		if queued and combo < COMBO.size() - 1:
			combo += 1
			_start_attack()
		else:
			_end_attack(true)   # 버튼이 계속 눌려 있으면 충전 대기(_charge_hold)가 이어진다


func _swing_time() -> float:
	return COMBO[combo]["time"] / (1.4 if _frenzy() else 1.0) / (1.3 if height_t > 0.0 else 1.0)


## 무아지경: at the edge of falling he moves faster and feels less
func _frenzy() -> bool:
	return Game.has_skill("muaji") and hp <= max_hp * 0.3


func _end_attack(keep_hold := false) -> void:
	state = "move"
	arm.visible = false
	slash.visible = false
	combo = 0
	_charge_c = 0.0   # 맞음·기절·끌림·구르기·노래 등 어떤 끊김도 충전을 버린다
	_charge_full = false
	if _charge_fx:
		_charge_fx.visible = false
	if not keep_hold:
		_charge_hold = false
		_hold_t = 0.0


func _resolve_hit(c: Dictionary, base: float) -> void:
	var origin := global_position + Vector2(0, -14)
	var last := combo == COMBO.size() - 1
	var whirl := last and Game.has_skill("geommu")   # 검무: the thrust becomes a full turn
	var reach: float = c["reach"] + (6.0 if whirl else 0.0)
	var mult := Game.attack_mult()
	if last and rhythm >= 2:   # 장단맞춤
		mult *= 1.3
		Game.float_text(get_parent(), global_position + Vector2(0, -40), ["얼쑤!"])
	if parry_bonus:   # 받아넘기기 일격
		mult *= 2.0
	if whirl:
		_whirl_fx()
	if Game.has_skill("eumpa"):
		SoundWave.fire(self, base, int(round(5 * Game.attack_mult())))
	for e in get_tree().get_nodes_in_group("enemy"):
		var to: Vector2 = (e.global_position + Vector2(0, -10)) - origin
		if to.length() > reach:
			continue
		if not whirl and absf(wrapf(to.angle() - base, -PI, PI)) > 1.3 and to.length() > 10:
			continue
		if e.has_method("take_hit"):
			var m := mult * _bind_mult(e)   # 결박된 적에 대한 베기 ×1.2 (결박부·진 ×1.4)
			e.take_hit(int(round(c["dmg"] * m)), to.normalized(), last or parry_bonus)
			add_sin(SIN_PER_HIT)
			_spark(e.global_position + Vector2(0, -12))
			hit_landed.emit(e)
			_hit_stop(CT.HITSTOP_HEAVY if (last or parry_bonus) else CT.HITSTOP_LIGHT)
	if parry_bonus:
		parry_bonus = false


## 검무: a ring of wind around him
func _whirl_fx() -> void:
	var ring := Line2D.new()
	var pts := PackedVector2Array()
	for i in 25:
		pts.append(Vector2.from_angle(i * TAU / 24.0) * Vector2(1.0, 0.6) * 20.0)
	ring.points = pts
	ring.width = 3.0
	ring.default_color = Color(0.75, 0.95, 1.0, 0.8)
	ring.material = slash.material
	ring.position = Vector2(0, -12)
	ring.z_index = 40
	ring.z_as_relative = false
	add_child(ring)
	var tw := ring.create_tween().set_parallel()
	tw.tween_property(ring, "scale", Vector2(2.4, 2.4), 0.25)
	tw.tween_property(ring, "modulate:a", 0.0, 0.25)
	tw.chain().tween_callback(ring.queue_free)


func _spark(at: Vector2) -> void:
	var s := Sprite2D.new()
	s.texture = load("res://assets/fx/spark.png")
	s.hframes = 3
	s.material = slash.material
	s.global_position = at
	s.z_index = 41
	s.z_as_relative = false
	get_parent().add_child(s)
	var tw := s.create_tween()
	tw.tween_property(s, "frame", 2, 0.12)
	tw.tween_callback(s.queue_free)


# ---------------------------------------------------------------- 강 베기 (D2, 차징)
## 베기 버튼을 계속 누르고 있는 시간을 잰다. 버튼을 떼거나 컷신이 되면 대기를 버리고, CHARGE_ENTER 에 이르면 충전 상태로 들어간다.
func _update_charge_hold(delta: float) -> void:
	if not _charge_hold:
		return
	if locked or not Input.is_action_pressed("attack"):
		_charge_hold = false
		_hold_t = 0.0
		return
	_hold_t += delta
	if state == "move" and _hold_t >= CT.CHARGE_ENTER:
		_enter_charge()


func _enter_charge() -> void:
	_charge_hold = false
	_hold_t = 0.0
	state = "charge"
	_charge_c = 0.0
	_charge_full = false
	t = 0.0
	velocity = Vector2.ZERO
	arm.visible = false
	slash.visible = false
	_pose("%s_atk2" % facing, 0)   # 대금을 뒤로 당긴 자세
	Audio.sfx("slash", -12.0, 0.2)


func _charge(delta: float, dir: Vector2) -> void:
	if locked:
		_end_attack()   # 컷신·대사 중에는 충전을 버린다
		return
	if dir != Vector2.ZERO:
		_face(dir)   # 이동은 못 하지만 스틱으로 조준한다
	velocity = Vector2.ZERO
	_pose("%s_atk2" % facing, 0)
	_charge_c += delta
	_charge_fx_update()
	if _charge_c >= CT.CHARGE_FULL and not _charge_full:
		_charge_full = true   # 만충 번쩍임 + 진동
		_ring_fx(Color(1.0, 0.95, 0.7), 30.0, 0.25)
		_haptic()
	if not Input.is_action_pressed("attack"):
		if _charge_c >= CT.CHARGE_MIN:
			_release_charge()
		else:
			_end_attack()   # 너무 일찍 뗌: 조용히 취소(후딜·손실 없음)
	elif _charge_c >= CT.CHARGE_MAX:
		_release_charge()   # 손가락이 멈춘 경우의 무한 대기 방지


## 발치 충전 링: 눈이 전투에 있어도 보인다 (0.35 지점에 표식)
func _charge_fx_update() -> void:
	if _charge_fx == null:
		_charge_fx = Line2D.new()
		_charge_fx.width = 1.5
		_charge_fx.material = slash.material
		_charge_fx.z_index = 40
		_charge_fx.z_as_relative = false
		_charge_fx.position = Vector2(0, -4)
		add_child(_charge_fx)
	_charge_fx.visible = true
	var k := clampf(_charge_c / CT.CHARGE_FULL, 0.0, 1.0)
	var pts := PackedVector2Array()
	var n := maxi(2, int(k * 32.0))
	for i in n + 1:
		pts.append(Vector2.from_angle(-PI / 2 + TAU * k * float(i) / float(n)) * Vector2(15.0, 8.0))
	_charge_fx.points = pts
	_charge_fx.default_color = Color(1.0, 0.95, 0.65, 0.95) if _charge_c >= CT.CHARGE_MIN else Color(0.7, 0.8, 1.0, 0.6)


func charge_ratio() -> float:
	return clampf(_charge_c / CT.CHARGE_FULL, 0.0, 1.0) if state == "charge" else 0.0


func _bind_mult(e: Node) -> float:
	if e.get("bind_t") != null and e.bind_t > 0.0:
		return CT.BIND_HIT_MULT_SKILL if Game.has_skill("gyeolbak2") else CT.BIND_HIT_MULT
	return 1.0


## 손을 뗐다: 충전량 tt(0=최소, 1=만충)로 강 베기. 장갑 무시·예고 끊기·넉백. 소리는 쓰지 않는다.
func _release_charge() -> void:
	var tt := clampf((_charge_c - CT.CHARGE_MIN) / (CT.CHARGE_FULL - CT.CHARGE_MIN), 0.0, 1.0)
	var dir := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if dir != Vector2.ZERO:
		_face(dir)
	else:
		var best: Node2D = null
		var bd := CT.CHARGE_AUTOAIM   # 스틱이 없으면 발동 시점에 가까운 적을 향한다
		for e in get_tree().get_nodes_in_group("enemy"):
			var dd: float = (e.global_position - global_position).length()
			if dd < bd:
				bd = dd; best = e
		if best:
			_face(best.global_position - global_position)
	_charge_c = 0.0
	_charge_full = false
	if _charge_fx:
		_charge_fx.visible = false
	state = "slash"
	t = 0.0
	hit_done = true
	var base: float = FACE_ANGLE[facing]
	var origin := global_position + Vector2(0, -14)
	var reach := CT.CHARGE_REACH_MIN + CT.CHARGE_REACH_SPAN * tt
	var arc := CT.CHARGE_ARC_MIN + CT.CHARGE_ARC_SPAN * tt
	var mult := Game.attack_mult() * (1.5 if parry_bonus else 1.0)
	parry_bonus = false
	Audio.sfx("slash", 0.0, 0.0)
	_slash_scale = 1.0 + 0.6 * tt
	if tt >= 1.0:
		_haptic()
	for e in get_tree().get_nodes_in_group("enemy"):
		var to: Vector2 = (e.global_position + Vector2(0, -10)) - origin
		if to.length() > reach:
			continue
		if absf(wrapf(to.angle() - base, -PI, PI)) > arc and to.length() > 10:
			continue
		if e.has_method("take_hit"):
			var dmg := int(round(CT.CHARGE_BASE_DMG * (CT.CHARGE_DMG_BASE + CT.CHARGE_DMG_SPAN * tt) * mult * _bind_mult(e)))
			e.take_hit(dmg, to.normalized(), true, false, true, tt)
			add_sin(CT.SIN_PER_CHARGED)
			_spark(e.global_position + Vector2(0, -12))
			hit_landed.emit(e)
			_hit_stop(CT.HITSTOP_HEAVY)
	slash_base = base


var _slash_scale := 1.0
var _hitstop_until := 0


## 적중 정지: 짧게 시간을 거의 멈춘다. 받아넘기기 슬로모(time_scale≠1)나 다른 정지 중이면 겹치지 않는다.
func _hit_stop(frames: int) -> void:
	if frames <= 0 or not is_equal_approx(Engine.time_scale, 1.0) or Time.get_ticks_msec() < _hitstop_until:
		return
	var sec := float(frames) / 60.0
	_hitstop_until = Time.get_ticks_msec() + int(sec * 1000.0) + 20   # 같은 정지가 연달아 걸리지 않게(다중 적중)
	Engine.time_scale = 0.05
	get_tree().create_timer(sec * 0.05, true, false, false).timeout.connect(func():   # 게임 시계 기준(time_scale 0.05 에서 sec*0.05 = 실시간 sec): 고정 프레임 하네스에서도 같은 프레임 수
		if is_equal_approx(Engine.time_scale, 0.05):
			Engine.time_scale = 1.0)
var slash_base := 0.0


## 강 베기 직후 후딜 (구르기로 취소 가능)
func _slash(delta: float) -> void:
	var k := clampf(t / CT.CHARGE_RECOVER, 0.0, 1.0)
	velocity = Vector2.ZERO
	_pose("%s_atk2" % facing, 1 if k < 0.5 else 2)
	var swing := k < 0.6
	slash.visible = swing
	if swing:
		slash.frame = mini(3, int(k / 0.6 * 4.0))
		slash.position = Vector2(0, -16) + Vector2.from_angle(slash_base) * 12.0
		slash.rotation = slash_base
		slash.scale = Vector2(0.9, 0.9) * _slash_scale
	if k >= 1.0:
		_end_attack()


# ---------------------------------------------------------------- getting hit
var hurt_t := 0.0
var hurt_pose_t := 0.0


## melee: 근접 접촉 공격(받아넘기기 대상). kind: "miasma" = 독기 틱(수호부가 충전 소모 없이 무시).
func hurt(dmg: int, dir: Vector2, melee := false, kind := "") -> void:
	if ult_t > 0.0 or state == "dead":
		return
	if invuln:
		if state == "roll" and melee and t <= _parry_window():
			_parry(dir)
		return
	if kind == "miasma" and shield > 0:
		return   # 독기 틱: 수호부가 켜져 있는 동안 충전 소모 없이 0 피해로 무시 (D3, 10초 지속)
	if hurt_t > 0.0:
		return
	if shield > 0:   # 수호부
		shield -= 1
		_guard_t = CT.GUARD_T
		if shield <= 0:
			shield_t = 0.0
			ki = minf(max_ki, ki + CT.GUARD_REFUND)   # 직접 타격을 막아 사라질 때 환급 (마지막 충전에서 1회)
			stats_changed.emit(hp, max_hp, ki, max_ki)
			Game.float_text(get_parent(), global_position + Vector2(0, -44), ["+소리"])
			_haptic()
		hurt_t = 0.5
		Audio.sfx("block", -2.0)
		_ring_fx(Color(1.0, 0.9, 0.55), 26.0, 0.35)
		if Game.has_skill("suho2"):   # 수호부·진: the blow goes back as sound
			SoundWave.fire(self, (-dir).angle(), int(round(10 * Game.attack_mult())))
		return
	hurt_t = 0.6
	hurt_pose_t = 0.3
	Audio.sfx("hurt", -2.0)
	dmg = int(ceil(dmg * Game.damage_taken_mult() * (0.8 if _frenzy() else 1.0)))   # 탈·가호·무아지경
	if Game.has_skill("simhae"):  # 심해의 인내
		ki = minf(max_ki, ki + 5.0)
	if gentle_hits > 0:
		gentle_hits -= 1  # 벌 없이 배운다: early hits only push him back
		dmg = 0
	hp = maxf(0.0, hp - dmg)
	if dmg > 0:
		add_sin(-CT.SIN_PENALTY_HIT)   # 피해를 입으면 신명이 흩어진다 (대충 싸우면 처용무가 안 온다)
	stats_changed.emit(hp, max_hp, ki, max_ki)
	if hp <= 0.0:
		_die()
		return
	_end_attack()
	velocity = dir * 160.0
	_slide()
	var tw := create_tween()
	for i in 3:
		tw.tween_property(sprite, "modulate", Color(1.8, 0.5, 0.5), 0.05)
		tw.tween_property(sprite, "modulate", Color.WHITE, 0.08)


func _process(delta: float) -> void:
	hurt_t = maxf(0.0, hurt_t - delta)
	hurt_pose_t = maxf(0.0, hurt_pose_t - delta)
	if ki < max_ki and state != "dead":
		ki = minf(max_ki, ki + CT.KI_REGEN * delta)
		stats_changed.emit(hp, max_hp, ki, max_ki)


func _die() -> void:
	Game.record_death()
	_end_attack()   # resets state to "move" — must run before "dead" is set
	state = "dead"
	velocity = Vector2.ZERO
	died.emit()
	var tw := create_tween()
	sprite.rotation = 0.0
	sprite.animation = "die"   # 쓰러지는 컷(무릎→엎드림): 오른쪽을 향한 시트, 왼쪽이면 뒤집는다
	sprite.pause()
	sprite.flip_h = facing == "left"
	sprite.frame = 0
	tw.tween_property(sprite, "frame", 3, 0.5)
	tw.parallel().tween_property(sprite, "modulate", Color(0.7, 0.75, 0.95, 0.9), 0.6)
	tw.tween_interval(1.4)
	tw.tween_callback(_respawn)


func _respawn() -> void:
	position = spawn
	hp = max_hp
	ki = max_ki
	sprite.rotation = 0.0
	sprite.modulate = Color.WHITE
	state = "move"
	hurt_t = 1.0
	stats_changed.emit(hp, max_hp, ki, max_ki)
	respawned.emit()


# ---------------------------------------------------------------- 처용가 (the purifying song)
## true when something nearby lies in 탁기 waiting to be sung clean
func can_sing() -> bool:
	if not Game.flag("flute"):
		return false
	for d in get_tree().get_nodes_in_group("downed"):
		if d.global_position.distance_to(global_position) < song_range():
			return true
	return false


## play 처용가 on cue (cutscenes)
func sing() -> void:
	if state == "move":
		_start_song()


func _start_song() -> void:
	Audio.sfx("song", -1.0, 0.0)
	_end_attack()
	state = "song"
	t = 0.0
	velocity = Vector2.ZERO
	_pose(facing + "_song", 0)   # the 대금 held level at the lips
	arm.visible = false
	_song_t = 0.0


var _song_t := 0.0
const OBANG := [Color(0.35, 0.55, 1.0), Color(1.0, 0.3, 0.25), Color(1.0, 0.85, 0.3), Color(0.95, 0.95, 1.0), Color(0.3, 0.9, 0.6)]


func _song(delta: float) -> void:
	_song_t -= delta
	if _song_t <= 0.0:
		_song_t = 0.2
		_note()
	if t >= SONG_TIME:
		# 오방색 ripples spread out and every 탁기-wreathed body nearby is sung clean
		for i in 5:
			_ripple(OBANG[i], i * 0.08)
		var n := 0
		var heal_hp := 0
		var gain_ki := 0.0
		for d in get_tree().get_nodes_in_group("downed"):
			if d.global_position.distance_to(global_position) < song_range():
				var tier := _purify_tier(d)
				d.purify()
				n += 1
				if tier == "normal":   # 정화가 전투 중 회복의 유일한 길 (보스 제외)
					heal_hp += int(max_hp * CT.HP_PURIFY_NORMAL)
					gain_ki += CT.KI_PURIFY_NORMAL
				elif tier == "elite":
					heal_hp += int(max_hp * CT.HP_PURIFY_ELITE)
					gain_ki += CT.KI_PURIFY_ELITE
		if heal_hp > 0 or gain_ki > 0.0:
			ki = minf(max_ki, ki + gain_ki)
			heal(heal_hp)
			Game.float_text(get_parent(), global_position + Vector2(0, -34), ["+%d 체력 +%d 소리" % [heal_hp, int(gain_ki)]])
		arm.visible = false
		state = "move"
		sang.emit(n)


## 정화 보상 등급: "normal"/"elite", 보상 대상이 아니면 ""
func _purify_tier(d: Node) -> String:
	var k = d.get("kind")
	if k == null or d.get("is_clone") == true or d.get("state") != "downed":
		return ""
	var tier: String = Bestiary.entry(k)["tier"]
	return tier if tier in ["normal", "elite"] else ""


func gain_ki(n: float) -> void:
	ki = minf(max_ki, ki + n)
	stats_changed.emit(hp, max_hp, ki, max_ki)


func heal(n: float) -> void:
	if state == "dead" or n <= 0.0:
		return
	hp = minf(max_hp, hp + n)
	stats_changed.emit(hp, max_hp, ki, max_ki)


func _note() -> void:
	var nt := Sprite2D.new()
	nt.texture = load("res://assets/fx/spark.png")
	nt.hframes = 3
	nt.frame = 0
	nt.material = slash.material
	nt.modulate = OBANG[randi() % 5]
	nt.position = position + Vector2(randf_range(-8, 8) + (10 if facing == "right" else -10 if facing == "left" else 0), -30)
	nt.z_index = 41
	nt.z_as_relative = false
	get_parent().add_child(nt)
	var tw := nt.create_tween().set_parallel()
	tw.tween_property(nt, "position", nt.position + Vector2(randf_range(-10, 10), -28), 0.9)
	tw.tween_property(nt, "modulate:a", 0.0, 0.9)
	tw.chain().tween_callback(nt.queue_free)


func _ripple(col: Color, delay: float) -> void:
	var ring := Line2D.new()
	ring.width = 2.0
	ring.default_color = col
	ring.material = slash.material
	ring.z_index = 40
	ring.z_as_relative = false
	ring.position = Vector2(0, -4)
	add_child(ring)
	# grow the radius, not the node scale (scale would fatten the line into a disc)
	var grow := func(r: float) -> void:
		var pts := PackedVector2Array()
		for i in 33:
			pts.append(Vector2.from_angle(i * TAU / 32) * Vector2(r, r * 0.55))
		ring.points = pts
	grow.call(4.0)
	var tw := ring.create_tween()
	tw.tween_interval(delay)
	tw.tween_method(grow, 4.0, SONG_RANGE, 0.7).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(ring, "modulate:a", 0.0, 0.75)
	tw.tween_callback(ring.queue_free)


## 레벨업: stats rise on their own, and the body is renewed
func _on_leveled(_lv: int) -> void:
	Audio.sfx("levelup", -2.0, 0.0)
	max_hp = Game.max_hp()
	hp = max_hp
	ki = max_ki
	stats_changed.emit(hp, max_hp, ki, max_ki)
	var ring := Shockwave.new()
	ring.max_r = 30.0; ring.time = 0.6; ring.color = Color(1.0, 0.85, 0.45)
	ring.position = position
	get_parent().add_child(ring)


# ---------------------------------------------------------------- status effects from 요괴
func stun(sec: float) -> void:
	if invuln or state == "dead" or _guard_t > 0.0:
		return
	Audio.sfx("stun", -6.0)
	_end_attack()
	if state != "move":
		state = "move"
	stun_t = maxf(stun_t, sec)
	if _stun_fx == null:
		_stun_fx = Label.new()
		_stun_fx.text = "~"
		_stun_fx.add_theme_font_override("font", DialogBox._pixel_font("res://assets/fonts/Galmuri11-Bold.ttf"))
		_stun_fx.add_theme_font_size_override("font_size", 12)
		_stun_fx.add_theme_color_override("font_color", Color(0.8, 0.85, 1.0))
		_stun_fx.position = Vector2(-4, -60)
		_stun_fx.z_index = 45
		add_child(_stun_fx)
	_stun_fx.visible = true


func slow(sec: float) -> void:
	if invuln or state == "dead" or _guard_t > 0.0:
		return   # 수호부가 막은 직후, 그리고 구르기 무적 중에는 둔화도 걸리지 않는다
	slow_t = maxf(slow_t, sec)


## drag toward a point for a while (the hero can still roll to break free)
func pull(to: Vector2, sec: float) -> void:
	if _guard_t > 0.0 or state == "dead":
		return
	if state == "charge":
		_end_attack()   # 끌려가면 충전이 끊긴다
	pull_to = to
	pull_t = sec


func _pull_vel() -> Vector2:
	if pull_t <= 0.0 or state == "roll":
		return Vector2.ZERO
	var d := pull_to - global_position
	return d.normalized() * minf(70.0, d.length() * 3.0)


# ---------------------------------------------------------------- 행낭 items
## use one of Game.items; returns false if there is none (or it would do nothing)
func use_item(id: String) -> bool:
	if int(Game.items.get(id, 0)) <= 0:
		return false
	match id:
		"insam":
			if hp >= max_hp:
				return false
			hp = minf(max_hp, hp + 60.0)
		"gugija":
			if ki >= max_ki:
				return false
			ki = minf(max_ki, ki + 50.0)
		"jeonghwa":
			for e in get_tree().get_nodes_in_group("enemy"):
				var to: Vector2 = e.global_position - global_position
				if to.length() < 80.0 and e.has_method("take_hit"):
					e.take_hit(40, to.normalized(), true)
			for i in 5:
				_ripple(OBANG[i], i * 0.05)
	Game.items[id] = int(Game.items[id]) - 1
	stats_changed.emit(hp, max_hp, ki, max_ki)
	return true


# ---------------------------------------------------------------- 부적 (웹판 이식: 화염·결박·수호 + 파동)
func t_now() -> float:
	return Time.get_ticks_msec() / 1000.0


## 햅틱 (CS-08): 지원 기기만, 설정 "haptic" 이 false 면 끈다
func _haptic(ms := CT.HAPTIC_MS) -> void:
	if Game.setting("haptic") == false:
		return
	Input.vibrate_handheld(ms)


func song_range() -> float:
	return SONG_RANGE * (2.0 if Game.has_skill("gyeopnorae") else 1.0)   # 겹노래


## the talismans he can draw right now
func talismans() -> Array:
	var a := ["fire", "bind", "guard"]
	if Game.has_skill("padong"):
		a.append("wave")
	return a


func current_talisman() -> String:
	var a := talismans()
	return a[Game.tal_idx % a.size()]


func swap_talisman() -> void:
	if swap_cd > 0.0:
		return
	swap_cd = 0.5 if Game.has_skill("bujeok") else 1.0   # 부적 다루기
	Game.tal_idx = (Game.tal_idx + 1) % talismans().size()
	Audio.sfx("ui_move", -6.0, 0.0)
	Game.float_text(get_parent(), global_position + Vector2(0, -44), [TAL_NAME[current_talisman()]])
	talisman_changed.emit(current_talisman())


func _talisman() -> void:
	var kind := current_talisman()
	if ki < TAL_COST[kind]:
		Game.float_text(get_parent(), global_position + Vector2(0, -44), ["소리가 모자라다"])
		return
	ki -= TAL_COST[kind]
	stats_changed.emit(hp, max_hp, ki, max_ki)
	var ang: float = FACE_ANGLE[facing]
	var big := Game.has_skill("hwayeom2")   # 화염부·진
	match kind:
		"fire":
			var z := TalismanZone.new()
			z.kind = "fire"
			z.angle = ang
			z.radius = 58.0 * (1.4 if big else 1.0)
			z.life = 3.0 + (2.0 if big else 0.0)
			z.position = position + Vector2.from_angle(ang) * 4.0
			get_parent().add_child(z)
			Audio.sfx("slash", -2.0, 0.3)
		"bind":
			var at := _bind_spot(position + Vector2.from_angle(ang) * 40.0)
			var z := TalismanZone.new()
			z.kind = "bind"
			z.radius = CT.BIND_RADIUS
			z.life = 8.0 + (4.0 if Game.has_skill("gyeolbak2") else 0.0)
			z.position = at
			get_parent().add_child(z)
			Audio.sfx("block", -4.0, 0.0)
		"guard":
			shield = 2 if Game.has_skill("suho2") else 1
			shield_t = 10.0
			_ring_fx(Color(1.0, 0.9, 0.55), 22.0, 0.4)
			Audio.sfx("bell", -4.0, 0.0)
		"wave":   # 파동부: a wall of sound that throws them back
			for e in get_tree().get_nodes_in_group("enemy"):
				var to: Vector2 = e.global_position - global_position
				if to.length() < 70.0 and absf(wrapf(to.angle() - ang, -PI, PI)) < 0.9 and e.has_method("take_hit"):
					var bound: bool = e.get("bind_t") != null and e.bind_t > 0.0   # S4 묶어 울리기: 결박된 적은 피해 ×2·넉백 ×0.5
					e.take_hit(6 * (int(CT.WAVE_BIND_DMG_MULT) if bound else 1), to.normalized() * 2.0 * (CT.WAVE_BIND_KNOCK_MULT if bound else 1.0), true)
					if e.has_method("_interrupt"):
						e._interrupt()   # 파동은 예고·시전을 끊는다
			for i in 3:
				SoundWave.fire(self, ang + (i - 1) * 0.35, 4)
	_paper_fx()


## 결박부 설치 위치 (CS-04): 110px 안 적 중 "반지름 40 안에 가장 많은 적을 담는 적"의 위치. 동수면 가장 가까운 적.
func _bind_spot(fallback: Vector2) -> Vector2:
	var foes := get_tree().get_nodes_in_group("enemy")
	var best := fallback
	var best_n := 0
	var best_d := 1e9
	for c in foes:
		var dd: float = c.global_position.distance_to(global_position)
		if dd >= CT.BIND_PICK_RANGE:
			continue
		var n := 0
		for o in foes:
			var to: Vector2 = o.global_position - c.global_position
			if Vector2(to.x, to.y / 0.6).length() <= CT.BIND_RADIUS + 6.0:   # 장판과 같은 지면 타원
				n += 1
		if n > best_n or (n == best_n and dd < best_d):
			best_n = n; best_d = dd; best = c.global_position
	return best


## the paper talisman flares above his head as it is spent
func _paper_fx() -> void:
	var tl := Sprite2D.new()
	tl.texture = load("res://assets/ui/btn_talisman.png")
	tl.region_enabled = true
	tl.region_rect = Rect2(12, 9, 10, 16)
	tl.position = Vector2(0, -52)
	tl.material = slash.material
	tl.z_index = 41
	tl.z_as_relative = false
	add_child(tl)
	var tw2 := tl.create_tween().set_parallel()
	tw2.tween_property(tl, "position:y", -64.0, 0.5)
	tw2.tween_property(tl, "modulate:a", 0.0, 0.5)
	tw2.chain().tween_callback(tl.queue_free)


func _ring_fx(col: Color, r: float, time: float) -> void:
	var ring := Line2D.new()
	ring.width = 2.0
	ring.default_color = col
	ring.material = slash.material
	ring.z_index = 40
	ring.z_as_relative = false
	for i in 33:
		ring.add_point(Vector2.from_angle(i * TAU / 32) * Vector2(1, 0.55))
	ring.position = Vector2(0, -6)
	add_child(ring)
	var tw := ring.create_tween().set_parallel()
	tw.tween_property(ring, "scale", Vector2(r, r), time).set_ease(Tween.EASE_OUT)
	tw.tween_property(ring, "modulate:a", 0.0, time + 0.05)
	tw.chain().tween_callback(ring.queue_free)


# ---------------------------------------------------------------- 신명 · 받아넘기기 · 처용무
func add_sin(n: float) -> void:
	shinmyeong = clampf(shinmyeong + n, 0.0, 100.0)
	sin_changed.emit(shinmyeong)
	if n > 0.0 and shinmyeong >= 100.0 and _burst_ready and Game.has_skill("sinmyeong"):
		_burst_ready = false   # 신명폭발: the brim spills over by itself
		_ring_fx(Color(1.0, 0.85, 0.45), 90.0, 0.5)
		for e in get_tree().get_nodes_in_group("enemy"):
			var to: Vector2 = e.global_position - global_position
			if to.length() < 90.0 and e.has_method("take_hit"):
				e.take_hit(30, to.normalized(), true)
		Game.float_text(get_parent(), global_position + Vector2(0, -48), ["신명폭발!"])


## 받아넘기기: rolled through a blow at the last moment — time slows, the next blow lands double
func _parry_window() -> float:
	return CT.PARRY_WINDOW_SKILL if Game.has_skill("batanum") else CT.PARRY_WINDOW


func _parry(_dir: Vector2) -> void:
	if _parry_cd > 0.0:
		return
	_parry_cd = CT.PARRY_CD
	parry_bonus = true
	add_sin(CT.SIN_PER_PARRY)
	ki = minf(max_ki, ki + CT.KI_PER_PARRY)   # CS-01: 받아넘기기는 소리도 돌려준다
	stats_changed.emit(hp, max_hp, ki, max_ki)
	_haptic()
	if Game.has_skill("batanum"):   # 되받아치기: 정면의 적을 밀쳐 낸다 (피해 0, 예고·타격 중단)
		var fwd := roll_dir if roll_dir != Vector2.ZERO else Vector2.from_angle(FACE_ANGLE[facing])
		for e in get_tree().get_nodes_in_group("enemy"):
			if e is PlagueGod or not (e is Node2D):
				continue
			var to: Vector2 = e.global_position - global_position
			if to.length() < CT.PARRY_SHOVE_RANGE and to.normalized().dot(fwd) > 0.0 and e.has_method("take_hit"):
				e.take_hit(0, to.normalized(), true, true)
				if e.has_method("_interrupt"):
					e._interrupt()
	parry_chain += 1
	parry_chain_t = 10.0
	Audio.sfx("block", 0.0, 0.0)
	_ring_fx(Color(1, 1, 1), 34.0, 0.4)
	Game.float_text(get_parent(), global_position + Vector2(0, -48), ["받아넘기기"])
	Engine.time_scale = 0.35
	get_tree().create_timer(0.35, true, false, true).timeout.connect(func(): Engine.time_scale = 1.0)
	if parry_chain >= 3:
		parry_chain = 0
		height_t = 5.0
		Game.say_toast("신명 고조 — 발과 피리가 빨라진다 (5초)", Color(1.0, 0.85, 0.45))


func can_dance() -> bool:
	return shinmyeong >= 100.0 and Game.flag("flute")


## 처용무: six seconds of untouchable dance; everything near is struck and its 탁기 shaken loose
func dance() -> void:
	if not can_dance():
		return
	shinmyeong = 0.0
	_burst_ready = true
	sin_changed.emit(shinmyeong)
	_end_attack()
	state = "move"
	ult_t = ULT_TIME
	_ult_tick = 0.0
	Audio.sfx("song", 0.0, 0.0)
	Game.say_toast("처용무!", Color(1.0, 0.85, 0.45))
	for i in 5:
		_ripple(OBANG[i], i * 0.06)
	if Game.has_skill("cheonji"):   # 천지울림: the whole screen rings
		var cam := get_viewport().get_camera_2d()
		var view := Rect2(cam.get_screen_center_position() - Vector2(240, 135), Vector2(480, 270)) if cam else Rect2(global_position - Vector2(240, 135), Vector2(480, 270))
		for e in get_tree().get_nodes_in_group("enemy"):
			if view.has_point(e.global_position) and e.has_method("take_hit"):
				e.take_hit(12 if e is PlagueGod else 40, (e.global_position - global_position).normalized(), true)
		_ring_fx(Color(0.75, 0.95, 1.0), 200.0, 0.6)


func _ult(delta: float, dir: Vector2) -> void:
	ult_t -= delta
	_ult_tick -= delta
	velocity = dir * 60.0
	_slide()
	sprite.rotation = 0.0
	_pose("spin", int(ult_t * 14.0) % 8)   # 처용무: turning and turning
	if _ult_tick <= 0.0:
		_ult_tick = 0.2
		var strikes := 2 if Game.has_skill("obang") else 1   # 오방신장 join in
		for e in get_tree().get_nodes_in_group("enemy"):
			var to: Vector2 = e.global_position - global_position
			if to.length() < 70.0 and e.has_method("take_hit"):
				var boss := e is PlagueGod
				e.take_hit(int(round(30 * (0.12 if boss else 1.0) * strikes)), to.normalized(), false, true)   # 보스는 춤 한 번에 2할 남짓
		_ring_fx(OBANG[randi() % 5] if Game.has_skill("obang") else Color(1.0, 0.85, 0.45), 40.0, 0.2)
		Audio.sfx("slash", -8.0)
	if ult_t <= 0.0:
		ult_t = 0.0
		sprite.flip_h = facing == "left"


# ---------------------------------------------------------------- roll (춤 구르기)
func _start_roll(dir: Vector2, dash := false) -> void:
	_dash = dash
	if dash:   # 학의 질주
		Audio.sfx("roll", -3.0, 0.2)
	_end_attack()
	pull_t = 0.0  # rolling tears free of whatever is dragging him
	Audio.sfx("roll", -6.0)
	state = "roll"
	t = 0.0
	roll_dir = dir.normalized() if dir != Vector2.ZERO else Vector2.from_angle(FACE_ANGLE[facing])
	_face(roll_dir)
	invuln = true
	ghost_t = 0.0


func _roll(delta: float) -> void:
	var k := clampf(t / ROLL_TIME, 0.0, 1.0)
	velocity = roll_dir * ROLL_SPEED * (1.3 if Game.has_skill("nabi") else 1.0) * (2.0 if _dash else 1.0) * (1.0 - k * 0.6)
	_slide()
	# 춤 구르기: one full turn on the spot of the step, the robe flaring (rendered, art/hero.py)
	var rrow := "right" if facing == "left" else facing   # 구르기: 드라이브 '달리기' 컷을 낮게 몰아친다
	_pose(rrow + "_roll", mini(int(k * 6.0), 5))
	sprite.flip_h = facing == "left"
	ghost_t -= delta
	if ghost_t <= 0.0:
		ghost_t = 0.05
		_ghost()
	if k >= 1.0:
		state = "move"
		invuln = false
		if Game.has_skill("yeonpung"):  # 연풍
			haste_t = 2.0
		_last_roll_end = -10.0 if _dash else t_now()
		_roll_lock_t = CT.ROLL_LOCK
		_dash = false
		sprite.rotation = 0.0
		sprite.scale = Vector2.ONE
		sprite.position = Vector2.ZERO
		sprite.offset = Vector2(0, FRAME.y / 2.0 - FEET_ROW)


func _ghost() -> void:
	var g := Sprite2D.new()
	g.texture = sprite.sprite_frames.get_frame_texture(sprite.animation, sprite.frame)
	g.offset = sprite.offset
	g.flip_h = sprite.flip_h
	g.rotation = sprite.rotation
	g.scale = sprite.scale
	g.global_position = sprite.global_position
	g.modulate = Color(0.55, 0.8, 1.0, 0.55)
	var add := CanvasItemMaterial.new()
	add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	g.material = add
	get_parent().add_child(g)
	var tw := g.create_tween()
	tw.tween_property(g, "modulate:a", 0.0, 0.25)
	tw.tween_callback(g.queue_free)


## move_and_slide with the depth foreshortening: on the flattened ground, going up or down the
## screen covers fewer pixels than going sideways (velocity itself stays in footprint units)
func _slide() -> void:
	var vy := velocity.y
	velocity.y *= 1.0 - (1.0 - Game.depth_k) * 0.4   # 0.75 felt too slow on a phone: about 0.9
	move_and_slide()
	velocity.y = vy
