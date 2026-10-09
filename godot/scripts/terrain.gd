class_name Terrain
extends Node2D
## Dual-grid terrain: the map is a grid of *vertices* (one char each); every 16px cell picks its tile
## from its four corners. Layers stack water → dirt (banks) → stone → grass, each from its own atlas
## (row = corner mask, column = 16px window of a 128px texture) written by art/tiles.py.

const TS := 16
const WIN := 8 # texture windows per side (128px textures)
const LAYERS := ["water", "dirt", "stone", "grass"]
## vertex char → which layers are "inside" at that vertex
const KEYS := {
	"~": ["water"],
	".": ["water", "dirt"],
	"#": ["water", "dirt", "stone"],
	",": ["water", "dirt", "grass"],
}

var layers := {}


func build(rows: PackedStringArray) -> void:
	for l in LAYERS:
		var tm := TileMapLayer.new()
		tm.name = l.capitalize()
		tm.tile_set = _tileset(l)
		tm.z_index = -20 + LAYERS.find(l)
		add_child(tm)
		layers[l] = tm
	var h := rows.size() - 1
	var w := rows[0].length() - 1
	for cy in h:
		for cx in w:
			var corners := [rows[cy][cx], rows[cy][cx + 1], rows[cy + 1][cx], rows[cy + 1][cx + 1]]
			var window := (cx % WIN) + (cy % WIN) * WIN
			for l in LAYERS:
				var mask := 0
				for i in 4:
					if l in KEYS.get(corners[i], ["water", "dirt"]):
						mask |= 1 << i
				if mask != 0 or l == "water":
					layers[l].set_cell(Vector2i(cx, cy), 0, Vector2i(window, mask if l != "water" else 15))


static var _cache := {}


static func _tileset(layer: String) -> TileSet:
	if _cache.has(layer):
		return _cache[layer]
	var ts := TileSet.new()
	ts.tile_size = Vector2i(TS, TS)
	var src := TileSetAtlasSource.new()
	src.texture = load("res://assets/tiles/%s.png" % layer)
	src.texture_region_size = Vector2i(TS, TS)
	for y in 16:
		for x in WIN * WIN:
			src.create_tile(Vector2i(x, y))
	ts.add_source(src, 0)
	_cache[layer] = ts
	return ts
