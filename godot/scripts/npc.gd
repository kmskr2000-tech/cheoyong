class_name Npc
extends StaticBody2D
## A villager standing in the world: lit sprite (normal-mapped), a slow breathing bob, solid feet.

var id := ""
var display_name := ""
var talkable := true
var sprite: Sprite2D
var _t := 0.0


func setup(npc_id: String, sheet: String, shown_name: String) -> void:
	id = npc_id
	display_name = shown_name
	sprite = Sprite2D.new()
	sprite.texture = Tex.lit("res://assets/sprites/%s.png" % sheet)
	sprite.offset = Vector2(0, 24 - 44) # 32x48 cell, feet on row 44
	add_child(sprite)
	var col := CollisionShape2D.new()
	var sh := RectangleShape2D.new()
	sh.size = Vector2(12, 6)
	col.shape = sh
	col.position = Vector2(0, -3)
	add_child(col)
	_t = randf() * 3.0


func _process(delta: float) -> void:
	_t += delta
	sprite.position.y = -1.0 if fmod(_t, 1.6) < 0.8 else 0.0


## hide / show (story beats bring people on and off stage); hidden NPCs are not solid
func set_present(on: bool) -> void:
	visible = on
	collision_layer = 1 if on else 0


## walk to a screen position (cutscenes); awaitable
func walk_to(p: Vector2, speed := 40.0) -> void:
	var tw := create_tween()
	tw.tween_property(self, "position", p, position.distance_to(p) / speed)
	await tw.finished


# ---------------------------------------------------------------- 탁기에 든 사람 (처용가로 낫는다)
signal cleansed
var _miasma: CPUParticles2D


## lying sick, wreathed in 탁기; joins group "downed" so the song finds it
func set_afflicted(on: bool) -> void:
	if on:
		add_to_group("downed")
		sprite.rotation = -PI / 2
		sprite.modulate = Color(0.7, 0.72, 0.62)
		_miasma = CPUParticles2D.new()
		_miasma.amount = 14
		_miasma.lifetime = 1.8
		_miasma.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
		_miasma.emission_rect_extents = Vector2(12, 3)
		_miasma.position = Vector2(-8, -6)
		_miasma.direction = Vector2(0, -1)
		_miasma.gravity = Vector2(0, -8)
		_miasma.initial_velocity_min = 3.0
		_miasma.initial_velocity_max = 9.0
		_miasma.scale_amount_min = 2.0
		_miasma.scale_amount_max = 3.5
		_miasma.color = Color(0.25, 0.1, 0.32, 0.7)
		add_child(_miasma)
	else:
		remove_from_group("downed")
		if is_instance_valid(_miasma):
			_miasma.emitting = false
		var tw := create_tween().set_parallel()
		tw.tween_property(sprite, "modulate", Color.WHITE, 1.2)
		tw.tween_property(sprite, "rotation", 0.0, 0.8).set_delay(0.6)


## called by 처용가
func purify() -> void:
	if not is_in_group("downed"):
		return
	set_afflicted(false)
	var motes := CPUParticles2D.new()
	motes.amount = 16
	motes.lifetime = 1.4
	motes.one_shot = true
	motes.explosiveness = 0.7
	motes.position = Vector2(-6, -8)
	motes.direction = Vector2(0, -1)
	motes.spread = 30.0
	motes.gravity = Vector2(0, -24)
	motes.initial_velocity_min = 8.0
	motes.initial_velocity_max = 26.0
	motes.color = Color(0.6, 0.85, 1.0, 0.9)
	var add := CanvasItemMaterial.new()
	add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	add.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	motes.material = add
	add_child(motes)
	motes.emitting = true
	cleansed.emit()
