extends Node
## Headless-ish verification: `godot --path godot -- --capture=out.png [--frames=N] [--hold=move_right]`
## holds an input action, waits N frames, saves the viewport and quits. Does nothing without --capture.

var out := ""
var frames := 60
var hold := ""


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--capture="): out = a.get_slice("=", 1)
		elif a.begins_with("--frames="): frames = int(a.get_slice("=", 1))
		elif a.begins_with("--hold="): hold = a.get_slice("=", 1)
	if out == "":
		set_process(false)
	elif hold != "":
		Input.action_press(hold)


func _process(_delta: float) -> void:
	frames -= 1
	if frames > 0:
		return
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out)
	print("captured ", out)
	get_tree().quit()
