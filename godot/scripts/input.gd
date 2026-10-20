# Input: keyboard plus touch (left floating joystick, right buttons registered by the UI each frame).
extends Node

const KEYMAP := {
	KEY_J: "attack", KEY_Z: "attack", KEY_K: "roll", KEY_SHIFT: "roll", KEY_X: "roll",
	KEY_U: "skill1", KEY_I: "skill2", KEY_O: "skill3", KEY_L: "ult", KEY_E: "interact", KEY_SPACE: "interact",
	KEY_C: "interact", KEY_ENTER: "confirm", KEY_1: "item1", KEY_2: "item2", KEY_M: "mask", KEY_ESCAPE: "menu", KEY_P: "menu",
}
var keys := {}          # keycode -> true
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
	if bot and bot.down.has(a): return true
	return touch_held.has(a)

func hit(a: String) -> bool:
	return pressed.has(a)

func press(a: String) -> void:
	pressed[a] = true

func end_frame() -> void:
	pressed.clear()

func move() -> Vector2:
	var v := Vector2.ZERO
	if keys.has(KEY_A) or keys.has(KEY_LEFT): v.x -= 1
	if keys.has(KEY_D) or keys.has(KEY_RIGHT): v.x += 1
	if keys.has(KEY_W) or keys.has(KEY_UP): v.y -= 1
	if keys.has(KEY_S) or keys.has(KEY_DOWN): v.y += 1
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

func _unhandled_input(e: InputEvent) -> void:
	if e is InputEventKey:
		var k: int = e.keycode
		if e.pressed and not e.echo:
			keys[k] = true; last_touch = false; any_key = true
			Sfx.unlock()
			if KEYMAP.has(k): pressed[KEYMAP[k]] = true
			if k in [KEY_ENTER, KEY_SPACE, KEY_J, KEY_E]: pressed["confirm"] = true
		elif not e.pressed:
			keys.erase(k)
	elif e is InputEventScreenTouch:
		last_touch = true
		Sfx.unlock()
		var p := _ui_pos(e.position)
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
		else:
			var o = owner_of.get(e.index)
			if o == "stick": stick.active = false; stick.id = -1
			elif o: touch_held.erase(o)
			owner_of.erase(e.index)
	elif e is InputEventScreenDrag:
		if owner_of.get(e.index) == "stick":
			var p := _ui_pos(e.position)
			stick.x = p.x; stick.y = p.y
			var d := Vector2(stick.x - stick.ox, stick.y - stick.oy)
			if d.length() > 70:
				var o := Vector2(stick.x, stick.y) - d.normalized() * 70
				stick.ox = o.x; stick.oy = o.y
	elif e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT:
		Sfx.unlock()
		var p := _ui_pos(e.position)
		if e.pressed:
			var b = _button_at(p)
			if b:
				pressed[b.action] = true; touch_held[b.action] = true; owner_of[-1] = b.action
			else:
				tap_pos = p; pressed["confirm"] = true; pressed["tap"] = true
		else:
			var o = owner_of.get(-1)
			if o: touch_held.erase(o)
			owner_of.erase(-1)
