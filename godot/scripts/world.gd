# World: terrain generation (Wang corner tiles), zones, roads, gates, props and the 16px collision grid.
class_name World
extends RefCounted

const T := 32
const W := 120
const H := 90
enum { SEA, SAND, GRASS, PATH, PLAZA, FOREST, POND, RUIN, YARD }
# tileset per terrain pair: [set, lower, upper]
const PAIRS := {
	"0-1": ["sea_sand", 0, 1], "1-2": ["sand_grass", 1, 2], "2-3": ["grass_path", 2, 3],
	"2-4": ["grass_plaza", 2, 4], "2-5": ["grass_forest", 2, 5], "2-6": ["grass_pond", 6, 2],
	"2-7": ["grass_ruin", 2, 7], "2-8": ["grass_yard", 2, 8],
}
const HOME := {0: "0-1", 1: "1-2", 2: "1-2", 3: "2-3", 4: "2-4", 5: "2-5", 6: "2-6", 7: "2-7", 8: "2-8"}

var ZONES = [
	{"id": "beach", "name": "개운포", "x0": 80, "y0": 54, "x1": 118, "y1": 88, "music": "sea", "amb": "sea"},
	{"id": "town", "name": "서라벌 저잣거리", "x0": 42, "y0": 34, "x1": 77, "y1": 66, "music": "town", "amb": "wind"},
	{"id": "ruin", "name": "폐허 우물터", "x0": 85, "y0": 5, "x1": 117, "y1": 38, "music": "eerie", "amb": "wind"},
	{"id": "pond", "name": "연못 절터", "x0": 42, "y0": 4, "x1": 80, "y1": 28, "music": "eerie", "amb": "wind"},
	{"id": "forest", "name": "여우숲", "x0": 4, "y0": 42, "x1": 38, "y1": 86, "music": "eerie", "amb": "wind"},
	{"id": "house", "name": "처용의 집", "x0": 5, "y0": 5, "x1": 34, "y1": 34, "music": "eerie", "amb": "wind"},
]
var ROADS = [
	{"pts": [[100, 70], [88, 71], [76, 70], [68, 68], [66, 64]], "w": 2.2},
	{"pts": [[66, 64], [64, 56], [61, 50]], "w": 1.6, "plaza": true},
	{"pts": [[61, 40], [61, 28], [61, 22]], "w": 1.8},
	{"pts": [[72, 46], [80, 44], [86, 38], [92, 32], [100, 26]], "w": 1.8},
	{"pts": [[50, 54], [40, 56], [32, 58], [22, 66], [18, 72]], "w": 1.8},
	{"pts": [[48, 40], [40, 34], [30, 30], [22, 28]], "w": 1.8},
]
var GATES = [
	{"id": "south", "x0": 61.5, "y0": 65, "x1": 70.5, "y1": 68.5, "flag": "gate_open"},
	{"id": "ruin", "x0": 81, "y0": 39, "x1": 86, "y1": 46, "flag": "paths_open"},
	{"id": "pond", "x0": 58, "y0": 29, "x1": 64, "y1": 33, "flag": "paths_open"},
	{"id": "forest", "x0": 37, "y0": 50.5, "x1": 41.5, "y1": 61.5, "flag": "paths_open"},
	{"id": "house", "x0": 34, "y0": 26, "x1": 39, "y1": 37.5, "flag": "house_open"},
]
# footprint [x, y, w, h] relative to the bottom-centre anchor; light [ox, oy, radius, color, strength]
const KINDS := {
	"pine": {"foot": [-10, -10, 20, 12], "shadow": 26}, "pine2": {"foot": [-10, -10, 20, 12], "shadow": 26},
	"deadtree": {"foot": [-9, -10, 18, 12], "shadow": 22}, "bush": {"foot": [-12, -8, 24, 10], "shadow": 14},
	"rock": {"foot": [-18, -14, 36, 16], "shadow": 18}, "reeds": {"shadow": 0},
	"giwa": {"foot": [-86, -70, 172, 66], "shadow": 90}, "choga": {"foot": [-70, -54, 140, 50], "shadow": 74},
	"stall": {"foot": [-50, -36, 100, 32], "shadow": 50}, "well": {"foot": [-28, -26, 56, 26], "shadow": 30},
	"brokenwell": {"foot": [-30, -26, 60, 24], "shadow": 32, "light": [0, -30, 90, "8a4cff", 0.5]},
	"pagoda": {"foot": [-28, -28, 56, 26], "shadow": 34}, "pavilion": {"foot": [-66, -50, 132, 18], "shadow": 70},
	"lantern": {"foot": [-12, -12, 24, 12], "shadow": 12, "light": [0, -40, 150, "ffb35a", 0.95]},
	"jangseung": {"foot": [-24, -12, 48, 12], "shadow": 22}, "wall": {"foot": [-64, -22, 128, 20], "shadow": 0},
	"ruinwall": {"foot": [-52, -20, 104, 18], "shadow": 0}, "gate": {"shadow": 0},
	"boat": {"foot": [-48, -28, 96, 26], "shadow": 40},
	"lamppost": {"foot": [-6, -8, 12, 8], "shadow": 8, "light": [0, -70, 170, "ff8a4a", 0.9]},
	"jars": {"foot": [-28, -22, 56, 20], "shadow": 26}, "shrine": {"foot": [-50, -50, 100, 46], "shadow": 50, "light": [0, -40, 120, "7fd0ff", 0.6]},
	"cheoyonghouse": {"foot": [-118, -90, 236, 86], "shadow": 120, "light": [-60, -40, 160, "ffb35a", 0.7]},
	"palanquin": {"foot": [-48, -30, 96, 28], "shadow": 46}, "altar": {"foot": [-26, -18, 52, 16], "shadow": 20, "light": [0, -20, 110, "7fd0ff", 0.7]},
	"lotus": {"shadow": 0, "flat": true}, "cart": {"foot": [-40, -26, 80, 24], "shadow": 36},
	"bones": {"shadow": 0, "flat": true},
	"cave": {"light": [0, -20, 140, "8a4cff", 0.7]}, "maae": {"light": [0, -30, 110, "ffd28a", 0.4]},
	"stonebuddha": {"light": [0, -30, 90, "ffd28a", 0.35]}, "palace": {"light": [0, -40, 200, "ffb35a", 0.6]},
	"tuft": {"shadow": 0}, "tuft2": {"shadow": 0}, "flowers": {"shadow": 0, "flat": true}, "pebbles": {"shadow": 0, "flat": true},
}

var V = PackedByteArray()
var cells = []          # per cell: {set, idx, flip, t: [nw, ne, sw, se], full}
var solid = PackedByteArray()
var walkable = PackedByteArray()
var cell_zone = []
var props = []
var flags = {}          # shared with the game (gates read it)
var pw = W * T
var ph = H * T
var map_id := "seorabeol"
var spec := {}          # data of a chapter map (maps.gd); empty for 서라벌

func init() -> void:
	if map_id != "seorabeol":
		spec = Maps.get_spec(map_id)
		ZONES = spec.zones; ROADS = spec.get("roads", []); GATES = spec.get("gates", [])
		_paint_spec()
	else: _paint()
	_build_cells()
	_build_walk()
	if spec: _place_props_spec()
	else: _place_props()
	for p in props:
		p.k = KINDS.get(p.kind, {})
		if Buildings.has(p.kind) and not p.kind in ["gate", "palacegate", "poseok"]:
			p.k = p.k.duplicate(); p.k.foot = Buildings.foot(p.kind); p.k.building = true
		if p.k.has("light"):
			var l: Array = p.k.light
			p.light = [l[0], l[1], l[2], Color("#" + l[3]), l[4]]
	_prop_solids()

# ---------- chapter maps from data ----------
# areas: {t, rect: [x0, y0, x1, y1]} or {t, ell: [cx, cy, rx, ry]}, optional noise threshold
func _paint_spec() -> void:
	V.resize((W + 1) * (H + 1)); V.fill(spec.get("base", GRASS))
	for y in H + 1:
		for x in W + 1:
			var t: int = V[vi(x, y)]
			for a in spec.get("areas", []):
				var inside := false
				if a.has("rect"):
					var r: Array = a.rect
					inside = x >= r[0] and x <= r[2] and y >= r[1] and y <= r[3]
				elif a.has("ell"):
					var e: Array = a.ell
					var n0 = (G.fbm(x * 0.15, y * 0.15, 3) - 0.5) * 0.4
					inside = pow((x - e[0]) / e[2], 2) + pow((y - e[1]) / e[3], 2) < 1.0 - n0
				if inside and (not a.has("noise") or G.fbm(x * 0.15, y * 0.15, a.get("seed", 3)) > a.noise): t = a.t
			V[vi(x, y)] = t
	for r in ROADS:
		for y in H + 1:
			for x in W + 1:
				var d = road_dist(x, y, r)
				if d < r.w * 0.55 + G.noise(x * 0.5, y * 0.5, 2) * 0.5:
					var cur = V[vi(x, y)]
					if cur == POND or cur == YARD or cur == PLAZA: continue
					V[vi(x, y)] = PLAZA if r.get("plaza", false) else PATH
	if spec.has("sea"):
		var sea_d: Dictionary = spec.sea
		var sea = PackedByteArray(); sea.resize(V.size())
		for y in H + 1:
			for x in W + 1:
				var n = G.fbm(x * 0.09, y * 0.09, 5) * 6.0
				var s := false
				if sea_d.has("east"): s = s or x >= sea_d.east - n
				if sea_d.has("south"): s = s or y >= sea_d.south - n * 0.6
				if sea_d.has("north"): s = s or y <= sea_d.north + n * 0.6
				if s: sea[vi(x, y)] = 1
		for y in H + 1:
			for x in W + 1:
				if sea[vi(x, y)]: V[vi(x, y)] = SEA; continue
				var near = 99.0
				for dy in range(-6, 7):
					for dx in range(-6, 7):
						var xx = x + dx; var yy = y + dy
						if xx < 0 or yy < 0 or xx > W or yy > H or not sea[vi(xx, yy)]: continue
						near = min(near, Vector2(dx, dy).length())
				if near <= 3.2 + G.fbm(x * 0.12, y * 0.12, 6) * 3.0: V[vi(x, y)] = SAND
	_legalize()

func _place_props_spec() -> void:
	props.clear()
	for p in spec.get("props", []):
		# decorations never sit on a road (they would narrow it to a gap nobody fits through)
		if p[0] in ["jangseung", "rock", "cart", "jars", "bush", "pine", "pine2", "deadtree", "reeds"] and _on_road(int(p[1]), int(p[2] - 0.5)): continue
		_add(p[0], p[1], p[2], p[3] if p.size() > 3 else {})
	var trees: Array = spec.get("trees", ["pine", "pine2"])
	var keep: Array = spec.get("clear", [])  # spots kept free of scattered props [x, y, radius]
	var near_bld := PackedByteArray(); near_bld.resize(W * H)
	for pr in props:
		if not Buildings.has(pr.kind): continue
		var bx := int(pr.x / T); var by := int(pr.y / T)
		for yy in range(by - 6, by + 2):
			for xx in range(bx - 5, bx + 6):
				if xx >= 0 and yy >= 0 and xx < W and yy < H: near_bld[yy * W + xx] = 1
	for y in H:
		for x in W:
			var h = G.hash2(x, y, 31)
			var t: Array = cells[y * W + x].t
			if t.has(SEA) or t.has(POND) or t.has(SAND): continue
			if walkable[y * W + x] == 0:
				if (x + (y % 2)) % 2 == 0 and y % 2 == 0 and _near_walk(x, y, 7):
					var kind: String = trees[int(G.hash2(x, y, 33) * trees.size())]
					_add(kind, x + 0.5 + (h - 0.5) * 0.8, y + 1 + (G.hash2(x, y, 32) - 0.5) * 0.6, {"flip": h > 0.5})
				continue
			var z = cell_zone[y * W + x]
			if z == null or _on_road(x, y): continue
			var free := true
			for q in keep:
				if Vector2(q[0] - x, q[1] - y).length() < q[2]: free = false
			if not free or near_bld[y * W + x]: continue
			var acc := 0.0
			for sc in z.get("scatter", []):
				acc += sc[1]
				if h < acc:
					_add(sc[0], x + 0.5 + (G.hash2(x, y, 56) - 0.5) * 0.6, y + 1, {"flip": G.hash2(x, y, 57) > 0.5})
					break

# ---------- helpers ----------
static func in_rect(x: float, y: float, r: Dictionary, m := 0.0) -> bool:
	return x >= r.x0 - m and x <= r.x1 + m and y >= r.y0 - m and y <= r.y1 + m

static func seg_dist(px: float, py: float, ax: float, ay: float, bx: float, by: float) -> float:
	var dx = bx - ax; var dy = by - ay; var l2 = dx * dx + dy * dy
	var t = clampf(((px - ax) * dx + (py - ay) * dy) / l2, 0.0, 1.0) if l2 > 0 else 0.0
	return Vector2(px - (ax + t * dx), py - (ay + t * dy)).length()

static func road_dist(x: float, y: float, road: Dictionary) -> float:
	var d = 1e9
	var p: Array = road.pts
	for i in p.size() - 1:
		d = min(d, seg_dist(x, y, p[i][0], p[i][1], p[i + 1][0], p[i + 1][1]))
	return d

func vi(x: int, y: int) -> int: return y * (W + 1) + x
func getv(x: int, y: int) -> int: return V[vi(clampi(x, 0, W), clampi(y, 0, H))]
static func pair_key(a: int, b: int) -> String: return "%d-%d" % [min(a, b), max(a, b)]

func _is_sea(x: int, y: int) -> bool:
	var n = G.fbm(x * 0.09, y * 0.09, 5) * 6.0
	if y >= 46 and x >= 111 - n + (-6 if (y > 62 and y < 80) else 0): return true
	if x >= 74 and y >= 85 - n * 0.6: return true
	return false

# ---------- terrain ----------
func _paint() -> void:
	V.resize((W + 1) * (H + 1)); V.fill(GRASS)
	for y in H + 1:
		for x in W + 1:
			var n = G.fbm(x * 0.15, y * 0.15, 3)
			var t = GRASS
			if in_rect(x, y, ZONES[4], 1) and n > 0.28: t = FOREST
			if in_rect(x, y, ZONES[2]) and G.fbm(x * 0.2, y * 0.2, 8) > 0.38: t = RUIN
			if x >= 50 and x <= 73 and y >= 40 and y <= 60: t = PLAZA
			if x >= 9 and x <= 31 and y >= 8 and y <= 29: t = YARD
			if x >= 68 and x <= 77 and y >= 6 and y <= 13: t = PLAZA
			var pe = pow((x - 59) / 10.0, 2) + pow((y - 14) / 5.5, 2)
			if pe < 1.0 - (n - 0.5) * 0.4: t = POND
			V[vi(x, y)] = t
	for r in ROADS:
		for y in H + 1:
			for x in W + 1:
				var d = road_dist(x, y, r)
				if d < r.w * 0.55 + G.noise(x * 0.5, y * 0.5, 2) * 0.5:
					var cur = V[vi(x, y)]
					if cur == POND or cur == YARD or cur == PLAZA: continue
					V[vi(x, y)] = PLAZA if r.get("plaza", false) else PATH
	var sea = PackedByteArray(); sea.resize(V.size())
	for y in H + 1:
		for x in W + 1:
			if _is_sea(x, y): sea[vi(x, y)] = 1
	for y in H + 1:
		for x in W + 1:
			if sea[vi(x, y)]: V[vi(x, y)] = SEA; continue
			var near = 99.0
			for dy in range(-6, 7):
				for dx in range(-6, 7):
					var xx = x + dx; var yy = y + dy
					if xx < 0 or yy < 0 or xx > W or yy > H or not sea[vi(xx, yy)]: continue
					near = min(near, Vector2(dx, dy).length())
			var band = 3.2 + G.fbm(x * 0.12, y * 0.12, 6) * 3.0
			if near <= band and x >= 74: V[vi(x, y)] = SAND
	_legalize()

func _legal_pair(a: int, b: int) -> bool:
	return a == b or PAIRS.has(pair_key(a, b))

func _legalize() -> void:
	for pass_i in 8:
		var changed = 0
		for y in H:
			for x in W:
				var c = [getv(x, y), getv(x + 1, y), getv(x, y + 1), getv(x + 1, y + 1)]
				var st = _uniq(c)
				if st.size() == 1 or (st.size() == 2 and _legal_pair(st[0], st[1])): continue
				var pts = [[x, y], [x + 1, y], [x, y + 1], [x + 1, y + 1]]
				var has_sea = st.has(SEA)
				for i in 4:
					var t: int = c[i]
					if has_sea:
						if t != SEA and t != SAND: V[vi(pts[i][0], pts[i][1])] = SAND; changed += 1
					elif st.has(SAND):
						if t != SAND and t != GRASS: V[vi(pts[i][0], pts[i][1])] = GRASS; changed += 1
					elif t != GRASS:
						var keep = 99
						for s in st:
							if s != GRASS: keep = min(keep, s)
						if t != keep: V[vi(pts[i][0], pts[i][1])] = GRASS; changed += 1
		if changed == 0: break

static func _uniq(a: Array) -> Array:
	var out = []
	for v in a:
		if not out.has(v): out.append(v)
	return out

func _build_cells() -> void:
	cells.resize(W * H)
	for y in H:
		for x in W:
			var c = [getv(x, y), getv(x + 1, y), getv(x, y + 1), getv(x + 1, y + 1)]
			var st = _uniq(c)
			var key: String = HOME[st[0]] if st.size() == 1 else pair_key(st[0], st[1])
			if not PAIRS.has(key): key = HOME[st[0]]
			var pr: Array = PAIRS[key]
			var ts: Dictionary = Assets.tiles.get(pr[0], {})
			var pick = null
			if ts:
				var want = ""
				for t in c: want += "1" if t == pr[2] else "0"
				var cands = ts.by.get(want)
				if cands == null:
					cands = ts.by.get(("1111" if st[0] == pr[2] else "0000") if st.size() == 1 else "0000")
				if cands: pick = cands[int(G.hash2(x, y, 11) * cands.size())]
			var full = st.size() == 1
			cells[y * W + x] = {"set": pr[0], "idx": pick, "flip": full and G.hash2(x, y, 12) < 0.5, "t": c, "full": st[0] if full else -1}

func zone_cell(tx: int, ty: int):
	for z in ZONES:
		if in_rect(tx, ty, z): return z
	return null

func _build_walk() -> void:
	walkable.resize(W * H); cell_zone.resize(W * H)
	for y in H:
		for x in W:
			var ok: bool = zone_cell(x, y) != null
			if not ok:
				for r in ROADS:
					if road_dist(x + 0.5, y + 0.5, r) < r.w + 0.6: ok = true; break
			walkable[y * W + x] = 1 if ok else 0
			cell_zone[y * W + x] = zone_cell(x, y)
	solid.resize(W * 2 * H * 2); solid.fill(0)
	for y in H:
		for x in W:
			var c: Array = cells[y * W + x].t
			var water = 0
			for t in c:
				if t == SEA or t == POND: water += 1
			var block = walkable[y * W + x] == 0 or water >= 3 or x < 2 or y < 2 or x >= W - 2 or y >= H - 2
			for k in 4:
				var wk: bool = c[k] == SEA or c[k] == POND
				if block or (water == 2 and wk):
					solid[(y * 2 + (k >> 1)) * W * 2 + x * 2 + (k & 1)] = 1

# ---------- props ----------
func _add(kind: String, tx: float, ty: float, opt := {}) -> Dictionary:
	var p = {"kind": kind, "x": tx * T, "y": ty * T, "flip": false}
	p.merge(opt, true)
	props.append(p)
	return p

func _on_road(x: int, y: int) -> bool:
	for r in ROADS:
		if road_dist(x + 0.5, y + 0.5, r) < r.w + 0.4: return true
	return false

func _place_props() -> void:
	props.clear()
	var r = G.Rng.new(1234)
	_add("giwa", 47, 39); _add("giwa", 76, 39); _add("giwa", 46, 49, {"flip": true})
	_add("choga", 46, 64); _add("choga", 76, 63); _add("choga", 77, 52, {"flip": true})
	_add("stall", 55, 45); _add("stall", 68, 45, {"flip": true}); _add("stall", 56, 58)
	_add("well", 61, 51); _add("jars", 50, 44); _add("jars", 73, 58); _add("cart", 70, 59)
	_add("pavilion", 74, 45)
	for p in [[53, 41], [69, 41], [53, 61], [69, 61], [58, 51], [64, 51], [61, 36], [57, 66], [75, 67], [44, 56]]: _add("lamppost", p[0], p[1])
	_add("gate", 66, 66.4, {"gate": "south"})
	for x in [42, 46, 50, 54, 58, 62.4, 70.2, 74, 78]: _add("wall", x + 2, 66.8, {"gate_wall": true})
	_add("boat", 98, 79); _add("boat", 104, 59, {"flip": true}); _add("rock", 94, 62); _add("rock", 108, 84)
	_add("reeds", 86, 58); _add("reeds", 82, 76); _add("jangseung", 92, 68); _add("lantern", 96, 66)
	_add("altar", 103.5, 74.5)
	_add("brokenwell", 101, 21)
	for p in [[90, 12], [110, 14], [94, 30], [112, 30], [88, 22], [106, 9]]: _add("ruinwall", p[0], p[1], {"flip": r.next() < 0.5})
	for p in [[96, 16], [108, 24], [92, 26], [114, 20], [99, 33], [87, 8]]: _add("deadtree", p[0], p[1])
	for p in [[104, 27], [95, 20], [110, 33]]: _add("bones", p[0], p[1])
	_add("lantern", 100, 35)
	_add("pagoda", 73, 11); _add("lantern", 69, 12); _add("lantern", 77, 12); _add("altar", 73, 15)
	for p in [[53, 12], [57, 17], [64, 11], [61, 16], [66, 15]]: _add("lotus", p[0], p[1])
	for p in [[48, 18], [70, 19], [50, 9], [67, 7]]: _add("reeds", p[0], p[1])
	_add("giwa", 50, 24, {"flip": true})
	_add("shrine", 34, 52); _add("lantern", 37, 54); _add("altar", 18, 70); _add("jangseung", 26, 60)
	_add("cheoyonghouse", 20, 17)
	for x in [10, 14, 18, 26, 30]: _add("wall", x, 31)
	for x in [10, 14, 18, 22, 26, 30]: _add("wall", x, 7.5)
	_add("lantern", 15, 27); _add("lantern", 25, 27); _add("jars", 29, 21); _add("pine2", 9, 12)
	_add("lantern", 59, 34); _add("lantern", 63, 34)
	for y in H:
		for x in W:
			var h = G.hash2(x, y, 31)
			var t: Array = cells[y * W + x].t
			if t.has(SEA) or t.has(POND) or t.has(SAND): continue
			if walkable[y * W + x] == 0:
				if (x + (y % 2)) % 2 == 0 and y % 2 == 0 and _near_walk(x, y, 7):
					var kind = "pine" if cell_zone[y * W + x] else ("deadtree" if h < 0.12 else ("pine" if h < 0.6 else "pine2"))
					if x > 82 and y < 42: kind = "deadtree"
					_add(kind, x + 0.5 + (h - 0.5) * 0.8, y + 1 + (G.hash2(x, y, 32) - 0.5) * 0.6, {"flip": h > 0.5})
				continue
			var z = cell_zone[y * W + x]
			if z == null or _on_road(x, y): continue
			var hc = G.hash2(x, y, 55)
			var plain = true
			for v in t:
				if not (v in [GRASS, FOREST, RUIN, YARD]): plain = false
			if z.id != "town" and plain:
				var ox = G.hash2(x, y, 56); var oy = G.hash2(x, y, 57)
				var dry: bool = z.id in ["ruin", "beach", "house"]
				if hc < 0.07: _add("tuft" if dry and hc < 0.03 else "tuft2", x + ox, y + oy + 0.4, {"flip": ox > 0.5})
				elif hc < 0.095 and z.id != "ruin": _add("flowers", x + ox, y + oy)
			var near_spot = false
			for q in [[34, 52], [18, 72], [26, 60]]:
				if Vector2(q[0] - x, q[1] - y).length() < 5: near_spot = true
			if z.id == "forest" and h < 0.085 and not near_spot: _add("pine" if h < 0.06 else "pine2", x + 0.5, y + 1, {"flip": h < 0.03})
			elif z.id == "forest" and h < 0.11: _add("bush", x + 0.5, y + 1)
			elif z.id == "beach" and h < 0.006: _add("rock", x + 0.5, y + 1)
			elif z.id != "town" and z.id != "house" and h < 0.012: _add("bush", x + 0.5, y + 1)
			elif z.id == "ruin" and h < 0.02: _add("rock", x + 0.5, y + 1)

func _near_walk(x: int, y: int, rad: int) -> bool:
	for dy in range(-rad, rad + 1):
		for dx in range(-rad, rad + 1):
			var xx = x + dx; var yy = y + dy
			if xx >= 0 and yy >= 0 and xx < W and yy < H and walkable[yy * W + xx]: return true
	return false

func _prop_solids() -> void:
	for p in props:
		if not p.k.has("foot"): continue
		if p.get("gate_wall", false) and abs(p.x / T - 66) < 3.2: continue
		var f: Array = p.k.foot
		var x0 = int(floor((p.x + f[0]) / 16.0)); var y0 = int(floor((p.y + f[1]) / 16.0))
		var x1 = int(floor((p.x + f[0] + f[2] - 1) / 16.0)); var y1 = int(floor((p.y + f[1] + f[3] - 1) / 16.0))
		for y in range(y0, y1 + 1):
			for x in range(x0, x1 + 1):
				if x >= 0 and y >= 0 and x < W * 2 and y < H * 2: solid[y * W * 2 + x] = 1

# ---------- queries ----------
func zone_at(px: float, py: float):
	var tx = int(px / T); var ty = int(py / T)
	if tx < 0 or ty < 0 or tx >= W or ty >= H: return null
	return cell_zone[ty * W + tx]

func terrain_at(px: float, py: float) -> int:
	var c = cells[clampi(int(py / T), 0, H - 1) * W + clampi(int(px / T), 0, W - 1)]
	return c.t[3]

func gate_blocks(px: float, py: float):
	var tx = px / T; var ty = py / T
	for g in GATES:
		if not flags.get(g.flag, false) and tx >= g.x0 and tx <= g.x1 and ty >= g.y0 and ty <= g.y1: return g
	return null

func solid_at(px: float, py: float) -> bool:
	var x = int(floor(px / 16.0)); var y = int(floor(py / 16.0))
	if x < 0 or y < 0 or x >= W * 2 or y >= H * 2: return true
	if solid[y * W * 2 + x]: return true
	return gate_blocks(px, py) != null

func blocked(x: float, y: float, r: float) -> bool:
	for i in 8:
		var a = i / 8.0 * TAU
		if solid_at(x + cos(a) * r, y + sin(a) * r * 0.7): return true
	return solid_at(x, y)

# move an entity (any object with x, y, r) with wall sliding
func move_circle(e, dx: float, dy: float) -> void:
	var r: float = e.r
	if dx != 0:
		if not blocked(e.x + dx, e.y, r): e.x += dx
		else:
			for s in [1, -1]:
				if not blocked(e.x + dx * 0.7, e.y + s * abs(dx) * 0.7, r):
					e.x += dx * 0.7; e.y += s * abs(dx) * 0.7; break
	if dy != 0:
		if not blocked(e.x, e.y + dy, r): e.y += dy
		else:
			for s in [1, -1]:
				if not blocked(e.x + s * abs(dy) * 0.7, e.y + dy * 0.7, r):
					e.x += s * abs(dy) * 0.7; e.y += dy * 0.7; break

func is_water(tx: int, ty: int) -> bool:
	if tx < 0 or ty < 0 or tx >= W or ty >= H: return false
	var f: int = cells[ty * W + tx].full
	return f == SEA or f == POND

# Ground as a TileMapLayer: full-resolution 64px painted tiles drawn at half scale.
func build_tilemap() -> TileMapLayer:
	var ts = TileSet.new()
	ts.tile_size = Vector2i(64, 64)
	var src_ids = {}
	var sid = 0
	for name in Assets.tiles:
		var t: Dictionary = Assets.tiles[name]
		var src = TileSetAtlasSource.new()
		src.texture = t.tex
		var sz: int = t.size
		src.texture_region_size = Vector2i(sz, sz)
		var cols: int = t.tex.get_width() / sz
		var rows: int = t.tex.get_height() / sz
		for yy in rows:
			for xx in cols:
				src.create_tile(Vector2i(xx, yy))
				var alt = src.create_alternative_tile(Vector2i(xx, yy))
				src.get_tile_data(Vector2i(xx, yy), alt).flip_h = true
		ts.add_source(src, sid)
		src_ids[name] = [sid, sz]
		sid += 1
	var layer = TileMapLayer.new()
	layer.tile_set = ts
	for y in H:
		for x in W:
			var c: Dictionary = cells[y * W + x]
			if c.idx == null or not src_ids.has(c.set): continue
			var s: Array = src_ids[c.set]
			var i: int = c.idx
			layer.set_cell(Vector2i(x, y), s[0], Vector2i(i % 4, i / 4), 1 if c.flip else 0)
	layer.scale = Vector2(float(T) / 64.0, float(T) / 64.0)
	layer.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	return layer
