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
var _finishing := false
## --view=<안>: 시점·카메라 설계 프로토타입(design/gdd/view-camera.md). 기본값(플래그 없음)은 현행 480x270 그대로다.
##   a 현행 480x270 / a2 현행+카메라 룩어헤드 / b576 576x324 / b640 640x360 / c75 480x270 + 카메라 zoom 0.75(스프라이트 축소)
var view_mode := "a"
var view_size := Vector2(480, 270)   # 논리 해상도 (HUD가 우하단 버튼을 이만큼 밀어 앵커링한다)
var view_zoom := 1.0
var _cpu0 := 0.0   # /proc/self/stat utime+stime (초) — 프레임 시간이 다른 프로세스 때문에 부풀어도 CPU 소비량은 그대로 남는다


static func _cpu_s() -> float:
	var f := FileAccess.open("/proc/self/stat", FileAccess.READ)
	if f == null: return -1.0
	var line := f.get_line()   # /proc 파일은 길이가 0으로 보고돼 get_as_text()가 비어 있다
	if line.find(")") < 0: return -1.0
	var parts := line.substr(line.rfind(")") + 1).strip_edges().split(" ")
	return (float(parts[11]) + float(parts[12])) / 100.0   # utime, stime (14·15번째 필드; ')' 뒤 인덱스 11·12)


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS   # keep counting frames while the game is paused (행낭 menu)
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--capture="): out = a.get_slice("=", 1)
		elif a.begins_with("--frames="): frames = int(a.get_slice("=", 1))
		elif a == "--perf": perf = true
		elif a.begins_with("--view="): _set_view(a.get_slice("=", 1))
		elif a.begins_with("--hold="): hold = a.get_slice("=", 1)
		elif a.begins_with("--at="): at = a.get_slice("=", 1)
		elif a.begins_with("--seq="):
			for item in a.get_slice("=", 1).split(","):
				seq[int(item.get_slice(":", 1))] = item.get_slice(":", 0)
	if view_mode != "a":
		var sz := Vector2i(view_size)
		get_window().content_scale_size = sz
		print("VIEW ", view_mode, " logical=", sz, " zoom=", view_zoom)
	if out == "" and view_mode != "a2":
		set_process(false)
	else:
		Engine.max_fps = 0 if perf else 60  # frame counts ≈ seconds × 60 regardless of how light the scene is
		if hold != "":
			Input.action_press(hold)
		if at != "":
			_place.call_deferred()


func _set_view(v: String) -> void:
	view_mode = v
	match v:
		"b576": view_size = Vector2(576, 324)
		"b640": view_size = Vector2(640, 360)
		"c75": view_zoom = 0.75


## a2: 이동 방향으로 카메라를 미리 내민다(룩어헤드). 캡처에서는 --hold=move_right 와 함께 쓴다.
func _lookahead() -> void:
	var sc := get_tree().current_scene
	var cam: Camera2D = sc.get_node_or_null("Player/Camera") if sc else null
	if cam == null:
		return
	var d := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	cam.offset = cam.offset.lerp(d * Vector2(64, 40), 0.06)


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
	if frame_i == perf_warm: _cpu0 = _cpu_s()
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
	var shadow_lights := 0
	var occ := 0
	var shaders := 0
	var nodes := 0
	var stack: Array = [lv]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		nodes += 1
		if n is Light2D:
			lights += 1
			if (n as Light2D).shadow_enabled: shadow_lights += 1
		elif n is LightOccluder2D: occ += 1
		if n is CanvasItem and (n as CanvasItem).material is ShaderMaterial: shaders += 1
		stack.append_array(n.get_children())
	print("PERF level=", Game.level_id, " frames=", _pw.size())
	print("  wall_ms   ", _stat(_pw), "   (xvfb 소프트웨어 렌더: 상대 비교용)")
	var cpu1 := _cpu_s()
	if _cpu0 >= 0.0 and cpu1 >= 0.0 and not _pw.is_empty():
		print("  cpu_ms/frame %.1f   (프로세스 CPU 시간 ÷ 프레임, 부하 영향 적음)" % ((cpu1 - _cpu0) * 1000.0 / (_pw.size() + 1)))
	print("  process_ms ", _stat(_pp))
	print("  physics_ms ", _stat(_pf))
	print("  drawcalls ", _stat(_pd), "  canvas_items ", _stat(_po))
	print("  nodes %d lights %d (그림자 %d) occluders %d shader_items %d enemies %d" % [nodes, lights, shadow_lights, occ, shaders, get_tree().get_nodes_in_group("enemy").size()])
	print("  tex_mem_MB %.2f  video_mem_MB %.2f  static_mem_MB %.1f  orphan_nodes %d" % [
		RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TEXTURE_MEM_USED) / 1048576.0,
		RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_VIDEO_MEM_USED) / 1048576.0,
		Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0,
		int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT))])


func _process(_delta: float) -> void:
	if view_mode == "a2": _lookahead()
	if out == "":
		return
	frame_i += 1
	if perf: _perf_sample()
	for f in seq:
		if f == frame_i or f == frame_i - 3:
			var ev := InputEventAction.new()  # a real event, so _input handlers (dialogue) see it too
			ev.action = seq[f]
			ev.pressed = f == frame_i
			Input.parse_input_event(ev)
	frames -= 1
	if frames > 0 or _finishing:
		return
	_finishing = true
	if DisplayServer.get_name() != "headless":   # 헤드리스에서는 frame_post_draw 가 오지 않아 영원히 멈춘다
		await RenderingServer.frame_post_draw
	if perf: _perf_report()
	if not (perf and DisplayServer.get_name() == "headless"):
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
