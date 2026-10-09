extends CharacterBody2D
## 처용: 8-direction movement, 4-facing walk animation, a three-hit 대금 combo (cut-out arm swung
## around the shoulder + spirit-wind slash) and a spinning dodge roll with after-images.

signal hit_landed(target: Node2D)
signal stats_changed(hp: float, max_hp: float, ki: float, max_ki: float)
signal died
signal sang(purified: int)

const SPEED := 72.0
const FRAME := Vector2i(32, 48)
const FEET_ROW := 44 # feet row inside the 48px cell; the node origin sits on it

# Sheet order written by art/build.py (art/src/cheoyong.py FRAMES).
const SHEET := {
	"down_idle": [0], "up_idle": [1], "right_idle": [2],
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

@onready var sprite: AnimatedSprite2D = $Sprite
var arm: Sprite2D
var slash: Sprite2D
var facing := "down"
var locked := false # dialogue / cutscene

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
const KI_REGEN := 6.0 # per second
const TALISMAN_COST := 35.0
var spawn := Vector2.ZERO
var interact: Callable          # level hook: returns true if something was talked to / examined
var gentle_hits := 0            # tutorial: the next N hits only knock back (no damage)
const SONG_TIME := 1.1
const SONG_RANGE := 90.0


func _ready() -> void:
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
	slash.visible = false
	slash.z_index = 40 # effects draw over the y-sorted world
	slash.z_as_relative = false
	add_child(slash)


func _physics_process(delta: float) -> void:
	t += delta
	var dir := Vector2.ZERO if locked else Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if state == "dead":
		return
	if not locked and Input.is_action_just_pressed("talisman") and state == "move":
		_talisman()
	if not locked and Input.is_action_just_pressed("song") and state == "move":
		_start_song()
	if not locked and Input.is_action_just_pressed("roll") and state != "roll":
		_start_roll(dir)
	elif not locked and Input.is_action_just_pressed("attack"):
		if state == "attack":
			queued = true
		elif state == "move":
			if interact.is_valid() and interact.call():
				return
			combo = 0
			_start_attack()
	match state:
		"move": _move(dir)
		"attack": _attack(delta)
		"roll": _roll(delta)
		"song": _song(delta)


func _move(dir: Vector2) -> void:
	velocity = dir * SPEED
	move_and_slide()
	if dir != Vector2.ZERO:
		_face(dir)
	var row := "right" if facing == "left" else facing
	sprite.flip_h = facing == "left"
	sprite.rotation = 0.0
	sprite.scale = Vector2.ONE
	var anim := row + ("_walk" if dir != Vector2.ZERO else "_idle")
	if sprite.animation != anim:
		sprite.play(anim)


func _face(dir: Vector2) -> void:
	if absf(dir.x) > absf(dir.y) + 0.1:
		facing = "right" if dir.x > 0 else "left"
	else:
		facing = "down" if dir.y > 0 else "up"


# ---------------------------------------------------------------- attack
func _start_attack() -> void:
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
	var row := "right" if facing == "left" else facing
	sprite.play(row + "_attack")
	sprite.flip_h = facing == "left"
	var sh: Array = SHOULDER[facing]
	arm.position = sh[0]
	arm.z_index = sh[1]
	arm.visible = true
	slash.visible = false


func _attack(delta: float) -> void:
	var c: Dictionary = COMBO[combo]
	var dur: float = c["time"]
	var k := clampf(t / dur, 0.0, 1.0)
	var base: float = FACE_ANGLE[facing]
	var mirror := -1.0 if facing == "left" or facing == "up" else 1.0
	var a: float
	var lunge := 0.0
	if c.get("thrust", false):
		# pull back, then drive the flute straight out with a short lunge
		a = base
		var reach := -3.0 if k < 0.3 else lerpf(-3.0, 6.0, smoothstep(0.3, 0.5, k)) if k < 0.6 else lerpf(6.0, 0.0, (k - 0.6) / 0.4)
		arm.position = (SHOULDER[facing][0] as Vector2) + Vector2.from_angle(base) * reach
		lunge = 110.0 if k > 0.3 and k < 0.55 else 0.0
	else:
		# wind-up 0-25%, fast sweep 25-55%, follow-through hold
		var from: float = c["from"] * mirror
		var to: float = c["to"] * mirror
		var s := 0.0 if k < 0.25 else smoothstep(0.25, 0.55, k)
		a = base + lerpf(from, to, s)
	arm.rotation = a
	arm.flip_v = cos(a) < -0.05 # keep the sleeve's lit side on top when pointing left
	velocity = Vector2.from_angle(base) * lunge
	move_and_slide()
	# spirit-wind crescent during the sweep
	var swing := k > 0.25 and k < 0.8
	slash.visible = swing
	if swing:
		var fk := (k - 0.25) / 0.55
		slash.frame = mini(3, int(fk * 4.0))
		slash.position = Vector2(0, -20) + Vector2.from_angle(base) * (12.0 + (6.0 if c.get("thrust", false) else 0.0))
		slash.rotation = base
		slash.scale = Vector2(0.8, 0.45) if c.get("thrust", false) else Vector2.ONE
		slash.flip_v = (c["to"] < c["from"]) != (mirror < 0)
	if not hit_done and k > 0.4:
		hit_done = true
		_resolve_hit(c, base)
	if k >= 1.0:
		if queued and combo < COMBO.size() - 1:
			combo += 1
			_start_attack()
		else:
			_end_attack()


func _end_attack() -> void:
	state = "move"
	arm.visible = false
	slash.visible = false
	combo = 0


func _resolve_hit(c: Dictionary, base: float) -> void:
	var origin := global_position + Vector2(0, -14)
	for e in get_tree().get_nodes_in_group("enemy"):
		var to: Vector2 = (e.global_position + Vector2(0, -10)) - origin
		if to.length() > c["reach"]:
			continue
		if absf(wrapf(to.angle() - base, -PI, PI)) > 1.3 and to.length() > 10:
			continue
		if e.has_method("take_hit"):
			e.take_hit(c["dmg"], to.normalized(), combo == COMBO.size() - 1)
			_spark(e.global_position + Vector2(0, -12))
			hit_landed.emit(e)


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


# ---------------------------------------------------------------- getting hit
var hurt_t := 0.0


func hurt(dmg: int, dir: Vector2) -> void:
	if invuln or hurt_t > 0.0 or state == "dead":
		return
	hurt_t = 0.6
	if gentle_hits > 0:
		gentle_hits -= 1  # 벌 없이 배운다: early hits only push him back
		dmg = 0
	hp = maxf(0.0, hp - dmg)
	stats_changed.emit(hp, max_hp, ki, max_ki)
	if hp <= 0.0:
		_die()
		return
	_end_attack()
	velocity = dir * 160.0
	move_and_slide()
	var tw := create_tween()
	for i in 3:
		tw.tween_property(sprite, "modulate", Color(1.8, 0.5, 0.5), 0.05)
		tw.tween_property(sprite, "modulate", Color.WHITE, 0.08)


func _process(delta: float) -> void:
	hurt_t = maxf(0.0, hurt_t - delta)
	if ki < max_ki and state != "dead":
		ki = minf(max_ki, ki + KI_REGEN * delta)
		stats_changed.emit(hp, max_hp, ki, max_ki)


func _die() -> void:
	state = "dead"
	_end_attack()
	velocity = Vector2.ZERO
	died.emit()
	var tw := create_tween()
	tw.tween_property(sprite, "rotation", PI / 2 * (1 if facing != "left" else -1), 0.25)
	tw.parallel().tween_property(sprite, "modulate", Color(0.5, 0.6, 0.9, 0.8), 0.6)
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


# ---------------------------------------------------------------- 처용가 (the purifying song)
## true when something nearby lies in 탁기 waiting to be sung clean
func can_sing() -> bool:
	for d in get_tree().get_nodes_in_group("downed"):
		if d.global_position.distance_to(global_position) < SONG_RANGE:
			return true
	return false


func _start_song() -> void:
	_end_attack()
	state = "song"
	t = 0.0
	velocity = Vector2.ZERO
	var row := "right" if facing == "left" else facing
	sprite.play(row + "_attack")
	# the 대금 held level at the lips
	arm.visible = true
	arm.position = (SHOULDER[facing][0] as Vector2) + Vector2(0, -4)
	arm.rotation = 0.0 if facing != "left" else PI
	arm.flip_v = facing == "left"
	arm.z_index = SHOULDER[facing][1]
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
		for d in get_tree().get_nodes_in_group("downed"):
			if d.global_position.distance_to(global_position) < SONG_RANGE:
				d.purify()
				n += 1
		arm.visible = false
		state = "move"
		sang.emit(n)


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


# ---------------------------------------------------------------- 정화부 (talisman burst)
func _talisman() -> void:
	if ki < TALISMAN_COST:
		return
	ki -= TALISMAN_COST
	stats_changed.emit(hp, max_hp, ki, max_ki)
	for e in get_tree().get_nodes_in_group("enemy"):
		var to: Vector2 = e.global_position - global_position
		if to.length() < 58.0 and e.has_method("take_hit"):
			e.take_hit(14, to.normalized(), true)
	# an expanding ring of pearl light with a paper talisman flaring at the centre
	var ring := Line2D.new()
	ring.width = 2.0
	ring.default_color = Color(0.75, 0.95, 1.0, 0.9)
	ring.material = slash.material
	ring.z_index = 40
	ring.z_as_relative = false
	for i in 33:
		ring.add_point(Vector2.from_angle(i * TAU / 32) * Vector2(1, 0.55))
	ring.position = Vector2(0, -6)
	add_child(ring)
	var tw := ring.create_tween().set_parallel()
	tw.tween_property(ring, "scale", Vector2(60, 60), 0.35).set_ease(Tween.EASE_OUT)
	tw.tween_property(ring, "width", 0.04, 0.35)
	tw.tween_property(ring, "modulate:a", 0.0, 0.4)
	tw.chain().tween_callback(ring.queue_free)
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


# ---------------------------------------------------------------- roll (춤 구르기)
func _start_roll(dir: Vector2) -> void:
	_end_attack()
	state = "roll"
	t = 0.0
	roll_dir = dir.normalized() if dir != Vector2.ZERO else Vector2.from_angle(FACE_ANGLE[facing])
	_face(roll_dir)
	invuln = true
	ghost_t = 0.0


func _roll(delta: float) -> void:
	var k := clampf(t / ROLL_TIME, 0.0, 1.0)
	velocity = roll_dir * ROLL_SPEED * (1.0 - k * 0.6)
	move_and_slide()
	# a spinning dance step: full turn, squashed low in the middle
	var spin := (1.0 if roll_dir.x >= 0 else -1.0) * TAU * smoothstep(0.0, 1.0, k)
	# spin around the body's centre, not the feet
	sprite.position = Vector2(0, -20)
	sprite.offset = Vector2(0, FRAME.y / 2.0 - FEET_ROW + 20)
	sprite.rotation = spin
	sprite.scale = Vector2(1.0 + sin(k * PI) * 0.12, 1.0 - sin(k * PI) * 0.18)
	ghost_t -= delta
	if ghost_t <= 0.0:
		ghost_t = 0.05
		_ghost()
	if k >= 1.0:
		state = "move"
		invuln = false
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
