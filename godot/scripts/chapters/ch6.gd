# 6장 반월성 — 도솔가, and the end. Two suns hang over Silla: the false one is Samjogo, corrupted by Yeoksin.
# Wolmyeong sings the Dosol song to bring it down; then Yeoksin's true body waits in the palace courtyard.
extends Chapter

func _init(game) -> void:
	super(game)
	n = 6; map = "banwol"; title = "제6장 · 반월성 — 도솔가"

func npcs() -> Array:
	return [
		["wolmyeong6", "wolmyeong", 29, 62, "월명사", "south", null],
		["elder", "sansin", 22, 64, "계림 노인", "east", null],
		["ilgwan", "dosa", 70, 64, "일관", "west", null],
		["king6", "king", 80, 46, "왕", "south", func(f): return f.get("c6_dosol", false)],
		["guard6", "hwarang", 74, 46, "궁성 화랑", "south", null],
		["peddler", "merchant", 32, 78.6, "봇짐장수", "south", null],
		["girl", "child", 40, 70, "계림 아이", "west", null],
	]

func spawns() -> Dictionary:
	return {
		"cheomseong": {"lvl": 27, "list": [["hwagwi", 56, 56], ["jangsanbeom", 76, 58], ["ghost", 60, 74], ["hwagwi", 84, 66], ["dokkaebi", 52, 70], ["jangsanbeom", 92, 56], ["hwagwi", 72, 78], ["ghost", 88, 78], ["dokkaebi", 64, 50], ["jangsanbeom", 98, 74]],
			"elite": ["jangsanbeom", 100, 50, "금빛 장산범"]},
		"banwol": {"lvl": 29, "list": [["seokjang", 64, 30], ["kkoktu", 90, 30], ["mulgwisin", 66, 12], ["seokjang", 88, 12], ["ghoul", 60, 24], ["kkoktu", 94, 24], ["mulgwisin", 72, 34], ["ghoul", 84, 34]]},
	}

func bosses() -> Dictionary:
	return {
		"cheomseong": {"type": "samjogo", "flag": "c6_sun", "at": [66, 66], "trigger": [66, 70], "lvl": 20,
			"need": [["c6_ilgwan", true]],
			"lines": [["삼족오", "까아악! 나는 해다. 해가 둘이면 어떠냐, 더 밝을 뿐이다!"], ["월명사", "본디 해는 하나요. 그대는 역신의 그늘을 쓴 새일 뿐이오."], ["처용", "내려오시오."]]},
		"banwol": {"type": "yeoksin_true", "flag": "c6_final", "at": [77, 22], "trigger": [77, 28], "lvl": 22,
			"need": [["ch6_palace", true], ["kills_banwol", 12]],
			"lines": [["역신", "왔구나, 처용. 그림자를 꿇렸다고 내가 꿇을 줄 알았느냐?"], ["역신", "신라 곳곳에 내린 뿌리를 네가 다 뽑았다지. 허나 뿌리는 다시 난다. 사람이 미워하는 한."], ["처용", "미워하지 않소. 노래하오."]]},
	}

func steps() -> Array:
	return [
		{"text": "계림의 월명사를 만나시오", "talk": "wolmyeong6", "done": func(): return fl("c6_met")},
		{"text": "첨성대 들판의 요괴 정화", "hunt": "cheomseong", "count": ["kills_cheomseong", 14], "pos": [66, 70], "done": func(): return num("kills_cheomseong") >= 14 or fl("c6_ilgwan")},
		{"text": "첨성대의 일관", "talk": "ilgwan", "done": func(): return fl("c6_ilgwan")},
		{"text": "두 번째 해", "pos": [66, 70], "done": func(): return fl("c6_sun")},
		{"text": "월명사와 함께 반월성으로", "talk": "wolmyeong6", "done": func(): return fl("c6_dosol")},
		{"text": "반월성의 요괴 정화", "hunt": "banwol", "count": ["kills_banwol", 12], "pos": [77, 30], "done": func(): return num("kills_banwol") >= 12 or fl("c6_final")},
		{"text": "궁궐 앞뜰의 역신", "pos": [77, 28], "done": func(): return fl("c6_final")},
	]

func sides() -> Array:
	return [
		{"id": "c6_star", "giver": "ilgwan", "name": "떨어진 별가루", "kind": "collect", "zone": "cheomseong", "item": "stardust", "item_name": "별가루", "count": 6, "chance": 0.4,
			"offer": [["일관", "가짜 해가 뜬 뒤로 별들이 들판에 떨어졌소. 요괴들이 그 가루를 삼켰다오."], ["일관", "여섯 줌만 모아 주면 하늘의 길을 다시 그리겠소."]],
			"remind": "별가루 여섯 줌이오.", "thanks": [["일관", "이제 하늘이 제자리를 찾겠소. 묘부적을 하나 더 드리리다."]],
			"reward": {"talis": "myo", "coins": 600, "exp": 2000}},
		{"id": "c6_gold", "giver": "elder", "name": "금빛 장산범", "kind": "elite", "type": "jangsanbeom", "count": 1,
			"offer": [["계림 노인", "김알지가 금궤에서 나온 이 숲에 금빛 짐승이 어슬렁거리오. 첨성대 동북쪽 끝이오."]],
			"remind": "첨성대 들판 동북쪽 끝이오.", "thanks": [["계림 노인", "숲의 닭이 다시 울겠구먼. 금강부적이오."]],
			"reward": {"talis": "geum", "coins": 800, "exp": 2500}},
		{"id": "c6_guard", "giver": "guard6", "name": "궁성 지키기", "kind": "kill", "zone": "banwol", "count": 12,
			"offer": [["궁성 화랑", "궁성 안이 요괴 소굴이 되었소. 열둘만 정화해 주면 화랑도가 힘을 보태리다."]],
			"remind": "궁성 안 요괴 열둘이오.", "thanks": [["궁성 화랑", "화랑도의 이름으로 감사드리오! 엽전과 약과요."]],
			"reward": {"coins": 1000, "exp": 3000, "items": {"yakgwa": 4, "sikhye": 2}}},
	]

func interact(npc) -> bool:
	match npc.id:
		"wolmyeong6":
			if not fl("c6_met"):
				say([
					["월명사", "또 만났구려, 처용 공. 하늘을 보시오. 해가 둘이오."],
					["월명사", "임금께서 나더러 노래로 괴변을 물리치라 하셨소. 헌데 가짜 해는 역신의 그늘을 쓴 삼족오요."],
					["월명사", "첨성대의 일관이 그 둥지를 찾고 있소. 들판의 요괴부터 걷어 주시오."],
					["처용", "가겠소."],
				], func(): setf("c6_met"); g.save_game())
			elif fl("c6_sun") and not fl("c6_dosol"):
				say([
					["월명사", "해가 하나로 돌아왔구려. 이제 이 노래를 받으시오. 도솔천의 미륵을 부르는 노래요."],
					hyangga("dosol"),
					["월명사", "다섯 노래가 모였소. 처용가와 함께라면… 역신의 본체도 견디지 못할 게요."],
					["월명사", "반월성 문을 열라고 화랑들에게 일러두었소. 가시오."],
					["@", "반월성으로 가는 문이 열렸다.", func(): Sfx.sfx("quest")],
				], func(): setf("c6_dosol"); setf("ch6_palace"); g.refresh_npcs(); g.save_game())
			elif fl("c6_dosol"): say([["월명사", "반월성 궁궐 앞뜰이오. 노래를 잊지 마시오."]])
			else: say([["월명사", "들판의 요괴를 걷어 내면 일관이 길을 알려 줄 게요."]])
		"ilgwan":
			if not fl("c6_ilgwan"):
				if num("kills_cheomseong") < 14: say([["일관", "요괴들이 하늘을 가려 별을 볼 수가 없소. (%d/14)" % num("kills_cheomseong")]])
				else:
					say([
						["일관", "첨성대에서 보니 가짜 해는 해 질 녘마다 이 탑 위에 내려앉소."],
						["일관", "탑 앞에서 기다리면 놈이 내려올 게요. 월명 스님도 곧 오실 게요."],
					], func(): setf("c6_ilgwan"); g.save_game())
			else: say([["일관", "하늘의 일은 하늘에, 땅의 일은 노래에."]])
		"king6": say([["왕", "처용, 서라벌을 다시 부탁하오. 이번이 마지막이길 바라오."]])
		"guard6": say([["궁성 화랑", "문이 열렸소. 화랑도가 뒤를 지키겠소." if fl("ch6_palace") else "반월성 문은 굳게 닫혔소. 월명 스님의 허락이 있어야 하오."]])
		"elder": say([["계림 노인", "계림은 신라가 시작된 숲이오. 끝도 여기서 보게 되려나."]])
		"peddler": say([["봇짐장수", "마지막 장터일지도 모르오. 아낌없이 사 가시오!"]], func(): g.ui.open_shop(6))
		"girl": say([["계림 아이", "하늘에 해가 두 개라 눈이 부셔요."]])
		_: return false
	return true

# at 30%: the five hyangga and the song of Cheoyong answer together; only 처용가 can end it
func final_turn(boss) -> void:
	var pl = p()
	g.cutscene(func():
		await g.pan(Vector2(boss.x, boss.y - 30), 0.8)
		await g.say_async([
			["역신", "흐흐… 노래 따위로 나를 지울 수 있느냐? 미워하라, 처용! 칼을 들어라!"],
			["@", "잣나무 가지처럼 곧은 소리가 들렸다. — 찬기파랑가"],
			["@", "한 가지에 나서 흩어진 이들을 위로하는 피리 소리. — 제망매가"],
			["@", "바위 끝에 바친 붉은 꽃. — 헌화가"],
			["@", "천 개의 손이 처용의 소매를 받쳤다. — 도천수관음가"],
			["@", "하늘에 뿌린 꽃잎이 길을 냈다. — 도솔가"],
			["처용", "…서라벌 밝은 달에, 밤 늦도록 노닐다가."],
			["@", "노래가 하나가 되었다. 흥이 가득 찼다.", func(): pl.heung = 100.0],
		])
		await g.pan(null, 0.5)
		boss.ult_vulnerable = true
		g.tutorial("ult"))

func boss_defeated(b) -> bool:
	match b.type:
		"samjogo":
			setf("c6_sun")
			g.cutscene_say([
				["삼족오", "까악… 나는 그저 해를 따라 날던 까마귀였다. 언제부터 해가 되고 싶었던가…"],
				["@", "가짜 해가 빛을 잃고 검은 깃털이 되어 흩어졌다. 하늘에 해가 하나 남았다."],
			], func(): g.end_boss_fight(); g.refresh_npcs(); g.save_game())
			return true
		"yeoksin_true":
			setf("c6_final")
			g.cutscene_say([
				["역신", "…미워하지 않는구나. 끝까지."],
				["역신", "미움이 없으면 나는 깃들 곳이 없다. 졌다, 처용."],
				["역신", "맹세하마. 처용의 얼굴을 그린 문에는, 아니 노래가 들리는 집에는 다시 들지 않으리라."],
				["@", "역신의 본체가 무릎 꿇고 새벽빛 속으로 흩어졌다. 신라의 하늘에 역병의 그늘이 걷혔다."],
				["월명사", "다섯 노래와 처용가… 이제 이 노래들은 사람들 입에서 입으로 전해질 게요."],
				["처용", "…집에 가겠소."],
			], func(): setf("c6_done"); g.end_boss_fight(); g.save_game(); g.start_ending())
			return true
	return false
