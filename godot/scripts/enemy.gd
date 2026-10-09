class_name Enemy
extends CharacterBody2D
## Plague creatures. KIND picks the sheet and behaviour:
##   dog   — 역병 들개: circles in, crouches (red tell), then lunges with open jaws
##   ghoul — 역귀 졸개: shambles closer, raises both arms (tell), rakes down
##   sea   — 갯귀 (바다 요괴): drags itself forward, lifts its barnacled claw high (long tell), slams
## 설화 요괴 each add a gimmick on top of that loop (see EXTRA and the "gimmicks" section below):
##   마마귀신 종기 투사체 · 달걀귀신 은신 · 처녀귀신 울음 스턴 · 물귀신 발목 끌기 · 외눈박이 감투 은신 · 불도깨비 불 장판 ·
##   장산범 목소리 유인 · 산군 돌진(벽에 부딪히면 휘청) · 여우 환술 분신 · 손각시 붉은 실 · 장승 단단함 · 해태 부적 흡수 ·
##   어둑시니 어둠 · 파도 요괴 파도 돌진 · 망자 서로 일으킴 · 불개 일식 · 저승 파수꾼 정면 방어
## Elites (정예) carry a name and an overhead gauge.
## Hit: white flash + knockback. At 0 HP it does not die: it collapses, still wreathed in 탁기
## (group "downed"). Only 처용가 purifies it (purify()); left alone it rises again.

const KINDS := {
	"dog": {"sheet": "plague_dog", "cell": Vector2i(44, 30), "feet": 28, "hp": 30, "speed": 62.0,
		"anims": {"move": [0, 1, 2, 3], "tell": [5], "strike": [4], "hurt": [5]},
		"range": 46.0, "tell": 0.4, "strike": 0.28, "dmg": 8, "faces_right": true},
	"ghoul": {"sheet": "ghoul", "cell": Vector2i(30, 42), "feet": 40, "hp": 40, "speed": 30.0,
		"anims": {"move": [0, 1, 2, 3], "tell": [4], "strike": [5], "hurt": [0]},
		"range": 22.0, "tell": 0.5, "strike": 0.25, "dmg": 10, "faces_right": false},
	"sea": {"sheet": "gaetgwi", "cell": Vector2i(44, 54), "feet": 52, "hp": 44, "speed": 24.0,
		"anims": {"move": [0, 1, 2, 3], "tell": [4], "strike": [5], "hurt": [6]},
		"range": 30.0, "tell": 0.9, "strike": 0.3, "dmg": 12, "faces_right": false},
	# ---- 설화 요괴 (art/monsters.py, 7-frame sheets: move0-3, tell, strike, hurt). Baseline AI; gimmicks per kind later.
	"mama": {"sheet": "mama", "cell": Vector2i(48, 58), "feet": 56, "hp": 70, "speed": 22.0,
		"anims": {"move": [0, 1, 2, 3], "tell": [4], "strike": [5], "hurt": [6]},
		"range": 60.0, "tell": 0.8, "strike": 0.35, "dmg": 12, "faces_right": false},
	"egg_ghost": {"sheet": "egg_ghost", "cell": Vector2i(34, 56), "feet": 54, "hp": 36, "speed": 46.0,
		"anims": {"move": [0, 1, 2, 3], "tell": [4], "strike": [5], "hurt": [6]},
		"range": 26.0, "tell": 0.5, "strike": 0.25, "dmg": 10, "faces_right": false},
	"maiden_ghost": {"sheet": "maiden_ghost", "cell": Vector2i(34, 56), "feet": 54, "hp": 40, "speed": 28.0,
		"anims": {"move": [0, 1, 2, 3], "tell": [4], "strike": [5], "hurt": [6]},
		"range": 48.0, "tell": 0.9, "strike": 0.4, "dmg": 6, "faces_right": false},
	"mulgwi": {"sheet": "mulgwi", "cell": Vector2i(56, 46), "feet": 40, "hp": 44, "speed": 18.0,
		"anims": {"move": [0, 1, 2, 3], "tell": [4], "strike": [5], "hurt": [6]},
		"range": 40.0, "tell": 0.7, "strike": 0.35, "dmg": 10, "faces_right": false},
	"dokkaebi_oneeye": {"sheet": "dokkaebi_oneeye", "cell": Vector2i(48, 56), "feet": 54, "hp": 60, "speed": 30.0,
		"anims": {"move": [0, 1, 2, 3], "tell": [4], "strike": [5], "hurt": [6]},
		"range": 30.0, "tell": 0.7, "strike": 0.3, "dmg": 14, "faces_right": false},
	"dokkaebi_fire": {"sheet": "dokkaebi_fire", "cell": Vector2i(48, 56), "feet": 54, "hp": 60, "speed": 30.0,
		"anims": {"move": [0, 1, 2, 3], "tell": [4], "strike": [5], "hurt": [6]},
		"range": 30.0, "tell": 0.7, "strike": 0.3, "dmg": 14, "faces_right": false},
	"jangsanbeom": {"sheet": "jangsanbeom", "cell": Vector2i(66, 44), "feet": 42, "hp": 120, "speed": 58.0,
		"anims": {"move": [0, 1, 2, 3], "tell": [4], "strike": [5], "hurt": [6]},
		"range": 50.0, "tell": 0.6, "strike": 0.3, "dmg": 16, "faces_right": true},
	"sangun": {"sheet": "sangun", "cell": Vector2i(66, 44), "feet": 42, "hp": 90, "speed": 56.0,
		"anims": {"move": [0, 1, 2, 3], "tell": [4], "strike": [5], "hurt": [6]},
		"range": 60.0, "tell": 0.7, "strike": 0.35, "dmg": 16, "faces_right": true},
	"fox_minion": {"sheet": "fox_minion", "cell": Vector2i(36, 50), "feet": 48, "hp": 40, "speed": 40.0,
		"anims": {"move": [0, 1, 2, 3], "tell": [4], "strike": [5], "hurt": [6]},
		"range": 44.0, "tell": 0.6, "strike": 0.3, "dmg": 10, "faces_right": false},
	"songaksi": {"sheet": "songaksi", "cell": Vector2i(40, 56), "feet": 54, "hp": 56, "speed": 26.0,
		"anims": {"move": [0, 1, 2, 3], "tell": [4], "strike": [5], "hurt": [6]},
		"range": 50.0, "tell": 0.8, "strike": 0.35, "dmg": 12, "faces_right": false},
	"jangseung_taki": {"sheet": "jangseung_taki", "cell": Vector2i(34, 64), "feet": 62, "hp": 140, "speed": 14.0,
		"anims": {"move": [0, 1, 2, 3], "tell": [4], "strike": [5], "hurt": [6]},
		"range": 28.0, "tell": 1.0, "strike": 0.35, "dmg": 18, "faces_right": false},
	"haetae": {"sheet": "haetae", "cell": Vector2i(66, 44), "feet": 42, "hp": 160, "speed": 50.0,
		"anims": {"move": [0, 1, 2, 3], "tell": [4], "strike": [5], "hurt": [6]},
		"range": 56.0, "tell": 0.8, "strike": 0.35, "dmg": 16, "faces_right": true},
	"eodukssini": {"sheet": "eodukssini", "cell": Vector2i(52, 64), "feet": 62, "hp": 60, "speed": 20.0,
		"anims": {"move": [0, 1, 2, 3], "tell": [4], "strike": [5], "hurt": [6]},
		"range": 40.0, "tell": 1.0, "strike": 0.4, "dmg": 8, "faces_right": false},
	"pado": {"sheet": "pado", "cell": Vector2i(60, 44), "feet": 42, "hp": 50, "speed": 60.0,
		"anims": {"move": [0, 1, 2, 3], "tell": [4], "strike": [5], "hurt": [6]},
		"range": 60.0, "tell": 0.7, "strike": 0.35, "dmg": 14, "faces_right": true},
	"mangja": {"sheet": "mangja", "cell": Vector2i(28, 44), "feet": 42, "hp": 24, "speed": 26.0,
		"anims": {"move": [0, 1, 2, 3], "tell": [4], "strike": [5], "hurt": [6]},
		"range": 20.0, "tell": 0.5, "strike": 0.25, "dmg": 8, "faces_right": false},
	"bulgae": {"sheet": "bulgae", "cell": Vector2i(66, 48), "feet": 46, "hp": 140, "speed": 56.0,
		"anims": {"move": [0, 1, 2, 3], "tell": [4], "strike": [5], "hurt": [6]},
		"range": 56.0, "tell": 0.7, "strike": 0.35, "dmg": 12, "faces_right": true},
	"jeoseung_guard": {"sheet": "jeoseung_guard", "cell": Vector2i(54, 72), "feet": 70, "hp": 120, "speed": 24.0,
		"anims": {"move": [0, 1, 2, 3], "tell": [4], "strike": [5], "hurt": [6]},
		"range": 40.0, "tell": 0.8, "strike": 0.3, "dmg": 16, "faces_right": false},
}

## per-kind gimmick settings layered over KINDS
const EXTRA := {
	"mama": {"elite": "마마귀신", "keep": 92.0, "melee": false},
	"egg_ghost": {"strike": 0.32},
	"maiden_ghost": {"keep": 66.0, "melee": false},
	"mulgwi": {"melee": false},
	"dokkaebi_oneeye": {},
	"dokkaebi_fire": {},
	"jangsanbeom": {"elite": "장산범", "strike": 0.42},
	"sangun": {"strike": 0.55, "contact": 22.0},
	"fox_minion": {"melee": false, "keep": 56.0},
	"songaksi": {"elite": "손각시", "keep": 74.0, "melee": false},
	"jangseung_taki": {"contact": 30.0},
	"haetae": {"elite": "해태", "neutral": true, "strike": 0.5, "contact": 24.0},
	"eodukssini": {},
	"pado": {"strike": 0.5, "contact": 24.0},
	"mangja": {},
	"bulgae": {"elite": "불개", "strike": 0.42, "contact": 24.0},
	"jeoseung_guard": {"melee": false},
}

signal telegraph   # wind-up began (tutorial: teach the roll here)
signal hit_taken
signal collapsed   # fell into 탁기 (downed)
signal purified

@export var kind := "dog"
var cfg: Dictionary
var hp := 1
var state := "idle"
var st := 0.0
var cd := 1.0
var knock := Vector2.ZERO
var lunge_dir := Vector2.ZERO
var flash := 0.0
var sprite: AnimatedSprite2D
var target: Node2D
var st_down := 0.0
var miasma: CPUParticles2D
const DOWN_TIME := 9.0
var ex: Dictionary = {}       # EXTRA for this kind
var alpha := 1.0              # stealth fade (sprite alpha eases toward want_alpha)
var want_alpha := 1.0
var reveal_t := 0.0
var gim_t := 4.0              # timer for periodic gimmicks
var aux_t := 0.0              # secondary timer (eclipse, blackout, lure…)
var aux_v := Vector2.ZERO
var stagger_time := 0.0
var is_clone := false
var life_t := 6.0
var guard_dir := Vector2.DOWN
var grow := 1.0               # 어둑시니: grows while you are near it
var surround := 0.0
var _bar: Node2D
var _bar_fill: ColorRect
var _voice: Label


func _ready() -> void:
	cfg = KINDS[kind].duplicate()
	ex = EXTRA.get(kind, {})
	if ex.has("strike"):
		cfg["strike"] = ex["strike"]
	hp = cfg["hp"] if not is_clone else 1
	gim_t = randf_range(3.0, 6.0)
	surround = randf() * TAU
	add_to_group("enemy")
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	var col := CollisionShape2D.new()
	var sh := RectangleShape2D.new()
	sh.size = Vector2(14, 6)
	col.shape = sh
	col.position = Vector2(0, -3)
	add_child(col)
	sprite = AnimatedSprite2D.new()
	var tex: Texture2D = Tex.lit("res://assets/sprites/%s.png" % cfg["sheet"])
	var cell: Vector2i = cfg["cell"]
	var frames := SpriteFrames.new()
	frames.remove_animation("default")
	for a in cfg["anims"]:
		frames.add_animation(a)
		frames.set_animation_speed(a, 8.0)
		for i in cfg["anims"][a]:
			var at := AtlasTexture.new()
			at.atlas = tex
			at.region = Rect2(i * cell.x, 0, cell.x, cell.y)
			frames.add_frame(a, at)
	sprite.sprite_frames = frames
	sprite.offset = Vector2(0, cell.y / 2.0 - float(cfg["feet"]))
	sprite.play("move")
	add_child(sprite)
	target = get_tree().current_scene.get_node_or_null("Player")
	if is_clone:
		alpha = 0.55; want_alpha = 0.55
	if ex.has("elite"):
		_make_bar()
	if ex.get("neutral", false):
		state = "neutral"
	if kind == "mulgwi":
		want_alpha = 0.3; alpha = 0.3


# ---------------------------------------------------------------- elite gauge
func _make_bar() -> void:
	_bar = Node2D.new()
	_bar.position = Vector2(-14, -float(cfg["feet"]) - 6)
	_bar.z_index = 44
	_bar.z_as_relative = false
	var bg := ColorRect.new()
	bg.size = Vector2(28, 4)
	bg.color = Color(0.03, 0.02, 0.05, 0.85)
	_bar.add_child(bg)
	_bar_fill = ColorRect.new()
	_bar_fill.position = Vector2(1, 1)
	_bar_fill.size = Vector2(26, 2)
	_bar_fill.color = Color(0.85, 0.25, 0.3)
	_bar.add_child(_bar_fill)
	var nm := Label.new()
	nm.text = ex["elite"]
	nm.add_theme_font_override("font", DialogBox._pixel_font("res://assets/fonts/Galmuri11.ttf"))
	nm.add_theme_font_size_override("font_size", 12)
	nm.add_theme_color_override("font_color", Color(0.95, 0.82, 0.55))
	nm.add_theme_color_override("font_outline_color", Color(0.02, 0.02, 0.05))
	nm.add_theme_constant_override("outline_size", 4)
	nm.position = Vector2(-20, -16)
	nm.size = Vector2(68, 14)
	nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_bar.add_child(nm)
	_bar.visible = false
	add_child(_bar)


func _physics_process(delta: float) -> void:
	st += delta
	cd -= delta
	gim_t -= delta
	aux_t -= delta
	reveal_t -= delta
	flash = maxf(0.0, flash - delta)
	var col := Color(2.6, 2.6, 2.6) if flash > 0.0 else (Color(1.6, 0.6, 0.6) if state == "tell" and fmod(st, 0.12) < 0.06 else Color.WHITE)
	alpha = move_toward(alpha, want_alpha if reveal_t <= 0.0 else 1.0, delta * 3.0)
	col.a = alpha
	sprite.modulate = col
	knock = knock.move_toward(Vector2.ZERO, 600.0 * delta)
	if kind == "jangseung_taki":
		knock = Vector2.ZERO   # 돌장승은 밀리지 않는다
	if _bar:
		_bar.visible = state not in ["neutral", "dead", "downed"]
		_bar_fill.size.x = roundf(26.0 * clampf(float(hp) / float(cfg["hp"]), 0.0, 1.0))
	if state == "dead":
		return
	if state == "downed":
		# the song holds the 탁기 still while it is being sung
		if not (target and target.get("state") == "song"):
			st_down -= delta
		if st_down <= 0.0:
			_rise()
		return
	if is_clone:
		life_t -= delta
		if life_t <= 0.0:
			_poof()
			return
	var to := (target.global_position - global_position) if target else Vector2.ZERO
	var d := to.length()
	var v := Vector2.ZERO
	_ambient(delta, to, d)
	match state:
		"neutral":   # 해태: wanders and waits to be tested
			sprite.play("move")
			v = Vector2.from_angle(st * 0.4) * 12.0
		"idle":
			if d < 130.0:
				state = "chase"
				guard_dir = to.normalized()   # it turns to face what it noticed
		"chase":
			sprite.play("move")
			v = _chase_vel(to, d)
			_chase_hook(to, d)
			if state == "chase" and d <= _reach() and cd <= 0.0:
				_begin_tell(to)
		"tell":
			if st >= cfg["tell"]:
				state = "strike"; st = 0.0
				sprite.play("strike")
				_on_strike(to, d)
		"strike":
			v = _strike_vel(to, d)
			if ex.get("melee", true) and d < ex.get("contact", cfg["range"] * 0.7) and target.has_method("hurt"):
				target.hurt(_dmg(), to.normalized())
			if st >= cfg["strike"]:
				_after_strike(to, d)
		"stagger":   # vulnerable after a charge, a slam or an eclipse
			sprite.play("hurt")
			if st >= stagger_time:
				state = "chase"; cd = randf_range(0.6, 1.2)
		"vanish":
			v = _vanish(delta, to, d)
		"lure":
			v = _lure(delta, to, d)
		"hurt":
			sprite.play("hurt")
			if st >= 0.25:
				state = "chase"
	velocity = v + knock
	move_and_slide()
	if kind == "sangun" and state == "strike" and get_slide_collision_count() > 0:
		for i in get_slide_collision_count():
			if get_slide_collision(i).get_collider() != target:
				_stagger(1.3)   # 산군 slammed into a wall
				break
	if absf(velocity.x) > 4.0:
		var right := velocity.x > 0.0
		sprite.flip_h = (not right) if cfg["faces_right"] else false
	elif cfg["faces_right"] and state == "tell":
		sprite.flip_h = to.x < 0.0


func _dmg() -> int:
	var dm := int(cfg["dmg"])
	if is_clone:
		dm = dm / 2
	if kind == "eodukssini":
		dm = int(dm * grow)
	if kind == "bulgae" and aux_t > 0.0:
		dm += 3
	return dm


func _reach() -> float:
	if ex.has("keep"):
		return ex["keep"] + 40.0
	return cfg["range"] * (1.4 if kind == "eodukssini" else 1.0) * (grow if kind == "eodukssini" else 1.0)


func _begin_tell(to: Vector2) -> void:
	Audio.sfx("tell", -10.0)
	state = "tell"; st = 0.0
	lunge_dir = to.normalized()
	sprite.play("tell")
	reveal_t = maxf(reveal_t, cfg["tell"] + cfg["strike"] + 0.3)
	telegraph.emit()


func _stagger(sec: float) -> void:
	state = "stagger"; st = 0.0
	stagger_time = sec


## movement while closing in
func _chase_vel(to: Vector2, d: float) -> Vector2:
	var sp: float = cfg["speed"]
	if kind == "bulgae" and aux_t > 0.0:
		sp *= 1.5
	if kind == "mulgwi":
		return Vector2.ZERO   # waits in the water
	if ex.has("keep"):        # ranged kinds hold a distance
		var keep: float = ex["keep"]
		if d < keep - 18.0:
			return -to.normalized() * sp
		if d > keep + 18.0:
			return to.normalized() * sp
		return to.normalized().orthogonal() * sin(st * 1.3) * sp * 0.6
	if d <= cfg["range"]:
		return Vector2.ZERO
	var v := to.normalized() * sp
	match kind:
		"dog":
			v += to.normalized().orthogonal() * sin(st * 2.0) * 25.0
		"jangseung_taki":   # it hops: moves only in the air
			v *= 2.2 if fmod(st, 0.7) < 0.3 else 0.0
		"mangja":           # the horde fans out to surround
			v = (to + Vector2.from_angle(surround) * 18.0).normalized() * sp
	return v


## periodic gimmicks that interrupt the chase
func _chase_hook(to: Vector2, d: float) -> void:
	if gim_t > 0.0:
		return
	match kind:
		"dokkaebi_oneeye":
			if d < 160.0:
				state = "vanish"; st = 0.0; gim_t = 7.0
				want_alpha = 0.06
				aux_v = target.global_position + to.normalized().orthogonal() * (34.0 if randf() < 0.5 else -34.0)
		"jangsanbeom":
			if d < 180.0:
				state = "lure"; st = 0.0; gim_t = 9.0
				want_alpha = 0.0
		"bulgae":
			if d < 200.0:
				aux_t = 4.5; gim_t = 13.0   # 일식: it bites the moon
				Game.say_toast("불개가 달을 물었다", Color(1.0, 0.55, 0.3))
				var tw := create_tween()
				tw.tween_property(sprite, "position:y", -18.0, 0.25).set_ease(Tween.EASE_OUT)
				tw.tween_property(sprite, "position:y", 0.0, 0.25).set_ease(Tween.EASE_IN)


## always-on effects (stealth, darkness, the guard's turning shield)
func _ambient(delta: float, to: Vector2, d: float) -> void:
	match kind:
		"egg_ghost":
			want_alpha = 1.0 if (state in ["tell", "strike", "stagger"] or d < 34.0) else 0.07
		"mulgwi":
			want_alpha = 1.0 if state in ["tell", "strike"] else 0.3
		"eodukssini":
			if d < 130.0:
				grow = minf(1.45, grow + delta * 0.06)   # it grows while you stand near it
			sprite.scale = Vector2(grow, grow)
			var lv: Node = get_tree().current_scene
			if lv.has_method("request_darkness"):
				lv.request_darkness(self, clampf(1.0 - d / 220.0, 0.0, 1.0) * 0.45 * grow + (0.85 if aux_t > 0.0 else 0.0))
		"bulgae":
			if aux_t > 0.0:
				var lv: Node = get_tree().current_scene
				if lv.has_method("request_darkness"):
					lv.request_darkness(self, 0.72)
				sprite.self_modulate = Color(0.55, 0.45, 0.45)
				if aux_t - delta <= 0.0:
					sprite.self_modulate = Color.WHITE
					_stagger(1.6)   # dazzled when the moon comes back
		"jeoseung_guard":
			if d > 0.1:
				var want := to.normalized()
				guard_dir = Vector2.from_angle(rotate_toward(guard_dir.angle(), want.angle(), delta * 1.7))


## what happens the instant the strike lands
func _on_strike(to: Vector2, d: float) -> void:
	match kind:
		"mama":
			for k in [-0.28, 0.0, 0.28]:
				_shoot("mama_boil", Vector2i(10, 10), 2, to.normalized().rotated(k) * 115.0, 8)
		"maiden_ghost":   # 울음: a ring that stuns whoever it sweeps over
			Audio.sfx("wail", -3.0)
			var w := Shockwave.new()
			w.max_r = 84.0; w.time = 0.6; w.color = Color(0.85, 0.8, 1.0)
			w.on_hit = func(p):
				p.hurt(4, (p.global_position - global_position).normalized())
				p.stun(1.2)
			w.position = position
			get_parent().add_child(w)
		"mulgwi":
			if d < cfg["range"] + 12.0 and target.has_method("hurt"):
				target.hurt(_dmg(), -to.normalized())     # dragged toward the water, not pushed away
				target.pull(global_position, 0.9)
				target.slow(1.6)
		"fox_minion":
			_shoot("foxfire", Vector2i(10, 10), 2, to.normalized() * 70.0, 6, 1.6, 3.0)
			if not is_clone:
				for sgn in [-1.0, 1.0]:
					var c := Enemy.new()
					c.kind = "fox_minion"
					c.is_clone = true
					c.position = position + to.normalized().orthogonal() * 26.0 * sgn
					get_parent().add_child.call_deferred(c)
		"songaksi":
			var pr := _shoot("thread_knot", Vector2i(8, 8), 2, to.normalized() * 190.0, 4)
			pr.tether = self
			pr.on_hit = func(p):
				p.slow(2.5)
				p.pull(global_position, 1.3)
		"haetae":
			for k in [-0.25, 0.0, 0.25]:
				_shoot("fireball", Vector2i(10, 10), 2, to.normalized().rotated(k) * 130.0, 8)
		"jangseung_taki":
			var w := Shockwave.new()
			w.max_r = 48.0; w.time = 0.35; w.color = Color(0.7, 0.6, 0.9)
			w.on_hit = func(p): p.hurt(_dmg(), (p.global_position - global_position).normalized())
			w.position = position + lunge_dir * 14.0
			get_parent().add_child(w)
		"eodukssini":
			aux_t = 1.4   # blackout
		"jeoseung_guard":
			if d < 62.0 and to.normalized().dot(lunge_dir) > 0.75 and target.has_method("hurt"):
				target.hurt(_dmg(), lunge_dir)


func _strike_vel(to: Vector2, d: float) -> Vector2:
	var k: float = 1.0 - st / float(cfg["strike"])
	match kind:
		"dog": return lunge_dir * 190.0 * k
		"egg_ghost": return lunge_dir * 230.0 * k
		"sangun": return lunge_dir * 280.0
		"pado": return lunge_dir * 300.0 * (0.4 + 0.6 * k)
		"jangsanbeom": return lunge_dir * 260.0 * k
		"bulgae": return lunge_dir * 250.0 * k
		"haetae": return lunge_dir * 200.0 * k if st > 0.12 else Vector2.ZERO
	return Vector2.ZERO


func _after_strike(to: Vector2, d: float) -> void:
	state = "chase"; cd = randf_range(1.0, 1.8)
	match kind:
		"dokkaebi_fire":   # the flaming club leaves the ground burning
			var h := Hazard.make("fire_patch", Vector2i(28, 14), 4)
			Audio.sfx("fire", -8.0)
			h.position = position + lunge_dir * 22.0
			get_parent().add_child(h)
		"sangun", "pado":
			_stagger(1.0)
		"jangseung_taki":
			_stagger(1.2)   # face-down after the slam: the moment to strike it
		"jeoseung_guard":
			_stagger(0.9)   # recovering from the thrust, shield down
		"songaksi":       # blinks away
			var tw := create_tween()
			tw.tween_property(self, "want_alpha", 0.0, 0.01)
			tw.tween_interval(0.35)
			tw.tween_callback(func():
				position += Vector2.from_angle(randf() * TAU) * 50.0
				want_alpha = 1.0)
		"mulgwi":
			cd = 2.2


## 외눈박이: 감투를 쓰고 사라져 옆으로 돌아 들어온다
func _vanish(delta: float, to: Vector2, d: float) -> Vector2:
	var go := aux_v - global_position
	if st > 1.6 or go.length() < 6.0:
		want_alpha = 1.0
		_begin_tell(to)
		return Vector2.ZERO
	return go.normalized() * 95.0


## 장산범: 모습을 감추고 엉뚱한 곳에서 사람 목소리를 낸 뒤, 반대쪽에서 덮친다
func _lure(delta: float, to: Vector2, d: float) -> Vector2:
	if _voice == null and st > 0.3:
		var at: Vector2 = target.global_position + Vector2.from_angle(randf() * TAU) * 90.0
		_voice = Label.new()
		_voice.text = ["…거기 누구 있소?", "살려 주오…", "이리 좀 와 보시오…"][randi() % 3]
		_voice.add_theme_font_override("font", DialogBox._pixel_font("res://assets/fonts/Galmuri11.ttf"))
		_voice.add_theme_font_size_override("font_size", 12)
		_voice.add_theme_color_override("font_color", Color(0.9, 0.88, 0.8, 0.9))
		_voice.add_theme_color_override("font_outline_color", Color(0.02, 0.02, 0.05))
		_voice.add_theme_constant_override("outline_size", 4)
		_voice.position = at + Vector2(-40, -40)
		_voice.z_index = 46
		_voice.z_as_relative = false
		get_parent().add_child(_voice)
		var tw := _voice.create_tween()
		tw.tween_property(_voice, "modulate:a", 0.0, 1.6).set_delay(0.6)
		tw.tween_callback(_voice.queue_free)
		aux_v = at
	if st > 1.8:
		# reappear on the far side from the voice, already crouching to pounce
		var away: Vector2 = (target.global_position - aux_v).normalized()
		position = target.global_position + away * 64.0
		_voice = null
		want_alpha = 1.0
		alpha = 0.6
		_begin_tell(target.global_position - global_position)
	return Vector2.ZERO


func _shoot(sheet: String, cell: Vector2i, n: int, vel: Vector2, dmg: int, homing := 0.0, life := 2.0) -> Projectile:
	Audio.sfx("throw", -8.0)
	var pr := Projectile.make(sheet, cell, n)
	pr.vel = vel
	pr.dmg = dmg
	pr.homing = homing
	pr.life = life
	pr.position = position + vel.normalized() * 8.0
	get_parent().add_child(pr)
	return pr


## 해태 eats the fire of a 부적 instead of being hurt by it
func absorb_talisman() -> bool:
	if kind != "haetae" or state in ["dead", "downed"]:
		return false
	hp = mini(int(cfg["hp"]), hp + 20)
	flash = 0.15
	sprite.self_modulate = Color(1.6, 1.0, 0.5)
	create_tween().tween_property(sprite, "self_modulate", Color.WHITE, 0.6)
	Game.say_toast("해태가 부적의 불기운을 삼켰다", Color(1.0, 0.7, 0.35))
	if state == "neutral":
		state = "chase"
	return true


## fox clones burst into smoke when struck or when their time runs out
func _poof() -> void:
	state = "dead"
	remove_from_group("enemy")
	var tw := create_tween()
	tw.tween_property(sprite, "modulate", Color(1.4, 0.8, 1.6, 0.0), 0.25)
	tw.tween_callback(queue_free)


func take_hit(dmg: int, dir: Vector2, heavy := false) -> void:
	if state == "dead" or state == "downed":
		return
	if is_clone:
		_poof()
		return
	if state == "neutral":
		state = "chase"; cd = 0.8   # 해태 accepts the challenge
	if kind == "jeoseung_guard" and state not in ["strike", "stagger"] and guard_dir.dot(-dir) > 0.45:
		flash = 0.05                 # 정면 방어: the blow glances off
		Audio.sfx("block", -3.0)
		knock = dir * 40.0
		_spark(-dir)
		return
	var mult := 1.0
	if state == "stagger":
		mult = 2.0 if kind == "jangseung_taki" else 1.5
	elif kind == "jangseung_taki":
		mult = 0.4
	dmg = int(ceil(dmg * mult))
	reveal_t = 2.0
	Audio.sfx("hit", -3.0)
	if kind == "eodukssini":
		grow = maxf(0.85, grow - 0.1)
	if state in ["vanish", "lure"]:
		want_alpha = 1.0
		state = "hurt"; st = 0.0
	hp -= dmg
	flash = 0.08
	hit_taken.emit()
	knock = dir * (220.0 if heavy else 130.0)
	if hp <= 0:
		_down()
	elif state == "stagger":
		pass
	elif state != "strike" or heavy:
		state = "hurt"; st = 0.0


func _spark(dir: Vector2) -> void:
	var p := CPUParticles2D.new()
	p.one_shot = true
	p.amount = 8
	p.lifetime = 0.3
	p.explosiveness = 1.0
	p.direction = dir
	p.spread = 50.0
	p.gravity = Vector2.ZERO
	p.initial_velocity_min = 60.0
	p.initial_velocity_max = 110.0
	p.color = Color(0.8, 0.9, 1.0)
	p.position = Vector2(0, -30) + dir * 10.0
	p.z_index = 45
	p.z_as_relative = false
	add_child(p)
	p.emitting = true
	p.finished.connect(p.queue_free)


## collapsed and smoking with 탁기 — waiting for the song
func _down() -> void:
	state = "downed"
	st_down = DOWN_TIME
	if kind == "mangja":   # the horde lifts its fallen quickly — sing before they do
		for e in get_tree().get_nodes_in_group("enemy"):
			if e != self and e.get("kind") == "mangja" and e.global_position.distance_to(global_position) < 60.0:
				st_down = 3.0
				break
	if _bar:
		_bar.visible = false
	remove_from_group("enemy")
	add_to_group("downed")
	sprite.play("hurt")
	sprite.modulate = Color(0.55, 0.5, 0.65)
	sprite.rotation = 0.25 if kind == "dog" else 0.0
	sprite.scale = Vector2(1.0, 0.8)
	collapsed.emit()
	miasma = CPUParticles2D.new()
	miasma.amount = 18
	miasma.lifetime = 1.6
	miasma.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	miasma.emission_rect_extents = Vector2(10, 4)
	miasma.position = Vector2(0, -8)
	miasma.direction = Vector2(0, -1)
	miasma.gravity = Vector2(0, -10)
	miasma.initial_velocity_min = 4.0
	miasma.initial_velocity_max = 12.0
	miasma.scale_amount_min = 2.0
	miasma.scale_amount_max = 4.0
	miasma.color = Color(0.25, 0.1, 0.32, 0.75)
	add_child(miasma)


func _rise() -> void:
	remove_from_group("downed")
	add_to_group("enemy")
	miasma.queue_free()
	hp = int(cfg["hp"]) / 2
	sprite.modulate = Color.WHITE
	sprite.rotation = 0.0
	sprite.scale = Vector2.ONE
	state = "chase"
	cd = 0.6


func purify() -> void:
	if state != "downed":
		return
	if is_instance_valid(miasma):
		miasma.queue_free()
	_purify()


func _purify() -> void:
	state = "dead"
	remove_from_group("enemy")
	remove_from_group("downed")
	purified.emit()
	Audio.sfx("purify", -4.0, 0.03)
	if not is_clone:   # 맑아진 탁기 → 정기·덕망 (growth-system §1)
		var lv: Node = get_tree().current_scene
		var r := Game.reward_purify(kind, global_position, get_parent())
		if lv.has_method("on_purified"):
			lv.on_purified(r, global_position)
	var motes := CPUParticles2D.new()
	motes.amount = 24
	motes.lifetime = 1.2
	motes.one_shot = true
	motes.explosiveness = 0.8
	motes.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	motes.emission_rect_extents = Vector2(10, 8)
	motes.position = Vector2(0, -14)
	motes.direction = Vector2(0, -1)
	motes.spread = 40.0
	motes.gravity = Vector2(0, -30)
	motes.initial_velocity_min = 10.0
	motes.initial_velocity_max = 40.0
	motes.color = Color(0.6, 0.85, 1.0, 0.9)
	var add := CanvasItemMaterial.new()
	add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	add.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	motes.material = add
	add_child(motes)
	motes.emitting = true
	var tw := create_tween().set_parallel()
	tw.tween_property(sprite, "modulate", Color(0.7, 0.9, 1.4, 0.0), 0.8)
	tw.tween_property(sprite, "position:y", -10.0, 0.8)
	tw.chain().tween_interval(0.6)
	tw.chain().tween_callback(queue_free)
