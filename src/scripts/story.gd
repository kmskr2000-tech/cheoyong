extends Node
## Story beats (autoload "Story"): what happens when a level opens, when the hero walks into a
## trigger and when he talks to / examines something. Lines follow docs/story-bible.md
## (말투 ~하오, 처용은 짧게; 튜토리얼은 글 대신 빛나는 버튼으로).

## per-NPC lines for 경주 일상 (SC1-10 생활 대사); later chapters key off Game flags
const TALK := {
	"nanyeong": [{"name": "난영", "text": "처음 보시는 얼굴이오. 약재는 무슨 병에 쓰시오?"}],
	"apothecary": [{"name": "약방 주인", "text": "요즘 역병 때문에 약재가 동이 났소."}],
	"elder": [{"name": "노인", "text": "서쪽 폐가에는 가지 말게. 들어간 사람이 못 나왔어."}],
	"villagerA": [{"name": "마을 아낙", "text": "밤마다 기침 소리가 담을 넘어오오. 문을 꼭 걸어 두시오."}],
	"villagerB": [{"name": "나무꾼", "text": "산에 들면 나무가 검게 젖어 있소. 비도 안 왔는데 말이오."}],
	"villagerC": [{"name": "기침하는 사내", "text": "콜록… 괜찮소. 그냥… 고뿔이오."}],
	"board": [{"text": "방(榜): 역병이 도니 해 진 뒤 바깥 출입을 삼가라. — 관아"}],
	"fisherA": [{"name": "어부", "text": "바다에서 올라온 것이 노래 한 가락에 녹아 버렸소. 평생 처음 보오."}],
	"fisherB": [{"name": "아낙", "text": "고맙소, 고맙소… 우리 애 아버지가 저것한테 끌려갈 뻔했소."}],
	"fisherC": [{"name": "어부", "text": "요즘 바다가 이상하오. 그물에 검은 물이 묻어 나와."}],
}


func on_enter(level: Node) -> void:
	if Game.level_id != "beach":
		Game.set_flag("flute")   # 백사장 이후에는 언제나 피리를 지니고 있다 (테스트 진입 대비)
	match Game.level_id:
		"beach":
			if "--beach-fight" in OS.get_cmdline_user_args():  # test hook: straight to SC1-05
				_test_fight(level)
			elif not Game.flag("beach_done"):
				_beach_wake(level)
		"pyega2":
			if not Game.flag("boss_done"):
				_pyega2_enter(level)
		"gyeongju":
			Game.set_flag("arrived")
			_gyeongju_enter(level)
		"hwagae":
			_hwagae_enter(level)
		"jiri_path":
			_jiri_enter(level)
		"old_village":
			_village_enter(level)
		"den1":
			_den1_enter(level)
		"den2":
			_den2_enter(level)
		"den3":
			_den3_enter(level)


const RUMOR := {
	"villagerA": [{"name": "마을 아낙", "text": "탈을 쓴 어사님이오! 그분 얼굴을 깎아 문에 걸면 역병이 비켜 간다오."}],
	"villagerB": [{"name": "나무꾼", "text": "그날 밤 서쪽 하늘이 오색으로 물들었다지 뭐요. 노랫소리도 들렸다고."}],
	"elder": [{"name": "노인", "text": "노래로 역신을 물리친 자가 있다더군. …살다 보니 별일을 다 듣네."}],
	"apothecary": [{"name": "약방 주인", "text": "약재가 다시 돌기 시작했소. 사위 덕이오. …허허."}],
	"child": [{"name": "아이", "text": "형, 어젯밤에 이상한 노래가 들렸어!"}],
	"villagerC": [{"name": "사내", "text": "기침이 멎었소. 탈을 문에 건 날부터."}],
	"nanyeong": [{"name": "난영", "text": "사람들이 당신 얼굴을 탈로 깎아 문에 거오. …닮지는 않았소."}],
}


func interact(level: Node, id: String) -> void:
	if Game.level_id in Game.CH2_LEVELS:   # 2장: 1장의 소문·잡담 표와 섞이지 않게 따로 처리
		await _ch2_interact(level, id)
		return
	if Game.flag("rumor") and RUMOR.has(id) and not Game.flag("appointed"):
		await level.talk(RUMOR[id])
		if not "cheoyong" in Game.tals and id in ["villagerA", "elder", "villagerB", "villagerC", "apothecary"]:
			# SC1-21 → 처용탈 (growth-system §3): the mask they hang on gates, carved for him to wear
			await level.talk([{"name": RUMOR[id][0]["name"], "text": "어사님 것도 하나 깎아 왔소. 문에 거는 것 말고, 쓰시라고."}])
			Game.give_tal("cheoyong")
		return
	match id:
		"flute": _pick_flute(level)
		"nanyeong": _talk_nanyeong(level)
		"apothecary": _shop(level)
		"home": _rest(level)
		"child":
			await level.talk([{"name": "아이", "text": "형, 어젯밤에 이상한 노래가 들렸어!"}] if Game.flag("night")
				else [{"name": "아이", "text": "…몸이 따뜻해졌어. 바닷소리가 났어."}])
		"gwanri": _briefing(level)
		"guardA", "guardB":
			await level.talk([{"name": "포졸", "text": "밤마다 서쪽에서 개 짖는 소리가 나오. …사람 소리 같기도 하고."}])
		"villagerC":
			await level.talk([{"name": "기침하는 사내", "text": "콜록, 콜록… 관아 쪽으로 사람들이 몰려가오…"}] if Game.flag("night")
				else TALK["villagerC"])
		_:
			await level.talk(TALK.get(id, [{"text": "…"}]))


func trigger(level: Node, id: String) -> void:
	match id:
		"fight": _fight(level)
		"close": _close(level)
		"inner": _inner_room(level)
		"audience": _audience(level)
		"raid": _raid(level)
		"jangseung": _jangseung_first(level)
		"sight": _den1_sight(level)
		"deep": _den1_deep(level)
		"gate": _den3_gate(level)


# ================================================================ 1장 1-1 백사장 (SC1-01~04)
## SC1-01: 파도 소리. 처용이 모래 위에서 눈을 뜬다 — 무음, 글 없음
func _beach_wake(level: Node) -> void:
	var p: Node2D = level.get_node("Player")
	p.locked = true
	p.state = "lie"   # no state branch runs: he stays as posed
	level.hud.visible = false
	p.sprite.rotation = -PI / 2
	p.sprite.modulate = Color(0.75, 0.8, 0.95)
	await level.get_tree().create_timer(3.0).timeout   # 인트로 샷 5: 무음 3초
	if not Game.flag("logo_shown"):
		# 샷 6: 타이틀 로고와 복선 — '돌아오겠다'는 말은 하지 않는다
		Game.set_flag("logo_shown")
		await Game.card("신 처용가", "노래가 완성되면 —", 2.6)
	var tw := p.create_tween().set_parallel()
	tw.tween_property(p.sprite, "rotation", 0.0, 0.7).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.tween_property(p.sprite, "modulate", Color.WHITE, 0.7)
	await tw.finished
	await level.get_tree().create_timer(0.4).timeout
	p.state = "move"
	p.locked = false
	level.hud.reveal()


## SC1-03: 떠밀려온 대나무 피리 → SC1-04: 멀리 해안 마을에서 비명
func _pick_flute(level: Node) -> void:
	level.remove_interact("flute")
	Audio.sfx("pickup", -4.0, 0.0)
	Game.set_flag("flute")
	Game.say_toast("대나무 피리를 주웠다.")
	await level.get_tree().create_timer(1.6).timeout
	# the creature comes up into the village; the fishers scatter
	var yokai: Enemy = level.spawn_enemy("sea", level.def["anchors"]["yokai"])
	yokai.name = "Gaetgwi"
	_arm_fight(level, yokai)   # B03: purifying him before the trigger is stepped on must still end the scene
	for id in ["fisherA", "fisherB", "fisherC"]:
		var n: Npc = level.npc(id)
		n.set_present(true)
		n.talkable = false
	# look up toward the screams, then back
	var p: Node2D = level.get_node("Player")
	var cam: Camera2D = p.get_node("Camera")
	p.locked = true
	var tw := cam.create_tween()
	tw.tween_property(cam, "offset", yokai.global_position - p.global_position + Vector2(0, 20), 0.9).set_trans(Tween.TRANS_SINE)
	await tw.finished
	await level.talk([{"name": "마을 사람", "text": "요괴다! 요괴가 나타났다!"}])
	tw = cam.create_tween()
	tw.tween_property(cam, "offset", Vector2.ZERO, 0.7).set_trans(Tween.TRANS_SINE)
	await tw.finished
	p.locked = false
	level.add_trigger(level.def["anchors"]["fight"], "fight")


func _test_fight(level: Node) -> void:
	Game.set_flag("flute")
	level.remove_interact("flute")
	level.spawn_enemy("sea", level.def["anchors"]["yokai"]).name = "Gaetgwi"
	for id in ["fisherA", "fisherB", "fisherC"]:
		level.npc(id).set_present(true)
		level.npc(id).talkable = false
	level.get_node("Player").position = level.lift(level.def["anchors"]["fight_player"])
	await level.get_tree().process_frame
	if "--beach-early-purify" in OS.get_cmdline_user_args():   # B03 test hook: the chain must be armed before any trigger is stepped on
		var y: Enemy = level.get_node("Gaetgwi")
		_arm_fight(level, y)
		print("EARLY_PURIFY_ARMED=", y.purified.get_connections().size())
		return
	_fight(level)


# ================================================================ 1장 1-2 첫 전투와 천거 (SC1-05~07)
## SC1-05: 튜토리얼 전투 — 베기 → 구르기 → 정화. 글 없이, 해야 할 버튼 하나만 빛난다.
func _fight(level: Node) -> void:
	var yokai: Enemy = level.get_node_or_null("Gaetgwi")
	if yokai == null:
		return
	_arm_fight(level, yokai)
	var p: Node2D = level.get_node("Player")
	p.gentle_hits = 3          # 벌 없이 배운다
	yokai.cd = 3.5             # 먼저 베기를 배울 틈을 준다
	level.hud.guide("attack")
	yokai.hit_taken.connect(func():
		if level.hud._guide == "attack":
			level.hud.guide(""), CONNECT_ONE_SHOT)
	yokai.telegraph.connect(func():
		await _teach_roll(level)
		if is_instance_valid(yokai):   # CS-09: 두 번째 예고에서 "맞기 직전에 구르면 받아넘긴다"를 버튼 점등만으로 보여 준다
			yokai.telegraph.connect(func(): _teach_parry(level, yokai), CONNECT_ONE_SHOT), CONNECT_ONE_SHOT)
	yokai.collapsed.connect(func(): level.hud.guide("song"))


## connect the "he is purified → SC1-06" chain exactly once, as soon as the 개귀 exists
func _arm_fight(level: Node, yokai: Enemy) -> void:
	if yokai.has_meta("fight_armed"):
		return
	yokai.set_meta("fight_armed", true)
	yokai.purified.connect(func(): _after_fight(level), CONNECT_ONE_SHOT)


## the first wind-up: time slows and the roll button glows until he rolls (or the slam lands)
func _teach_roll(level: Node) -> void:
	var p: Node2D = level.get_node("Player")
	level.hud.guide("roll")
	Engine.time_scale = 0.3
	var until := Time.get_ticks_msec() + 2500
	while Time.get_ticks_msec() < until and p.state != "roll":
		await level.get_tree().process_frame
	Engine.time_scale = 1.0
	if level.hud._guide == "roll":
		level.hud.guide("")


## CS-09: 두 번째 예고 — 구르기 버튼만 빛나고 시간이 느려진다. 글 없음. (갯귀 gentle_hits 3 은 그대로: 틀려도 벌이 없다)
func _teach_parry(level: Node, yokai: Node) -> void:
	var p: Node2D = level.get_node("Player")
	level.hud.guide("roll")
	var until := Time.get_ticks_msec() + 3500
	while Time.get_ticks_msec() < until and is_instance_valid(yokai) and p.state != "roll" and yokai.state in ["tell", "strike"]:
		Engine.time_scale = 0.5 if yokai.state == "tell" else 1.0
		await level.get_tree().process_frame
	Engine.time_scale = 1.0
	if level.hud._guide == "roll":
		level.hud.guide("")


## SC1-06: 정화 후 환호, 수령 등장 → SC1-07: 처용, 말없이 고개 끄덕. 화면 전환: 경주
func _after_fight(level: Node) -> void:
	level.hud.guide("")
	Engine.time_scale = 1.0
	var p: Node2D = level.get_node("Player")
	await level.get_tree().create_timer(1.0).timeout
	p.locked = true
	await level.talk([
		{"name": "어부", "text": "자, 잠들었소…? 저것이 노래 한 가락에…!"},
		{"name": "아낙", "text": "살았다…! 살았소!"},
	])
	var su: Npc = level.npc("suryeong")
	su.set_present(true)
	su.talkable = false
	await su.walk_to(p.position + Vector2(44, -6), 46.0)
	p.facing = "right"
	p.sprite.flip_h = false
	p.sprite.play("right_idle")
	await level.talk([
		{"name": "수령", "text": "개운포 수령 한기요. 바닷가에서 들려온 그 노래, 나도 들었소."},
		{"name": "수령", "text": "요괴를 다스리는 자가 있다 하오. 조정에서 쓰겠소."},
	])
	p.locked = true
	# the nod — no words
	var tw := p.create_tween()
	tw.tween_property(p.sprite, "position:y", 2.0, 0.18)
	tw.tween_property(p.sprite, "position:y", 0.0, 0.25)
	await tw.finished
	await level.get_tree().create_timer(0.7).timeout
	Game.set_flag("beach_done")
	Game.set_flag("arrived")
	Game.checkpoint = "gyeongju"
	Game.change_level("gyeongju", "start", "서라벌", "경주 변두리")


# ================================================================ 1장 1-3 경주 일상과 난영 (SC1-08~11)
const DAY_PEOPLE := ["nanyeong", "apothecary", "elder", "villagerA", "villagerB"]


func _gyeongju_enter(level: Node) -> void:
	if Game.flag("rumor"):
		_gyeongju_after(level)
		return
	if Game.flag("met_nanyeong") and not Game.flag("sang_child"):
		_show_sick_child(level)
	elif Game.flag("sang_child"):
		level.npc("child").set_present(true)
	if Game.flag("night"):
		for id in DAY_PEOPLE:
			level.npc(id).set_present(false)   # 밤: 다들 문을 걸어 잠갔다
		if not Game.flag("nanyeong_fallen") or Game.flag("rescued"):
			var nan: Npc = level.npc("nanyeong")   # 이제 처용의 아내: 집 앞에 있다
			nan.set_present(true)
			nan.position = level.lift(level.def["anchors"]["home_nanyeong"])
		if Game.flag("rescued") and not Game.flag("nanyeong_woke"):
			_nanyeong_wakes(level)
		elif not Game.flag("summoned"):
			_night_summons(level)
		else:
			_open_road_to_gwana(level)
		if Game.flag("briefed") and not Game.flag("rescued"):
			level._exit(level.def["gates"]["pyega"])
			if Game.spawn_name == "fromGwana":   # 관아에서 막 돌아왔다: 서쪽 길이 열렸음을 한 줄로 알린다 (§3.7)
				_announce_once("pyega_open", "서쪽 길이 열렸다.")


## SC1-08: 약방 앞. 난영 첫 등장.
func _talk_nanyeong(level: Node) -> void:
	if not Game.flag("met_nanyeong"):
		await level.talk([
			{"name": "난영", "text": "처음 보시는 얼굴이오. 약재는 무슨 병에 쓰시오?"},
			{"name": "처용", "text": "…목이 쉬었소."},
			{"name": "난영", "text": "노래하는 분이구려. 길경을 달여 드시오. 값은 아버지께 치르시고."},
			{"name": "난영", "text": "…금줄 친 집 아이가 사흘째 열이 내리지 않소. 아버지 약도 듣지 않고."},
		])
		Game.set_flag("met_nanyeong")
		_show_sick_child(level)
	elif Game.flag("chapter1_done"):
		await level.talk([{"name": "난영", "text": "…노래가 완성되면, 라 했소. 기다리고 있겠소."}])
	elif Game.flag("night") and not Game.flag("rescued"):
		await level.talk([{"name": "난영", "text": "다녀오시오. …바람에서 탁한 냄새가 나오."}])
	elif not Game.flag("sang_child"):
		await level.talk([{"name": "난영", "text": "탁한 기운이 그 집 마당에 고여 있소. 약으로 될 일이 아닌 것 같소."}])
	else:
		await level.talk([{"name": "난영", "text": "아이는 이제 괜찮소. …고맙다는 말은 아이 어미가 할 거요."}])


## SC1-09: 금줄 너머, 탁기에 든 아이. 노래 버튼이 저절로 빛난다 (can_sing).
func _show_sick_child(level: Node) -> void:
	var child: Npc = level.npc("child")
	child.set_present(true)
	child.talkable = false
	child.set_afflicted(true)
	if not child.cleansed.is_connected(_on_child_cleansed):
		child.cleansed.connect(_on_child_cleansed.bind(level), CONNECT_ONE_SHOT)


func _on_child_cleansed(level: Node) -> void:
	var p: Node2D = level.get_node("Player")
	var child: Npc = level.npc("child")
	await level.get_tree().create_timer(1.6).timeout
	p.locked = true
	# 난영이 지켜보고 있었다
	var nan: Npc = level.npc("nanyeong")
	var home := nan.position
	await nan.walk_to(p.position + Vector2(30, -10), 50.0)
	await level.talk([
		{"name": "난영", "text": "당신, 무당이오?"},
		{"name": "처용", "text": "아니오. 그냥 노래하는 사람이오."},
	])
	p.locked = true
	await level.get_tree().create_timer(0.9).timeout   # 난영은 묻지 않는다
	await level.talk([{"name": "난영", "text": "…아이 어미를 불러 오겠소."}])
	p.locked = true
	child.talkable = true
	Game.set_flag("sang_child")
	await nan.walk_to(home, 50.0)
	p.locked = false


func _shop(level: Node) -> void:
	await level.talk([{"name": "약방 주인", "text": "요즘 역병 때문에 약재가 동이 났소. 남은 거라도 보시겠소?"}])
	var p: Node2D = level.get_node("Player")
	p.locked = true
	while true:
		var opts := []
		for it in Game.SHOP:
			opts.append("%s  %d냥" % [it["name"], it["price"]])
		opts.append("그만두겠소")
		var i: int = await level.dialog.choose({"name": "약방 주인", "text": "엽전 %d냥이 있구려. 무얼 드릴까?" % Game.money}, opts)
		if i >= Game.SHOP.size():
			break
		var it: Dictionary = Game.SHOP[i]
		if Game.money < it["price"]:
			await level.talk([{"name": "약방 주인", "text": "값이 모자라오."}])
		else:
			Game.money -= it["price"]
			Game.items[it["id"]] = int(Game.items.get(it["id"], 0)) + 1
			Game.say_toast("%s — %s" % [it["name"], it["desc"]])
		p.locked = true
	p.locked = false


## SC1-10 휴식: 집에서 쉬면 기력이 차고 기록된다. 아이를 고친 뒤라면 밤이 온다 (SC1-11).
func _rest(level: Node) -> void:
	var p: Node2D = level.get_node("Player")
	p.locked = true
	var i: int = await level.dialog.choose({"text": "처용의 거처. 쉬어 가겠소?"}, ["쉬어 간다", "그만둔다"])
	if i != 0:
		p.locked = false
		return
	p.hp = p.max_hp
	p.ki = p.max_ki
	p.stats_changed.emit(p.hp, p.max_hp, p.ki, p.max_ki)
	Game.checkpoint = "gyeongju"
	if Game.flag("rumor") and not Game.flag("king_call"):
		Game.set_flag("king_call")
		Game.set_flag("night")
		Game.save()
		Game.change_level("gyeongju", "home", "그날 밤", "")
		return
	if Game.flag("sang_child") and not Game.flag("night"):
		# 바이블 장면 5: 혼례까지는 길게 그리지 않는다 — 몇 개의 일상 컷
		await Game.fade(1.0, 1.2)
		for line in ["봄. 약방 마당에 도라지꽃이 피었다.",
				"여름. 쉰 목에 난영이 길경차를 내왔다.\n처용은 묻지 않았고, 난영도 묻지 않았다.",
				"가을. 두 사람은 조촐한 혼례를 올렸다."]:
			await Game.card("", line, 2.2)
		Game.set_flag("married")
		Game.set_flag("night")
		Game.save()
		Game.change_level("gyeongju", "home", "그날 밤", "")
		return
	await Game.fade(1.0, 0.6)
	Game.save()
	Game.say_toast("기력을 되찾았다. (기록됨)")
	await Game.fade(0.0, 0.6)
	p.locked = false


## SC1-11: 밤. 기침 소리. 웅성거림. 관아 사람이 찾아온다.
func _night_summons(level: Node) -> void:
	var p: Node2D = level.get_node("Player")
	p.locked = true
	await level.get_tree().create_timer(1.4).timeout
	await level.talk(["(어디선가 기침 소리가 끊이지 않는다.)", "(담 너머로 웅성거리는 소리.)"])
	p.locked = true
	var off: Npc = level.npc("official")
	off.set_present(true)
	off.talkable = false
	await off.walk_to(p.position + Vector2(34, 4), 60.0)
	await level.talk([
		{"name": "관아 사람", "text": "급간 나리 되시오? 관아에서 찾으시오."},
		{"name": "관아 사람", "text": "역병이오."},
	])
	p.locked = true
	Game.set_flag("summoned")
	await off.walk_to(level.lift(level.def["anchors"]["gwana_gate"]), 70.0)
	off.set_present(false)
	p.locked = false
	_open_road_to_gwana(level, true)


func _open_road_to_gwana(level: Node, announce := false) -> void:
	if Levels.DATA.has("gwana"):
		level._exit(level.def["gates"]["gwana"])
		if announce:
			_announce_once("gwana_open", "관아로 가는 길이 열렸다.")


## 길이 열렸다는 토스트 — 세션당 한 번 (세이브에 새 키를 만들지 않는다)
var _announced := {}


func _announce_once(key: String, text: String) -> void:
	if _announced.has(key):
		return
	_announced[key] = true
	Game.say_toast(text, Color(0.8, 0.95, 1.0))


# ================================================================ 1장 1-4 역병 조사와 폐가 (SC1-12~15)
## SC1-12: 관아. 관리가 의뢰. 그리고 — 난영이 쓰러졌다는 소식.
func _briefing(level: Node) -> void:
	if Game.flag("briefed"):
		await level.talk([{"name": "형방 박문", "text": "서쪽 폐가요. 해 뜨기 전에 다녀오시오."}])
		return
	var p: Node2D = level.get_node("Player")
	await level.talk([
		{"name": "형방 박문", "text": "급간 처용이오? 개운포 수령 영감의 천거로 왔다는…"},
		{"name": "형방 박문", "text": "서쪽 폐가에서 역병이 시작됐다는 소문이오. 들어가 본 자가 없소."},
		{"name": "처용", "text": "…가겠소."},
		{"name": "형방 박문", "text": "관아에서 내주는 약이오. 폐가는 사람 몸으로 버틸 곳이 아니라 하오."},
	])
	# 난이도: the first dungeon comes with a safety net (인삼정기탕 ×2)
	Game.items["insam"] = int(Game.items.get("insam", 0)) + 2
	Game.say_toast("인삼정기탕 ×2 — 행낭에서 꺼내 쓰시오")
	p.locked = true
	var run: Npc = level.npc("runner")
	run.set_present(true)
	run.talkable = false
	await run.walk_to(p.position + Vector2(-30, 6), 110.0)
	await level.talk([
		{"name": "약방 일꾼", "text": "급간 나리! 아씨가… 난영 아씨가 쓰러졌소!"},
		{"name": "약방 일꾼", "text": "숨은 붙어 있는데, 아무리 불러도 깨어나질 않소!"},
	])
	p.locked = true
	await level.get_tree().create_timer(0.8).timeout   # 처용은 말이 없다
	Game.set_flag("briefed")
	Game.set_flag("nanyeong_fallen")
	Game.save()
	p.locked = false


## SC1-14: 탁기가 진해진다. 용패가 검게 울린다.
func _close(level: Node) -> void:
	var p: Node2D = level.get_node("Player")
	p.locked = true
	var cam: Camera2D = p.get_node("Camera")
	var tw := level.create_tween()
	for i in 8:
		tw.tween_property(cam, "offset", Vector2(randf_range(-2, 2), randf_range(-2, 2)), 0.04)
	tw.tween_property(cam, "offset", Vector2.ZERO, 0.05)
	level.hud.pulse_emblem(Color(0.1, 0.05, 0.15))
	await tw.finished
	await level.talk([{"name": "처용", "text": "…가깝다."}])


func _pyega2_enter(level: Node) -> void:
	var soul: Npc = level.npc("soul")
	soul.talkable = false
	soul.sprite.rotation = -PI / 2
	soul.modulate = Color(0.6, 0.78, 1.4, 0.7)
	var boss := PlagueGod.new()
	boss.name = "Boss"
	boss.position = level.lift(level.def["anchors"]["boss"])
	level.add_child(boss)
	boss.disguise()


## SC1-15~17: 최심부. 사람 모습의 역신이 난영의 넋 곁에 앉아 있다.
func _inner_room(level: Node) -> void:
	var boss: PlagueGod = level.get_node_or_null("Boss")
	if boss == null:
		return
	var p: Node2D = level.get_node("Player")
	p.locked = true
	level.add_barrier.call_deferred(level.def["anchors"]["door"])   # called from a physics callback
	# the door seals the room for 처용 and 역신 alone: anything that followed him in is thrown back out
	for e in level.get_tree().get_nodes_in_group("enemy") + level.get_tree().get_nodes_in_group("downed"):
		if e == boss or e is Npc or not (e is Node2D) or e.global_position.x < level.def["anchors"]["door_x"]:
			continue
		var out: Vector2 = level.lift(level.def["anchors"]["kicked"]) + Vector2(0, randf_range(-24, 24))
		e.global_position = out
	var cam: Camera2D = p.get_node("Camera")
	var tw := cam.create_tween()
	tw.tween_property(cam, "offset", (boss.global_position - p.global_position) * 0.6, 1.0).set_trans(Tween.TRANS_SINE)
	await tw.finished
	await level.talk([
		{"name": "역신", "text": "용의 아들이로구나. 냄새가 났다."},
		{"name": "역신", "text": "네 아내의 넋은 달콤하더구나. 노래하는 자여, 네 노래가 병을 이기더냐?"},
	])
	p.locked = true
	tw = cam.create_tween()
	tw.tween_property(cam, "offset", Vector2.ZERO, 0.6).set_trans(Tween.TRANS_SINE)
	await tw.finished
	# SC1-17: 대답 없이 피리를 든다
	p.locked = false
	p.sing()
	await level.get_tree().create_timer(1.2).timeout
	boss.awaken()
	if "--boss-weak" in OS.get_cmdline_user_args():  # test hook: verify the ending sequence
		boss.hp = 20.0
	level.hud.show_boss(boss, "역신(疫神)")
	Game.death_zone = "pyega2_boss"   # CS-07: 역신전 사망은 폐가2 와 따로 센다
	# CS-12(OQ-1, 디렉터 확정): 쓰러지면 보스방 입구에서 다시 일어선다. 몹은 되살아나지 않고 역신 HP·페이즈만 초기화된다.
	p.spawn = level.lift(level.def["anchors"]["boss_respawn"])
	boss.home_pos = boss.position
	p.died.connect(_boss_player_died.bind(level, boss))
	if "--boss-kneel" in OS.get_cmdline_user_args():  # test hook: skip straight to SC1-19
		await level.get_tree().create_timer(1.0).timeout
		boss.take_hit(9999, Vector2.ZERO)
	boss.phase_two.connect(_boss_phase_two.bind(level, boss))   # 재도전마다 다시 2페이즈를 겪으므로 ONE_SHOT 아님
	boss.knelt.connect(_boss_knelt.bind(level), CONNECT_ONE_SHOT)
	boss.defeated.connect(_boss_defeated.bind(level), CONNECT_ONE_SHOT)


## CS-12: 보스전 사망 → 역신은 잠시 멈추고, 처용이 입구에서 일어서면 HP·페이즈·졸개를 초기화한다
func _boss_player_died(level: Node, boss: PlagueGod) -> void:
	if not is_instance_valid(boss) or boss.state in ["kneel", "dead"]:
		return
	boss.stand_down()
	var p: Node = level.get_node("Player")
	await p.respawned
	if is_instance_valid(boss) and boss.state == "wait":
		boss.reset_fight()


## SC1-18
func _boss_phase_two(level: Node, boss: PlagueGod) -> void:
	boss.state = "wait"
	await level.talk([{"name": "역신", "text": "이럴 수가…! 노래가… 탁기를 걷어내다니!"}])
	if boss.state == "wait":   # one blow may cross phase two and the knee together: leave a kneeling god alone
		boss.phase_shift()   # CS-06: 전환 열림 1.2초(×1.5) · 안개 제거 · 소리 +30 뒤 전투 재개


## SC1-19: 무릎 꿇은 역신의 유언
func _boss_knelt(level: Node) -> void:
	await level.get_tree().create_timer(0.8).timeout
	await level.talk([{"name": "역신", "text": "왕이… 오신다."}])
	level.hud.guide("song")


## SC1-20: 난영의 넋이 몸으로 돌아간다
func _boss_defeated(level: Node) -> void:
	level.hud.guide("")
	var pl: Node = level.get_node("Player")
	for c in pl.died.get_connections():
		pl.died.disconnect(c["callable"])
	Game.set_flag("boss_done")
	Game.death_zone = ""
	var p: Node2D = level.get_node("Player")
	p.locked = true
	await level.get_tree().create_timer(2.6).timeout
	var soul: Npc = level.npc("soul")
	var tw := soul.create_tween().set_parallel()
	tw.tween_property(soul.sprite, "rotation", 0.0, 1.0)
	tw.tween_property(soul, "position:y", soul.position.y - 18, 2.0).set_trans(Tween.TRANS_SINE)
	tw.chain().tween_property(soul, "modulate", Color(0.9, 1.0, 1.6, 0.0), 1.2)
	await tw.finished
	Game.set_flag("rescued")
	Game.checkpoint = "gyeongju"
	Game.save()
	Game.change_level("gyeongju", "home", "새벽", "")


func _nanyeong_wakes(level: Node) -> void:
	var p: Node2D = level.get_node("Player")
	var nan: Npc = level.npc("nanyeong")
	nan.talkable = false
	nan.sprite.rotation = -PI / 2
	nan.sprite.modulate = Color(0.75, 0.75, 0.8)
	p.locked = true
	p.position = nan.position + Vector2(-26, 4)
	await level.get_tree().create_timer(1.6).timeout
	var tw := nan.create_tween().set_parallel()
	tw.tween_property(nan.sprite, "rotation", 0.0, 0.9).set_trans(Tween.TRANS_SINE)
	tw.tween_property(nan.sprite, "modulate", Color.WHITE, 0.9)
	await tw.finished
	await level.talk([{"name": "난영", "text": "…노래가 들렸소."}])
	p.locked = true
	Game.set_flag("nanyeong_woke")
	await level.get_tree().create_timer(1.0).timeout
	# SC1-21: 소문 확산 — 며칠 뒤, 대문마다 처용탈
	Game.set_flag("rumor")
	Game.flags.erase("night")
	Game.save()
	Game.change_level("gyeongju", "start", "며칠 뒤", "")


# ================================================================ 1장 1-6 임명과 작별 (SC1-21~25)
func _gyeongju_after(level: Node) -> void:
	var nan: Npc = level.npc("nanyeong")
	nan.position = level.lift(level.def["anchors"]["home_nanyeong"])   # 이제 처용의 집에 산다
	level.npc("child").set_present(true)
	if Game.flag("chapter1_done"):
		# SB-28: the ending was already seen. Continuing a finished save lands in free roam, not in the farewell again.
		nan.talkable = true
		if Game.ch2_enabled():
			_enter_ch2()   # 2장 스위치가 켜진 빌드: 끝난 1장 세이브는 곧장 2장으로
		else:
			Game.say_toast("2장은 준비 중입니다")   # SB-30
	elif Game.flag("appointed"):
		for id in DAY_PEOPLE + ["child", "villagerC"]:
			if id != "nanyeong":
				level.npc(id).set_present(false)
		_farewell(level)
	elif Game.flag("king_call"):
		for id in DAY_PEOPLE + ["child"]:
			if id != "nanyeong":
				level.npc(id).set_present(false)
		_royal_summons(level)


## SC1-22: 밤중, 왕의 부름
func _royal_summons(level: Node) -> void:
	var p: Node2D = level.get_node("Player")
	p.locked = true
	await level.get_tree().create_timer(1.2).timeout
	var off: Npc = level.npc("official")
	off.display_name = "내관"
	off.set_present(true)
	off.talkable = false
	await off.walk_to(p.position + Vector2(34, 4), 70.0)
	await level.talk([{"name": "내관", "text": "어명이오. 급간 처용은 지금 입궐하시오. …아무도 모르게."}])
	p.locked = true
	Game.change_level("palace", "start", "월성", "왕의 편전")


## SC1-22~23: 편전. 왕은 알고 있었다.
func _audience(level: Node) -> void:
	var p: Node2D = level.get_node("Player")
	p.locked = true
	p.facing = "up"
	p.sprite.play("up_idle")
	var cam: Camera2D = p.get_node("Camera")
	var king: Npc = level.npc("king")
	king.talkable = false
	var ct := cam.create_tween()
	ct.tween_property(cam, "offset", Vector2(0, (king.global_position.y - p.global_position.y) * 0.55), 1.2).set_trans(Tween.TRANS_SINE)
	await ct.finished
	await level.talk([
		{"name": "왕", "text": "네가 용궁의 셋째라는 것을 안다."},
		{"name": "처용", "text": "…!"},
		{"name": "왕", "text": "왕실에는 대대로 '밤의 일'을 기록하는 비기가 있다. 용패를 가져온 자가 처음은 아니다."},
		{"name": "왕", "text": "군대는 요괴를 죽일 수 있으나, 탁기는 흩어질 뿐이다. 죽이지 않고 풀어주는 자가 필요하다."},
		{"name": "왕", "text": "낮에는 급간, 밤에는 탈을 쓰고 전국을 돌아라."},
		{"name": "왕", "text": "처용. 너를 퇴마어사에 임명한다."},
	])
	p.locked = true
	var tw := p.create_tween()   # 말없이 엎드려 받는다
	tw.tween_property(p.sprite, "position:y", 3.0, 0.3)
	tw.tween_interval(0.6)
	tw.tween_property(p.sprite, "position:y", 0.0, 0.3)
	await tw.finished
	Game.set_flag("appointed")
	Game.flags.erase("night")
	Game.save()
	Game.change_level("gyeongju", "home", "떠나는 날", "")


## SC1-24: 난영과 작별. SC1-25: 1절 완성.
func _farewell(level: Node) -> void:
	var p: Node2D = level.get_node("Player")
	var nan: Npc = level.npc("nanyeong")
	nan.talkable = false
	p.locked = true
	p.position = nan.position + Vector2(-28, 6)
	p.facing = "right"
	p.sprite.flip_h = false
	p.sprite.play("right_idle")
	await level.get_tree().create_timer(1.2).timeout
	await level.talk([
		{"name": "난영", "text": "언제 돌아오오?"},
		{"name": "처용", "text": "노래가 완성되면."},
		{"name": "난영", "text": "그게 언제요?"},
	])
	# 대답하지 않는다. 대신 짧게 노래 한 구절을 부르고 떠난다.
	p.locked = false
	p.sing()
	await level.get_tree().create_timer(1.6).timeout
	p.locked = true
	p.facing = "right"
	p.sprite.play("right_walk")
	var tw := p.create_tween()
	tw.tween_property(p, "position", p.position + Vector2(170, 20), 3.2)
	await level.get_tree().create_timer(1.8).timeout
	Audio.override("title")   # SC1-25: the theme carries the verse
	await Game.fade(1.0, 1.4)
	tw.kill()
	for line in ["동경 밝은 달 아래\n기침 소리 잦아들고",
			"스러진 이들의 숨결을\n바람에 실어 보내노라"]:
		await Game.card("", line, 2.4)
	await Game.card("1절", "역병에 스러진 자들의 구절", 2.6)
	await Game.card("1장 「처용가」", "끝", 1.8)
	Game.set_flag("chapter1_done")
	Game.save()
	if Game.ch2_enabled():
		_enter_ch2()   # SC2-01 로 이어진다 (스위치가 꺼져 있으면 1장 그대로 타이틀)
	else:
		Game.to_title()


# ================================================================ 용패 길잡이 · 목표 (바이블 2-5, design/gdd/objective-marker.md)
## 목표 한 건 = {id, text, target, kind, follow, via, show}  (데이터는 design/gdd/objective-marker-table.md §3 과 1:1)
##  text   : UI 간결체 18자 이하. "" 이면 문구만 숨김(마커는 유지). show=="fallback" 이면 20초 무입력 때만 노출(SC1-01)
##  target : 마커가 향할 footprint 좌표(Vector2) 또는 null(마커 없음)
##  kind   : npc · interact · exit · node · area · none
##  follow : 움직이는 대상 추적 — "npc:<id>" / "node:<노드 이름>". 없거나 숨었으면 target 좌표로 폴백
##  via    : 직선이 막힐 때 먼저 향할 footprint 지점들
## 상태 없는 계산: Game.level_id + Game.flags 만 본다(세이브·디버그 진입이 따로 손대지 않아도 맞는다). 위에서 아래로 처음 맞는 행.
const OBJ_MAX_CHARS := 18


func _obj(id: String, text := "", target = null, kind := "none", follow := "", via := [], show := "normal") -> Dictionary:
	return {"id": id, "text": text, "target": target, "kind": kind, "follow": follow, "via": via, "show": show}


func objective_info(level: Node) -> Dictionary:
	var f := func(k): return Game.flag(k)
	match Game.level_id:
		"beach":
			if not f.call("flute"):
				return _obj("ch1.beach.flute", "반짝이는 것을 줍는다", Vector2(205, 427), "interact", "", [], "fallback")   # 바이블 SC1-01 무음: 폴백 때만
			if not f.call("beach_done") and level.get_node_or_null("Gaetgwi"):
				return _obj("ch1.beach.yokai", "요괴를 정화한다", level.def["anchors"]["yokai"], "node", "node:Gaetgwi")
			return _obj("ch1.beach.scene")
		"gyeongju":
			if f.call("chapter1_done"):
				return _obj("ch1.gyeongju.done")   # 예외 E-5
			if f.call("appointed"):
				return _obj("ch1.gyeongju.farewell")
			if f.call("rumor"):
				if f.call("king_call"):
					return _obj("ch1.gyeongju.royal_call")
				# SC1-21: 마을 사람에게 소문을 들으면 처용탈이 생긴다(선택 보상을 목표로 올림 — 디렉터 결정 2026-10-13)
				if not "cheoyong" in Game.tals:
					return _obj("ch1.gyeongju.rumor_hear", "마을 소문을 듣는다", Vector2(318, 213), "npc", "npc:villagerA")
				return _obj("ch1.gyeongju.rumor_rest", "집에서 쉰다", Vector2(130, 237), "interact")   # 집 interact "home" (옛 (96,130) 결함 D-1 수정)
			if not f.call("met_nanyeong"):
				return _obj("ch1.gyeongju.apothecary", "약방에서 약재를 구한다", Vector2(220, 314), "npc", "npc:nanyeong")
			if not f.call("sang_child"):
				return _obj("ch1.gyeongju.child", "금줄 친 집 아이를 살핀다", Vector2(240, 376), "npc", "npc:child")
			if not f.call("night"):
				return _obj("ch1.gyeongju.rest", "집에서 쉰다", Vector2(130, 237), "interact")
			if f.call("briefed") and not f.call("rescued"):
				return _obj("ch1.gyeongju.pyega_road", "서쪽 폐가로 간다", Vector2(4, 379), "exit")
			if f.call("summoned") and not f.call("briefed"):
				return _obj("ch1.gyeongju.summoned", "관아로 간다", Vector2(562, 28), "exit")
			return _obj("ch1.gyeongju.scene")   # 밤 연출(SC1-11 도입·SC1-20 난영 깨어남) 중
		"gwana":
			if not f.call("briefed"):
				return _obj("ch1.gwana.officer", "형방 박문을 만난다", Vector2(395, 140), "npc", "npc:gwanri")
			return _obj("ch1.gwana.leave", "관아를 나서 폐가로 간다", Vector2(100, 410), "exit")
		"pyega1":
			return _obj("ch1.pyega1.attic", "다락으로 올라간다", Vector2(146, 197), "exit")
		"pyega2":
			var b = level.get_node_or_null("Boss")
			if b and b.state == "wait":
				if b.home_pos == Vector2.ZERO:   # 아직 깨어나기 전(사람 모습으로 앉아 있다)
					return _obj("ch1.pyega2.deep", "폐가 안쪽으로 나아간다", level.def["anchors"]["boss_goal"], "area")
				return _obj("ch1.pyega2.after_death", "역신 앞으로 다시 나선다", level.def["anchors"]["boss_goal"], "node", "node:Boss")
			return _obj("ch1.pyega2.fight")   # 보스전·무릎 꿇음: 체력바·노래 점등이 말한다(E-3)
		"palace":
			return _obj("ch1.palace.audience", "편전 앞으로 나아간다", Vector2(256, 228), "area")
	# ---- 2장: 문구는 후속(P7). 마커 좌표는 이전 동작 그대로 ----
	var t = _objective_ch2(level)
	return _obj("ch2." + Game.level_id, "", t, "none" if t == null else "area")


## where the 용패 faintly pulls (footprint coords), or null when there's nothing to follow — objective_info 의 래퍼
func objective(level: Node):
	var t = objective_info(level).get("target")
	return t if t is Vector2 else null


func _objective_ch2(level: Node):
	var f := func(k): return Game.flag(k)
	match Game.level_id:
		"hwagae":
			if f.call("boss2_done"): return null if f.call("chapter2_done") else Vector2(470, 325)   # M4: 도깨비 장수
			if not f.call("raided"): return Vector2(345, 250) if f.call("ch2_start") else null
			if not f.call("ch2_old_man"): return Vector2(385, 173)
			return level.def["anchors"]["exit"]
		"jiri_path":
			return Vector2(1100, 100)   # 동쪽 소굴 (M2). 북쪽 마을은 산신령이 일러 준 선택 구간
		"old_village":
			if not f.call("girl_heard"): return Vector2(748, 160)
			if f.call("q_b") < 2: return level.def["anchors"]["doll"]
			if f.call("q_b") < 3: return level.def["anchors"]["grave"]
			return level.def["anchors"]["exit"]
		"den1":
			return level.def["anchors"]["exit"]
		"den2":
			return level.def["anchors"]["exit"] if f.call("den2_gate_cleared") else Vector2(320, 200)
		"den3":
			if f.call("boss2_done"): return level.def["anchors"]["exit"]
			return Vector2(90, 200) if not f.call("boss2_intro_seen") else level.def["anchors"]["hall"]
	return null


# ================================================================ 2장 「도깨비골」 마일스톤 1 (design/levels/ch2-dokkaebigol.md §10)
## 1장 → 2장 연결. chapter1_done 는 그대로 서 있고, 2장 진행은 ch2_* 플래그로 따로 센다.
func _enter_ch2() -> void:
	# 이어하기(title.gd)는 Game.change_level 도중 _busy=true 인 채로 레벨 훅을 돌린다 → 그대로 부르면 change_level 이 조용히 무시된다.
	# 진행 중인 전환이 끝날 때까지 기다린 뒤 들어간다. (작별 경로는 이미 _busy=false 라 지연 없음)
	while Game._busy:
		await Game.get_tree().process_frame
	Game.checkpoint = "hwagae"
	Game.change_level("hwagae", "start", "2장 「도깨비골」", "지리산")


## SC2-01: 처음 들어오면 장사치가 하소연한다. 그 뒤 습격 트리거(SC2-02)를 연다.
func _hwagae_enter(level: Node) -> void:
	Game.set_flag("flute")
	Game.checkpoint = "hwagae"
	var elder: Npc = level.npc("elder")
	if Game.flag("boss2_done") and Game.ch2_enabled():
		_hwagae_morning(level)   # 챕터2 M4: 두억시니를 거둔 이튿날 아침 (SC2-11~14)
		return
	if Game.flag("ch2_old_man"):
		level._exit(level.def["gates"]["path"])
		elder.set_present(true)
		return
	if Game.flag("raided"):
		Game.set_flag("night")   # SC2-02 후 밤
		elder.set_present(true)
		return
	if not Game.flag("ch2_start"):
		Game.set_flag("ch2_start")
		Game.save()
		var p: Node2D = level.get_node("Player")
		p.locked = true
		await level.get_tree().create_timer(0.8).timeout
		await level.talk([{"name": "장사치", "text": "도깨비들이 장터를 털어 간다오! 방망이로 사람을 날려버린다오!"}])   # SC2-01
		p.locked = false
	level.add_trigger(level.def["anchors"]["raid"], "raid")


## SC2-02: 외눈박이 둘이 장터에 난입한다(연출 — 덤비지 않는다). 눈이 탁기로 검다. 밤으로 다시 불러온다.
func _raid(level: Node) -> void:
	var p: Node2D = level.get_node("Player")
	p.locked = true
	await level.get_tree().process_frame   # 트리거 콜백(물리 질의 중) 밖에서 노드를 만든다
	var raiders: Array = []
	for at in level.def["anchors"]["raiders"]:
		var e: Enemy = level.spawn_enemy("dokkaebi_oneeye", at)
		e.set_physics_process(false)   # 연출용: 공격·추적 없음
		e.remove_from_group("enemy")
		raiders.append(e)
	Audio.sfx("door", -6.0)
	await level.get_tree().create_timer(1.0).timeout
	await level.talk([{"name": "처용", "text": "…오염됐다."}])   # SC2-02
	for e in raiders:
		if is_instance_valid(e):
			var tw: Tween = e.create_tween()
			tw.tween_property(e.sprite, "modulate:a", 0.0, 0.6)
			tw.tween_callback(e.queue_free)
	await level.get_tree().create_timer(0.8).timeout
	Game.set_flag("raided")
	Game.set_flag("night")
	Game.save()
	Game.change_level("hwagae", "start")   # 밤 재로드: 노인이 나타난다


func _ch2_interact(level: Node, id: String) -> void:
	if Game.level_id == "old_village":
		await _village_interact(level, id)
		return
	match id:
		"sangin":
			await level.talk([{"name": "장사치", "text": "동쪽 산길로 갔을 게요. 조심하시오." if Game.flag("raided")
				else "도깨비들이 장터를 털어 간다오! 방망이로 사람을 날려버린다오!"}])
		"jumo":
			await level.talk([{"name": "주모", "text": "해 지면 문을 걸어 잠그시오. 요즘 밤엔 방망이 소리가 들려오."}])
		"victim":
			await level.talk([{"name": "털린 짐꾼", "text": "짐을 통째로 빼앗겼소. …눈이 시커멓더이다."}])
		"board":
			await level.talk([{"text": "방(榜): 도깨비 사태로 길손은 해 지기 전 저자에 들라. — 의뢰는 준비 중"}])
		"elder":
			if not Game.flag("ch2_old_man"):
				await level.talk([{"name": "노인", "text": "역병 때 사람들이 물건을 버리고 도망갔지. 그 물건들에 혼이 깃든 게야."}])   # SC2-03
				Game.set_flag("ch2_old_man")
				Game.save()
				level._exit(level.def["gates"]["path"])
				Game.say_toast("동쪽 산길이 열렸다.")
			else:
				await level.talk([{"name": "노인", "text": "산으로 가려거든 길목의 장승을 조심하게."}])
		"sansin":
			if Game.level_id == "hwagae":
				await _sansin_broker(level)
			else:
				await _shrine(level)
		"dok_jangsu":
			await _dok_shop(level)
		"shrine":
			await _shrine(level)
		_:
			await level.talk([{"text": "…"}])


func _jiri_enter(level: Node) -> void:   # 장승 트리거(SC2-15)는 레벨 정의가 매번 건다; _jangseung_first 가 한 번만 말한다
	Game.set_flag("flute")
	Game.checkpoint = "jiri_path"
	if Game.flag("dok_open") and Game.ch2_enabled():
		level.npc("sansin").set_present(false)   # SC2-12: 산신령은 저자로 이주했다 (산신각 상호작용 지점은 그대로)


## SC2-15: 길목 직후 장승 첫 접촉
func _jangseung_first(level: Node) -> void:
	if Game.flag("jangseung_seen"):
		return
	Game.set_flag("jangseung_seen")
	await level.talk([{"name": "처용", "text": "…한때는 마을을 지키던 것이다."}])


## SC2-16: 산신각 — 산신령 (D-B: 용왕은 죽지 않았다, '당부')
func _shrine(level: Node) -> void:
	if not Game.flag("shrine_seen"):
		Game.set_flag("shrine_seen")
		await level.talk([
			{"name": "산신령", "text": "아비는 바다에 있고 아들은 산을 걷는구려. 아비의 당부를 잊지 마오."},
			{"name": "처용", "text": "…잊지 않았소."},
			{"name": "산신령", "text": "저 아래 빈 마을에 우는 아이가 있소. 아무도 들어주질 않는구려."},
		])
		if Game.flag("q_b") == 0:
			Game.set_flag("q_b")   # 의뢰 B 수주 (북쪽 산길 끝 버려진 마을)
	else:
		await level.talk([{"name": "산신령", "text": "산이 깊소. 서두르지 마오."}])


# ================================================================ 2장 「도깨비골」 마일스톤 2 (design/levels/ch2-dokkaebigol.md §4.3~4.6, §9, §10)
## 1장 체크포인트·스폰 규칙: 레벨에 들어올 때마다 체크포인트를 그 레벨로 옮긴다 (den3 만 SC2-06 뒤에 옮긴다).
func _ch2_arrive(level_id: String) -> void:
	Game.set_flag("flute")
	Game.checkpoint = level_id


## 연출 공통: 플레이어를 묶고 잠깐 기다린 뒤 대사를 연다. 끝나면 풀린다 (level.talk 가 푼다).
func _beat(level: Node, lines: Array, wait := 0.8) -> void:
	var p: Node2D = level.get_node("Player")
	p.locked = true
	await level.get_tree().create_timer(wait).timeout
	await level.talk(lines)


## SC2-17: 버려진 마을 진입. 사연(SC2-18)·인형(SC2-19)·무덤(SC2-20)은 서쪽 절반(요괴 어그로 밖)에 있다.
func _village_enter(level: Node) -> void:
	_ch2_arrive("old_village")
	if Game.flag("q_b") >= 3:
		level.npc("girl_soul").set_present(false)
	elif Game.flag("girl_heard") and Game.flag("q_b") < 2:
		level.add_interact("doll", level.def["anchors"]["doll"], "짚인형", true)
	if not Game.flag("village_seen"):
		Game.set_flag("village_seen")
		Game.save()
		await _beat(level, [{"name": "처용", "text": "…서둘러 떠난 자리다."}])   # SC2-17


## 의뢰 B 「빈집의 아이」 (q_b: 0 미수주 · 1 수주 · 2 인형 회수 · 3 완료 / girl_heard: 사연을 들었다 / q_b_clean: 마을에서 아직 아무도 정화하지 않았다)
func _village_interact(level: Node, id: String) -> void:
	match id:
		"girl_soul":
			if Game.flag("q_b") >= 3:
				await level.talk([{"name": "빈집의 넋", "text": "…고마워요."}])
			elif not Game.flag("girl_heard"):
				Game.set_flag("girl_heard")
				Game.set_flag("q_b", maxi(Game.flag("q_b"), 1))
				if Game.flag("q_b_clean") == 0 and Game.flag("hanpuri_old_village") == 0:
					Game.set_flag("q_b_clean")   # 이 순간부터 마을 요괴를 정화하지 않고 끝내면 무전투 보너스
				await level.talk([
					{"name": "빈집의 넋", "text": "엄마가 짚인형을 두고 갔어요. 같이 가자고 했는데… 두고 갔어요."},   # SC2-18
					{"name": "처용", "text": "…찾아주마."},
				])
				level.add_interact("doll", level.def["anchors"]["doll"], "짚인형", true)
				Game.say_toast("의뢰 「빈집의 아이」 — 짚인형을 찾아 주자.")
				Game.save()
			elif Game.flag("q_b") < 2:
				await level.talk([{"name": "빈집의 넋", "text": "…인형이 있었는데. 서쪽 빈집 뒤꼍에…"}])
			else:
				await level.talk([{"name": "빈집의 넋", "text": "…인형을 안고 가고 싶어요. 어귀 무덤으로 와 줘요."}])
		"doll":
			level.remove_interact("doll")
			Audio.sfx("pickup", -4.0, 0.0)
			Game.set_flag("q_b", 2)
			await level.talk([{"name": "처용", "text": "…여기 있다."}])   # SC2-19
			Game.say_toast("짚인형을 얻었다.")
			Game.save()
		"grave":
			if Game.flag("q_b") < 2:
				await level.talk([{"text": "이름 없는 무덤이다. 풀이 말랐다."}])
			elif Game.flag("q_b") < 3:
				await _grave_rite(level)
			else:
				await level.talk([{"text": "…풀이 다시 푸르다."}])


## SC2-20: 무덤에서 굿 — 처용은 말 없이 노래로. 아이 넋이 승천하고 한풀이 보상(전투 없이 끝내면 +30%).
func _grave_rite(level: Node) -> void:
	if level.has_meta("rite_busy"):   # 노래하는 동안 플레이어는 풀려 있다 → 같은 굿이 겹쳐 시작되지 않게
		return
	level.set_meta("rite_busy", true)
	var p: Node2D = level.get_node("Player")
	p.locked = true
	await level.get_tree().create_timer(0.4).timeout
	p.locked = false
	p.sing()
	await level.get_tree().create_timer(1.8).timeout
	p.locked = true
	var girl: Npc = level.npc("girl_soul")
	girl.talkable = false
	var tw: Tween = girl.create_tween().set_parallel()
	tw.tween_property(girl.sprite, "modulate:a", 0.0, 1.4)
	tw.tween_property(girl.sprite, "position:y", girl.sprite.position.y - 18.0, 1.4)
	await tw.finished
	await level.talk([{"name": "빈집의 넋", "text": "…고마워요."}])   # SC2-20
	girl.set_present(false)
	var mult := 1.3 if Game.flag("q_b_clean") == 1 else 1.0
	Game.reward_bonus(int(80 * mult), int(120 * mult), p.global_position, level)
	Game.set_flag("q_b", 3)
	Game.say_toast("의뢰 완료 — 빈집의 아이" + (" (전투 없이: +30%)" if mult > 1.0 else ""), Color(0.75, 0.9, 1.0))
	Game.save()


## 소굴 외곽: SC2-04(소굴 어귀에서 졸개의 목소리) · SC2-05(첫 외눈박이 감투 → 용패)
func _den1_enter(_level: Node) -> void:
	_ch2_arrive("den1")


func _den1_sight(level: Node) -> void:
	if Game.flag("den_sight"):
		return
	Game.set_flag("den_sight")
	await level.get_tree().process_frame
	await level.talk([{"name": "도깨비 졸개", "text": "크르릉…! 물러가라…!"}])   # SC2-04


func _den1_deep(level: Node) -> void:
	if Game.flag("den_deep"):
		return
	Game.set_flag("den_deep")
	await level.get_tree().process_frame
	await level.talk([{"name": "처용", "text": "…울고 있다."}])


## SC2-05: 외눈박이가 감투로 사라질 때(enemy.gd) — 첫 번째는 시스템 문구, 처음 3번은 도착점에 용패 잔영(반짝임)
func oneeye_vanish(level: Node, at: Vector2) -> void:
	if Game.level_id != "den1":   # SC2-05 는 소굴 외곽의 학습 구간 몫 — 마을 외눈박이가 잔영·문구를 먼저 써 버리지 않게
		return
	var n := Game.flag("yongpae_trace_n")
	if n >= 3 or not level.has_method("_glint"):
		return
	Game.set_flag("yongpae_trace_n", n + 1)
	if n == 0:
		Game.say_toast("용패가 탁기의 흐름을 비춘다.", Color(0.75, 0.9, 1.0))   # SC2-05
	var mark: Node2D = level._glint(at)   # _glint 가 레벨에 붙여 준다
	await level.get_tree().create_timer(1.6).timeout
	if is_instance_valid(mark):
		mark.queue_free()


## 도깨비 곳간: SC2-21 입장. 동쪽 문은 정예 장산범 정화 전까지 막혀 있다(den2_gate_cleared).
func _den2_enter(level: Node) -> void:
	_ch2_arrive("den2")
	if not Game.flag("den2_gate_cleared"):
		level.set_meta("door", level.add_barrier(level.def["anchors"]["door"]))
	if not Game.flag("den2_seen"):
		Game.set_flag("den2_seen")
		Game.save()
		await _beat(level, [
			{"name": "처용", "text": "…누가 부르는 것 같다."},   # SC2-21
			{"name": "장산범", "text": "…거기 누구 있소?"},
		])


## 정화 훅 (level.on_purified 에서): 장산범 정화 → 곳간 동문 · 마을에서 정화하면 의뢰 B 의 무전투 보너스 소멸
func purified(level: Node, kind: String) -> void:
	if Game.level_id == "den2" and kind == "jangsanbeom" and not Game.flag("den2_gate_cleared"):
		Game.set_flag("den2_gate_cleared")
		var door = level.get_meta("door", null)
		if is_instance_valid(door):
			door.queue_free()
		Game.say_toast("곳간 동쪽 문이 열렸다.")
		Game.save()
	elif Game.level_id == "old_village" and Game.flag("q_b") in [1, 2] and Game.flag("q_b_clean") == 1:
		Game.set_flag("q_b_clean", 0)


## 두억시니의 방: 입장하면 입구 복도가 닫히고(전투가 끝날 때까지) 두억시니가 모습을 드러낸다.
## SC2-06·07 연출(첫 입장, 체크포인트 den3) 뒤 전투. 재도전(boss2_intro_seen)이면 연출을 건너뛰고 1초 뒤 전투. 격파(boss2_done) 뒤에는 방이 비어 있다.
func _den3_enter(_level: Node) -> void:
	Game.set_flag("flute")
	if not Game.flag("boss2_intro_seen"):
		Game.checkpoint = "den2"   # 연출 전까지는 곳간이 체크포인트 (SC2-06 에서 den3 로 옮긴다)


func _den3_gate(level: Node) -> void:
	if Game.flag("boss2_done") or not Game.ch2_enabled():
		return   # 이미 거둔 방(또는 2장 스위치가 꺼진 빌드): 보스도 봉쇄문도 없다
	var p: Node2D = level.get_node("Player")
	p.locked = true
	await level.get_tree().process_frame
	var door: Node = level.add_barrier(level.def["anchors"]["door"])   # 입구 복도가 닫힌다 (격파 때까지)
	level.set_meta("den3_door", door)
	Audio.sfx("door", -6.0)
	var boss := Dueoksini.new()
	boss.name = "Boss"
	boss.position = level.lift(level.def["anchors"]["boss"])
	level.add_child(boss)
	boss.appear()
	if not Game.flag("boss2_intro_seen"):
		Game.checkpoint = "den3"
		Game.set_flag("boss2_intro_seen")
		Game.save()
		await level.get_tree().create_timer(0.8).timeout
		await level.talk([
			{"name": "두억시니", "text": "인간! 인간이 버렸으면서, 왜 도로 뺏으려 드느냐!"},   # SC2-06
			{"name": "두억시니", "text": "우리는 버려졌다! 버려진 것들의 설움을 네가 아느냐!"},   # SC2-07
			{"name": "처용", "text": "…안다."},
		])
	else:
		await level.get_tree().create_timer(1.0).timeout   # 재도전: 연출 생략, 곧 전투
		p.locked = false
	_den3_fight(level, boss)


## SC2-08: 전투 개시. 쓰러지면 입구 안쪽에서 다시 일어서고(레벨 재로드 없음) 두억시니 HP·페이즈·졸개가 초기화된다 (1장 CS-12 와 같은 규칙).
func _den3_fight(level: Node, boss: Dueoksini) -> void:
	var p: Node2D = level.get_node("Player")
	boss.awaken()
	level.hud.show_boss(boss, "두억시니")
	Game.death_zone = "den3_boss"   # CS-07: 두억시니전 사망은 den3_boss 키로 따로 센다
	p.spawn = level.lift(level.def["anchors"]["boss_respawn"])
	boss.home_pos = boss.position
	p.died.connect(_boss_player_died.bind(level, boss))
	boss.phase_two.connect(_boss2_phase_two.bind(level, boss))
	boss.knelt.connect(_boss2_knelt.bind(level), CONNECT_ONE_SHOT)
	boss.defeated.connect(_boss2_defeated.bind(level), CONNECT_ONE_SHOT)


## SC2-22
func _boss2_phase_two(level: Node, boss: Dueoksini) -> void:
	boss.state = "wait"
	await level.talk([{"name": "두억시니", "text": "…비가… 또… 내린다…"}])
	if boss.state == "wait":   # 한 방에 2페이즈와 무릎 꿇음을 넘었다면 쓰러진 보스는 그대로 둔다
		boss.phase_shift()   # 열림 1.2초(×1.5) · 소리 +30 · 검은 비 시작


## 무릎 꿇음: 노래로 거두라는 길잡이 (SC2-09 의 대사는 정화 순간)
func _boss2_knelt(level: Node) -> void:
	await level.get_tree().create_timer(0.8).timeout
	level.hud.guide("song")


## SC2-09·10: 낡은 절구로 돌아가며 한 마디, 처용의 독백, 이튿날 아침 화개 저자로 (SC2-11 이후는 다음 마일스톤)
func _boss2_defeated(level: Node) -> void:
	level.hud.guide("")
	var pl: Node = level.get_node("Player")
	for c in pl.died.get_connections():
		pl.died.disconnect(c["callable"])
	Game.set_flag("boss2_done")
	Game.death_zone = ""
	var p: Node2D = level.get_node("Player")
	p.locked = true
	await level.get_tree().create_timer(2.0).timeout
	await level.talk([
		{"name": "두억시니", "text": "…고맙다. 검은 비가 내리던 날부터, 정신이 아니었다."},   # SC2-09
		{"name": "처용", "text": "검은 비… 1장의 역병과 같은 냄새."},   # SC2-10
	])
	var door = level.get_meta("den3_door", null)
	if is_instance_valid(door):
		door.queue_free()
	Game.flags.erase("night")   # hwagae 가 아침 빛으로 다시 열린다 (level.gd _atmosphere: boss2_done)
	Game.checkpoint = "hwagae"
	Game.save()
	Game.change_level("hwagae", "fromBoss", "이튿날 아침", "")


# ================================================================ 2장 「도깨비골」 마일스톤 4 (design/levels/ch2-dokkaebigol.md §10 SC2-11~14, §8 장비)
const DOK_TINT := Color(0.62, 0.86, 1.0)   # 도깨비 장수: 사람 시트에 푸른 도깨비 빛깔을 입힌 임시 모습 (production/qa/ch2-m4-asset-needs.md)
const VERSE2_HOLD := 2.4


## 이튿날 아침의 화개 저자. 진행은 플래그로 이어진다: obang_given(SC2-11) → dok_open(SC2-12) → verse2(SC2-13) → chapter2_done(SC2-14).
## 이어하기로 중간에 들어와도 빠진 단계부터 다시 시작한다. 마친 뒤에는 자유 이동이고 도깨비 상점이 열려 있다.
func _hwagae_morning(level: Node) -> void:
	Game.flags.erase("night")
	level._exit(level.def["gates"]["path"])
	level.npc("elder").set_present(true)
	var jang: Npc = level.npc("dok_jangsu")
	jang.sprite.modulate = DOK_TINT
	jang.set_present(true)
	if Game.flag("dok_open"):
		level.npc("sansin").set_present(true)
	if Game.flag("chapter2_done"):
		return
	var p: Node2D = level.get_node("Player")
	p.locked = true
	await level.get_tree().create_timer(0.8).timeout
	if not is_instance_valid(level):
		return
	if not Game.flag("obang_given"):
		await level.talk([
			{"name": "도깨비 장수", "text": "…노래하는 이여. 간밤에 두억시니가 울음을 그쳤다네."},
			{"name": "도깨비 장수", "text": "은혜는 갚는다. 우리 장터에서 물건을 팔게 해주게."},   # SC2-11
			{"name": "도깨비 장수", "text": "이건 답례일세. 오방의 빛깔을 새긴 탈이지."},
		])
		Game.give_tal("obang")   # 오방탈: 정화 속도 +20% (바로 쓴다 — 지닌 것 에서 처용탈과 바꿀 수 있다)
		Game.set_flag("obang_given")
		Game.save()
	if not Game.flag("dok_open"):
		Game.set_flag("dok_open")
		Game.say_toast("도깨비 상점이 열렸다.", Color(0.6, 0.9, 1.0))   # SC2-12
		var sansin: Npc = level.npc("sansin")
		sansin.set_present(true)
		Game.say_toast("산신령이 저자로 내려와 정보를 판다.", Color(0.94, 0.85, 0.55))
		Game.save()
		await level.get_tree().create_timer(1.2).timeout
		if not is_instance_valid(level):
			return
	if not Game.flag("verse2"):
		await _verse2()   # SC2-13
		if not is_instance_valid(level):
			return
		Game.set_flag("verse2")
		Game.save()
	await level.talk([{"name": "도깨비들", "text": "노래하는 자여, 잘 가게!"}])   # SC2-14
	if not is_instance_valid(level):
		return
	await Game.fade(1.0, 1.0)
	if not is_instance_valid(level):
		return
	await Game.card("2장 「도깨비골」", "끝", 1.8)
	if not is_instance_valid(level):
		return
	Game.set_flag("chapter2_done")
	Game.save()
	await Game.fade(0.0, 0.8)
	if not is_instance_valid(level):
		return
	Game.say_toast("3장은 준비 중입니다")
	if is_instance_valid(p):
		p.locked = false


## SC2-13: 2절 가사와 자막 (설계서 §10)
func _verse2() -> void:
	Audio.override("title")   # 1절과 같은 선율이 이어진다 (SC1-25)
	await Game.fade(1.0, 1.4)
	for line in ["산그늘 깊은 골짝에\n버려진 것들의 울음",
			"쓰이다 잊힌 손길마다\n노래로 돌려보내노라"]:
		await Game.card("", line, VERSE2_HOLD)
	await Game.card("2절", "버려진 것들의 구절", 2.6)
	Audio.override("")
	await Game.fade(0.0, 1.0)


## SC2-12 이후 산신령 — 화개 저자의 정보상 (정보 내용은 3장 이후 채운다: 지금은 안내 한마디)
func _sansin_broker(level: Node) -> void:
	await level.talk([{"name": "산신령", "text": "산이 시끄러워 저자로 내려왔소. 길손이 오가는 소문은 내가 먼저 듣지."},
		{"name": "산신령", "text": "서쪽 길은 아직 닫혀 있소. 때가 되면 일러 주리다."}])


## 도깨비 상점 (SC2-12 이후). 약방(_shop)과 같은 틀, 상품은 Game.DOK_SHOP.
func _dok_shop(level: Node) -> void:
	if not Game.flag("dok_open"):
		await level.talk([{"name": "도깨비 장수", "text": "…"}])
		return
	await level.talk([{"name": "도깨비 장수", "text": "에누리는 없고, 덤은 있지. 무엇을 드릴까?"}])
	var p: Node2D = level.get_node("Player")
	p.locked = true
	while true:
		var opts := []
		for it in Game.DOK_SHOP:
			opts.append("%s  %d푼" % [it["name"], it["price"]] if it["price"] > 0 else "%s  (준비 중)" % it["name"])
		opts.append("그만두겠소")
		var i: int = await level.dialog.choose({"name": "도깨비 장수", "text": "엽전 %d푼이 있구려." % Game.money}, opts)
		if i >= Game.DOK_SHOP.size():
			break
		var it: Dictionary = Game.DOK_SHOP[i]
		if it["price"] <= 0:
			await level.talk([{"name": "도깨비 장수", "text": "그건 아직 다듬는 중이라네. 피리가 영글면 다시 오게."}])
		elif Game.money < it["price"]:
			await level.talk([{"name": "도깨비 장수", "text": "값이 모자라네."}])
		else:
			Game.money -= it["price"]
			Game.items[it["id"]] = int(Game.items.get(it["id"], 0)) + 1
			Game.say_toast("%s — %s" % [it["name"], it["desc"]])
		p.locked = true
	p.locked = false
