class_name Hazard
extends Node2D
## A patch of ground that hurts while it lasts (불 장판). Looping sheet animation, fades out at the end.

var radius := 14.0
var dmg := 6
var tick := 0.6
var life := 4.0
var _cd := 0.0
var _sprite: AnimatedSprite2D


static func make(sheet: String, cell: Vector2i, nframes: int, light := Color(1.0, 0.5, 0.15)) -> Hazard:
	var h := Hazard.new()
	h._sprite = AnimatedSprite2D.new()
	var tex: Texture2D = load("res://assets/sprites/%s.png" % sheet)
	var frames := SpriteFrames.new()
	frames.set_animation_speed("default", 10.0)
	for i in nframes:
		var at := AtlasTexture.new()
		at.atlas = tex
		at.region = Rect2(i * cell.x, 0, cell.x, cell.y)
		frames.add_frame("default", at)
	h._sprite.sprite_frames = frames
	h._sprite.offset = Vector2(0, -cell.y / 2.0 + 2)
	var um := CanvasItemMaterial.new()
	um.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	h._sprite.material = um
	h._sprite.play()
	h.add_child(h._sprite)
	var l := PointLight2D.new()
	var g := Gradient.new()
	g.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0)])
	var gt := GradientTexture2D.new()
	gt.gradient = g
	gt.fill = GradientTexture2D.FILL_RADIAL
	gt.fill_from = Vector2(0.5, 0.5)
	gt.fill_to = Vector2(1.0, 0.5)
	gt.width = 64
	gt.height = 64
	l.texture = gt
	l.color = light
	l.energy = 1.2
	h.add_child(l)
	return h


func _physics_process(delta: float) -> void:
	life -= delta
	_cd -= delta
	if life < 0.6:
		modulate.a = maxf(0.0, life / 0.6)
	if life <= 0.0:
		queue_free()
		return
	var p: Node2D = get_tree().current_scene.get_node_or_null("Player")
	if _cd <= 0.0 and p and p.global_position.distance_to(global_position) < radius and p.has_method("hurt"):
		p.hurt(dmg, (p.global_position - global_position).normalized())
		_cd = tick
