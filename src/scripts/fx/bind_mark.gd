extends Node2D
## 결박된 적 머리 위 사슬 표식. 결박이 풀리면 사라진다. 화염이 얹히면(syn_t) 주황 불꽃 사슬로 달아오른다.
const CFX := preload("res://scripts/fx/combat_fx.gd")

var _s: Sprite2D
var _t := 0.0


func _ready() -> void:
	_s = CFX.sheet("bindmark", 4, 2, 0)
	_s.position = Vector2(0, -44)
	add_child(_s)


func _process(delta: float) -> void:
	var h := get_parent()
	_t += delta
	var syn: float = h.get_meta("syn_t", 0.0)
	if syn > 0.0:
		h.set_meta("syn_t", syn - delta)
	_s.frame = (4 if syn > 0.0 else 0) + int(_t * 8.0) % 4
	if h.get("bind_t") == null or h.bind_t <= 0.0 or h.get("state") in ["dead", "downed"]:
		queue_free()
