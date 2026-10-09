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
	# 경주 변두리 (서라벌 외곽) — SC1-08~11
	"gyeongju": {
		"name": "경주 변두리",
		"ground": "village",
		"spawns": {"start": Vector2(330, 196), "home": Vector2(168, 172), "fromWest": Vector2(606, 178)},
		"props": [
			["house", 72, 108, [-6, WARM, 1.1, 0.9]],
			["lantern", 160, 100, [-34, WARM, 1.2, 1.0]],
			["house", 560, 300, [-6, WARM, 1.0, 0.9]],
			["lantern", 282, 138, [-34, WARM, 1.3, 1.1]],
			["lantern", 440, 214, [-34, WARM, 1.3, 1.1]],
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
		],
		"interact": [["board", 300, 156, "의뢰 게시판"]],
		"enemies": [],
		"exits": [],
		"wisps": Vector2(470, 290),
	},
}
