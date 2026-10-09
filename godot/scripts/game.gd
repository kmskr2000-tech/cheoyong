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
var level_id := "gyeongju"
var spawn_name := "start"
var _fade: ColorRect
var _busy := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var layer := CanvasLayer.new()
	layer.layer = 30
	_fade = ColorRect.new()
	_fade.color = Color(0.0, 0.0, 0.02, 0.0)
	_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_fade)
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


func change_level(id: String, spawn: String) -> void:
	if _busy:
		return
	_busy = true
	await fade(1.0, 0.35)
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
	return ["dungeon1", "entrance"] if checkpoint == "dungeon" else ["gyeongju", "start"]
