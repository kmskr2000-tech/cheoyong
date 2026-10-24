# Audio: pre-synthesized gugak loops and effects (art/sound.py). Music crossfades, effects use a small pool.
extends Node

var music_a: AudioStreamPlayer
var music_b: AudioStreamPlayer
var amb: AudioStreamPlayer
var pool: Array[AudioStreamPlayer] = []
var current := ""
var amb_name := ""
var cache := {}
var last := {}
var off := false
var muted := false

func _ready() -> void:
	muted = G.has("mute")
	for n in ["Music", "SFX"]: _ensure_bus(n)
	music_a = _player("Music"); music_b = _player("Music"); amb = _player("SFX")
	for i in 10: pool.append(_player("SFX"))

func _player(bus := "Master") -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.bus = bus
	add_child(p)
	return p

# Music and SFX buses feed Master; the settings menu sets their volume (0-100) without touching the per-sound levels.
func _ensure_bus(name: String) -> void:
	if AudioServer.get_bus_index(name) >= 0: return
	AudioServer.add_bus()
	var i := AudioServer.bus_count - 1
	AudioServer.set_bus_name(i, name)
	AudioServer.set_bus_send(i, "Master")

func set_volume(bus: String, pct: int) -> void:
	var i := AudioServer.get_bus_index(bus)
	if i < 0: return
	AudioServer.set_bus_volume_db(i, -80.0 if pct <= 0 else linear_to_db(pct / 100.0))

func _stream(name: String, loop: bool) -> AudioStream:
	if cache.has(name): return cache[name]
	var s = load("res://audio/" + name + ".ogg")
	if s and loop: s.loop = true
	cache[name] = s
	return s

func unlock() -> void:
	pass  # web builds start audio on the first input event automatically

func music(name: String) -> void:
	if name == current or muted: return
	current = name
	var s := _stream("music_" + name, true)
	if not s: return
	var old := music_a
	music_a = music_b; music_b = old
	music_a.stream = s; music_a.volume_db = -40; music_a.play()
	var t := create_tween().set_parallel()
	t.tween_property(music_a, "volume_db", -6.0, 1.2)
	t.tween_property(music_b, "volume_db", -40.0, 1.0)
	t.chain().tween_callback(music_b.stop)

func ambient(name: String) -> void:
	if name == amb_name or muted: return
	amb_name = name
	if name == "": amb.stop(); return
	amb.stream = _stream("amb_" + name, true); amb.volume_db = -14; amb.play()

func sfx(name: String) -> void:
	if muted or off: return
	var now := Time.get_ticks_msec()
	if last.get(name, -1000) > now - 40: return
	last[name] = now
	var s := _stream(name, false)
	if not s: return
	for p in pool:
		if not p.playing:
			p.stream = s; p.volume_db = -3; p.play(); return

func toggle() -> void:
	off = not off
	AudioServer.set_bus_mute(0, off)
