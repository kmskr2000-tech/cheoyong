extends SceneTree
# plan: hold A N | tap A | wait N | shot NAME | tp X Y | tpi ID | tpn ID | st | pump N | info | dump | auto N | lvl ID flags | god | quit
var plan: Array = []
var pi := 0
var wait_n := 0
var hold := {}
var shotdir := ""
var logf := ""
var pump_n := 0
var frame := 0
var G: Node
var god := false
var auto_n := 0
var wb_n := 0
var gt_n := 0
var gt_t := Vector2.ZERO
var gt_fight := false
var gt_last := Vector2.ZERO
var gt_stuck := 0
var gt_maxstuck := 0
var gt_name := ""
var wb_dodge := false
var wb_dir := Vector2.ZERO
var _lf: FileAccess
func _initialize() -> void:
	var pf := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--plan="): pf = a.get_slice("=", 1)
		if a.begins_with("--shots="): shotdir = a.get_slice("=", 1)
		if a.begins_with("--log="): logf = a.get_slice("=", 1)
	plan = FileAccess.get_file_as_string(pf).split("\n", false)
	G = root.get_node("Game")
	Engine.max_fps = 60
	_boot.call_deferred()
func _boot() -> void:
	await process_frame
	change_scene_to_file("res://scenes/title.tscn")
func ev(act: String, p: bool) -> void:
	var e := InputEventAction.new(); e.action = act; e.pressed = p; Input.parse_input_event(e)
func lv() -> Node:
	var s := current_scene
	return s if (s != null and s.get_node_or_null("Player") != null) else null
func st() -> void:
	var l = lv()
	var s: String = "ST f=%d scene=%s lvl=%s flags=%s" % [frame, current_scene.scene_file_path.get_file() if current_scene else "-", G.level_id, G.flags.keys()]
	if l:
		var p = l.get_node("Player")
		s += " pos=%s state=%s hp=%s/%s en=%d" % [p.position.round(), p.state, p.hp, p.max_hp, get_nodes_in_group("enemy").size()]
	lg(s)
func _process(_d: float) -> bool:
	frame += 1
	if god and lv() and lv().get_node("Player").state != "dead": lv().get_node("Player").hp = lv().get_node("Player").max_hp
	if auto_n > 0 and lv():
		auto_n -= 1
		if frame % 40 == 0: ev("confirm", true); ev("confirm", false)
		if frame % 12 == 0:
			var pl = lv().get_node("Player")
			if pl.state == "move" or pl.state == "attack":
				var tgt = null
				for d in get_nodes_in_group("downed"):
					if d.get("kind") != null and d.state == "downed": tgt = d
				if tgt:
					pl.position = tgt.position + Vector2(-14, 4); ev("song", true); ev("song", false)
				else:
					for e in get_nodes_in_group("enemy"):
						if e.get("kind") != null: tgt = e
					var bo = lv().get_node_or_null("Boss")
					if bo and str(bo.state) not in ["wait", "disguise", "disguised"]: tgt = bo
					if tgt:
						if pl.position.distance_to(tgt.position) > 30: pl.position = tgt.position + Vector2(-22, 4)
						ev("attack", true); ev("attack", false)
		if auto_n == 0: lg("AUTO done")
		if auto_n % 180 == 0 and lv(): st(); var bb = lv().get_node_or_null("Boss"); if bb: lg("BOSS hp ", bb.hp, " ", bb.state, " deaths ", G.deaths, " plhp ", lv().get_node("Player").hp)
		return false
	if gt_n > 0:
		gt_n -= 1
		var l0 = lv()
		if l0 == null:
			if gt_n % 60 == 0: lg("GOTO ", gt_name, " (no level, waiting) f=", frame)
			return false
		var pl = l0.get_node("Player")
		var nd := Vector2.ZERO
		var dd: float = pl.position.distance_to(gt_t)
		if frame % 40 == 0: ev("confirm", true); ev("confirm", false)
		if pl.state in ["move", "attack"] and dd > 6:
			nd = (gt_t - pl.position).normalized()
		if gt_fight and pl.state in ["move", "attack"]:
			var tg = null
			var bd2 := 44.0
			for e in get_nodes_in_group("enemy") + get_nodes_in_group("downed"):
				if e.get("kind") != null and e.position.distance_to(pl.position) < bd2: tg = e; bd2 = e.position.distance_to(pl.position)
			if tg != null:
				nd = Vector2.ZERO if bd2 < 30 else (tg.position - pl.position).normalized()
				if frame % 14 == 0:
					if tg.get("state") == "downed": ev("song", true); ev("song", false)
					else: ev("attack", true); ev("attack", false)
		if pl.position.distance_to(gt_last) < 0.5 and nd != Vector2.ZERO and pl.state == "move": gt_stuck += 1
		else: gt_stuck = 0
		gt_maxstuck = maxi(gt_maxstuck, gt_stuck)
		gt_last = pl.position
		for a in ["move_left", "move_right", "move_up", "move_down"]: ev(a, false)
		if nd.x < -0.3: ev("move_left", true)
		if nd.x > 0.3: ev("move_right", true)
		if nd.y < -0.3: ev("move_up", true)
		if nd.y > 0.3: ev("move_down", true)
		if gt_n % 120 == 0: lg("GOTO %s pos=%s d=%d hp=%s en=%d stuck=%d lvl=%s" % [gt_name, pl.position.round(), int(dd), pl.hp, get_nodes_in_group("enemy").size(), gt_stuck, G.level_id])
		if dd <= 6 or gt_n == 0:
			gt_n = 0
			for a in ["move_left", "move_right", "move_up", "move_down"]: ev(a, false)
			lg("GOTO_END %s arrived=%s pos=%s d=%d maxstuck=%d f=%d lvl=%s hp=%s" % [gt_name, dd <= 6, pl.position.round(), int(dd), gt_maxstuck, frame, G.level_id, pl.hp])
		return false
	if wb_n > 0 and lv():
		wb_n -= 1
		var pl = lv().get_node("Player")
		if frame % 40 == 0: ev("confirm", true); ev("confirm", false)
		var nd := Vector2.ZERO
		if pl.state in ["move", "attack"]:
			var tgt = null
			var bd := 1e9
			for d in get_nodes_in_group("downed"):
				if d.get("kind") != null and d.state == "downed" and d.position.distance_to(pl.position) < bd: tgt = d; bd = d.position.distance_to(pl.position)
			var song_t = tgt
			if tgt == null:
				for e in get_nodes_in_group("enemy"):
					if e.get("kind") != null and e.position.distance_to(pl.position) < bd: tgt = e; bd = e.position.distance_to(pl.position)
			var bo = lv().get_node_or_null("Boss")
			if tgt == null and bo and str(bo.state) not in ["wait", "disguise", "disguised", "dead", "kneel"]: tgt = bo
			if bo and str(bo.state) not in ["wait", "disguise", "disguised", "dead"]:
				if bo.state == "kneel": tgt = bo
				elif tgt == null or bd > 60: tgt = bo
			if tgt:
				var to: Vector2 = tgt.position - pl.position
				var dd := to.length()
				if wb_dodge and bo and bo.get("tells") != null:
					for t in bo.tells:
						if is_instance_valid(t) and t.position.distance_to(pl.position) < 34:
							nd = (pl.position - t.position).normalized()
							if frame % 20 == 0: ev("roll", true); ev("roll", false)
				if nd == Vector2.ZERO and dd > 26: nd = to.normalized()
				if dd < 40 and frame % 14 == 0:
					if song_t != null and tgt == song_t: ev("song", true); ev("song", false)
					else: ev("attack", true); ev("attack", false)
		for a in ["move_left", "move_right", "move_up", "move_down"]: ev(a, false)
		if nd.x < -0.3: ev("move_left", true)
		if nd.x > 0.3: ev("move_right", true)
		if nd.y < -0.3: ev("move_up", true)
		if nd.y > 0.3: ev("move_down", true)
		if wb_n % 180 == 0:
			st()
			var b2 = lv().get_node_or_null("Boss")
			if b2: lg("BOSS hp %s %s phase %s deaths %s plhp %s" % [b2.hp, b2.state, b2.phase, G.deaths, pl.hp])
		if wb_n == 0:
			for a in ["move_left", "move_right", "move_up", "move_down"]: ev(a, false)
			lg("WBOT done")
		return false
	if pump_n > 0:
		pump_n -= 1
		if frame % 6 == 0: ev("confirm", true); ev("confirm", false)
		return false
	if wait_n > 0:
		wait_n -= 1; return false
	while pi < plan.size():
		var parts: PackedStringArray = plan[pi].strip_edges().split(" ", false); pi += 1
		if parts.is_empty() or parts[0].begins_with("#"): continue
		match parts[0]:
			"hold":
				for k in hold.keys(): ev(k, false)
				hold.clear()
				ev(parts[1], true); hold[parts[1]] = 1; wait_n = int(parts[2]); return false
			"rel": ev(parts[1], false); hold.erase(parts[1])
			"holdon": ev(parts[1], true); hold[parts[1]] = 1
			"tap": ev(parts[1], true); ev(parts[1], false)
			"wait":
				for k in hold.keys(): ev(k, false)
				hold.clear(); wait_n = int(parts[1]); return false
			"pump": pump_n = int(parts[1]); return false
			"st": st()
			"tp":
				var l = lv()
				if l: l.get_node("Player").position = Vector2(float(parts[1]), float(parts[2])); l.get_node("Player/Camera").reset_smoothing()
			"tpg":
				var l = lv()
				if l:
					l.get_node("Player").position = l.lift(Vector2(float(parts[1]), float(parts[2]))); l.get_node("Player/Camera").reset_smoothing()
			"tpi":
				var l = lv()
				if l:
					for ip in l.interact_points:
						if ip["id"] == parts[1]:
							l.get_node("Player").position = ip["pos"]; lg("TPI ", ip["pos"])
			"tpn":
				var l = lv()
				if l:
					var n = l.npc(parts[1])
					if n: l.get_node("Player").position = n.position + Vector2(-18, 4)
					else: lg("NO NPC ", parts[1])
			"info":
				var l = lv()
				if l:
					for e in get_nodes_in_group("enemy"): lg("EN ", e.get("kind"), " ", e.position.round(), " ", e.get("state"), " hp ", e.get("hp"))
					lg("IP ", l.interact_points.map(func(i): return i["id"] + str(i["pos"])))
			"dump": lg("DUMP lv ", G.lv, " deaths ", G.get("deaths"), " dz ", G.get("death_zone"), " dogam ", G.dogam)
			"lvl":
				G.flags = {}
				if parts.size() > 2:
					for f in parts[2].split(","): G.set_flag(f)
				G._busy = false
				G.change_level(parts[1], "start"); wait_n = 240; return false
			"tour":
				var l = lv()
				if l:
					var ins: Array = []
					var i := 0
					for ip in l.interact_points:
						ins.append("tp %d %d" % [ip["pos"].x, ip["pos"].y]); ins.append("wait 20"); ins.append("shot %s_%d_%s" % [parts[1], i, ip["id"]]); i += 1
					for e in l.get_children():
						if e.get_script() != null and str(e.get_script().resource_path).ends_with("npc.gd"):
							ins.append("tp %d %d" % [e.position.x - 18, e.position.y + 4]); ins.append("wait 20"); ins.append("shot %s_%d_npc_%s" % [parts[1], i, e.name]); i += 1
					for a in l.get_children():
						if a is Area2D and a.get_child_count() > 0:
							ins.append("tp %d %d" % [a.position.x, a.position.y]); ins.append("wait 20"); ins.append("shot %s_%d_area" % [parts[1], i]); i += 1
					lg("TOUR n=", ins.size() / 3)
					var np: Array = []
					np.append_array(plan.slice(0, pi)); np.append_array(ins); np.append_array(plan.slice(pi))
					plan = np
			"ni":
				var l = lv()
				if l:
					var t = l.nearest_interactable()
					lg("NI ", t.get("id", "-"), " locked=", l.get_node("Player").locked, " dialog_active=", l.dialog._active, " pos=", l.get_node("Player").position)
			"wbot": wb_n = int(parts[1]); wb_dodge = parts.size() > 2 and parts[2] == "dodge"; return false
			"goto":
				var l = lv()
				if l:
					gt_t = l.lift(Vector2(float(parts[1]), float(parts[2]))); gt_n = int(parts[3]); gt_fight = parts.size() > 4 and parts[4] == "fight"
					gt_name = "%s,%s" % [parts[1], parts[2]]; gt_stuck = 0; gt_maxstuck = 0; gt_last = Vector2.ZERO
					return false
			"god": god = true
			"auto": auto_n = int(parts[1]); return false
			"shot":
				var nm: String = parts[1]
				RenderingServer.frame_post_draw.connect(func():
					root.get_viewport().get_texture().get_image().save_png(shotdir + "/" + nm + ".png"), CONNECT_ONE_SHOT)
				lg("SHOT ", nm); st(); wait_n = 2; return false
			"quit": quit(0); return false
	for k in hold.keys(): ev(k, false)
	quit(0)
	return false
func lg(a = "", b = "", c = "", d = "", e = "", f = "", g = "", h = "", i = "", j = "") -> void:
	if _lf == null: _lf = FileAccess.open(logf, FileAccess.WRITE)
	_lf.store_line(str(a) + str(b) + str(c) + str(d) + str(e) + str(f) + str(g) + str(h) + str(i) + str(j)); _lf.flush()
