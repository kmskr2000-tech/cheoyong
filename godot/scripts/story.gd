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


func interact(level: Node, id: String) -> void:
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
		if not Game.flag("nanyeong_fallen") or Game.flag("rescued"):
			var nan: Npc = level.npc("nanyeong")   # 이제 처용의 아내: 집 앞에 있다
			nan.set_present(true)
			nan.position = level.lift(Vector2(196, 166))
		if Game.flag("rescued") and not Game.flag("nanyeong_woke"):
			_nanyeong_wakes(level)
		elif not Game.flag("summoned"):
			_night_summons(level)
		else:
			_open_road_to_gwana(level)
		if Game.flag("briefed") and not Game.flag("rescued"):
			level._exit([Rect2(0, 150, 6, 70), "pyega1", "start"])


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
	await off.walk_to(level.lift(Vector2(630, 186)), 70.0)
	off.set_present(false)
	p.locked = false
	_open_road_to_gwana(level)


func _open_road_to_gwana(level: Node) -> void:
	if Levels.DATA.has("gwana"):
		level._exit([Rect2(632, 150, 8, 70), "gwana", "start"])


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
	])
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
	boss.position = level.lift(Vector2(650, 150))
	level.add_child(boss)
	boss.disguise()


## SC1-15~17: 최심부. 사람 모습의 역신이 난영의 넋 곁에 앉아 있다.
func _inner_room(level: Node) -> void:
	var boss: PlagueGod = level.get_node_or_null("Boss")
	if boss == null:
		return
	var p: Node2D = level.get_node("Player")
	p.locked = true
	level.add_barrier(Rect2(492, 156, 22, 72))
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
	# falling here means trying the room again from the stair (the door is sealed behind him)
	p.died.connect(func(): Game.change_level("pyega2", "start"), CONNECT_ONE_SHOT)
	if "--boss-kneel" in OS.get_cmdline_user_args():  # test hook: skip straight to SC1-19
		await level.get_tree().create_timer(1.0).timeout
		boss.take_hit(9999, Vector2.ZERO)
	boss.phase_two.connect(_boss_phase_two.bind(level, boss), CONNECT_ONE_SHOT)
	boss.knelt.connect(_boss_knelt.bind(level), CONNECT_ONE_SHOT)
	boss.defeated.connect(_boss_defeated.bind(level), CONNECT_ONE_SHOT)


## SC1-18
func _boss_phase_two(level: Node, boss: PlagueGod) -> void:
	boss.state = "wait"
	await level.talk([{"name": "역신", "text": "이럴 수가…! 노래가… 탁기를 걷어내다니!"}])
	boss._begin("idle")


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
	nan.talkable = true
	Game.set_flag("nanyeong_woke")
	p.locked = false
