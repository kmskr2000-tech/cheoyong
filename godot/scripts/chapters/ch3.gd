# 3장 토함산 — 제망매가. The monk Wolmyeong cannot rest: his dead sister wanders the mountain, and a darkness
# that grows when watched (어둑시니) has covered the cave Buddha of Seokguram.
extends Chapter

func _init(game) -> void:
	super(game)
	n = 3; map = "toham"; title = "제3장 · 토함산 — 제망매가"

func npcs() -> Array:
	return [
		["wolmyeong", "wolmyeong", 88, 67, "월명사", "south", func(f): return not f.get("c3_boss", false) or f.get("c3_song", false)],
		["wolmyeong_s", "wolmyeong", 31, 25, "월명사", "north", func(f): return f.get("c3_boss", false) and not f.get("c3_song", false)],
		["jusi", "monk", 82, 76, "주지 스님", "east", null],
		["asadal", "merchant", 79, 74.5, "석공 아사달", "east", null],
		["hunter", "hwarang", 72, 63, "사냥꾼", "west", null],
		["peddler", "merchant", 92, 79.6, "봇짐장수", "south", null],
		["pilgrim", "villager", 97, 74, "순례객", "west", null],
		["sister", "ghost", 33, 25.5, "누이의 넋", "west", func(f): return f.get("c3_boss", false) and not f.get("c3_song", false)],
	]

func spawns() -> Dictionary:
	return {
		"toham_path": {"lvl": 16, "list": [["ghost", 50, 44], ["jangsanbeom", 58, 52], ["ghost", 64, 60], ["snake", 46, 56], ["jangsanbeom", 68, 48], ["ghost", 54, 62], ["snake", 44, 46], ["jangsanbeom", 62, 42]]},
		"summit": {"lvl": 17, "list": [["jangsanbeom", 64, 20], ["dokkaebi", 74, 12], ["hwagwi", 86, 14], ["dokkaebi", 90, 26], ["hwagwi", 62, 10], ["jangsanbeom", 82, 28]],
			"elite": ["ghost", 92, 8, "그림자 원귀"]},
		"seokgul": {"lvl": 18, "list": [["seokjang", 20, 30], ["ghoul", 36, 30], ["ghost", 18, 14], ["seokjang", 40, 14], ["ghoul", 26, 34], ["ghost", 42, 24], ["seokjang", 14, 22], ["ghoul", 34, 12]]},
	}

func bosses() -> Dictionary:
	return {
		"seokgul": {"type": "eoduksini", "flag": "c3_boss", "at": [28, 22.5], "trigger": [28, 27], "lvl": 11,
			"need": [["c3_dawn", true], ["kills_seokgul", 12]],
			"lines": [["어둑시니", "보아라… 나를 볼수록… 나는 커진다…"], ["어둑시니", "석굴의 부처도… 이제 내 그늘 아래 있다."], ["처용", "눈을 감고도 노래는 부를 수 있소."]]},
	}

func steps() -> Array:
	return [
		{"text": "불국사의 월명사를 만나시오", "talk": "wolmyeong", "done": func(): return fl("c3_wol")},
		{"text": "토함산 숲길의 원귀 정화", "hunt": "toham_path", "count": ["kills_toham_path", 12], "pos": [56, 52], "done": func(): return num("kills_toham_path") >= 12 or fl("c3_summit_open")},
		{"text": "월명사에게 알리시오", "talk": "wolmyeong", "done": func(): return fl("c3_summit_open")},
		{"text": "토함산 마루의 요괴 정화", "hunt": "summit", "count": ["kills_summit", 10], "pos": [76, 20], "done": func(): return num("kills_summit") >= 10 or fl("c3_dawn")},
		{"text": "마루의 제단에서 해돋이를 기다리시오", "pos": [72, 24], "done": func(): return fl("c3_dawn")},
		{"text": "석굴 앞의 요괴 정화", "hunt": "seokgul", "count": ["kills_seokgul", 12], "pos": [28, 30], "done": func(): return num("kills_seokgul") >= 12 or fl("c3_boss")},
		{"text": "석굴의 어둠", "pos": [28, 27], "done": func(): return fl("c3_boss")},
		{"text": "석굴 앞의 월명사", "talk": "wolmyeong_s", "done": func(): return fl("c3_song")},
		{"text": "불국사로 돌아가 월명사를 만나시오", "talk": "wolmyeong", "done": func(): return fl("c3_done")},
	]

func sides() -> Array:
	return [
		{"id": "c3_wick", "giver": "jusi", "name": "연등 심지", "kind": "collect", "zone": "toham_path", "item": "wick", "item_name": "연등 심지", "count": 5, "chance": 0.45,
			"offer": [["주지 스님", "숲길의 연등이 모두 꺼졌소. 원귀들이 심지를 물어 갔다오."], ["주지 스님", "심지 다섯 개만 찾아 주시오. 등을 다시 밝히리다."]],
			"remind": "연등 심지 다섯이오.", "thanks": [["주지 스님", "나무아미타불. 등불이 다시 켜졌소. 이 수부적을 지니시오."]],
			"reward": {"talis": "su", "coins": 150, "exp": 300}},
		{"id": "c3_shadow", "giver": "asadal", "name": "그림자 원귀", "kind": "elite", "type": "ghost", "count": 1,
			"offer": [["석공 아사달", "내 아내 아사녀는 영지 못에 탑 그림자가 비치길 기다리다 물에 들었소."], ["석공 아사달", "헌데 마루에 아내를 닮은 그림자 원귀가 떠돈다 하오. 제발… 편히 보내 주시오."]],
			"remind": "토함산 마루 동쪽 끝이오.", "thanks": [["석공 아사달", "…고맙소. 이제야 탑을 마저 깎을 수 있겠소. 흥부적이오. 노래에 힘이 실릴 게요."]],
			"reward": {"talis": "heung", "coins": 200, "exp": 500}},
		{"id": "c3_hunt", "giver": "hunter", "name": "숲길의 장산범", "kind": "kill", "zone": "", "type": "jangsanbeom", "count": 8,
			"offer": [["사냥꾼", "장산범 놈들이 순례길을 끊었소. 여덟만 정화해 주시오."]],
			"remind": "장산범 여덟이오.", "thanks": [["사냥꾼", "순례객들이 다시 오르겠소! 묘부적이오. 운이 따를 게요."]],
			"reward": {"talis": "myo", "coins": 120, "exp": 300}},
	]

func interact(npc) -> bool:
	match npc.id:
		"wolmyeong":
			if not fl("c3_wol"):
				say([
					["월명사", "…피리 소리가 끊긴 지 오래되었소. 처용 공이시구려."],
					["월명사", "먼저 떠난 누이의 넋이 저승으로 가지 못하고 토함산을 헤매오. 역신이 길을 흐려 놓았소."],
					["월명사", "숲길엔 원귀가 들끓고, 석굴의 부처님은 어둠에 덮였소. 그 어둠은 볼수록 자란다 하오."],
					["처용", "숲길부터 걷겠소."],
				], func(): setf("c3_wol"); g.save_game())
			elif not fl("c3_summit_open"):
				if num("kills_toham_path") < 12: say([["월명사", "숲길의 원귀를 걷어 주시오. (%d/12)" % num("kills_toham_path")]])
				else:
					say([
						["월명사", "숲이 조용해졌소. 허나 석굴 앞의 어둠은 해가 떠야 물러나오."],
						["월명사", "토함산 마루에서 동해의 해돋이를 맞으시오. 첫 햇살이 석굴로 길을 낼 게요."],
						["@", "토함산 마루로 가는 길이 열렸다.", func(): Sfx.sfx("quest")],
					], func(): setf("c3_summit_open"); setf("ch3_summit"); g.save_game())
			elif fl("c3_song") and not fl("c3_done"):
				say([
					["월명사", "누이가 편히 갔소. 그대 덕이오."],
					["월명사", "이 각시탈은 누이가 어릴 적 쓰던 것이오. 가볍게 춤추는 이에게 어울리오."],
					["@", "각시탈을 얻었다. (이동 +15%, 구르기 대기 −40%, 흥 +20%)", func(): g.add_mask("gaksi")],
					["월명사", "동해 감은사에서 기별이 왔소. 바다에서 용이 사람을 채어 갔다 하오."],
				], func(): setf("c3_done"); setf("map_donghae"); g.ui.toast("이동할 수 있는 곳: 동해 감은사"); g.save_game())
			elif fl("c3_done"): say([["월명사", "피리를 불면 달도 멈춘다 했던가… 오늘은 그냥 불고 싶소."]])
			else: say([["월명사", "마루는 북쪽, 석굴은 북서쪽이오."]])
		"wolmyeong_s":
			if not fl("c3_song"):
				say([
					["월명사", "어둠이 걷혔구려. …누이야."],
					["누이의 넋", "오라버니… 길이 보이지 않았어요."],
					["월명사", "이 노래를 따라가거라. 한 가지에 나서 가는 곳을 모르니, 미타찰에서 만나자꾸나."],
					hyangga("jemang"),
					["@", "피리 소리를 따라 누이의 넋이 새벽빛 속으로 사라졌다."],
					["월명사", "처용 공, 이 노래를 가져가시오. 춤추며 떠나간 이를 위로하는 노래요."],
				], func(): setf("c3_song"); g.refresh_npcs(); g.save_game())
		"jusi": say([["주지 스님", "불국사는 부처님 나라를 땅에 옮긴 절이오. 청운교 백운교를 건너면 다른 세상이오."]])
		"asadal": say([["석공 아사달", "석가탑은 그림자가 비치지 않는 탑이라 무영탑이라 부르오."]])
		"hunter": say([["사냥꾼", "토함산은 내 앞마당 같은 곳이오."]])
		"peddler": say([["봇짐장수", "산 위라 값이 좀 나가오. 그래도 좋은 물건이오!"]], func(): g.ui.open_shop(3))
		"pilgrim": say([["순례객", "석굴 부처님께 절 한 번 올리러 왔는데… 길이 무서워 못 가오."]])
		"sister": say([["누이의 넋", "…"]])
		_: return false
	return true

func update(dt: float) -> void:
	super(dt)
	var pl = p()
	if g.frozen or g.boss: return
	# dawn on the summit altar once the summit is clear
	if not fl("c3_dawn") and num("kills_summit") >= 10 and Vector2(pl.x, pl.y).distance_to(at(72, 24)) < 120:
		setf("c3_dawn")
		g.cutscene(func():
			await g.pan(at(80, 12), 1.2)
			g.fx.screen_flash(0.8, Color("#ffe8c0"))
			await g.say_async([
				["@", "동해 너머로 해가 솟았다. 첫 햇살이 산줄기를 타고 석굴 쪽으로 흘러갔다."],
				["처용", "…길이 열렸소."],
			])
			setf("ch3_seokgul")
			await g.pan(null, 0.6)
			g.save_game())

func boss_defeated(b) -> bool:
	if b.type != "eoduksini": return false
	setf("c3_boss")
	g.cutscene_say([
		["어둑시니", "…네가 나를 보지 않았구나. 노래만… 보았구나."],
		["어둑시니", "어둠은 바라봐 주는 이가 없으면… 그저 그늘일 뿐…"],
		["@", "어둠이 걷히고 석굴의 부처님 얼굴에 새벽빛이 들었다."],
	], func(): g.end_boss_fight(); g.refresh_npcs(); g.save_game())
	return true
