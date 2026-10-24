# Settings: player options kept in user://settings.cfg (ConfigFile), loaded on boot, saved shortly after a change.
# Volumes 0-100 go to the Master/Music/SFX buses (Sfx.set_volume). Screen shake and text speed are published on G
# (G.shake_scale, G.text_speed). Fullscreen only exists on desktop; the window starts 1600x900 (see project.godot).
extends Node

const PATH := "user://settings.cfg"
const TEXT_MODES := ["보통", "빠름", "즉시"]
const TEXT_SPEEDS := [1.0, 2.5, 100.0]

var master := 100
var music := 100
var sfx := 100
var fullscreen := false
var shake := true
var text_mode := 0

var _dirty := 0.0   # seconds until the pending change is written (0 = nothing pending)

func is_desktop() -> bool:
	return OS.has_feature("pc")

func _ready() -> void:
	_load()
	apply_all()
	if is_desktop() and DisplayServer.get_name() != "headless": _fit_window.call_deferred()

func _load() -> void:
	var c := ConfigFile.new()
	if c.load(PATH) != OK: return
	master = clampi(int(c.get_value("audio", "master", master)), 0, 100)
	music = clampi(int(c.get_value("audio", "music", music)), 0, 100)
	sfx = clampi(int(c.get_value("audio", "sfx", sfx)), 0, 100)
	fullscreen = bool(c.get_value("display", "fullscreen", fullscreen))
	shake = bool(c.get_value("game", "shake", shake))
	text_mode = clampi(int(c.get_value("game", "text_mode", text_mode)), 0, TEXT_MODES.size() - 1)

func save() -> void:
	_dirty = 0.0
	var c := ConfigFile.new()
	c.set_value("audio", "master", master)
	c.set_value("audio", "music", music)
	c.set_value("audio", "sfx", sfx)
	c.set_value("display", "fullscreen", fullscreen)
	c.set_value("game", "shake", shake)
	c.set_value("game", "text_mode", text_mode)
	c.save(PATH)

func apply_all() -> void:
	Sfx.set_volume("Master", master)
	Sfx.set_volume("Music", music)
	Sfx.set_volume("SFX", sfx)
	G.shake_scale = 1.0 if shake else 0.0
	G.text_speed = TEXT_SPEEDS[text_mode]
	_apply_fullscreen()

# one entry point for the menu: key is master|music|sfx|fullscreen|shake|text_mode
func set_value(key: String, v) -> void:
	match key:
		"master": master = clampi(int(v), 0, 100)
		"music": music = clampi(int(v), 0, 100)
		"sfx": sfx = clampi(int(v), 0, 100)
		"fullscreen": fullscreen = bool(v)
		"shake": shake = bool(v)
		"text_mode": text_mode = posmod(int(v), TEXT_MODES.size())
		_: return
	apply_all()
	_dirty = 0.6

func get_value(key: String):
	match key:
		"master": return master
		"music": return music
		"sfx": return sfx
		"fullscreen": return fullscreen
		"shake": return shake
		"text_mode": return text_mode
	return null

func toggle_fullscreen() -> void:
	if is_desktop(): set_value("fullscreen", not fullscreen)

func _apply_fullscreen() -> void:
	if not is_desktop() or DisplayServer.get_name() == "headless": return
	var want := DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen else DisplayServer.WINDOW_MODE_WINDOWED
	if DisplayServer.window_get_mode() != want: DisplayServer.window_set_mode(want)

# a 1600x900 window does not fit small laptop screens: shrink to the usable area and centre it
func _fit_window() -> void:
	if fullscreen or DisplayServer.window_get_mode() != DisplayServer.WINDOW_MODE_WINDOWED: return
	var scr := DisplayServer.window_get_current_screen()
	var area := DisplayServer.screen_get_usable_rect(scr)
	var win := DisplayServer.window_get_size()
	var fit := Vector2i(mini(win.x, int(area.size.x * 0.94)), mini(win.y, int(area.size.y * 0.94)))
	if fit != win:
		DisplayServer.window_set_size(fit)
		win = fit
	DisplayServer.window_set_position(area.position + (area.size - win) / 2)

func _process(dt: float) -> void:
	if _dirty > 0.0:
		_dirty -= dt
		if _dirty <= 0.0: save()

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST and _dirty > 0.0: save()

func _exit_tree() -> void:
	if _dirty > 0.0: save()
