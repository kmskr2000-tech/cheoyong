extends SceneTree
## 상 등급에서 post 셰이더가 main 과 같은 화면을 내는지 같은 프로세스·같은 정지 프레임으로 비교한다
## (프로세스가 다르면 셰이더 TIME 이 달라 픽셀이 흔들리므로 main/브랜치 별도 실행 비교는 쓰지 않는다).
##   xvfb-run godot --path src --rendering-driver opengl3 -s ../tests/lowend_shader_main.gd -- --map=gyeongju
## A = 브랜치 post.gdshader (bloom 기본값 그대로, 폴백이 건드리지 않은 상태) / B = main 의 post.gdshader (tests/fixtures/post_main.gdshader). 허용 오차 0 px.
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
	var Q: Node = root.get_node("Quality")
	Q.auto = false   # 기본 등급(상)을 자동 조정이 건드리지 않게 — 사용자가 --quality 를 주지 않은 실제 기본 경로
	var lv: Node = load("res://scenes/level.tscn").instantiate()
	root.add_child(lv)
	current_scene = lv
	for i in 40:
		await process_frame
	print("  tier=%d pinned=%s bloom 파라미터=%s" % [Q.tier, Q.pinned, lv._post_mat.get_shader_parameter("bloom")])
	Engine.time_scale = 0.0
	lv.set_process(false)
	lv._ash.speed_scale = 0.0
	await process_frame
	await RenderingServer.frame_post_draw
	var a: Image = root.get_viewport().get_texture().get_image()
	var a2: Image
	await process_frame
	await RenderingServer.frame_post_draw
	a2 = root.get_viewport().get_texture().get_image()
	var noise := _diff(a, a2)
	var new_shader: Shader = lv._post_mat.shader
	var old := Shader.new()
	old.code = FileAccess.get_file_as_string(OS.get_environment("HOME") + "/workspace/goals/rpg/dev/wt-prog-lowend/tests/fixtures/post_main.gdshader")
	lv._post_mat.shader = old
	await process_frame
	await RenderingServer.frame_post_draw
	var b: Image = root.get_viewport().get_texture().get_image()
	var d := _diff(a, b)
	lv._post_mat.shader = new_shader
	print("  동일 상태 재캡처 노이즈 %d px, 브랜치 셰이더 vs main 셰이더 달라진 픽셀 %d (허용 0)" % [noise, d])
	var ok := d == 0 and noise == 0
	print("LOWEND_SHADER_MAIN ", "PASS" if ok else "FAIL")
	quit(0 if ok else 1)


func _diff(a: Image, b: Image) -> int:
	var n := 0
	for y in a.get_height():
		for x in a.get_width():
			if a.get_pixel(x, y) != b.get_pixel(x, y):
				n += 1
	return n
