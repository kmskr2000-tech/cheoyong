extends SceneTree
## Headless save checks, driven by tests/save_check.sh (sets a throwaway user dir). Prints PASS/FAIL lines.
var fails := 0

func _ck(name: String, ok: bool, extra := "") -> void:
	print(("PASS " if ok else "FAIL ") + name + (" :: " + extra if extra != "" else ""))
	if not ok: fails += 1

func _put(path: String, text: String) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE); f.store_string(text); f.close()

func _clean() -> void:
	for n in ["save.json", "save.json.bad", "save.json.tmp"]:
		DirAccess.remove_absolute("user://" + n)

func _initialize() -> void:
	var G = root.get_node("Game")
	var fx_path: String = OS.get_environment("SAVE_FIXTURES")
	# (a) legacy v1 sample
	_clean()
	var legacy := FileAccess.get_file_as_string(fx_path + "/save_v0.json")
	var src: Dictionary = JSON.parse_string(legacy)
	_ck("a0 fixture has no save_version", not src.has("save_version"))
	_put("user://save.json", legacy)
	_ck("a1 has_save legacy", G.has_save())
	_ck("a2 load_save legacy", G.load_save())
	var ok: bool = G.money == 137 and G.lv == 5 and G.deok == 17 and G.jeonggi == 42 and G.skill_points == 2 \
		and G.checkpoint == "gyeongju" and G.tal == "cheoyong" and G.skills == ["a", "b"] and G.items["insam"] == 3 \
		and G.mats["철"] == 3 and G.dogam["dokkaebi"] == 4 and G.flags.has("night") and G.titles == ["첫정화"] \
		and G.accessories == ["ring1"] and G.tals == ["cheoyong"]
	_ck("a3 legacy fields preserved", ok)
	G.save()
	var out: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("user://save.json"))
	_ck("a4 resave adds save_version=2 and keeps all old keys", int(out.get("save_version", 0)) == 2 and src.keys().all(func(k): return out.has(k)))
	# a5 partial legacy (missing keys -> defaults)
	_put("user://save.json", '{"flags":{"x":1},"lv":3}')
	_ck("a5 partial legacy loads with defaults", G.load_save() and G.lv == 3 and G.money == 50 and G.skills == [] and G.checkpoint == "beach")
	# a6 unknown future key survives
	_put("user://save.json", '{"save_version":3,"flags":{},"future_gear":{"a":1}}')
	G.load_save(); G.save()
	var o2: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("user://save.json"))
	_ck("a6 unknown key + newer version preserved on resave", o2.has("future_gear") and int(o2["save_version"]) == 3)
	# (b) corrupt samples
	var bad := {"garbage": "{not json", "wrongtype": '{"flags":{},"lv":"five"}', "notdict": "[1,2]",
		"nokey": '{"lv":2}', "empty": ""}
	for k in bad:
		_clean()
		_put("user://save.json", bad[k])
		var hs: bool = G.has_save()
		_ck("b %s: has_save false" % k, not hs)
		_ck("b %s: load_save false" % k, not G.load_save())
		_ck("b %s: .bad preserved with original bytes" % k, FileAccess.file_exists("user://save.json.bad") and FileAccess.get_file_as_string("user://save.json.bad") == bad[k])
		G.new_game(); G.save()
		_ck("b %s: new save after corruption works" % k, G.has_save() and G.load_save())
	# b2: second quarantine keeps the first .bad; b3: .tmp-only recovery
	_clean()
	_put("user://save.json", "{bad1"); G.has_save()
	_put("user://save.json", "{bad2"); G.has_save()
	var da := DirAccess.open("user://")
	var bads := 0
	for n in da.get_files():
		if n.begins_with("save.json.bad"): bads += 1
	_ck("b2 two quarantines keep both files", bads == 2, str(bads))
	_clean()
	_put("user://save.json.tmp", '{"flags":{},"lv":8}')
	_ck("b3 .tmp-only save recovered", G.has_save() and G.load_save() and G.lv == 8)
	_clean()
	for n in DirAccess.open("user://").get_files():
		if n.begins_with("save.json"): DirAccess.remove_absolute("user://" + n)
	# (c) round trip
	_clean()
	G.new_game()
	G.flags = {"a": 1, "b": 2}; G.money = 99; G.items = {"insam": 5, "gugija": 1, "jeonghwa": 0}; G.checkpoint = "gyeongju"
	G.jeonggi = 7; G.deok = 3; G.lv = 9; G.skill_points = 4; G.skills = ["s1"]; G.mats = {"m": 2}; G.dogam = {"d": 1}
	G.tal = "cheoyong"; G.tals = ["cheoyong"]; G.accessories = ["x"]; G.titles = ["t"]
	var before := [G.flags, G.money, G.items, G.checkpoint, G.jeonggi, G.deok, G.lv, G.skill_points, G.skills, G.mats, G.dogam, G.tal, G.tals, G.accessories, G.titles].duplicate(true)
	G.save()
	G.new_game()
	_ck("c1 load after save", G.load_save())
	var after := [G.flags, G.money, G.items, G.checkpoint, G.jeonggi, G.deok, G.lv, G.skill_points, G.skills, G.mats, G.dogam, G.tal, G.tals, G.accessories, G.titles]
	_ck("c2 round trip identical", after == before)
	_ck("c3 no leftover tmp file", not FileAccess.file_exists("user://save.json.tmp"))
	_clean()
	quit(1 if fails > 0 else 0)
