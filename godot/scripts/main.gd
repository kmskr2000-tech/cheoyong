# Main: state machine (title -> intro -> play -> ending), title/intro/ending overlays, test hooks.
# Test hooks (after "--" on the command line, or ?query on the web):
#   play, quest=n, at=x,y, flags=a,b, lvl=n, heung, enemies=imp,snake, boss=gumiho, ending, mute, god, auto, speed=n
#   capture=out.png frames=N  -> run N fixed frames, save a screenshot, print a status line, quit
#   keys=hold:right@0.3-1.4,interact@1.9  -> scripted input by game time (actions or up/down/left/right)
extends Node

var game
var overlay: Control
var st = {"t": 0.0}
var frame = 0
var keys = []

const INTRO := [
	{"cam": [61, 47], "text": ["신라 헌강왕 시절,", "서라벌에는 노래와 춤이 끊이지 않았다."]},
	{"cam": [98, 64], "text": ["어느 날 동해 개운포에 짙은 안개가 깔리고,", "바다에서 용왕과 일곱 아들이 나타났다."]},
	{"cam": [14, 10], "text": ["그러나 밤이 되면", "역신이 집집마다 스며들어 병을 퍼뜨렸다."]},
	{"cam": [96, 66], "text": ["역신을 물리칠 노래는", "여덟 구절로 흩어져 버렸다."]},
	{"cam": [96, 66], "text": ["노래가 완성되면 —"], "last": true},
]
const ENDING := [
	{"text": ["그날 이후 서라벌 사람들은", "문에 처용의 얼굴을 그려 붙였다."]},
	{"text": ["역신은 맹세를 지켜", "그 문으로는 다시 들지 않았다."]},
	{"text": ["서라벌 밝은 달에", "밤 늦도록 노닐다가 —"]},
	{"text": ["신 처용가", "끝"], "last": true},
]

func _ready() -> void:
	game = Node.new()
	game.set_script(load("res://scripts/game.gd"))
	game.name = "Game"
	add_child(game)
	var oc = CanvasLayer.new(); oc.layer = 20
	add_child(oc)
	overlay = Control.new()
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.draw.connect(_draw_overlay)
	oc.add_child(overlay)
	if G.has("auto"):
		var a = Node.new(); a.set_script(load("res://scripts/autopilot.gd")); add_child(a)
	_parse_keys()
	get_viewport().size_changed.connect(_resize)
	_resize()
	game.new_game()
	if G.has("play") or G.has("quest") or G.has("at"):
		game.apply_debug()
		set_state("play")
		if G.param("enemies") != "":
			for k in G.param("enemies").split(","):
				game.spawn_enemy(k, game.player.x + 140 + randf() * 60, game.player.y + (randf() - 0.5) * 100, {"level": 1})
		if G.param("boss") != "":
			var b = game.spawn_boss(G.param("boss"), game.player.x + 220, game.player.y, null)
			game.start_boss_fight(b, game.player.x + 110, game.player.y)
	elif G.has("ending"): set_state("ending")
	else: set_state("title")

# UI layer: about CSS-pixel sized on phones (readable text, thumb-sized buttons), scaled up on big screens
func _resize() -> void:
	var vs = get_viewport().get_visible_rect().size
	var win = Vector2(DisplayServer.window_get_size())
	var dpi_scale = 1.0
	if OS.has_feature("web"): dpi_scale = float(JavaScriptBridge.eval("window.devicePixelRatio || 1", true))
	elif OS.has_feature("mobile"): dpi_scale = max(1.0, DisplayServer.screen_get_dpi() / 160.0)
	var css_h = win.y / dpi_scale
	var ui_h = clampf(css_h, 380, 600)
	var s = vs.y / ui_h
	Inp.ui_scale = s
	var ul: CanvasLayer = game.ui.get_parent()
	ul.scale = Vector2(s, s)
	game.ui.vw = vs.x / s; game.ui.vh = vs.y / s
	game.ui.size = Vector2(game.ui.vw, game.ui.vh)
	overlay.size = vs

func set_state(s: String) -> void:
	G.state = s
	st = {"t": 0.0, "st": 0.0, "sel": 0, "shot": 0, "cool": 0.0, "rects": []}
	match s:
		"title":
			Sfx.music("title")
			game.new_game()
			game.cam = Vector2(84 * 32, 58 * 32)
			st.has_save = game.has_save()
		"intro": Sfx.music("title")
		"ending": Sfx.music("song")

func _parse_keys() -> void:
	for k in G.param("keys").split(",", false):
		var hold = k.begins_with("hold:")
		var body = k.trim_prefix("hold:")
		var a = body.split("@")
		var tr = a[1].split("-")
		keys.append({"a": a[0], "t0": float(tr[0]), "t1": float(tr[1]) if tr.size() > 1 else -1.0, "hold": hold, "done": false})

func _scripted_input(t: float) -> void:
	var dirs = {"right": Vector2(1, 0), "left": Vector2(-1, 0), "up": Vector2(0, -1), "down": Vector2(0, 1)}
	var mv = Vector2.ZERO
	var down = {}
	for k in keys:
		if k.hold:
			if t >= k.t0 and t < k.t1:
				if dirs.has(k.a): mv += dirs[k.a]
				else: down[k.a] = true
		elif not k.done and t >= k.t0:
			k.done = true; Inp.press(k.a)
			if k.a in ["interact", "attack"]: Inp.press("confirm")
	if keys.size() > 0 and Inp.bot == null or (Inp.bot != null and not G.has("auto")):
		Inp.bot = {"x": mv.x, "y": mv.y, "down": down}

func _process(delta: float) -> void:
	var dt: float = 1.0 / 60.0 if G.has("capture") else min(delta, 0.05)
	frame += 1
	var speed = int(G.param("speed", "1"))
	for i in speed:
		var t: float = frame / 60.0
		if keys.size() > 0: _scripted_input(t)
		_step(dt if i == speed - 1 else min(dt, 1.0 / 30.0))
		if i < speed - 1: Inp.end_frame()
	overlay.queue_redraw()
	game.ui.queue_redraw()
	Inp.end_frame()
	if G.has("capture") and frame >= int(G.param("frames", "60")): _capture()
	if G.has("auto") and frame % 600 == 0: _report()

# playthrough progress for tests/playthrough_godot.sh
func _report() -> void:
	var f: Dictionary = game.flags
	var keys := ["q1", "q2", "king_met", "q3", "boss_dok", "boss_fox", "boss_imugi", "dosa_done", "q4", "yeoksin_done"]
	var done := keys.filter(func(k): return f.get(k, false))
	print("PROGRESS t=%d state=%s stage=%s zone=%s lvl=%d hp=%d kills=%d verses=%d boss=%s" % [game.time, G.state, ",".join(done),
		game.zone.id if game.zone else "-", game.player.lvl, game.player.hp, int(f.get("kills_total", 0)), game.verse_count(),
		("%s:%d" % [game.boss.type, game.boss.hp]) if game.boss is Object else "-"])
	if G.state == "ending":
		print("REACHED ENDING game_time=%d" % game.time); get_tree().quit()
	if frame > int(G.param("maxframes", "200000")): print("TIMEOUT"); get_tree().quit()

func _step(dt: float) -> void:
	if has_node("Autopilot"): get_node("Autopilot").tick(dt)
	st.t += dt
	match G.state:
		"title": _title(dt)
		"intro": _intro(dt)
		"play": game.tick(dt)
		"ending": _ending(dt)

func _title(dt: float) -> void:
	game.time += dt; game.fx.update(dt)
	game.cam = Vector2(84 * 32 + sin(st.t * 0.05) * 200, 58 * 32 + cos(st.t * 0.04) * 80)
	game.clamp_cam()
	var opts = ["이어하기", "새로 시작"] if st.has_save else ["시작하기"]
	st.opts = opts
	st.cool -= dt
	var mv = Inp.move()
	if abs(mv.y) > 0.5 and st.cool <= 0: st.sel = (st.sel + 1) % opts.size(); st.cool = 0.25; Sfx.sfx("ui")
	var choose = null
	if Inp.hit("tap"):
		for r in st.rects:
			var p = Inp.tap_pos
			if p and Rect2(r.x, r.y, r.w, r.h).has_point(p / 1.0 * Inp.ui_scale / Inp.ui_scale): choose = r.i
	if choose == null and st.t > 0.4 and (Inp.hit("confirm") or Inp.hit("interact") or Inp.hit("attack")): choose = st.sel
	if choose != null:
		Sfx.sfx("verse")
		if opts[choose] == "이어하기": game.load_game(); set_state("play")
		elif G.has("skipintro"): game.new_game(); set_state("play")
		else: set_state("intro")

func _intro(dt: float) -> void:
	st.st += dt
	game.time += dt; game.fx.update(dt)
	var shot: Dictionary = INTRO[st.shot]
	var vs = get_viewport().get_visible_rect().size
	game.cam = Vector2(shot.cam[0] * 32 - vs.x / 2 + st.st * 14, shot.cam[1] * 32 - vs.y / 2)
	game.clamp_cam()
	var dur = 4.0 if shot.get("last", false) else 5.2
	if st.st > dur or (st.st > 0.6 and (Inp.hit("confirm") or Inp.hit("tap"))):
		st.shot += 1; st.st = 0.0
		if st.shot >= INTRO.size(): game.new_game(); set_state("play"); Sfx.music("sea")

func _ending(dt: float) -> void:
	st.st += dt
	game.fx.update(dt)
	game.cam.y = max(0.0, game.cam.y - 0.15)
	var shot: Dictionary = ENDING[st.shot]
	var last: bool = shot.get("last", false)
	if not last and (st.st > 5.5 or (st.st > 0.8 and (Inp.hit("confirm") or Inp.hit("tap")))): st.shot += 1; st.st = 0.0
	if last and st.st > 3 and (Inp.hit("confirm") or Inp.hit("tap")): set_state("title")

# ---------- overlay drawing (screen coordinates) ----------
func _text(s: String, x: float, y: float, size: int, col: Color, font: Font = null, outline := 0) -> void:
	var f: Font = font if font else Assets.font_bold
	var w = f.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	if outline > 0: overlay.draw_string_outline(f, Vector2(x - w / 2, y), s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, outline, Color(0, 0, 0, col.a * 0.9))
	overlay.draw_string(f, Vector2(x - w / 2, y), s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, col)

func _caption(lines: Array, t: float, big: bool) -> void:
	var vs = overlay.size
	var a: float = min(1.0, t * 1.2)
	for i in lines.size():
		var y = vs.y * (0.48 if big else 0.74) + i * (52 if big else 36)
		_text(lines[i], vs.x / 2, y, 40 if big else 24, Color(0.97, 0.93, 0.82, a) if big else Color(0.91, 0.86, 0.75, a), Assets.font_black if big else Assets.font, 4)

func _draw_overlay() -> void:
	var vs = overlay.size
	match G.state:
		"title":
			var a: float = min(1.0, st.t * 0.8)
			overlay.draw_rect(Rect2(Vector2.ZERO, vs), Color(0.016, 0.024, 0.07, 0.4 * a))
			_text("신 처용가", vs.x / 2, vs.y * 0.36 + 4, 84, Color(0.47, 0.78, 1, 0.25 * a), Assets.font_black)
			_text("신 처용가", vs.x / 2, vs.y * 0.36, 84, Color(0.96, 0.91, 0.8, a), Assets.font_black, 6)
			_text("— 탈과 노래 —", vs.x / 2, vs.y * 0.36 + 44, 20, Color(0.84, 0.7, 0.43, a), Assets.font_bold, 3)
			st.rects = []
			var opts: Array = st.get("opts", [])
			for i in opts.size():
				var y = vs.y * 0.6 + i * 50; var w = 220.0; var x = vs.x / 2 - w / 2
				st.rects.append({"x": x / Inp.ui_scale, "y": (y - 28) / Inp.ui_scale, "w": w / Inp.ui_scale, "h": 42 / Inp.ui_scale, "i": i})
				overlay.draw_rect(Rect2(x, y - 28, w, 42), Color(0.84, 0.7, 0.43, 0.28) if st.sel == i else Color(0.04, 0.05, 0.11, 0.55))
				overlay.draw_rect(Rect2(x, y - 28, w, 42), Color("#ffd27a") if st.sel == i else Color(0.84, 0.7, 0.43, 0.5), false, 1.5)
				_text(opts[i], vs.x / 2, y, 20, Color("#ffe2a0") if st.sel == i else Color("#d8ccb0"), Assets.font_black)
			_text("가로 화면 · 왼쪽 엄지로 이동, 오른쪽 버튼으로 춤 · PC: WASD / J K U I O L E", vs.x / 2, vs.y - 24, 12, Color(0.86, 0.82, 0.75, 0.6 * a), Assets.font)
		"intro":
			var shot: Dictionary = INTRO[min(st.shot, INTRO.size() - 1)]
			var last: bool = shot.get("last", false)
			var dur = 4.0 if last else 5.2
			var fade: float = min(1.0, min(st.st * 1.5, (dur - st.st) * 1.5))
			overlay.draw_rect(Rect2(Vector2.ZERO, vs), Color(0, 0, 0, 0.85 if last else 0.35 + (1 - fade) * 0.65))
			overlay.draw_rect(Rect2(0, 0, vs.x, 56), Color.BLACK); overlay.draw_rect(Rect2(0, vs.y - 56, vs.x, 56), Color.BLACK)
			_caption(shot.text, max(0.0, st.st - 0.3), last)
		"ending":
			overlay.draw_rect(Rect2(Vector2.ZERO, vs), Color(0, 0, 0, 0.6))
			var shot: Dictionary = ENDING[st.shot]
			_caption(shot.text, max(0.0, st.st - 0.3), shot.get("last", false))
			if shot.get("last", false):
				_text("그림: PixelLab 생성 · 소리: 합성 국악 · 엔진: Godot", vs.x / 2, vs.y - 40, 13, Color(0.86, 0.82, 0.75, 0.7), Assets.font)
				_text("처용 Lv.%d · 정화한 요괴 %d" % [game.player.lvl, int(game.flags.get("kills_total", 0))], vs.x / 2, vs.y - 20, 13, Color(0.86, 0.82, 0.75, 0.7), Assets.font)

func _capture() -> void:
	var img = get_viewport().get_texture().get_image()
	img.save_png(G.param("capture"))
	var p = game.player
	var alive = 0; var kneel = 0
	for e in game.enemies:
		if e.state == "kneel": kneel += 1
		elif not e.dead: alive += 1
	var fl = []
	for k in game.flags:
		if game.flags[k] and not str(k).begins_with("tut_"): fl.append(k)
	print("RESULT state=%s zone=%s enemies=%d kneeling=%d hp=%d lvl=%d coins=%d pos=%.1f,%.1f boss=%s dialog=%s flags=%s" % [
		G.state, game.zone.id if game.zone else "-", alive, kneel, p.hp, p.lvl, p.coins, p.x / 32, p.y / 32,
		("%s:%d" % [game.boss.type, game.boss.hp]) if game.boss is Object else "-",
		game.ui.dialog.lines[game.ui.dialog.i][1] if game.ui.dialog else "-", ",".join(fl)])
	get_tree().quit()
