extends SceneTree
## 1장 시나리오 회귀 하네스 (QA). 헤드리스 Godot에서 `-s` 로 실행한다. 게임 코드는 수정하지 않는다.
##   godot --headless --fixed-fps 60 --path src -s ../tests/godot/harness.gd -- --scn=<이름> [게임 인자]
## 시나리오: chain · save_mid · continue_mid · corrupt_save · death · boss_retry
## 원칙: 실제 게임 경로(Story 트리거·대사·change_level·세이브)를 그대로 태운다.
##   하네스가 대신하는 것은 입력뿐이다 — 대사 넘기기(confirm 연타), 순간이동(트리거/출구/NPC 앞),
##   전투(Enemy/PlagueGod.take_hit 호출), 노래(Player.sing()). 이 대체는 docs/qa/ 커버리지 표에 명시한다.
## 규칙: 실패는 "FAIL:" 줄을 찍고 비-0으로 종료. 끝까지 가면 "SCN_RESULT <이름> PASS".

signal _halt   # 절대 emit 안 함 — 실패 후 코루틴을 멈춰 두는 용도

const BOSS_MAX := 1000.0   # PlagueGod.MAX_HP = CT.BOSS_HP (클래스를 직접 참조하면 오토로드 등록 전에 컴파일되어 실패)
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
		# ---- 2장 마일스톤 1 smoke (tests/chapter1_playthrough.sh ch2_m1 로 단독 실행; 기본 1장 목록에는 넣지 않는다)
		"ch2_m1": await sc_ch2_m1()
		# ---- 2장 마일스톤 2 (old_village·den1~3, tests/chapter1_playthrough.sh ch2_m2): 실제 걷기 + 정화 경로, tp 는 레벨 이동(출구 중심)에만
		"ch2_m2": await sc_ch2_m2()
		# ---- 2장 진입 검증(prog/ch2-enter): ch2_farewell·ch2_continue 는 --ch2 로, ch2_off_continue 는 인자 없이(꺼짐) 실행
		"ch2_farewell": await sc_ch2_farewell()
		"ch2_continue": await sc_ch2_continue()
		"ch2_off_continue": await sc_ch2_off_continue()
		# ---- 전투 전략(combat-strategy) 시나리오: tests/combat_strategy.sh 로 실행 (기본 chapter1 목록과 분리)
		"cs_parry": await sc_cs_parry()
		"cs_charge": await sc_cs_charge()
		"cs_guard": await sc_cs_guard()
		"cs_targeting": await sc_cs_targeting()
		"cs_economy": await sc_cs_economy()
		"cs_boss": await sc_cs_boss()
		"cs_deaths": await sc_cs_deaths()
		"cs_wave": await sc_cs_wave()
		"cs_aura": await sc_cs_aura()
		"cs_tutorial": await sc_cs_tutorial()
		"cs_cover": await sc_cs_cover()
		_:
			await fail("알 수 없는 시나리오: " + scn)


# ================================================================ chain: 타이틀 → 1절 → 타이틀
## 목표·마커(design/gdd/objective-marker.md T3): 현재 레벨의 목표 id 가 기대와 같아질 때까지 기다렸다가 OBJ 로그를 찍는다.
## 레벨 간 stale 검사 — id 의 레벨 접두(ch1.<레벨>.)가 현재 레벨과 같아야 한다 (이전 레벨 좌표를 들고 있지 않다는 뜻).
var toasts: Array = []
func obj_expect(id: String, label := "") -> void:
	await until(func(): return lvl() != null and str(lvl()._obj.get("id", "")) == id, "목표 → " + id + (" " + label if label != "" else ""), 600)
	var o: Dictionary = lvl()._obj
	print("OBJ %s %s '%s' target=%s kind=%s" % [G.level_id, o["id"], o["text"], str(o["target"]), o["kind"]])
	await must(String(o["id"]).begins_with("ch1.%s." % G.level_id), "목표 id 가 현재 레벨 것 (stale 아님): " + id)
	if o["text"] != "":
		await must(String(o["text"]).length() <= 18, "문구 18자 이하: " + String(o["text"]))


func toast_count(text: String) -> int:
	return toasts.filter(func(t): return t == text).size()


func sc_chain() -> void:
	G.toast.connect(func(t, _c): toasts.append(t))
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
	await obj_expect("ch1.beach.flute", "(폴백 문구 — 20초 무입력 전엔 숨김)")
	await must(lvl().hud.objective_alpha() < 0.01, "SC1-01 무음: 문구는 폴백 20초 전까지 보이지 않는다")
	await must(G.flag("logo_shown") == 1, "타이틀 로고 카드가 나갔다")

	step("SC1-03/04 피리 → 요괴 출현")
	await tp_to_interact("flute")
	await interact("flute")
	await until(func(): return lvl().get_node_or_null("Gaetgwi") != null, "갯귀 출현", 600)
	await must(G.flag("flute") == 1, "피리 획득 플래그")
	await until(func(): return not player().locked, "마을 사람 대사 끝", 1500)
	await obj_expect("ch1.beach.yokai")

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
	await obj_expect("ch1.gyeongju.apothecary")
	await tp_to_npc("nanyeong")
	await interact("nanyeong")
	await until(func(): return G.flag("met_nanyeong") == 1 and not player().locked, "난영 대화 완료", 2000)
	await obj_expect("ch1.gyeongju.child")

	step("SC1-09 병든 아이 → 노래로 치유")
	var child = lvl().npc("child")
	await must(child.visible and child.is_in_group("downed"), "아이가 탁기에 들어 있다(노래 대상)")
	player().position = child.position + Vector2(-16, 6)
	await tick(2)
	await sing_now()
	await until(func(): return G.flag("sang_child") == 1 and not player().locked, "아이 치유 후 난영 대사 끝", 3000)
	await obj_expect("ch1.gyeongju.rest")

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
	await obj_expect("ch1.gyeongju.summoned")
	await must(toast_count("관아로 가는 길이 열렸다.") == 1, "열림 토스트(관아) 정확히 1회")
	iid = level_iid()
	await tp(gate_center("gwana"))
	await until(func(): return level_ready("gwana", iid), "관아 도착(출구 이동)", 1500)

	step("SC1-12 관아 의뢰 + 난영 쓰러짐")
	await free_player()
	await obj_expect("ch1.gwana.officer")
	await tp_to_npc("gwanri")
	await interact("gwanri")
	await until(func(): return G.flag("briefed") == 1 and not player().locked, "의뢰 대사·일꾼 소식 끝", 3000)
	await must(G.flag("nanyeong_fallen") == 1, "난영 쓰러짐 플래그")
	await obj_expect("ch1.gwana.leave")
	await must(int(G.items["insam"]) >= 4, "관아 지급 인삼정기탕 +2 (2→4)")
	iid = level_iid()
	await tp(lvl().def["anchors"]["exit"])
	await until(func(): return level_ready("gyeongju", iid), "경주 복귀(관아 출구)", 1500)

	step("SC1-13 경주 → 서쪽 폐가 (마당)")
	await free_player()
	await obj_expect("ch1.gyeongju.pyega_road")
	await must(toast_count("서쪽 길이 열렸다.") == 1, "열림 토스트(서쪽 길) 정확히 1회")
	iid = level_iid()
	await tp(gate_center("pyega"))
	await until(func(): return level_ready("pyega1", iid), "폐가 마당 도착", 1500)
	await obj_expect("ch1.pyega1.attic")
	await clear_room()

	step("SC1-14 폐가 다락")
	iid = level_iid()
	await tp(exit_center(1))
	await until(func(): return level_ready("pyega2", iid), "폐가 다락 도착", 1500)
	var boss = lvl().get_node("Boss")
	await must(boss.state == "wait", "역신은 사람 모습으로 앉아 있다(wait)")
	await obj_expect("ch1.pyega2.deep")
	await clear_room()
	await tp(Vector2(420, 190))   # trigger close
	await until(func(): return not player().locked, "'가깝다' 연출 끝", 1500)

	step("SC1-15~17 최심부 · 역신 각성")
	await tp(Vector2(562, 190))   # trigger inner
	await until(func(): return boss.state == "idle", "역신 각성", 3000)
	await until(func(): return lvl().hud._boss_root != null, "보스 체력바 표시", 300)
	await tick(30)
	await must(lvl().hud.objective_alpha() < 0.01, "보스 체력바 표시 중에는 목표 문구 숨김 (T5)")
	await until(func(): return not player().locked, "각성 후 조작 가능", 600)

	step("SC1-18 2페이즈")
	boss.take_hit(int((boss.hp - BOSS_MAX * 0.5) / boss.exposure()) + 2, Vector2.ZERO)
	await until(func(): return boss.phase == 2, "2페이즈 진입", 120)
	await until(func(): return boss.state == "idle", "2페이즈 대사 후 전투 재개", 1500)

	step("SC1-19 무릎 꿇음")
	boss.take_hit(int(boss.hp / boss.exposure()) + 2, Vector2.ZERO)
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
	await obj_expect("ch1.gyeongju.rumor_hear")

	step("SC1-21 소문 → 처용탈")
	await tp_to_npc("elder")
	await interact("elder")
	await until(func(): return G.tal == "cheoyong" and not player().locked, "처용탈 획득", 3000)
	await obj_expect("ch1.gyeongju.rumor_rest")

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
	await obj_expect("ch1.palace.audience")
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
	# 세이브 버전 관리 이후: 깨진 세이브는 save.json.bad로 격리되고 이어하기는 숨겨진다(크래시 없음)
	await must(not ("continue" in title_actions()), "깨진 세이브는 격리되어 이어하기가 숨겨진다")
	await must(FileAccess.file_exists("user://save.json.bad") and not FileAccess.file_exists("user://save.json"), "원본은 save.json.bad로 보존")
	_tap("confirm")
	await until(func(): return scene_name() == "intro.tscn" or (lvl() != null and not G._busy), "처음부터로 게임이 열렸다(크래시 없음)", 1500)
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
	# CS-12 (OQ-1 디렉터 확정): 보스방 사망 → 레벨 재로드 없이 보스방 입구에서 부활, 몹 재생성 없음, 보스 HP·페이즈 리셋
	G.deaths = {}
	for attempt in 2:
		step("재도전 %d: 보스전 중 사망 → 보스방 입구에서 부활(재로드 없음)" % (attempt + 1))
		var iid := level_iid()
		god = false
		boss = lvl().get_node("Boss")
		boss.take_hit(int((boss.hp - BOSS_MAX * 0.5) / boss.exposure()) + 2, Vector2.ZERO) if attempt == 1 else boss.take_hit(int(100.0 / boss.exposure()), Vector2.ZERO)
		if attempt == 1:   # 2페이즈를 겪은 뒤 죽어도 처음부터(페이즈 1)
			await until(func(): return boss.phase == 2 and boss.state != "wait", "2페이즈 대사 후", 1500)
		boss.take_hit(30, Vector2.ZERO)   # 일부 피해
		var ghoul = cs_spawn("ghoul", boss.position + Vector2(30, 0))   # 소환된 졸개가 남아 있어도 정리된다
		var foes_before: int = get_nodes_in_group("enemy").filter(func(e): return e.get("kind") != null and e != boss).size()
		await until(func(): return player().hurt_t <= 0.0, "피격 유예 해제", 300)
		player().hurt(99999, Vector2.RIGHT)
		await must(player().hp == 0.0, "치명타로 쓰러졌다")
		await until(func(): return player().hp == player().max_hp and player().state == "move", "플레이어 부활", 600)
		await tick(3)
		await must(level_iid() == iid, "레벨 재로드 없음(같은 장면)")
		boss = lvl().get_node("Boss")
		await must(boss.hp == BOSS_MAX and boss.phase == 1 and boss.state == "idle", "역신 HP 만피·1페이즈·전투 상태로 초기화 hp=%s ph=%s st=%s" % [boss.hp, boss.phase, boss.state])
		await must(not is_instance_valid(ghoul) or ghoul.is_queued_for_deletion(), "소환된 졸개 제거")
		await must(get_nodes_in_group("enemy").filter(func(e): return e.get("kind") != null and not e.is_queued_for_deletion()).is_empty(), "다락 몹이 되살아나지 않는다")
		await must(G.flag("boss_done") == 0, "boss_done 미설정")
		await must(player().position.distance_to(lvl().lift(Vector2(556, 192))) < 2.0, "보스방 입구(봉쇄문 안쪽)에서 부활")
		await must(not player().locked, "조작 가능")
		await must(int(G.deaths.get("pyega2_boss", 0)) == attempt + 1 and int(G.deaths.get("pyega2", 0)) == 0, "사망이 pyega2_boss 키로 집계")
		god = true
	step("재도전 뒤에도 격파 경로가 열려 있다")
	boss.take_hit(int((boss.hp - BOSS_MAX * 0.5) / boss.exposure()) + 2, Vector2.ZERO)
	await until(func(): return boss.phase == 2 and boss.state == "idle", "2페이즈 대사 후 전투 재개", 1500)
	boss.take_hit(int(boss.hp / boss.exposure()) + 2, Vector2.ZERO)
	await until(func(): return boss.state == "kneel", "무릎 꿇음", 600)
	await until(func(): return lvl().hud._guide == "song", "노래 안내", 1500)
	player().position = boss.position + Vector2(-30, 8)
	await tick(2)
	await sing_now()
	await until(func(): return G.flag("boss_done") == 1, "격파 플래그", 600)
	await done()


# ================================================================ 전투 전략 (design/gdd/combat-strategy.md)
## 타이밍 시나리오는 실시간(1배속)으로 돈다: 받아넘기기 창 0.15초 ≈ 9프레임이라 4배속이면 2프레임으로 뭉개진다.
func cs_setup(lv_note := "") -> void:
	Engine.time_scale = 1.0
	await boot_level()
	await free_player()
	cs_purge()
	G.skills = []
	var p := player()
	p.hp = p.max_hp
	p.ki = p.max_ki
	p.shinmyeong = 0.0
	p.hurt_t = 0.0
	p.gentle_hits = 0


## 방의 요괴·쓰러진 것을 전부 치운다 (시나리오가 직접 소환한 것만 남기려고)
func cs_purge() -> void:
	for g in ["enemy", "downed"]:
		for e in get_nodes_in_group(g):
			if e.get("kind") != null or e.get("phase") != null:   # Enemy / PlagueGod (클래스를 직접 참조하면 오토로드 등록 전에 컴파일되어 실패)
				e.remove_from_group("enemy")
				e.remove_from_group("downed")
				e.queue_free()


func cs_spawn(kind: String, at: Vector2, state := ""):
	var e = load("res://scripts/enemy.gd").new()
	e.kind = kind
	e.position = at
	lvl().add_child(e)
	if state != "":
		e.state = state
	return e


func press(action: String, frames := 1) -> void:
	Input.action_press(action)
	await tick(frames)
	Input.action_release(action)


## 한 프레임씩 진행하며 조건이 될 때까지 (최대 max_frames)
func wait_cond(cond: Callable, label: String, max_frames := 600) -> void:
	await until(cond, label, max_frames)


func cs_idle() -> void:
	var p := player()
	await until(func(): return p.state == "move" and p._roll_lock_t <= 0.0 and p._parry_cd <= 0.0 and p.hurt_t <= 0.0 and Engine.time_scale >= 0.99, "구르기 끝·잠금·쿨다운 해제", 600)


func sc_cs_parry() -> void:
	step("CS-01 준비 — 요괴 없는 폐가 마당")
	await cs_setup()
	var p := player()
	await tp(p.spawn / 1.0 if false else lvl().def["spawns"]["start"])

	step("스킬 없이: 구르기 시작 0.15초 안 근접 접촉 → 받아넘기기 (신명 +15·소리 +8·다음 타 ×2)")
	p.ki = 50.0
	var sin0: float = p.shinmyeong
	await press("roll")
	await until(func(): return p.state == "roll", "구르기 시작", 30)
	await until(func(): return p.t >= 0.05, "구르기 0.05초", 60)
	var hp0: float = p.hp
	p.hurt(10, Vector2.LEFT, true)
	await must(p.parry_bonus, "받아넘기기 발동(스킬 batanum 없이)")
	await must(absf(p.shinmyeong - (sin0 + 15.0)) < 0.01, "신명 +15")
	await must(absf(p.ki - 58.0) < 1.5, "소리 +8 (재생 오차 허용)")
	await must(p.hp == hp0, "피해 없음")
	await cs_idle()
	p.parry_bonus = false

	step("0.15초 이후(0.17초) 접촉 → 피해만 무시, 보상 없음")
	p.shinmyeong = 0.0
	await press("roll")
	await until(func(): return p.state == "roll" and p.t >= 0.17, "구르기 0.17초", 90)
	hp0 = p.hp
	p.hurt(10, Vector2.LEFT, true)
	await must(not p.parry_bonus and p.shinmyeong == 0.0, "보상 없음(창 0.15 밖)")
	await must(p.hp == hp0, "무적 중이라 피해도 없음")
	await cs_idle()

	step("원거리·장판·독기(melee=false)는 구르기 무적 중에도 받아넘기기가 뜨지 않는다")
	p.shinmyeong = 0.0
	await press("roll")
	await until(func(): return p.state == "roll" and p.t >= 0.04, "구르기 0.04초", 60)
	p.hurt(5, Vector2.ZERO, false, "miasma")
	p.hurt(8, Vector2.LEFT)
	await must(not p.parry_bonus and p.shinmyeong == 0.0, "melee=false → 받아넘기기 없음")
	await cs_idle()

	step("스킬 batanum: 창이 0.22초, 성공 시 정면 80px 요괴가 밀쳐지고 예고가 끊긴다")
	G.skills = ["batanum"]
	p.shinmyeong = 0.0
	p.facing = "right"
	p.position = lvl().lift(lvl().def["spawns"]["start"])
	var foe = cs_spawn("ghoul", p.position + Vector2(40, 0), "tell")
	foe.st = 0.0
	await tick(1)
	await press("roll")
	await until(func(): return p.state == "roll" and p.t >= 0.20, "구르기 0.20초 (기본 창 밖·스킬 창 안)", 90)
	p.hurt(10, Vector2.LEFT, true)
	await must(p.parry_bonus, "되받아치기 창 0.22초 안에서 발동")
	await tick(2)
	await must(foe.state == "hurt", "정면 요괴의 예고가 끊겼다(state=hurt)")
	await must(foe.hp == foe.cfg["hp"], "밀쳐내기는 피해 0")
	G.skills = []
	await cs_idle()
	foe.queue_free()
	p.parry_bonus = false

	step("실제 들개 접촉 타격(enemy.gd strike 분기)이 melee=true 로 받아넘기기를 일으킨다")
	p.position = lvl().lift(lvl().def["spawns"]["start"])
	p.shinmyeong = 0.0
	await press("roll")
	await until(func(): return p.state == "roll", "구르기 시작", 30)
	var dog = cs_spawn("dog", p.position + Vector2(14, 0))
	await tick(1)
	dog.state = "strike"
	dog.st = 0.0
	dog.lunge_dir = Vector2.LEFT
	await until(func(): return p.parry_bonus or dog.state != "strike", "들개 타격 판정", 30)
	await must(p.parry_bonus and absf(p.shinmyeong - 15.0) < 0.01, "들개 돌진 접촉 → 받아넘기기 (신명 +15)")
	p.parry_bonus = false
	await cs_idle()
	dog.queue_free()

	step("구르기 잠금: 연속 구르기의 두 번째는 잠금 0.25초 뒤에 시작된다")
	var starts: Array[int] = []
	var f0 := frame
	await press("roll")
	await until(func(): return p.state == "roll", "1번째 구르기", 30)
	await until(func(): return p.state == "move", "1번째 구르기 끝", 60)
	var end_f := frame
	await press("roll")   # 잠금 시작 직후 입력(남은 0.25초 > 선입력 0.10초) → 버려진다
	await tick(30)
	await must(p.state == "move", "잠금 중 이른 입력은 버려진다(구르기 안 함)")
	await cs_idle()

	step("잠금 끝 0.10초 안의 입력은 선입력으로 저장돼 잠금 해제 즉시 실행")
	await press("roll")
	await until(func(): return p.state == "roll", "구르기", 30)
	await until(func(): return p.state == "move", "구르기 끝", 60)
	await until(func(): return p._roll_lock_t > 0.0 and p._roll_lock_t <= 0.08, "잠금 끝 0.08초 전", 60)
	await press("roll")
	await must(p._roll_queued, "선입력 저장")
	await until(func(): return p.state == "roll", "잠금 해제 즉시 2번째 구르기 시작", 30)
	await must(p._roll_lock_t == 0.0, "잠금이 풀린 시점")
	await cs_idle()

	step("학의 질주(hak): 구르기 중 두 번째 입력은 잠금과 무관하게 질주")
	G.skills = ["hak"]
	await press("roll")
	await until(func(): return p.state == "roll" and p.t > 0.12, "구르기 0.12초", 60)
	await press("roll")
	await until(func(): return p._dash, "질주(_dash) 시작", 20)
	G.skills = []
	await cs_idle()
	await done()


func cs_dummy(kind: String, at: Vector2, hp_override := -1):
	var e = cs_spawn(kind, at)
	e.set_physics_process(false)   # 가만히 서 있는 표적 (take_hit 은 그대로 동작)
	e.state = "idle"
	if hp_override > 0:
		e.hp = hp_override
	return e


func sc_cs_charge() -> void:
	step("CS-02 준비")
	await cs_setup()
	var p := player()
	var home: Vector2 = lvl().lift(lvl().def["spawns"]["start"])
	await tp(lvl().def["spawns"]["start"])
	p.facing = "right"

	step("탭 경로 회귀: 짧게 누르면 지금처럼 즉시 1타, 충전 없음")
	var d1 = cs_dummy("ghoul", p.position + Vector2(24, 0))
	Input.action_press("attack")
	await tick(2)
	await must(p.state == "attack", "누르자마자 1타(state=attack)")
	Input.action_release("attack")
	await until(func(): return p.state == "move", "1타 종료", 60)
	await must(d1.hp < d1.cfg["hp"], "1타가 적중했다")
	await must(p._charge_c == 0.0 and not p._charge_hold, "충전 상태 없음")
	await cs_idle()

	step("느린 탭(0.3초 누름)은 충전으로 오인되지 않는다")
	p.facing = "right"
	Input.action_press("attack")
	await tick(18)
	Input.action_release("attack")
	await tick(30)
	await must(p.state != "charge" and p._charge_c == 0.0, "0.3초 누름 → 충전 없음")
	await cs_idle()
	d1.queue_free()

	step("0.45초 이상 누르면 충전 상태: 이동 불가, 스틱으로 방향만 바꾼다")
	p.facing = "right"
	Input.action_press("attack")
	await until(func(): return p.state == "charge", "충전 진입", 90)
	var pos1: Vector2 = p.position
	Input.action_press("move_up")
	await tick(10)
	await must(p.state == "charge" and p.position.distance_to(pos1) < 0.01 and p.velocity == Vector2.ZERO, "충전 중 이동 불가(위치 고정)")
	await must(p.facing == "up", "스틱으로 조준(방향 전환)")
	Input.action_release("move_up")
	Input.action_release("attack")   # c < 0.35 → 조용히 취소
	await tick(3)
	await must(p.state == "move" and p._charge_c == 0.0, "일찍 떼면 조용히 취소(후딜 없음)")
	await cs_idle()

	step("만충(c≥0.90) 강 베기: Lv.1 피해 45·장갑 무시·소리 소모 없음·넉백")
	p.position = home
	p.facing = "right"
	p.ki = 60.0
	var mama = cs_dummy("mama", p.position + Vector2(40, 0))
	var mhp: int = mama.hp
	await must(mhp == 70, "마마귀신 HP 70")
	Input.action_press("attack")
	await until(func(): return p.state == "charge" and p._charge_c >= 0.92, "만충 대기", 240)
	var ki_before: float = p.ki
	Input.action_release("attack")
	await tick(2)
	await must(p.state == "slash", "발동 후 후딜(state=slash)")
	await must(mhp - mama.hp == 45, "Lv.1 만충 피해 45 (장갑 ×0.6 무시): " + str(mhp - mama.hp))
	await must(p.ki >= ki_before, "소리 소모 없음")
	await must(mama.knock.length() > 250.0, "넉백")
	await cs_idle()
	var sin_a: float = p.shinmyeong
	await must(sin_a >= 5.0, "신명 +5/체: " + str(sin_a))

	step("같은 마마귀신에 일반 타격(3타 마지막 18)은 장갑 ×0.6 → 11")
	var h0: int = mama.hp
	mama.take_hit(18, Vector2.RIGHT)
	await must(h0 - mama.hp == 11, "일반 18 → 11")
	mama.queue_free()

	step("최소 충전(c≈0.35)은 Lv.1 피해 23 근처")
	p.position = home
	p.facing = "right"
	var mama2 = cs_dummy("mama", p.position + Vector2(40, 0))
	Input.action_press("attack")
	await until(func(): return p.state == "charge" and p._charge_c >= 0.36, "최소 충전", 240)
	Input.action_release("attack")
	await tick(2)
	var dm: int = 70 - mama2.hp
	await must(dm >= 23 and dm <= 27, "최소~조금 더 충전 피해 23~27: " + str(dm))
	await cs_idle()
	mama2.queue_free()

	step("쓰러지면 죽지 않고 downed 로 남는다 (정화는 노래로만)")
	p.position = home
	p.facing = "right"
	var low = cs_dummy("ghoul", p.position + Vector2(30, 0), 10)
	Input.action_press("attack")
	await until(func(): return p.state == "charge" and p._charge_c >= 0.4, "충전", 240)
	Input.action_release("attack")
	await tick(2)
	await must(low.state == "downed" and low.is_in_group("downed"), "강 베기로 HP 0 → downed(죽음 아님)")
	await cs_idle()
	low.queue_free()

	step("충전 중 구르기: c<0.35 는 취소+구르기, c≥0.35 는 무시")
	p.position = home
	Input.action_press("attack")
	await until(func(): return p.state == "charge", "충전", 240)
	await press("roll")
	await tick(2)
	await must(p.state == "roll", "c<0.35: 충전 취소 + 구르기 즉시")
	Input.action_release("attack")
	await cs_idle()
	Input.action_press("attack")
	await until(func(): return p.state == "charge" and p._charge_c >= 0.4, "충전 0.4", 240)
	await press("roll")
	await tick(3)
	await must(p.state == "charge", "c≥0.35: 구르기 입력 무시")
	Input.action_release("attack")
	await cs_idle()

	step("충전 중 피해 → 끊김 / 수호부로 막은 피격은 안 끊김")
	p.position = home
	Input.action_press("attack")
	await until(func(): return p.state == "charge" and p._charge_c >= 0.2, "충전", 240)
	p.shield = 1
	p.shield_t = 10.0
	p.hurt(10, Vector2.LEFT, true)
	await tick(1)
	await must(p.state == "charge" and p.shield == 0, "수호부가 막았다 → 충전 유지")
	await until(func(): return p.hurt_t <= 0.0, "피격 유예 해제", 60)
	var hp1: float = p.hp
	p.hurt(10, Vector2.LEFT, true)
	await tick(1)
	await must(p.hp < hp1 and p.state != "charge" and p._charge_c == 0.0, "실제 피해 → 충전 끊김")
	Input.action_release("attack")
	await cs_idle()

	step("충전 중 기절 / 끌림도 끊는다")
	p.position = home
	Input.action_press("attack")
	await until(func(): return p.state == "charge", "충전", 240)
	p.pull(home + Vector2(30, 0), 0.5)
	await tick(1)
	await must(p.state != "charge", "끌림 → 충전 끊김")
	Input.action_release("attack")
	await cs_idle()
	p.pull_t = 0.0
	Input.action_press("attack")
	await until(func(): return p.state == "charge", "충전", 240)
	p.stun(0.3)
	await tick(1)
	await must(p.state != "charge" and p.stun_t > 0.0, "기절 → 충전 끊김")
	Input.action_release("attack")
	await until(func(): return p.stun_t <= 0.0, "기절 끝", 120)
	await cs_idle()

	step("2.0초가 되면 손가락이 멈춰도 자동 발동")
	p.position = home
	Input.action_press("attack")
	await until(func(): return p.state == "slash", "자동 발동(state=slash)", 400)
	Input.action_release("attack")
	await cs_idle()

	step("충전 중 신명 100이면 처용무를 쓸 수 있다")
	p.position = home
	G.set_flag("flute")
	p.shinmyeong = 100.0
	Input.action_press("attack")
	await until(func(): return p.state == "charge", "충전", 240)
	await press("dance")
	await tick(2)
	await must(p.ult_t > 0.0, "충전 중 처용무 발동")
	Input.action_release("attack")
	p.ult_t = 0.0
	await cs_idle()

	step("말 걸기에 쓰인 눌림은 공격도 충전도 일으키지 않는다")
	p.position = home
	var talked := [0]
	p.interact = func():
		talked[0] += 1
		return true
	Input.action_press("attack")
	await tick(60)
	await must(p.state == "move" and p._charge_c == 0.0 and not p._charge_hold, "길게 눌러도 차징 시작 안 함")
	await must(talked[0] == 1, "상호작용은 1회")
	Input.action_release("attack")
	await done()


func sc_cs_guard() -> void:
	step("CS-03 준비")
	await cs_setup()
	var p := player()
	await tp(lvl().def["spawns"]["start"])

	step("수호부가 막은 공격의 기절·끌림·둔화도 함께 막는다 (D3), 환급 +10")
	p.shield = 1
	p.shield_t = 10.0
	p.ki = 50.0
	var hp0: float = p.hp
	# 요괴 코드가 하는 순서 그대로: 피해 → 상태이상 (처녀귀신 울음 / 물귀신 발목 끌기 / 손각시 붉은 실)
	p.hurt(4, Vector2.LEFT, false)
	p.stun(1.2)
	p.pull(p.position + Vector2(30, 0), 0.9)
	p.slow(1.6)
	await tick(1)
	await must(p.hp == hp0 and p.shield == 0, "피해 0 · 수호부 소모")
	await must(p.stun_t == 0.0 and p.pull_t == 0.0 and p.slow_t == 0.0, "기절·끌림·둔화 전부 없음")
	await must(p.ki >= 59.0 and p.ki <= 62.0, "수호부 파괴 환급 소리 +10: " + str(p.ki))
	await must(p._guard_t > 0.0, "_guard_t 가 걸렸다")

	step("0.4초가 지나면 다시 걸린다 (차단은 한 번의 막기에 한정)")
	await until(func(): return p._guard_t <= 0.0 and p.hurt_t <= 0.0, "차단·유예 해제", 120)
	p.stun(0.2)
	await must(p.stun_t > 0.0, "수호부 없이/시간이 지난 뒤에는 기절한다")
	await until(func(): return p.stun_t <= 0.0, "기절 끝", 60)

	step("수호부 없이 맞으면 피해와 상태이상이 그대로 들어온다")
	p.hurt_t = 0.0
	hp0 = p.hp
	p.hurt(4, Vector2.LEFT, false)
	await must(p.hp < hp0, "피해를 입었다")
	p.slow(0.5)
	await must(p.slow_t > 0.0, "둔화가 걸린다")
	await cs_idle()
	p.slow_t = 0.0

	step("독기 틱(kind=miasma)은 수호부가 켜진 동안 0 피해·충전 유지 (10초 지속)")
	p.hurt_t = 0.0
	p.shield = 1
	p.shield_t = 10.0
	p.ki = 40.0
	hp0 = p.hp
	for i in 6:
		p.hurt(5, Vector2.ZERO, false, "miasma")
		await tick(2)
	await must(p.hp == hp0 and p.shield == 1, "독기 6틱에도 피해 0·수호부 유지")
	await must(p.hurt_t == 0.0 and p._guard_t == 0.0, "피격 유예·차단 타이머도 쓰지 않음")
	await must(p.ki < 45.0, "환급 없음(직접 타격을 막은 것이 아님)")
	p.shield_t = 0.1
	await until(func(): return p.shield == 0, "10초 지속이 끝나면 사라진다", 60)
	await must(p.ki < 45.0, "막지 못하고 사라진 수호부는 환급 없음")
	p.hurt(5, Vector2.ZERO, false, "miasma")
	await must(p.hp < hp0, "수호부가 없으면 독기에 맞는다")
	await cs_idle()

	step("suho2: 충전 2회, 환급은 마지막 충전이 소모될 때 1회")
	p.hurt_t = 0.0
	p.hp = p.max_hp
	G.skills = ["suho2"]
	p.shield = 2
	p.shield_t = 10.0
	p.ki = 40.0
	p.hurt(8, Vector2.LEFT, false)
	await tick(1)
	await must(p.shield == 1 and p.ki < 45.0, "첫 충전 소모: 환급 없음")
	await until(func(): return p.hurt_t <= 0.0, "피격 유예 해제", 60)
	p.hurt(8, Vector2.LEFT, false)
	await tick(1)
	await must(p.shield == 0 and p.ki >= 49.0, "마지막 충전 소모: 환급 +10")
	G.skills = []
	await cs_idle()

	step("구르기 무적 중에는 slow() 도 무시된다")
	await press("roll")
	await until(func(): return p.state == "roll", "구르기", 30)
	p.slow(1.0)
	p.stun(1.0)
	await must(p.slow_t <= 0.0 and p.stun_t <= 0.0, "구르기 중 둔화·기절 없음 slow=%s stun=%s inv=%s st=%s" % [p.slow_t, p.stun_t, p.invuln, p.state])
	await cs_idle()
	await done()


func sc_cs_targeting() -> void:
	step("CS-04 준비")
	await cs_setup()
	var p := player()
	var home: Vector2 = lvl().lift(lvl().def["spawns"]["start"])
	await tp(lvl().def["spawns"]["start"])

	step("후딜: 헛돌진한 들개 0.5초·갯귀 0.8초·마마귀신 1.2초, 후딜 중 피해 ×1.5")
	for spec in [["dog", 0.5], ["sea", 0.8], ["mama", 1.2]]:
		var e = cs_dummy(spec[0], home + Vector2(300, 0))
		e.state = "strike"
		e.st = e.cfg["strike"] + 0.01
		e.set_physics_process(true)
		await tick(1)
		e.set_physics_process(false)
		await must(e.state == "stagger" and absf(e.stagger_time - spec[1]) < 0.001, "%s 후딜 %.1f초" % [spec[0], spec[1]])
		var h: int = e.hp
		e.take_hit(10, Vector2.RIGHT)
		await must(h - e.hp == 15, "%s 후딜 중 피해 10 → 15" % spec[0])
		e.queue_free()

	step("마마귀신 장갑 ×0.6: 3연타 18→11·화염 틱 5→3, 강 베기·처용무(charged)는 무시")
	var m = cs_dummy("mama", home + Vector2(300, 0))
	var mh: int = m.hp
	m.take_hit(18, Vector2.RIGHT)
	await must(mh - m.hp == 11, "18 → 11")
	mh = m.hp
	m.take_hit(5, Vector2.ZERO, false, true)
	await must(mh - m.hp == 3, "화염 틱 5 → 3")
	mh = m.hp
	m.take_hit(30, Vector2.ZERO, false, true, true)
	await must(mh - m.hp == 30, "charged(처용무) 장갑 무시")
	m.queue_free()

	step("결박부: 군집 중심에 깔려 졸개 3마리를 동시에 포획한다 (가까운 외톨이 대신)")
	p.position = home
	p.facing = "right"
	var lone = cs_dummy("ghoul", home + Vector2(-50, 0))
	var c1 = cs_dummy("ghoul", home + Vector2(95, -10))
	var c2 = cs_dummy("ghoul", home + Vector2(100, 8))
	var c3 = cs_dummy("ghoul", home + Vector2(88, 6))
	G.tal_idx = 1
	p.ki = 100.0
	await must(p.current_talisman() == "bind", "결박부 선택")
	p._talisman()
	await tick(1)
	var zone = null
	for c in lvl().get_children():
		if c.get("kind") == "bind" and c.get("radius") != null:
			zone = c
	await must(zone != null, "결박 장판 생성")
	await tick(3)
	await must(c1.bind_t > 0.0 and c2.bind_t > 0.0 and c3.bind_t > 0.0, "군집 3마리 모두 결박")
	await must(lone.bind_t <= 0.0, "외톨이는 결박되지 않음")
	zone.queue_free()

	step("결박된 적 위의 화염 틱은 8, 아닌 적은 5 (S1)  /  결박된 적에 대한 베기 ×1.2")
	for e in [lone, c1, c2, c3]:
		e.queue_free()
	await tick(2)
	var fz = load("res://scripts/fx/talisman_zone.gd").new()
	fz.kind = "fire"
	fz.angle = 0.0
	fz.position = home
	var a = cs_dummy("ghoul", home + Vector2(30, 0))
	var b = cs_dummy("ghoul", home + Vector2(30, 6))
	a.bind_t = 5.0
	lvl().add_child(fz)
	await tick(2)
	await must(a.cfg["hp"] - a.hp == 8, "결박된 적 화염 8: " + str(a.cfg["hp"] - a.hp))
	await must(b.cfg["hp"] - b.hp == 5, "비결박 화염 5: " + str(b.cfg["hp"] - b.hp))
	fz.queue_free()
	b.queue_free()
	a.position = home + Vector2(24, 0)
	a.hp = a.cfg["hp"]
	p.facing = "right"
	await tick(1)
	await press("attack")
	await until(func(): return a.hp < a.cfg["hp"], "베기 적중", 60)
	await must(a.cfg["hp"] - a.hp == 12, "결박된 적 베기 10 ×1.2 = 12: " + str(a.cfg["hp"] - a.hp))
	G.skills = ["gyeolbak2"]
	await must(absf(p._bind_mult(a) - 1.4) < 0.001, "gyeolbak2 ×1.4")
	G.skills = []
	await done()


func sc_cs_economy() -> void:
	step("CS-05 준비")
	await cs_setup()
	var p := player()
	var home: Vector2 = lvl().lift(lvl().def["spawns"]["start"])
	await tp(lvl().def["spawns"]["start"])

	step("소리 재생 초당 4.0")
	p.ki = 0.0
	await tick(60)
	await must(p.ki > 3.5 and p.ki < 4.5, "1초 재생 ≈ 4.0: " + str(p.ki))

	step("피해를 입으면 신명 −12 (0 하한), 수호부가 막은 피격은 감점 없음")
	p.shinmyeong = 50.0
	p.hurt_t = 0.0
	p.hurt(5, Vector2.LEFT)
	await must(absf(p.shinmyeong - 38.0) < 0.01, "50 → 38")
	p.hurt_t = 0.0
	p.shinmyeong = 5.0
	p.hurt(5, Vector2.LEFT)
	await must(p.shinmyeong == 0.0, "0 하한")
	p.hurt_t = 0.0
	p.shinmyeong = 30.0
	p.shield = 1
	p.hurt(5, Vector2.LEFT)
	await must(p.shinmyeong == 30.0, "수호부로 막으면 감점 없음")

	step("정화 보상: normal 4마리 → 체력 +16·소리 +32 (Lv.3), elite → 체력 +12·소리 +20")
	G.set_flag("hanpuri_" + G.level_id)   # 이 단계에선 한풀이 보너스를 끈다(아래 단계에서 따로 검증)
	G.lv = 3
	p.max_hp = G.max_hp()
	p.hp = 40.0
	p.ki = 0.0
	p.hurt_t = 0.0
	p.position = home
	var foes := []
	for i in 4:
		foes.append(cs_dummy("ghoul", home + Vector2(12 + i * 4, 4 * i - 6)))
	for e in foes:
		e.take_hit(9999, Vector2.ZERO)
	await tick(2)
	await sing_now()
	await must(absf(p.hp - 56.0) < 0.6, "체력 +16: " + str(p.hp))
	await must(p.ki > 31.5 and p.ki < 40.0, "소리 +32 (+재생): " + str(p.ki))
	await cs_idle()
	p.hp = 40.0
	p.ki = 0.0
	var el = cs_dummy("mama", home + Vector2(14, 0))
	el.take_hit(9999, Vector2.ZERO)
	await tick(2)
	await sing_now()
	await must(absf(p.hp - 52.0) < 0.6, "elite 체력 +12: " + str(p.hp))
	await must(p.ki > 19.5 and p.ki < 28.0, "elite 소리 +20: " + str(p.ki))

	step("한풀이(구역 전원 정화, 최소 3) 성립 시 체력 +15%")
	G.flags.erase("hanpuri_" + G.level_id)
	G.lv = 3
	G.deok = 0   # 레벨업(전회복)이 체력 대조를 흐리지 않게
	p.max_hp = G.max_hp()
	cs_purge()
	await tick(2)
	var lv_ := lvl()
	lv_._purified_n = 0
	p.hp = 20.0
	var trio := []
	for i in 3:
		trio.append(cs_dummy("ghoul", home + Vector2(12 + i * 4, 4 * i - 6)))
	for e in trio:
		e.take_hit(9999, Vector2.ZERO)
	await tick(2)
	await sing_now()
	await must(G.flag("hanpuri_" + G.level_id) == 1, "한풀이 성립")
	# 3마리 정화(4×3=12) + 한풀이 15% of 112 = 16.8
	await must(absf(p.hp - (20.0 + 12.0 + 16.8)) < 1.0, "체력 +12 + 16.8: " + str(p.hp))
	await done()


## 보스방을 깨워 역신이 idle 인 상태로 만든다 (플레이어는 조작 가능, god=false)
func cs_wake_boss():
	Engine.time_scale = 1.0
	await boot_level()
	god = true
	pump = true
	await clear_room()
	await tp(Vector2(420, 190))
	await until(func(): return not player().locked, "'가깝다' 연출 끝", 1500)
	await tp(Vector2(562, 190))
	var boss = lvl().get_node("Boss")
	await until(func(): return boss.state == "idle", "역신 각성", 3000)
	await until(func(): return not player().locked, "조작 가능", 600)
	pump = false
	god = false
	G.skills = []
	return boss


func sc_cs_boss() -> void:
	step("CS-06 준비 — 보스방, 역신 각성")
	var boss = await cs_wake_boss()
	var p := player()
	var home: Vector2 = p.position
	boss.set_physics_process(false)   # 패턴이 멋대로 돌지 않게 상태를 직접 만든다
	boss.state = "idle"

	step("받는 피해 배율: 평시 ×0.5(BOSS_IDLE_MULT), 열림 ×2.0, 안개·졸개 시전 ×1.25")
	for spec in [["idle", 25], ["open", 100], ["fog", 63], ["clones", 63]]:
		boss.hp = BOSS_MAX
		boss.state = spec[0]
		boss.take_hit(50, Vector2.RIGHT)
		await must(int(BOSS_MAX - boss.hp) == spec[1], "%s: 50 → %d (실제 %d)" % [spec[0], spec[1], int(BOSS_MAX - boss.hp)])
	boss.hp = BOSS_MAX
	boss.state = "idle"

	step("패턴 순서는 그대로: 1페이즈 안개-기침-졸개-기침, 2페이즈 안개-기침-졸개-기침-안개-졸개")
	var seq1 := []
	boss.pat_i = 0
	for i in 4:
		boss._next_pattern()
		seq1.append(boss.state)
		boss._clear_tells()
	await must(seq1 == ["fog", "cough", "clones", "cough"], "1페이즈: " + str(seq1))
	boss.phase = 2
	var seq2 := []
	boss.pat_i = 0
	for i in 6:
		boss._next_pattern()
		seq2.append(boss.state)
		boss._clear_tells()
	await must(seq2 == ["fog", "cough", "clones", "cough", "fog", "clones"], "2페이즈: " + str(seq2))
	boss.phase = 1

	step("기침 숨결 뒤 열림 1.2초: 이동·공격 없이 서 있고 피해 ×1.5")
	boss.set_physics_process(true)
	boss.position = p.position + Vector2(220, 0)   # 숨결이 닿지 않는 거리
	boss.coughs = 0
	boss._begin("cough")
	boss._aim_cough()
	await until(func(): return boss.state == "open", "기침 → 열림", 120)
	await must(absf(boss.open_t - 1.2) < 0.001, "열림 1.2초")
	var bp: Vector2 = boss.position
	await tick(20)
	await must(boss.state == "open" and boss.position.distance_to(bp) < 6.0, "열림 중 이동하지 않는다")
	boss.hp = BOSS_MAX
	boss.take_hit(50, Vector2.ZERO)
	await must(int(BOSS_MAX - boss.hp) == 100, "열림 중 만충 강 베기 50 → 100 (BOSS_OPEN_MULT 2.0)")
	await until(func(): return boss.state == "idle", "열림 종료 → idle", 120)

	step("2페이즈 기침은 2연속, 두 번째 뒤에 0.9초 열림")
	boss.phase = 2
	boss.position = p.position + Vector2(220, 0)
	boss.coughs = 0
	boss._begin("cough")
	boss._aim_cough()
	var saw_again := [false]
	await until(func():
		if boss.state == "cough_again" or (boss.state == "cough" and boss.coughs == 1):
			saw_again[0] = true
		return boss.state == "open", "2연속 기침 → 열림", 240)
	await must(saw_again[0] and boss.coughs == 2 and absf(boss.open_t - 0.9) < 0.001, "두 번째 숨결 뒤 0.9초 열림")
	boss.phase = 1
	await until(func(): return boss.state == "idle", "열림 종료", 120)

	step("펄스: 피했으면 열림 1.0초, 붙어서 맞았으면 열림 없음(BOSS_OPEN_IF_HIT)")
	boss.position = p.position + Vector2(120, 0)   # 펄스 사거리(80) 밖 = 피함
	boss._begin("pulse")
	await until(func(): return boss.state == "open", "펄스 → 열림", 120)
	await must(absf(boss.open_t - 1.0) < 0.001, "피한 펄스 뒤 열림 1.0초")
	await until(func(): return boss.state == "idle", "열림 종료", 120)
	p.hp = 100.0
	boss.position = p.position + Vector2(30, 0)   # 붙어서 맞음
	boss._begin("pulse")
	await until(func(): return boss.state == "open", "펄스 → 열림(0초)", 120)
	await must(boss.open_t < 0.01, "맞은 펄스 뒤 열림 없음(0초)")
	await until(func(): return boss.state == "idle", "열림 종료", 120)
	boss.position = p.position + Vector2(220, 0)

	step("풀 충전 강 베기가 시전 중(안개/졸개)인 역신에 맞으면 시전 중단 + 열림 1.2초, 소환 취소")
	for pat in ["clones", "fog"]:
		boss.hp = BOSS_MAX
		boss._begin(pat)
		boss.take_hit(30, Vector2.RIGHT, true, false, true, 0.5)
		await must(boss.state == pat, "충전 0.5(반충전)는 끊지 못한다: " + pat)
		boss.take_hit(50, Vector2.RIGHT, true, false, true, 1.0)
		await must(boss.state == "open" and absf(boss.open_t - 1.2) < 0.001, pat + " 시전 중단 → 열림")
		await tick(80)
		var ghouls := get_nodes_in_group("enemy").filter(func(e): return e.get("kind") == "ghoul")
		await must(ghouls.is_empty(), pat + ": 졸개 소환이 취소됨")
		await until(func(): return boss.state == "idle", "idle 복귀", 120)

	step("받아넘기기: 기침 숨결·펄스 접촉이 구르기 초반(0.15초)에 닿으면 발동")
	boss.position = p.position + Vector2(60, 0)
	p.shinmyeong = 0.0
	await press("roll")
	await until(func(): return p.state == "roll" and p.t >= 0.03, "구르기", 30)
	boss.aim = (p.global_position - boss.global_position).angle()
	boss._breath()
	await must(p.parry_bonus and absf(p.shinmyeong - 15.0) < 0.01, "숨결 접촉 → 받아넘기기")
	p.parry_bonus = false
	await cs_idle()
	boss.position = p.position + Vector2(220, 0)

	step("독기 안개 틱: 수호부가 켜진 동안 0 피해(충전 유지), 없으면 5")
	p.hurt_t = 0.0
	p.shield = 1
	p.shield_t = 10.0
	var hp0: float = p.hp
	boss._poison(p.global_position)
	await tick(75)
	await must(p.hp == hp0 and p.shield == 1, "안개 위에서 수호부 유지·피해 0")
	p.shield = 0
	await tick(40)
	await must(p.hp < hp0, "수호부가 없으면 안개 피해")
	for f in get_nodes_in_group("fog"):
		f.queue_free()
	p.hp = p.max_hp
	await tick(2)

	step("2페이즈 전환: 대사 뒤 열림 1.2초(×1.5)·안개 제거·소리 +30")
	boss.position = home + Vector2(120, -40)
	boss._poison(home + Vector2(60, 0))
	await tick(2)
	await must(get_nodes_in_group("fog").size() == 1, "안개 장판 존재")
	god = true
	pump = true
	p.ki = 10.0
	boss.hp = BOSS_MAX
	boss.state = "idle"
	boss.take_hit(int((boss.hp - BOSS_MAX * 0.5) / boss.exposure()) + 2, Vector2.ZERO)
	await must(boss.phase == 2, "2페이즈 진입")
	await tick(2)
	await must(get_nodes_in_group("fog").is_empty(), "안개 제거")
	await until(func(): return boss.state == "open", "대사 뒤 전환 열림", 600)
	await must(absf(boss.open_t - 1.2) < 0.001, "열림 1.2초")
	await must(p.ki >= 39.0, "소리 +30: " + str(p.ki))
	pump = false
	await until(func(): return boss.state == "idle", "전환 열림 종료", 200)

	step("무릎 꿇은 역신은 처용가로만 끝난다 (정화 철학)")
	boss.take_hit(int(boss.hp / boss.exposure()) + 2, Vector2.ZERO)
	await until(func(): return boss.state == "kneel", "무릎", 120)
	await must(boss.is_in_group("downed"), "downed(죽음 아님)")
	await done()


func sc_cs_deaths() -> void:
	step("CS-07 사망 3회 → 구역별 카운터 → 세이브 → 로드 후 유지")
	await cs_setup()
	var p := player()
	G.deaths = {}
	var spawn: Vector2 = p.spawn
	for i in 3:
		await until(func(): return p.hurt_t <= 0.0 and p.state == "move", "사망 가능 상태 %d" % (i + 1), 600)
		p.hurt(99999, Vector2.RIGHT)
		await until(func(): return p.hp == p.max_hp and p.position.distance_to(spawn) < 1.0, "리스폰 %d" % (i + 1), 600)
	await must(int(G.deaths.get("pyega1", 0)) == 3, "pyega1 사망 3회: " + str(G.deaths))
	G.save()
	G.deaths = {}
	await must(G.load_save() and int(G.deaths.get("pyega1", 0)) == 3, "세이브→로드 후 값 유지")
	await done()


func sc_cs_wave() -> void:
	step("CS-15 S4 묶어 울리기: 결박된 적에게 파동부 피해 ×2·넉백 ×0.5, 시전 중단")
	await cs_setup()
	var p := player()
	var home: Vector2 = lvl().lift(lvl().def["spawns"]["start"])
	await tp(lvl().def["spawns"]["start"])
	G.skills = ["padong"]
	p.facing = "right"
	G.tal_idx = 3
	await must(p.current_talisman() == "wave", "파동부 선택")
	var a = cs_dummy("ghoul", home + Vector2(40, 0))
	var b = cs_dummy("ghoul", home + Vector2(40, 12))
	a.bind_t = 5.0
	a.state = "tell"
	b.state = "tell"
	p.ki = 100.0
	p._talisman()
	await tick(1)
	await must(a.cfg["hp"] - a.hp == 12, "결박된 적 6×2 = 12: " + str(a.cfg["hp"] - a.hp))
	await must(b.cfg["hp"] - b.hp == 6, "일반 적 6: " + str(b.cfg["hp"] - b.hp))
	await must(a.knock.length() < b.knock.length() * 0.6, "결박된 적 넉백 ×0.5")
	await must(a.state == "hurt" and b.state == "hurt", "예고 중단")
	G.skills = []
	await done()


func sc_cs_aura() -> void:
	step("CS-11 보스 예고 색 오라: 패턴 직전 0.5초, 안개 녹/기침 적/졸개 보라")
	var boss = await cs_wake_boss()
	boss.position = player().position + Vector2(300, 0)
	for spec in [[0, "fog"], [1, "cough"], [2, "clones"], [3, "cough"]]:
		boss._begin("idle")
		boss.pat_i = spec[0]
		await must(boss.next_pattern_name() == spec[1], "다음 패턴 = " + spec[1])
		boss.st = 0.2
		await tick(2)
		await must(boss.aura.color == boss.AURA_IDLE, "패턴 0.5초 전엔 평시 색")
		boss.st = 1.0
		await tick(1)
		await must(boss.aura.color == boss.AURA_COLOR[spec[1]] and boss.aura.energy > 0.8, spec[1] + " 오라 색")
	await done()


func sc_cs_tutorial() -> void:
	step("CS-09 받아넘기기 튜토리얼: 갯귀 첫 예고 = 구르기 점등, 두 번째 예고 = 다시 구르기 점등(글 없음)")
	Engine.time_scale = 1.0
	await boot_level()
	G.skills = []
	var yk = lvl().get_node("Gaetgwi")
	var seen := [0]
	yk.telegraph.connect(func(): seen[0] += 1)
	await until(func(): return seen[0] >= 1, "첫 예고", 1500)
	await tick(2)
	await must(lvl().hud._guide == "roll", "첫 예고: 구르기 버튼 점등")
	await press("roll")   # 플레이어가 구른다 → 안내가 풀린다
	await until(func(): return lvl().hud._guide != "roll", "안내 해제", 600)
	await until(func(): return seen[0] >= 2, "두 번째 예고", 2500)
	await tick(2)
	await must(lvl().hud._guide == "roll", "두 번째 예고: 구르기 버튼 점등(받아넘기기 안내)")
	await must(Engine.time_scale < 1.0, "예고 동안 시간이 느려진다")
	await must(player().gentle_hits >= 0, "갯귀 gentle_hits 유지")
	await press("roll")
	await until(func(): return lvl().hud._guide != "roll", "안내 해제", 600)
	await done()


func sc_cs_cover() -> void:
	step("CS-10 엄폐: 투사체는 소품·지형 충돌체에 막히고, 열린 곳에서는 맞는다")
	await cs_setup()
	var p := player()
	var home: Vector2 = lvl().lift(lvl().def["spawns"]["start"])
	await tp(lvl().def["spawns"]["start"])
	var PR = load("res://scripts/fx/projectile.gd")
	# 열린 곳: 처용을 향해 쏘면 맞는다
	var open_hp: float = p.hp
	var a = PR.make("", Vector2i(1, 1), 1)
	a.vel = Vector2(-120, 0)
	a.dmg = 8
	a.position = home + Vector2(45, 0)
	lvl().add_child(a)
	await until(func(): return not is_instance_valid(a), "투사체 소멸", 120)
	await must(p.hp < open_hp, "엄폐 없음 → 맞는다")
	# 엄폐: 사이에 벽
	await until(func(): return p.hurt_t <= 0.0, "피격 유예 해제", 120)
	var wall := StaticBody2D.new()
	var cs := CollisionShape2D.new()
	var sh := RectangleShape2D.new()
	sh.size = Vector2(8, 40)
	cs.shape = sh
	wall.add_child(cs)
	wall.position = home + Vector2(24, 0)
	lvl().add_child(wall)
	await tick(2)
	var hp1: float = p.hp
	var b = PR.make("", Vector2i(1, 1), 1)
	b.vel = Vector2(-120, 0)
	b.dmg = 8
	b.position = home + Vector2(45, 0)
	lvl().add_child(b)
	await until(func(): return not is_instance_valid(b), "투사체 소멸", 120)
	await must(p.hp == hp1, "벽 뒤에 있으면 맞지 않는다(엄폐)")
	await done()


# ================================================================ 2장 M1: 화개 저자(SC2-01~03) → 지리산 산길(SC2-15·16) → 이어하기 지점
func sc_ch2_m1() -> void:
	step("2장 스위치 기본 꺼짐 (1장 엔딩 보호)")
	await must(not G.ch2_enabled(), "ch2_enabled() 기본 false")
	G.flags["ch2_unlocked"] = 1   # 이 시나리오는 2장 켜짐 상태의 이어하기 지점을 본다 (꺼짐 동작은 ch2_off_continue)
	for f in ["chapter1_done", "appointed", "rumor", "king_call", "flute"]:
		G.flags[f] = 1   # 1장을 끝낸 세이브
	G.level_id = "hwagae"
	G.spawn_name = "start"
	step("SC2-01 화개 저자 입장")
	pump = true
	await boot_level()
	await until(func(): return G.flag("ch2_start") == 1, "ch2_start 플래그", 600)
	await until(func(): return not player().locked, "SC2-01 대사 끝", 1500)
	await must(G.checkpoint == "hwagae", "체크포인트 = hwagae")
	await must(G.checkpoint_spawn()[0] == "hwagae", "이어하기 지점 = hwagae")
	await must(not lvl().npc("elder").visible, "노인은 SC2-03 전까지 숨어 있다")
	step("SC2-02 습격 → 밤 재로드")
	var iid := level_iid()
	await tp(lvl().def["anchors"]["raid"].get_center())
	await until(func(): return G.flag("raided") == 1, "raided 플래그", 1500)
	await until(func(): return level_ready("hwagae", iid), "밤의 화개 저자 재로드", 3000)
	await must(G.flag("night") == 1, "밤 플래그")
	await must(lvl().npc("elder").visible, "노인 등장")
	step("SC2-03 노인 → 동쪽 산길 열림")
	await free_player()
	await tp_to_npc("elder")
	await interact("elder")
	await until(func(): return G.flag("ch2_old_man") == 1, "ch2_old_man", 1500)
	await tick(5)
	iid = level_iid()
	await free_player()
	await tp(gate_center("path"))
	await until(func(): return level_ready("jiri_path", iid), "지리산 산길 진입", 3000)
	await must(G.checkpoint == "jiri_path", "체크포인트 = jiri_path")
	await must(G.checkpoint_spawn()[0] == "jiri_path", "이어하기 지점 = jiri_path")
	await must(get_nodes_in_group("enemy").size() == 6, "산길 요괴 6체 (산군3·불도깨비2·장승)")
	step("SC2-16 산신각 · SC2-15 장승")
	await free_player()
	god = true
	await tp_to_interact("shrine")
	await interact("shrine")
	await until(func(): return G.flag("shrine_seen") == 1 and not player().locked, "SC2-16 산신령", 1500)
	await tp(lvl().def["triggers"][0][0].get_center())   # SC2-15 장승 트리거 (M2: 북쪽 출구 개방으로 장승이 동쪽으로 옮겨졌다)
	await until(func(): return G.flag("jangseung_seen") == 1, "SC2-15 장승 첫 접촉", 1500)
	step("산길 서쪽 출구 → 화개 저자 (이어하기 저장값 유지)")
	await until(func(): return not player().locked, "조작 가능", 1500)
	iid = level_iid()
	await tp(exit_center(0))
	await until(func(): return level_ready("hwagae", iid), "화개 저자 복귀", 3000)
	await must(G.flag("ch2_old_man") == 1 and lvl().npc("elder").visible, "복귀해도 출구·노인 상태 유지")
	await done()


# ================================================================ 2장 진입 (prog/ch2-enter)
## 스위치 켜짐(--ch2): SC1-24/25 작별 → 1절 → 2장 화개 저자로 이어진다 (타이틀로 가지 않는다)
func sc_ch2_farewell() -> void:
	step("--ch2 켜짐 확인")
	await must(G.ch2_enabled(), "ch2_enabled() 켜짐(--ch2)")
	for f in ["arrived", "met_nanyeong", "sang_child", "rescued", "nanyeong_woke", "rumor", "king_call", "flute", "appointed"]:
		G.flags[f] = 1
	G.checkpoint = "gyeongju"
	G.level_id = "gyeongju"
	G.spawn_name = "home"
	step("SC1-24/25 작별 → 1절 → 2장")
	pump = true
	await boot_level()
	await until(func(): return G.flag("chapter1_done") == 1, "1장 완료 플래그", 6000)
	await until(func(): return level_ready("hwagae"), "작별 뒤 화개 저자 진입 (타이틀 아님)", 3000)
	await must(G.checkpoint == "hwagae", "체크포인트 = hwagae")
	await until(func(): return G.flag("ch2_start") == 1, "SC2-01 시작 (ch2_start)", 1500)
	await must(save_flags().get("chapter1_done", 0) == 1, "디스크 세이브에 chapter1_done 유지")
	await done()


## 스위치 켜짐: 끝난 1장 세이브를 이어하기 → 화개 저자 (이어하기는 change_level 도중 _busy 에서 레벨 훅이 돈다)
func sc_ch2_continue() -> void:
	step("완료 세이브 작성 (chapter1_done, 2장 시작 전)")
	await must(G.ch2_enabled(), "ch2_enabled() 켜짐(--ch2)")
	G.new_game()
	for f in ["beach_done", "arrived", "met_nanyeong", "sang_child", "rescued", "nanyeong_woke", "rumor", "king_call", "flute", "appointed", "chapter1_done"]:
		G.set_flag(f)
	G.checkpoint = "gyeongju"
	G.save()
	await must(G.has_save(), "세이브 파일 생성")
	step("타이틀 → 이어하기 → 화개 저자")
	await boot("res://scenes/title.tscn")
	await until(func(): return scene_name() == "title.tscn" and current_scene.get("_ready_t") > 0.9, "타이틀 준비", 600)
	await must("continue" in title_actions(), "'이어하기' 노출")
	await must(current_scene._sel == title_actions().find("continue"), "완료 세이브: 이어하기가 기본 선택")
	_tap("confirm")
	await until(func(): return level_ready("hwagae"), "완료 세이브 이어하기 → 화개 저자", 2500)
	await must(G.checkpoint == "hwagae", "체크포인트 = hwagae")
	await done()


## 스위치 꺼짐(기본): 2장 세이브(checkpoint=hwagae)를 이어해도 2장 지점으로 들어가지 않는다 → 경주 복귀 + '2장은 준비 중'
func sc_ch2_off_continue() -> void:
	step("2장 세이브 작성 (스위치 꺼짐 빌드에서 이어하기)")
	await must(not G.ch2_enabled(), "ch2_enabled() 꺼짐(기본)")
	G.new_game()
	for f in ["beach_done", "arrived", "met_nanyeong", "sang_child", "rescued", "nanyeong_woke", "rumor", "king_call", "flute", "appointed", "chapter1_done", "ch2_start"]:
		G.set_flag(f)
	G.checkpoint = "hwagae"
	G.save()
	await boot("res://scenes/title.tscn")
	await until(func(): return scene_name() == "title.tscn" and current_scene.get("_ready_t") > 0.9, "타이틀 준비", 600)
	await must("continue" in title_actions(), "'이어하기' 노출")
	await must(current_scene._sel == title_actions().find("continue"), "완료 세이브: 이어하기가 기본 선택")
	_tap("confirm")
	await until(func(): return level_ready("gyeongju"), "꺼짐 빌드: 2장 세이브가 경주로 복귀", 2500)
	await tick(120)
	await must(G.level_id == "gyeongju", "여전히 경주 (hwagae 로 가지 않음)")
	await must(G.checkpoint_spawn()[0] == "gyeongju", "꺼짐 상태의 재시작·사망 지점도 경주 (checkpoint 값 자체는 보존)")
	await must(G.flag("ch2_start") == 1, "2장 진행 플래그는 보존 (스위치를 다시 켜면 이어진다)")
	await done()


# ================================================================ 2장 M2: 버려진 마을(의뢰 B) → 소굴 외곽(SC2-04·05) → 곳간(SC2-21, 동문) → 두억시니의 방(SC2-06·07, 체크포인트)
## 연출 전 전투 확정 방지: 스폰은 요괴에서 어그로(130, lift 좌표) 140 이상, 연출 순간 요괴는 전부 idle. 지형상 걷기는 tests/ch2_aggro.sh(--live) 가 따로 검증한다.
func spawns_safe(note: String) -> void:
	var l := lvl()
	for sp in l.def["spawns"]:
		var a: Vector2 = l.lift(l.def["spawns"][sp])
		var near := 9999.0
		for e in l.def.get("enemies", []):
			near = minf(near, a.distance_to(l.lift(Vector2(e[1], e[2]))))
		await must(near >= 140.0, "%s 스폰 %s ↔ 가장 가까운 요괴 %.0f ≥ 140 (어그로 130)" % [note, sp, near])


## 연출 트리거(사각형 모서리·중심) ↔ 모든 요괴 ≥ 140 (어그로 130): 트리거를 밟는 순간 전투가 확정돼 있으면 안 된다
func triggers_safe(note: String) -> void:
	var l := lvl()
	for tr in l.def.get("triggers", []):
		var r: Rect2 = tr[0]
		var near := 9999.0
		for pt in [r.position, r.position + Vector2(r.size.x, 0), r.position + Vector2(0, r.size.y), r.end, r.get_center()]:
			for e in l.def.get("enemies", []):
				near = minf(near, l.lift(pt).distance_to(l.lift(Vector2(e[1], e[2]))))
		await must(near >= 140.0, "%s 트리거 %s ↔ 가장 가까운 요괴 %.0f ≥ 140 (어그로 130)" % [note, tr[1], near])


func all_idle() -> bool:
	for e in get_nodes_in_group("enemy"):
		if e.get("state") != "idle":
			return false
	return true


func goto_exit(i: int, to_level: String) -> void:
	var iid := level_iid()
	await free_player()
	player().position = lvl().lift(exit_center(i))   # 풀린 즉시 같은 프레임에 출구로 (연타가 근처 상호작용을 다시 열어 묶지 않게; 연출 직후 대사는 호출 쪽이 tick 으로 기다린다)
	await tick(3)
	await until(func(): return level_ready(to_level, iid), "%s 진입" % to_level, 3000)
	await tick(3)


func sc_ch2_m2() -> void:
	step("준비: 1장을 끝내고 M1(화개 저자·산길)을 지난 세이브")
	G.flags["ch2_unlocked"] = 1
	for f in ["chapter1_done", "appointed", "rumor", "king_call", "flute", "ch2_start", "raided", "night", "ch2_old_man"]:
		G.flags[f] = 1
	G.level_id = "jiri_path"
	G.spawn_name = "start"
	pump = true
	await boot_level()
	await free_player()
	await must(lvl().def["exits"].size() == 3, "산길 출구 3개 (서·북·동)")
	await must(get_nodes_in_group("enemy").size() == 6, "산길 요괴 6체")
	await spawns_safe("산길")
	await triggers_safe("산길")

	step("산길 북쪽 → 버려진 마을 (SC2-17)")
	await goto_exit(1, "old_village")
	await must(G.checkpoint == "old_village" and G.checkpoint_spawn() == ["old_village", "start"], "체크포인트·이어하기 = old_village")
	await must(get_nodes_in_group("enemy").size() == 4, "마을 요괴 4체 (불도깨비 3·외눈박이 1)")
	await spawns_safe("마을")
	await until(func(): return G.flag("village_seen") == 1, "SC2-17 마을 진입 연출", 900)
	await must(all_idle(), "연출 중 요괴 전부 idle")
	await free_player()

	step("의뢰 B: 사연(SC2-18) → 짚인형(SC2-19) → 무덤 굿(SC2-20), 전투 없이 +30%")
	await must(G.flag("q_b") == 0, "산신각 전이라 q_b = 0")
	await tp_to_npc("girl_soul")
	await interact("girl_soul")
	await until(func(): return G.flag("girl_heard") == 1 and not player().locked, "SC2-18 사연", 1500)
	await must(G.flag("q_b") == 1 and G.flag("q_b_clean") == 1, "수주 q_b=1, 무전투 보너스 유효")
	await free_player()
	await tp_to_interact("doll")
	await interact("doll")
	await until(func(): return G.flag("q_b") == 2 and not player().locked, "SC2-19 짚인형 회수", 900)
	await free_player()
	await tp_to_interact("grave")
	var jg0: int = G.jeonggi
	var dk0: int = G.deok if G.get("deok") != null else 0
	await interact("grave")
	await until(func(): return G.flag("q_b") == 3 and not player().locked, "SC2-20 무덤 굿", 2500)
	await must(G.jeonggi - jg0 >= 104, "무전투 보상 정기 +104 (80×1.3): +%d" % (G.jeonggi - jg0))
	await must(not lvl().npc("girl_soul").visible, "아이 넋 승천")
	G.save()

	step("마을 → 산길(fromVillage) 복귀 → 동쪽 소굴 외곽 (SC2-04)")
	await goto_exit(0, "jiri_path")
	await must(G.checkpoint == "jiri_path", "산길 체크포인트")
	await spawns_safe("산길 복귀")
	await must(all_idle(), "북쪽 도착 직후 요괴 전부 idle")
	await goto_exit(2, "den1")
	await must(G.checkpoint == "den1" and G.checkpoint_spawn() == ["den1", "start"], "체크포인트·이어하기 = den1")
	await must(get_nodes_in_group("enemy").size() == 7, "소굴 외곽 요괴 7체")
	await spawns_safe("소굴 외곽")
	await triggers_safe("소굴 외곽")
	step("SC2-04: 입구에서 오른쪽으로 걸어 sight 트리거 (tp 없음)")
	await free_player()
	Input.action_press("move_right")
	await until(func(): return G.flag("den_sight") == 1, "SC2-04 졸개의 목소리 (걸어서)", 900)
	Input.action_release("move_right")
	await must(all_idle(), "SC2-04 순간 요괴 전부 idle (연출 전 전투 확정 없음)")
	await tick(8)   # 트리거 다음 프레임에 대사가 열린다
	await free_player()

	step("SC2-05: 외눈박이 감투 → 용패 (잔영 3회 한정)")
	var a_pos: Vector2 = lvl().lift(Vector2(222, 181))   # den1 oneeye_A (새 지형 좌표)
	god = true
	player().position = a_pos + Vector2(-60, 0)
	await until(func(): return G.flag("yongpae_trace_n") >= 1, "외눈박이 첫 감투 (SC2-05 문구·잔영)", 1800)
	await must(G.flag("yongpae_trace_n") <= 3, "잔영 3회 한정")
	cs_purge()
	god = false
	await tick(5)
	step("깊은 곳(deep) 트리거 → 처용 독백")
	await tp(Vector2(740, 200))   # deep 트리거 중심 (C 덩굴 방 안쪽)
	await until(func(): return G.flag("den_deep") == 1, "deep 트리거", 600)
	await tick(8)
	await free_player()

	step("동쪽 → 도깨비 곳간 (SC2-21), 동문 막힘")
	await goto_exit(1, "den2")
	await must(G.checkpoint == "den2", "체크포인트 = den2")
	await must(get_nodes_in_group("enemy").size() == 4, "곳간 요괴 4체 (장산범 정예 1 + 외눈박이 2 + 불도깨비 1)")
	await spawns_safe("곳간")
	await until(func(): return G.flag("den2_seen") == 1, "SC2-21 곳간 입장", 900)
	await must(all_idle(), "SC2-21 순간 요괴 전부 idle")
	await free_player()
	var door = lvl().get_meta("door", null)
	await must(is_instance_valid(door), "동쪽 문 막이 서 있다 (정예 정화 전)")
	await must(G.flag("den2_gate_cleared") == 0, "den2_gate_cleared = 0")
	step("장산범 정화(실제 노래) → 동쪽 문 열림")
	var elite = null
	for e in get_nodes_in_group("enemy"):
		if e.get("kind") == "jangsanbeom":
			elite = e
	await must(elite != null, "정예 장산범이 있다")
	for e in get_nodes_in_group("enemy"):
		if e != elite:
			e.remove_from_group("enemy")
			e.queue_free()
	god = true
	elite.take_hit(9999, Vector2.ZERO)
	await tick(3)
	await until(func(): return elite.state == "downed", "장산범 쓰러짐", 600)
	player().position = elite.position + Vector2(-14, 4)
	await tick(2)
	await sing_now()
	await until(func(): return G.flag("den2_gate_cleared") == 1, "동쪽 문 해금 플래그", 900)
	await tick(3)
	await must(not is_instance_valid(door), "동쪽 문 막이 사라졌다")
	god = false
	G.save()

	step("두억시니의 방 (SC2-06·07): 입구에서 오른쪽으로 걸어 gate 트리거, 체크포인트 den3")
	await goto_exit(1, "den3")
	await must(G.checkpoint == "den2", "연출 전 체크포인트는 den2")
	await must(G.flag("boss2_intro_seen") == 0, "boss2_intro_seen = 0")
	await free_player()
	Input.action_press("move_right")
	await until(func(): return G.flag("boss2_intro_seen") == 1, "SC2-06 gate (걸어서)", 900)
	Input.action_release("move_right")
	await until(func(): return G.checkpoint == "den3", "체크포인트 den3", 60)
	await until(func(): return not player().locked, "SC2-06·07 끝", 2500)
	await must(G.checkpoint_spawn() == ["den3", "start"], "이어하기·사망 리스폰 = den3 start")
	step("재도전: 연출 건너뜀 (boss2_intro_seen)")
	G.level_id = "den3"
	G.spawn_name = "start"
	var iid2 := level_iid()
	await boot_level()
	await free_player()
	Input.action_press("move_right")
	await until(func(): return player().position.x > lvl().lift(Vector2(130, 0)).x, "gate 통과", 900)
	Input.action_release("move_right")
	await tick(30)
	await must(lvl()._talking == 0, "재도전: 대사창 없음 (SC2-06~07 스킵)")
	await until(func(): return not player().locked, "1초 뒤 풀림", 600)

	step("이어하기 지점: 스위치 켜짐=각 맵 start, 꺼짐=경주")
	for id in ["old_village", "den1", "den2", "den3"]:
		G.checkpoint = id
		await must(G.checkpoint_spawn() == [id, "start"], "켜짐 checkpoint=%s → start" % id)
	G.flags["ch2_unlocked"] = 0
	for id in ["old_village", "den1", "den2", "den3"]:
		G.checkpoint = id
		await must(G.checkpoint_spawn()[0] == "gyeongju", "꺼짐 checkpoint=%s → 경주(2장 지점으로 들이지 않음)" % id)
	await done()
