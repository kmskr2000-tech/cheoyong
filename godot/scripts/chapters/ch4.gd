# 4장 동해 감은사 — 헌화가. A sea dragon has carried off Lady Suro from the cliffs; an old cowherd once climbed
# those cliffs to pick her an azalea. The villagers' old chant ("거북아 거북아") brings the dragon to shore.
extends Chapter

func _init(game) -> void:
	super(game)
	n = 4; map = "donghae"; title = "제4장 · 동해 감은사 — 헌화가"

func npcs() -> Array:
	return [
		["sunjeong", "hwarang", 38, 62.5, "순정공", "south", null],
		["suro", "suro", 40, 62.5, "수로부인", "south", func(f): return f.get("c4_boss", false)],
		["noin", "noin", 66, 27, "소 끄는 노인", "south", null],
		["monk4", "monk", 33, 66, "감은사 스님", "east", null],
		["fisher", "villager", 72, 64, "어부 아낙", "west", null],
		["haenyeo", "villager", 64, 72, "해녀", "east", null],
		["boy", "child", 46, 70, "목동", "west", null],
		["oldfisher", "sick", 80, 70, "늙은 어부", "west", null],
		["peddler", "merchant", 47, 75.4, "봇짐장수", "south", null],
		["guard4", "hwarang", 50, 46, "순정공의 종자", "south", null],
	]

func spawns() -> Dictionary:
	return {
		"cliff": {"lvl": 20, "list": [["jangsanbeom", 56, 30], ["dokkaebi", 62, 18], ["hwagwi", 74, 14], ["dokkaebi", 80, 24], ["imp", 52, 38], ["hwagwi", 70, 36], ["jangsanbeom", 82, 38], ["dokkaebi", 58, 12]]},
		"coast": {"lvl": 21, "list": [["mulgwisin", 66, 56], ["snake", 72, 74], ["mulgwisin", 80, 58], ["ghost", 86, 78], ["mulgwisin", 74, 82], ["snake", 62, 80], ["ghost", 84, 54], ["mulgwisin", 70, 62]],
			"elite": ["mulgwisin", 88, 80, "검은 물귀신"]},
	}

func bosses() -> Dictionary:
	return {
		"daewangam": {"type": "haeryong", "flag": "c4_boss", "at": [98, 66], "trigger": [91, 66], "lvl": 14,
			"need": [["ch4_dragon", true]],
			"lines": [["해룡", "누가 감히 바다를 불러내느냐! 그 노래… 거북아, 거북아…"], ["해룡", "수로는 내 궁에서 칠보 잔치를 즐기고 있다. 돌려줄 까닭이 없다!"], ["처용", "용궁의 법도는 그렇지 않소. 나는 용왕의 아들이오."]]},
	}

func villagers() -> int:
	var c := 0
	for k in ["c4_v1", "c4_v2", "c4_v3"]:
		if fl(k): c += 1
	return c

func steps() -> Array:
	return [
		{"text": "감은사 터의 순정공을 만나시오", "talk": "sunjeong", "done": func(): return fl("c4_met")},
		{"text": "임해 절벽길의 요괴 정화", "hunt": "cliff", "count": ["kills_cliff", 12], "pos": [64, 26], "done": func(): return num("kills_cliff") >= 12 or fl("c4_noin")},
		{"text": "절벽 위의 소 끄는 노인", "talk": "noin", "done": func(): return fl("c4_noin")},
		{"text": "함께 노래할 사람들 — 어부 아낙", "talk": "fisher", "done": func(): return fl("c4_v1")},
		{"text": "함께 노래할 사람들 — 해녀", "talk": "haenyeo", "done": func(): return fl("c4_v2")},
		{"text": "함께 노래할 사람들 — 늙은 어부", "talk": "oldfisher", "done": func(): return fl("c4_v3")},
		{"text": "대왕암 바닷가의 물귀신 정화", "hunt": "coast", "count": ["kills_coast", 12], "pos": [74, 66], "done": func(): return num("kills_coast") >= 12 or fl("ch4_dragon")},
		{"text": "대왕암 앞에서 다 함께 노래하시오", "pos": [87, 66], "done": func(): return fl("ch4_dragon")},
		{"text": "대왕암의 해룡", "pos": [91, 66], "done": func(): return fl("c4_boss")},
		{"text": "감은사로 돌아가 순정공을 만나시오", "talk": "sunjeong", "done": func(): return fl("c4_done")},
	]

func sides() -> Array:
	return [
		{"id": "c4_pearl", "giver": "boy", "name": "흩어진 진주", "kind": "collect", "zone": "coast", "item": "pearl", "item_name": "진주", "count": 5, "chance": 0.4,
			"offer": [["목동", "할아버지가 수로부인께 드리려던 진주 목걸이가 끊어졌어요. 물귀신들이 주워 갔대요."], ["목동", "다섯 알만 찾아 주세요!"]],
			"remind": "진주 다섯 알이요!", "thanks": [["목동", "와! 할아버지가 좋아하시겠다. 이건 우리 집 복부적… 아니, 금강부적이래요!"]],
			"reward": {"talis": "geum", "coins": 200, "exp": 600}},
		{"id": "c4_black", "giver": "haenyeo", "name": "검은 물귀신", "kind": "elite", "type": "mulgwisin", "count": 1,
			"offer": [["해녀", "바닷가 남쪽 바위에 검은 물귀신이 숨어 해녀들을 끌어당기오."], ["해녀", "놈만 없으면 다시 물질을 하겠소."]],
			"remind": "바닷가 남동쪽 바위요.", "thanks": [["해녀", "이제 마음 놓고 물에 들겠소. 받으시오, 해녀들이 지니는 수부적이오."]],
			"reward": {"talis": "su", "coins": 260, "exp": 700}},
		{"id": "c4_road", "giver": "guard4", "name": "절벽길 청소", "kind": "kill", "zone": "cliff", "count": 14,
			"offer": [["순정공의 종자", "부인을 모시던 행렬이 절벽길에 짐을 두고 왔소. 요괴를 열넷만 정화해 길을 열어 주시오."]],
			"remind": "절벽길 요괴 열넷이오.", "thanks": [["순정공의 종자", "짐을 찾았소. 사례로 엽전과 약과를 드리리다."]],
			"reward": {"coins": 400, "exp": 800, "items": {"yakgwa": 3}}},
	]

func interact(npc) -> bool:
	match npc.id:
		"sunjeong":
			if not fl("c4_met"):
				say([
					["순정공", "그대가 처용이오? 부디 내 아내를 찾아 주시오."],
					["순정공", "강릉으로 가던 길, 바닷가 정자에서 점심을 먹는데 바다에서 용이 솟아 부인을 채어 갔소."],
					["순정공", "그 전날엔 절벽 위 철쭉을 갖고 싶다는 부인께 웬 노인이 소를 놓고 올라가 꽃을 꺾어 바쳤지."],
					["순정공", "그 노인이라면 무언가 알지 모르오. 북쪽 절벽길에 있소."],
					["@", "임해 절벽길로 가는 길이 열렸다.", func(): Sfx.sfx("quest")],
				], func(): setf("c4_met"); setf("ch4_cliff"); g.save_game())
			elif fl("c4_boss") and not fl("c4_done"):
				say([
					["순정공", "부인을 데려와 주셨구려! 이 은혜를 어찌 갚겠소."],
					["수로부인", "용궁은 화려했지만… 이 바닷바람이 더 좋소."],
					["순정공", "우리 집안에 내려오는 사자탈이오. 무섭게 생겼지만 그대처럼 든든하오."],
					["@", "사자탈을 얻었다. (공격 +55%, 기 회복 절반)", func(): g.add_mask("saja")],
					["감은사 스님", "처용 공, 서라벌 동쪽 분황사에 역병이 돈다 하오. 꼭두각시가 밤마다 거리를 돈다고."],
				], func(): setf("c4_done"); setf("map_hwangnyong"); g.ui.toast("이동할 수 있는 곳: 황룡사"); g.save_game())
			elif fl("c4_done"): say([["순정공", "그대의 이름은 감은사 탑에 새겨 두겠소."]])
			else: say([["순정공", "부인… 무사해야 할 텐데."]])
		"suro": say([["수로부인", "꽃을 바치던 노인의 노래가 아직 귓가에 맴도오."]])
		"noin":
			if not fl("c4_noin"):
				if num("kills_cliff") < 12: say([["소 끄는 노인", "허허, 절벽길이 험하오. 요괴부터 걷어 내고 오시게. (%d/12)" % num("kills_cliff")]])
				else:
					say([
						["소 끄는 노인", "부인을 채어 간 건 동해의 해룡이오. 용왕의 핏줄이면서 탐욕에 눈이 멀었지."],
						["소 끄는 노인", "옛말에 '뭇 입은 쇠도 녹인다' 했소. 바닷가 사람들이 다 함께 노래하면 용도 견디지 못하오."],
						["소 끄는 노인", "'거북아 거북아, 수로를 내놓아라.' 어부들을 모아 대왕암 앞에서 부르시오."],
						["처용", "모아 오겠소."],
					], func(): setf("c4_noin"); g.save_game())
			elif fl("c4_boss"): say([["소 끄는 노인", "허허, 붉은 바위 끝에 핀 꽃은 그대가 꺾은 셈이오."]])
			else: say([["소 끄는 노인", "어부 아낙, 해녀, 늙은 어부. 셋이면 노래가 바다를 덮을 게요."]])
		"fisher":
			if fl("c4_noin") and not fl("c4_v1"):
				say([["어부 아낙", "거북아 거북아… 우리 어머니가 부르던 노래요. 같이 부르리다!"]], func(): setf("c4_v1"); g.ui.toast("함께 노래할 사람 %d/3" % villagers()))
			else: say([["어부 아낙", "요즘 그물에 물고기 대신 해초만 걸리오."]])
		"haenyeo":
			if fl("c4_noin") and not fl("c4_v2"):
				say([["해녀", "용이 무서워 물질도 못 하오. 노래로 쫓을 수 있다면 목청껏 부르겠소!"]], func(): setf("c4_v2"); g.ui.toast("함께 노래할 사람 %d/3" % villagers()))
			else: say([["해녀", "바닷물이 차졌소."]])
		"oldfisher":
			if fl("c4_noin") and not fl("c4_v3"):
				say([["늙은 어부", "콜록… 이 늙은 목청도 보태리다. 바다는 노래를 기억하오."]], func(): setf("c4_v3"); g.ui.toast("함께 노래할 사람 %d/3" % villagers()))
			else: say([["늙은 어부", "대왕암 아래엔 문무대왕께서 용이 되어 잠드셨다 하오."]])
		"monk4": say([["감은사 스님", "문무대왕께서 죽어서도 용이 되어 나라를 지키겠다 하셨소. 이 절은 그 은혜에 감사하는 절이오."]])
		"boy": say([["목동", "할아버지 소는 제가 보고 있어요!"]])
		"peddler": say([["봇짐장수", "바닷가 장터요! 싱싱한… 아니, 튼튼한 물건이오."]], func(): g.ui.open_shop(4))
		"guard4": say([["순정공의 종자", "부인을 지키지 못한 내 죄요."]])
		_: return false
	return true

func update(dt: float) -> void:
	super(dt)
	var pl = p()
	if g.frozen or g.boss: return
	# the village sings the turtle chant at the shore: the dragon's rock opens
	if not fl("ch4_dragon") and villagers() >= 3 and num("kills_coast") >= 12 and Vector2(pl.x, pl.y).distance_to(at(87, 66)) < 140:
		setf("ch4_dragon")
		g.cutscene(func():
			await g.pan(at(96, 66), 1.2)
			await g.say_async([
				["어부 아낙", "거북아 거북아, 수로를 내놓아라!"],
				["해녀", "남의 부인 앗아 간 죄 얼마나 큰가!"],
				["늙은 어부", "네 만일 거역하고 내놓지 않으면, 그물로 잡아 구워 먹으리라!"],
				["@", "바다가 크게 출렁였다. 대왕암 앞의 물길이 열렸다."],
			])
			g.fx.screen_shake(8)
			await g.pan(null, 0.6)
			g.save_game())

func boss_defeated(b) -> bool:
	if b.type != "haeryong": return false
	setf("c4_boss")
	g.cutscene_say([
		["해룡", "크윽… 노래가 이리 무거운 줄 몰랐구나. 수로를 돌려주마."],
		["@", "물결 사이로 수로부인이 걸어 나왔다. 옷에서 처음 맡는 향기가 났다."],
		["소 끄는 노인", "부인, 무사하셨구려. 허허, 이 늙은이가 노래 하나 더 바치리다."],
		hyangga("heonhwa"),
		["소 끄는 노인", "꽃을 바치는 마음은 바위 끝도 두렵지 않은 법이오. 그대도 그리 구르시게."],
	], func(): g.end_boss_fight(); g.refresh_npcs(); g.save_game())
	return true
