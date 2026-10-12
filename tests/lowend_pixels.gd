extends SceneTree
## 기본(상) 등급 화면 불변 증명: 시야 컬링으로 끈 라이트를 전부 켠 화면과 픽셀 비교.
##   xvfb-run godot --path src --rendering-driver opengl3 -s ../tests/lowend_pixels.gd -- --map=gyeongju [--flags=a,b]
## Engine.time_scale=0 으로 셰이더 TIME·파티클·플리커를 멈춰 두 캡처가 결정적이게 한다.
var fails := 0


func _initialize() -> void:
	_main.call_deferred()


func _main() -> void:
	var map := "gyeongju"
	var flags := "summoned,briefed,arrived"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--map="): map = a.get_slice("=", 1)
		elif a.begins_with("--flags="): flags = a.get_slice("=", 1)
	var G: Node = root.get_node("Game")
	G.level_id = map
	G.spawn_name = "start"
	for f in flags.split(",", false):
		G.flags[f] = 1
	root.get_node("Quality").set_tier(2, true)
	var lv: Node = load("res://scenes/level.tscn").instantiate()
	root.add_child(lv)
	current_scene = lv
	for i in 40:
		await process_frame
	var player: Node2D = lv.get_node("Player")
	var spots: Array[Vector2] = [player.position]
	for L in lv.flicker:   # 라이트 근처 몇 곳도 확인 (시야 가장자리에서 컬링 경계가 걸리는 위치)
		if spots.size() < 6:
			spots.append(L.global_position + Vector2(230, 40))
	var total_off := 0
	for sp in spots:
		player.position = sp
		(player.get_node("Camera") as Camera2D).reset_smoothing()
		Engine.time_scale = 1.0
		for i in 4:
			await process_frame
		lv._cull_lights()
		Engine.time_scale = 0.0
		lv._cull_t = 1e9
		await process_frame
		await RenderingServer.frame_post_draw
		var a: Image = root.get_viewport().get_texture().get_image()
		var off := 0
		for L in lv.flicker:
			if not L.visible:
				off += 1
				L.visible = true
		await process_frame
		await RenderingServer.frame_post_draw
		var b: Image = root.get_viewport().get_texture().get_image()
		var diff := 0
		for y in a.get_height():
			for x in a.get_width():
				if a.get_pixel(x, y) != b.get_pixel(x, y):
					diff += 1
		total_off += off
		var ok := diff == 0
		print("  %s at %s: 컬링으로 꺼진 라이트 %d개, 전부 켠 화면과 달라진 픽셀 %d" % ["ok  " if ok else "FAIL", sp.round(), off, diff])
		if not ok: fails += 1
		lv._cull_t = 0.0
	print("  컬링으로 꺼진 라이트 합계 %d (0이면 증명이 무의미)" % total_off)
	if total_off == 0: fails += 1
	Engine.time_scale = 1.0
	print("LOWEND_PIXELS ", "PASS" if fails == 0 else "FAIL")
	quit(0 if fails == 0 else 1)
