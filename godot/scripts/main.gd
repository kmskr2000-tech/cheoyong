# Main: state machine (title -> intro -> play -> ending), title/intro/ending overlays, test hooks.
# Test hooks (after "--" on the command line, or ?query on the web):
#   play, quest=n, at=x,y, flags=a,b, lvl=n, heung, enemies=imp,snake, boss=gumiho, ending, intro, card=n, verse=n, hyangga=key, say=text, who=name, mute, god, auto, speed=n
#   capture=out.png frames=N  -> run N fixed frames, save a screenshot, print a status line, quit
#   keys=hold:right@0.3-1.4,interact@1.9  -> scripted input by game time (actions or up/down/left/right)
extends Node

var game
var overlay: Control
var st = {"t": 0.0}
var frame = 0
var keys = []
var fade_a := 1.0      # black veil over everything (1 = black); title, intro, ending and the start of a game fade through it
var fade_dir := -1     # +1 closing, -1 lifting, 0 idle
var fade_dur := 1.0
var fade_back := 0.8
var fade_fn = null

const INTRO := [
	{"cam": [61, 47], "text": ["신라 헌강왕 시절,", "서라벌에는 노래와 춤이 끊이지 않았다."]},
	{"cam": [98, 64], "text": ["어느 날 동해 개운포에 짙은 안개가 깔리고,", "바다에서 용왕과 일곱 아들이 나타났다."]},
	{"cam": [14, 10], "text": ["그러나 밤이 되면", "역신이 집집마다 스며들어 병을 퍼뜨렸다."]},
	{"cam": [96, 66], "text": ["역신을 물리칠 노래는", "여덟 구절로 흩어져 버렸다."]},
	{"cam": [96, 66], "text": ["노래가 완성되면 —"], "last": true},
]
const INTRO_DUR := 6.6   # seconds per intro shot (slow and solemn)
const INTRO_LAST := 4.8
const ENDING_DUR := 6.6
const ENDING := [
	{"text": ["그날 이후 서라벌 사람들은", "문에 처용의 얼굴을 그려 붙였다."]},
	{"text": ["역신은 맹세를 지켜", "그 문으로는 다시 들지 않았다."]},
	{"text": ["서라벌 밝은 달에", "밤 늦도록 노닐다가 —"]},
	{"text": ["신 처용가", "끝"], "last": true},
]

func _ready() -> void:
	Typo.setup()
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
	if G.has("play") or G.has("quest") or G.has("at") or G.has("chapter") or G.has("card"):
		game.apply_debug()
		set_state("play")
		fade_a = 0.0; fade_dir = 0
		if G.param("enemies") != "":
			for k in G.param("enemies").split(","):
				game.spawn_enemy(k, game.player.x + 140 + randf() * 60, game.player.y + (randf() - 0.5) * 100, {"level": 1})
		if G.has("card"):   # card=n: show chapter n's title card
			var cn := int(G.param("card", "1"))
			game.ui.start_card(Story.CARD1 if cn <= 1 else game.story.chapters[Maps.ORDER[cn - 1]].card())
		if G.has("verse"): game.ui.say([["@verse", int(G.param("verse", "1"))]])    # verse=n: the verse banner
		if G.has("hyangga"): game.ui.say([["@hyangga", G.param("hyangga", "chan")]])  # hyangga=key: the hyangga banner
		if G.has("say"): game.ui.say([[G.param("who", "할미"), G.param("say").uri_decode()]])   # say=text who=name: one dialogue line
		if G.param("boss") != "":
			var b = game.spawn_boss(G.param("boss"), game.player.x + 220, game.player.y, null)
			game.start_boss_fight(b, game.player.x + 110, game.player.y)
	elif G.has("ending"): set_state("ending")
	elif G.has("intro"): set_state("intro")
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
	if s != "play":
		fade_a = 1.0; fade_dir = -1; fade_dur = 0.25 if G.has("auto") else 1.2   # out of the dark
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
	_fade_step(dt)
	match G.state:
		"title": _title(dt)
		"intro": _intro(dt)
		"play": game.tick(dt)
		"ending": _ending(dt)

func _title(dt: float) -> void:
	game.time += dt; game.fx.update(dt)
	game.cam = Vector2(84 * 32 + 90 + sin(st.t * 0.05) * 200, 58 * 32 - 250 + cos(st.t * 0.04) * 80)
	game.clamp_cam()
	var opts = ["이어하기", "새로 시작"] if st.has_save else ["시작하기"]
	st.opts = opts
	st.cool -= dt
	if fade_dir > 0: return
	var auto: bool = G.has("auto")
	var ready_t := 0.4 if auto else 2.6   # the options appear once the logo has settled; a first press shows them at once
	var pressed: bool = Inp.hit("confirm") or Inp.hit("interact") or Inp.hit("attack")
	if st.t < ready_t:
		if pressed and st.t > 0.3: st.t = ready_t
		if not auto: return
	var mv = Inp.move()
	if abs(mv.y) > 0.5 and st.cool <= 0: st.sel = (st.sel + 1) % opts.size(); st.cool = 0.25; Sfx.sfx("ui")
	var choose = null
	if Inp.hit("tap"):
		for r in st.rects:
			var p = Inp.tap_pos
			if p and Rect2(r.x, r.y, r.w, r.h).has_point(p / 1.0 * Inp.ui_scale / Inp.ui_scale): choose = r.i
	if choose == null and st.t > 0.4 and pressed: choose = st.sel
	if choose != null:
		Sfx.sfx("verse")
		var k := 0.2 if auto else 1.0
		if opts[choose] == "이어하기": _fade_to(func(): game.load_game(); set_state("play"), 0.7 * k, 0.8 * k)
		elif G.has("skipintro"): _fade_to(func(): game.new_game(); set_state("play"); game.ui.start_card(Story.CARD1), 0.7 * k, 0.3 * k)
		else: _fade_to(func(): set_state("intro"), 0.9 * k, 1.0 * k)

func _intro(dt: float) -> void:
	st.st += dt
	game.time += dt; game.fx.update(dt)
	var shot: Dictionary = INTRO[st.shot]
	var vs = get_viewport().get_visible_rect().size
	game.cam = Vector2(shot.cam[0] * 32 - vs.x / 2 + st.st * 14, shot.cam[1] * 32 - vs.y / 2)
	game.clamp_cam()
	if st.get("leaving", false): return
	var dur = INTRO_LAST if shot.get("last", false) else INTRO_DUR
	if st.st > dur or (st.st > 0.8 and (Inp.hit("confirm") or Inp.hit("tap"))):
		st.shot += 1; st.st = 0.0
		if st.shot >= INTRO.size():
			st.shot = INTRO.size() - 1; st.st = dur; st.leaving = true
			_fade_to(func(): game.new_game(); set_state("play"); Sfx.music("sea"); game.ui.start_card(Story.CARD1), 1.0, 0.3)

func _ending(dt: float) -> void:
	st.st += dt
	game.fx.update(dt)
	game.cam.y = max(0.0, game.cam.y - 0.15)
	if st.get("leaving", false): return
	var shot: Dictionary = ENDING[st.shot]
	var last: bool = shot.get("last", false)
	if not last and (st.st > ENDING_DUR or (st.st > 1.0 and (Inp.hit("confirm") or Inp.hit("tap")))): st.shot += 1; st.st = 0.0
	if last and st.st > 4 and (Inp.hit("confirm") or Inp.hit("tap")):
		st.leaving = true
		_fade_to(func(): set_state("title"), 1.4, 1.4)

# ---------- fade through black (over everything) ----------
func _fade_to(fn: Callable, out := 0.7, back := 0.8) -> void:
	fade_fn = fn; fade_dir = 1; fade_dur = maxf(out, 0.01); fade_back = back

func _fade_step(dt: float) -> void:
	if fade_dir == 0: return
	fade_a = clampf(fade_a + fade_dir * dt / fade_dur, 0.0, 1.0)
	if fade_dir > 0 and fade_a >= 1.0:
		var fn = fade_fn
		fade_fn = null
		if fn is Callable and fn.is_valid(): fn.call()
		fade_dir = -1; fade_dur = maxf(fade_back, 0.01)
	elif fade_dir < 0 and fade_a <= 0.0:
		fade_dir = 0

# ---------- overlay drawing (screen coordinates) ----------
const GOLD := Color(0.84, 0.69, 0.42)
const PAPER := Color(0.95, 0.91, 0.81)

func _vignette(a: float) -> void:
	var vs = overlay.size
	var z := Color(0, 0, 0, 0.0); var d := Color(0.0, 0.0, 0.01, a)
	var th = vs.y * 0.34; var sw = vs.x * 0.2
	overlay.draw_polygon(PackedVector2Array([Vector2(0, 0), Vector2(vs.x, 0), Vector2(vs.x, th), Vector2(0, th)]), PackedColorArray([d, d, z, z]))
	overlay.draw_polygon(PackedVector2Array([Vector2(0, vs.y - th), Vector2(vs.x, vs.y - th), Vector2(vs.x, vs.y), Vector2(0, vs.y)]), PackedColorArray([z, z, d, d]))
	overlay.draw_polygon(PackedVector2Array([Vector2(0, 0), Vector2(sw, 0), Vector2(sw, vs.y), Vector2(0, vs.y)]), PackedColorArray([d, z, z, d]))
	overlay.draw_polygon(PackedVector2Array([Vector2(vs.x - sw, 0), Vector2(vs.x, 0), Vector2(vs.x, vs.y), Vector2(vs.x - sw, vs.y)]), PackedColorArray([z, d, d, z]))

func _bars(k: float) -> void:
	var vs = overlay.size
	var h: float = vs.y * 0.11 * Typo.smooth(k)
	overlay.draw_rect(Rect2(0, 0, vs.x, h), Color.BLACK); overlay.draw_rect(Rect2(0, vs.y - h, vs.x, h), Color.BLACK)

# intro / ending lines: serif, letter-spaced, each line rising out of the dark a little after the one before
func _caption(lines: Array, t: float, big: bool, out := 1.0) -> void:
	var vs = overlay.size
	for i in lines.size():
		var a: float = Typo.smooth((t - i * 0.9) / 1.4) * out
		if big:
			var y = vs.y * 0.5 + i * 70
			var f: Font = Assets.font_title
			var size = 64 if i == 0 else 40
			Typo.draw(overlay, f, lines[i], vs.x / 2, y, size, Color(PAPER, a), 0.16, 1, -1, 0)
		else:
			var y = vs.y * 0.70 + i * 46
			if i == 0: overlay.draw_texture_rect(game.dot, Rect2(vs.x / 2 - 520, y - 90, 1040, 230), false, Color(0, 0, 0, 0.5 * a))   # soft shade under the lines
			Typo.draw(overlay, Assets.font_serif, lines[i], vs.x / 2, y, 27, Color(0.93, 0.89, 0.79, a), 0.07, 1, -1, 3)

func _draw_overlay() -> void:
	var vs = overlay.size
	match G.state:
		"title":
			var T: float = st.t
			var la: float = Typo.smooth((T - 0.5) / 2.2)
			overlay.draw_rect(Rect2(Vector2.ZERO, vs), Color(0.012, 0.016, 0.04, 0.5 * Typo.smooth(T / 1.0)))
			_vignette(0.55)
			var cy: float = vs.y * 0.37
			overlay.draw_texture_rect(game.dot, Rect2(vs.x / 2 - 520, cy - 230, 1040, 440), false, Color(0, 0, 0, 0.5 * la))
			overlay.draw_texture_rect(game.dot, Rect2(vs.x / 2 - 440, cy - 170, 880, 280), false, Color(0.95, 0.72, 0.38, 0.11 * la))
			var sp: float = 0.30 - 0.08 * Typo.smooth(T / 4.0)
			Typo.draw(overlay, Assets.font_title, "신 처용가", vs.x / 2, cy + 3, 100, Color(0.55, 0.78, 1.0, 0.18 * la), sp, 1, -1, 0)
			Typo.draw(overlay, Assets.font_title, "신 처용가", vs.x / 2, cy, 100, Color(PAPER, la), sp, 1, -1, 5)
			var sa: float = Typo.smooth((T - 1.8) / 1.6)
			Typo.rule(overlay, vs.x / 2, cy + 34, 300, Color(GOLD, 0.75 * sa), sa)
			Typo.draw(overlay, Assets.font_serif, "탈 과  노 래", vs.x / 2, cy + 70, 21, Color(0.86, 0.72, 0.45, sa), 0.55)
			st.rects = []
			var opts: Array = st.get("opts", [])
			var ma: float = Typo.smooth((T - 2.4) / 1.0)
			if G.has("auto"): ma = 1.0
			for i in opts.size():
				var y: float = vs.y * 0.66 + i * 54; var w := 260.0; var x: float = vs.x / 2 - w / 2
				st.rects.append({"x": x / Inp.ui_scale, "y": (y - 32) / Inp.ui_scale, "w": w / Inp.ui_scale, "h": 46 / Inp.ui_scale, "i": i})
				var on: bool = st.sel == i
				var col: Color = Color(0.99, 0.86, 0.55, ma) if on else Color(0.74, 0.69, 0.60, ma * 0.8)
				Typo.draw(overlay, Assets.font_serif_bold, opts[i], vs.x / 2, y, 23, col, 0.32, 1, -1, 3 if on else 2)
				if on:
					var tw: float = Typo.width(Assets.font_serif_bold, opts[i], 23, 0.32)
					for sgn in [-1, 1]:
						var dx: float = vs.x / 2 + sgn * (tw / 2 + 26); var dy: float = y - 8
						overlay.draw_colored_polygon(PackedVector2Array([Vector2(dx, dy - 4), Vector2(dx + 4, dy), Vector2(dx, dy + 4), Vector2(dx - 4, dy)]), Color(GOLD, ma))
					overlay.draw_line(Vector2(vs.x / 2 - tw / 2 - 6, y + 9), Vector2(vs.x / 2 + tw / 2 + 6, y + 9), Color(GOLD, 0.55 * ma), 1.0)
			Typo.draw(overlay, Assets.font_serif, "가로 화면 · 왼쪽 엄지로 이동, 오른쪽 버튼으로 춤 · PC: WASD / J K U I O L E", vs.x / 2, vs.y - 26, 13, Color(0.80, 0.76, 0.68, 0.55 * ma), 0.04)
		"intro":
			var shot: Dictionary = INTRO[min(st.shot, INTRO.size() - 1)]
			var last: bool = shot.get("last", false)
			var dur = INTRO_LAST if last else INTRO_DUR
			var fade: float = Typo.smooth(minf(st.st / 1.3, (dur - st.st) / 1.3))
			overlay.draw_rect(Rect2(Vector2.ZERO, vs), Color(0, 0, 0, 0.85 if last else 0.45 + (1 - fade) * 0.55))
			_vignette(0.5)
			_bars(st.t / 0.9)
			_caption(shot.text, max(0.0, st.st - 0.5), last, Typo.smooth((dur - st.st) / 1.2))
		"ending":
			var shot: Dictionary = ENDING[st.shot]
			var last: bool = shot.get("last", false)
			overlay.draw_rect(Rect2(Vector2.ZERO, vs), Color(0, 0, 0, 0.88 if last else 0.6))
			_vignette(0.5)
			_bars(st.t / 1.0)
			var out: float = 1.0 if last else Typo.smooth((ENDING_DUR - st.st) / 1.4)
			_caption(shot.text, max(0.0, st.st - 0.5), last, out)
			if last:
				Typo.rule(overlay, vs.x / 2, vs.y * 0.5 + 24, 220, Color(GOLD, 0.6 * Typo.smooth((st.st - 0.6) / 1.4)), Typo.smooth((st.st - 0.6) / 1.4))
				var ca: float = Typo.smooth((st.st - 2.4) / 1.6)
				Typo.draw(overlay, Assets.font_serif, "그림: PixelLab 생성  ·  소리: 합성 국악  ·  엔진: Godot", vs.x / 2, vs.y - 52, 13, Color(0.82, 0.78, 0.70, 0.7 * ca), 0.1)
				Typo.draw(overlay, Assets.font_serif, "처용 Lv.%d  ·  정화한 요괴 %d" % [game.player.lvl, int(game.flags.get("kills_total", 0))], vs.x / 2, vs.y - 32, 13, Color(0.82, 0.78, 0.70, 0.7 * ca), 0.1)
	if fade_a > 0.002: overlay.draw_rect(Rect2(Vector2.ZERO, vs), Color(0, 0, 0, fade_a))

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
