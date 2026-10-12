class_name Crab
extends Node2D
## 백사장 게 (SC1-02): idles and sidesteps; when the hero comes close it scuttles away sideways,
## and if it reaches the surf it slips under.

const FLEE_R := 40.0
var sprite: AnimatedSprite2D
var target: Node2D
var vel := Vector2.ZERO
var idle_t := 0.0
var level: Node


func _ready() -> void:
	sprite = AnimatedSprite2D.new()
	var tex: Texture2D = Tex.lit("res://assets/sprites/crab.png")
	var frames := SpriteFrames.new()
	frames.set_animation_speed("default", 14.0)
	for i in 2:
		var at := AtlasTexture.new()
		at.atlas = tex
		at.region = Rect2(i * 14, 0, 14, 10)
		frames.add_frame("default", at)
	sprite.sprite_frames = frames
	sprite.offset = Vector2(0, -4)
	add_child(sprite)
	target = get_tree().current_scene.get_node_or_null("Player")
	level = get_tree().current_scene


func _physics_process(delta: float) -> void:
	idle_t -= delta
	var away := global_position - target.global_position if target else Vector2.RIGHT * 99
	if away.length() < FLEE_R:
		# crabs run sideways: flee mostly along x, drifting toward the water (south)
		vel = Vector2(signf(away.x if absf(away.x) > 1 else 1.0) * 70.0, 18.0)
	elif idle_t <= 0.0:
		idle_t = randf_range(1.0, 2.6)
		vel = Vector2(randf_range(-14, 14), 0) if randf() < 0.5 else Vector2.ZERO
	else:
		vel = vel.move_toward(Vector2.ZERO, 60.0 * delta) if vel.length() > 20.0 else vel
	position += vel * delta
	if vel.length() > 2.0:
		sprite.play()
	else:
		sprite.pause()
	# reached the surf: slip under
	if level.has_method("is_water") and level.is_water(global_position):
		set_physics_process(false)
		var tw := create_tween()
		tw.tween_property(self, "modulate:a", 0.0, 0.3)
		tw.tween_callback(queue_free)
