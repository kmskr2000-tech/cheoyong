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
	var allow_nocull := false
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--map="): map = a.get_slice("=", 1)
		elif a.begins_with("--flags="): flags = a.get_slice("=", 1)
		elif a == "--allow-nocull": allow_nocull = true
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
	for L in lv.flicker:   # 라이트마다 그 라이트가 막 시야 가장자리에 걸치는 위치 (컬링 경계)
		if spots.size() < 8:
			spots.append(L.global_position + Vector2(240 + L.texture.get_width() * L.texture_scale * 0.5 + 20, 0))
			spots.append(L.global_position + Vector2(-240 - L.texture.get_width() * L.texture_scale * 0.5 - 20, 0))
	var total_off := 0
	for sp in spots:
		player.position = sp
		(player.get_node("Camera") as Camera2D).reset_smoothing()
		Engine.time_scale = 1.0
		for i in 4:
			await process_frame
		lv._cull_lights()
		Engine.time_scale = 0.0
		paused = true   # 적·NPC·물리·애니메이션까지 정지 (렌더만 남김)
		lv.set_process(false)   # 플리커(벽시계)·귀화 움직임 정지
		lv._ash.speed_scale = 0.0
		await process_frame
		await RenderingServer.frame_post_draw
		var a: Image = root.get_viewport().get_texture().get_image()
		await process_frame
		await RenderingServer.frame_post_draw
		var c: Image = root.get_viewport().get_texture().get_image()
		var noise := 0
		var nb := Rect2i()
		for y in a.get_height():
			for x in a.get_width():
				if a.get_pixel(x, y) != c.get_pixel(x, y):
					noise += 1
					nb = nb.expand(Vector2i(x, y)) if nb.size != Vector2i.ZERO else Rect2i(x, y, 1, 1)
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
		if noise > 0: print("     (대조: 같은 상태 재캡처에서도 %d px 다름, bbox %s — 렌더 비결정 성분)" % [noise, nb])
		print("  %s at %s: 컬링으로 꺼진 라이트 %d개, 전부 켠 화면과 달라진 픽셀 %d" % ["ok  " if ok else "FAIL", sp.round(), off, diff])
		if not ok: fails += 1
		paused = false
		lv.set_process(true)
		lv._ash.speed_scale = 1.0
	print("  컬링으로 꺼진 라이트 합계 %d (0이면 증명이 무의미)" % total_off)
	print("  허용 오차: 0 px (정지 후 동일 상태 재캡처 대조 노이즈도 함께 출력)")
	if total_off == 0:
		if allow_nocull:
			print("  (--allow-nocull: 이 맵은 컬링 대상 라이트가 없어 컬링 증명 대상 아님 — 컬링 외 항목은 tests/lowend_vs_main.sh 로 증명)")
		else:
			fails += 1
	Engine.time_scale = 1.0
	print("LOWEND_PIXELS ", "PASS" if fails == 0 else "FAIL")
	quit(0 if fails == 0 else 1)
