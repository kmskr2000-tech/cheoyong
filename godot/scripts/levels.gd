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

const DATA := {
	# 개운포 — 백사장과 해안 마을 (SC1-01~07). 처용이 바다에서 뭍으로 올라오는 곳.
	"beach": {
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
		"name": "경주 변두리",
		"ground": "village",
		"time": "dusk",
		"spawns": {"start": Vector2(330, 196), "home": Vector2(168, 172), "fromWest": Vector2(606, 178)},
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
