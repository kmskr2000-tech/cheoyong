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
	# 월성 편전 — SC1-22~23 왕의 부름과 퇴마어사 임명
	"palace": {
		"music": "title", "amb": "",
		"name": "월성 편전",
		"ground": "palace",
		"ambient": Color(0.3, 0.29, 0.42),
		"spawns": {"start": Vector2(256, 318)},
		"props": [
			["irworobong", 256, 58, null],
			["chotdae", 196, 100, [-38, WARM, 1.1, 0.9]], ["chotdae", 316, 100, [-38, WARM, 1.1, 0.9]],
			["pillar", 80, 150, null], ["pillar", 432, 150, null], ["pillar", 80, 290, null], ["pillar", 432, 290, null],
			["chotdae", 120, 220, [-38, WARM, 0.9, 0.9]], ["chotdae", 392, 220, [-38, WARM, 0.9, 0.9]],
		],
		"npcs": [["king", "npc_king", 256, 92, "왕"]],
		"interact": [],
		"enemies": [],
		"triggers": [[Rect2(150, 176, 212, 40), "audience"]],
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
		"enemies": [["dog", 190, 360], ["ghoul", 300, 317], ["dog", 420, 387], ["ghoul", 230, 280],
			["mulgwi", 520, 387], ["maiden_ghost", 100, 400]],
		"exits": [[Rect2(0, 360, 6, 53), "gyeongju", "fromPyega"], [Rect2(130, 187, 30, 20), "pyega2", "start"]],
		"wisps": Vector2(146, 200),
	},
	# 서쪽 폐가 — 다락과 최심부 (SC1-14~20)
	"pyega2": {
		"music": "dread", "amb": "",
		"name": "폐가 다락",
		"ground": "pyega2",
		"ambient": Color(0.3, 0.29, 0.44),
		"wisps": Vector2(610, 220),
		"spawns": {"start": Vector2(70, 200)},
		"props": [
			["jars", 60, 70, null], ["beam", 140, 300, null], ["jars", 350, 318, null], ["beam", 300, 64, null],
			["altar", 690, 86, [-20, CANDLE, 1.1, 1.3]],
			["jars", 740, 330, null],
		],
		"npcs": [["soul", "npc_nanyeong", 690, 132, "난영의 넋"]],
		"interact": [],
		# SC1-14: 다락 — 어둠 속 달걀귀신, 울음 우는 처녀귀신, 최심부 문 앞을 지키는 정예 마마귀신
		"enemies": [["ghoul", 150, 150], ["egg_ghost", 160, 300], ["dog", 330, 200], ["maiden_ghost", 300, 110],
			["egg_ghost", 340, 300], ["mama", 452, 200]],
		"vents": [Vector2(290, 110), Vector2(300, 290), Vector2(230, 210), Vector2(430, 120), Vector2(440, 300), Vector2(470, 210)],
		"triggers": [[Rect2(400, 48, 40, 290), "close"], [Rect2(530, 48, 30, 330), "inner"]],
		"exits": [[Rect2(0, 60, 6, 270), "pyega1", "fromUp"]],
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
