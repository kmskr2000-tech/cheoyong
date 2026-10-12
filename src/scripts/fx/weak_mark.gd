extends Node2D
## 열림(후딜) 표식: 발밑 고리(open.png) + 머리 위 약점(weak.png). sec 가 지나면 사라진다. 읽는 이에게 "지금이 찬스"를 알린다.
const CFX := preload("res://scripts/fx/combat_fx.gd")

var sec := 1.0
var big := false
var _t := 0.0
var _ring: Sprite2D
var _mark: Sprite2D


func _ready() -> void:
	_ring = CFX.sheet("open", 3, 2, 1 if big else 0)
	_ring.z_index = -1
	_ring.z_as_relative = true
	_ring.position = Vector2(0, -2)
	_ring.scale = Vector2(1.2, 1.2)   # 어두운 맵에서도 읽히도록 크게·밝게 (아트팀)
	_ring.modulate = Color(1.2, 0.95, 0.6)
	add_child(_ring)
	_mark = CFX.sheet("weak", 4)
	_mark.position = Vector2(0, -78.0 if big else -40.0)
	_mark.scale = Vector2(2.4, 2.4) if big else Vector2(1.9, 1.9)
	_mark.modulate = Color(1.0, 0.72, 0.3)   # 금빛 틴트, 흰 판으로 날지 않게 과밝 제거 (아트팀)
	var sh := CFX.sheet("weak", 4)   # 어두운 외곽 그림자 — 흰 표식도 윤곽이 서도록
	sh.name = "Shadow"
	sh.scale = _mark.scale * 1.35
	sh.modulate = Color(0, 0, 0, 0.75)
	sh.position = _mark.position
	sh.z_index = -1
	sh.z_as_relative = true
	add_child(sh)
	add_child(_mark)
	# 열리는 순간의 번쩍임
	var par := get_parent().get_parent()
	if par:
		CFX.play_once(par, get_parent().global_position + Vector2(0, -(48.0 if big else 18.0)), "fullflash", 5, 22.0, 0.9 if big else 0.5)
		if big:
			CFX.vignette(get_tree(), sec)
			CFX.pop_text(par, get_parent().global_position + Vector2(0, -96), "열렸다!", CFX.COL_OPEN, 12)


func _process(delta: float) -> void:
	_t += delta
	_ring.frame = (1 if big else 0) * 3 + int(_t * 8.0) % 3
	_mark.frame = int(_t * 8.0) % 4
	var shd := get_node_or_null("Shadow")
	if shd:
		shd.frame = _mark.frame
		shd.position = _mark.position
	_mark.position.y += sin(_t * 9.0) * 0.12
	if _t >= sec:
		var a := modulate.a - delta * 4.0
		modulate.a = a
		if a <= 0.0:
			queue_free()
	var h := get_parent()
	if h and h.get("state") != null and h.state not in ["stagger", "open"]:
		queue_free()   # 맞아서 일어났다·기절 등으로 상태가 바뀌면 즉시 닫힘
