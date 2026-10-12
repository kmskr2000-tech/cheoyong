extends Node2D
## 결박된 적 머리 위 사슬 표식. 결박이 풀리면 사라진다. 화염이 얹히면(syn_t) 주황 불꽃 사슬로 달아오른다.
const CFX := preload("res://scripts/fx/combat_fx.gd")

var _s: Sprite2D
var _t := 0.0


func _ready() -> void:
	_s = CFX.sheet("bindmark", 4, 2, 0)
	_s.position = Vector2(-16, -34)
	_s.scale = Vector2(1.5, 1.5)
	_s.modulate = Color(0.85, 0.35, 1.0, 1.0)   # 흰 판 방지: 결박은 보랏빛 (아트팀)
	var sh := CFX.sheet("bindmark", 4, 2, 0)   # 어두운 외곽 그림자: 처용 발광 위에서도 윤곽이 읽힌다
	sh.name = "Shadow"
	sh.position = _s.position
	sh.scale = Vector2(2.1, 2.1)
	sh.modulate = Color(0, 0, 0, 0.8)
	sh.z_index = -1
	sh.z_as_relative = true
	add_child(sh)
	add_child(_s)


func _process(delta: float) -> void:
	var h := get_parent()
	_t += delta
	var syn: float = h.get_meta("syn_t", 0.0)
	if syn > 0.0:
		h.set_meta("syn_t", syn - delta)
	_s.modulate = Color(1.0, 0.62, 0.25, 0.9) if syn > 0.0 else Color(0.85, 0.35, 1.0, 1.0)
	_s.frame = (4 if syn > 0.0 else 0) + int(_t * 8.0) % 4
	var shd := get_node_or_null("Shadow")
	if shd:
		shd.frame = _s.frame
	if h.get("bind_t") == null or h.bind_t <= 0.0 or h.get("state") in ["dead", "downed"]:
		queue_free()
