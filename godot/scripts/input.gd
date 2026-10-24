# Input: keyboard, gamepad and touch (left floating joystick, right buttons registered by the UI each frame).
# The gamepad feeds the same actions as the keyboard: Inp.hit/down/move read keys, pad and touch alike.
#   pad: stick + d-pad move; A attack/confirm, B roll/cancel, X interact, Y ult, LB/RB/LT skill1/2/3 (U/I/O),
#   RT roll, L3/R3 items 1/2, Start menu, Select mask. Menus also get discrete "nav_up/down/left/right" presses
#   (keyboard, d-pad and stick, with auto repeat), read through nav_hit().
extends Node

const KEYMAP := {
	KEY_J: "attack", KEY_Z: "attack", KEY_K: "roll", KEY_SHIFT: "roll", KEY_X: "roll",
	KEY_U: "skill1", KEY_I: "skill2", KEY_O: "skill3", KEY_L: "ult", KEY_E: "interact", KEY_SPACE: "interact",
	KEY_C: "interact", KEY_ENTER: "confirm", KEY_1: "item1", KEY_2: "item2", KEY_M: "mask", KEY_ESCAPE: "menu", KEY_P: "menu",
}
const PAD_BUTTONS := {
	JOY_BUTTON_A: "attack", JOY_BUTTON_B: "roll", JOY_BUTTON_X: "interact", JOY_BUTTON_Y: "ult",
	JOY_BUTTON_LEFT_SHOULDER: "skill1", JOY_BUTTON_RIGHT_SHOULDER: "skill2",
	JOY_BUTTON_START: "menu", JOY_BUTTON_BACK: "mask", JOY_BUTTON_LEFT_STICK: "item1", JOY_BUTTON_RIGHT_STICK: "item2",
}
const PAD_TRIGGERS := {JOY_AXIS_TRIGGER_LEFT: "skill3", JOY_AXIS_TRIGGER_RIGHT: "roll"}
const PAD_DEADZONE := 0.25
# pad button glyphs shown in place of key letters (Xbox layout; PlayStation owners know A=Cross, B=Circle, X=Square, Y=Triangle)
const PAD_LABEL := {"attack": "A", "roll": "B", "interact": "X", "ult": "Y", "skill1": "LB", "skill2": "RB", "skill3": "LT",
	"item1": "L3", "item2": "R3", "menu": "Start", "mask": "Select"}
var keys := {}          # keycode -> true
var pad_btn := {}       # joypad button -> true (held)
var pad_trig := {}      # trigger axis -> true (held past 0.5)
var pad_used := false   # the last input came from a gamepad (the UI then shows pad glyphs, not key letters)
var ptr_down := false   # a finger or the left mouse button is held on empty screen (for sliders)
var ptr_pos := Vector2.ZERO  # its position in UI coordinates
var ptr_idx := -2
var nav_prev := Vector2i.ZERO
var nav_t := 0.0
var menu_hook := false   # test hook --menu (set in _ready: G has not read its parameters yet when this script loads)
var pad_sim_done := false
var pad_sim: Array = []  # test hook --padsim=A@1.0,START@2.5,DOWN@3 : synthetic gamepad presses at game seconds
var pressed := {}       # action -> true (this frame)
var touch_held := {}    # action -> true
var buttons: Array = [] # [{action, x, y, r}] in UI coordinates
var stick := {"active": false, "id": -1, "ox": 0.0, "oy": 0.0, "x": 0.0, "y": 0.0}
var owner_of := {}      # touch index -> action or "stick"
var last_touch := false
var any_key := false
var tap_pos = null
var ui_scale := 1.0     # UI layer scale (set by the UI)
var bot = null          # autopilot: {x, y, down: {}}

func down(a: String) -> bool:
	for k in keys:
		if KEYMAP.get(k) == a: return true
	for b in pad_btn:
		if PAD_BUTTONS.get(b) == a: return true
	for t in pad_trig:
		if PAD_TRIGGERS.get(t) == a: return true
	if bot and bot.down.has(a): return true
	return touch_held.has(a)

func hit(a: String) -> bool:
	return pressed.has(a)

func press(a: String) -> void:
	pressed[a] = true

func end_frame() -> void:
	pressed.clear()

func _pad_stick() -> Vector2:
	var best := Vector2.ZERO
	for d in Input.get_connected_joypads():
		var a := Vector2(Input.get_joy_axis(d, JOY_AXIS_LEFT_X), Input.get_joy_axis(d, JOY_AXIS_LEFT_Y))
		if a.length() > best.length(): best = a
	if best.length() < PAD_DEADZONE: return Vector2.ZERO
	return best.normalized() * minf(1.0, (best.length() - PAD_DEADZONE) / (1.0 - PAD_DEADZONE))

# keyboard + d-pad + left stick (no touch stick, no autopilot)
func _human_move() -> Vector2:
	var v := Vector2.ZERO
	if keys.has(KEY_A) or keys.has(KEY_LEFT) or pad_btn.has(JOY_BUTTON_DPAD_LEFT): v.x -= 1
	if keys.has(KEY_D) or keys.has(KEY_RIGHT) or pad_btn.has(JOY_BUTTON_DPAD_RIGHT): v.x += 1
	if keys.has(KEY_W) or keys.has(KEY_UP) or pad_btn.has(JOY_BUTTON_DPAD_UP): v.y -= 1
	if keys.has(KEY_S) or keys.has(KEY_DOWN) or pad_btn.has(JOY_BUTTON_DPAD_DOWN): v.y += 1
	var ps := _pad_stick()
	if ps != Vector2.ZERO and v == Vector2.ZERO: v = ps
	return v

func move() -> Vector2:
	var v := _human_move()
	if stick.active:
		var d := Vector2(stick.x - stick.ox, stick.y - stick.oy)
		if d.length() > 6: v = d / max(d.length(), 46.0)
	if bot and (bot.x != 0 or bot.y != 0): v = Vector2(bot.x, bot.y)
	return v.limit_length(1.0)

func _ui_pos(p: Vector2) -> Vector2:
	return p / ui_scale

func _button_at(p: Vector2):
	for b in buttons:
		if Vector2(b.x, b.y).distance_to(p) <= b.r * 1.15: return b
	return null

func _modal() -> bool:
	return G.state != "play" or (G.game != null and G.game.ui.modal())

# B closes shops, choices and the pause menu like Esc does; elsewhere it rolls
func _cancelable() -> bool:
	return G.state == "play" and G.game != null and (G.game.ui.shop != null or G.game.ui.choice != null or G.game.ui.menu)

func nav_hit(dir: String) -> bool:
	return pressed.has("nav_" + dir)

func _nav_fire(d: Vector2i) -> void:
	pressed["nav_" + ("left" if d.x < 0 else "right" if d.x > 0 else "up" if d.y < 0 else "down")] = true

const SIM_BUTTONS := {"A": JOY_BUTTON_A, "B": JOY_BUTTON_B, "X": JOY_BUTTON_X, "Y": JOY_BUTTON_Y, "LB": JOY_BUTTON_LEFT_SHOULDER,
	"RB": JOY_BUTTON_RIGHT_SHOULDER, "START": JOY_BUTTON_START, "BACK": JOY_BUTTON_BACK, "L3": JOY_BUTTON_LEFT_STICK,
	"R3": JOY_BUTTON_RIGHT_STICK, "UP": JOY_BUTTON_DPAD_UP, "DOWN": JOY_BUTTON_DPAD_DOWN, "LEFT": JOY_BUTTON_DPAD_LEFT, "RIGHT": JOY_BUTTON_DPAD_RIGHT}

func _ready() -> void:
	menu_hook = G.has("menu")
	for k in G.param("padsim").split(",", false):
		var a := k.split("@")
		if a.size() == 2 and SIM_BUTTONS.has(a[0]): pad_sim.append({"b": SIM_BUTTONS[a[0]], "t": float(a[1]), "n": 0})

func _sim_pad() -> void:
	var t := Engine.get_process_frames() / 60.0
	for s in pad_sim:
		if s.n == 0 and t >= s.t or s.n == 1 and t >= s.t + 0.12:
			var ev := InputEventJoypadButton.new()
			ev.button_index = s.b; ev.pressed = s.n == 0
			Input.parse_input_event(ev)
			s.n += 1
	if not pad_sim_done and pad_sim.all(func(s): return s.n == 2) and t > pad_sim.back().t + 0.5 and G.game != null:
		pad_sim_done = true   # state dump for headless checks
		var u = G.game.ui
		print("PADSIM menu=%s page=%d focus=%s master=%d music=%d sfx=%d fs=%s shake=%s text=%d state=%s" % [u.menu, u.menu_page, u.menu_focus,
			Settings.master, Settings.music, Settings.sfx, Settings.fullscreen, Settings.shake, Settings.text_mode, G.state])
		if DisplayServer.get_name() == "headless": get_tree().quit()

# discrete direction presses for menus: first press at once, then repeat while held
func _process(dt: float) -> void:
	if pad_sim.size() > 0: _sim_pad()
	var m := _human_move()
	var d := Vector2i.ZERO
	if absf(m.x) > 0.55 or absf(m.y) > 0.55:
		d = Vector2i(int(signf(m.x)), 0) if absf(m.x) > absf(m.y) else Vector2i(0, int(signf(m.y)))
	if d != Vector2i.ZERO:
		if d != nav_prev: _nav_fire(d); nav_t = 0.38
		else:
			nav_t -= dt
			if nav_t <= 0.0: _nav_fire(d); nav_t = 0.11
	nav_prev = d
	if menu_hook and G.state == "play" and G.game != null and Engine.get_process_frames() > 20:
		menu_hook = false   # test hook --menu[=page]: open the pause menu on that page (default: settings)
		G.game.ui.menu = true
		G.game.ui.menu_page = int(G.param("menu")) if G.param("menu") != "" else 2

func _unhandled_input(e: InputEvent) -> void:
	if e is InputEventJoypadButton:
		var b: int = e.button_index
		if not e.pressed: pad_btn.erase(b); return
		pad_btn[b] = true; pad_used = true; last_touch = false; any_key = true
		Sfx.unlock()
		match b:
			JOY_BUTTON_A: pressed["attack"] = true; pressed["confirm"] = true
			JOY_BUTTON_X: pressed["interact"] = true; pressed["confirm"] = true
			JOY_BUTTON_B:
				pressed["roll"] = true; pressed["cancel"] = true
				if _cancelable(): pressed["menu"] = true
			_:
				if PAD_BUTTONS.has(b): pressed[PAD_BUTTONS[b]] = true
		return
	if e is InputEventJoypadMotion:
		var ax: int = e.axis
		if PAD_TRIGGERS.has(ax):
			var on: bool = e.axis_value > 0.5
			if on and not pad_trig.has(ax):
				pad_trig[ax] = true; pad_used = true; last_touch = false; any_key = true
				pressed[PAD_TRIGGERS[ax]] = true
			elif not on and e.axis_value < 0.3: pad_trig.erase(ax)
		elif absf(e.axis_value) > 0.6 and (ax == JOY_AXIS_LEFT_X or ax == JOY_AXIS_LEFT_Y):
			pad_used = true; last_touch = false; any_key = true
		return
	if e is InputEventKey:
		var k: int = e.keycode
		if e.pressed and not e.echo:
			keys[k] = true; last_touch = false; any_key = true; pad_used = false
			if k == KEY_F11: Settings.toggle_fullscreen(); return
			Sfx.unlock()
			if KEYMAP.has(k): pressed[KEYMAP[k]] = true
			if k in [KEY_ENTER, KEY_SPACE, KEY_J, KEY_E]: pressed["confirm"] = true
		elif not e.pressed:
			keys.erase(k)
	elif e is InputEventScreenTouch:
		last_touch = true; pad_used = false
		Sfx.unlock()
		var p := _ui_pos(e.position)
		if not e.pressed and e.index == ptr_idx: ptr_down = false
		if e.pressed:
			var b = _button_at(p)
			if b:
				owner_of[e.index] = b.action; touch_held[b.action] = true; pressed[b.action] = true
			elif not _modal() and p.x < get_viewport().get_visible_rect().size.x / ui_scale * 0.5 and not stick.active:
				stick.active = true; stick.id = e.index
				stick.ox = p.x; stick.x = p.x; stick.oy = p.y; stick.y = p.y
				owner_of[e.index] = "stick"
			else:
				tap_pos = p; pressed["confirm"] = true; pressed["tap"] = true
				ptr_down = true; ptr_pos = p; ptr_idx = e.index
		else:
			var o = owner_of.get(e.index)
			if o == "stick": stick.active = false; stick.id = -1
			elif o: touch_held.erase(o)
			owner_of.erase(e.index)
	elif e is InputEventScreenDrag:
		if ptr_down and e.index == ptr_idx: ptr_pos = _ui_pos(e.position)
		if owner_of.get(e.index) == "stick":
			var p := _ui_pos(e.position)
			stick.x = p.x; stick.y = p.y
			var d := Vector2(stick.x - stick.ox, stick.y - stick.oy)
			if d.length() > 70:
				var o := Vector2(stick.x, stick.y) - d.normalized() * 70
				stick.ox = o.x; stick.oy = o.y
	elif e is InputEventMouseMotion:
		if ptr_down and ptr_idx == -1: ptr_pos = _ui_pos(e.position)
	elif e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT:
		Sfx.unlock(); pad_used = false
		var p := _ui_pos(e.position)
		if not e.pressed and ptr_idx == -1: ptr_down = false
		if e.pressed:
			var b = _button_at(p)
			if b:
				pressed[b.action] = true; touch_held[b.action] = true; owner_of[-1] = b.action
			else:
				tap_pos = p; pressed["confirm"] = true; pressed["tap"] = true
				ptr_down = true; ptr_pos = p; ptr_idx = -1
		else:
			var o = owner_of.get(-1)
			if o: touch_held.erase(o)
			owner_of.erase(-1)
