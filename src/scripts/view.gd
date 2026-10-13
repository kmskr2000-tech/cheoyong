extends Node
## 화면 모드 서비스 (design/gdd/view-camera.md §5.1 A+, V-P1·V-P5).
## 높이는 270 으로 고정하고 가로만 기기 비율로 넓힌다(정수 배율 유지). 폭 = clamp(floor(270·기기W/기기H), 480, min(640, 맵 폭)).
## 480 폭 이하 기기(16:9 이하)에서는 현행 480x270 과 똑같다. 타이틀·인트로·회상처럼 480x270 기준으로 그린 장면은 fixed 로 잠근다.
## 버림(floor)을 쓰는 이유: 반올림하면 폭이 1 늘어 `기기W/폭` 이 `기기H/270` 아래로 떨어지고 정수 배율이 한 단계 내려간다.

signal changed(size: Vector2)

const BASE := Vector2i(480, 270)
const MAX_W := 640

## 현재 논리 뷰포트 크기 (changed 신호로 갱신)
var size := Vector2(BASE)
var _fixed := false
var _cap := MAX_W
var _fixed_n := 0          # 겹치는 fixed 요청(회상 중 인트로 등)
var _force_window := Vector2i.ZERO   # 테스트용: 창 크기 흉내


func _ready() -> void:
	if is_inside_tree():
		get_tree().root.size_changed.connect(apply)
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--winsize="):   # 캡처·테스트: 기기 창 크기를 흉내(예: 2556x1179)
			var w := a.get_slice("=", 1).split("x")
			force_window(Vector2i(int(w[0]), int(w[1])))
	apply()


## 우측·중앙 정렬에 쓰는 값: 480 기준 화면과의 폭 차이
func extra() -> float:
	return size.x - float(BASE.x)


## 480 폭 UI 를 가운데 두기 위한 왼쪽 여백
func pad() -> float:
	return roundf(extra() / 2.0)


## 장면이 480x270 고정 그림이면 true (title·intro·회상). 중첩 호출을 센다.
func lock_base(on: bool) -> void:
	_fixed_n = maxi(0, _fixed_n + (1 if on else -1))
	apply()


## 장면 하나를 통째로 고정/해제 (title·intro 는 true, level 은 false)
func set_fixed(on: bool) -> void:
	_fixed = on
	apply()


## 맵 폭 상한 (V-P5). 맵 폭이 480 보다 작으면 480 으로 취급한다.
func set_cap(map_w: float) -> void:
	_cap = clampi(int(map_w), BASE.x, MAX_W)
	apply()


func force_window(sz: Vector2i) -> void:
	_force_window = sz
	apply()


func target_size(window_px: Vector2i) -> Vector2i:
	if _fixed or _fixed_n > 0 or window_px.x <= 0 or window_px.y <= 0:
		return BASE
	var w := int(floor(float(BASE.y) * window_px.x / window_px.y))
	return Vector2i(clampi(w, BASE.x, maxi(BASE.x, _cap)), BASE.y)


func apply() -> void:
	if not is_inside_tree():
		return
	var win := get_tree().root
	var px: Vector2i = _force_window if _force_window != Vector2i.ZERO else win.size
	var t := target_size(px)
	if win.content_scale_size != t:
		win.content_scale_size = t
	if _force_window != Vector2i.ZERO and win.size != _force_window and not DisplayServer.get_name() == "headless":
		win.size = _force_window
	if Vector2(t) != size:
		size = Vector2(t)
		changed.emit(size)
