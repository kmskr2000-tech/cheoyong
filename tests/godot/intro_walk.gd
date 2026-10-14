extends SceneTree
## 인트로 용궁 컷 처용 걷기 모션 검증 (프로그래밍팀-인트로보정).
##   [xvfb-run] godot --path src -s ../tests/godot/intro_walk.gd -- [--shots=<dir>]
## 대사를 confirm 으로 넘기며 intro.tscn 을 재생하고, 처용(AnimatedSprite2D)이 이동 구간에서 up_walk 로
## 프레임이 바뀌고, 멈추면 up_idle 로 돌아오는지 확인한다. 성공: "INTRO_WALK PASS".
var shots := ""
var walk_frames := {}
var walk_samples := 0
var idle_after := false
var moved := false
var frame := 0
var me: AnimatedSprite2D
var y0 := 0.0
var shot_n := 0
var fail := ""

func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shots="): shots = a.get_slice("=", 1)
	root.get_node("Game").set_setting("intro_seen", false)
	var sc: Node = load("res://scenes/intro.tscn").instantiate()
	root.add_child(sc)
	current_scene = sc

func _tap() -> void:
	for p in [true, false]:
		var ev := InputEventAction.new()
		ev.action = "confirm"
		ev.pressed = p
		Input.parse_input_event(ev)

func _find(n: Node) -> AnimatedSprite2D:
	for c in n.get_children():
		if c is AnimatedSprite2D and c.sprite_frames and c.sprite_frames.has_animation("up_walk"):
			return c
		var r := _find(c)
		if r: return r
	return null

func _process(_d: float) -> bool:
	frame += 1
	var sc := current_scene
	if sc == null or not is_instance_valid(sc) or sc.name == "":
		return false
	if me == null or not is_instance_valid(me):
		me = _find(sc)
		if me: y0 = me.position.y
		if frame % 6 == 0: _tap()
		return _timeout()
	if frame % 6 == 0: _tap()
	if me.animation == "up_walk" and me.position.y < y0 - 1.0 and me.position.y > 177.0:
		moved = true
		walk_samples += 1
		walk_frames[me.frame] = true
		if shots != "" and walk_samples % 12 == 1 and shot_n < 3:
			var img := root.get_viewport().get_texture().get_image()
			img.save_png("%s/walk_%d.png" % [shots, shot_n]); shot_n += 1
	if moved and me.position.y <= 176.01 and me.animation == "up_idle":
		idle_after = true
	if idle_after or moved and me.position.y <= 176.01 and frame > 0 and me.animation != "up_walk":
		return _done()
	return _timeout()

func _timeout() -> bool:
	if frame > 3000:
		fail = "timeout (moved=%s)" % moved
		return _done()
	return false

func _done() -> bool:
	if fail == "":
		if not moved: fail = "이동 구간을 못 봤다"
		elif walk_frames.size() < 3: fail = "걷기 프레임이 %d 종뿐" % walk_frames.size()
		elif not idle_after: fail = "도착 후 up_idle 로 안 돌아옴"
	if fail == "":
		print("INTRO_WALK PASS frames=%s samples=%d" % [walk_frames.keys(), walk_samples])
		quit(0)
	else:
		print("FAIL: ", fail)
		quit(1)
	return true
