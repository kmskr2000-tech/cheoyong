# Settings page of the pause menu (page 2): volumes, fullscreen, screen shake, text speed, back to title, quit.
# ui.gd owns the menu frame, tabs and focus; this class draws the page into ui.menu_rects and applies taps / pad input.
# Rect keys used by ui.gd: id (focusable), nofocus, def (default focus), set (setting key), type, act.
class_name SettingsMenu
extends RefCounted

const GOLD := Color("#ffd27a")
const PAPER := Color("#f3e6c4")
const SLIDER_STEP := 5

var armed := ""        # "title" / "quit": the first press asks, a second press within 3 s does it
var armed_until := 0

func rows() -> Array:
	var r := [
		{"k": "master", "label": "전체 음량", "type": "slider"},
		{"k": "music", "label": "음악", "type": "slider"},
		{"k": "sfx", "label": "효과음", "type": "slider"},
	]
	if Settings.is_desktop(): r.append({"k": "fullscreen", "label": "전체 화면", "type": "toggle"})
	r.append({"k": "shake", "label": "화면 흔들림", "type": "toggle"})
	r.append({"k": "text_mode", "label": "대사 속도", "type": "cycle"})
	return r

func draw(ui, x: float, y: float, w: float, h: float) -> void:
	if Time.get_ticks_msec() > armed_until: armed = ""
	var R := rows()
	ui.txt("설정", x + 24, y + 80, 16, GOLD)
	var top := y + 92.0
	var row_h := clampf((h - 92.0 - 66.0) / R.size(), 30.0, 46.0)
	var lx := x + 40.0
	var rw := w - 80.0
	for i in R.size():
		var row: Dictionary = R[i]
		var ry := top + i * row_h
		var rh := row_h - 4.0
		var focus: bool = ui.menu_focus == "set:" + row.k and not ui.is_touch()
		ui.draw_rect(Rect2(lx, ry, rw, rh), Color(0.84, 0.7, 0.43, 0.2) if focus else Color(1, 1, 1, 0.05))
		ui.txt(row.label, lx + 14, ry + rh / 2 + 6, 16, PAPER)
		var rect := {"x": lx, "y": ry, "w": rw, "h": rh, "id": "set:" + row.k, "set": row.k, "type": row.type}
		if i == 0: rect["def"] = true
		ui.menu_rects.append(rect)
		var cx0 := lx + 200.0
		var cx1 := lx + rw - 14.0
		var cy := ry + rh / 2
		var v = Settings.get_value(row.k)
		match row.type:
			"slider":
				var bw := 28.0
				var minus := {"x": cx0, "y": cy - bw / 2, "w": bw, "h": bw, "set": row.k, "type": "step", "step": -SLIDER_STEP, "nofocus": true}
				var tx := cx0 + bw + 12.0
				var tw := cx1 - 56.0 - bw - 12.0 - tx
				var plus := {"x": tx + tw + 12.0, "y": cy - bw / 2, "w": bw, "h": bw, "set": row.k, "type": "step", "step": SLIDER_STEP, "nofocus": true}
				var track := {"x": tx, "y": ry, "w": tw, "h": rh, "set": row.k, "type": "track", "nofocus": true, "id": "track:" + row.k}
				for b in [minus, plus]:
					ui.menu_rects.append(b)
					ui.draw_rect(Rect2(b.x, b.y, b.w, b.h), Color(1, 1, 1, 0.1))
					ui.txt("−" if b.step < 0 else "+", b.x + b.w / 2, b.y + 20, 18, PAPER, 1)
				ui.menu_rects.append(track)
				ui.draw_rect(Rect2(tx, cy - 4, tw, 8), Color(0, 0, 0, 0.45))
				ui.draw_rect(Rect2(tx, cy - 4, tw * v / 100.0, 8), Color(0.84, 0.7, 0.43, 0.85))
				ui.draw_rect(Rect2(tx + tw * v / 100.0 - 5, cy - 11, 10, 22), Color("#ffe2a0"))
				ui.txt(str(v), cx1, cy + 6, 16, PAPER, 2)
			"toggle":
				var on: bool = v
				ui.draw_rect(Rect2(cx1 - 90, cy - 15, 90, 30), Color(0.84, 0.7, 0.43, 0.35) if on else Color(1, 1, 1, 0.08))
				ui.draw_rect(Rect2(cx1 - 90, cy - 15, 90, 30), Color(0.84, 0.7, 0.43, 0.7) if on else Color(1, 1, 1, 0.2), false, 1.5)
				ui.txt("켜짐" if on else "꺼짐", cx1 - 45, cy + 6, 15, GOLD if on else Color("#9a9080"), 1)
			"cycle":
				var mid := cx1 - 90.0
				ui.txt("◀", mid - 70, cy + 6, 14, Color("#b8b0a0"), 1)
				ui.txt("▶", mid + 70, cy + 6, 14, Color("#b8b0a0"), 1)
				ui.txt(Settings.TEXT_MODES[v], mid, cy + 6, 16, GOLD, 1)
	# bottom row
	var by := y + h - 54.0
	var bx := x + w - 130.0
	var btns := [["close", "돌아가기", ""]]
	btns.append(["title", "타이틀로", "정말 타이틀로?"])
	if Settings.is_desktop(): btns.append(["quit", "게임 종료", "정말 종료?"])
	for i in btns.size():
		var b: Array = btns[i]
		var r := {"x": bx - i * 130.0, "y": by, "w": 120.0, "h": 38.0, "id": b[0]}
		if b[0] == "close": r["close"] = true; r.w = 110.0
		else: r["act"] = b[0]
		ui.menu_rects.append(r)
		var hot: bool = armed == b[0]
		ui.draw_rect(Rect2(r.x, r.y, r.w, r.h), Color(0.84, 0.7, 0.43, 0.25) if b[0] == "close" else (Color(0.8, 0.3, 0.25, 0.4) if hot else Color(1, 1, 1, 0.08)))
		ui.txt(b[2] if hot else b[1], r.x + r.w / 2, r.y + 25, 14 if hot else 15, GOLD if b[0] == "close" else Color("#d8ccb0"), 1)
	var hint := "↑↓ 고르기 · ←→ 바꾸기 · A 선택 · B 닫기 · LB/RB 쪽 넘기기" if Inp.pad_used else "↑↓ 고르기 · ←→ 바꾸기 · Enter 선택 · Esc 닫기 · U/I 쪽 넘기기"
	ui.txt(ui.fit(hint, 12, bx - 130.0 * (btns.size() - 1) - x - 40.0), x + 24, y + h - 18, 12, Color("#9a9080"), 0, Assets.font)

# a left / right press on a focused row; true when it changed something (the focus then stays put)
func adjust(ui, r: Dictionary, dir: int) -> bool:
	if not r.has("set"): return false
	var k: String = r.set
	match r.type:
		"slider": Settings.set_value(k, Settings.get_value(k) + dir * SLIDER_STEP)
		"toggle": Settings.set_value(k, dir > 0)
		"cycle": Settings.set_value(k, Settings.get_value(k) + dir)
		_: return false
	Sfx.sfx("ui")
	return true

func set_from_x(r: Dictionary, px: float) -> void:
	Settings.set_value(r.set, int(round(clampf((px - r.x) / r.w, 0.0, 1.0) * 100.0)))

# tap (tap = position in UI coordinates) or A on a focused row (tap = null)
func activate(ui, r: Dictionary, tap = null) -> void:
	if r.has("act"):
		Sfx.sfx("ui")
		if armed != r.act:
			armed = r.act; armed_until = Time.get_ticks_msec() + 3000
			return
		armed = ""
		Settings.save()
		if r.act == "title":
			ui.menu = false
			ui.g.get_parent().set_state("title")
		elif r.act == "quit": ui.get_tree().quit()
		return
	if not r.has("set"): return
	var k: String = r.set
	match r.type:
		"toggle": Settings.set_value(k, not Settings.get_value(k)); Sfx.sfx("ui")
		"cycle":
			var mid: float = r.x + r.w - 104.0   # centre of the value; a tap on the left arrow goes back, anywhere else forward
			var d := -1 if tap != null and tap.x > mid - 100.0 and tap.x < mid else 1
			Settings.set_value(k, Settings.get_value(k) + d); Sfx.sfx("ui")
		"step": Settings.set_value(k, Settings.get_value(k) + int(r.step)); Sfx.sfx("ui")
		"track":
			if tap != null: set_from_x(r, tap.x); Sfx.sfx("ui")
