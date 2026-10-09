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
	# 경주 관아 — SC1-12 의뢰
	"gwana": {
		"music": "night", "amb": "wind",
		"name": "경주 관아",
		"ground": "gwana",
		"spawns": {"start": Vector2(24, 232)},
		"props": [
			["hall", 320, 128, null],
			["lantern", 262, 176, [-34, WARM, 1.2, 1.1]], ["lantern", 378, 176, [-34, WARM, 1.2, 1.1]],
			["lantern", 120, 300, [-34, WARM, 1.0, 1.0]], ["lantern", 520, 300, [-34, WARM, 1.0, 1.0]],
			["board", 480, 214, null],
			["dodam", 80, 372, null], ["dodam", 560, 372, null], ["dodam", 160, 372, null], ["dodam", 480, 372, null],
			["pine", 40, 120, null], ["pine", 610, 110, null], ["pine", 600, 260, null],
		],
		"npcs": [
			["gwanri", "npc_official", 320, 196, "형방 박문"],
			["guardA", "npc_official", 250, 200, "포졸"],
			["guardB", "npc_official", 390, 200, "포졸"],
			["runner", "npc_fisher", 24, 232, "약방 일꾼", "hidden"],
		],
		"interact": [],
		"enemies": [],
		"exits": [[Rect2(0, 200, 6, 70), "gyeongju", "fromGwana"]],
	},
	# 서쪽 폐가 — 마당과 안채 (SC1-13)
	"pyega1": {
		"music": "dread", "amb": "wind",
		"name": "서쪽 폐가",
		"ground": "pyega1",
		"ambient": Color(0.26, 0.28, 0.44),
		"spawns": {"start": Vector2(22, 220), "fromUp": Vector2(320, 100)},
		"props": [
			["seonang", 96, 340, [-60, GHOSTFIRE, 0.6, 1.4]],
			["jars", 168, 66, null], ["beam", 430, 92, null], ["jars", 560, 300, null],
			["beam", 120, 250, null], ["cairn", 470, 248, null], ["jars", 260, 360, null],
		],
		"npcs": [],
		"interact": [],
		# SC1-13: 무너진 마당 — 역병 들개·역귀, 우물엔 물귀신, 서낭나무 아래 처녀귀신
		"enemies": [["dog", 200, 310], ["ghoul", 340, 262], ["dog", 420, 210], ["ghoul", 250, 90],
			["mulgwi", 488, 312], ["maiden_ghost", 140, 300]],
		"exits": [[Rect2(0, 196, 6, 56), "gyeongju", "fromPyega"], [Rect2(296, 34, 48, 10), "pyega2", "start"]],
		"wisps": Vector2(320, 70),
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
	"beach": {
		"music": "night", "amb": "waves",
		"name": "개운포",
		"ground": "beach",
		"spawns": {"start": Vector2(100, 262)},
		"props": [
			["house", 100, 112, [-6, WARM, 1.0, 0.9]],
			["house", 548, 112, [-6, WARM, 0.9, 0.9]],
			["lantern", 232, 120, [-34, WARM, 1.2, 1.0]],
			["lantern", 430, 120, [-34, WARM, 1.2, 1.0]],
			["netrack", 250, 70, null], ["netrack", 440, 66, null],
			["jangseung_m", 304, 124, null], ["jangseung_f", 368, 124, null],
			["sotdae", 600, 150, null], ["sotdae_s", 614, 146, null],
			["boat", 440, 246, null], ["boat", 176, 196, null],
			["cairn", 566, 232, null],
			["pine", 22, 70, null], ["pine", 40, 110, null], ["pine", 616, 36, null], ["pine", 170, 36, null],
		],
		"npcs": [
			["fisherA", "npc_fisher", 286, 98, "어부", "hidden"],
			["fisherB", "npc_villager_f", 398, 102, "아낙", "hidden"],
			["fisherC", "npc_dolsoe", 470, 104, "어부", "hidden"],
			["suryeong", "npc_suryeong", 630, 100, "수령", "hidden"],
		],
		"interact": [["flute", 184, 270, "대나무 피리", "glint"]],
		"crabs": [Vector2(240, 252), Vector2(290, 230), Vector2(420, 266), Vector2(140, 222), Vector2(520, 256)],
		"enemies": [],
		"exits": [],
	},
	# 경주 변두리 (서라벌 외곽) — SC1-08~11
	"gyeongju": {
		"music": "night", "amb": "wind",
		"name": "경주 변두리",
		"ground": "village",
		"time": "dusk",
		"spawns": {"start": Vector2(330, 196), "home": Vector2(168, 172), "fromGwana": Vector2(600, 180), "fromPyega": Vector2(26, 180)},
		"props": [
			["house", 72, 108, [-6, WARM, 1.1, 0.9]],
			["lantern", 160, 100, [-34, WARM, 1.2, 1.0]],
			["house", 560, 300, [-6, WARM, 1.0, 0.9]],
			["lantern", 282, 138, [-34, WARM, 1.3, 1.1]],
			["lantern", 424, 226, [-34, WARM, 0.85, 1.0]],
			["board", 300, 150, null],
			["stall", 476, 196, [-20, WARM, 0.7, 0.8]],
			["jangseung_m", 618, 154, null], ["jangseung_f", 618, 204, null],
			["dodam", 470, 250, null], ["dodam", 400, 250, null],
			["geumjul", 320, 330, null],
			["seonang", 470, 330, [-60, GHOSTFIRE, 0.7, 1.5]],
			["cairn", 432, 344, null],
			["sotdae", 580, 40, null], ["sotdae_s", 594, 36, null], ["sotdae", 608, 42, null],
			# SC1-21: 소문이 돌자 대문마다 처용탈이 걸린다
			["tal", 132, 116, null, "rumor"], ["tal", 506, 304, null, "rumor"], ["tal", 400, 236, null, "rumor"], ["tal", 250, 290, null, "rumor"],
			["pine", 18, 60, null], ["pine", 236, 30, null], ["pine", 630, 60, null], ["pine", 520, 26, null],
			["pine", 60, 340, null], ["pine", 630, 350, null], ["pine", 380, 356, null], ["pine", 220, 300, null],
		],
		"npcs": [
			["nanyeong", "npc_nanyeong", 456, 214, "난영"],
			["apothecary", "npc_seokgu", 498, 210, "약방 주인"],
			["elder", "npc_elder", 360, 168, "노인"],
			["villagerA", "npc_villager_f", 250, 132, "마을 아낙"],
			["villagerB", "npc_dolsoe", 560, 196, "나무꾼"],
			["villagerC", "npc_sick", 230, 290, "기침하는 사내"],
			["child", "npc_child", 330, 350, "아이", "hidden"],
			["official", "npc_official", 630, 186, "관아 사람", "hidden"],
		],
		"interact": [["board", 300, 156, "의뢰 게시판"], ["home", 96, 124, "처용의 집"]],
		"enemies": [],
		"exits": [],
		"wisps": Vector2(470, 290),
	},
}
