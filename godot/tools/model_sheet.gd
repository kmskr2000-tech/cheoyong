# Contact sheet of a 3D model: top row the 5 facing directions (idle), bottom row each clip mid-way.
# xvfb-run -a godot --rendering-driver opengl3 --path godot res://tools/model_sheet.tscn -- --model=cheoyong --out=/tmp/sheet.png
extends Node3D

class FakeView:
	func to3(px, py, z := 0.0): return Vector3(px / 32.0, z / 32.0, py / 32.0)

var models: Models
var frame := 0
var name_m := "cheoyong"
var out := "/tmp/model_sheet.png"
var size := 5.0

func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--model="): name_m = a.substr(8)
		if a.begins_with("--out="): out = a.substr(6)
		if a.begins_with("--size="): size = float(a.substr(7))
	var cam := Camera3D.new(); cam.projection = Camera3D.PROJECTION_ORTHOGONAL; cam.size = size
	cam.rotation = Vector3(-deg_to_rad(55), 0, 0)
	cam.position = Vector3(2.0 * size / 5.0, 0.9, 0.6 * size / 5.0) + Vector3(0, sin(deg_to_rad(55)), cos(deg_to_rad(55))) * 20
	add_child(cam); cam.make_current()
	var sun := DirectionalLight3D.new(); sun.rotation = Vector3(deg_to_rad(-50), deg_to_rad(-80), 0)
	sun.light_color = Color(1.0, 0.92, 0.8); sun.light_energy = 1.25; sun.shadow_enabled = true; add_child(sun)
	var env := Environment.new(); env.background_mode = Environment.BG_COLOR; env.background_color = Color(0.75, 0.62, 0.45)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR; env.ambient_light_color = Color(0.62, 0.64, 0.8); env.ambient_light_energy = 0.45
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	var we := WorldEnvironment.new(); we.environment = env; add_child(we)
	RenderingServer.global_shader_parameter_set("sprite_tint", Color(1, 1, 1))
	models = Models.new(self)
	Models.has(name_m)

func _process(_d: float) -> void:
	frame += 1
	models.begin_frame()
	var v := FakeView.new()
	var dirs := ["south", "south-east", "east", "north-east", "north"]
	for i in 5:
		models.draw(v, name_m, "idle", dirs[i], 0.3, i * 26.0, -10.0, 60.0, {})
	var clips: Array = Models.defs[name_m].clips.keys()
	for i in min(5, clips.size()):
		var c: Dictionary = Models.defs[name_m].clips[clips[i]]
		models.draw(v, name_m, clips[i], "south" if i % 2 == 0 else "south-east", c.len * 0.5 / max(0.01, c.len) * c.n / c.fps, i * 26.0, 60.0, 60.0, {"fps": c.fps})
	models.end_frame()
	if frame == 10:
		get_viewport().get_texture().get_image().save_png(out)
		get_tree().quit()
