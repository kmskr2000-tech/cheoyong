extends SceneTree
## main 대비 화면 동일성 증거용: 결정적 정지 프레임을 PNG 로 저장한다. main 과 브랜치에서 똑같이 실행해 비교(tests/lowend_vs_main.sh).
##   godot --path src --rendering-driver opengl3 -s <this> -- --map=gyeongju --out=DIR [--flags=a,b]
## 위치 목록은 맵 정의의 플레이어 시작점 + 고정 오프셋(코드 버전과 무관). 폴백 코드가 없는 main 에서도 돌아가도록 Quality 를 직접 참조하지 않는다.
func _initialize() -> void:
	_main.call_deferred()


func _main() -> void:
	var map := "gyeongju"
	var out := ""
	var flags := "summoned,briefed,arrived"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--map="): map = a.get_slice("=", 1)
		elif a.begins_with("--out="): out = a.get_slice("=", 1)
		elif a.begins_with("--flags="): flags = a.get_slice("=", 1)
	var G: Node = root.get_node("Game")
	G.level_id = map
	G.spawn_name = "start"
	for f in flags.split(",", false):
		G.flags[f] = 1
	if root.has_node("Quality"):
		root.get_node("Quality").set_tier(2, true)
	var lv: Node = load("res://scenes/level.tscn").instantiate()
	root.add_child(lv)
	current_scene = lv
	for i in 40:
		await process_frame
	var player: Node2D = lv.get_node("Player")
	var home := player.position
	var offs := [Vector2.ZERO, Vector2(300, 0), Vector2(-300, 0), Vector2(600, 40), Vector2(-500, 30), Vector2(150, -60)]
	DirAccess.make_dir_recursive_absolute(out)
	var n := 0
	for o in offs:
		player.position = home + o
		(player.get_node("Camera") as Camera2D).reset_smoothing()
		for i in 6:
			await process_frame
		Engine.time_scale = 0.0
		paused = true
		lv.set_process(false)
		for c in lv.find_children("*", "CPUParticles2D", true, false):
			(c as CPUParticles2D).speed_scale = 0.0
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_viewport().get_texture().get_image().save_png("%s/%s_%d.png" % [out, map, n])
		n += 1
		paused = false
		lv.set_process(true)
		for c in lv.find_children("*", "CPUParticles2D", true, false):
			(c as CPUParticles2D).speed_scale = 1.0
		Engine.time_scale = 1.0
	print("DUMP_DONE ", map, " ", n)
	quit(0)
