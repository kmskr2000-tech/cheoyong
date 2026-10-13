class_name Levels
## Level definitions (see docs/story-bible.md for what happens where).
## Positions are *footprint* coordinates (before the tier lift; level.gd lifts them).
## ground:  baked ground id (art/ground3d.py → assets/levels/<id>.png/.json)
## props:   [name, x, y, light | null]          light = [offset_y, colour, energy, scale]
## npcs:    [id, sprite sheet, x, y, display name]
## interact:[id, x, y, label]                    things you can examine (board, bed …)
## enemies: [kind, x, y]
## exits:   [Rect2 footprint, target level, target spawn]
## spawns:  {name: Vector2}

const WARM := Color(1.0, 0.52, 0.18)
const GHOSTFIRE := Color(0.75, 0.35, 1.0)

const CANDLE := Color(0.7, 0.55, 1.0)

const DATA := {
	# 월성 편전 — SC1-22~23 왕의 부름과 퇴마어사 임명. 그림 좌표: 남문으로 들어와 돌계단을 올라 편전 앞마당에서 왕을 뵌다.
	"palace": {
		"music": "title", "amb": "",
		"name": "월성 편전",
		"ground": "palace",
		"ambient": Color(0.3, 0.29, 0.42),
		"spawns": {"start": Vector2(258, 376)},
		"props": [["chotdae", 210, 227, [-38, WARM, 1.0, 0.9]], ["chotdae", 306, 227, [-38, WARM, 1.0, 0.9]]],
		"lights": [[258, 140, CANDLE, 0.7, 0.8], [258, 330, CANDLE, 0.5, 0.6], [45, 167, CANDLE, 0.5, 0.5], [455, 167, CANDLE, 0.5, 0.5]],
		"npcs": [["king", "npc_king", 256, 189, "왕"]],
		"interact": [],
		"enemies": [],
		"triggers": [[Rect2(215, 221, 85, 14), "audience"]],
		"exits": [],
	},
	# 경주 관아 — SC1-12 의뢰. 그림(관아 마당)에 맞춘 좌표: 남쪽 길로 들어와 마당에서 형방을 만난다.
	"gwana": {
		"music": "night", "amb": "wind",
		"name": "경주 관아",
		"ground": "gwana",
		"spawns": {"start": Vector2(95, 395)},
		"props": [["jars", 262, 258, null], ["jars", 118, 316, null]],
		"lights": [[200, 204, WARM, 1.0, 0.55], [342, 100, WARM, 1.0, 0.55], [443, 43, WARM, 0.9, 0.5], [496, 80, WARM, 0.9, 0.5],
			[433, 143, WARM, 1.0, 0.55], [308, 260, WARM, 1.0, 0.6], [148, 416, WARM, 0.9, 0.5],
			[250, 73, WARM, 0.6, 0.4], [335, 24, WARM, 0.6, 0.4], [560, 83, WARM, 0.6, 0.4], [100, 147, WARM, 0.6, 0.4]],
		"npcs": [
			["gwanri", "npc_official", 395, 140, "형방 박문"],
			["guardA", "npc_official", 358, 149, "포졸"],
			["guardB", "npc_official", 432, 149, "포졸"],
			["runner", "npc_fisher", 110, 387, "약방 일꾼", "hidden"],
		],
		"interact": [],
		"enemies": [],
		"exits": [[Rect2(50, 400, 100, 19), "gyeongju", "fromGwana"]],
		"anchors": {"exit": Vector2(100, 410)},
	},
	# 서쪽 폐가 — 마당과 안채 (SC1-13). 그림(무너진 대청 마당)에 맞춘 좌표: 서쪽 입구, 왼쪽 문(디딤돌) 위가 다락.
	"pyega1": {
		"music": "dread", "amb": "wind",
		"name": "서쪽 폐가",
		"ground": "pyega1",
		"ambient": Color(0.26, 0.28, 0.44),
		"spawns": {"start": Vector2(26, 387), "fromUp": Vector2(150, 232)},
		"props": [],
		"lights": [[146, 193, GHOSTFIRE, 0.7, 0.5], [440, 147, GHOSTFIRE, 0.8, 0.7], [300, 267, GHOSTFIRE, 0.4, 0.5], [60, 400, GHOSTFIRE, 0.4, 0.5]],
		"npcs": [],
		"interact": [],
		# SC1-13: 무너진 마당 — 역병 들개·역귀, 깨진 항아리 곁엔 물귀신, 구석엔 처녀귀신
		"enemies": [["dog", 260, 300], ["ghoul", 300, 330], ["dog", 420, 387], ["ghoul", 230, 280],
			["mulgwi", 520, 387], ["maiden_ghost", 200, 420]],
		"exits": [[Rect2(0, 360, 6, 53), "gyeongju", "fromPyega"], [Rect2(130, 187, 30, 20), "pyega2", "start"]],
		"wisps": Vector2(146, 200),
	},
	# 서쪽 폐가 — 다락과 최심부 (SC1-14~20). 그림 좌표: 아래 복도로 들어와 어두운 대청(다락)을 지나, 기둥 틈 너머 오른쪽 방이 최심부.
	"pyega2": {
		"music": "dread", "amb": "",
		"name": "폐가 다락",
		"ground": "pyega2",
		"ambient": Color(0.3, 0.29, 0.44),
		"wisps": Vector2(680, 213),
		"spawns": {"start": Vector2(282, 400)},
		"props": [["altar", 690, 133, [-20, CANDLE, 1.1, 1.3]]],
		"lights": [[400, 160, GHOSTFIRE, 0.6, 0.8], [282, 309, GHOSTFIRE, 0.5, 0.5], [600, 187, CANDLE, 0.5, 0.7]],
		"npcs": [["soul", "npc_nanyeong", 690, 187, "난영의 넋"]],
		"interact": [],
		# SC1-14: 다락 — 어둠 속 달걀귀신, 울음 우는 처녀귀신, 최심부 문 앞을 지키는 정예 마마귀신
		"enemies": [["ghoul", 350, 173], ["egg_ghost", 300, 227], ["dog", 420, 213], ["maiden_ghost", 330, 136],
			["egg_ghost", 470, 160], ["mama", 500, 221]],
		"vents": [Vector2(300, 147), Vector2(360, 233), Vector2(430, 160), Vector2(470, 233), Vector2(520, 173), Vector2(400, 247)],
		"triggers": [[Rect2(400, 120, 30, 141), "close"], [Rect2(552, 109, 24, 152), "inner"]],
		"exits": [[Rect2(262, 408, 44, 11), "pyega1", "fromUp"]],
		# story.gd: 역신(변장)이 앉은 자리, 최심부 문을 닫는 막, 그 문 바깥으로 쫓겨난 적이 놓이는 자리
		"anchors": {"boss": Vector2(640, 220), "door": Rect2(536, 109, 12, 152), "door_x": 536.0, "kicked": Vector2(518, 213), "boss_goal": Vector2(600, 213), "boss_respawn": Vector2(556, 192)},
	},
	# 개운포 — 백사장과 해안 마을 (SC1-01~07). 처용이 바다에서 뭍으로 올라오는 곳.
	# 좌표는 그림(art/collision_author.py)에 맞춘 값: 남쪽 넓은 백사장이 싸움터, 서쪽 모래띠로 올라가면 해안 마을 앞이다.
	"beach": {
		"music": "night", "amb": "waves",
		"name": "개운포",
		"ground": "beach",
		"spawns": {"start": Vector2(150, 384)},
		"props": [
			["boat", 262, 424, null], ["cairn", 172, 411, null], ["netrack", 92, 368, null],
			["lantern", 272, 128, [-34, WARM, 1.1, 1.0]], ["lantern", 326, 128, [-34, WARM, 1.1, 1.0]],
		],
		# 그림 속 마을 창(오두막 등불)에 얹는 빛: [x, y, 색, 세기, 크기]
		"lights": [[232, 101, WARM, 0.8, 0.5], [290, 104, WARM, 0.8, 0.5], [338, 91, WARM, 0.7, 0.45], [196, 96, WARM, 0.6, 0.4]],
		"npcs": [
			["fisherA", "npc_fisher", 470, 437, "어부", "hidden"],
			["fisherB", "npc_villager_f", 448, 443, "아낙", "hidden"],
			["fisherC", "npc_dolsoe", 426, 437, "어부", "hidden"],
			["suryeong", "npc_suryeong", 492, 443, "수령", "hidden"],
		],
		"interact": [["flute", 205, 427, "대나무 피리", "glint"]],
		"crabs": [Vector2(250, 407), Vector2(300, 420), Vector2(180, 400), Vector2(390, 424), Vector2(330, 440)],
		"enemies": [],
		"exits": [],
		# story.gd 가 쓰는 자리: 요괴가 올라오는 곳, 싸움 시작 구역
		"anchors": {"yokai": Vector2(380, 405), "fight": Rect2(300, 360, 120, 88), "fight_player": Vector2(340, 424)},
	},
	# 경주 변두리 (서라벌 외곽) — SC1-08~11
	# 그림(우물 광장·기와집·돌담·등롱길)에 맞춘 좌표. 서쪽 길 끝 = 폐가로, 북동 관아 문 = 관아로 (gates).
	"gyeongju": {
		"music": "night", "amb": "wind",
		"name": "경주 변두리",
		"ground": "village",
		"time": "dusk",
		"spawns": {"start": Vector2(345, 256), "home": Vector2(140, 245), "fromGwana": Vector2(562, 48), "fromPyega": Vector2(14, 379)},
		"props": [
			["stall", 262, 288, [-20, WARM, 0.7, 0.8]],
			["board", 350, 155, null],
			["jangseung_m", 10, 351, null], ["jangseung_f", 40, 407, null],
			["cairn", 200, 384, null],
			# SC1-21: 소문이 돌자 대문마다 처용탈이 걸린다
			["tal", 546, 40, null, "rumor"], ["tal", 578, 40, null, "rumor"], ["tal", 140, 227, null, "rumor"], ["tal", 484, 67, null, "rumor"],
		],
		# 그림 속 등롱·창에 얹는 빛: [x, y, 색, 세기, 크기]
		"lights": [[97, 293, WARM, 0.9, 0.55], [283, 315, WARM, 1.0, 0.6], [402, 189, WARM, 1.0, 0.6], [322, 155, WARM, 0.9, 0.5],
			[491, 109, WARM, 0.9, 0.5], [545, 69, WARM, 0.9, 0.5], [497, 33, WARM, 0.7, 0.45],
			[235, 157, WARM, 0.6, 0.4], [300, 120, WARM, 0.6, 0.4], [440, 29, WARM, 0.6, 0.4], [480, 340, WARM, 0.5, 0.4], [590, 73, WARM, 0.6, 0.4], [100, 160, WARM, 0.6, 0.4]],
		"npcs": [
			["nanyeong", "npc_nanyeong", 220, 314, "난영"],
			["apothecary", "npc_seokgu", 304, 281, "약방 주인"],
			["elder", "npc_elder", 385, 173, "노인"],
			["villagerA", "npc_villager_f", 318, 213, "마을 아낙"],
			["villagerB", "npc_dolsoe", 448, 157, "나무꾼"],
			["villagerC", "npc_sick", 170, 360, "기침하는 사내"],
			["child", "npc_child", 240, 376, "아이", "hidden"],
			["official", "npc_official", 520, 48, "관아 사람", "hidden"],
		],
		"interact": [["board", 350, 155, "의뢰 게시판"], ["home", 130, 237, "처용의 집"]],
		"enemies": [],
		"exits": [],
		# 이야기가 열어 주는 출구 (story.gd 가 해당 플래그가 서면 level._exit(def.gates[이름]) 로 연다): [Rect2, 목적지, 스폰]
		"gates": {"pyega": [Rect2(0, 355, 6, 48), "pyega1", "start"], "gwana": [Rect2(550, 19, 24, 19), "gwana", "start"]},
		"anchors": {"home_nanyeong": Vector2(104, 247), "gwana_gate": Vector2(562, 27)},
		"wisps": Vector2(230, 360),
	},
	# ===== 2장 「도깨비골」 (design/levels/ch2-dokkaebigol.md) — 마일스톤 1: hwagae + jiri_path =====
	# 지형: 아트팀 전용 땅그림(hwagae 800×400 / jiri 1120×400, 브랜치 asset/ch2-m1). 좌표는 그 그림 기준 footprint
	# (production/qa/asset-import/ch2-m1/README.md §3~4). 필요한 에셋은 production/qa/ch2-asset-needs.md.
	# 화개 저자 — SC2-01~03 (도입). 이번 마일스톤의 동쪽 출구는 gates.path (SC2-03 후 story.gd 가 연다).
	"hwagae": {
		"music": "night", "amb": "wind",
		"name": "화개 저자",
		"ground": "hwagae",
		"time": "dusk",
		"spawns": {"start": Vector2(312, 342), "fromPath": Vector2(706, 14), "fromBoss": Vector2(360, 320)},
		# 등롱 8개·기와집은 그림에 이미 그려져 있어 소품으로 얹지 않는다(이중 표시 방지). burnt_stall 2개는 털린 좌판 자리(좌판 3·4 대신).
		"props": [
			["stall", 300, 296, [-20, WARM, 0.7, 0.8]], ["stall", 500, 190, null],
			["tent", 252, 352, null], ["tent", 420, 347, null],
			["burnt_stall", 345, 296, null], ["burnt_stall", 390, 290, null],
			["board", 430, 230, null],
		],
		# 그림에 그려진 등롱 위치 (x, fy)
		"lights": [[122, 329, WARM, 0.9, 0.55], [400, 157, WARM, 1.0, 0.6], [533, 68, WARM, 0.9, 0.5], [619, 8, WARM, 0.9, 0.5],
			[673, 45, WARM, 0.9, 0.5], [617, 103, WARM, 0.9, 0.5], [500, 209, WARM, 0.9, 0.5], [362, 360, WARM, 0.7, 0.45]],
		"npcs": [
			["sangin", "npc_dolsoe", 330, 330, "장사치"],
			["jumo", "npc_villager_f", 190, 262, "주모"],
			["victim", "npc_sick", 290, 335, "털린 짐꾼"],
			["elder", "npc_elder", 580, 120, "노인", "hidden"],
		],
		"interact": [["board", 430, 230, "의뢰 게시판"]],
		"enemies": [],
		"exits": [],
		"gates": {"path": [Rect2(690, 2, 32, 14), "jiri_path", "fromHwagae"]},
		# raid: SC2-02 습격 무대(트리거) · raiders: 난입한 외눈박이 자리 · exit: 열린 출구 안쪽(용패 길잡이)
		"anchors": {"raid": Rect2(380, 285, 70, 30), "raiders": [Vector2(330, 320), Vector2(390, 300)], "exit": Vector2(706, 9)},
	},
	# 지리산 산길 — 산군·불도깨비·장승(SC2-15)·산신각(SC2-16). 서(화개)·북(버려진 마을, M2)·동(소굴 외곽, M2) 출구. 북 출구 도착점(fromVillage)이 장승 어그로 안이라
	# 장승·산군을 동쪽 숲 마당으로 옮겼다(M2): 모든 스폰·SC2-15 트리거가 요괴 어그로(130, lift 좌표) 밖.
	# 그림에 거송·숲·산신각·제상이 이미 있어 pine·seonang·산신각 소품은 얹지 않는다. 길목(x538~625) 폭 약 64.
	"jiri_path": {
		"music": "dread", "amb": "wind",
		"name": "지리산 산길",
		"ground": "jiri",
		"ambient": Color(0.40, 0.44, 0.60),
		"spawns": {"fromHwagae": Vector2(24, 205), "start": Vector2(24, 205), "fromVillage": Vector2(656, 46), "fromDen": Vector2(1088, 100)},
		"props": [["rockwall", 532, 152, null], ["rockwall", 580, 152, null], ["rockwall", 556, 310, null], ["rockwall", 604, 310, null], ["cairn", 430, 240, null]],
		"lights": [],
		"npcs": [["sansin", "npc_sansin", 250, 175, "산신령"]],
		"interact": [["shrine", 258, 158, "산신각"]],
		# 산군 3(의뢰 A 「길목의 범」 대상은 산군) · 불도깨비 2 · 길목 직후 단독 장승 1 (jangseung_taki 트리거 = SC2-15). 도착 후 x≈430 까지 적 없음(산신각 150px+, 어그로 130).
		"enemies": [["sangun", 440, 192], ["dokkaebi_fire", 580, 215], ["jangseung_taki", 885, 118], ["sangun", 950, 262], ["sangun", 940, 185], ["dokkaebi_fire", 900, 215]],
		# SC2-15 장승 첫 접촉: 트리거는 장승·산군·불도깨비 모두에서 어그로 130 밖(≥140, 화면엔 장승이 보이는 거리)이어야 한다 — 연출 전 전투 확정 금지
		"triggers": [[Rect2(712, 96, 30, 32), "jangseung"]],
		"exits": [[Rect2(0, 181, 6, 50), "hwagae", "fromPath"], [Rect2(620, 0, 76, 20), "old_village", "fromPath"], [Rect2(1106, 64, 14, 64), "den1", "start"]],
		"anchors": {"exit": Vector2(14, 205)},
	},
	# ===== 2장 마일스톤 2: old_village · den1 · den2 · den3 (설계서 §4.3~4.6). 전용 땅그림이 아직 없어 기존 지형으로 폴백 — production/qa/ch2-m2-asset-needs.md.
	# 좌표는 폴백 지형(걸을 수 있는 자리, tests/art_walk.sh)에 맞춘 값이고, 스폰·연출 트리거는 모든 요괴에서 어그로 130(lift 좌표) 이상 떨어져 있다.
	# 버려진 마을 — 폴백 지형 village(1장 경주 변두리 땅그림). 서쪽 어귀(무덤)·우물 둘레·북동 끝. SC2-17~20(의뢰 B).
	"old_village": {
		"music": "dread", "amb": "wind",
		"name": "버려진 마을",
		"ground": "village",
		"ambient": Color(0.30, 0.31, 0.46),
		"spawns": {"start": Vector2(26, 382), "fromPath": Vector2(26, 382)},
		"props": [["jars", 205, 318, null], ["jars", 168, 262, null], ["cairn", 96, 392, null]],
		"lights": [[135, 232, GHOSTFIRE, 0.5, 0.5], [160, 340, GHOSTFIRE, 0.5, 0.55], [520, 90, GHOSTFIRE, 0.45, 0.5]],
		"npcs": [["girl_soul", "npc_ghost", 150, 336, "빈집의 넋"]],
		# doll(짚인형, 의뢰 B)은 girl_soul 사연을 들은 뒤 story.gd 가 add_interact 로 켠다. grave = 마을 어귀 무덤
		"interact": [["grave", 96, 380, "무덤"]],
		# 불도깨비 3 · 외눈박이 1. 폴백 지형엔 우회로가 없어 요괴를 피해 갈 수는 없지만, 사연·인형·무덤은 서쪽 절반(요괴 어그로 밖)에 둬서 전투 없이 의뢰를 끝낼 수 있다.
		"enemies": [["dokkaebi_fire", 360, 225], ["dokkaebi_fire", 425, 175], ["dokkaebi_fire", 480, 112], ["dokkaebi_oneeye", 535, 60]],
		"exits": [[Rect2(0, 355, 6, 48), "jiri_path", "fromVillage"]],
		"anchors": {"doll": Vector2(126, 250), "grave": Vector2(96, 380), "exit": Vector2(14, 380)},
	},
	# 도깨비 소굴 외곽 — 폴백 지형 pyega1(1장 폐가 마당). 서쪽 입구 홀(A) → 아래 긴 복도 → 동쪽 안쪽(C), 위쪽 곁방(B·샛길). SC2-04·05.
	"den1": {
		"music": "dread", "amb": "wind",
		"name": "도깨비 소굴 외곽",
		"ground": "pyega1",
		"ambient": Color(0.27, 0.28, 0.44),
		"spawns": {"start": Vector2(26, 410), "fromDen2": Vector2(556, 386)},
		"props": [["pillar", 130, 424, null], ["pillar", 190, 290, null], ["pillar", 290, 360, null], ["pillar", 365, 385, null], ["pillar", 470, 436, null], ["pillar", 520, 392, null],
			["jars", 60, 300, null], ["jars", 90, 308, null], ["jars", 175, 255, null], ["jars", 560, 424, null]],
		"lights": [[146, 200, GHOSTFIRE, 0.7, 0.5], [300, 267, GHOSTFIRE, 0.5, 0.5], [470, 400, GHOSTFIRE, 0.45, 0.5], [60, 400, GHOSTFIRE, 0.4, 0.5]],
		"npcs": [],
		"interact": [],
		# A 학습용 외눈박이 1(SC2-05) · B 외눈박이·불도깨비 2 · 샛길 외눈박이 · C 산군 + 단독 장승 (일반 6 + 장승 1 = 7)
		"enemies": [["dokkaebi_oneeye", 250, 415], ["dokkaebi_oneeye", 225, 262], ["dokkaebi_fire", 235, 318], ["dokkaebi_fire", 330, 405], ["dokkaebi_oneeye", 146, 222],
			["sangun", 395, 432], ["jangseung_taki", 312, 332]],
		"vents": [Vector2(250, 300), Vector2(330, 420), Vector2(490, 410)],
		"triggers": [[Rect2(62, 400, 36, 40), "sight"], [Rect2(540, 372, 28, 24), "deep"]],
		"exits": [[Rect2(0, 368, 6, 50), "jiri_path", "fromDen"], [Rect2(574, 366, 16, 30), "den2", "start"]],
		"anchors": {"exit": Vector2(584, 382)},
	},
	# 도깨비 곳간(정예 관문) — 폴백 지형 gwana(1장 관아 마당). 남서 입구 → 마당 → 북동 문(장산범 정화 전엔 막힘). SC2-21.
	"den2": {
		"music": "dread", "amb": "wind",
		"name": "도깨비 곳간",
		"ground": "gwana",
		"ambient": Color(0.30, 0.30, 0.46),
		"spawns": {"start": Vector2(95, 395), "fromDen3": Vector2(490, 64)},
		"props": [["pillar", 250, 252, null], ["pillar", 330, 255, null], ["pillar", 385, 195, null], ["pillar", 372, 150, null], ["jars", 240, 300, null], ["jars", 300, 300, null], ["beam", 140, 340, null]],
		"lights": [[200, 204, GHOSTFIRE, 0.7, 0.5], [343, 100, GHOSTFIRE, 0.6, 0.5], [496, 80, GHOSTFIRE, 0.5, 0.5], [148, 416, GHOSTFIRE, 0.4, 0.5]],
		"npcs": [],
		"interact": [],
		"enemies": [["jangsanbeom", 272, 228], ["dokkaebi_oneeye", 235, 282], ["dokkaebi_oneeye", 358, 185], ["dokkaebi_fire", 385, 235]],
		"exits": [[Rect2(50, 400, 100, 19), "den1", "fromDen2"], [Rect2(450, 36, 80, 12), "den3", "start"]],
		# door: 동쪽 문 앞을 막는 막(정예 정화 전). 열림 = den2_gate_cleared
		"anchors": {"door": Rect2(430, 66, 110, 12), "exit": Vector2(490, 44)},
	},
	# 두억시니의 방 — 폴백 지형 pyega2(1장 역신의 방: 보스 실루엣이 그림에 있다). M2 는 입장 연출(SC2-06·07)까지, 전투는 다음 마일스톤.
	"den3": {
		"music": "dread", "amb": "",
		"name": "두억시니의 방",
		"ground": "pyega2",
		"ambient": Color(0.3, 0.29, 0.44),
		"spawns": {"start": Vector2(284, 395)},
		"props": [["pillar", 360, 150, null], ["pillar", 600, 150, null], ["pillar", 360, 236, null], ["pillar", 600, 236, null], ["altar", 480, 190, [-20, CANDLE, 1.1, 1.3]],
			["jars", 300, 150, null], ["jars", 700, 235, null]],
		"lights": [[400, 160, GHOSTFIRE, 0.6, 0.8], [282, 309, GHOSTFIRE, 0.5, 0.5], [640, 187, CANDLE, 0.5, 0.7]],
		"npcs": [],
		"interact": [],
		"enemies": [],
		"triggers": [[Rect2(262, 296, 46, 24), "gate"]],
		"exits": [[Rect2(262, 410, 46, 12), "den2", "fromDen3"]],
		# door: 입장 뒤 입구 복도를 닫는 막 · hall: 두억시니가 설 홀 중앙(M3)
		"anchors": {"door": Rect2(262, 344, 46, 12), "hall": Vector2(480, 190), "exit": Vector2(284, 416)},
	},
}
