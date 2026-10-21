# Buildings: hanok houses, thatched huts, walls, gates, pavilions, pagodas and wells built as real 3D meshes
# so they sit in the terrain (lit, shadowed, axis-aligned) instead of standing up as pictures.
# Sizes are in metres; a prop's anchor is the middle of its south (front) edge.
class_name Buildings
extends RefCounted

const T := 32.0
# body width x depth in game pixels: the collision footprint is the body (world.gd uses foot())
const DIMS := {
	"giwa": [176, 100], "choga": [144, 88], "cheoyonghouse": [236, 150], "shrine": [100, 76],
	"pavilion": [132, 108], "stall": [100, 56], "well": [56, 56], "brokenwell": [60, 60],
	"pagoda": [60, 60], "wall": [128, 20], "ruinwall": [104, 18], "altar": [52, 22], "gate": [0, 0],
	"hall": [240, 150], "dabotap": [76, 76], "cave": [200, 120], "poseok": [190, 120], "brickpagoda": [96, 96],
	"mokta": [190, 190], "cheomseong": [90, 90], "palace": [340, 190], "palacegate": [300, 40], "maae": [150, 40], "stonebuddha": [44, 36],
}

static var mats := {}

static func has(kind: String) -> bool: return DIMS.has(kind)

static func foot(kind: String) -> Array:
	var d: Array = DIMS[kind]
	return [-d[0] / 2, -d[1] - 4, d[0], d[1]]

static func mat(name: String) -> StandardMaterial3D:
	if mats.has(name): return mats[name]
	var m = StandardMaterial3D.new()
	m.albedo_texture = load("res://assets/tex/%s.png" % name)
	m.roughness = 1.0
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	mats[name] = m
	return m

# ---------- primitives (all write into a SurfaceTool per material) ----------
class Kit:
	var st := {}
	func s(name: String) -> SurfaceTool:
		if not st.has(name):
			var t = SurfaceTool.new(); t.begin(Mesh.PRIMITIVE_TRIANGLES); st[name] = t
		return st[name]
	# normals are set explicitly and turned towards `out` (faces are double sided)
	func quad(name: String, a: Vector3, b: Vector3, c: Vector3, d: Vector3, ua: Vector2, ub: Vector2, uc: Vector2, ud: Vector2, out := Vector3.UP) -> void:
		var t := s(name)
		var n := (b - a).cross(c - a)
		if n.length_squared() < 1e-10: n = (c - a).cross(d - a)
		n = n.normalized()
		# Godot's front faces wind clockwise (geometric normal pointing away): keep the outside facing out
		var order := [[a, ua], [b, ub], [c, uc], [a, ua], [c, uc], [d, ud]]
		if n.dot(out) > 0: order = [[a, ua], [d, ud], [c, uc], [a, ua], [c, uc], [b, ub]]
		else: n = -n
		for p in order:
			t.set_normal(n); t.set_uv(p[1]); t.add_vertex(p[0])
	# axis-aligned box; texture repeats every `tile` metres (v spans the height when vfit)
	func box(name: String, c: Vector3, sz: Vector3, tile := 1.0, vfit := false) -> void:
		var h := sz / 2
		var x0 := c.x - h.x; var x1 := c.x + h.x; var y0 := c.y; var y1 := c.y + sz.y; var z0 := c.z - h.z; var z1 := c.z + h.z
		var vh: float = 1.0 if vfit else sz.y / tile
		# south, north, east, west, top
		quad(name, Vector3(x0, y1, z1), Vector3(x1, y1, z1), Vector3(x1, y0, z1), Vector3(x0, y0, z1), Vector2(0, 0), Vector2(sz.x / tile, 0), Vector2(sz.x / tile, vh), Vector2(0, vh), Vector3.BACK)
		quad(name, Vector3(x1, y1, z0), Vector3(x0, y1, z0), Vector3(x0, y0, z0), Vector3(x1, y0, z0), Vector2(0, 0), Vector2(sz.x / tile, 0), Vector2(sz.x / tile, vh), Vector2(0, vh), Vector3.FORWARD)
		quad(name, Vector3(x1, y1, z1), Vector3(x1, y1, z0), Vector3(x1, y0, z0), Vector3(x1, y0, z1), Vector2(0, 0), Vector2(sz.z / tile, 0), Vector2(sz.z / tile, vh), Vector2(0, vh), Vector3.RIGHT)
		quad(name, Vector3(x0, y1, z0), Vector3(x0, y1, z1), Vector3(x0, y0, z1), Vector3(x0, y0, z0), Vector2(0, 0), Vector2(sz.z / tile, 0), Vector2(sz.z / tile, vh), Vector2(0, vh), Vector3.LEFT)
		quad(name, Vector3(x0, y1, z0), Vector3(x1, y1, z0), Vector3(x1, y1, z1), Vector3(x0, y1, z1), Vector2(0, 0), Vector2(sz.x / tile, 0), Vector2(sz.x / tile, sz.z / tile), Vector2(0, sz.z / tile), Vector3.UP)
	func cylinder(name: String, c: Vector3, r: float, hgt: float, seg := 14, from := 0.0, to := TAU, top := true) -> void:
		for i in seg:
			var a0 := lerpf(from, to, i / float(seg)); var a1 := lerpf(from, to, (i + 1) / float(seg))
			var p0 := c + Vector3(cos(a0) * r, 0, sin(a0) * r); var p1 := c + Vector3(cos(a1) * r, 0, sin(a1) * r)
			var u0 := a0 * r; var u1 := a1 * r
			var am := (a0 + a1) / 2
			quad(name, p0 + Vector3(0, hgt, 0), p1 + Vector3(0, hgt, 0), p1, p0, Vector2(u0, 0), Vector2(u1, 0), Vector2(u1, hgt), Vector2(u0, hgt), Vector3(cos(am), 0, sin(am)))
			if top:
				var t := s(name)
				for p in [c + Vector3(0, hgt, 0), p0 + Vector3(0, hgt, 0), p1 + Vector3(0, hgt, 0)]:
					t.set_normal(Vector3.UP); t.set_uv(Vector2(p.x, p.z)); t.add_vertex(p)
	# hip roof over the eave rectangle (half sizes ax, bz) at height y0 rising `rise` to a ridge of half length rr.
	# lift: upturned corners (Korean eaves); curve > 1 concave (giwa), < 1 rounded (thatch)
	func roof(name: String, c: Vector3, ax: float, bz: float, rise: float, rr: float, lift: float, curve: float, rows := 6, cols := 10, uvk := 0.55) -> void:
		var top := c.y + rise
		var faces := [
			[Vector2(-ax, bz), Vector2(ax, bz), Vector2(-rr, 0), Vector2(rr, 0)],     # south
			[Vector2(ax, -bz), Vector2(-ax, -bz), Vector2(rr, 0), Vector2(-rr, 0)],   # north
			[Vector2(ax, bz), Vector2(ax, -bz), Vector2(rr, 0), Vector2(rr, 0)],      # east
			[Vector2(-ax, -bz), Vector2(-ax, bz), Vector2(-rr, 0), Vector2(-rr, 0)],  # west
		]
		for f in faces:
			var ea: Vector2 = f[0]; var eb: Vector2 = f[1]; var ra: Vector2 = f[2]; var rb: Vector2 = f[3]
			var elen := ea.distance_to(eb)
			var slope := Vector2((ea + eb) / 2).distance_to((ra + rb) / 2) + rise
			var grid := []
			for j in rows + 1:
				var tt := j / float(rows)
				var row := []
				for i in cols + 1:
					var ss := i / float(cols)
					var e := ea.lerp(eb, ss); var r := ra.lerp(rb, ss)
					var hp := e.lerp(r, tt)
					var ey := c.y + lift * pow(abs(ss * 2 - 1), 3)
					var y := lerpf(ey, top, pow(tt, curve))
					row.append([Vector3(c.x + hp.x, y, c.z + hp.y), Vector2(ss * elen, (1 - tt) * slope) * uvk])
				grid.append(row)
			for j in rows:
				for i in cols:
					var a: Array = grid[j][i]; var b: Array = grid[j][i + 1]; var d: Array = grid[j + 1][i]; var e2: Array = grid[j + 1][i + 1]
					quad(name, a[0], b[0], e2[0], d[0], a[1], b[1], e2[1], d[1], Vector3.UP)
	func build() -> MeshInstance3D:
		var mesh := ArrayMesh.new()
		for name in st:
			var t: SurfaceTool = st[name]
			t.commit(mesh)
			mesh.surface_set_material(mesh.get_surface_count() - 1, Buildings.mat(name))
		var mi := MeshInstance3D.new()
		mi.mesh = mesh
		return mi

# ---------- buildings ----------
# returns {"node": Node3D, "doors": Node3D or null}; origin = anchor on the ground (y = ground height)
static func make(kind: String) -> Dictionary:
	var k := Kit.new()
	var d: Array = DIMS[kind]
	var w: float = d[0] / T; var dp: float = d[1] / T
	var cz: float = -(4.0 / T) - dp / 2   # body centre (north of the anchor)
	var doors = null
	match kind:
		"giwa", "shrine", "cheoyonghouse":
			var big = kind == "cheoyonghouse"
			var ph := 0.55 if big else 0.4
			var wall_h := 2.5 if big else (1.9 if kind == "shrine" else 2.25)
			k.box("stone_block", Vector3(0, -0.6, cz), Vector3(w, ph + 0.6, dp), 1.0)
			var bw := w - 0.5; var bd := dp - (1.3 if big else 0.6)
			var bz := cz - (0.45 if big else 0.0)
			k.box("wall_shrine" if kind == "shrine" else "wall_hanok", Vector3(0, ph, bz), Vector3(bw, wall_h, bd), 2.0, true)
			if big:  # wooden veranda (maru) with red pillars along the front
				k.box("wood", Vector3(0, ph, cz + dp / 2 - 0.55), Vector3(w - 0.3, 0.12, 1.0), 1.0)
				for i in 6:
					var x := lerpf(-w / 2 + 0.35, w / 2 - 0.35, i / 5.0)
					k.box("red_wood", Vector3(x, ph, cz + dp / 2 - 0.2), Vector3(0.2, wall_h, 0.2), 1.0)
			# front steps
			k.box("stone_block", Vector3(0, -0.3, cz + dp / 2 + 0.25), Vector3(1.2, ph * 0.5 + 0.3, 0.5), 1.0)
			var top := ph + wall_h
			k.box("wood", Vector3(0, top - 0.05, cz), Vector3(w + 0.2, 0.18, dp + 0.2), 1.0)
			var ox := 0.5 if not big else 0.7
			k.roof("roof_giwa", Vector3(0, top + 0.05, cz), w / 2 + ox, dp / 2 + ox, (1.5 if big else 1.25), max(0.3, w / 2 - dp / 2 - 0.2), 0.38, 1.6)
			# white-edged tile ends (makssae) along the front eave
			k.box("stone_smooth", Vector3(0, top - 0.02 + 0.0, cz + dp / 2 + ox - 0.05), Vector3(w + ox * 2 - 0.4, 0.1, 0.12), 0.5)
			# ridge cap with raised ends
			var rr: float = max(0.3, w / 2 - dp / 2 - 0.2)
			var ry := top + 0.05 + (1.5 if big else 1.25)
			k.box("roof_giwa", Vector3(0, ry - 0.1, cz), Vector3(rr * 2 + 0.3, 0.28, 0.32), 0.5)
			for sx in [-1, 1]: k.box("roof_giwa", Vector3(sx * (rr + 0.12), ry - 0.05, cz), Vector3(0.2, 0.45, 0.34), 0.5)
		"choga":
			k.box("stone_block", Vector3(0, -0.6, cz), Vector3(w, 0.85, dp), 1.0)
			k.box("wall_mud", Vector3(0, 0.25, cz), Vector3(w - 0.4, 1.75, dp - 0.4), 2.0, true)
			k.roof("roof_thatch", Vector3(0, 1.9, cz), w / 2 + 0.6, dp / 2 + 0.6, 1.35, max(0.2, w / 2 - dp / 2 - 0.6), 0.0, 0.55, 6, 10)
			k.box("roof_thatch", Vector3(0, 3.1, cz), Vector3(max(0.6, w - dp - 0.8), 0.22, 0.5), 0.5)
		"pavilion":
			k.box("stone_block", Vector3(0, -0.6, cz), Vector3(w, 0.95, dp), 1.0)
			k.box("wood", Vector3(0, 0.35, cz), Vector3(w - 0.2, 0.15, dp - 0.2), 1.0)
			for sx in [-1, 1]:
				for sz in [-1, 1]:
					k.box("red_wood", Vector3(sx * (w / 2 - 0.3), 0.5, cz + sz * (dp / 2 - 0.3)), Vector3(0.22, 2.0, 0.22), 1.0)
			# railing
			for sz in [-1, 1]: k.box("wood", Vector3(0, 0.75, cz + sz * (dp / 2 - 0.3)), Vector3(w - 0.6, 0.08, 0.08), 1.0)
			k.box("wood", Vector3(0, 2.45, cz), Vector3(w + 0.1, 0.16, dp + 0.1), 1.0)
			k.roof("roof_giwa", Vector3(0, 2.55, cz), w / 2 + 0.7, dp / 2 + 0.7, 1.15, max(0.2, w / 2 - dp / 2), 0.4, 1.6)
		"stall":
			k.box("wood", Vector3(0, 0, cz + 0.2), Vector3(w - 0.4, 0.75, dp - 0.6), 1.0)
			k.box("cloth", Vector3(-0.6, 0.75, cz + 0.1), Vector3(0.6, 0.25, 0.5), 1.0)
			k.box("brick", Vector3(0.5, 0.75, cz + 0.2), Vector3(0.5, 0.3, 0.4), 1.0)
			for sx in [-1, 1]:
				for sz in [-1, 1]:
					k.box("wood", Vector3(sx * (w / 2 - 0.1), 0, cz + sz * (dp / 2 - 0.1)), Vector3(0.12, 2.0 + (0.3 if sz < 0 else 0.0), 0.12), 1.0)
			k.roof("cloth", Vector3(0, 2.0, cz), w / 2 + 0.25, dp / 2 + 0.35, 0.55, w / 2 + 0.25, 0.0, 1.0, 2, 4, 1.0)
		"well", "brokenwell":
			var r := w / 2 - 0.05
			if kind == "well":
				k.cylinder("stone_block", Vector3(0, -0.4, cz), r, 1.15, 16)
				k.cylinder("stone_smooth", Vector3(0, -0.4, cz), r - 0.18, 1.0, 16, 0.0, TAU, false)
				for sx in [-1, 1]: k.box("wood", Vector3(sx * (r - 0.05), 0.6, cz), Vector3(0.12, 1.5, 0.12), 1.0)
				k.box("wood", Vector3(0, 1.9, cz), Vector3(r * 2 + 0.1, 0.1, 0.1), 1.0)
				k.roof("roof_giwa", Vector3(0, 2.05, cz), r + 0.35, 0.55, 0.45, r, 0.12, 1.4, 3, 6)
			else:
				for i in 7:
					var a0 := i / 7.0 * TAU
					var hh := 0.5 + G.hash2(i, 3, 9) * 0.7
					k.cylinder("stone_block", Vector3(0, -0.4, cz), r, hh, 2, a0, a0 + TAU / 7.0 - 0.15, false)
					k.cylinder("stone_block", Vector3(0, -0.4, cz), r - 0.22, hh, 2, a0, a0 + TAU / 7.0 - 0.15, false)
				k.cylinder("stone_smooth", Vector3(0, -0.3, cz), r - 0.22, 0.05, 14)
		"pagoda":
			k.box("stone_smooth", Vector3(0, -0.4, cz), Vector3(w, 0.8, dp), 1.0)
			var y := 0.4
			var s := w * 0.62
			for i in 4:
				var bh := 0.75 - i * 0.08
				k.box("stone_smooth", Vector3(0, y, cz), Vector3(s, bh, s), 1.0)
				y += bh
				k.roof("stone_smooth", Vector3(0, y, cz), s / 2 + 0.3, s / 2 + 0.3, 0.22, 0.05, 0.12, 1.2, 2, 4)
				y += 0.22
				s *= 0.82
			k.cylinder("stone_smooth", Vector3(0, y, cz), 0.08, 0.7, 6)
		"wall":
			k.box("brick", Vector3(0, -0.3, cz), Vector3(w, 1.65, dp), 1.0)
			k.roof("roof_giwa", Vector3(0, 1.35, cz), w / 2 + 0.05, dp / 2 + 0.22, 0.3, w / 2 - 0.2, 0.0, 1.0, 1, 6)
		"ruinwall":
			var n := 5
			for i in n:
				var hh := 0.4 + G.hash2(i, 7, int(w * 10)) * 1.1
				k.box("stone_block", Vector3(-w / 2 + (i + 0.5) * w / n, -0.3, cz + (G.hash2(i, 8, 3) - 0.5) * 0.1), Vector3(w / n - 0.05, hh + 0.3, dp), 1.0)
		"altar":
			for sx in [-1, 1]: k.box("stone_smooth", Vector3(sx * (w / 2 - 0.15), -0.2, cz), Vector3(0.22, 0.75, dp - 0.1), 1.0)
			k.box("stone_smooth", Vector3(0, 0.55, cz), Vector3(w, 0.14, dp + 0.1), 1.0)
		"gate":
			# south city gate spanning the road between the wall ends; the doors hide once it opens
			var half := 3.9
			for sx in [-1, 1]:
				k.box("red_wood", Vector3(sx * half, -0.2, -0.2), Vector3(0.5, 3.6, 0.5), 1.0)
				k.box("stone_block", Vector3(sx * half, -0.4, -0.2), Vector3(0.8, 0.6, 0.8), 1.0)
			k.box("red_wood", Vector3(0, 3.0, -0.2), Vector3(half * 2 + 0.6, 0.35, 0.4), 1.0)
			k.box("wood", Vector3(0, 3.35, -0.2), Vector3(half * 2 + 0.8, 0.15, 0.9), 1.0)
			k.roof("roof_giwa", Vector3(0, 3.45, -0.2), half + 0.9, 0.95, 0.9, half + 0.2, 0.35, 1.5, 4, 12)
			var dk := Kit.new()
			for sx in [-1, 1]:
				dk.box("wood", Vector3(sx * half / 2, -0.1, -0.2), Vector3(half - 0.3, 3.0, 0.14), 1.0)
			doors = dk.build()
		"hall", "palace":
			# temple hall / palace: stone terrace, red pillars all round, lattice walls, big hipped roof
			var pal = kind == "palace"
			var ph := 1.1 if pal else 0.6
			k.box("stone_block", Vector3(0, -0.8, cz), Vector3(w, ph + 0.8, dp), 1.0)
			k.box("stone_block", Vector3(0, -0.5, cz + dp / 2 + 0.5), Vector3(2.2, ph * 0.6 + 0.5, 1.0), 1.0)
			var bw := w - 1.6; var bd := dp - 1.6
			k.box("wall_shrine", Vector3(0, ph, cz), Vector3(bw, 2.7, bd), 2.0, true)
			var n := int(bw / 1.6) + 1
			for i in n:
				var x := lerpf(-w / 2 + 0.5, w / 2 - 0.5, i / float(n - 1))
				k.box("red_wood", Vector3(x, ph, cz + dp / 2 - 0.45), Vector3(0.26, 2.9, 0.26), 1.0)
			var top := ph + 2.9
			k.box("red_wood", Vector3(0, top - 0.25, cz), Vector3(w - 0.6, 0.3, dp - 0.6), 1.0)
			k.roof("roof_giwa", Vector3(0, top, cz), w / 2 + 0.5, dp / 2 + 0.5, 2.1 if pal else 1.8, max(0.4, w / 2 - dp / 2), 0.55, 1.6, 8, 14)
			var rr: float = max(0.4, w / 2 - dp / 2)
			var ry := top + (2.1 if pal else 1.8)
			k.box("roof_giwa", Vector3(0, ry - 0.12, cz), Vector3(rr * 2 + 0.4, 0.34, 0.4), 0.5)
			for sx in [-1, 1]: k.box("roof_giwa", Vector3(sx * (rr + 0.18), ry - 0.05, cz), Vector3(0.26, 0.6, 0.42), 0.5)
			k.box("stone_smooth", Vector3(0, top - 0.02, cz + dp / 2 + 0.45), Vector3(w + 0.6, 0.1, 0.12), 0.5)
		"dabotap":
			# Dabotap: square base with stairs, an open pillared storey, octagonal railings and a finial
			k.box("stone_smooth", Vector3(0, -0.4, cz), Vector3(w, 1.2, dp), 1.0)
			for sx in [-1, 1]:
				for sz in [-1, 1]: k.box("stone_smooth", Vector3(sx * 0.6, 0.8, cz + sz * 0.6), Vector3(0.22, 1.1, 0.22), 1.0)
			k.box("stone_smooth", Vector3(0, 0.8, cz), Vector3(0.5, 1.1, 0.5), 1.0)
			k.roof("stone_smooth", Vector3(0, 1.9, cz), 1.25, 1.25, 0.25, 0.05, 0.1, 1.0, 2, 4)
			k.cylinder("stone_smooth", Vector3(0, 2.15, cz), 0.75, 0.55, 8)
			k.cylinder("stone_smooth", Vector3(0, 2.7, cz), 0.55, 0.12, 8)
			k.cylinder("stone_smooth", Vector3(0, 2.82, cz), 0.45, 0.5, 8)
			k.roof("stone_smooth", Vector3(0, 3.32, cz), 0.85, 0.85, 0.3, 0.02, 0.08, 1.0, 2, 4)
			k.cylinder("stone_smooth", Vector3(0, 3.6, cz), 0.07, 0.9, 6)
		"cave":
			# Seokguram: a grassy mound of stone with a dark arched doorway facing south
			k.box("stone_block", Vector3(0, -0.5, cz), Vector3(w, 3.0, dp * 0.8), 1.0)
			k.roof("roof_thatch" if false else "stone_block", Vector3(0, 2.5, cz), w / 2, dp * 0.4, 1.8, w / 4, 0.0, 0.5, 4, 8, 1.0)
			k.box("wood", Vector3(0, -0.1, cz + dp * 0.4 + 0.02), Vector3(2.0, 2.4, 0.05), 1.0)
			k.box("stone_smooth", Vector3(0, -0.2, cz + dp * 0.4 + 0.1), Vector3(2.8, 0.3, 0.2), 1.0)
			for sx in [-1, 1]: k.box("stone_smooth", Vector3(sx * 1.2, -0.2, cz + dp * 0.4 + 0.1), Vector3(0.4, 2.7, 0.3), 1.0)
		"poseok":
			# Poseokjeong: abalone-shaped stone water channel around a garden
			var rx := w / 2 - 0.3; var rz := dp / 2 - 0.3
			for i in 22:
				var a0 := i / 22.0 * TAU; var a1 := (i + 1) / 22.0 * TAU
				var wob := 1.0 + 0.12 * sin(a0 * 3)
				var p0 := Vector3(cos(a0) * rx * wob, 0, cz + sin(a0) * rz * wob)
				var p1 := Vector3(cos(a1) * rx * (1.0 + 0.12 * sin(a1 * 3)), 0, cz + sin(a1) * rz * (1.0 + 0.12 * sin(a1 * 3)))
				var mid := (p0 + p1) / 2
				k.box("stone_smooth", Vector3(mid.x, -0.3, mid.z), Vector3(abs(p1.x - p0.x) + 0.35, 0.55, abs(p1.z - p0.z) + 0.35), 0.5)
		"brickpagoda":
			# Bunhwangsa: square pagoda of dark stone bricks, stepped eaves, guardian lions at the corners
			k.box("stone_block", Vector3(0, -0.4, cz), Vector3(w, 0.8, dp), 1.0)
			var y := 0.4; var s := w - 0.8
			for i in 3:
				k.box("brick", Vector3(0, y, cz), Vector3(s, 1.3 - i * 0.2, s), 1.0)
				y += 1.3 - i * 0.2
				for st in 3:
					k.box("stone_block", Vector3(0, y, cz), Vector3(s + 0.5 - st * 0.35, 0.14, s + 0.5 - st * 0.35), 1.0)
					y += 0.14
				s *= 0.82
			for sx in [-1, 1]:
				for sz in [-1, 1]: k.box("stone_smooth", Vector3(sx * (w / 2 - 0.3), 0.4, cz + sz * (dp / 2 - 0.3)), Vector3(0.45, 0.6, 0.6), 1.0)
		"mokta":
			# Hwangnyongsa nine-storey wooden pagoda
			k.box("stone_block", Vector3(0, -0.6, cz), Vector3(w, 1.2, dp), 1.0)
			var y := 0.6; var s := w - 1.2
			for i in 9:
				var bh := 1.05 - i * 0.04
				k.box("wall_shrine", Vector3(0, y, cz), Vector3(s, bh, s), 2.0, true)
				y += bh
				k.roof("roof_giwa", Vector3(0, y - 0.05, cz), s / 2 + 0.55, s / 2 + 0.55, 0.45, 0.05, 0.22, 1.4, 2, 6)
				y += 0.4
				s *= 0.9
			k.cylinder("stone_smooth", Vector3(0, y, cz), 0.1, 2.2, 6)
			for j in 5: k.cylinder("stone_smooth", Vector3(0, y + 0.5 + j * 0.3, cz), 0.25, 0.06, 8)
		"cheomseong":
			# Cheomseongdae: bottle-shaped stone observatory with a square window and a well frame on top
			k.box("stone_block", Vector3(0, -0.3, cz), Vector3(w, 0.6, dp), 1.0)
			var y := 0.3
			for i in 12:
				var t := i / 11.0
				var r := lerpf(1.25, 0.82, t) + 0.12 * sin(t * PI) * (1.0 - t)
				k.cylinder("stone_block", Vector3(0, y, cz), r, 0.38, 16, 0.0, TAU, i == 11)
				y += 0.38
			k.box("wood", Vector3(0, 2.2, cz + 1.02), Vector3(0.55, 0.55, 0.05), 1.0)
			for sz in [-1, 1]: k.box("stone_smooth", Vector3(0, y, cz + sz * 0.75), Vector3(1.9, 0.22, 0.22), 1.0)
			for sx in [-1, 1]: k.box("stone_smooth", Vector3(sx * 0.75, y + 0.22, cz), Vector3(0.22, 0.22, 1.9), 1.0)
		"palacegate":
			var half := w / 2
			for i in 5:
				var x := lerpf(-half + 0.4, half - 0.4, i / 4.0)
				if abs(x) < 1.0: continue
				k.box("red_wood", Vector3(x, -0.2, cz), Vector3(0.4, 3.4, 0.4), 1.0)
			k.box("stone_block", Vector3(-half + 1.6, -0.4, cz), Vector3(3.0, 1.2, dp), 1.0)
			k.box("stone_block", Vector3(half - 1.6, -0.4, cz), Vector3(3.0, 1.2, dp), 1.0)
			k.box("red_wood", Vector3(0, 2.9, cz), Vector3(w, 0.4, 0.5), 1.0)
			k.roof("roof_giwa", Vector3(0, 3.3, cz), half + 0.8, 1.2, 1.1, half, 0.4, 1.5, 4, 14)
			var dk := Kit.new()
			dk.box("wood", Vector3(0, -0.1, cz), Vector3(4.6, 3.0, 0.16), 1.0)
			doors = dk.build()
		"maae":
			# rock face with a carved Buddha (raised relief built from a few blocks)
			k.box("stone_block", Vector3(0, -0.4, cz), Vector3(w, 3.6, dp), 1.0)
			k.roof("stone_block", Vector3(0, 3.2, cz), w / 2 + 0.1, dp / 2 + 0.1, 0.6, w / 2 - 0.4, 0.0, 0.6, 2, 4, 1.0)
			var fz := cz + dp / 2 + 0.06
			k.box("stone_smooth", Vector3(0, 0.1, fz), Vector3(1.3, 1.6, 0.12), 1.0)
			k.box("stone_smooth", Vector3(0, 1.7, fz), Vector3(0.65, 0.7, 0.14), 1.0)
			k.box("stone_smooth", Vector3(0, 2.4, fz), Vector3(0.25, 0.25, 0.12), 1.0)
			k.cylinder("stone_smooth", Vector3(0, 1.5, fz - 0.02), 1.0, 0.05, 14, PI, TAU, false)
		"stonebuddha":
			k.box("stone_smooth", Vector3(0, -0.2, cz), Vector3(w, 0.55, dp), 1.0)
			k.box("stone_smooth", Vector3(0, 0.35, cz), Vector3(0.9, 0.55, 0.7), 1.0)
			k.box("stone_smooth", Vector3(0, 0.9, cz), Vector3(0.6, 0.75, 0.45), 1.0)
			k.box("stone_smooth", Vector3(0, 1.65, cz), Vector3(0.36, 0.38, 0.36), 1.0)
			k.box("stone_smooth", Vector3(0, 2.03, cz), Vector3(0.16, 0.12, 0.16), 1.0)
	var node := Node3D.new()
	var mi := k.build()
	node.add_child(mi)
	if doors: node.add_child(doors)
	return {"node": node, "doors": doors}
