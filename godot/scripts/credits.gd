# Credits: the text of the title screen's "제작진" page, plus the scrolling draw used by main.gd (state "credits").
# LINES entries are [kind, text]: h = game title, s = small dim line, k = section heading, t = text, g = gap.
# Add names under "제작" when the team list is final.
class_name Credits

const LINES := [
	["h", "신 처용가"],
	["s", "— 탈과 노래 —"],
	["g", ""],
	["k", "제작"],
	["t", "기획 · 시나리오 · 프로그래밍"],
	["t", "신 처용가 제작팀"],
	["g", ""],
	["k", "이야기의 뿌리"],
	["t", "향가 〈처용가〉 · 『삼국유사』 처용랑 망해사조"],
	["g", ""],
	["k", "엔진"],
	["t", "Godot Engine 4.4 — MIT License"],
	["s", "© 2014-present Godot Engine contributors"],
	["s", "© 2007-2014 Juan Linietsky, Ariel Manzur"],
	["s", "godotengine.org"],
	["g", ""],
	["k", "글꼴"],
	["t", "Pretendard · Gowun Batang · Song Myung"],
	["s", "SIL Open Font License 1.1"],
	["g", ""],
	["k", "그림"],
	["t", "인물 · 요괴 · 지형 · 소품"],
	["s", "PixelLab (pixellab.ai) 으로 생성한 픽셀 아트"],
	["g", ""],
	["k", "소리"],
	["t", "국악풍 음악과 효과음"],
	["s", "Python · NumPy · SciPy 로 합성"],
	["g", ""],
	["k", "도구"],
	["t", "Godot Editor · PixelLab · Python · Pillow"],
	["s", "Claude Code (Anthropic) 와 함께 개발"],
	["g", ""],
	["g", ""],
	["t", "끝까지 함께해 주어 고맙소"],
	["g", ""],
]
const HEIGHT := {"h": 64.0, "s": 26.0, "k": 52.0, "t": 32.0, "g": 22.0}
const SPEED := 34.0   # auto scroll, pixels per second

static func total_height() -> float:
	var h := 0.0
	for l in LINES: h += HEIGHT[l[0]]
	return h

# furthest scroll offset: the last line stops a little above the middle of the screen
static func max_scroll(view_h: float) -> float:
	return total_height() + view_h * 0.47

static func _ctext(c: Control, s: String, x: float, y: float, size: int, col: Color, font: Font, outline := 0) -> void:
	var w := font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	if outline > 0: c.draw_string_outline(font, Vector2(x - w / 2, y), s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, outline, Color(0, 0, 0, col.a * 0.9))
	c.draw_string(font, Vector2(x, y) - Vector2(w / 2, 0), s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, col)

# draw on a screen-sized control; offset is the scroll position in pixels
static func draw(c: Control, offset: float, fade: float, pad: bool) -> void:
	var vs := c.size
	c.draw_rect(Rect2(Vector2.ZERO, vs), Color(0.016, 0.024, 0.07, 0.72 * fade))
	var y := vs.y * 0.92 - offset
	for l in LINES:
		var kind: String = l[0]
		var a := clampf((y - 24.0) / 90.0, 0.0, 1.0) * clampf((vs.y - 84.0 - y) / 40.0, 0.0, 1.0) * fade
		if a > 0.0 and kind != "g":
			match kind:
				"h": _ctext(c, l[1], vs.x / 2, y + 34, 64, Color(0.96, 0.91, 0.8, a), Assets.font_black, 6)
				"s": _ctext(c, l[1], vs.x / 2, y + 14, 14, Color(0.78, 0.74, 0.66, a * 0.85), Assets.font)
				"k": _ctext(c, l[1], vs.x / 2, y + 32, 22, Color(1.0, 0.82, 0.48, a), Assets.font_black, 3)
				"t": _ctext(c, l[1], vs.x / 2, y + 20, 19, Color(0.95, 0.9, 0.8, a), Assets.font_bold, 2)
		y += HEIGHT[kind]
	var hint := "A · B · Start : 돌아가기" if pad else "Enter · Esc : 돌아가기      ↑ ↓ : 빨리 넘기기"
	_ctext(c, hint, vs.x / 2, vs.y - 18, 13, Color(0.86, 0.82, 0.75, 0.75 * fade), Assets.font)
