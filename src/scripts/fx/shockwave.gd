class_name Shockwave
extends Node2D
## An expanding ring on the ground (울음 파동, 장승의 박치기). When its edge sweeps over the hero — unless he
## is rolling through it — `on_hit(player)` fires once.

var max_r := 70.0
var time := 0.5
var color := Color(0.8, 0.85, 1.0)
var on_hit: Callable
var _t := 0.0
var _done := false
var _ring: Line2D


func _ready() -> void:
	_ring = Line2D.new()
	_ring.width = 2.0
	_ring.default_color = color
	var add := CanvasItemMaterial.new()
	add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	add.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	_ring.material = add
	add_child(_ring)
	z_index = 39
	z_as_relative = false


func _physics_process(delta: float) -> void:
	_t += delta
	var k := clampf(_t / time, 0.0, 1.0)
	var r := 6.0 + (max_r - 6.0) * (1.0 - pow(1.0 - k, 2.0))
	var pts := PackedVector2Array()
	for i in 33:
		pts.append(Vector2.from_angle(i * TAU / 32) * r)   # world distances are not squashed: a true circle
	_ring.points = pts
	_ring.modulate.a = 1.0 - k
	var p: Node2D = get_tree().current_scene.get_node_or_null("Player")
	if not _done and p:
		var off := p.global_position - global_position
		var dist := off.length()
		if absf(dist - r) < 10.0 and p.get("state") != "roll":
			_done = true
			if on_hit.is_valid():
				on_hit.call(p)
	if k >= 1.0:
		queue_free()
