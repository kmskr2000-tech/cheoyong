class_name Dueoksini
extends PlagueGod
## 두억시니 — 2장 「도깨비골」 보스 (design/levels/ch2-dokkaebigol.md §6·§7 M-2, 챕터2 M3). 역신(PlagueGod)을 확장해
## player.gd 의 보스 판정(`is PlagueGod`)·HUD 게이지 신호·1장 스토리 재도전 훅을 그대로 쓴다. 1장 코드는 건드리지 않는다.
## 역신과 반대로 "평소엔 닫혀 있고 열쇠를 쓰면 열리는" 보스다:
##   상시 「군단 장갑」 — 졸개가 살아 있는 동안(downed 제외) 받는 피해 ×0.4. 졸개가 전부 쓰러지면 풀린다.
##   씻김 공명        — 쓰러진 졸개 2체 이상을 노래 한 번에 정화하면 열림 2.5초(×1.5) + HP −30/45/60 (호령 사이클마다 1회).
##   ① 방망이 호출 (summon) — 소환진 표식 → 도깨비 졸개 4(P2 5, 동시 상한 4/6). 정답: 결박부로 모으고 쓰러뜨려 한 번에 노래.
##   ② 감투 은신 (stealth)  — 5초(P2 6) 투명·이동 ×1.6, 처용 곁에서 풀리며 방망이 내려침 예고. 정답: 화염부로 노출 / 받아넘기기.
##   ③ 짚신 순간이동 (blink) — 착지 표식 → 순간이동 → 부채꼴 불덩이 3(P2 5). 정답: 기둥 뒤 엄폐(CS-10), 후딜에 접근.
## 2페이즈(HP ≤ 절반): 검은 비 장판(탁기 비, kind="miasma" 라 수호부로 무효), 소리 +30.
## 수치는 설계서 §6.2~6.3 그대로이고 전투 상수 파일(combat_tuning.gd)은 건드리지 않는다 — 여기 상수가 정본이다.

const TUN := preload("res://scripts/combat_tuning.gd")   # 읽기 전용: 2페이즈 전환 열림·소리 보상만 역신과 같은 값 재사용
const DFX := preload("res://scripts/fx/combat_fx.gd")

# ---- 몸 (시트: Drive dokkaebi_extra 8칸 72×66 — 0~3 푸른 거구 idle, 6 피격. 4·5·7 은 초록 장수라 쓰지 않는다)
const D_SHEET := "res://assets/sprites/yokai/dokkaebi_extra.png"
const D_CELL := Vector2i(72, 66)
const D_FEET := 65.0
const D_SCALE := 1.6          # 66px 원화가 졸개(54px)와 비슷해 1.6배로 키운다 (production/qa/ch2-m3-asset-needs.md)
const D_ANIMS := {"idle": [0, 1, 2, 3], "hurt": [6]}
const D_HP := 600.0           # §6.2
const D_SPEED := 24.0
const D_STOP := 90.0
const D_AURA_IDLE := Color(0.55, 0.5, 1.0)
const D_AURA := {"summon": Color(0.7, 0.35, 1.0), "stealth": Color(0.35, 0.6, 1.0), "blink": Color(1.0, 0.3, 0.25)}   # 호령 보라 / 은신 청 / 짚신 적
const D_AURA_WARN := 0.5

# ---- 군단 장갑·상태별 피해 배율 (§6.3 T7)
const D_ARMOR := 0.4
const D_STEALTH_MULT := 0.3
const D_OPEN_MULT := 1.5

# ---- ① 방망이 호출
const D_ARENA_C := Vector2(320, 200)   # 의식대 중심 (footprint). 소환점 8 = 45도 r130 (production/qa/asset-import/ch2-den3/README.md)
const D_SIGIL_R := 130.0
const D_SIGIL_MIN_PLAYER := 70.0
const D_MINION_KINDS := ["dokkaebi_oneeye", "dokkaebi_fire"]

# ---- ② 감투 은신
const D_STEALTH_MOVE := 1.6
const D_AMBUSH := 34.0         # 처용 곁 접근 거리
const D_SLAM_R := 44.0
const D_SLAM_DMG := 18
const D_EXPOSE_OPEN := 1.2     # 화염으로 드러났을 때 휘청
const D_EXPOSE_DMG := 40.0     # 은신 중 누적 피해 (배율 적용 후 실제 HP 손실)

# ---- ③ 짚신 순간이동
const D_BLINK_PLAYER_MIN := 90.0
const D_AIM_T := 0.6           # 부채꼴 가이드 표시·조준 시간 (끝 0.2초는 방향 고정)
const D_AIM_LOCK := 0.4
const D_FIRE_SPEED := 130.0
const D_FIRE_DMG := 12
const D_BLINK_OPEN := 0.6

# ---- 2페이즈 검은 비 (footprint 3곳, 한 곳씩 4초 주기: 예고 1초 + 3초 활성)
const D_RAIN_SPOTS := [Vector2(190, 130), Vector2(450, 270), Vector2(320, 200)]
const D_RAIN_R := 36.0
const D_RAIN_DMG := 5
const D_RAIN_TICK := 0.5

var open_mult := 1.5           # 지금 열림의 피해 배율 (공명·노출 ×1.5 / 짚신 후딜 ×1.0)
var minions: Array = []
var rain_on := false
var rain_t := 0.0
var _res_n := 0                # 같은 프레임에 정화된 졸개 수
var _res_used := false         # 호령 사이클마다 공명 1회
var _spawn_i := 0
var _sigils: Array = []        # footprint
var _blink_to := Vector2.ZERO  # footprint
var _stealth_dmg := 0.0
var _ripple_t := 0.0
var _a := 1.0                  # 몸 투명도 (은신)
var _want_a := 1.0
var _fan: Line2D
var _rain_idx := -1
var _rain_node: Node2D
var _rain_tick := 0.0
var _armor_hint_t := 0.0


func _ready() -> void:
	add_to_group("enemy")
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	var col := CollisionShape2D.new()
	var sh := RectangleShape2D.new()
	sh.size = Vector2(52, 14)
	col.shape = sh
	col.position = Vector2(0, -7)
	add_child(col)
	sprite = AnimatedSprite2D.new()
	var tex: Texture2D = Tex.lit(D_SHEET)
	var frames := SpriteFrames.new()
	frames.remove_animation("default")
	for a in D_ANIMS:
		frames.add_animation(a)
		frames.set_animation_speed(a, 5.0)
		for i in D_ANIMS[a]:
			var at := AtlasTexture.new()
			at.atlas = tex
			at.region = Rect2(i * D_CELL.x, 0, D_CELL.x, D_CELL.y)
			frames.add_frame(a, at)
	sprite.sprite_frames = frames
	sprite.offset = Vector2(0, D_CELL.y / 2.0 - D_FEET)
	sprite.scale = Vector2(D_SCALE, D_SCALE)
	sprite.play("idle")
	add_child(sprite)
	var mi := CPUParticles2D.new()   # 낡은 절구에서 새는 탁기
	mi.amount = 50
	mi.lifetime = 2.0
	mi.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	mi.emission_rect_extents = Vector2(30, 4)
	mi.position = Vector2(0, -4)
	mi.direction = Vector2(0, -1)
	mi.gravity = Vector2(0, -12)
	mi.initial_velocity_min = 4.0
	mi.initial_velocity_max = 12.0
	mi.scale_amount_min = 2.0
	mi.scale_amount_max = 4.0
	mi.color = Color(0.4, 0.25, 0.6, 0.35)
	mi.z_index = -1
	add_child(mi)
	aura = PointLight2D.new()
	aura.texture = _radial()
	aura.color = D_AURA_IDLE
	aura.energy = 0.7
	aura.texture_scale = 2.4
	aura.position = Vector2(0, -50)
	add_child(aura)
	target = get_tree().current_scene.get_node_or_null("Player")
	state = "wait"   # 스토리가 awaken() 으로 깨울 때까지 가만히 선다
	hp = D_HP
	_a = 0.0         # appear() 로 서서히 나타난다


## 입장 연출: 절구에서 검은 기운과 함께 서서히 모습을 드러낸다
func appear() -> void:
	_want_a = 1.0
	_ring(position, 60.0, Color(0.7, 0.5, 1.0))


func disguise() -> void:
	state = "wait"


# ================================================================ 상태 기계
func _physics_process(delta: float) -> void:
	st += delta
	flash = maxf(0.0, flash - delta)
	_armor_hint_t = maxf(0.0, _armor_hint_t - delta)
	knock = knock.move_toward(Vector2.ZERO, 500.0 * delta)
	_want_a = 0.1 if state == "stealth" else 1.0
	_a = move_toward(_a, _want_a, delta * (3.0 if state == "stealth" else 1.5))
	sprite.modulate = Color(2.4, 2.4, 2.4, _a) if flash > 0.0 else Color(1, 1, 1, _a)
	sprite.self_modulate = _tint()
	if state == "dead" or state == "kneel" or state == "wait" or target == null:
		return
	if rain_on:
		_rain_step(delta)
	var to := target.global_position - global_position
	var d := to.length()
	var spd := D_SPEED * (1.3 if phase == 2 else 1.0)
	var v := Vector2.ZERO
	match state:
		"idle":
			sprite.play("idle")
			if d > D_STOP:
				v = to.normalized() * spd
			if st > _gap():
				_next_pattern()
			else:
				_aura_warn()
		"summon":   # ① 방망이를 땅에 찍고 소환진 표식 → 졸개
			sprite.play("idle")
			if st > _wind(1.2, 1.0):
				_do_summon()
				_begin("idle")
		"stealth_in":   # ② 감투를 쓴다 (푸른 파문)
			sprite.play("idle")
			if st > _wind(1.0, 0.8):
				_stealth_dmg = 0.0
				_ripple_t = 0.0
				_begin("stealth")
		"stealth":
			sprite.play("idle")
			v = to.normalized() * spd * D_STEALTH_MOVE if d > D_AMBUSH + 4.0 else Vector2.ZERO
			_ripple_t -= delta
			if _ripple_t <= 0.0:
				_ripple_t = 0.7
				_ring(position, 18.0, Color(0.5, 0.7, 1.0))   # 자취: 은신 중에도 파문으로 위치를 읽는다
			if _fire_exposed():
				_expose()
			elif d <= D_AMBUSH + 4.0:
				_clear_tells()
				tells.append(_mark(position, D_SLAM_R))   # 방망이 내려침 예고 (반경 44)
				_begin("slam_tell")
			elif st >= (6.0 if phase == 2 else 5.0):
				_begin("idle")   # 놓쳤다: 조용히 모습이 드러난다
		"slam_tell":
			sprite.play("idle")
			if st > _wind(1.0, 0.8):
				_clear_tells()
				if _slam():
					_begin("idle")                 # 못 읽고 맞았다 = 열림 없음
				else:
					_open2(1.0, D_OPEN_MULT)       # 받아넘기기·구르기로 피했다 = 열린다
		"blink_tell":   # ③ 짚신을 던진다 — 착지점 표식이 곧 순간이동 목적지
			sprite.play("idle")
			if st > _wind(1.0, 0.8):
				_do_blink()
				_begin("blink_aim")
		"blink_aim":
			sprite.play("idle")
			if st < D_AIM_LOCK:
				aim = (target.global_position - global_position).angle()
			_draw_fan()
			if st >= D_AIM_T:
				_clear_fan()
				_fire_fan()
				_open2(D_BLINK_OPEN, 1.0)
		"open":
			sprite.play("hurt")
			if st >= open_t:
				_begin("idle")
	bind_t = maxf(0.0, bind_t - delta)
	velocity = v * (0.35 if bind_t > 0.0 else 1.0) + knock
	_slide()
	sprite.flip_h = to.x > 0.0


func _gap() -> float:
	return 1.0 if phase == 2 else 1.4


func _wind(p1: float, p2: float) -> float:
	return p2 if phase == 2 else p1


func _tint() -> Color:
	var base := Color(1.18, 1.0, 1.0) if phase == 2 else Color.WHITE   # 2페이즈: 검은 비 탁기로 붉게 달아오른다
	match state:
		"summon":
			return base.lerp(Color(1.4, 0.8, 1.6), 0.5 + 0.5 * sin(st * 14.0))
		"stealth_in":
			return base.lerp(Color(0.7, 0.9, 1.7), 0.5 + 0.5 * sin(st * 14.0))
		"blink_tell":
			return base.lerp(Color(1.7, 0.7, 0.6), 0.5 + 0.5 * sin(st * 14.0))
		"slam_tell":
			return base.lerp(Color(1.7, 0.7, 0.6), 0.5 + 0.5 * sin(st * 18.0))
	return base


## 졸개가 살아 있는 수 (downed 제외)
func minions_alive() -> int:
	var n := 0
	for e in minions:
		if is_instance_valid(e) and not e.is_queued_for_deletion() and e.state not in ["downed", "dead"]:
			n += 1
	return n


func minions_total() -> int:
	var n := 0
	for e in minions:
		if is_instance_valid(e) and not e.is_queued_for_deletion() and e.state != "dead":
			n += 1
	return n


## 받는 피해 배율: 열림(공명·노출 ×1.5 / 짚신 후딜 ×1.0) > 은신 ×0.3 > 군단 장갑 ×0.4 > 평시 ×1.0
func exposure() -> float:
	if state == "open":
		return open_mult
	if state == "stealth":
		return D_STEALTH_MULT
	return D_ARMOR if minions_alive() > 0 else 1.0


## 열림(후딜) + 배율. 부모의 _open 이 상태 전환·열림 표식을 맡는다
func _open2(sec: float, mult: float) -> void:
	open_mult = mult
	_open(sec)


# ================================================================ 패턴 순환
## 1페이즈 ①→③→②→③ (대기 1.4초), 2페이즈 7칸 ①→②→③→①→③→②→③ (대기 1.0초).
## 설계서 §6.3 의 6칸 순환 ①②③①③② 은 한 바퀴 돌 때 ② 직후 ① 이 와 "② 직후 ① 금지" 규칙을 스스로 어긴다 → 끝에 ③ 을 하나 덧붙였다.
func _cycle() -> Array:
	return ["summon", "stealth", "blink", "summon", "blink", "stealth", "blink"] if phase == 2 else ["summon", "blink", "stealth", "blink"]


func next_pattern_name() -> String:
	var c := _cycle()
	return c[pat_i % c.size()]


func _aura_warn() -> void:
	if aura == null:
		return
	if st > _gap() - D_AURA_WARN:
		aura.color = D_AURA[next_pattern_name()]
		aura.energy = 0.9
	else:
		aura.color = D_AURA_IDLE
		aura.energy = 0.55


func _next_pattern() -> void:
	if aura:
		aura.color = D_AURA_IDLE
		aura.energy = 0.55
	var cycle := _cycle()
	var p: String = cycle[pat_i % cycle.size()]
	pat_i += 1
	if p == "summon" and _summon_count() <= 0:   # 졸개 상한이 꽉 찼다 — 호령은 건너뛰고 다음 패턴
		p = cycle[pat_i % cycle.size()]
		pat_i += 1
	match p:
		"summon":
			_sigils = _pick_sigils(_summon_count())
			for s in _sigils:
				tells.append(_mark(_fp(s), 16.0))
			_ring(position, 50.0, Color(0.7, 0.35, 1.0))
			Audio.sfx("slash", -4.0)
			_begin("summon")
		"stealth":
			_ring(position, 40.0, Color(0.5, 0.7, 1.0))
			_begin("stealth_in")
		"blink":
			_blink_to = _pick_blink()
			tells.append(_mark(_fp(_blink_to), 18.0))   # 붉은 착지 표식
			_begin("blink_tell")


# ================================================================ ① 방망이 호출
func _fp(p: Vector2) -> Vector2:
	return get_parent().lift(p)


## 소환진 8점(45도, 의식대 반경 130) 전체
static func sigil_points() -> Array:
	var a := []
	for i in 8:
		a.append(D_ARENA_C + Vector2.from_angle(i * TAU / 8.0) * D_SIGIL_R)
	return a


func _summon_count() -> int:
	var cap := 6 if phase == 2 else 4
	return clampi(cap - minions_total(), 0, 5 if phase == 2 else 4)


## 처용에서 70px 이상 떨어진 소환점을 무작위로 n개 (모자라면 먼 곳부터 채운다)
func _pick_sigils(n: int) -> Array:
	var pts := sigil_points()
	pts.shuffle()
	var far := pts.filter(func(s): return _fp(s).distance_to(target.global_position) >= D_SIGIL_MIN_PLAYER)
	var near := pts.filter(func(s): return not far.has(s))
	near.sort_custom(func(a, b): return _fp(a).distance_to(target.global_position) > _fp(b).distance_to(target.global_position))
	return (far + near).slice(0, n)


func _do_summon() -> void:
	_clear_tells()
	var lv := get_parent()
	for i in _sigils.size():
		var e: Enemy = lv.spawn_enemy(D_MINION_KINDS[(_spawn_i + i) % 2], _sigils[i])
		e.no_reward = true
		e.state = "chase"
		e.purified.connect(_on_minion_purified)
		minions.append(e)
		_ring(e.position, 20.0, Color(0.7, 0.35, 1.0))
	_spawn_i += _sigils.size()
	_res_used = false   # 새 호령 = 새 사이클: 공명을 다시 쓸 수 있다
	Audio.sfx("fire", -6.0)


## 씻김 공명 (M-2): 같은 프레임에 정화된 졸개를 모아 센다 — 처용가 한 번이 정화 루프 안에서 한꺼번에 purify() 를 부르기 때문이다
func _on_minion_purified() -> void:
	if state in ["kneel", "dead"]:
		return
	_res_n += 1
	if _res_n == 1:
		_resolve_resonance.call_deferred()


func _resolve_resonance() -> void:
	var n := _res_n
	_res_n = 0
	if n < 2 or _res_used or state in ["kneel", "dead", "wait"]:
		return
	_res_used = true
	var cut := 30 if n == 2 else (45 if n == 3 else 60)
	_flinch()
	DFX.pop_text(get_parent(), position + Vector2(0, -78), "씻김 공명 −%d" % cut, Color(0.75, 0.95, 1.0), 12)
	_ring(position, 70.0, Color(0.75, 0.95, 1.0))
	Audio.sfx("purify", -2.0, 0.0)
	hp -= cut
	hp_changed.emit(hp, D_HP)
	if hp <= 0.0 or (phase == 1 and hp <= D_HP * 0.5):
		_after_hp_loss()
	if state not in ["kneel", "dead", "wait"]:
		_clear_tells()
		_clear_fan()
		_open2(2.5, D_OPEN_MULT)   # 열림 2.5초(×1.5)


## 졸개가 낡은 물건으로 돌아가는 순간 두억시니가 움찔하고 검은 기운이 빠진다
func _flinch() -> void:
	flash = 0.25
	var tw := create_tween()
	tw.tween_property(sprite, "position:y", 5.0, 0.08)
	tw.tween_property(sprite, "position:y", 0.0, 0.2)


# ================================================================ ② 감투 은신
## 화염부가 몸 위에 깔려 있는가 (결박부의 잔 틱과 구분한다)
func _fire_exposed() -> bool:
	for n in get_parent().get_children():
		if n is TalismanZone and n.kind == "fire" and n._inside(self):
			return true
	return false


## 은신이 풀려 휘청 — 화염 노출 또는 누적 피해
func _expose() -> void:
	_clear_tells()
	_ring(position, 36.0, Color(1.0, 0.85, 0.5))
	Game.say_toast("감투가 벗겨졌다", Color(1.0, 0.9, 0.55))
	_open2(D_EXPOSE_OPEN + (Game.GAMTU_REVEAL_BONUS if Game.has_gamtu() else 0.0), D_OPEN_MULT)


## 방망이 내려침: 처용이 반경 안에 있으면 맞는다 (받아넘기기·구르기로 피했으면 false). 근접 접촉이라 받아넘기기 대상.
func _slam() -> bool:
	_ring(position, D_SLAM_R, Color(1.0, 0.45, 0.3))
	Audio.sfx("slash", -2.0)
	var to := target.global_position - global_position
	if Vector2(to.x, to.y / 0.55).length() < D_SLAM_R and target.has_method("hurt"):
		var hp0 = target.get("hp")
		target.hurt(D_SLAM_DMG, to.normalized(), true)
		return hp0 != null and target.get("hp") < hp0
	return false


# ================================================================ ③ 짚신 순간이동 + 불덩이
func _pick_blink() -> Vector2:
	var pts := sigil_points()
	pts.shuffle()
	var ok := pts.filter(func(s): return _fp(s).distance_to(target.global_position) >= D_BLINK_PLAYER_MIN and _fp(s).distance_to(position) > 40.0)
	if ok.is_empty():
		pts.sort_custom(func(a, b): return _fp(a).distance_to(target.global_position) > _fp(b).distance_to(target.global_position))
		return pts[0]
	return ok[0]


func _do_blink() -> void:
	_clear_tells()
	_ring(position, 40.0, Color(1.0, 0.4, 0.3))   # 떠나는 자리
	position = _fp(_blink_to)
	velocity = Vector2.ZERO
	_ring(position, 40.0, Color(1.0, 0.4, 0.3))   # 도착하는 자리
	Audio.sfx("throw", -4.0)
	aim = (target.global_position - global_position).angle()
	if phase == 2:   # P2: 도착점에 4초 불 장판
		var h := Hazard.make("fire_patch", Vector2i(28, 14), 4)
		h.radius = 20.0
		h.life = 4.0
		h.position = position
		get_parent().add_child(h)


func _fan_n() -> int:
	return 5 if phase == 2 else 3


func _fan_step() -> float:
	return 0.25 if phase == 2 else 0.3


## 부채꼴 불덩이 외곽선 (읽기 보조: 엄폐 대상이 가려지는지 눈으로 판단한다)
func _draw_fan() -> void:
	if _fan == null:
		_fan = Line2D.new()
		_fan.width = 1.0
		_fan.default_color = Color(1.0, 0.45, 0.3, 0.45)
		_world_fx(_fan)
	var half := (_fan_n() - 1) / 2.0 * _fan_step() + 0.06
	var pts := PackedVector2Array([Vector2.ZERO])
	for i in 9:
		pts.append(Vector2.from_angle(aim - half + i * (half * 2.0 / 8.0)) * 130.0)
	pts.append(Vector2.ZERO)
	_fan.points = pts
	_fan.position = position + Vector2(0, -8)


func _clear_fan() -> void:
	if _fan != null and is_instance_valid(_fan):
		_fan.queue_free()
	_fan = null


func _fire_fan() -> void:
	var n := _fan_n()
	for i in n:
		var a := aim + (i - (n - 1) / 2.0) * _fan_step()
		var pr := Projectile.make("fireball", Vector2i(10, 10), 2)
		pr.vel = Vector2.from_angle(a) * D_FIRE_SPEED
		pr.dmg = D_FIRE_DMG
		pr.life = 2.6
		pr.position = position + Vector2(0, -6) + pr.vel.normalized() * 12.0
		get_parent().add_child(pr)
	Audio.sfx("fire", -4.0)


# ================================================================ 2페이즈: 검은 비
func _rain_spot(i: int) -> Vector2:
	return _fp(D_RAIN_SPOTS[i % D_RAIN_SPOTS.size()])


func _rain_step(delta: float) -> void:
	rain_t += delta
	var cyc := fmod(rain_t, 4.0 * D_RAIN_SPOTS.size())
	var idx := int(cyc / 4.0)
	var local := fmod(cyc, 4.0)
	if idx != _rain_idx:
		_make_rain_node(idx)
	var active := local >= 1.0
	_rain_node.get_node("drops").emitting = active
	_rain_node.get_node("ring").modulate.a = 0.35 + 0.45 * (sin(rain_t * 10.0) * 0.5 + 0.5) if not active else 0.9
	_rain_tick -= delta
	if active and _rain_tick <= 0.0:
		_rain_tick = D_RAIN_TICK
		var to: Vector2 = target.global_position - _rain_node.global_position
		if Vector2(to.x, to.y / 0.6).length() < D_RAIN_R and target.has_method("hurt"):
			target.hurt(Game.miasma_dmg(D_RAIN_DMG), Vector2.ZERO, false, "miasma")   # 수호부가 막는 독기 틱 (kind="miasma")


func _make_rain_node(idx: int) -> void:
	_clear_rain()
	_rain_idx = idx
	_rain_node = Node2D.new()
	_rain_node.position = _rain_spot(idx)
	var ring := Line2D.new()
	ring.name = "ring"
	for i in 33:
		ring.add_point(Vector2.from_angle(i * TAU / 32.0) * Vector2(D_RAIN_R, D_RAIN_R * 0.6))
	ring.width = 1.5
	ring.default_color = Color(0.55, 0.3, 0.8, 0.9)
	_rain_node.add_child(ring)
	var drops := CPUParticles2D.new()
	drops.name = "drops"
	drops.amount = 40
	drops.lifetime = 0.5
	drops.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	drops.emission_sphere_radius = D_RAIN_R * 0.8
	drops.position = Vector2(0, -50)
	drops.direction = Vector2(0, 1)
	drops.spread = 5.0
	drops.gravity = Vector2(0, 160)
	drops.initial_velocity_min = 40.0
	drops.initial_velocity_max = 70.0
	drops.scale_amount_min = 1.0
	drops.scale_amount_max = 2.0
	drops.color = Color(0.35, 0.2, 0.5, 0.85)
	drops.emitting = false
	_rain_node.add_child(drops)
	_world_fx(_rain_node)


func _clear_rain() -> void:
	if _rain_node != null and is_instance_valid(_rain_node):
		_rain_node.queue_free()
	_rain_node = null
	_rain_idx = -1
	_rain_tick = 0.0


# ================================================================ 피격·페이즈·쓰러짐
func take_hit(dmg: int, dir: Vector2, heavy := false, quiet := false, charged := false, charge_t := -1.0) -> void:
	if state in ["dead", "kneel", "wait"]:
		return
	if not quiet:
		Audio.sfx("hit", -3.0)
	if exposure() == D_ARMOR and not quiet and _armor_hint_t <= 0.0:
		_armor_hint_t = 1.6
		DFX.pop_text(get_parent(), position + Vector2(0, -78), "군단 장갑", Color(0.7, 0.7, 0.8), 10)   # 졸개가 있는 한 단단하다
	var dealt := int(ceil(dmg * exposure()))
	hp -= dealt
	flash = 0.08
	knock = dir * (lerpf(TUN.CHARGE_BOSS_KNOCK_MIN, TUN.CHARGE_BOSS_KNOCK_MAX, charge_t) if charge_t >= 0.0 else (60.0 if heavy else 30.0))
	hp_changed.emit(hp, D_HP)
	if state == "stealth":
		_stealth_dmg += dealt
	_after_hp_loss()
	if state == "stealth" and _stealth_dmg >= D_EXPOSE_DMG and hp > 0.0:
		_expose()   # 누적 40 이상 맞으면 은신이 풀린다


func _after_hp_loss() -> void:
	if phase == 1 and hp <= D_HP * 0.5:
		phase = 2
		pat_i = 0
		_ring(position, 90.0, Color(0.8, 0.5, 1.0))
		_clear_tells()
		_clear_fan()
		phase_two.emit()
		if state != "wait":
			phase_shift()
	if hp <= 0.0 and state not in ["kneel", "dead"]:
		_kneel()


## 2페이즈 전환 (스토리 대사가 끝난 뒤 호출): 열림 1.2초, 소리 +30, 검은 비 시작
func phase_shift() -> void:
	_clear_tells()
	_clear_fan()
	if is_instance_valid(target) and target.has_method("gain_ki"):
		target.gain_ki(TUN.BOSS_PHASE_KI)
	_open2(TUN.BOSS_PHASE_SHIFT, D_OPEN_MULT)
	rain_on = true
	rain_t = 0.0


func _kneel() -> void:
	_clear_rain()
	_clear_fan()
	rain_on = false
	super._kneel()   # 졸개는 전부 쓰러지고(downed), 두억시니는 무릎을 꿇는다 — 노래로만 거둔다
	minions.clear()


## 처용이 쓰러진 동안 가만히 선다
func stand_down() -> void:
	super.stand_down()
	_clear_rain()
	_clear_fan()
	rain_on = false
	rain_t = 0.0


## 재도전: HP·페이즈·패턴 순서 초기화, 졸개·표식·검은 비 제거. 입구에서 다시 일어선 처용에게 1.5초 여유를 준다
func reset_fight() -> void:
	hp = D_HP
	phase = 1
	pat_i = 0
	open_t = 0.0
	open_mult = D_OPEN_MULT
	knock = Vector2.ZERO
	rain_on = false
	rain_t = 0.0
	_res_n = 0
	_res_used = false
	_spawn_i = 0
	_stealth_dmg = 0.0
	_a = 1.0
	sprite.self_modulate = Color.WHITE
	_clear_tells()
	_clear_fan()
	_clear_rain()
	minions.clear()
	for g in ["enemy", "downed"]:
		for e in get_tree().get_nodes_in_group(g):
			if e != self and e.get("kind") != null:
				e.remove_from_group("enemy")
				e.remove_from_group("downed")
				e.queue_free()
	if home_pos != Vector2.ZERO:
		position = home_pos
	hp_changed.emit(hp, D_HP)
	_begin("idle")
	st = -1.5


func _defeat() -> void:
	Audio.sfx("purify", 0.0, 0.0)
	Audio.override("")
	state = "dead"
	_clear_tells()
	_clear_rain()
	_clear_fan()
	remove_from_group("enemy")
	Game.reward_purify("dueoksini", global_position, get_parent())
	DFX.purify(get_parent(), global_position, 2.0)
	if not Game.has_gamtu():
		Game.accessories.append(Game.GAMTU_NAME)
		Game.say_toast("장신구 「%s」을 얻었다 — %s" % [Game.GAMTU_NAME, Game.gamtu_desc()], Color(0.75, 0.85, 1.0))
	for e in get_tree().get_nodes_in_group("downed"):
		e.purify()
	defeated.emit()
	sprite.play("hurt")
	var tw := create_tween()
	for i in 6:
		tw.tween_callback(_ring.bind(position, 40.0 + i * 12.0, Color(0.75, 0.9, 1.0)))
		tw.tween_interval(0.25)
	tw.tween_property(sprite, "modulate", Color(0.8, 0.95, 1.5, 0.0), 1.6)   # 낡은 절구로 돌아간다 (의식대의 mortar_altar 가 그 자리)
	tw.tween_callback(queue_free)
