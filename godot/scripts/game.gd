extends Node
## Global game state (autoload "Game"): story flags, purse and medicine, checkpoint, save/load,
## and level transitions behind a fade. Saves go to user://save.json.

signal toast(text: String, color: Color)

const SAVE_PATH := "user://save.json"
const SHOP := [
	{"id": "insam", "name": "인삼정기탕", "desc": "기력(체력) 60 회복", "price": 30},
	{"id": "gugija", "name": "구기자환", "desc": "소리(기력) 50 회복", "price": 25},
	{"id": "jeonghwa", "name": "정화부", "desc": "주변 요괴에게 큰 정화 피해", "price": 40},
]

var flags := {}
var money := 50
var items := {"insam": 2, "gugija": 1, "jeonghwa": 0}
var checkpoint := "village"
var level_id := "beach"
var spawn_name := "start"
var _fade: ColorRect
var _busy := false
var _card: VBoxContainer


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for a in OS.get_cmdline_user_args():  # test hooks: --level=gyeongju --spawn=home --flags=met_nanyeong,night
		if a.begins_with("--level="): level_id = a.get_slice("=", 1)
		elif a.begins_with("--spawn="): spawn_name = a.get_slice("=", 1)
		elif a.begins_with("--flags="):
			for f in a.get_slice("=", 1).split(","):
				flags[f] = 1
	var layer := CanvasLayer.new()
	layer.layer = 30
	_fade = ColorRect.new()
	_fade.color = Color(0.0, 0.0, 0.02, 0.0)
	_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_fade)
	_card = VBoxContainer.new()
	_card.set_anchors_preset(Control.PRESET_FULL_RECT)
	_card.alignment = BoxContainer.ALIGNMENT_CENTER
	_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card.modulate.a = 0.0
	for i in 2:
		var l := Label.new()
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.add_theme_font_override("font", DialogBox._pixel_font("res://assets/fonts/Galmuri11-Bold.ttf" if i == 0 else "res://assets/fonts/Galmuri11.ttf"))
		l.add_theme_font_size_override("font_size", 24 if i == 0 else 12)
		l.add_theme_color_override("font_color", Color(0.93, 0.88, 0.76) if i == 0 else Color(0.62, 0.7, 0.86))
		_card.add_child(l)
	layer.add_child(_card)
	add_child(layer)


func flag(k: String) -> int:
	return int(flags.get(k, 0))


func set_flag(k: String, v := 1) -> void:
	flags[k] = v


func say_toast(text: String, color := Color(0.94, 0.85, 0.55)) -> void:
	toast.emit(text, color)


# ---------------------------------------------------------------- fades and level changes
func fade(to: float, time := 0.4) -> void:
	var tw := create_tween()
	tw.tween_property(_fade, "color:a", to, time)
	await tw.finished


## a place / chapter card over black (call with the screen already faded out); awaitable
func card(title: String, sub := "", hold := 1.6) -> void:
	_card.get_child(0).text = title
	_card.get_child(1).text = sub
	var tw := create_tween()
	tw.tween_property(_card, "modulate:a", 1.0, 0.6)
	tw.tween_interval(hold)
	tw.tween_property(_card, "modulate:a", 0.0, 0.6)
	await tw.finished


func change_level(id: String, spawn: String, title := "", sub := "") -> void:
	if _busy:
		return
	_busy = true
	await fade(1.0, 0.35 if title == "" else 1.2)
	if title != "":
		await card(title, sub)
	level_id = id
	spawn_name = spawn
	get_tree().change_scene_to_file("res://scenes/level.tscn")
	await get_tree().process_frame
	await get_tree().process_frame
	await fade(0.0, 0.45)
	_busy = false


# ---------------------------------------------------------------- save / load
func save() -> void:
	var data := {"flags": flags, "money": money, "items": items, "checkpoint": checkpoint}
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(data))


func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)


func load_save() -> bool:
	if not has_save():
		return false
	var data = JSON.parse_string(FileAccess.get_file_as_string(SAVE_PATH))
	if typeof(data) != TYPE_DICTIONARY:
		return false
	flags = data.get("flags", {})
	money = int(data.get("money", 50))
	items = data.get("items", items)
	checkpoint = data.get("checkpoint", "village")
	return true


func new_game() -> void:
	flags = {}
	money = 50
	items = {"insam": 2, "gugija": 1, "jeonghwa": 0}
	checkpoint = "village"


## where a fresh start / continue / death puts you
func checkpoint_spawn() -> Array:
	return ["dungeon1", "entrance"] if checkpoint == "dungeon" else ["beach", "start"] if not flag("arrived") else ["gyeongju", "start"]
