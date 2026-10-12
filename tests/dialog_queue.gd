extends SceneTree
## SB-29 regression: overlapping say() calls queue instead of overwriting (headless, driven by dialog_queue.sh).
var fails := 0
var log_: Array = []

func _ck(name: String, ok: bool, extra := "") -> void:
	print(("PASS " if ok else "FAIL ") + name + (" :: " + extra if extra != "" else ""))
	if not ok: fails += 1

func _tap(d) -> void:
	var ev := InputEventMouseButton.new()
	ev.pressed = true
	d._unhandled_input(ev)

func _run(d, tag: String, lines: Array) -> void:
	await d.say(lines)
	log_.append(tag)

func _initialize() -> void:
	var d = load("res://scripts/dialog_box.gd").new()
	root.add_child(d)
	await process_frame
	_run(d, "A", [{"name": "역신", "text": "A1"}])
	_run(d, "B", [{"name": "역신", "text": "B1"}, {"name": "역신", "text": "B2"}])
	_run(d, "C", ["C1"])
	await process_frame
	_ck("q1 first dialogue shows A1", d._body.text == "A1", d._body.text)
	_ck("q2 queued dialogues not finished early", log_.is_empty())
	_tap(d); _tap(d)   # complete line, advance
	await process_frame
	_ck("q3 A done, B1 shown whole", log_ == ["A"] and d._body.text == "B1", str(log_) + d._body.text)
	_tap(d); _tap(d); await process_frame
	_ck("q4 B2 shown (B not cut)", d._body.text == "B2" and log_ == ["A"], d._body.text)
	_tap(d); _tap(d); await process_frame
	_ck("q5 B done, C1 shown", log_ == ["A", "B"] and d._body.text == "C1", str(log_))
	_tap(d); _tap(d); await process_frame
	_ck("q6 all done in FIFO order, box idle", log_ == ["A", "B", "C"] and not d.busy(), str(log_))
	quit(1 if fails > 0 else 0)
