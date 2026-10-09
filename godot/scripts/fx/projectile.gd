class_name Projectile
extends Node2D
## A thrown thing (종기, 여우불, 불덩이, 붉은 실). Flies at `vel`, optionally homes a little, hurts the hero on
## contact and calls `on_hit(player)` for status effects. `tether` draws a line back to its thrower.

var vel := Vector2.ZERO
var dmg := 8
var life := 2.0
var radius := 7.0
var homing := 0.0
var on_hit: Callable
var tether: Node2D
var sprite: AnimatedSprite2D
var _line: Line2D


static func make(sheet: String, cell: Vector2i, nframes: int) -> Projectile:
	var p := Projectile.new()
	p.sprite = AnimatedSprite2D.new()
	if sheet != "":
		var tex: Texture2D = load("res://assets/sprites/%s.png" % sheet)
		var frames := SpriteFrames.new()
		frames.set_animation_speed("default", 10.0)
		for i in nframes:
			var at := AtlasTexture.new()
			at.atlas = tex
			at.region = Rect2(i * cell.x, 0, cell.x, cell.y)
			frames.add_frame("default", at)
		p.sprite.sprite_frames = frames
		p.sprite.play()
	p.sprite.position = Vector2(0, -12)
	var um := CanvasItemMaterial.new()
	um.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	p.sprite.material = um
	p.add_child(p.sprite)
	p.z_index = 40
	p.z_as_relative = false
	return p


func _ready() -> void:
	if tether:
		_line = Line2D.new()
		_line.width = 1.0
		_line.default_color = Color(0.95, 0.2, 0.25)
		_line.z_index = 39
		_line.z_as_relative = false
		get_parent().add_child(_line)


func _physics_process(delta: float) -> void:
	life -= delta
	var p: Node2D = get_tree().current_scene.get_node_or_null("Player")
	if p and homing > 0.0:
		var want := (p.global_position - global_position).normalized() * vel.length()
		vel = vel.lerp(want, homing * delta)
	position += vel * delta
	if _line and is_instance_valid(tether):
		_line.points = PackedVector2Array([tether.global_position + Vector2(0, -16), global_position + Vector2(0, -12)])
	if p and p.global_position.distance_to(global_position) < radius and p.get("state") != "roll":
		if p.has_method("hurt"):
			p.hurt(dmg, vel.normalized())
		if on_hit.is_valid():
			on_hit.call(p)
		_end()
		return
	if life <= 0.0:
		_end()


func _end() -> void:
	if _line:
		_line.queue_free()
	queue_free()
