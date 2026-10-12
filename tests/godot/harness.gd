extends SceneTree
## 1장 시나리오 회귀 하네스 (QA). 헤드리스 Godot에서 `-s` 로 실행한다. 게임 코드는 수정하지 않는다.
##   godot --headless --fixed-fps 60 --path src -s ../tests/godot/harness.gd -- --scn=<이름> [게임 인자]
## 시나리오: chain · save_mid · continue_mid · corrupt_save · death · boss_retry
## 원칙: 실제 게임 경로(Story 트리거·대사·change_level·세이브)를 그대로 태운다.
##   하네스가 대신하는 것은 입력뿐이다 — 대사 넘기기(confirm 연타), 순간이동(트리거/출구/NPC 앞),
##   전투(Enemy/PlagueGod.take_hit 호출), 노래(Player.sing()). 이 대체는 docs/qa/ 커버리지 표에 명시한다.
## 규칙: 실패는 "FAIL:" 줄을 찍고 비-0으로 종료. 끝까지 가면 "SCN_RESULT <이름> PASS".

signal _halt   # 절대 emit 안 함 — 실패 후 코루틴을 멈춰 두는 용도

const BOSS_MAX := 480.0   # PlagueGod.MAX_HP (클래스를 직접 참조하면 오토로드 등록 전에 컴파일되어 실패)
const SPEED := 4.0          # Engine.time_scale (대사·페이드·카드가 실시간이라 가속)
var scn := ""
var G: Node                 # autoload Game
var frame := 0
var god := false            # 플레이어 체력 고정 (전투 시나리오에서 입력 대체)
var pump := false           # 대사/선택 confirm 연타
var _finished := false
var steps := 0
var soft_fails: Array[String] = []


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--scn="):
			scn = a.get_slice("=", 1)
	G = root.get_node("Game")
	Engine.time_scale = SPEED
	_main.call_deferred()


func _process(_d: float) -> bool:
	frame += 1
	if pump and frame % 4 == 0:
		_tap("confirm")
	if god:
		var p := player()
		if p != null and p.get("hp") != null and p.state != "dead":
			p.hp = p.max_hp
	return false


# ---------------------------------------------------------------- helpers
func _tap(action: String) -> void:
	var ev := InputEventAction.new()
	ev.action = action
	ev.pressed = true
	Input.parse_input_event(ev)
	var up := InputEventAction.new()
	up.action = action
	up.pressed = false
	Input.parse_input_event(up)


func fail(msg: String) -> void:
	print("FAIL: [%s] %s  (frame %d, level %s)" % [scn, msg, frame, G.level_id])
	_finished = true
	quit(1)
	await _halt


func step(label: String) -> void:
	steps += 1
	print("STEP %02d %s" % [steps, label])


func must(cond: bool, label: String) -> void:
	if cond:
		print("  ok   ", label)
	else:
		await fail("검증 실패: " + label)


## 실패해도 계속 가는 검증 (끝에서 비-0)
func expect(cond: bool, label: String) -> void:
	if cond:
		print("  ok   ", label)
	else:
		print("  FAIL ", label)
		soft_fails.append(label)


func until(cond: Callable, label: String, max_frames := 4000) -> void:
	var i := 0
	while not cond.call():
		await process_frame
		i += 1
		if i % 1500 == 0:
			print("  ...   기다리는 중: ", label, " (", i, "프레임, 장면 ", scene_name(), ")")
		if i > max_frames:
			await fail("시간 초과: " + label)
	print("  ok   ", label, "  (", i, "프레임)")


## 알려진 결함: 실패해도 종료 코드에 영향 없음. 고쳐져서 통과하면 알려 준다(→ expect 로 승격할 것).
var known_open := 0
func known(cond: bool, label: String) -> void:
	if cond:
		print("  FIXED? ", label, "  -- 이제 통과: expect 로 승격하세요")
	else:
		known_open += 1
		print("  KNOWN-BUG ", label)


func done() -> void:
	if not soft_fails.is_empty():
		print("FAIL: [%s] 소프트 검증 %d건 실패" % [scn, soft_fails.size()])
		_finished = true
		quit(1)
		await _halt
	print("SCN_RESULT %s PASS (%d steps, known-bugs %d)" % [scn, steps, known_open])
	_finished = true
	quit(0)


func scene_name() -> String:
	return current_scene.scene_file_path.get_file() if current_scene else ""


func lvl() -> Node:
	var s := current_scene
	if s != null and s.get("def") != null and s.get_node_or_null("Player") != null and s.get("hud") != null:
		return s
	return null


func player() -> Node:
	var l := lvl()
	return l.get_node("Player") if l else null


## 새로 로드된 레벨 (같은 id 로 다시 불러온 경우도 구분하려고 이전 인스턴스 id 를 받는다)
func level_ready(id: String, old_instance := 0) -> bool:
	var l := lvl()
	return l != null and G.level_id == id and not G._busy and l.get_instance_id() != old_instance


func level_iid() -> int:
	return current_scene.get_instance_id() if current_scene else 0


func boot(path: String) -> void:
	await process_frame
	change_scene_to_file(path)
	await process_frame
	await process_frame


func boot_level() -> void:
	await boot("res://scenes/level.tscn")
	await until(func(): return lvl() != null, "레벨 로드", 300)
	await tick(2)


func tick(n := 1) -> void:
	for i in n:
		await process_frame


func tp(footprint: Vector2) -> void:
	player().position = lvl().lift(footprint)
	await tick(3)


## 레벨 정의의 gates(이야기가 여는 출구)·exits 의 중심 (좌표를 하드코딩하지 않는다: 아트팀이 지형을 바꿔도 따라간다)
func gate_center(name: String) -> Vector2:
	var r: Rect2 = lvl().def["gates"][name][0]
	return r.get_center()


func exit_center(i: int) -> Vector2:
	var r: Rect2 = lvl().def["exits"][i][0]
	return r.get_center()


func tp_raw(p: Vector2) -> void:
	player().position = p
	await tick(3)


func tp_to_interact(id: String) -> void:
	for ip in lvl().interact_points:
		if ip["id"] == id:
			player().position = ip["pos"]
			await tick(2)
			return
	await fail("상호작용 지점 없음: " + id)


func tp_to_npc(id: String, off := Vector2(-18, 4)) -> void:
	var n = lvl().npc(id)
	if n == null:
		await fail("NPC 없음: " + id)
	player().position = n.position + off
	await tick(2)


## 앞에 있는 것에게 말 걸기/조사 (플레이어 입력 훅 그대로)
func interact(id: String) -> void:
	var t: Dictionary = lvl().nearest_interactable()
	if t.is_empty() or t["id"] != id:
		await fail("가까운 상호작용 대상이 %s 이어야 함 (실제: %s)" % [id, str(t.get("id", "없음"))])
	await must(lvl()._try_interact(), "%s 에게 상호작용" % id)


func free_player() -> void:
	await until(func(): return player() != null and not player().locked and player().state == "move", "플레이어 조작 가능", 3000)


func sing_now() -> void:
	await until(func(): return player().state == "move", "노래 가능 상태", 600)
	player().sing()
	await tick(2)
	await until(func(): return player().state == "move", "노래 끝", 600)


## 방 안의 요괴를 전부 쓰러뜨리고(take_hit) 노래로 정화한다 — 한풀이 경로까지 탄다
func clear_room() -> void:
	for round in 6:
		var foes: Array = get_nodes_in_group("enemy").filter(func(e): return e.get("kind") != null and not e.is_clone)
		if foes.is_empty() and get_nodes_in_group("downed").filter(func(e): return e.get("kind") != null).is_empty():
			break
		for e in foes:
			if is_instance_valid(e):
				e.take_hit(9999, Vector2.ZERO)
		await tick(2)
		for d in get_nodes_in_group("downed").filter(func(e): return e.get("kind") != null and e.state == "downed"):
			if is_instance_valid(d) and d.state == "downed":
				player().position = d.position + Vector2(-14, 4)
				await tick(2)
				await sing_now()
	await must(get_nodes_in_group("enemy").filter(func(e): return e.get("kind") != null and not e.is_clone).is_empty(), "방의 요괴 소탕")


func save_text() -> String:
	return FileAccess.get_file_as_string("user://save.json")


func save_flags() -> Dictionary:
	var d = JSON.parse_string(save_text())
	return d.get("flags", {}) if typeof(d) == TYPE_DICTIONARY else {}


func title_actions() -> Array:
	return current_scene.get("_actions") if scene_name() == "title.tscn" else []


# ---------------------------------------------------------------- 시나리오 진입
func _main() -> void:
	match scn:
		"chain": await sc_chain()
		"save_mid": await sc_save_mid()
		"continue_mid": await sc_continue_mid()
		"corrupt_save": await sc_corrupt_save()
		"death": await sc_death()
		"boss_retry": await sc_boss_retry()
		_:
			await fail("알 수 없는 시나리오: " + scn)


# ================================================================ chain: 타이틀 → 1절 → 타이틀
func sc_chain() -> void:
	step("타이틀 (세이브 없음)")
	await boot("res://scenes/title.tscn")
	await until(func(): return scene_name() == "title.tscn" and current_scene.get("_ready_t") > 0.9, "타이틀 준비", 600)
	await must(not G.has_save(), "깨끗한 데이터 디렉터리: 세이브 없음")
	await must(title_actions() == ["new"], "메뉴는 '처음부터' 하나 (이어하기 없음)")

	step("처음부터 → 인트로 (SC 오프닝, 끝까지 재생)")
	_tap("confirm")
	pump = true   # 인트로의 용궁 대사를 넘긴다
	await until(func(): return scene_name() == "intro.tscn", "인트로 장면 진입", 600)
	await until(func(): return level_ready("beach"), "인트로 완주 → 개운포", 9000)
	god = true

	step("SC1-01 백사장 기상")
	await until(func(): return player().state == "move" and not player().locked, "기상 연출 끝, 조작 가능", 1500)
	await must(G.flag("logo_shown") == 1, "타이틀 로고 카드가 나갔다")

	step("SC1-03/04 피리 → 요괴 출현")
	await tp_to_interact("flute")
	await interact("flute")
	await until(func(): return lvl().get_node_or_null("Gaetgwi") != null, "갯귀 출현", 600)
	await must(G.flag("flute") == 1, "피리 획득 플래그")
	await until(func(): return not player().locked, "마을 사람 대사 끝", 1500)

	step("SC1-05 첫 전투 → 정화 (노래)")
	await tp(lvl().def["anchors"]["fight_player"])
	await until(func(): return lvl().hud._guide == "attack", "전투 튜토리얼 안내(베기 버튼)", 300)
	var yokai = lvl().get_node("Gaetgwi")
	yokai.take_hit(9999, Vector2.ZERO)
	await until(func(): return yokai.state == "downed", "갯귀 쓰러짐(탁기)", 120)
	await must(lvl().hud._guide == "song", "노래 버튼 안내로 전환")
	player().position = yokai.position + Vector2(-14, 4)
	await tick(2)
	await sing_now()
	await until(func(): return yokai.state == "dead" or not is_instance_valid(yokai), "갯귀 정화", 300)

	step("SC1-06/07 환호·수령 → 경주")
	await until(func(): return level_ready("gyeongju"), "경주 변두리 도착", 4000)
	await must(G.flag("beach_done") == 1 and G.flag("arrived") == 1, "beach_done/arrived")
	await must(G.checkpoint == "gyeongju", "체크포인트 = 경주")

	step("SC1-08 난영 첫 만남")
	await free_player()
	await tp_to_npc("nanyeong")
	await interact("nanyeong")
	await until(func(): return G.flag("met_nanyeong") == 1 and not player().locked, "난영 대화 완료", 2000)

	step("SC1-09 병든 아이 → 노래로 치유")
	var child = lvl().npc("child")
	await must(child.visible and child.is_in_group("downed"), "아이가 탁기에 들어 있다(노래 대상)")
	player().position = child.position + Vector2(-16, 6)
	await tick(2)
	await sing_now()
	await until(func(): return G.flag("sang_child") == 1 and not player().locked, "아이 치유 후 난영 대사 끝", 3000)

	step("SC1-10 휴식 → 혼례 컷 → 밤 (세이브)")
	var iid := level_iid()
	await tp_to_interact("home")
	await interact("home")
	await until(func(): return G.flag("married") == 1, "혼례 플래그", 3000)
	await until(func(): return level_ready("gyeongju", iid), "경주(밤) 재진입", 3000)
	await must(G.flag("night") == 1, "밤 플래그")
	await must(save_flags().get("married", 0) == 1, "디스크 세이브에 married 기록")

	step("SC1-11 밤 · 관아 사람의 호출")
	await until(func(): return G.flag("summoned") == 1 and not player().locked, "관아 사람 호출 대사 끝", 3000)
	iid = level_iid()
	await tp(gate_center("gwana"))
	await until(func(): return level_ready("gwana", iid), "관아 도착(출구 이동)", 1500)

	step("SC1-12 관아 의뢰 + 난영 쓰러짐")
	await free_player()
	await tp_to_npc("gwanri")
	await interact("gwanri")
	await until(func(): return G.flag("briefed") == 1 and not player().locked, "의뢰 대사·일꾼 소식 끝", 3000)
	await must(G.flag("nanyeong_fallen") == 1, "난영 쓰러짐 플래그")
	await must(int(G.items["insam"]) >= 4, "관아 지급 인삼정기탕 +2 (2→4)")
	iid = level_iid()
	await tp(lvl().def["anchors"]["exit"])
	await until(func(): return level_ready("gyeongju", iid), "경주 복귀(관아 출구)", 1500)

	step("SC1-13 경주 → 서쪽 폐가 (마당)")
	await free_player()
	iid = level_iid()
	await tp(gate_center("pyega"))
	await until(func(): return level_ready("pyega1", iid), "폐가 마당 도착", 1500)
	await clear_room()

	step("SC1-14 폐가 다락")
	iid = level_iid()
	await tp(exit_center(1))
	await until(func(): return level_ready("pyega2", iid), "폐가 다락 도착", 1500)
	var boss = lvl().get_node("Boss")
	await must(boss.state == "wait", "역신은 사람 모습으로 앉아 있다(wait)")
	await clear_room()
	await tp(Vector2(420, 190))   # trigger close
	await until(func(): return not player().locked, "'가깝다' 연출 끝", 1500)

	step("SC1-15~17 최심부 · 역신 각성")
	await tp(Vector2(562, 190))   # trigger inner
	await until(func(): return boss.state == "idle", "역신 각성", 3000)
	await until(func(): return not player().locked, "각성 후 조작 가능", 600)

	step("SC1-18 2페이즈")
	boss.take_hit(int(boss.hp - BOSS_MAX * 0.5) + 1, Vector2.ZERO)
	await until(func(): return boss.phase == 2, "2페이즈 진입", 120)
	await until(func(): return boss.state == "idle", "2페이즈 대사 후 전투 재개", 1500)

	step("SC1-19 무릎 꿇음")
	boss.take_hit(int(boss.hp) + 1, Vector2.ZERO)
	await until(func(): return boss.state == "kneel", "역신 무릎 꿇음", 120)
	await until(func(): return lvl().hud._guide == "song", "유언 대사 후 노래 안내", 1500)

	step("SC1-20 정화 → 난영 구원 → 새벽")
	player().position = boss.position + Vector2(-30, 8)
	await tick(2)
	await sing_now()
	await until(func(): return G.flag("boss_done") == 1, "보스 격파 플래그", 600)
	await must("역신의 눈물" in G.accessories, "장신구 「역신의 눈물」 획득")
	await must(G.dogam.has("plague_god"), "도감 등록 plague_god")
	await until(func(): return G.flag("rescued") == 1, "난영 구원 플래그", 1500)
	await must(save_flags().get("rescued", 0) == 1, "디스크 세이브에 rescued 기록")

	step("SC1-20/21 새벽 · 난영 깨어남 → 며칠 뒤")
	await until(func(): return G.flag("rumor") == 1 and level_ready("gyeongju"), "소문 확산, '며칠 뒤' 경주", 5000)
	await must(G.flag("nanyeong_woke") == 1, "난영 깨어남")
	await free_player()

	step("SC1-21 소문 → 처용탈")
	await tp_to_npc("elder")
	await interact("elder")
	await until(func(): return G.tal == "cheoyong" and not player().locked, "처용탈 획득", 3000)

	step("SC1-22 밤 · 왕의 부름 (휴식 → 내관)")
	var iid2 := level_iid()
	await tp_to_interact("home")
	await interact("home")
	await until(func(): return G.flag("king_call") == 1, "king_call 플래그", 1500)
	await until(func(): return level_ready("gyeongju", iid2), "경주(밤) 재진입", 3000)
	iid2 = level_iid()
	await until(func(): return level_ready("palace", iid2), "월성 편전 도착(내관 연출 후)", 4000)

	step("SC1-22~23 편전 · 퇴마어사 임명")
	await free_player()
	iid2 = level_iid()
	await tp(Vector2(256, 228))
	await until(func(): return G.flag("appointed") == 1, "임명 플래그", 3000)
	await until(func(): return level_ready("gyeongju", iid2), "경주 '떠나는 날'", 3000)

	step("SC1-24/25 작별 → 1절 → 타이틀")
	await until(func(): return G.flag("chapter1_done") == 1, "1장 완료 플래그", 6000)
	await must(save_flags().get("chapter1_done", 0) == 1, "디스크 세이브에 chapter1_done 기록")
	pump = false   # 타이틀 메뉴를 confirm 연타가 눌러 버리지 않게
	await until(func(): return scene_name() == "title.tscn" and current_scene.get("_ready_t") > 0.9, "타이틀 복귀", 1500)
	await must("continue" in title_actions(), "타이틀에 '이어하기' 노출")
	await done()


# ================================================================ 세이브/이어하기
## 프로세스 A: 중간 진행 상태를 세이브로 남긴다 (프로세스 재시작 후 B가 이어한다)
func sc_save_mid() -> void:
	step("중간 진행 세이브 작성")
	G.new_game()
	for f in ["beach_done", "arrived", "met_nanyeong", "sang_child"]:
		G.set_flag(f)
	G.money = 77
	G.lv = 3
	G.deok = 11
	G.jeonggi = 42
	G.skills = ["simhae"]
	G.tals = ["cheoyong"]
	G.tal = "cheoyong"
	G.items = {"insam": 5, "gugija": 2, "jeonghwa": 1}
	G.accessories = ["역신의 눈물"]
	G.checkpoint = "gyeongju"
	G.save()
	await must(G.has_save(), "세이브 파일 생성")
	await done()


func sc_continue_mid() -> void:
	step("프로세스 재시작 후 타이틀 → 이어하기")
	await boot("res://scenes/title.tscn")
	await until(func(): return scene_name() == "title.tscn" and current_scene.get("_ready_t") > 0.9, "타이틀 준비", 600)
	await must(G.has_save(), "디스크에 세이브가 남아 있다")
	await must(title_actions().slice(0, 2) == ["new", "continue"], "메뉴: 처음부터 / 이어하기 (인트로를 본 뒤라면 회상이 뒤에 붙는다)")
	_tap("move_down")
	await tick(2)
	_tap("confirm")
	await until(func(): return level_ready("gyeongju"), "경주로 이어하기", 1500)
	await must(G.flag("sang_child") == 1 and G.flag("met_nanyeong") == 1, "진행 플래그 복원")
	await must(G.money == 77 and G.lv == 3 and G.deok == 11 and G.jeonggi == 42, "엽전·레벨·덕망·정기 복원")
	await must(G.tal == "cheoyong" and G.skills == ["simhae"] and G.accessories == ["역신의 눈물"], "탈·수·장신구 복원")
	await must(int(G.items["insam"]) == 5, "소지품 복원")
	await must(absf(player().max_hp - G.max_hp()) < 0.01 and G.max_hp() > 100.0, "최대 체력이 성장치를 반영")
	await must(lvl().def["name"] == "경주 변두리" and G.spawn_name == "start", "낮 체크포인트는 마을 입구(start)")
	step("밤 체크포인트는 집 앞(home)으로 이어진다")
	G.set_flag("night")
	G.save()
	await boot("res://scenes/title.tscn")
	await until(func(): return scene_name() == "title.tscn" and current_scene.get("_ready_t") > 0.9, "타이틀 재진입", 600)
	_tap("move_down")
	await tick(2)
	_tap("confirm")
	await until(func(): return level_ready("gyeongju") and G.spawn_name == "home", "밤 경주(home)로 이어하기", 1500)
	await must(G.flag("night") == 1, "night 복원")
	await done()


func sc_corrupt_save() -> void:
	step("망가진 세이브로 이어하기 — 크래시 없이 시작 지점으로")
	var f := FileAccess.open("user://save.json", FileAccess.WRITE)
	f.store_string("{ this is not json ")
	f.close()
	await boot("res://scenes/title.tscn")
	await until(func(): return scene_name() == "title.tscn" and current_scene.get("_ready_t") > 0.9, "타이틀 준비", 600)
	await must("continue" in title_actions(), "세이브 파일이 있으면 이어하기는 보인다")
	_tap("move_down")
	await tick(2)
	_tap("confirm")
	await until(func(): return lvl() != null and not G._busy, "게임이 열렸다(크래시 없음)", 1500)
	await must(G.level_id == "beach", "읽기 실패 시 백사장(기본 체크포인트)에서 시작")
	await done()


# ================================================================ 사망·리스폰
func sc_death() -> void:
	step("폐가 마당에서 사망 → 리스폰")
	await boot_level()
	await must(G.level_id == "pyega1", "pyega1 직접 진입")
	var p := player()
	var died := [0]
	p.died.connect(func(): died[0] += 1)
	G.money = 123
	G.set_flag("briefed")
	var spawn: Vector2 = p.spawn
	p.position = spawn + Vector2(120, 20)
	await tick(2)
	p.hurt(99999, Vector2.RIGHT)
	await tick(1)
	await must(died[0] == 1 and p.hp == 0.0, "치명타 → died 시그널 1회, 체력 0")
	# 알려진 결함: Player._die() 가 state="dead" 를 세팅한 뒤 _end_attack() 이 state="move" 로 되돌린다
	# (src/scripts/player.gd:441-444). 죽는 연출 동안 조작·피격 판정이 살아 있다. 고쳐지면 아래가 통과 → expect 로 승격.
	known(p.state == "dead", "사망 직후 state == dead (결함: 현재 move)")
	await until(func(): return p.hp == p.max_hp and p.position.distance_to(spawn) < 1.0, "리스폰: 체력 가득·스폰 지점 복귀", 600)
	await must(p.ki == p.max_ki, "기력 가득 회복")
	await must(G.money == 123 and G.flag("briefed") == 1, "사망이 진행도(엽전·플래그)를 지우지 않는다")
	await must(not p.locked and p.state == "move", "조작 잠금 없음")
	step("연속 사망 3회에도 상태가 깨지지 않는다")
	for i in 3:
		await until(func(): return p.hurt_t <= 0.0, "피격 무적 해제 %d" % (i + 1), 300)
		p.position = spawn + Vector2(60, 10)
		await tick(1)
		p.hurt(99999, Vector2.LEFT)
		await until(func(): return died[0] >= i + 2, "사망 %d" % (i + 2), 60)
		await until(func(): return p.hp == p.max_hp and p.position.distance_to(spawn) < 1.0, "리스폰 %d" % (i + 2), 600)
	await must(died[0] >= 4, "died 시그널 누적 4회 이상(죽은 뒤 맞으면 중복 발생 — 위 결함)")
	await done()


# ================================================================ 보스 재도전
func sc_boss_retry() -> void:
	step("보스방 진입 · 역신 각성")
	await boot_level()
	await must(G.level_id == "pyega2", "pyega2 직접 진입")
	god = true
	pump = true
	await clear_room()
	await tp(Vector2(420, 190))
	await until(func(): return not player().locked, "'가깝다' 연출 끝", 1500)
	await tp(Vector2(562, 190))
	var boss = lvl().get_node("Boss")
	await until(func(): return boss.state == "idle", "역신 각성", 3000)
	await until(func(): return not player().locked, "조작 가능", 600)
	# 보스방 문(add_barrier)이 실제로 막는가: 트리거 콜백 안에서 만들어져 엔진이 "Can't change this state while flushing queries"를 찍는다
	await tp(Vector2(520, 190))
	var blocked: bool = player().test_move(player().global_transform, Vector2(40, 0))
	expect(blocked, "보스방 봉쇄벽이 입구를 막는다 (결함이면 플레이어가 나갈 수 있음)")
	for attempt in 2:
		step("재도전 %d: 보스전 중 사망 → 입구 계단에서 재시작" % (attempt + 1))
		var iid := level_iid()
		god = false
		boss = lvl().get_node("Boss")
		boss.take_hit(100, Vector2.ZERO)   # 일부 피해를 줘도 재도전하면 초기화되어야 한다
		player().hurt(99999, Vector2.RIGHT)
		await until(func(): return level_ready("pyega2", iid), "pyega2 재로드", 1500)
		god = true
		boss = lvl().get_node("Boss")
		await must(boss.state == "wait" and boss.hp == BOSS_MAX, "역신이 사람 모습·만피로 재배치")
		await must(G.flag("boss_done") == 0, "boss_done 미설정")
		await must(player().hp == player().max_hp and not player().locked, "플레이어 체력 가득·조작 가능")
		await must(player().position.distance_to(lvl().lift(lvl().def["spawns"]["start"])) < 2.0, "입구 스폰 위치")
		await clear_room()
		await tp(Vector2(562, 190))
		await until(func(): return boss.state == "idle", "역신 재각성(트리거 재작동)", 3000)
		await until(func(): return not player().locked, "재각성 후 조작 가능", 600)
	step("재도전 뒤에도 격파 경로가 열려 있다")
	boss.take_hit(int(boss.hp - BOSS_MAX * 0.5) + 1, Vector2.ZERO)
	await until(func(): return boss.phase == 2 and boss.state == "idle", "2페이즈 대사 후 전투 재개", 1500)
	boss.take_hit(int(boss.hp) + 1, Vector2.ZERO)
	await until(func(): return boss.state == "kneel", "무릎 꿇음", 600)
	await until(func(): return lvl().hud._guide == "song", "노래 안내", 1500)
	player().position = boss.position + Vector2(-30, 8)
	await tick(2)
	await sing_now()
	await until(func(): return G.flag("boss_done") == 1, "격파 플래그", 600)
	await done()
