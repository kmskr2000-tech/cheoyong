# 5장 황룡사 — 도천수관음가. Plague in the streets east of Seorabeol: a mother, Heemyeong, prays for her child
# who went blind, while puppets walk the night pulled by a tall shadow (그슨대) from the ruined great temple.
extends Chapter

func _init(game) -> void:
	super(game)
	n = 5; map = "hwangnyong"; title = "제5장 · 황룡사 — 도천수관음가"

func npcs() -> Array:
	return [
		["heemyeong", "heemyeong", 86, 64.5, "희명", "south", null],
		["blindkid", "child", 87.6, 64.8, "희명의 아이", "west", null],
		["bmonk", "monk", 94, 64, "분황사 스님", "west", null],
		["kkoktusoe", "merchant", 69, 70, "꼭두쇠", "west", null],
		["guard5", "hwarang", 56, 50, "황룡사 문지기", "south", null],
		["peddler", "merchant", 90, 75.6, "봇짐장수", "south", null],
		["sick5", "sick", 76, 72, "앓는 장인", "east", null],
		["widow", "villager", 100, 70, "과부", "west", null],
	]

func spawns() -> Dictionary:
	return {
		"plague_street": {"lvl": 24, "list": [["kkoktu", 40, 60], ["ghost", 48, 72], ["kkoktu", 58, 56], ["ghoul", 36, 70], ["kkoktu", 62, 74], ["imp", 44, 80], ["ghost", 56, 80], ["kkoktu", 38, 54], ["ghoul", 64, 64], ["imp", 50, 58]]},
		"hwangnyong": {"lvl": 25, "list": [["kkoktu", 40, 30], ["hwagwi", 66, 30], ["seokjang", 36, 14], ["kkoktu", 70, 14], ["hwagwi", 44, 38], ["seokjang", 62, 38], ["kkoktu", 30, 38], ["ghost", 74, 40]],
			"elite": ["kkoktu", 32, 10, "붉은 꼭두각시"]},
	}

func bosses() -> Dictionary:
	return {
		"hwangnyong": {"type": "geuseundae", "flag": "c5_boss", "at": [53, 31], "trigger": [53, 37], "lvl": 17,
			"need": [["ch5_temple", true], ["kills_hwangnyong", 12]],
			"lines": [["그슨대", "…줄을 당기면 춤추고, 줄을 놓으면 쓰러지지. 사람이나 인형이나."], ["그슨대", "역신께서 이 거리를 내게 맡기셨다. 너도 내 줄에 매달려 보아라."], ["처용", "나는 줄 없이도 춤추오."]]},
	}

func steps() -> Array:
	return [
		{"text": "분황사의 희명을 만나시오", "talk": "heemyeong", "done": func(): return fl("c5_met")},
		{"text": "역병 든 저자의 요괴 정화", "hunt": "plague_street", "count": ["kills_plague_street", 14], "pos": [50, 66], "done": func(): return num("kills_plague_street") >= 14 or fl("c5_puppet")},
		{"text": "저자 끝의 꼭두쇠", "talk": "kkoktusoe", "done": func(): return fl("c5_puppet")},
		{"text": "황룡사 터의 요괴 정화", "hunt": "hwangnyong", "count": ["kills_hwangnyong", 12], "pos": [53, 34], "done": func(): return num("kills_hwangnyong") >= 12 or fl("c5_boss")},
		{"text": "구층 목탑 앞의 그림자", "pos": [53, 37], "done": func(): return fl("c5_boss")},
		{"text": "분황사로 돌아가 희명을 만나시오", "talk": "heemyeong", "done": func(): return fl("c5_done")},
	]

func sides() -> Array:
	return [
		{"id": "c5_herb", "giver": "bmonk", "name": "역병 약초", "kind": "collect", "zone": "plague_street", "item": "herb", "item_name": "약초", "count": 6, "chance": 0.4,
			"offer": [["분황사 스님", "원효 스님이 남기신 처방이 있소. 저자의 요괴들이 약초 밭을 짓밟았소."], ["분황사 스님", "약초 여섯 줌만 모아 주시오. 앓는 이들에게 달여 먹이겠소."]],
			"remind": "약초 여섯 줌이오.", "thanks": [["분황사 스님", "이만하면 저자 사람들을 살리겠소. 용부적이오. 그대 춤에 용의 기운이 실릴 게요."]],
			"reward": {"talis": "yong", "coins": 400, "exp": 1200}},
		{"id": "c5_strings", "giver": "kkoktusoe", "name": "끊어진 줄", "kind": "kill", "zone": "", "type": "kkoktu", "count": 10,
			"offer": [["꼭두쇠", "내 남사당패 인형들이오. 줄이 끊긴 채 사람을 해치고 다니오."], ["꼭두쇠", "열만 쉬게 해 주시오. 인형도 넋이 있소."]],
			"remind": "꼭두각시 열이오.", "thanks": [["꼭두쇠", "고맙소. 놀이판에 쓰던 흥부적… 아니, 이건 천부적이오. 가져가시오."]],
			"reward": {"talis": "cheon", "coins": 300, "exp": 1000}},
		{"id": "c5_red", "giver": "guard5", "name": "붉은 꼭두각시", "kind": "elite", "type": "kkoktu", "count": 1,
			"offer": [["황룡사 문지기", "목탑 서북쪽 구석에 붉은 꼭두각시가 있소. 문지기 셋이 놈에게 당했소."]],
			"remind": "황룡사 터 서북쪽이오.", "thanks": [["황룡사 문지기", "원수를 갚아 주셨소! 엽전과 식혜를 드리리다."]],
			"reward": {"coins": 600, "exp": 1500, "items": {"sikhye": 3, "yakgwa": 2}}},
	]

func interact(npc) -> bool:
	match npc.id:
		"heemyeong":
			if not fl("c5_met"):
				say([
					["희명", "…처용 공이시지요. 우리 아이가 역병을 앓고 나서 눈이 멀었소."],
					["희명", "분황사 북벽의 천수관음께 빌고 또 빌었지만, 관음님 그림마저 빛이 바랬소."],
					["희명", "밤마다 저자에 꼭두각시들이 돌아다니며 병을 옮긴다오. 황룡사 터 쪽에서 내려온다고들 하오."],
					["처용", "저자부터 걷어 내겠소."],
				], func(): setf("c5_met"); g.save_game())
			elif fl("c5_boss") and not fl("c5_done"):
				say([
					["희명", "그림자가 걷히니 관음님 그림에 다시 빛이 도오. 이제 아이와 함께 빌어 보겠소."],
					["희명의 아이", "엄마… 노래 불러 줘."],
					["희명", "천 개의 손, 천 개의 눈을 가지신 관음보살님…"],
					hyangga("docheon"),
					["희명의 아이", "…엄마? 엄마 얼굴이 보여!"],
					["희명", "아아… 처용 공, 이 노래를 가져가시오. 천 개의 손이 그대와 함께할 게요."],
					["꼭두쇠", "처용 공! 우리 패가 쓰던 말뚝이탈이오. 양반 놀리던 그 탈이 이제 역신을 놀릴 게요!"],
					["@", "말뚝이탈을 얻었다. (엽전·경험 +50%, 흥 +20%)", func(): g.add_mask("malttugi")],
					["분황사 스님", "이제 남은 건 반월성이오. 하늘에 해가 둘 떴다는 소문이 들리오."],
				], func(): setf("c5_done"); setf("map_banwol"); g.ui.toast("이동할 수 있는 곳: 반월성"); g.save_game())
			elif fl("c5_done"): say([["희명", "아이가 오늘 처음으로 꽃 이름을 물었소."]])
			else: say([["희명", "부디 조심하시오."]])
		"blindkid": say([["희명의 아이", "아저씨… 아저씨 목소리는 바다 냄새가 나요." if not fl("c5_done") else "아저씨 얼굴이 이렇게 생겼구나!"]])
		"kkoktusoe":
			if not fl("c5_puppet"):
				if num("kills_plague_street") < 14: say([["꼭두쇠", "저자에 인형들이 날뛰오. 먼저 좀 잠재워 주시오. (%d/14)" % num("kills_plague_street")]])
				else:
					say([
						["꼭두쇠", "내가 꼭두쇠, 남사당패 우두머리요. 인형들 줄을 웬 키 큰 그림자가 채어 갔소."],
						["꼭두쇠", "놈은 황룡사 구층 목탑에 숨었소. 문지기에게 내 이름을 대면 문을 열어 줄 게요."],
						["@", "황룡사 터로 가는 문이 열렸다.", func(): Sfx.sfx("quest")],
					], func(): setf("c5_puppet"); setf("ch5_temple"); g.save_game())
			else: say([["꼭두쇠", "그림자 놈은 목탑 앞마당에 있소."]])
		"bmonk": say([["분황사 스님", "자장 스님이 세운 황룡사 목탑은 이웃 아홉 나라를 누르려 지었다 하오."]])
		"guard5": say([["황룡사 문지기", "꼭두쇠 어른이 보내셨다면 들어가시오." if fl("c5_puppet") else "이 너머는 황룡사 터요. 그림자가 무서워 문을 닫았소."]])
		"peddler": say([["봇짐장수", "서라벌 동쪽 장터요! 비싸도 좋은 물건이오."]], func(): g.ui.open_shop(5))
		"sick5": say([["앓는 장인", "콜록… 인형 춤을 보고 나서부터 앓았소."]])
		"widow": say([["과부", "남편이 그림자에 홀려 목탑으로 갔다가 돌아오지 않았소."]])
		_: return false
	return true

func boss_defeated(b) -> bool:
	if b.type != "geuseundae": return false
	setf("c5_boss")
	g.cutscene_say([
		["그슨대", "…줄이… 끊겼구나. 나도 누군가의 줄에 매달려 있었던가."],
		["그슨대", "반월성… 그분이 기다린다. 해가 둘 뜨는 날, 신라는 끝난다…"],
		["@", "그림자가 흩어지자 꼭두각시들이 하나둘 바닥에 내려앉았다."],
	], func(): g.end_boss_fight(); g.save_game())
	return true
