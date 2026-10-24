# Typo: typography helpers for the cinematic layers (letter-spaced serif text, typewriter reveal, ink-brush strokes).
# Everything draws on a CanvasItem passed in, so the UI, the title overlay and the cards share one look.
class_name Typo
extends RefCounted

const INK_GOLD := Color(0.80, 0.66, 0.40)
const PAPER := Color(0.94, 0.90, 0.80)

# Gowun Batang and Song Myung lack some symbols (middle dot, brackets): let them fall back to Pretendard
static var _done := false
static func setup() -> void:
	if _done: return
	_done = true
	# Song Myung is a brush face with overlapping contours: its distance field shows spikes, so it is rasterised normally
	Assets.font_title.multichannel_signed_distance_field = false
	Assets.font_title.fallbacks = [Assets.font_serif, Assets.font]
	Assets.font_serif.fallbacks = [Assets.font]
	Assets.font_serif_bold.fallbacks = [Assets.font_bold]

static func width(font: Font, s: String, size: int, sp := 0.0) -> float:
	if sp == 0.0 or s.length() < 2: return font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	var w := 0.0
	for ch in s: w += font.get_string_size(ch, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x + sp * size
	return w - sp * size

# align: 0 left, 1 centre, 2 right. shown < 0 draws everything; otherwise only the first `shown` characters
# (the position still follows the full string so a typewriter reveal does not shift). outline > 0 adds a dark edge.
static func draw(ci: CanvasItem, font: Font, s: String, x: float, y: float, size: int, col: Color, sp := 0.0, align := 1, shown := -1, outline := 0) -> void:
	if col.a <= 0.003: return
	var w := width(font, s, size, sp)
	var px := x - (w / 2 if align == 1 else (w if align == 2 else 0.0))
	var oc := Color(0.02, 0.015, 0.03, col.a * 0.85)
	if sp == 0.0:
		var t := s if shown < 0 else s.substr(0, shown)
		if outline > 0: ci.draw_string_outline(font, Vector2(px, y), t, HORIZONTAL_ALIGNMENT_LEFT, -1, size, outline, oc)
		ci.draw_string(font, Vector2(px, y), t, HORIZONTAL_ALIGNMENT_LEFT, -1, size, col)
		return
	var n := s.length() if shown < 0 else mini(shown, s.length())
	var xs := PackedFloat32Array()
	var cx := px
	for i in n:
		xs.append(cx)
		cx += font.get_string_size(s[i], HORIZONTAL_ALIGNMENT_LEFT, -1, size).x + sp * size
	if outline > 0:   # all edges first, so a neighbour's edge never cuts into a letter
		for i in n: ci.draw_string_outline(font, Vector2(xs[i], y), s[i], HORIZONTAL_ALIGNMENT_LEFT, -1, size, outline, oc)
	for i in n: ci.draw_string(font, Vector2(xs[i], y), s[i], HORIZONTAL_ALIGNMENT_LEFT, -1, size, col)

# largest size <= size whose width fits max_w
static func fit(font: Font, s: String, size: int, max_w: float, sp := 0.0) -> int:
	while size > 10 and width(font, s, size, sp) > max_w: size -= 1
	return size

static func wrap(font: Font, s: String, size: int, max_w: float) -> Array:
	var out := []
	var line := ""
	for ch in s:
		if font.get_string_size(line + ch, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x > max_w and line != "":
			out.append(line)
			line = ch if ch != " " else ""
		else: line += ch
	out.append(line)
	return out

# a single dry-brush stroke: heavy start, ragged tapering end. k (0..1) grows it from the left.
static func brush(ci: CanvasItem, cx: float, y: float, w: float, h: float, col: Color, k := 1.0, seed := 3) -> void:
	if k <= 0.01 or col.a <= 0.003: return
	var n := 28
	var up := PackedVector2Array(); var dn := PackedVector2Array()
	var x0 := cx - w / 2
	var m := maxi(2, int(n * clampf(k, 0.0, 1.0)))
	for i in m + 1:
		var u := float(i) / n
		var env := pow(sin(clampf(u, 0.0, 1.0) * PI * 0.92 + 0.08), 0.55) * (1.0 - 0.45 * u)
		var rag := 0.72 + 0.28 * G.noise(u * 9.0, seed * 1.7, seed)
		var th := maxf(0.7, h * env * rag)
		var yc := y + (G.noise(u * 3.0, seed * 0.9, seed + 4) - 0.5) * h * 0.5 + u * h * 0.25
		up.append(Vector2(x0 + w * u, yc - th * 0.5))
		dn.append(Vector2(x0 + w * u, yc + th * 0.5))
	var poly := PackedVector2Array(up)
	for i in range(dn.size() - 1, -1, -1): poly.append(dn[i])
	if poly.size() >= 3: ci.draw_colored_polygon(poly, col)
	# a few dry hairs trailing off the end of the stroke
	for j in 3:
		var hy := y + (j - 1) * h * 0.38 + h * 0.2
		var hx0 := x0 + w * (0.35 + 0.18 * j)
		var hx1 := x0 + w * minf(k, 0.78 + 0.1 * j)
		if hx1 > hx0 + 4: ci.draw_line(Vector2(hx0, hy), Vector2(hx1, hy + 0.6), Color(col, col.a * 0.45), 1.0)

# thin gold rule with a small diamond in the middle
static func rule(ci: CanvasItem, cx: float, y: float, w: float, col: Color, k := 1.0) -> void:
	if col.a <= 0.003 or k <= 0: return
	var half := w / 2 * clampf(k, 0.0, 1.0)
	ci.draw_line(Vector2(cx - half, y), Vector2(cx - 7, y), col, 1.0)
	ci.draw_line(Vector2(cx + 7, y), Vector2(cx + half, y), col, 1.0)
	ci.draw_colored_polygon(PackedVector2Array([Vector2(cx, y - 3.5), Vector2(cx + 3.5, y), Vector2(cx, y + 3.5), Vector2(cx - 3.5, y)]), col)

static func smooth(t: float) -> float:
	t = clampf(t, 0.0, 1.0)
	return t * t * (3.0 - 2.0 * t)

# 0 -> 1 over fin seconds, holds, 1 -> 0 over fout seconds before `dur`
static func envelope(t: float, dur: float, fin: float, fout: float) -> float:
	return smooth(minf(t / maxf(fin, 0.001), (dur - t) / maxf(fout, 0.001)))
