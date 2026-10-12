extends Node
## 소리 (autoload "Audio"): crossfading music, an ambience bed, and a pool of one-shot effects.
## All sounds are synthesised by art/sound.py. Levels pick their music/ambience; combat swaps in the
## 자진모리 battle track while 요괴 are hunting the hero, and the boss track overrides both.

const MUSIC_DB := -9.0
const AMB_DB := -14.0
var _music: Array[AudioStreamPlayer] = []
var _cur := 0
var _track := ""          # what's playing now
var _base := ""           # the level's own music
var _override := ""       # boss / cutscene
var _combat := false
var _amb: AudioStreamPlayer
var _pool: Array[AudioStreamPlayer] = []
var _cache := {}
var _tw: Tween


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i in 2:
		var p := AudioStreamPlayer.new()
		p.volume_db = -80.0
		add_child(p)
		_music.append(p)
	_amb = AudioStreamPlayer.new()
	_amb.volume_db = AMB_DB
	add_child(_amb)
	for i in 12:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_pool.append(p)


func _load(path: String, loop: bool) -> AudioStream:
	if _cache.has(path):
		return _cache[path]
	if not ResourceLoader.exists(path):
		return null
	var s: AudioStream = load(path)
	if loop and s is AudioStreamWAV:
		s.loop_mode = AudioStreamWAV.LOOP_FORWARD
		s.loop_begin = 0
		s.loop_end = int(s.get_length() * s.mix_rate)
	_cache[path] = s
	return s


# ---------------------------------------------------------------- music
## the level's own track ("" = silence)
func music(name: String) -> void:
	_base = name
	_override = ""
	_combat = false
	_refresh()


## boss fights and set-pieces take over until cleared ("")
func override(name: String) -> void:
	_override = name
	_refresh()


func combat(on: bool) -> void:
	if on == _combat:
		return
	_combat = on
	_refresh()


func _refresh(fade := 1.2) -> void:
	var want := _override if _override != "" else ("battle" if _combat and _base in ["night", "dread"] else _base)
	if want == _track:
		return
	_track = want
	var old := _music[_cur]
	_cur = 1 - _cur
	var nxt := _music[_cur]
	if _tw:
		_tw.kill()   # a crossfade still running must not stop the track we are switching to
	var tw := create_tween().set_parallel()
	_tw = tw
	tw.tween_property(old, "volume_db", -80.0, fade)
	if want != "":
		nxt.stream = _load("res://assets/audio/music_%s.wav" % want, true)
		nxt.volume_db = -40.0
		nxt.play()
		tw.tween_property(nxt, "volume_db", MUSIC_DB, fade)
	tw.chain().tween_callback(func():
		if _music[_cur] != old:
			old.stop())


func ambience(name: String) -> void:
	if name == "":
		_amb.stop()
		return
	var s := _load("res://assets/audio/amb_%s.wav" % name, true)
	if _amb.stream != s or not _amb.playing:
		_amb.stream = s
		_amb.play()


# ---------------------------------------------------------------- effects
func sfx(name: String, db := 0.0, pitch_jitter := 0.06) -> void:
	var s := _load("res://assets/audio/sfx_%s.wav" % name, false)
	if s == null:
		return
	for p in _pool:
		if not p.playing:
			p.stream = s
			p.volume_db = db
			p.pitch_scale = 1.0 + randf_range(-pitch_jitter, pitch_jitter)
			p.play()
			return
