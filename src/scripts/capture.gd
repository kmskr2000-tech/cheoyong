extends Node
## Headless-ish verification: `godot --path godot -- --capture=out.png [--frames=N] [--hold=move_right] [--at=x,y] [--seq=attack:5,roll:20]`
## holds an input action, waits N frames, saves the viewport and quits. Does nothing without --capture.

var out := ""
var frames := 60
var hold := ""
var at := ""
var seq := {} # frame -> action tapped on that frame
var frame_i := 0
## --perf: 프레임 시간·드로우콜·메모리 표본 수집 (헤드리스 한계: 소프트웨어 렌더라 절대 fps가 아니라 전후 비교용)
var perf := false
var perf_warm := 60
var _pw: Array[float] = []   # wall frame ms
var _pp: Array[float] = []   # script _process ms (Performance.TIME_PROCESS)
var _pf: Array[float] = []   # _physics_process ms
var _pd: Array[float] = []   # draw calls
var _po: Array[float] = []   # canvas items drawn (objects in frame)
var _last_us := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS   # keep counting frames while the game is paused (행낭 menu)
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--capture="): out = a.get_slice("=", 1)
		elif a.begins_with("--frames="): frames = int(a.get_slice("=", 1))
		elif a == "--perf": perf = true
		elif a.begins_with("--hold="): hold = a.get_slice("=", 1)
		elif a.begins_with("--at="): at = a.get_slice("=", 1)
		elif a.begins_with("--seq="):
			for item in a.get_slice("=", 1).split(","):
				seq[int(item.get_slice(":", 1))] = item.get_slice(":", 0)
	if out == "":
		set_process(false)
	else:
		Engine.max_fps = 0 if perf else 60  # frame counts ≈ seconds × 60 regardless of how light the scene is
		if hold != "":
			Input.action_press(hold)
		if at != "":
			_place.call_deferred()


func _place() -> void:
	# the title scene hands off to the level a few frames in: wait for the hero to exist
	var p: Node = null
	while p == null:
		await get_tree().process_frame
		var sc := get_tree().current_scene
		p = sc.get_node_or_null("Player") if sc else null
	await get_tree().process_frame
	p.position = Vector2(float(at.get_slice(",", 0)), float(at.get_slice(",", 1)))
	p.get_node("Camera").reset_smoothing()


func _perf_sample() -> void:
	var now := Time.get_ticks_usec()
	if frame_i > perf_warm and _last_us > 0:
		_pw.append((now - _last_us) / 1000.0)
		_pp.append(Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0)
		_pf.append(Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0)
		_pd.append(RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME))
		_po.append(RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_OBJECTS_IN_FRAME))
	_last_us = now


static func _stat(a: Array[float]) -> String:
	if a.is_empty(): return "n/a"
	var s := a.duplicate()
	s.sort()
	var sum := 0.0
	for v in s: sum += v
	return "avg %.2f p95 %.2f max %.2f" % [sum / s.size(), s[int(s.size() * 0.95)], s[-1]]


func _perf_report() -> void:
	var lv := get_tree().current_scene
	var lights := 0
	var occ := 0
	var shaders := 0
	var nodes := 0
	var stack: Array = [lv]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		nodes += 1
		if n is Light2D: lights += 1
		elif n is LightOccluder2D: occ += 1
		if n is CanvasItem and (n as CanvasItem).material is ShaderMaterial: shaders += 1
		stack.append_array(n.get_children())
	print("PERF level=", Game.level_id, " frames=", _pw.size())
	print("  wall_ms   ", _stat(_pw), "   (xvfb 소프트웨어 렌더: 상대 비교용)")
	print("  process_ms ", _stat(_pp))
	print("  physics_ms ", _stat(_pf))
	print("  drawcalls ", _stat(_pd), "  canvas_items ", _stat(_po))
	print("  nodes %d lights %d occluders %d shader_items %d enemies %d" % [nodes, lights, occ, shaders, get_tree().get_nodes_in_group("enemy").size()])
	print("  tex_mem_MB %.2f  video_mem_MB %.2f  static_mem_MB %.1f  orphan_nodes %d" % [
		RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TEXTURE_MEM_USED) / 1048576.0,
		RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_VIDEO_MEM_USED) / 1048576.0,
		Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0,
		int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT))])


func _process(_delta: float) -> void:
	frame_i += 1
	if perf: _perf_sample()
	for f in seq:
		if f == frame_i or f == frame_i - 3:
			var ev := InputEventAction.new()  # a real event, so _input handlers (dialogue) see it too
			ev.action = seq[f]
			ev.pressed = f == frame_i
			Input.parse_input_event(ev)
	frames -= 1
	if frames > 0:
		return
	await RenderingServer.frame_post_draw
	if perf: _perf_report()
	get_viewport().get_texture().get_image().save_png(out)
	print("t=", Time.get_ticks_msec(), "ms  captured ", out, "  enemies left: ", get_tree().get_nodes_in_group("enemy").size(), "  downed: ", get_tree().get_nodes_in_group("downed").size(), "  level: ", Game.level_id, "  flags: ", Game.flags)
	var pl = get_tree().current_scene.get_node_or_null("Player")
	var bs = get_tree().current_scene.get_node_or_null("Boss")
	if pl: print("player ", pl.position, " ", pl.state, " hp ", pl.hp, " stun ", snappedf(pl.stun_t, 0.1), " slow ", snappedf(pl.slow_t, 0.1), " pull ", snappedf(pl.pull_t, 0.1), " ki ", roundi(pl.ki), " 신명 ", snappedf(pl.shinmyeong, 0.1), " shield ", pl.shield, " ult ", snappedf(pl.ult_t, 0.1), " 부적 ", pl.current_talisman())
	for e in get_tree().get_nodes_in_group("enemy") + get_tree().get_nodes_in_group("downed"):
		if e is Enemy:
			print("  ", e.kind, (" clone" if e.is_clone else ""), " ", e.position.round(), " ", e.state, " hp ", e.hp, " bind ", snappedf(e.bind_t, 0.1), " a ", snappedf(e.alpha, 0.01), " grow ", snappedf(e.grow, 0.01))
	var ap := 0
	for c in Audio.get_children():
		if c is AudioStreamPlayer and c.playing: ap += 1
	print("  audio track ", Audio._track, " amb ", Audio._amb.playing, " playing ", ap, " stream ", Audio._music[Audio._cur].stream)
	print("  growth items ", Game.items, " Lv.", Game.lv, " deok ", Game.deok, " jeonggi ", Game.jeonggi, " money ", Game.money, " dogam ", Game.dogam, " mats ", Game.mats,  " tal ", Game.tal, " sp ", Game.skill_points, " skills ", Game.skills)
	var lv = get_tree().current_scene
	if lv.get("_dark") and lv._dark: print("  darkness ", snappedf(lv._dark.color.a, 0.01))
	print("  hazards/projectiles ", get_tree().current_scene.get_children().filter(func(n): return n is Hazard or n is Projectile or n is Shockwave).size())
	if bs: print("boss ", bs.position, " ", bs.state, " hp ", bs.hp)
	get_tree().quit()
