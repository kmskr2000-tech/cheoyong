# Cine: the cinematic layer of the UI. Child of the UI control, so it is not dimmed when the HUD fades out.
# Letterbox bars, the dialogue box (serif, typewriter), verse and zone captions, chapter title cards and fades through black.
# Timings run on game time (ui.tick), so tests with --speed behave. In --auto runs cards and fades are shortened.
extends Control

const BAR := 0.11            # letterbox bar height, share of the screen
const GOLD := Color(0.84, 0.69, 0.42)
const INK := Color(0.03, 0.027, 0.04)
const NUM_KO := ["일", "이", "삼", "사", "오", "육", "칠", "팔"]

var ui                       # the UI control
var lb := 0.0                # letterbox amount 0..1 (eased in/out over ~0.4 s)
var card = null              # {title, quote, by, t, fin, hold, fout, dur}
var fade = null              # {t, stage: "out" | "in", fn}

func _ready() -> void:
	Typo.setup()
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)

# ---------- state ----------
func active() -> bool: return ui.dialog != null or ui.g.cinema

# true while the world should stand still: a title card is up, or the screen is fading out before a change of map
func blocking() -> bool:
	return card != null or (fade != null and fade.stage == "out")

func hud_alpha() -> float:
	return 1.0 - Typo.smooth(lb)

func start_card(c: Dictionary) -> void:
	var k := 0.2 if G.has("auto") else 1.0
	card = {"title": c.title, "quote": c.get("quote", ""), "by": c.get("by", ""), "t": 0.0, "fin": 1.2 * k, "hold": 2.5 * k, "fout": 1.2 * k, "seed": int(c.get("n", 1))}
	card.dur = card.fin + card.hold + card.fout

# black out, run fn (a change of map), then reveal: 0.35 s each way
func fade_through(fn: Callable) -> void:
	fade = {"t": 0.0, "stage": "out", "fn": fn}

func update(dt: float) -> void:
	lb = move_toward(lb, 1.0 if active() else 0.0, dt / 0.4)
	if ui.dialog != null: ui.dialog.age = ui.dialog.get("age", 0.0) + dt
	if card != null:
		card.t += dt
		# confirm skips the hold once the title has been read
		if card.t > 1.4 and card.t < card.fin + card.hold and (Inp.hit("confirm") or Inp.hit("tap")): card.t = card.fin + card.hold
		if card.t >= card.dur: card = null
	if fade != null:
		fade.t += dt
		if fade.t >= 0.35:
			if fade.stage == "out":
				fade.stage = "in"; fade.t = 0.0
				if fade.fn.is_valid(): fade.fn.call()
			else: fade = null

# ---------- drawing ----------
func _draw() -> void:
	if ui == null or ui.g == null or G.state != "play": return
	_zone()
	_banner_dim()
	_letterbox()
	_dialog()
	_banner()
	_card()
	_fade()

func _letterbox() -> void:
	var bh: float = ui.vh * BAR * Typo.smooth(lb)
	if bh < 0.5: return
	draw_rect(Rect2(0, -1, ui.vw, bh + 1), Color.BLACK)
	draw_rect(Rect2(0, ui.vh - bh, ui.vw, bh + 1), Color.BLACK)

func _fade() -> void:
	if fade == null: return
	var k: float = clampf(fade.t / 0.35, 0.0, 1.0)
	draw_rect(Rect2(0, 0, ui.vw, ui.vh), Color(0.01, 0.01, 0.02, k if fade.stage == "out" else 1.0 - k))

# ----- zone name: serif with a faint ink-brush stroke under it -----
func _zone() -> void:
	var zb = ui.g.zone_banner
	if zb == null or zb.t >= 3.0: return
	var a: float = Typo.envelope(zb.t, 3.0, 0.9, 1.0) * hud_alpha()
	if a <= 0.01: return
	var y: float = ui.vh * 0.27
	var s: String = zb.name
	var size := 32
	draw_texture_rect(ui.g.dot, Rect2(ui.vw / 2 - 280, y - 70, 560, 130), false, Color(0, 0, 0, 0.42 * a))   # soft shade so the name reads on bright ground
	Typo.draw(self, Assets.font_serif_bold, s, ui.vw / 2, y, size, Color(0.97, 0.93, 0.83, a), 0.22, 1, -1, 5)
	var w: float = clampf(Typo.width(Assets.font_serif_bold, s, size, 0.22) + 36, 140.0, 360.0)
	Typo.brush(self, ui.vw / 2, y + 17, w, 6.0, Color(0.86, 0.70, 0.42, 0.5 * a), Typo.smooth(zb.t / 1.1), 5)

# ----- dialogue -----
func _portrait_frame(x: float, y: float, s: float, spr: String, a: float) -> void:
	draw_rect(Rect2(x, y, s, s), Color(0.075, 0.07, 0.095, 0.95 * a))
	ui.portrait_to(self, spr, x + 3, y + 3, s - 6, a)
	# soft edge shading so the pixel sprite sits inside the frame
	var e := 14.0
	var d0 := Color(0, 0, 0, 0.5 * a); var d1 := Color(0, 0, 0, 0.0)
	var i0 := Vector2(x + 3, y + 3); var i1 := Vector2(x + s - 3, y + s - 3)
	draw_polygon(PackedVector2Array([i0, Vector2(i1.x, i0.y), Vector2(i1.x, i0.y + e), Vector2(i0.x, i0.y + e)]), PackedColorArray([d0, d0, d1, d1]))
	draw_polygon(PackedVector2Array([Vector2(i0.x, i1.y - e), Vector2(i1.x, i1.y - e), i1, Vector2(i0.x, i1.y)]), PackedColorArray([d1, d1, d0, d0]))
	draw_rect(Rect2(x + 3, y + 3, s - 6, s - 6), Color(0, 0, 0, 0.55 * a), false, 1.0)
	draw_rect(Rect2(x + 0.5, y + 0.5, s - 1, s - 1), Color(GOLD, 0.8 * a), false, 1.0)

func _dialog() -> void:
	var d = ui.dialog
	if d == null or d.wait: return
	var l: Array = d.lines[d.i]
	var sp: String = l[0]
	var text: String = l[1]
	var narr: bool = sp == "@"
	var a: float = Typo.smooth(d.get("age", 1.0) / 0.3)
	var vw: float = ui.vw; var vh: float = ui.vh
	var w: float = minf(860.0, vw - 36.0)
	var x: float = (vw - w) / 2
	var spr: String = "" if narr else ui.speaker_sprite(sp)
	var portrait: bool = spr != "" and Assets.chars.has(spr)
	var tx: float = x + (138.0 if portrait else 34.0)
	var tw: float = x + w - 34.0 - tx
	var font: Font = Assets.font_serif
	var fs := 18
	var lines: Array = Typo.wrap(font, text, fs, tw - (0 if not narr else 40))
	if lines.size() > 3: fs = 16; lines = Typo.wrap(font, text, fs, tw)
	var lh: float = fs * 1.55
	var h: float = maxf(128.0, 58.0 + lines.size() * lh + 12.0)
	var y: float = vh - vh * BAR - h - 12.0 + (1.0 - a) * 8.0
	# panel: dark ink, gold rule on top, faint rule at the foot
	for i in 3: draw_rect(Rect2(x - i * 3, y - i * 3 + 6, w + i * 6, h + i * 6), Color(0, 0, 0, 0.10 * a))
	var c0 := Color(INK, 0.86 * a); var c1 := Color(0.015, 0.014, 0.022, 0.92 * a)
	draw_polygon(PackedVector2Array([Vector2(x, y), Vector2(x + w, y), Vector2(x + w, y + h), Vector2(x, y + h)]), PackedColorArray([c0, c0, c1, c1]))
	draw_line(Vector2(x, y + 0.5), Vector2(x + w, y + 0.5), Color(GOLD, 0.9 * a), 1.0)
	draw_line(Vector2(x, y + h - 0.5), Vector2(x + w, y + h - 0.5), Color(GOLD, 0.26 * a), 1.0)
	draw_line(Vector2(x + 0.5, y), Vector2(x + 0.5, y + h), Color(GOLD, 0.10 * a), 1.0)
	draw_line(Vector2(x + w - 0.5, y), Vector2(x + w - 0.5, y + h), Color(GOLD, 0.10 * a), 1.0)
	if portrait: _portrait_frame(x + 20, y + (h - 96) / 2, 96, spr, a)
	var ty: float = y + 62.0
	if not narr:
		var nw: float = Typo.width(Assets.font_serif_bold, sp, 18, 0.12)
		Typo.draw(self, Assets.font_serif_bold, sp, tx, y + 33, 18, Color(0.96, 0.80, 0.50, a), 0.12, 0)
		draw_line(Vector2(tx, y + 42), Vector2(tx + nw + 18, y + 42), Color(GOLD, 0.45 * a), 1.0)
	else:
		ty = y + (h - lines.size() * lh) / 2 + fs
	# typewriter: reveal the characters in order across the wrapped lines
	var left := int(d.shown)
	for i in lines.size():
		var ln: String = lines[i]
		var part := ln.substr(0, clampi(left, 0, ln.length()))
		left -= ln.length()
		if part == "": break
		if narr: Typo.draw(self, font, ln, vw / 2, ty + i * lh, fs, Color(0.84, 0.87, 0.91, a), 0.0, 1, part.length())
		else: Typo.draw(self, font, ln, tx, ty + i * lh, fs, Color(0.95, 0.91, 0.82, a), 0.0, 0, part.length())
	# a small blinking mark when the line is complete
	if d.shown >= text.length():
		var p: float = 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.0065)
		var bx: float = x + w - 30; var by: float = y + h - 24 + p * 2.0
		var col := Color(GOLD, (0.35 + 0.65 * p) * a)
		draw_colored_polygon(PackedVector2Array([Vector2(bx - 5, by - 3), Vector2(bx + 5, by - 3), Vector2(bx, by + 4)]), col)

# ----- verse / hyangga banner -----
func _banner_dim() -> void:
	var b = ui.banner
	if b == null: return
	var a: float = minf(1.0, minf(b.t * 1.5, (4.2 - b.t) * 1.5))
	draw_rect(Rect2(0, 0, ui.vw, ui.vh), Color(0.01, 0.012, 0.03, 0.74 * a))

func _banner() -> void:
	var b = ui.banner
	if b == null: return
	var D := 4.2
	var a: float = minf(1.0, minf(b.t * 1.5, (D - b.t) * 1.5))
	var cx: float = ui.vw / 2; var cy: float = ui.vh / 2
	var text: String
	var head: String
	if b.has("hy"):
		var H: Dictionary = Story.HYANGGA[b.hy]
		head = "향가  ·  %s  (%s)" % [H.name, H.by]
		text = H.line
		Typo.draw(self, Assets.font_serif, H.effect, cx, cy + 74, 15, Color(0.76, 0.88, 0.98, a * clampf(b.t - 1.4, 0.0, 1.0)), 0.03)
	else:
		head = "처용가  ·  제%s구" % NUM_KO[b.n - 1]
		text = Story.VERSES[b.n - 1]
	var shown := int(ceil(minf(1.0, b.t / 1.6) * text.length()))
	var fs := 46 if text.length() < 14 else 34
	fs = Typo.fit(Assets.font_title, text, fs, ui.vw - 80, 0.07)
	var g = ui.g
	var glow: float = 0.16 * a
	draw_texture_rect(g.dot, Rect2(cx - 300, cy - 70, 600, 150), false, Color(0.95, 0.78, 0.45, glow))
	Typo.draw(self, Assets.font_serif_bold, head, cx, cy - 52, 15, Color(GOLD, a), 0.2)
	Typo.draw(self, Assets.font_title, text, cx, cy + 12, fs, Color(0.97, 0.93, 0.82, a), 0.07, 1, shown, 5)
	Typo.brush(self, cx, cy + 36, minf(360.0, Typo.width(Assets.font_title, text, fs, 0.07) + 40), 6.0, Color(0.86, 0.70, 0.42, 0.55 * a), Typo.smooth(b.t / 1.8), 9)

# ----- chapter title card -----
func _card() -> void:
	if card == null: return
	var c: Dictionary = card
	var vw: float = ui.vw; var vh: float = ui.vh
	# the black holds until the end, then lifts together with the text
	var bg: float = 1.0 if c.t < c.fin + c.hold else 1.0 - Typo.smooth((c.t - c.fin - c.hold) / c.fout)
	draw_rect(Rect2(0, 0, vw, vh), Color(0.005, 0.005, 0.01, bg))
	var a: float = Typo.envelope(c.t, c.dur, c.fin, c.fout)
	var cy: float = vh * 0.43
	var settle: float = 0.10 + 0.05 * Typo.smooth(c.t / (c.fin + c.hold))   # the letters drift slowly apart
	var fs := Typo.fit(Assets.font_title, c.title, 54, vw - 80, settle)
	Typo.draw(self, Assets.font_title, c.title, vw / 2, cy, fs, Color(0.95, 0.90, 0.78, a), settle, 1, -1, 0)
	var qa: float = Typo.envelope(maxf(0.0, c.t - 0.7), c.dur - 0.7, c.fin, c.fout)
	Typo.rule(self, vw / 2, cy + 30, minf(320.0, vw - 120), Color(GOLD, 0.75 * a), Typo.smooth(c.t / (c.fin + 0.4)))
	if c.quote != "":
		var qs := Typo.fit(Assets.font_title, c.quote, 24, vw - 100, 0.06)
		Typo.draw(self, Assets.font_title, c.quote, vw / 2, cy + 74, qs, Color(0.84, 0.79, 0.67, qa), 0.06)
	if c.by != "":
		Typo.draw(self, Assets.font_serif, c.by, vw / 2, cy + 106, 14, Color(0.62, 0.56, 0.46, qa), 0.14)
