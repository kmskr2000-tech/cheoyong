extends Node
## Headless-ish verification: `godot --path godot -- --capture=out.png [--frames=N] [--hold=move_right] [--at=x,y] [--seq=attack:5,roll:20]`
## holds an input action, waits N frames, saves the viewport and quits. Does nothing without --capture.

var out := ""
var frames := 60
var hold := ""
var at := ""
var seq := {} # frame -> action tapped on that frame
var frame_i := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS   # keep counting frames while the game is paused (행낭 menu)
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--capture="): out = a.get_slice("=", 1)
		elif a.begins_with("--frames="): frames = int(a.get_slice("=", 1))
		elif a.begins_with("--hold="): hold = a.get_slice("=", 1)
		elif a.begins_with("--at="): at = a.get_slice("=", 1)
		elif a.begins_with("--seq="):
			for item in a.get_slice("=", 1).split(","):
				seq[int(item.get_slice(":", 1))] = item.get_slice(":", 0)
	if out == "":
		set_process(false)
	else:
		Engine.max_fps = 60  # frame counts ≈ seconds × 60 regardless of how light the scene is
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


func _process(_delta: float) -> void:
	frame_i += 1
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
	get_viewport().get_texture().get_image().save_png(out)
	print("t=", Time.get_ticks_msec(), "ms  captured ", out, "  enemies left: ", get_tree().get_nodes_in_group("enemy").size(), "  downed: ", get_tree().get_nodes_in_group("downed").size(), "  level: ", Game.level_id, "  flags: ", Game.flags)
	var pl = get_tree().current_scene.get_node_or_null("Player")
	var bs = get_tree().current_scene.get_node_or_null("Boss")
	if pl: print("player ", pl.position, " ", pl.state, " hp ", pl.hp, " stun ", snappedf(pl.stun_t, 0.1), " slow ", snappedf(pl.slow_t, 0.1), " pull ", snappedf(pl.pull_t, 0.1))
	for e in get_tree().get_nodes_in_group("enemy") + get_tree().get_nodes_in_group("downed"):
		if e is Enemy:
			print("  ", e.kind, (" clone" if e.is_clone else ""), " ", e.position.round(), " ", e.state, " hp ", e.hp, " a ", snappedf(e.alpha, 0.01), " grow ", snappedf(e.grow, 0.01))
	var ap := 0
	for c in Audio.get_children():
		if c is AudioStreamPlayer and c.playing: ap += 1
	print("  audio track ", Audio._track, " amb ", Audio._amb.playing, " playing ", ap, " stream ", Audio._music[Audio._cur].stream)
	print("  growth items ", Game.items, " Lv.", Game.lv, " deok ", Game.deok, " jeonggi ", Game.jeonggi, " money ", Game.money, " dogam ", Game.dogam, " mats ", Game.mats, " tal ", Game.tal)
	var lv = get_tree().current_scene
	if lv.get("_dark") and lv._dark: print("  darkness ", snappedf(lv._dark.color.a, 0.01))
	print("  hazards/projectiles ", get_tree().current_scene.get_children().filter(func(n): return n is Hazard or n is Projectile or n is Shockwave).size())
	if bs: print("boss ", bs.position, " ", bs.state, " hp ", bs.hp)
	get_tree().quit()
