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
		"anchors": {"boss": Vector2(640, 220), "door": Rect2(536, 109, 12, 152), "door_x": 536.0, "kicked": Vector2(518, 213), "boss_goal": Vector2(600, 213)},
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
			["jangseung_m", 14, 355, null], ["jangseung_f", 14, 403, null],
			["cairn", 200, 384, null],
			# SC1-21: 소문이 돌자 대문마다 처용탈이 걸린다
			["tal", 546, 40, null, "rumor"], ["tal", 578, 40, null, "rumor"], ["tal", 140, 227, null, "rumor"], ["tal", 484, 67, null, "rumor"],
		],
		# 그림 속 등롱·창에 얹는 빛: [x, y, 색, 세기, 크기]
		"lights": [[97, 293, WARM, 0.9, 0.55], [283, 315, WARM, 1.0, 0.6], [402, 189, WARM, 1.0, 0.6], [322, 155, WARM, 0.9, 0.5],
			[491, 109, WARM, 0.9, 0.5], [545, 69, WARM, 0.9, 0.5], [497, 33, WARM, 0.7, 0.45],
			[235, 157, WARM, 0.6, 0.4], [300, 120, WARM, 0.6, 0.4], [440, 29, WARM, 0.6, 0.4], [480, 340, WARM, 0.5, 0.4], [590, 73, WARM, 0.6, 0.4], [100, 160, WARM, 0.6, 0.4]],
		"npcs": [
			["nanyeong", "npc_nanyeong", 236, 309, "난영"],
			["apothecary", "npc_seokgu", 292, 277, "약방 주인"],
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
		"anchors": {"home_nanyeong": Vector2(118, 243), "gwana_gate": Vector2(562, 27)},
		"wisps": Vector2(230, 360),
	},
}
