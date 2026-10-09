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
	match Game.level_id:
		"beach":
			if "--beach-fight" in OS.get_cmdline_user_args():  # test hook: straight to SC1-05
				_test_fight(level)
			elif not Game.flag("beach_done"):
				_beach_wake(level)
		"gyeongju":
			Game.set_flag("flute")   # 백사장을 지나왔다면 이미 가지고 있다 (테스트 진입 대비)
			Game.set_flag("arrived")
			_gyeongju_enter(level)


func interact(level: Node, id: String) -> void:
	match id:
		"flute": _pick_flute(level)
		"nanyeong": _talk_nanyeong(level)
		"apothecary": _shop(level)
		"home": _rest(level)
		"child":
			await level.talk([{"name": "아이", "text": "형, 어젯밤에 이상한 노래가 들렸어!"}] if Game.flag("night")
				else [{"name": "아이", "text": "…몸이 따뜻해졌어. 바닷소리가 났어."}])
		"villagerC":
			await level.talk([{"name": "기침하는 사내", "text": "콜록, 콜록… 관아 쪽으로 사람들이 몰려가오…"}] if Game.flag("night")
				else TALK["villagerC"])
		_:
			await level.talk(TALK.get(id, [{"text": "…"}]))


func trigger(level: Node, id: String) -> void:
	if id == "fight":
		_fight(level)


# ================================================================ 1장 1-1 백사장 (SC1-01~04)
## SC1-01: 파도 소리. 처용이 모래 위에서 눈을 뜬다 — 무음, 글 없음
func _beach_wake(level: Node) -> void:
	var p: Node2D = level.get_node("Player")
	p.locked = true
	p.state = "lie"   # no state branch runs: he stays as posed
	level.hud.visible = false
	p.sprite.rotation = -PI / 2
	p.sprite.modulate = Color(0.75, 0.8, 0.95)
	await level.get_tree().create_timer(2.2).timeout
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
	Game.set_flag("flute")
	Game.say_toast("대나무 피리를 주웠다.")
	await level.get_tree().create_timer(1.6).timeout
	# the creature comes up into the village; the fishers scatter
	var yokai: Enemy = level.spawn_enemy("sea", Vector2(334, 90))
	yokai.name = "Gaetgwi"
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
	level.add_trigger(Rect2(180, 60, 300, 90), "fight")


func _test_fight(level: Node) -> void:
	Game.set_flag("flute")
	level.remove_interact("flute")
	level.spawn_enemy("sea", Vector2(334, 90)).name = "Gaetgwi"
	for id in ["fisherA", "fisherB", "fisherC"]:
		level.npc(id).set_present(true)
		level.npc(id).talkable = false
	level.get_node("Player").position = level.lift(Vector2(334, 150))
	await level.get_tree().process_frame
	_fight(level)


# ================================================================ 1장 1-2 첫 전투와 천거 (SC1-05~07)
## SC1-05: 튜토리얼 전투 — 베기 → 구르기 → 정화. 글 없이, 해야 할 버튼 하나만 빛난다.
func _fight(level: Node) -> void:
	var yokai: Enemy = level.get_node_or_null("Gaetgwi")
	if yokai == null:
		return
	var p: Node2D = level.get_node("Player")
	p.gentle_hits = 3          # 벌 없이 배운다
	yokai.cd = 3.5             # 먼저 베기를 배울 틈을 준다
	level.hud.guide("attack")
	yokai.hit_taken.connect(func():
		if level.hud._guide == "attack":
			level.hud.guide(""), CONNECT_ONE_SHOT)
	yokai.telegraph.connect(func(): _teach_roll(level), CONNECT_ONE_SHOT)
	yokai.collapsed.connect(func(): level.hud.guide("song"))
	yokai.purified.connect(func(): _after_fight(level))


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
	if Game.flag("met_nanyeong") and not Game.flag("sang_child"):
		_show_sick_child(level)
	elif Game.flag("sang_child"):
		level.npc("child").set_present(true)
	if Game.flag("night"):
		for id in DAY_PEOPLE:
			level.npc(id).set_present(false)   # 밤: 다들 문을 걸어 잠갔다
		if not Game.flag("summoned"):
			_night_summons(level)
		else:
			_open_road_to_gwana(level)


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
	if Game.flag("sang_child") and not Game.flag("night"):
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
	await off.walk_to(level.lift(Vector2(630, 186)), 70.0)
	off.set_present(false)
	p.locked = false
	_open_road_to_gwana(level)


func _open_road_to_gwana(level: Node) -> void:
	if Levels.DATA.has("gwana"):
		level._exit([Rect2(632, 150, 8, 70), "gwana", "start"])
