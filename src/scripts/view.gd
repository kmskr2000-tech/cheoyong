extends Node
## 화면 모드 서비스 (design/gdd/view-camera.md §5.1 A+, V-P1·V-P5).
## 높이는 270 으로 고정하고 가로만 기기 비율로 넓힌다(정수 배율 유지). 폭 = clamp(floor(270·기기W/기기H), 480, min(640, 맵 폭)).
## 480 폭 이하 기기(16:9 이하)에서는 현행 480x270 과 똑같다. 타이틀·인트로·회상처럼 480x270 기준으로 그린 장면은 fixed 로 잠근다.
## 버림(floor)을 쓰는 이유: 반올림하면 폭이 1 늘어 `기기W/폭` 이 `기기H/270` 아래로 떨어지고 정수 배율이 한 단계 내려간다.

signal changed(size: Vector2)

## 넓은 뷰(와이드) 모드 — prog/view-overhaul. Levels.DATA 의 "view": "wide" 인 맵에서만 켠다.
## 월드를 hud_scale 배(=2) 크게 다시 굽고, 뷰포트는 높이 540(처용 36px = 6.7%)으로 잡아 한 화면에 훨씬 넓은 땅을 보여 준다.
## HUD·대화창은 CanvasLayer.scale = hud_scale 로 현행 480x270 좌표계 그대로 쓴다(그래서 size 는 계속 HUD 좌표계 크기).
const WIDE_H := 540
const WIDE_MIN_W := 960
const WIDE_MAX_W := 1280
## 와이드 맵에서 걷기·구르기 속도 배율: 화면이 2배 넓어져 같은 속도가 화면 대비 절반으로 느려 보이는 것을 보정
const WIDE_MOVE := 1.35

const BASE := Vector2i(480, 270)
const MAX_W := 640

## 현재 논리 뷰포트 크기 (changed 신호로 갱신)
var size := Vector2(BASE)
var _fixed := false
var _wide := false
var hud_scale := 1       # 1 = 현행, 2 = 와이드(뷰포트 = size * 2)
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


## 월드가 보이는 뷰포트 크기(와이드에서는 size 의 hud_scale 배)
func world() -> Vector2:
	return size * float(hud_scale)


func move_scale() -> float:
	return WIDE_MOVE if hud_scale > 1 else 1.0


## 레벨이 와이드 모드인지 알린다 (level.gd _ready, set_cap 이전)
func set_wide(on: bool) -> void:
	_wide = on
	apply()


## HUD/대화창 같은 CanvasLayer 를 현재 hud_scale 로 맞춘다
func fit_layer(cl: CanvasLayer) -> void:
	cl.scale = Vector2(hud_scale, hud_scale)


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
	_cap = clampi(int(map_w), BASE.x, WIDE_MAX_W if _wide else MAX_W) & ~(1 if _wide else 0)
	apply()


func force_window(sz: Vector2i) -> void:
	_force_window = sz
	apply()


## 실제 뷰포트(content_scale_size) 크기
func target_size(window_px: Vector2i) -> Vector2i:
	if _fixed or _fixed_n > 0 or window_px.x <= 0 or window_px.y <= 0:
		return BASE
	if _wide:
		var ww := int(floor(float(WIDE_H) * window_px.x / window_px.y)) & ~1   # 짝수: HUD 좌표계(= 폭/2)가 정수가 되게
		return Vector2i(clampi(ww, WIDE_MIN_W, maxi(WIDE_MIN_W, _cap)), WIDE_H)
	var w := int(floor(float(BASE.y) * window_px.x / window_px.y))
	return Vector2i(clampi(w, BASE.x, maxi(BASE.x, _cap)), BASE.y)


func apply() -> void:
	if not is_inside_tree():
		return
	var win := get_tree().root
	var px: Vector2i = _force_window if _force_window != Vector2i.ZERO else win.size
	var t := target_size(px)
	var hs := 2 if t.y == WIDE_H else 1
	if win.content_scale_size != t:
		win.content_scale_size = t
	if _force_window != Vector2i.ZERO and win.size != _force_window and not DisplayServer.get_name() == "headless":
		win.size = _force_window
	var hud_size := Vector2(t) / float(hs)   # HUD 좌표계 = 뷰포트 / hud_scale
	if hs != hud_scale or hud_size != size:
		hud_scale = hs
		size = hud_size
		changed.emit(size)
