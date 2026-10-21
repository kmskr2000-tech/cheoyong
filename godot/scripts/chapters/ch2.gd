# 2장 남산 — 찬기파랑가. Iron vanishes from the villages under Namsan and the monk Chungdam has not come back
# from Samhwa pass. The plague's root here is Bulgasari, the iron-eating beast, waking at Poseokjeong.
extends Chapter

func _init(game) -> void:
	super(game)
	n = 2; map = "namsan"; title = "제2장 · 남산 — 찬기파랑가"

func npcs() -> Array:
	return [
		["chief", "halmi", 95, 66.5, "촌장 할멈", "south", null],
		["smith", "merchant", 90.5, 71.5, "대장장이", "east", null],
		["peddler", "merchant", 94, 72.6, "봇짐장수", "south", null],
		["mother", "villager", 103, 75, "아낙", "west", null],
		["sick2", "sick", 86, 68, "앓는 노인", "east", null],
		["chungdam", "chungdam", 74, 39, "충담사", "south", func(f): return not f.get("c2_boss", false)],
		["chungdam_v", "chungdam", 98, 69, "충담사", "south", func(f): return f.get("c2_boss", false)],
		["nangdo", "hwarang", 59, 53, "화랑 낭도", "west", null],
		["lostkid", "child", 66, 32, "길 잃은 아이", "south", func(f): return f.get("sq_c2_child", "") == "on" and not f.get("sqt_c2_child", false)],
		["lostkid_home", "child", 104.5, 76, "아이", "west", func(f): return f.get("sqt_c2_child", false)],
	]

func spawns() -> Dictionary:
	return {
		"samhwa": {"lvl": 11, "list": [["jangsanbeom", 66, 34], ["imp", 72, 44], ["jangsanbeom", 82, 34], ["snake", 64, 48], ["jangsanbeom", 86, 46], ["imp", 80, 30], ["snake", 70, 50], ["jangsanbeom", 62, 40]],
			"elite": ["jangsanbeom", 86, 32, "흰 장산범"]},
		"maae": {"lvl": 12, "list": [["seokjang", 30, 48], ["ghoul", 24, 56], ["ghost", 40, 62], ["seokjang", 46, 58], ["ghoul", 22, 44], ["ghost", 34, 66], ["seokjang", 50, 46], ["ghoul", 28, 62]]},
		"poseok": {"lvl": 13, "list": [["jangsanbeom", 22, 18], ["dokkaebi", 40, 16], ["seokjang", 20, 26], ["dokkaebi", 44, 26], ["jangsanbeom", 30, 10], ["seokjang", 38, 8]]},
	}

func bosses() -> Dictionary:
	return {
		"maae": {"type": "seokjang", "mini": true, "name": "돌장승 장군", "flag": "c2_general", "at": [37, 50], "trigger": [37, 54], "lvl": 12,
			"need": [["c2_chungdam", true], ["kills_maae", 12]],
			"lines": [["돌장승 장군", "…지나가지 못한다. 골짜기의 부처님은… 이제 탁기의 것이다."]]},
		"poseok": {"type": "bulgasari", "flag": "c2_boss", "at": [32, 27], "trigger": [33, 31], "lvl": 8,
			"need": [["c2_maae_done", true], ["kills_poseok", 10]],
			"lines": [["불가사리", "끄르르륵… 쇠다. 쇠 냄새가 난다…"], ["불가사리", "네 탈의 쇠장식부터 씹어 주마!"], ["처용", "…탈엔 쇠가 없소."]]},
	}

func steps() -> Array:
	return [
		{"text": "남산 어귀 마을의 촌장을 만나시오", "talk": "chief", "done": func(): return fl("c2_chief")},
		{"text": "삼화령의 요괴 정화", "hunt": "samhwa", "count": ["kills_samhwa", 12], "pos": [74, 42], "done": func(): return num("kills_samhwa") >= 12 or fl("c2_chungdam")},
		{"text": "삼화령의 충담사를 찾으시오", "talk": "chungdam", "done": func(): return fl("c2_chungdam")},
		{"text": "마애불 골짜기의 요괴 정화", "hunt": "maae", "count": ["kills_maae", 12], "pos": [36, 52], "done": func(): return num("kills_maae") >= 12 or fl("c2_general")},
		{"text": "마애불 앞의 돌장승 장군", "pos": [37, 54], "done": func(): return fl("c2_general")},
		{"text": "충담사에게 돌아가시오", "talk": "chungdam", "done": func(): return fl("c2_maae_done")},
		{"text": "포석정의 요괴 정화", "hunt": "poseok", "count": ["kills_poseok", 10], "pos": [32, 22], "done": func(): return num("kills_poseok") >= 10 or fl("c2_boss")},
		{"text": "포석정의 우두머리", "pos": [33, 31], "done": func(): return fl("c2_boss")},
		{"text": "촌장 할멈에게 돌아가시오", "talk": "chief", "done": func(): return fl("c2_done")},
	]

func sides() -> Array:
	return [
		{"id": "c2_iron", "giver": "smith", "name": "대장간의 쇳조각", "kind": "collect", "zone": "", "item": "iron", "item_name": "쇳조각", "count": 6, "chance": 0.4,
			"offer": [["대장장이", "솥이며 호미며 쇠붙이가 밤새 사라지오. 요괴들이 삼킨 게 분명하오."], ["대장장이", "놈들을 정화하면 쇳조각이 떨어질 게요. 여섯 개만 모아 주시오. 좋은 걸 벼려 드리리다."]],
			"remind": "쇳조각 여섯 개요.", "thanks": [["대장장이", "이만하면 됐소! 자, 쇠부적이오. 몸에 지니면 요괴 발톱이 덜 들 게요."]],
			"reward": {"talis": "soe", "coins": 60, "exp": 80}},
		{"id": "c2_child", "giver": "mother", "name": "길 잃은 아이", "kind": "talk", "target": "lostkid", "count": 1,
			"offer": [["아낙", "우리 아이가 나물 캐러 삼화령에 올랐다가 아직 안 왔소…"], ["아낙", "고개 위 탑 근처에서 자주 놀았다오. 제발 찾아 주시오."]],
			"found": [["길 잃은 아이", "흑… 아저씨, 무서운 하얀 짐승이 있어요."], ["처용", "집으로 가거라. 길은 내가 지키겠다."], ["@", "아이가 마을로 달려갔다."]],
			"remind": "삼화령 탑 근처라오.", "thanks": [["아낙", "아이고, 살았소! 이건 집안에 내려오는 복부적이오. 받아 주시오."]],
			"reward": {"talis": "bok", "coins": 40, "exp": 60}},
		{"id": "c2_beast", "giver": "nangdo", "name": "흰 장산범", "kind": "elite", "type": "jangsanbeom", "count": 1,
			"offer": [["화랑 낭도", "삼화령 동쪽 바위에 흰 장산범이 산다오. 사람 목소리를 흉내 내 홀린다오."], ["화랑 낭도", "놈을 정화해 주면 기파랑 낭도의 이름으로 사례하겠소."]],
			"remind": "흰 장산범은 삼화령 동쪽 바위 위에 있소.", "thanks": [["화랑 낭도", "과연 용왕의 아드님이오! 바람처럼 걷게 해 주는 풍부적이오."]],
			"reward": {"talis": "pung", "coins": 80, "exp": 120}},
	]

func interact(npc) -> bool:
	var pl = p()
	match npc.id:
		"chief":
			if not fl("c2_chief"):
				say([
					["촌장 할멈", "서라벌에서 오신 처용 님이시오? 마침 잘 오셨소."],
					["촌장 할멈", "달포 전부터 마을의 쇠붙이가 밤마다 사라지고, 사람들이 시름시름 앓소."],
					["촌장 할멈", "충담 스님이 삼화령 미륵님께 차를 올리러 가셨는데, 사흘째 내려오지 않으시오."],
					["처용", "찾아보겠소."],
					["촌장 할멈", "고개엔 장산범이 나온다오. 하얀 털에 사람 목소리를 흉내 내는 놈이오. 조심하시오."],
				], func(): setf("c2_chief"); g.save_game())
			elif fl("c2_boss") and not fl("c2_done"):
				say([
					["촌장 할멈", "포석정의 쇠먹는 짐승을 무릎 꿇리셨다고! 마을 쇠붙이도 다 돌아왔소."],
					["촌장 할멈", "이건 이 마을 탈춤패가 쓰던 양반탈이오. 처용 님 얼굴에 더 어울리겠소."],
					["@", "양반탈을 얻었다. (공격 +15%, 받는 피해 −10%)", func(): g.add_mask("yangban")],
					["촌장 할멈", "충담 스님이 그러시는데, 토함산 너머에도 역신의 뿌리가 내렸다 하오."],
					["촌장 할멈", "역참 마부에게 말하면 토함산 불국사까지 태워다 줄 게요."],
				], func(): setf("c2_done"); setf("map_toham"); g.ui.toast("이동할 수 있는 곳: 토함산"); g.save_game())
			elif fl("c2_done"): say([["촌장 할멈", "남산은 이제 평안하오. 처용 님 덕이오."]])
			else: say([["촌장 할멈", "충담 스님을 부탁하오. 삼화령은 북서쪽 고갯길이오."]])
		"chungdam":
			if not fl("c2_chungdam"):
				if num("kills_samhwa") < 12:
					say([["충담사", "…누구시오? 고개의 요괴들이 아직 사납소. 먼저 탁기를 걷어 주시오."]])
					return true
				say([
					["충담사", "용왕의 아드님이라… 노랫소리가 바다 냄새를 풍긴다 했소."],
					["충담사", "삼월 삼짇날마다 이 미륵님께 차를 올렸소. 헌데 올해는 미륵님 눈에서 검은 눈물이 흐르오."],
					["충담사", "탁기는 서쪽 마애불 골짜기에서 올라오오. 바위의 부처님마저 검게 물들었다오."],
					["충담사", "낭도에게 길을 열라 일러두겠소. 가 보시오."],
					["@", "마애불 골짜기로 가는 길이 열렸다.", func(): Sfx.sfx("quest")],
				], func(): setf("c2_chungdam"); setf("ch2_maae"); g.save_game())
			elif not fl("c2_general"): say([["충담사", "마애불 골짜기는 서쪽이오. 돌장승들이 길을 막고 있을 게요."]])
			elif not fl("c2_maae_done"):
				say([
					["충담사", "골짜기 부처님 얼굴이 다시 웃으시는구려. 고맙소."],
					["충담사", "허나 뿌리는 더 깊소. 북쪽 포석정 터에 쇠를 먹는 짐승이 깨어났소. 불가사리라 하오."],
					["충담사", "놈은 쇠를 먹을수록 단단해지오. 몸이 번쩍일 땐 정면으로 치지 마시오."],
					["@", "포석정으로 가는 길이 열렸다.", func(): Sfx.sfx("quest")],
				], func(): setf("c2_maae_done"); setf("ch2_poseok"); g.save_game())
			else: say([["충담사", "포석정은 북쪽이오. 물길이 전복 모양으로 휘도는 곳이오."]])
		"chungdam_v": say([["충담사", "기파랑의 노래가 그대에게 힘이 되기를. 잣나무 가지는 눈을 모른다오."]])
		"peddler": say([["봇짐장수", "남산 장터는 오랜만이오! 구경하고 가시오."]], func(): g.ui.open_shop(2))
		"sick2": say([["앓는 노인", "콜록… 꿈에 쇠 씹는 소리가 들리오…" if not fl("c2_boss") else "몸이 한결 가볍소. 고맙소."]])
		"nangdo":
			if not fl("c2_chungdam"): say([["화랑 낭도", "이 너머는 마애불 골짜기요. 충담 스님 허락 없인 못 지나가오."]])
			else: say([["화랑 낭도", "기파랑 어른의 뜻을 받들어 길을 지키고 있소."]])
		"smith": say([["대장장이", "쇠가 돌아오면 다시 망치를 들겠소."]])
		"mother": say([["아낙", "고맙소, 정말 고맙소."]])
		"lostkid_home": say([["아이", "아저씨 최고!"]])
		_: return false
	return true

func boss_defeated(b) -> bool:
	match b.type:
		"seokjang":
			setf("c2_general")
			g.cutscene_say([
				["돌장승 장군", "…따뜻한 노래로구나. 이 몸은 본디 마을 어귀를 지키던 장승이었다."],
				["돌장승 장군", "부처님께 길을 비켜 드리겠다."],
				["@", "마애불을 덮던 검은 기운이 걷혔다."],
			], func(): g.end_boss_fight(); g.save_game())
			return true
		"bulgasari":
			setf("c2_boss")
			g.cutscene_say([
				["불가사리", "끄으… 배가… 부르다. 노래가 쇠보다 든든하구나."],
				["불가사리", "역신이 내 배를 주리게 했다… 이제 삼킨 쇠는 돌려주마."],
				["@", "불가사리의 입에서 호미며 솥이며 쇠붙이가 쏟아졌다."],
				["충담사", "장하오, 처용. 이제 이 노래를 받으시오. 내가 기파랑을 기려 지은 노래요."],
				hyangga("chan"),
				["충담사", "그대의 소리결이 잣나무 가지처럼 높고 곧게 뻗을 것이오."],
			], func(): g.end_boss_fight(); g.refresh_npcs(); g.save_game())
			return true
	return false
