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
