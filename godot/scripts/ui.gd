# UI: HUD (minimap, quest list, bars), touch buttons (one glowing at a time), dialogue, verse banner, shop, pause menu.
extends Control

var g  # Game
var dialog = null
var banner = null
var shop = null
var menu = false
var menu_page = 0
var menu_focus := ""       # id of the menu rect the keyboard / pad cursor is on ("" = pick the page default)
var menu_rects_page := -1  # the page menu_rects was last built for
var menu_drag := ""        # id of the slider track being dragged
var settings_menu := SettingsMenu.new()
var choice = null          # {"title", "options": [{"label", "fn"}], "sel", "rects"}
var chapter_banner = null  # {"text", "t"}
var shop_lv = 1
var glow = null
var toasts = []
var menu_rects = []
var mini: ImageTexture
var vw = 1280.0
var vh = 600.0

# shop goods by chapter: food gets dearer, each market has its own talismans
const TALIS_SHOP := {2: ["hwa", "su"], 3: ["heung", "myo"], 4: ["geum"], 5: ["yong"], 6: ["cheon"]}
const TALIS_PRICE := {"hwa": 260, "su": 220, "heung": 420, "myo": 480, "geum": 820, "yong": 900, "cheon": 1200}
func goods() -> Array:
	var k: int = shop_lv
	var out = [{"k": "yakgwa", "name": "약과", "desc": "체력 40% 회복", "price": 20 * k}, {"k": "sikhye", "name": "식혜", "desc": "기 60 회복", "price": 15 * k}]
	for t in TALIS_SHOP.get(k, []):
		if not g.player.talis.has(t): out.append({"t": t, "name": Ent.TALIS[t].name, "desc": Ent.TALIS[t].desc, "price": TALIS_PRICE[t]})
	return out
const SPEAKER := {"용왕": "yongwang", "처용": "cheoyong", "화랑": "hwarang", "할미": "halmi", "상인": "merchant", "도사": "dosa", "아이": "child",
	"누렁이": "dog", "앓는 사람": "sick", "아내": "wife", "왕": "king", "스님": "monk", "산신령": "sansin", "아낙": "villager",
	"도깨비 대장": "dokchief", "구미호": "gumiho", "이무기": "imugi", "역신": "yeoksin"}
const GOLD := Color("#ffd27a")
const PAPER := Color("#f3e6c4")

func modal() -> bool: return dialog != null or shop != null or menu or choice != null

# who is talking: the fixed cast, then NPCs on this map, then the boss
func speaker_sprite(sp: String) -> String:
	if SPEAKER.has(sp): return SPEAKER[sp]
	for n in g.npcs:
		if n.name == sp: return n.sprite
	for e in g.enemies:
		if e.def.name == sp: return e.sprite
	return ""

func is_touch() -> bool:
	return Inp.last_touch or (DisplayServer.is_touchscreen_available() and not Inp.any_key) or G.has("touch")

# ---------- text helpers ----------
func txt(s: String, x: float, y: float, size: int, col: Color, align := 0, font: Font = null, outline := 0) -> void:
	var f: Font = font if font else Assets.font_bold
	var w = f.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	var px = x - (w / 2 if align == 1 else (w if align == 2 else 0.0))
	if outline > 0: draw_string_outline(f, Vector2(px, y), s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, outline, Color(0.04, 0.03, 0.06, 0.9 * col.a))
	draw_string(f, Vector2(px, y), s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, col)

func tw(s: String, size: int, font: Font = null) -> float:
	return (font if font else Assets.font_bold).get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x

func wrap_text(s: String, size: int, max_w: float, font: Font = null) -> Array:
	var out = []; var line = ""
	for ch in s:
		if tw(line + ch, size, font) > max_w and line != "":
			out.append(line); line = ch if ch != " " else ""
		else: line += ch
	out.append(line)
	return out

func fit(s: String, size: int, w: float) -> String:
	if tw(s, size) <= w: return s
	while s.length() > 2 and tw(s + "…", size) > w: s = s.substr(0, s.length() - 1)
	return s + "…"

func bar(x: float, y: float, w: float, h: float, v: float, mx: float, col: Color, back := Color(0.04, 0.035, 0.05, 0.78)) -> void:
	# ink well with a hairline of old gold, a lacquer fill that darkens toward its lower edge
	draw_rect(Rect2(x - 2, y - 2, w + 4, h + 4), back)
	if h >= 5: draw_rect(Rect2(x - 2, y - 2, w + 4, h + 4), Color(0.72, 0.6, 0.38, 0.55), false, 1)
	var fw: float = max(0.0, w * v / mx)
	draw_rect(Rect2(x, y, fw, h), col)
	draw_rect(Rect2(x, y + h * 0.55, fw, h * 0.45), Color(0, 0, 0, 0.28))
	draw_rect(Rect2(x, y, fw, 1), Color(1, 0.95, 0.85, 0.22))

func plate(x: float, y: float, w: float, h: float, a := 0.55) -> void:
	var sb = StyleBoxFlat.new()
	sb.bg_color = Color(0.055, 0.047, 0.08, a)
	sb.set_corner_radius_all(int(min(8.0, h / 2)))
	draw_style_box(sb, Rect2(x, y, w, h))

func panel(x: float, y: float, w: float, h: float, a := 0.85) -> void:
	draw_rect(Rect2(x, y, w, h), Color(0.05, 0.055, 0.12, a))
	draw_rect(Rect2(x + 1, y + 1, w - 2, h - 2), Color(0.84, 0.7, 0.43, 0.85), false, 2)
	draw_rect(Rect2(x + 5, y + 5, w - 10, h - 10), Color(0.84, 0.7, 0.43, 0.35), false, 1)

func ring(x: float, y: float, r: float, lit: bool) -> void:
	draw_circle(Vector2(x, y), r, Color(0.08, 0.07, 0.11, 0.9))
	draw_circle(Vector2(x - r * 0.15, y - r * 0.2), r * 0.7, Color(0.27, 0.25, 0.33, 0.35))
	draw_arc(Vector2(x, y), r - 1, 0, TAU, 40, Color("#ffe2a0") if lit else Color("#8a7652"), 2.5, true)
	draw_arc(Vector2(x, y), r - 4, PI * 1.1, PI * 1.9, 16, Color(1, 0.94, 0.78, 0.25), 1, true)

# ---------- dialogue ----------
# lines: [speaker, text, callable?]; "@" is narration, "@verse" shows a verse banner (text = verse number)
func say(lines: Array, on_done = null) -> void:
	dialog = {"lines": lines, "i": -1, "done": on_done, "t": 0.0, "shown": 0.0, "wait": false}
	next_line()

func next_line() -> void:
	var d = dialog
	d.i += 1
	if d.i >= d.lines.size():
		dialog = null
		if d.done is Callable and d.done.is_valid(): d.done.call()
		return
	var l: Array = d.lines[d.i]
	d.t = 0.0; d.shown = 0.0
	if l[0] == "@verse":
		g.flags["verse%d" % l[1]] = true
		banner = {"n": l[1], "t": 0.0}
		Sfx.sfx("verse")
		d.wait = true
		return
	if l[0] == "@hyangga":
		g.flags["hy_" + l[1]] = true
		banner = {"hy": l[1], "t": 0.0}
		Sfx.sfx("verse")
		d.wait = true
		return
	d.wait = false
	if l.size() > 2 and l[2] is Callable: l[2].call()

func update_dialog(dt: float) -> void:
	var d = dialog
	if d == null: return
	var conf = Inp.hit("confirm") or Inp.hit("interact") or Inp.hit("attack") or Inp.hit("tap")
	if d.wait:
		if banner and banner.t > 1.2 and conf: banner.t = max(banner.t, 3.2)
		if banner == null: next_line()
		return
	var text: String = d.lines[d.i][1]
	var before = int(d.shown)
	d.shown = min(float(text.length()), d.shown + dt * 38)
	if int(d.shown) != before and int(d.shown) % 3 == 0 and d.lines[d.i][0] != "@": Sfx.sfx("talk")
	d.t += dt
	if conf and d.t > 0.15:
		if d.shown < text.length(): d.shown = text.length()
		else: next_line()

# ---------- shop ----------
func open_shop(lv := 1) -> void:
	shop_lv = lv
	shop = {"sel": 0, "t": 0.0, "cool": 0.0, "rects": []}

# a list of choices (the post station); options: [{"label", "fn"}]
func choose(title: String, options: Array) -> void:
	choice = {"title": title, "options": options, "sel": 0, "t": 0.0, "cool": 0.0, "rects": []}

func update_choice(dt: float) -> void:
	var c = choice
	c.t += dt; c.cool -= dt
	var pick = func(i: int):
		choice = null
		var fn: Callable = c.options[i].fn
		fn.call()
	if Inp.hit("menu"): choice = null; return
	var mv = Inp.move()
	if abs(mv.y) > 0.5 and c.cool <= 0:
		c.sel = posmod(c.sel + (1 if mv.y > 0 else -1), c.options.size()); c.cool = 0.2; Sfx.sfx("ui")
	if Inp.hit("tap"):
		for r in c.rects:
			if hit_rect(r): pick.call(r.i); return
	if c.t > 0.25 and (Inp.hit("confirm") or Inp.hit("interact") or Inp.hit("attack")): pick.call(c.sel)

func draw_choice() -> void:
	var c = choice
	var n: int = c.options.size()
	var w = 340.0; var h = 70.0 + n * 50; var x = vw / 2 - w / 2; var y = vh / 2 - h / 2
	panel(x, y, w, h, 0.94)
	txt(c.title, vw / 2, y + 36, 19, GOLD, 1, Assets.font_black)
	c.rects = []
	for i in n:
		var ry = y + 56 + i * 50; var rx = x + 20; var rw = w - 40
		c.rects.append({"x": rx, "y": ry, "w": rw, "h": 42, "i": i})
		draw_rect(Rect2(rx, ry, rw, 42), Color(0.84, 0.7, 0.43, 0.28) if c.sel == i else Color(1, 1, 1, 0.05))
		txt(c.options[i].label, rx + rw / 2, ry + 27, 17, PAPER, 1)

func hit_rect(r: Dictionary) -> bool:
	var p = Inp.tap_pos
	return p != null and p.x >= r.x and p.x <= r.x + r.w and p.y >= r.y and p.y <= r.y + r.h

func toast(s: String) -> void: toasts.append({"s": s, "t": 0.0})

func update_shop(dt: float) -> void:
	var s = shop; var p = g.player
	s.t += dt; s.cool -= dt
	if Inp.hit("menu"): shop = null; return
	var mv = Inp.move()
	var list = goods()
	if abs(mv.y) > 0.5 and s.cool <= 0:
		s.sel = posmod(s.sel + (1 if mv.y > 0 else -1), list.size() + 1); s.cool = 0.2; Sfx.sfx("ui")
	var buy = func(i: int):
		if i >= list.size(): shop = null; return
		var it: Dictionary = list[i]
		if p.coins < it.price: toast("엽전이 모자라오"); return
		p.coins -= it.price; Sfx.sfx("coin")
		if it.has("t"): g.add_talis(it.t)
		else: p.items[it.k] += 1; toast(it.name + " 하나 샀소")
	if Inp.hit("tap"):
		for r in s.rects:
			if hit_rect(r): s.sel = r.i; buy.call(r.i); return
	if s.t > 0.2 and (Inp.hit("confirm") or Inp.hit("interact") or Inp.hit("attack")): buy.call(s.sel)

# ---------- pause menu ----------
# Pages: 0 body and masks, 1 talismans, 2 settings. Mouse / touch tap the rects; keyboard and pad move a focus cursor
# (nav_* presses, LB/RB = skill1/2 switch page, A/Enter use, B/Esc/Start close).
func update_menu() -> void:
	if Inp.hit("menu"): menu = false; return
	if Inp.hit("tap"):
		menu_drag = ""
		for r in menu_rects:
			if hit_rect(r):
				if r.get("type", "") == "track": menu_drag = r.id
				_menu_activate(r, Inp.tap_pos)
	elif menu_drag != "" and Inp.ptr_down:
		for r in menu_rects:
			if r.get("id", "") == menu_drag: settings_menu.set_from_x(r, Inp.ptr_pos.x)
	if not Inp.ptr_down: menu_drag = ""
	if menu_rects_page == menu_page and _menu_focus_rect() == null: _menu_default_focus()
	if Inp.hit("skill1") and menu_page > 0: menu_page -= 1; menu_focus = ""; Sfx.sfx("ui")
	if Inp.hit("skill2") and menu_page < 2: menu_page += 1; menu_focus = ""; Sfx.sfx("ui")
	for d in [["up", Vector2i(0, -1)], ["down", Vector2i(0, 1)], ["left", Vector2i(-1, 0)], ["right", Vector2i(1, 0)]]:
		if Inp.nav_hit(d[0]): _menu_nav(d[1])
	if Inp.hit("confirm") and not Inp.hit("tap"):
		var fr = _menu_focus_rect()
		if fr != null: _menu_activate(fr, null)
	if Inp.hit("mask"): g.player.cycle_mask()

func _menu_activate(r: Dictionary, tap) -> void:
	var p = g.player
	if r.has("page"): menu_page = r.page; menu_focus = r.get("id", ""); Sfx.sfx("ui")
	if r.has("talis"):
		var i: int = r.talis
		if p.equip.has(i): p.equip.erase(i)
		elif p.equip.size() < 2: p.equip.append(i)
		else: p.equip[0] = p.equip[1]; p.equip[1] = i
		Sfx.sfx("ui")
	if r.has("mask"): p.mask = r.mask; Sfx.sfx("ui")
	if r.has("close"): menu = false
	if r.has("sound"): Sfx.toggle()
	if r.has("set") or r.has("act"): settings_menu.activate(self, r, tap)

func _menu_focus_rect():
	for r in menu_rects:
		if r.get("id", "") == menu_focus and not r.get("nofocus", false): return r
	return null

func _menu_default_focus() -> void:
	menu_focus = "close"
	for r in menu_rects:
		if r.get("def", false): menu_focus = r.id; return

# slider / toggle rows take left-right as a value change; otherwise jump to the nearest rect in that direction
func _menu_nav(d: Vector2i) -> void:
	var fr = _menu_focus_rect()
	if fr == null: _menu_default_focus(); return
	if d.x != 0 and settings_menu.adjust(self, fr, d.x): return
	var c := Vector2(fr.x + fr.w / 2, fr.y + fr.h / 2)
	var best := ""
	var best_cost := INF
	for r in menu_rects:
		if not r.has("id") or r.get("nofocus", false) or r.id == fr.id: continue
		var o := Vector2(r.x + r.w / 2, r.y + r.h / 2) - c
		var along := o.x * d.x + o.y * d.y
		if along < 2.0: continue
		var cost := along + (absf(o.x * d.y) + absf(o.y * d.x)) * 2.5
		if cost < best_cost: best_cost = cost; best = r.id
	if best != "": menu_focus = best; Sfx.sfx("ui")

func _draw_menu_focus() -> void:
	if is_touch(): return
	var fr = _menu_focus_rect()
	if fr == null: return
	var a := 0.65 + 0.3 * sin(g.time * 7.0)
	draw_rect(Rect2(fr.x - 2, fr.y - 2, fr.w + 4, fr.h + 4), Color(1.0, 0.85, 0.45, a), false, 2.0)

# a key letter, or the pad button when a gamepad is in use
func _kl(action: String, key: String) -> String:
	return Inp.PAD_LABEL.get(action, key) if Inp.pad_used else key

# ---------- buttons ----------
func layout_buttons() -> Array:
	var p = g.player; var f: Dictionary = g.flags
	var B = []
	var bx = vw - 70; var by = vh - 70
	if f.get("has_attack", false):
		B.append({"action": "attack", "x": bx, "y": by, "r": 46.0, "icon": "attack", "main": true})
		B.append({"action": "roll", "x": bx - 4, "y": by - 112, "r": 24.0, "icon": "roll", "key": "K"})
	var cols = {"skill1": Color("#58d0ff"), "skill2": Color("#ff7ad0"), "skill3": Color("#3a9cff")}
	for s in [["skill1", bx - 104, by + 6, "U"], ["skill2", bx - 92, by - 62, "I"], ["skill3", bx - 52, by - 104, "O"]]:
		if p.skills.get(s[0], false):
			B.append({"action": s[0], "x": s[1], "y": s[2], "r": 27.0, "icon": s[0], "key": s[3], "cd": p.cd[s[0]] / Ent.SKILLS[s[0]].cd, "gi": Ent.SKILLS[s[0]].gi, "color": cols[s[0]]})
	if f.get("has_ult", false): B.append({"action": "ult", "x": bx - 170, "y": by + 4, "r": 31.0, "icon": "ult", "key": "L", "fill": p.heung / 100.0, "color": Color("#ffc85a")})
	if g.interact_target: B.append({"action": "interact", "x": bx - 150, "y": by - 92, "r": 30.0, "label": g.interact_target.label, "icon": "talk", "key": "E"})
	B.append({"action": "menu", "x": vw - 28, "y": 28, "r": 19.0, "icon": "menu"})
	if p.masks.size() > 1: B.append({"action": "mask", "x": vw - 72, "y": 28, "r": 19.0, "icon": "mask", "key": "M"})
	var qx = vw / 2 + 60; var qy = vh - 26
	B.append({"action": "item1", "x": qx, "y": qy, "r": 18.0, "icon": "yakgwa", "count": p.items.yakgwa, "slot": true, "key": "1"})
	B.append({"action": "item2", "x": qx + 44, "y": qy, "r": 18.0, "icon": "sikhye", "count": p.items.sikhye, "slot": true, "key": "2"})
	return B

func icon(name: String, x: float, y: float, s: float) -> void:
	var k = s / 20.0
	var c = PAPER
	var P = func(px, py): return Vector2(x + px * k, y + py * k)
	match name:
		"attack":
			draw_polyline(_curve(P.call(-10, 8), P.call(0, -16), P.call(12, -6)), c, 2.5, true)
			draw_polyline(_curve(P.call(-6, 10), P.call(4, -8), P.call(12, 2)), c, 2.5, true)
		"roll":
			draw_arc(Vector2(x, y), 9 * k, 0.4, PI * 1.8, 20, c, 2.5, true)
			draw_colored_polygon(PackedVector2Array([P.call(9, -6), P.call(9, 2), P.call(3, -2)]), c)
		"skill1":
			for i in 3: draw_arc(P.call(-8, 0), (6 + i * 6) * k, -0.7, 0.7, 10, c, 2.5, true)
		"skill2":
			for i in 3: draw_arc(Vector2(x, y), (4 + i * 4) * k, i, i + 4.2, 16, c, 2.5, true)
		"skill3":
			draw_polyline(_curve(P.call(-12, 4), P.call(-6, -8), P.call(0, 4)), c, 2.5, true)
			draw_polyline(_curve(P.call(0, 4), P.call(6, -8), P.call(12, 4)), c, 2.5, true)
			draw_polyline(_curve(P.call(-12, 10), P.call(0, 2), P.call(12, 10)), c, 2.5, true)
		"ult":
			draw_arc(Vector2(x, y), 10 * k, 0, TAU, 24, c, 2.5, true)
			draw_circle(P.call(-4, -3), 1.6 * k, c); draw_circle(P.call(4, -3), 1.6 * k, c)
			draw_arc(P.call(0, 2), 5 * k, 0.3, PI - 0.3, 10, c, 2.5, true)
		"talk":
			Fx.ellipse(self, P.call(0, -2), 11 * k, 8 * k, c, false, 2.5)
			draw_colored_polygon(PackedVector2Array([P.call(-4, 5), P.call(-8, 11), P.call(1, 6)]), c)
		"menu":
			for yy in [-6, 0, 6]: draw_rect(Rect2(x - 9 * k, y + (yy - 1.5) * k, 18 * k, 3 * k), c)
		"mask":
			Fx.ellipse(self, Vector2(x, y), 9 * k, 11 * k, c, false, 2.5)
			draw_circle(P.call(-4, 3), 2.5 * k, Color("#ff6a5a")); draw_circle(P.call(4, 3), 2.5 * k, Color("#ff6a5a"))
		"yakgwa":
			draw_circle(Vector2(x, y), 9 * k, Color("#c9822a")); draw_circle(Vector2(x, y), 3 * k, Color("#7a4a1a"))
		"sikhye":
			draw_rect(Rect2(x - 8 * k, y - 4 * k, 16 * k, 12 * k), Color("#e8dcc0")); draw_rect(Rect2(x - 8 * k, y - 4 * k, 16 * k, 3 * k), Color("#c9b48a"))

func _curve(a: Vector2, b: Vector2, c: Vector2) -> PackedVector2Array:
	var out = PackedVector2Array()
	for i in 11:
		var t = i / 10.0
		out.append(a.lerp(b, t).lerp(b.lerp(c, t), t))
	return out

func draw_buttons() -> void:
	var B = layout_buttons()
	Inp.buttons = [] if Inp.pad_used else B   # with a gamepad the buttons are only the cooldown / ult / item readout, no touch areas
	var touch = is_touch()
	for b in B:
		var lit: bool = glow == b.action
		if lit:
			var pulse = 0.5 + 0.5 * sin(g.time * 6)
			draw_texture_rect(g.dot, Rect2(b.x - b.r * 1.9, b.y - b.r * 1.9, b.r * 3.8, b.r * 3.8), false, Color(1, 0.86, 0.55, 0.5 + pulse * 0.4))
		if b.get("slot", false):
			draw_rect(Rect2(b.x - b.r, b.y - b.r, b.r * 2, b.r * 2), Color(0.06, 0.055, 0.086, 0.75))
			draw_rect(Rect2(b.x - b.r, b.y - b.r, b.r * 2, b.r * 2), Color("#ffe2a0") if lit else Color(0.59, 0.51, 0.35, 0.8), false, 1.5)
		else: ring(b.x, b.y, b.r, lit)
		if b.has("color"):
			var c: Color = b.color; c.a = 0.55
			draw_texture_rect(g.dot, Rect2(b.x - b.r * 0.9, b.y - b.r * 0.9, b.r * 1.8, b.r * 1.8), false, c)
		if b.has("fill"):
			draw_arc(Vector2(b.x, b.y), b.r + 3, -PI / 2, -PI / 2 + TAU * b.fill, 40, GOLD if b.fill >= 1 else Color("#ff9ad0"), 4, true)
		if b.get("cd", 0.0) > 0:
			draw_circle(Vector2(b.x, b.y), b.r - 2, Color(0, 0, 0, 0.6))
			txt("%.1f" % (b.cd * Ent.SKILLS[b.action].cd), b.x, b.y + 5, 13, Color.WHITE, 1)
		else: icon(b.icon, b.x, b.y, b.r * (0.62 if b.get("main", false) else 0.58))
		if b.has("gi") and g.player.gi < b.gi: draw_circle(Vector2(b.x, b.y), b.r - 2, Color(0, 0.04, 0.16, 0.55))
		if b.has("label"): txt(b.label, b.x, b.y + b.r + 13, 11, PAPER, 1, null, 3)
		if not touch:
			var kt: String = ""
			if Inp.pad_used: kt = Inp.PAD_LABEL.get(b.action, "") if b.action != "menu" and b.action != "mask" else ""
			else: kt = b.get("key", "")
			if kt != "": txt(kt, b.x + b.r * 0.72, b.y + (b.r * 0.9 if not (b.get("slot", false) and Inp.pad_used) else -b.r * 0.35), 10, Color("#d8ccb0"), 1, null, 3)
		if b.has("count"): txt(str(b.count), b.x + b.r - 2, b.y + b.r - 3, 12, Color.WHITE, 2, null, 3)
	var st: Dictionary = Inp.stick
	if touch and st.active:
		ring(st.ox, st.oy, 48, false)
		var d = Vector2(st.x - st.ox, st.y - st.oy)
		if d.length() > 46: d = d.normalized() * 46
		draw_circle(Vector2(st.ox, st.oy) + d, 20, Color(PAPER, 0.6))

# ---------- HUD ----------
func draw_hud() -> void:
	var p = g.player; var f: Dictionary = g.flags
	draw_minimap()
	# currency strip
	var items = [["엽전", str(p.coins), Color("#ffd25a")], ["구절", "%d/8" % g.verse_count(), Color("#bfe6ff")]]
	if f.get("ch1_done", false): items.append(["향가", "%d/5" % g.story.hyangga_count(), Color("#ffb0e0")])
	if p.mask != "": items.append(["탈", p.m().name, p.m().color])
	var total = 0.0
	for it in items: total += tw(it[0] + " " + it[1], 13) + 28
	var x = vw / 2 - total / 2
	plate(x - 6, 8, total + 12, 26, 0.5)
	for it in items:
		draw_circle(Vector2(x + 8, 21), 5, it[2])
		txt(it[0] + " ", x + 18, 26, 13, Color("#cdbf9f"), 0, Assets.font_serif, 2)
		txt(it[1], x + 18 + tw(it[0] + " ", 13), 26, 13, Color.WHITE, 0, null, 2)
		x += tw(it[0] + " " + it[1], 13) + 28
	# boss bar
	if g.boss is Object and not g.boss.dead:
		var b = g.boss
		var w: float = min(420.0, vw - 360); var x0 = vw / 2 - w / 2; var y0 = 44.0
		plate(x0 - 8, y0 - 4, w + 16, 34, 0.55)
		txt(("[처용가로 굴복시키시오] " if b.ult_vulnerable else "") + b.def.name, vw / 2, y0 + 11, 15, Color("#e8c9a8"), 1, Assets.font_serif_bold, 3)
		bar(x0, y0 + 17, w, 7, b.hp, b.max_hp, GOLD if b.ult_vulnerable else Color("#8f2430"))
	# quest tracker
	var ob: Dictionary = g.story.objective()
	var parts: PackedStringArray = ob.text.split(" — ")
	var rows = [parts[0]]
	var side_rows = side_lines()
	if parts.size() > 1: rows.append_array(parts[1].split(" · "))
	var qw: float = min(250.0, vw * 0.26); var qx = vw - qw - 12; var qy = 60.0
	var main_n := rows.size()
	rows.append_array(side_rows)
	plate(qx, qy, qw, 14 + rows.size() * 22, 0.5)
	for i in rows.size():
		var y = qy + 22 + i * 22
		if i >= main_n:
			txt(fit(rows[i], 12, qw - 30), qx + 24, y, 12, Color("#b9a8d8"), 0, Assets.font_serif, 2)
			continue
		if i == 0:
			draw_rect(Rect2(qx + 11, y - 7, 6, 6), Color("#c9a45c"))
			txt(fit(rows[i], 14, qw - 30), qx + 24, y, 14, Color("#ead6a8"), 0, Assets.font_serif_bold, 2)
		else: txt(fit(rows[i], 12, qw - 30), qx + 24, y, 12, Color("#d9d0bf"), 0, Assets.font_serif, 2)
	# health, gi, heung, exp
	var bw: float = min(360.0, vw * 0.36); var bx = vw / 2 - bw / 2; var by = vh - 62
	txt("Lv.%d" % p.lvl, bx - 30, by + 12, 13, Color("#ead6a8"), 1, Assets.font_serif_bold, 2)
	bar(bx, by, bw, 10, p.hp, p.max_hp, Color("#a8343a"))
	txt("%d / %d" % [ceil(p.hp), p.max_hp], vw / 2, by + 9, 10, Color.WHITE, 1, null, 2)
	bar(bx, by + 15, bw, 5, p.gi, p.max_gi, Color("#3d78a8"))
	if f.get("has_ult", false): bar(bx, by + 24, bw, 3, p.heung, 100, GOLD if p.heung >= 100 else Color("#b86a88"), Color(0.04, 0.04, 0.06, 0.6))
	bar(0, vh - 3, vw, 3, p.xp, p.exp_need(), Color("#d8c070"), Color(0, 0, 0, 0.4))
	# zone banner
	if g.zone_banner and g.zone_banner.t < 3:
		var k: float = g.zone_banner.t
		var a: float = min(1.0, min(k * 2, (3 - k) * 1.5))
		txt(g.zone_banner.name, vw / 2, vh * 0.28, 30, Color(1, 0.96, 0.86, a), 1, Assets.font_black, 5)
		draw_rect(Rect2(vw / 2 - 90, vh * 0.28 + 12, 180, 2), Color(1, 0.86, 0.6, 0.8 * a))
	# toasts
	for i in range(toasts.size() - 1, -1, -1):
		var t = toasts[i]
		var a: float = min(1.0, (2 - t.t) * 2)
		txt(t.s, vw / 2, vh * 0.62 - i * 22, 15, Color(1, 0.89, 0.63, a), 1, null, 3)

# active side quests (at most two shown)
func side_lines() -> Array:
	var c = g.story.chapter()
	var out = []
	if c == null: return out
	for q in c.sides():
		if c.side_state(q) != "on": continue
		var pr: int = c.side_progress(q)
		out.append("[부탁] %s %s" % [q.name, "— 돌아가 알리시오" if pr >= q.count else "(%d/%d)" % [pr, q.count]])
		if out.size() >= 2: break
	return out

func draw_minimap() -> void:
	var W: World = G.world
	if mini == null:
		var img = Image.create(W.W, W.H, false, Image.FORMAT_RGBA8)
		var cols = ["3a8ab0", "d8c088", "6a9a48", "a07a50", "b8a078", "3a5a32", "3a7068", "6a6058", "c0a070"]
		for y in W.H:
			for x in W.W:
				var t = W.terrain_at(x * 32 + 16, y * 32 + 16)
				var blocked = W.solid_at(x * 32 + 16, y * 32 + 16) and t != 0 and t != 6
				img.set_pixel(x, y, Color("#2e4228") if blocked else Color("#" + cols[t]))
		mini = ImageTexture.create_from_image(img)
	var R = 44.0 if vw < 700 else 58.0
	var c = Vector2(14 + R, 30 + R)
	var p = g.player
	draw_colored_polygon(PackedVector2Array([Vector2(14, 11), Vector2(22, 16), Vector2(14, 21)]), Color("#6fcf4a"))
	txt(g.zone.name if g.zone else "", 26, 21, 12, Color.WHITE, 0, null, 2)
	# the map texture is drawn in a circle with a polygon UV fan
	var s = 2.6
	var pts = PackedVector2Array(); var uvs = PackedVector2Array()
	for i in 41:
		var a = i / 40.0 * TAU
		var v = c + Vector2(cos(a), sin(a)) * R
		pts.append(v)
		uvs.append(Vector2((p.x / 32.0 + (v.x - c.x) / s) / W.W, (p.y / 32.0 + (v.y - c.y) / s) / W.H))
	draw_colored_polygon(pts, Color("#1a2418"))
	draw_polygon(pts, PackedColorArray(), uvs, mini)
	for n in g.npcs:
		if n.hidden: continue
		var q = c + Vector2(n.x - p.x, n.y - p.y) / 32.0 * s
		if q.distance_to(c) < R - 2: draw_rect(Rect2(q - Vector2(1.5, 1.5), Vector2(3, 3)), Color("#ffd25a"))
	for e in g.enemies:
		if e.dead or e.state == "kneel": continue
		var q = c + Vector2(e.x - p.x, e.y - p.y) / 32.0 * s
		var boss: bool = e.def.get("boss", false)
		if q.distance_to(c) < R - 2: draw_rect(Rect2(q - Vector2(2, 2), Vector2(4, 4) if boss else Vector2(3, 3)), Color("#ff3a3a") if boss else Color("#ff7a7a"))
	var ob: Dictionary = g.story.objective()
	if ob.target != null:
		var q: Vector2 = c + (ob.target - Vector2(p.x, p.y)) / 32.0 * s
		if q.distance_to(c) > R - 6: q = c + (q - c).normalized() * (R - 6)
		draw_circle(q, 4, Color("#ffcf5a"))
	var rot: float = p.face + PI / 2
	var tri = PackedVector2Array([Vector2(0, -6), Vector2(4.5, 5), Vector2(-4.5, 5)])
	for i in 3: tri[i] = c + tri[i].rotated(rot)
	draw_colored_polygon(tri, Color.WHITE)
	draw_arc(c, R + 1, 0, TAU, 48, Color("#6a5838"), 4, true)
	draw_arc(c, R + 3, 0, TAU, 48, Color("#d8b878"), 1.5, true)

func portrait(sprite: String, x: float, y: float, size: float) -> void:
	if not Assets.chars.has(sprite): return
	var c: Dictionary = Assets.chars[sprite]
	var f = Assets.frame(sprite, "idle", "south", 0)
	var crop: float = max(28.0, round((c.foot - c.top) * 0.5))
	var src = Rect2(f.src.position.x + c.cx - crop / 2, f.src.position.y + c.top - 2, crop, crop)
	draw_texture_rect_region(c.tex, Rect2(x, y, size, size), src)

func draw_dialog() -> void:
	var d = dialog
	if d == null or d.wait: return
	var l: Array = d.lines[d.i]
	var sp: String = l[0]; var text: String = l[1]
	var w: float = min(820.0, vw - 40); var h = 120.0; var x = (vw - w) / 2; var y = vh - h - 16
	panel(x, y, w, h, 0.9)
	var tx = x + 22
	if sp != "@":
		var spr := speaker_sprite(sp)
		if spr != "" and Assets.chars.has(spr):
			draw_rect(Rect2(x + 14, y + 14, 92, 92), Color(0.16, 0.17, 0.27, 0.9))
			portrait(spr, x + 16, y + 16, 88)
			draw_rect(Rect2(x + 14, y + 14, 92, 92), Color(0.84, 0.7, 0.43, 0.7), false, 1)
			tx = x + 122
		txt(sp, tx, y + 34, 17, GOLD, 0, Assets.font_black)
	var shown = text.substr(0, int(d.shown))
	var narr = sp == "@"
	var lines = wrap_text(shown, 17, w - (tx - x) - 26, Assets.font)
	for i in lines.size():
		if narr: txt(lines[i], x + w / 2, y + 56 + i * 24, 18, Color("#bfe6ff"), 1, Assets.font)
		else: txt(lines[i], tx, y + 62 + i * 24, 17, PAPER, 0, Assets.font)
	if d.shown >= text.length() and int(g.time * 2.5) % 2 == 0:
		draw_colored_polygon(PackedVector2Array([Vector2(x + w - 26, y + h - 22), Vector2(x + w - 16, y + h - 22), Vector2(x + w - 21, y + h - 15)]), GOLD)

func draw_banner(dt: float) -> void:
	var b = banner
	if b == null: return
	b.t += dt
	var D = 4.2
	if b.t > D: banner = null; return
	var a: float = min(1.0, min(b.t * 1.5, (D - b.t) * 1.5))
	draw_rect(Rect2(0, 0, vw, vh), Color(0.016, 0.024, 0.063, 0.6 * a))
	var text: String
	if b.has("hy"):
		var H: Dictionary = Story.HYANGGA[b.hy]
		txt("향가 · %s (%s)" % [H.name, H.by], vw / 2, vh / 2 - 46, 16, Color(0.84, 0.7, 0.43, a), 1)
		text = H.line
		txt(H.effect, vw / 2, vh / 2 + 64, 15, Color(0.75, 0.9, 1.0, a * min(1.0, max(0.0, b.t - 1.0))), 1, Assets.font)
	else:
		txt("처용가 · 제" + "一二三四五六七八"[b.n - 1] + "구", vw / 2, vh / 2 - 46, 16, Color(0.84, 0.7, 0.43, a), 1)
		text = Story.VERSES[b.n - 1]
	var shown = text.substr(0, int(ceil(min(1.0, b.t / 1.2) * text.length())))
	var fs := 40 if text.length() < 14 else 28
	txt(shown, vw / 2, vh / 2 + 14, fs, Color(0.63, 0.86, 1, 0.35 * a), 1, Assets.font_black)
	txt(shown, vw / 2, vh / 2 + 12, fs, Color(0.97, 0.93, 0.82, a), 1, Assets.font_black)
	var k: float = min(1.0, b.t)
	draw_rect(Rect2(vw / 2 - 160 * k, vh / 2 + 34, 320 * k, 2), Color(0.84, 0.7, 0.43, 0.8 * a))

func draw_shop() -> void:
	var s = shop; var p = g.player
	var list = goods()
	var w = 400.0; var h = 74.0 + (list.size() + 1) * 52; var x = vw / 2 - w / 2; var y = vh / 2 - h / 2
	panel(x, y, w, h, 0.94)
	txt("상인의 좌판", vw / 2, y + 34, 20, GOLD, 1, Assets.font_black)
	txt("가진 엽전 %d냥" % p.coins, vw / 2, y + 56, 13, Color("#d8d0c0"), 1, Assets.font)
	s.rects = []
	var all = list.duplicate(); all.append({"name": "그만 보겠소", "desc": ""})
	for i in all.size():
		var it: Dictionary = all[i]
		var ry = y + 70 + i * 52; var rx = x + 20; var rw = w - 40
		s.rects.append({"x": rx, "y": ry, "w": rw, "h": 44, "i": i})
		draw_rect(Rect2(rx, ry, rw, 44), Color(0.84, 0.7, 0.43, 0.25) if s.sel == i else Color(1, 1, 1, 0.05))
		var off = 16.0
		if it.has("k"): icon(it.k, rx + 24, ry + 22, 14); off = 46
		txt(it.name, rx + off, ry + 20, 16, PAPER)
		if it.has("k"):
			txt("%s  (가진 것 %d)" % [it.desc, p.items[it.k]], rx + off, ry + 37, 12, Color("#b8b0a0"), 0, Assets.font)
		elif it.has("t"):
			txt("부적 · " + it.desc, rx + off, ry + 37, 12, Color("#c8b0ff"), 0, Assets.font)
		if it.has("price"):
			txt("%d냥" % it.price, rx + rw - 12, ry + 28, 15, GOLD if p.coins >= it.price else Color("#888866"), 2)

func draw_menu() -> void:
	var p = g.player; var f: Dictionary = g.flags
	draw_rect(Rect2(0, 0, vw, vh), Color(0.016, 0.024, 0.063, 0.7))
	var w: float = min(760.0, vw - 40); var h: float = min(500.0, vh - 40); var x = vw / 2 - w / 2; var y = vh / 2 - h / 2
	panel(x, y, w, h, 0.95)
	menu_rects = []
	txt("쉬어 가기", x + 24, y + 40, 22, GOLD, 0, Assets.font_black)
	menu_rects_page = menu_page
	for i in 3:
		var tr = {"x": x + [170, 290, 440][i], "y": y + 16, "w": 140 if i == 1 else 110, "h": 34, "page": i, "id": "tab%d" % i}
		menu_rects.append(tr)
		draw_rect(Rect2(tr.x, tr.y, tr.w, tr.h), Color(0.84, 0.7, 0.43, 0.3) if menu_page == i else Color(1, 1, 1, 0.06))
		txt(["몸과 탈", "부적·향가·부탁", "설정"][i], tr.x + tr.w / 2, tr.y + 23, 13, PAPER, 1)
	if menu_page == 1:
		draw_menu2(x, y, w, h)
		_draw_menu_focus()
		return
	if menu_page == 2:
		settings_menu.draw(self, x, y, w, h)
		_draw_menu_focus()
		return
	var st = ["레벨 %d  (%d/%d)" % [p.lvl, p.xp, p.exp_need()], "체력 %d/%d" % [ceil(p.hp), p.max_hp], "기 %d/%d" % [p.gi, p.max_gi],
		"공격 %d" % round(p.atk()), "엽전 %d냥" % p.coins, "약과 %d · 식혜 %d" % [p.items.yakgwa, p.items.sikhye], "정화한 요괴 %d" % int(f.get("kills_total", 0))]
	for i in st.size(): txt(st[i], x + 24, y + 76 + i * 24, 14, PAPER, 0, Assets.font)
	txt("탈", x + 24, y + 262, 16, GOLD)
	var cols: int = 1 if p.masks.size() <= 4 else 2
	var mw: float = 300.0 if cols == 1 else (w / 2 - 40) / 2.0
	for i in p.masks.size():
		var M: Dictionary = Ent.MASKS[p.masks[i]]
		var rx = x + 24 + (i % cols) * (mw + 6); var ry = y + 272 + int(i / cols) * 44
		menu_rects.append({"x": rx, "y": ry, "w": mw, "h": 40, "mask": p.masks[i], "id": "mask%d" % i})
		draw_rect(Rect2(rx, ry, mw, 40), Color(0.84, 0.7, 0.43, 0.28) if p.mask == p.masks[i] else Color(1, 1, 1, 0.05))
		txt(M.name, rx + 10, ry + 18, 15, M.color)
		txt(fit(M.desc, 11, mw - 14), rx + 10, ry + 34, 11, Color("#c8c0b0"), 0, Assets.font)
	var vx = x + w / 2 + 10
	txt("처용가", vx, y + 76, 16, GOLD)
	for i in 8:
		var got: bool = f.get("verse%d" % (i + 1), false)
		txt("%d. %s" % [i + 1, Story.VERSES[i] if got else "· · · · · ·"], vx, y + 106 + i * 28, 16, PAPER if got else Color(PAPER, 0.25), 0, Assets.font)
	txt("익힌 춤", vx, y + 352, 16, GOLD)
	var sk = ["소매 [%s]" % _kl("attack", "J")]
	for k in ["skill1", "skill2", "skill3"]:
		if p.skills.get(k, false): sk.append("%s [%s]" % [Ent.SKILLS[k].name, _kl(k, {"skill1": "U", "skill2": "I", "skill3": "O"}[k])])
	if f.get("has_ult", false): sk.append("처용가 [%s]" % _kl("ult", "L"))
	txt(fit(" · ".join(sk), 13, w / 2 - 40), vx, y + 376, 13, Color("#d8d0c0"), 0, Assets.font)
	var keys_hint := "이동 스틱 · 구르기 B · 대화 X · 탈 Select · 약과 L3 · 식혜 R3" if Inp.pad_used else "이동 WASD · 구르기 K · 대화 E · 탈 M · 약과 1 · 식혜 2"
	txt(fit(keys_hint, 13, w / 2 - 40), vx, y + 404, 13, Color("#9a9080"), 0, Assets.font)
	var sr = {"x": x + w - 250, "y": y + h - 54, "w": 110, "h": 38, "sound": true, "id": "sound"}
	menu_rects.append(sr)
	draw_rect(Rect2(sr.x, sr.y, sr.w, sr.h), Color(1, 1, 1, 0.08))
	txt("소리 켜기" if Sfx.off else "소리 끄기", sr.x + sr.w / 2, sr.y + 24, 14, Color("#d8ccb0"), 1)
	var cr = {"x": x + w - 130, "y": y + h - 54, "w": 110, "h": 38, "close": true, "id": "close"}
	menu_rects.append(cr)
	draw_rect(Rect2(cr.x, cr.y, cr.w, cr.h), Color(0.84, 0.7, 0.43, 0.25))
	txt("돌아가기", cr.x + cr.w / 2, cr.y + 25, 15, GOLD, 1)
	txt("진행은 자동으로 저장되오", x + w / 2, y + h - 18, 12, Color("#9a9080"), 1, Assets.font)
	_draw_menu_focus()

# page 2: talismans (tap to wear, two at most), the hyangga gathered, side quests on this map
func draw_menu2(x: float, y: float, w: float, h: float) -> void:
	var p = g.player; var f: Dictionary = g.flags
	txt("부적 (둘까지 지닐 수 있소)", x + 24, y + 80, 16, GOLD)
	if p.talis.is_empty(): txt("아직 부적이 없소", x + 24, y + 110, 13, Color("#9a9080"), 0, Assets.font)
	for i in p.talis.size():
		var T: Dictionary = Ent.TALIS[p.talis[i]]
		var rx = x + 24 + (i % 2) * 168; var ry = y + 92 + int(i / 2) * 44
		menu_rects.append({"x": rx, "y": ry, "w": 160, "h": 40, "talis": i, "id": "talis%d" % i})
		var on: bool = p.equip.has(i)
		draw_rect(Rect2(rx, ry, 160, 40), Color(0.66, 0.5, 1.0, 0.32) if on else Color(1, 1, 1, 0.05))
		txt(("● " if on else "") + T.name, rx + 10, ry + 18, 14, Color("#e0d0ff") if on else PAPER)
		txt(fit(T.desc, 11, 146), rx + 10, ry + 34, 11, Color("#c8c0b0"), 0, Assets.font)
	var vx = x + w / 2 + 10
	txt("향가", vx, y + 80, 16, GOLD)
	for i in Story.HYANGGA_ORDER.size():
		var k: String = Story.HYANGGA_ORDER[i]
		var H: Dictionary = Story.HYANGGA[k]
		var got: bool = f.get("hy_" + k, false)
		txt(H.name if got else "· · · · ·", vx, y + 108 + i * 40, 15, Color("#ffb0e0") if got else Color(PAPER, 0.25))
		if got: txt(fit(H.effect, 11, w / 2 - 40), vx, y + 124 + i * 40, 11, Color("#c8c0b0"), 0, Assets.font)
	txt("부탁 (이 고장)", vx, y + 330, 16, GOLD)
	var c = g.story.chapter()
	var row := 0
	if c:
		for q in c.sides():
			var st: String = c.side_state(q)
			if st == "": continue
			var t2: String = q.name + ("  ✔" if st == "done" else "  (%d/%d)" % [min(c.side_progress(q), q.count), q.count])
			txt(fit(t2, 13, w / 2 - 40), vx, y + 356 + row * 22, 13, Color("#9a9080") if st == "done" else PAPER, 0, Assets.font)
			row += 1
	if row == 0: txt("맡은 부탁이 없소", vx, y + 356, 13, Color("#9a9080"), 0, Assets.font)
	var cr = {"x": x + w - 130, "y": y + h - 54, "w": 110, "h": 38, "close": true, "id": "close"}
	menu_rects.append(cr)
	draw_rect(Rect2(cr.x, cr.y, cr.w, cr.h), Color(0.84, 0.7, 0.43, 0.25))
	txt("돌아가기", cr.x + cr.w / 2, cr.y + 25, 15, GOLD, 1)

func tick(dt: float) -> void:
	for i in range(toasts.size() - 1, -1, -1):
		toasts[i].t += dt
		if toasts[i].t > 2: toasts.remove_at(i)

func _draw() -> void:
	if g == null or G.state != "play": return
	var dt = get_process_delta_time()
	if not g.cinema: draw_hud()
	if dialog == null and shop == null and choice == null and not menu and not g.cinema: draw_buttons()
	else: Inp.buttons = []
	if g.cinema:
		var k: float = min(1.0, g.cinema_t * 2); var bh = 48 * k
		draw_rect(Rect2(0, 0, vw, bh), Color.BLACK); draw_rect(Rect2(0, vh - bh, vw, bh), Color.BLACK)
	draw_dialog()
	if shop: draw_shop()
	if choice: draw_choice()
	if menu: draw_menu()
	draw_banner(dt)
	if chapter_banner:
		var cb = chapter_banner
		cb.t += dt
		if cb.t > 4.5: chapter_banner = null
		else:
			var a: float = min(1.0, min(cb.t * 1.5, (4.5 - cb.t) * 1.5))
			draw_rect(Rect2(0, vh * 0.2, vw, 70), Color(0.02, 0.02, 0.06, 0.55 * a))
			txt(cb.text, vw / 2, vh * 0.2 + 45, 28, Color(1, 0.93, 0.78, a), 1, Assets.font_black, 5)
