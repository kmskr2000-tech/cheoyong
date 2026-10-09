extends CharacterBody2D
## 처용: 8-direction movement, 4-facing walk animation, a three-hit 대금 combo (cut-out arm swung
## around the shoulder + spirit-wind slash) and a spinning dodge roll with after-images.

signal hit_landed(target: Node2D)

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
	if not locked and Input.is_action_just_pressed("roll") and state != "roll":
		_start_roll(dir)
	elif not locked and Input.is_action_just_pressed("attack"):
		if state == "attack":
			queued = true
		elif state == "move":
			combo = 0
			_start_attack()
	match state:
		"move": _move(dir)
		"attack": _attack(delta)
		"roll": _roll(delta)


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
