# FX: particles, floating damage text, rings, rune circles, screen shake and flash. Drawn in world coordinates.
class_name Fx
extends RefCounted

var parts = []
var texts = []
var rings = []
var circles = []
var shake = 0.0
var flash = 0.0
var flash_color = Color.WHITE

func add(p: Dictionary) -> void:
	var d = {"life": 1.0, "t": 0.0, "vx": 0.0, "vy": 0.0, "vz": 0.0, "z": 0.0, "g": 0.0, "size": 2.0, "color": Color.WHITE, "glow": false, "drag": 0.0, "smoke": false, "soul": false}
	d.merge(p, true)
	parts.append(d)

func burst(x: float, y: float, n: int, o := {}) -> void:
	for i in n:
		var a = randf() * TAU
		var s: float = o.get("speed", 80.0) * (0.4 + randf() * 0.8)
		add({"x": x, "y": y, "vx": cos(a) * s, "vy": sin(a) * s * 0.6, "vz": o.get("up", 60.0) * (0.5 + randf()), "g": o.get("g", 220.0),
			"life": o.get("life", 0.5) * (0.6 + randf() * 0.8), "size": o.get("size", 2.0), "color": o.get("color", Color.WHITE), "glow": o.get("glow", false), "drag": o.get("drag", 1.5)})

func hit(x: float, y: float, color := Color("#ffe6a0")) -> void:
	burst(x, y - 30, 8, {"speed": 140, "up": 40, "life": 0.25, "size": 2.0, "color": color, "glow": true, "g": 0.0})

func smoke(x: float, y: float, n := 1, color := Color("#7a3cff")) -> void:
	for i in n:
		add({"x": x + (randf() - 0.5) * 30, "y": y + (randf() - 0.5) * 10, "z": randf() * 40, "vz": 20 + randf() * 30,
			"vx": (randf() - 0.5) * 20, "life": 1.0 + randf(), "size": 5 + randf() * 6, "color": color, "smoke": true, "glow": true})

func soul(x: float, y: float) -> void:
	add({"x": x, "y": y, "z": 40.0, "vz": 60.0, "vx": (randf() - 0.5) * 30, "life": 1.8, "size": 6.0, "color": Color("#9fe0ff"), "glow": true, "soul": true})
	for i in 10:
		add({"x": x + (randf() - 0.5) * 20, "y": y, "z": 20 + randf() * 40, "vz": 40 + randf() * 60, "life": 1.0 + randf(), "size": 2.0, "color": Color("#c8f0ff"), "glow": true})

func text(x: float, y: float, s: String, color := Color.WHITE, size := 16) -> void:
	texts.append({"x": x, "y": y, "s": s, "color": color, "size": size, "t": 0.0, "life": 0.9})

func ring(x: float, y: float, r0: float, r1: float, life: float, color := Color("#9fe0ff"), w := 3.0) -> void:
	rings.append({"x": x, "y": y, "r0": r0, "r1": r1, "life": life, "t": 0.0, "color": color, "w": w})

func circle(x: float, y: float, r: float, color := Color("#7ff0ff"), life := 0.8) -> void:
	circles.append({"x": x, "y": y, "r": r, "color": color, "life": life, "t": 0.0})

func screen_shake(v: float) -> void: shake = max(shake, v)
func screen_flash(v: float, c := Color.WHITE) -> void:
	flash = max(flash, v); flash_color = c

func clear() -> void:
	parts.clear(); texts.clear(); rings.clear(); circles.clear()

func update(dt: float) -> void:
	for i in range(parts.size() - 1, -1, -1):
		var p: Dictionary = parts[i]
		p.t += dt
		if p.t >= p.life: parts.remove_at(i); continue
		p.x += p.vx * dt; p.y += p.vy * dt
		p.vz -= p.g * dt; p.z += p.vz * dt
		if p.z < 0 and p.g > 0: p.z = 0; p.vz *= -0.3; p.vx *= 0.6; p.vy *= 0.6
		var d = exp(-p.drag * dt); p.vx *= d; p.vy *= d
		if p.soul: p.vx += sin(p.t * 6) * 40 * dt
	for arr in [texts, rings, circles]:
		for i in range(arr.size() - 1, -1, -1):
			arr[i].t += dt
			if arr[i].t > arr[i].life: arr.remove_at(i)
	shake = max(0.0, shake - dt * 30)
	flash = max(0.0, flash - dt * 2.5)

# ---------- drawing (called by the layer nodes) ----------
static func ellipse(ci: CanvasItem, c: Vector2, rx: float, ry: float, col: Color, filled := true, width := 2.0) -> void:
	var pts = PackedVector2Array()
	var n = 28
	for i in n + 1:
		var a = i / float(n) * TAU
		pts.append(c + Vector2(cos(a) * rx, sin(a) * ry))
	if filled: ci.draw_colored_polygon(pts, col)
	else: ci.draw_polyline(pts, col, width, true)

# an ellipse lying on the terrain (game pixels), drawn in screen space through the 3D view
static func gellipse(ci: CanvasItem, c: Vector2, rx: float, ry: float, col: Color, filled := true, width := 2.0) -> void:
	var pts = PackedVector2Array()
	var n = 28
	for i in n + 1:
		var a = i / float(n) * TAU
		pts.append(G.game.sp(c.x + cos(a) * rx, c.y + sin(a) * ry))
	if filled:
		pts.remove_at(pts.size() - 1)
		if not Geometry2D.triangulate_polygon(pts).is_empty(): ci.draw_colored_polygon(pts, col)
	else: ci.draw_polyline(pts, col, width, true)

# additive layer under sprites: rune circles and expanding rings
func draw_ground(ci: CanvasItem) -> void:
	for r in rings:
		var k: float = r.t / r.life
		var rad: float = lerpf(r.r0, r.r1, G.ease_out(k))
		var c: Color = r.color; c.a = 1.0 - k
		gellipse(ci, Vector2(r.x, r.y), rad, rad * 0.62, c, false, r.w)
	for c in circles:
		var k: float = c.t / c.life
		var a: float = min(1.0, k * 6) * (1 - k * k)
		var r: float = c.r * (0.7 + 0.3 * G.ease_out(min(1.0, k * 3)))
		var col: Color = c.color; col.a = a
		var ctr = Vector2(c.x, c.y)
		var fill = col; fill.a = a * 0.18
		gellipse(ci, ctr, r, r * 0.6, fill)
		gellipse(ci, ctr, r, r * 0.6, col, false, 2.0)
		gellipse(ci, ctr, r * 0.78, r * 0.78 * 0.6, col, false, 1.2)
		var rot: float = c.t * 1.6
		for j in 12:
			var an = rot + j / 12.0 * TAU
			ci.draw_line(G.game.sp(ctr.x + cos(an) * r * 0.8, ctr.y + sin(an) * r * 0.8 * 0.6), G.game.sp(ctr.x + cos(an + 0.15) * r * 0.97, ctr.y + sin(an + 0.15) * r * 0.97 * 0.6), col, 1.2, true)
		var star = PackedVector2Array()
		for j in 6:
			var an = -c.t * 1.6 + (j * 4 * PI) / 5 - PI / 2
			star.append(G.game.sp(ctr.x + cos(an) * r * 0.62, ctr.y + sin(an) * r * 0.62 * 0.6))
		ci.draw_polyline(star, col, 1.2, true)

# particles: glow ones on the additive layer, the rest on the normal layer
func draw_parts(ci: CanvasItem, glow: bool, dot: Texture2D) -> void:
	for p in parts:
		if p.glow != glow: continue
		var k: float = p.t / p.life
		var col: Color = p.color
		col.a = (1 - k) * 0.35 if p.smoke else 1 - k * k
		var s: float = (p.size * (1 + k) if p.smoke else p.size) * G.game.view.ppx
		var pos: Vector2 = G.game.sp(p.x, p.y, p.z)
		if p.soul or p.smoke:
			ci.draw_texture_rect(dot, Rect2(pos - Vector2(s, s) * 1.6, Vector2(s, s) * 3.2), false, col)
		else:
			ci.draw_rect(Rect2(pos - Vector2(s, s) / 2, Vector2(s, s)), col)

func draw_texts(ci: CanvasItem, font: Font) -> void:
	for t in texts:
		var k: float = t.t / t.life
		var pop: float = 1 + (0.12 - k) * 5 if k < 0.12 else 1.0
		var size = int(round(t.size * 1.25 * pop))
		var col: Color = t.color; col.a = 1 - k * k
		var pos: Vector2 = G.game.sp(t.x, t.y, 26 * G.ease_out(k))
		var w = font.get_string_size(t.s, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
		var p = pos - Vector2(w / 2, 0)
		ci.draw_string_outline(font, p, t.s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, max(3, size / 5), Color(0.08, 0.04, 0.04, col.a))
		ci.draw_string(font, p, t.s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, col)
