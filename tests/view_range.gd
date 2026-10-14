extends SceneTree
## 시점·카메라 1단계 검증 (design/gdd/view-camera.md AC1-2·AC1-3·AC1-6, 프로그래밍팀).
## 12맵 × 기기 폭 {480,585,600,640} × 8방향: 카메라를 맵 밖으로 최대한 밀어도 화면이 카메라 가동 범위 밖(= 맵 밖 빈 공간)을 보이지 않는지.
## 같이 보는 것: 뷰포트 높이 270·폭 규칙(맵 폭 상한 반영)·정수 배율, 입력 해제 후 룩어헤드 복귀(0.5초 ≤ 2px).
##   godot --headless --path src -s ../tests/view_range.gd [-- --maps=beach,palace]
const MAPS := ["beach", "gyeongju", "gwana", "pyega1", "pyega2", "palace", "hwagae", "jiri_path", "old_village", "den1", "den2", "den3"]
const WIDTHS := [480, 585, 600, 640]
const DIRS := [Vector2(1, 0), Vector2(-1, 0), Vector2(0, 1), Vector2(0, -1), Vector2(1, 1), Vector2(-1, 1), Vector2(1, -1), Vector2(-1, -1)]
var fails := 0
var checks := 0


func _ck(name: String, ok: bool, extra := "") -> void:
	checks += 1
	if not ok:
		fails += 1
		print("FAIL " + name + (" :: " + extra if extra != "" else ""))


func _initialize() -> void:
	_main.call_deferred()


func _main() -> void:
	var maps: Array = Array(MAPS)
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--maps="):
			maps = Array(a.get_slice("=", 1).split(","))
	var G: Node = root.get_node("Game")
	var V: Node = root.get_node("View")
	for m in maps:
		G.set_flag("beach_done")   # 백사장 기상 연출(3초 대기)이 장면 교체와 겹쳐 오류를 내지 않게
		G.level_id = m
		G.spawn_name = ""
		change_scene_to_file("res://scenes/level.tscn")
		for i in 400:
			await process_frame
			if current_scene != null and current_scene.get("def") != null and current_scene.get_node_or_null("Player") != null and current_scene.get("hud") != null:
				break
		var lv: Node = current_scene
		var cam: Camera2D = lv.get_node("Player/Camera")
		var player: Node2D = lv.get_node("Player")
		cam.position_smoothing_enabled = false
		var map_w: int = cam.limit_right - cam.limit_left
		var rng_h: int = cam.limit_bottom - cam.limit_top
		for w in WIDTHS:
			V.force_window(Vector2i(w * 4, 1080))
			await process_frame
			await process_frame
			var wide: bool = lv.def.get("view", "") == "wide"   # prog/view-overhaul: 와이드 맵은 뷰포트 높이 540·폭 960~맵 폭(짝수)
			var want_w: int = (clampi(w * 2, 960, maxi(960, map_w)) & ~1) if wide else mini(w, maxi(480, map_w))
			var want_h: int = 540 if wide else 270
			var vp := root.get_visible_rect().size
			_ck("%s/%d 뷰포트 %dx%d" % [m, w, want_w, want_h], int(vp.x) == want_w and int(vp.y) == want_h, str(vp))
			var xf := root.get_screen_transform()
			_ck("%s/%d 정수 배율" % [m, w], is_equal_approx(xf.x.x, roundf(xf.x.x)), str(xf.x.x))
			for d in DIRS:
				cam.position = d * 4000.0   # 최대한 밀어 limit 가 막는지 본다 (룩어헤드·데드존·프레이밍이 더해져도 이 범위 안)
				await process_frame
				await process_frame
				var c := cam.get_screen_center_position()
				var r := Rect2(c - vp / 2.0, vp)
				var ok: bool = r.position.x >= cam.limit_left - 0.01 and r.end.x <= cam.limit_right + 0.01 and r.position.y >= cam.limit_top - 0.01 and r.end.y <= cam.limit_bottom + 0.01
				_ck("%s/%d 방향 %s 맵 밖 빈 공간 없음" % [m, w, d], ok, "view=%s limit=[%d..%d]x[%d..%d]" % [r, cam.limit_left, cam.limit_right, cam.limit_top, cam.limit_bottom])
		var wide_m: bool = lv.def.get("view", "") == "wide"
		_ck("%s 카메라 범위가 뷰포트 이상" % m, map_w >= (960 if wide_m else 480) and rng_h >= (540 if wide_m else 270), "%dx%d" % [map_w, rng_h])
		# 룩어헤드: 입력 해제 후 0.5초(30프레임) 안에 오프셋 ≤ 2px (AC1-6)
		V.force_window(Vector2i(960, 540))
		await process_frame
		cam.position = Vector2(0, -16)
		lv._cam_look = Vector2(64, 40)
		await create_timer(0.5).timeout   # 게임 시간 0.5초(프레임 수가 아니라 델타 합)
		_ck("%s 룩어헤드 0.5초 복귀 (남은 %.2fpx)" % [m, lv._cam_look.length()], lv._cam_look.length() <= 2.0)
	print("VIEW_RANGE ", "PASS" if fails == 0 else "FAIL", " checks=", checks, " fails=", fails)
	quit(1 if fails > 0 else 0)
