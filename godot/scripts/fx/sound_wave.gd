class_name SoundWave
extends Node2D
## 흩날리는 음파 (소리 1단): a pale crescent of sound that flies on from each swing and
## hits every 요괴 it passes through once.

const SPEED := 190.0
const LIFE := 0.55
var dir := Vector2.RIGHT
var dmg := 5
var _t := 0.0
var _hit := []
var _sprite: Sprite2D


static func fire(from: Node2D, angle: float, dmg_: int) -> void:
	var w := SoundWave.new()
	w.dir = Vector2.from_angle(angle)
	w.dmg = dmg_
	w.global_position = from.global_position + w.dir * 14.0
	from.get_parent().add_child(w)


func _ready() -> void:
	z_index = 40
	z_as_relative = false
	_sprite = Sprite2D.new()
	_sprite.texture = load("res://assets/fx/slash.png")
	_sprite.hframes = 4
	_sprite.frame = 2
	_sprite.position = Vector2(0, -20)
	_sprite.rotation = dir.angle()
	_sprite.scale = Vector2(0.7, 0.8)
	_sprite.modulate = Color(0.6, 0.9, 1.0, 0.85)
	var add := CanvasItemMaterial.new()
	add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	add.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	_sprite.material = add
	add_child(_sprite)


func _physics_process(delta: float) -> void:
	_t += delta
	position += dir * SPEED * delta
	_sprite.modulate.a = 0.85 * (1.0 - _t / LIFE)
	for e in get_tree().get_nodes_in_group("enemy"):
		if e in _hit or not e.has_method("take_hit"):
			continue
		if (e.global_position + Vector2(0, -10)).distance_to(global_position + Vector2(0, -14)) < 14.0:
			_hit.append(e)
			e.take_hit(dmg, dir, false)
	if _t >= LIFE:
		queue_free()
