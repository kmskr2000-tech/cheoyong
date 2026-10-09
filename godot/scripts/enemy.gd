class_name Enemy
extends CharacterBody2D
## Plague creatures. KIND picks the sheet and behaviour:
##   dog   — 역병 들개: circles in, crouches (red tell), then lunges with open jaws
##   ghoul — 역귀 졸개: shambles closer, raises both arms (tell), rakes down
## Hit: white flash + knockback. Death: purified — the body pales and drifts up as blue motes.

const KINDS := {
	"dog": {"sheet": "plague_dog", "cell": Vector2i(44, 30), "feet": 28, "hp": 30, "speed": 62.0,
		"anims": {"move": [0, 1, 2, 3], "tell": [5], "strike": [4], "hurt": [5]},
		"range": 46.0, "tell": 0.4, "strike": 0.28, "dmg": 8, "faces_right": true},
	"ghoul": {"sheet": "ghoul", "cell": Vector2i(30, 42), "feet": 40, "hp": 40, "speed": 30.0,
		"anims": {"move": [0, 1, 2, 3], "tell": [4], "strike": [5], "hurt": [0]},
		"range": 22.0, "tell": 0.5, "strike": 0.25, "dmg": 10, "faces_right": false},
}

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


func _ready() -> void:
	cfg = KINDS[kind]
	hp = cfg["hp"]
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


func _physics_process(delta: float) -> void:
	st += delta
	cd -= delta
	flash = maxf(0.0, flash - delta)
	sprite.modulate = Color(2.6, 2.6, 2.6) if flash > 0.0 else (Color(1.6, 0.6, 0.6) if state == "tell" and fmod(st, 0.12) < 0.06 else Color.WHITE)
	knock = knock.move_toward(Vector2.ZERO, 600.0 * delta)
	if state == "dead":
		return
	var to := (target.global_position - global_position) if target else Vector2.ZERO
	var d := to.length()
	var v := Vector2.ZERO
	match state:
		"idle":
			if d < 130.0:
				state = "chase"
		"chase":
			sprite.play("move")
			if d > cfg["range"]:
				v = to.normalized() * cfg["speed"]
				if kind == "dog":  # dogs circle a little as they close in
					v += to.normalized().orthogonal() * sin(st * 2.0) * 25.0
			elif cd <= 0.0:
				state = "tell"; st = 0.0
				lunge_dir = to.normalized()
				sprite.play("tell")
		"tell":
			if st >= cfg["tell"]:
				state = "strike"; st = 0.0
				sprite.play("strike")
		"strike":
			if kind == "dog":
				v = lunge_dir * 190.0 * (1.0 - st / cfg["strike"])
			if d < cfg["range"] * 0.7 and target.has_method("hurt"):
				target.hurt(cfg["dmg"], to.normalized())
			if st >= cfg["strike"]:
				state = "chase"; cd = randf_range(1.0, 1.8)
		"hurt":
			sprite.play("hurt")
			if st >= 0.25:
				state = "chase"
	velocity = v + knock
	move_and_slide()
	if absf(velocity.x) > 4.0:
		var right := velocity.x > 0.0
		sprite.flip_h = (not right) if cfg["faces_right"] else false


func take_hit(dmg: int, dir: Vector2, heavy := false) -> void:
	if state == "dead":
		return
	hp -= dmg
	flash = 0.08
	knock = dir * (220.0 if heavy else 130.0)
	if hp <= 0:
		_purify()
	elif state != "strike" or heavy:
		state = "hurt"; st = 0.0


func _purify() -> void:
	state = "dead"
	remove_from_group("enemy")
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
