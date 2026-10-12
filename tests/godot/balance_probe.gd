extends "harness.gd"
## 전투 밸런스 측정 프로브 (기획팀, 게임 코드 수정 없음). tests/godot/harness.gd 의 헬퍼를 그대로 쓴다.
##   godot --headless --fixed-fps 60 --path src -s ../tests/godot/balance_probe.gd -- --scn=ttk|boss|econ [--level=pyega1]
## 봇 정책으로 실제 AI·판정·피해식을 태워 "처치 시간·받은 피해·받아넘기기 횟수"를 잰다. 결과 줄은 "RES " 로 시작.
## 시간은 프레임/60 (--fixed-fps 60 이면 time_scale 1 에서 프레임당 1/60초).

var T := 0.0          # 측정용 게임 시간(초)
var rng := RandomNumberGenerator.new()


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--scn="):
			scn = a.get_slice("=", 1)
	G = root.get_node("Game")
	Engine.time_scale = 1.0
	rng.seed = 12345
	seed(12345)
	_main.call_deferred()


func _main() -> void:
	match scn:
		"ttk": await sc_ttk()
		"boss": await sc_boss()
		"econ": await sc_econ()
		"dbg": await sc_dbg()
		"ttk2": await sc_ttk2()
		_: await fail("알 수 없는 프로브: " + scn)


# ---------------------------------------------------------------- 봇 입력
func bot_dir(d: Vector2) -> void:
	for a in ["move_left", "move_right", "move_up", "move_down"]:
		Input.action_release(a)
	if d.length() < 0.1:
		return
	if d.x < -0.3: Input.action_press("move_left")
	if d.x > 0.3: Input.action_press("move_right")
	if d.y < -0.3: Input.action_press("move_up")
	if d.y > 0.3: Input.action_press("move_down")


func bot_release_all() -> void:
	for a in ["move_left", "move_right", "move_up", "move_down", "attack", "roll", "talisman", "song"]:
		Input.action_release(a)


func tap(action: String) -> void:
	Input.action_press(action)
	await process_frame
	Input.action_release(action)


func probe_reset(lv := 2) -> void:
	bot_release_all()
	G.lv = lv
	G.skills = []
	cs_purge()
	var p := player()
	p.max_hp = 1000.0
	p.hp = 1000.0
	p.max_ki = 100.0
	p.ki = 100.0
	p.shinmyeong = 0.0
	p.hurt_t = 0.0
	p.gentle_hits = 0
	p.shield = 0
	p.stun_t = 0.0
	p.slow_t = 0.0
	p.pull_t = 0.0
	p.parry_bonus = false
	p._parry_cd = 0.0
	p._roll_lock_t = 0.0
	p.ult_t = 0.0
	Engine.time_scale = 1.0


# ================================================================ ttk: 적 1마리 × 정책
## 정책: tap(탭만) · rollspam(구르기 가능하면 항상) · reader(예고를 읽고 구르기) · charge(항상 충전 후 놓기)
##       guard(수호부 후 탭) · bind_tap(결박부 후 탭) · fire_bind(결박+화염 후 탭)
func sc_ttk() -> void:
	await cs_setup()
	var p := player()
	var kinds := ["dog", "ghoul", "sea", "mulgwi", "maiden_ghost", "egg_ghost", "mama"]
	var policies := ["tap", "rollspam", "reader", "charge", "guard", "bind_tap"]
	var n := 5
	for kind in kinds:
		for pol in policies:
			var wins := 0
			var ttk_sum := 0.0
			var dmg_sum := 0.0
			var hits_sum := 0
			var parry_sum := 0
			var stagger_hit_sum := 0
			for i in n:
				var r: Dictionary = await run_ttk(kind, pol, 40.0)
				if r["win"]:
					wins += 1
					ttk_sum += r["t"]
				dmg_sum += r["dmg"]
				hits_sum += r["hits"]
				parry_sum += r["parries"]
			print("RES ttk kind=%s pol=%s win=%d/%d ttk=%.1f dmg=%.1f hits=%.1f parries=%.1f" % [kind, pol, wins, n, (ttk_sum / wins if wins > 0 else -1.0), dmg_sum / n, float(hits_sum) / n, float(parry_sum) / n])
	await done()


func run_ttk(kind: String, pol: String, limit: float) -> Dictionary:
	var p := player()
	probe_reset(2)
	await tp(Vector2(270, 290))
	p.facing = "right"
	await tick(3)
	var e = cs_spawn(kind, lvl().lift(Vector2(370, 290)))
	if kind == "mulgwi":
		e.position = lvl().lift(Vector2(330, 290))
	e.state = "chase"
	var t0 := 0.0
	var hp0: float = p.hp
	var hits := 0
	var parries := 0
	var last_hp: float = p.hp
	var last_pcd := 0.0
	var win := false
	var tt := 0.0
	var rolled_for := -1
	if pol == "guard":
		p.ki = 100.0; p.shield = 1; p.shield_t = 10.0
	if pol == "bind_tap":
		p.ki = 100.0
		p.current_talisman()   # no-op; 결박부 직접 설치
		var z = load("res://scripts/fx/talisman_zone.gd").new()
		z.kind = "bind"; z.radius = 40.0; z.life = 8.0
		z.position = e.position
		lvl().add_child(z)
	var charging := false
	var frame_n := 0
	while tt < limit:
		await process_frame
		frame_n += 1
		tt += 1.0 / 60.0 * Engine.time_scale
		if not is_instance_valid(e) or e.state == "downed" or e.state == "dead":
			win = true
			break
		if p.hp < last_hp - 0.01:
			hits += 1
		last_hp = p.hp
		if p._parry_cd > 0.0 and last_pcd <= 0.0:
			parries += 1
		last_pcd = p._parry_cd
		var to: Vector2 = e.global_position - p.global_position
		var d := to.length()
		match pol:
			"tap", "guard", "bind_tap":
				_approach_and_tap(to, d, frame_n)
			"charge":
				_approach_and_charge(to, d)
			"rollspam":
				if p.state == "roll" or p._roll_lock_t > 0.0 or p.state == "attack":
					pass
				bot_dir(to.normalized())
				if p.state == "move" and p._roll_lock_t <= 0.0 and frame_n % 2 == 0:
					Input.action_press("roll")
				else:
					Input.action_release("roll")
				if d < 34.0 and frame_n % 6 == 0:
					Input.action_press("attack")
				else:
					Input.action_release("attack")
			"reader":
				_reader(e, to, d, frame_n)
	bot_release_all()
	var dmg: float = hp0 - p.hp
	if is_instance_valid(e):
		e.queue_free()
	await tick(2)
	return {"win": win, "t": tt, "dmg": dmg, "hits": hits, "parries": parries}


func _approach_and_tap(to: Vector2, d: float, frame_n: int) -> void:
	var p := player()
	if d > 30.0:
		bot_dir(to.normalized())
		Input.action_release("attack")
	else:
		bot_dir(Vector2.ZERO)
		if frame_n % 8 == 0:
			Input.action_press("attack")
		else:
			Input.action_release("attack")


func _approach_and_charge(to: Vector2, d: float) -> void:
	var p := player()
	if d > 36.0 and p.state != "charge":
		bot_dir(to.normalized())
		Input.action_release("attack")
	else:
		bot_dir(Vector2.ZERO)
		Input.action_press("attack")   # 눌러 두면: 1타 → 충전 대기 → 충전 → (놓을 때까지)
		if p.state == "charge" and p._charge_c >= 0.95:
			Input.action_release("attack")


func _reader(e, to: Vector2, d: float, frame_n: int) -> void:
	var p := player()
	var st: String = e.state
	var want_roll := false
	# 예고(tell)가 끝나 타격(strike)이 시작되는 순간 구른다 — 접촉형은 받아넘기기 창에 맞는다
	if p.state != "roll" and p._roll_lock_t <= 0.0:
		if st == "strike" and d < 90.0:
			want_roll = true
		elif st == "tell" and e.cfg["tell"] - e.st < 0.07 and d < 110.0:
			want_roll = true
	if want_roll:
		bot_dir(to.normalized())
		Input.action_press("roll")
		return
	Input.action_release("roll")
	# 후딜(stagger)·idle 이면 달려들어 친다. 타격 중·예고 중에는 간격을 둔다
	if st in ["tell", "strike"]:
		bot_dir(Vector2.ZERO)
		Input.action_release("attack")
		return
	_approach_and_tap(to, d, frame_n)


# ================================================================ boss
## 역신 전투 봇. skill: 0=완벽한 리더 … 1=전혀 안 읽음. miss = 각 예고를 놓칠 확률.
func sc_boss() -> void:
	var pols := [["tap", 1.0, false], ["reader", 0.0, false], ["reader", 0.3, false], ["reader", 0.5, false], ["reader", 0.7, false], ["reader", 0.0, true], ["reader", 0.4, true]]
	var boss = await cs_wake_boss()
	var n := 6
	for spec in pols:
		var wins := 0
		var deaths_sum := 0
		var t_sum := 0.0
		var p1_sum := 0.0
		var p2_sum := 0.0
		for i in n:
			var r: Dictionary = await run_boss(boss, spec[0], spec[1], spec[2], 600.0)
			deaths_sum += r["deaths"]
			if r["win"]:
				wins += 1
				t_sum += r["t_total"]
				p1_sum += r["t_p1"]
				p2_sum += r["t_p2"]
		print("RES boss pol=%s miss=%.1f charge=%s win=%d/%d deaths/clear=%.2f t_total=%.0f t_p1=%.0f t_p2=%.0f" % [spec[0], spec[1], str(spec[2]), wins, n, float(deaths_sum) / n, (t_sum / wins if wins > 0 else -1.0), (p1_sum / wins if wins > 0 else -1.0), (p2_sum / wins if wins > 0 else -1.0)])
	await done()


func run_boss(boss, pol: String, miss: float, use_charge: bool, limit: float) -> Dictionary:
	var p := player()
	probe_reset(3)
	p.max_hp = G.max_hp()
	p.hp = p.max_hp
	var home: Vector2 = boss.home_pos if boss.home_pos != Vector2.ZERO else boss.position
	boss.reset_fight()
	boss._begin("idle")
	await tick(2)
	var deaths := 0
	var tt := 0.0
	var t_p1 := 0.0
	var t_p2 := 0.0
	var p2_start := -1.0
	var frame_n := 0
	var last_state := ""
	var decisions := {}      # 패턴 인스턴스별로 "읽었는가" 를 한 번만 정한다
	var key_prev := ""
	var win := false
	var fogs_dodging := false
	while tt < limit:
		await process_frame
		frame_n += 1
		tt += 1.0 / 60.0 * Engine.time_scale
		if boss.state in ["kneel", "dead"]:
			win = true
			break
		if p.state == "dead" or p.hp <= 0.0:
			deaths += 1
			# 게임 규칙(CS-12): 입구 부활, 보스 HP·페이즈 초기화, 졸개 제거
			p.state = "move"
			p.hp = p.max_hp
			p.hurt_t = 0.0
			p.locked = false
			p.invuln = false
			boss.reset_fight()
			boss.position = home
			p.position = boss.position + Vector2(-110, 0)
			p.ki = 40.0
			p.shinmyeong = 0.0
			p2_start = -1.0
			await tick(3)
			continue
		if boss.phase == 2 and p2_start < 0.0:
			p2_start = tt
		var to: Vector2 = boss.global_position - p.global_position
		var d := to.length()
		# 패턴 인스턴스 키
		var key := "%s_%d_%d" % [boss.state, boss.pat_i, boss.coughs]
		if key != key_prev:
			key_prev = key
			decisions[key] = rng.randf() >= miss      # true = 읽었다
		var read: bool = decisions.get(key, true)
		var st: String = boss.state
		var fast := 1.35 if boss.phase == 2 else 1.0
		# 졸개(역귀)가 있으면 그쪽을 먼저 친다 (가까운 것)
		var nearest = null
		var nd := 1e9
		for e in get_nodes_in_group("enemy"):
			if e != boss and e.get("kind") != null and e.state != "downed":
				var dd: float = (e.global_position - p.global_position).length()
				if dd < nd:
					nd = dd; nearest = e
		# ----- 안개: 읽었다면 안개 중심에서 벗어난다
		var in_fog := false
		for f in get_nodes_in_group("fog"):
			if f.global_position.distance_to(p.global_position) < 30.0:
				in_fog = true
				var away: Vector2 = (p.global_position - f.global_position).normalized()
				if rng.randf() >= miss or pol == "reader":
					if read:
						bot_dir(away)
		if in_fog and read and pol == "reader":
			continue
		# ----- 기침 읽기: 숨결이 나가기 직전(0.1초 전) 구르기 → 받아넘기기 (읽었을 때), 못 읽으면 그대로 서 있는다
		if st == "cough" and pol == "reader" and read and p.state != "roll" and p._roll_lock_t <= 0.0:
			var left: float = 1.0 / fast - boss.st
			if left < 0.1 and left > -0.01 and d < 130.0:
				bot_dir((boss.global_position - p.global_position).normalized())
				Input.action_press("roll")
				continue
		Input.action_release("roll")
		# ----- 펄스 읽기: 붙어 있으면 1.6초 규칙. 붙은 시간이 1.2초를 넘으면 한 걸음 빠진다
		# ----- 공격: 졸개 우선, 아니면 역신. 열림(open)이면 강 베기(충전)를 쓴다
		var tgt = nearest if (nearest != null and nd < 70.0) else boss
		var tto: Vector2 = tgt.global_position - p.global_position
		var td := tto.length()
		var closing: bool = boss.close_t > 1.0 and tgt == boss
		if closing and pol == "reader":
			bot_dir(-tto.normalized())
			Input.action_release("attack")
			continue
		if use_charge and tgt == boss and st == "open" and p.state != "slash":
			# 열림 직전/중에 충전: 충전은 0.45+0.9 = 1.35초 이므로 열림이 길지 않아 반충전(≈0.8~1.0)에서 놓는다
			if td > 34.0:
				bot_dir(tto.normalized())
			else:
				bot_dir(Vector2.ZERO)
				Input.action_press("attack")
				if p.state == "charge" and p._charge_c >= 0.5:
					Input.action_release("attack")
			continue
		if td > 36.0:
			bot_dir(tto.normalized())
			Input.action_release("attack")
		else:
			bot_dir(Vector2.ZERO)
			if frame_n % 8 == 0:
				Input.action_press("attack")
			else:
				Input.action_release("attack")
	bot_release_all()
	var t_total := tt
	if p2_start > 0.0:
		t_p1 = p2_start
		t_p2 = tt - p2_start
	else:
		t_p1 = tt
	# 정화 전 정리: 무릎 꿇은 보스를 되돌린다
	if win:
		boss.reset_fight()
		boss.state = "idle"
	await tick(3)
	return {"win": win, "deaths": deaths, "t_total": t_total, "t_p1": t_p1, "t_p2": t_p2}


# ================================================================ econ: 소리·신명 흐름 곡선 (정책 reader, 폐가 6마리를 순서대로)
func sc_econ() -> void:
	await cs_setup()
	var p := player()
	var order := ["dog", "ghoul", "dog", "ghoul", "mulgwi", "maiden_ghost"]
	probe_reset(2)
	p.max_hp = 106.0
	p.hp = 106.0
	p.ki = 100.0
	await tp(lvl().def["spawns"]["start"])
	var tt := 0.0
	var next_log := 0.0
	for kind in order:
		var e = cs_spawn(kind, p.position + Vector2(90, 0))
		e.state = "chase"
		var fn := 0
		while is_instance_valid(e) and e.state != "downed" and tt < 400.0:
			await process_frame
			fn += 1
			tt += 1.0 / 60.0
			var to: Vector2 = e.global_position - p.global_position
			if p.hp <= 20.0:
				p.hp = p.max_hp
			_reader(e, to, to.length(), fn)
			if tt >= next_log:
				next_log += 5.0
				print("RES econ t=%.0f kind=%s hp=%.0f ki=%.0f sin=%.0f" % [tt, kind, p.hp, p.ki, p.shinmyeong])
		bot_release_all()
		# 노래로 정화
		if is_instance_valid(e) and e.state == "downed":
			p.position = e.position + Vector2(-14, 4)
			await tick(2)
			var ki0: float = p.ki
			var hp0: float = p.hp
			await sing_now()
			print("RES econ_purify kind=%s ki+%.0f hp+%.0f t=%.1f" % [kind, p.ki - ki0, p.hp - hp0, tt])
	await done()


func sc_dbg() -> void:
	await cs_setup()
	var p := player()
	probe_reset(2)
	await tp(Vector2(270, 290))
	var e = cs_spawn("dog", lvl().lift(Vector2(370, 290)))
	e.state = "chase"
	for i in 300:
		await process_frame
		if i % 30 == 0:
			var to: Vector2 = e.global_position - p.global_position
			print("RES dbg i=%d p.state=%s locked=%s pos=%s e.state=%s epos=%s d=%.0f ehp=%d php=%.0f ts=%.2f" % [i, p.state, str(p.locked), str(p.position), e.state, str(e.position), to.length(), e.hp, p.hp, Engine.time_scale])
		_approach_and_tap(e.global_position - p.global_position, (e.global_position - p.global_position).length(), i)
	await done()


## 공격적 적(cd=0, 가까이서 시작)과 무리 — 실제 교전처럼 적이 먼저 선공권을 갖는 경우
func sc_ttk2() -> void:
	await cs_setup()
	var packs := [["dog"], ["ghoul"], ["sea"], ["mulgwi"], ["maiden_ghost"], ["egg_ghost"], ["mama"], ["dog", "ghoul", "dog"], ["ghoul", "egg_ghost", "maiden_ghost"], ["mama", "ghoul", "ghoul"]]
	var policies := ["tap", "rollspam", "reader", "guard", "bind_tap", "lag_tap"]
	var n := 6
	for pack in packs:
		for pol in policies:
			var wins := 0
			var ttk_sum := 0.0
			var dmg_sum := 0.0
			var hits_sum := 0
			var parry_sum := 0
			var dmax := 0.0
			for i in n:
				var r: Dictionary = await run_pack(pack, pol, 40.0)
				if r["win"]:
					wins += 1
					ttk_sum += r["t"]
				dmg_sum += r["dmg"]
				dmax = maxf(dmax, r["dmg"])
				hits_sum += r["hits"]
				parry_sum += r["parries"]
			print("RES ttk2 pack=%s pol=%s win=%d/%d ttk=%.1f dmg=%.1f dmgmax=%.0f hits=%.1f parries=%.1f" % ["+".join(pack), pol, wins, n, (ttk_sum / wins if wins > 0 else -1.0), dmg_sum / n, dmax, float(hits_sum) / n, float(parry_sum) / n])
	await done()


func run_pack(pack: Array, pol: String, limit: float) -> Dictionary:
	var p := player()
	probe_reset(2)
	await tp(Vector2(270, 290))
	p.facing = "right"
	await tick(3)
	var foes := []
	var k := 0
	for kind in pack:
		var e = cs_spawn(kind, lvl().lift(Vector2(330 + 18 * k, 270 + 28 * k)))
		e.state = "chase"
		e.cd = 0.0 + 0.15 * k
		if kind == "mulgwi":
			e.position = lvl().lift(Vector2(320, 290))
		foes.append(e)
		k += 1
	var hp0: float = p.hp
	var hits := 0
	var parries := 0
	var last_hp: float = p.hp
	var last_pcd := 0.0
	var win := false
	var tt := 0.0
	var fn := 0
	if pol == "guard":
		p.shield = 1; p.shield_t = 10.0
	if pol == "bind_tap":
		var z = load("res://scripts/fx/talisman_zone.gd").new()
		z.kind = "bind"; z.radius = 40.0; z.life = 8.0
		z.position = lvl().lift(Vector2(335, 280))
		lvl().add_child(z)
	var react := 0.0
	while tt < limit:
		await process_frame
		fn += 1
		tt += 1.0 / 60.0 * Engine.time_scale
		var alive := foes.filter(func(e): return is_instance_valid(e) and e.state != "downed" and e.state != "dead")
		if alive.is_empty():
			win = true
			break
		if p.hp < last_hp - 0.01:
			hits += 1
		last_hp = p.hp
		if p._parry_cd > 0.0 and last_pcd <= 0.0:
			parries += 1
		last_pcd = p._parry_cd
		var e = alive[0]
		var nd := 1e9
		for a in alive:
			var dd: float = (a.global_position - p.global_position).length()
			if dd < nd:
				nd = dd; e = a
		var to: Vector2 = e.global_position - p.global_position
		var d := to.length()
		match pol:
			"tap", "guard", "bind_tap":
				_approach_and_tap(to, d, fn)
			"lag_tap":
				# 사람 같은 반응 지연: 새 적이 30px 안에 들어온 뒤 0.35초 후에야 공격을 시작한다
				if d < 40.0:
					react += 1.0 / 60.0
				else:
					react = 0.0
				if react < 0.35:
					bot_dir(to.normalized() if d > 36.0 else Vector2.ZERO)
					Input.action_release("attack")
				else:
					_approach_and_tap(to, d, fn)
			"rollspam":
				bot_dir(to.normalized())
				if p.state == "move" and p._roll_lock_t <= 0.0 and fn % 2 == 0:
					Input.action_press("roll")
				else:
					Input.action_release("roll")
				if d < 34.0 and fn % 6 == 0:
					Input.action_press("attack")
				else:
					Input.action_release("attack")
			"reader":
				_reader(e, to, d, fn)
	bot_release_all()
	var dmg: float = hp0 - p.hp
	for a in foes:
		if is_instance_valid(a):
			a.queue_free()
	await tick(2)
	return {"win": win, "t": tt, "dmg": dmg, "hits": hits, "parries": parries}
