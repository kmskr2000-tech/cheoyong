extends SceneTree
## 에셋 겹침 전수 검출 (프로그래밍팀-에셋겹침수정). 사용: tests/overlap_check.sh [맵...]
##   godot --headless --path src -s ../tests/godot/overlap_check.gd -- --map=<레벨 id> [--md=<표 출력 파일>]
## levels.gd 의 props·npcs·interact·exits·triggers·spawns 를 level.gd 와 같은 규칙(lift·lift_size, 스프라이트 오프셋)으로
## 화면 좌표에 올려 '실제 불투명 픽셀' 기준으로 겹침을 센다.
##   OVERLAP     두 스프라이트의 불투명 픽셀이 PIX_MIN 이상 겹침(소품-소품 / 소품-NPC / NPC-NPC)
##   LABEL       상호작용 지점(발밑 점)이 다른 소품·NPC 의 불투명 픽셀 위에 놓임
##   AMBIGUOUS   말 걸기 대상 둘이 AMBIG_DIST 안에 있어 한 자리에서 둘 다 TALK_RANGE 안 → 가까운 쪽이 눌림
##   BLOCKED     출구·트리거·스폰이 소품/NPC 충돌에 걸림 (보행 불가)
## ALLOW 에 사유와 함께 적힌 쌍만 의도된 접촉으로 면제한다. 결과 줄: OVERLAP_RESULT <map> <건수>  (0 이면 통과)

const PIX_MIN := 6
const AMBIG_DIST := 20.0
const OCCLUDE := {"pillar": Vector2(7, 5), "irworobong": Vector2(50, 4), "chotdae": Vector2(4, 3), "tal": Vector2(3, 3), "hall": Vector2(80, 24), "jars": Vector2(16, 6), "beam": Vector2(24, 6), "altar": Vector2(20, 6), "boat": Vector2(28, 8), "netrack": Vector2(30, 3), "house": Vector2(50, 28), "pine": Vector2(5, 6), "seonang": Vector2(8, 6), "jangseung_m": Vector2(5, 4), "jangseung_f": Vector2(5, 4), "lantern": Vector2(8, 6), "dodam": Vector2(32, 6), "board": Vector2(18, 8), "rockwall": Vector2(32, 20), "tent": Vector2(26, 12), "burnt_stall": Vector2(26, 8), "sansingak": Vector2(40, 18)}
# 의도된 접촉: "<맵>|<이름A>|<이름B>" → 사유. (이름은 이 스크립트가 붙이는 라벨과 같다)
const ALLOW := {}

var meta := {}
var def := {}
var ents: Array = []
var findings: Array = []
var map_id := ""
var md_path := ""
var img_cache := {}


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--map="): map_id = a.get_slice("=", 1)
		elif a.begins_with("--md="): md_path = a.get_slice("=", 1)
	_main.call_deferred()


func _img(path: String) -> Image:
	if img_cache.has(path):
		return img_cache[path]
	var im := Image.load_from_file(ProjectSettings.globalize_path(path))
	if im == null:
		push_error("이미지 로드 실패 " + path)
		quit(2)
		return null
	im.convert(Image.FORMAT_RGBA8)
	img_cache[path] = im
	return im


func _lift(p: Vector2) -> Vector2:
	var rows: Array = meta["heights"]
	var ts: int = int(meta["ts"])
	var cy := clampi(int(p.y / ts), 0, rows.size() - 1)
	var cx := clampi(int(p.x / ts), 0, String(rows[0]).length() - 1)
	var c := String(rows[cy])[cx]
	var t := 1.0 if not c.is_valid_int() else float(c)
	return Vector2(p.x, p.y * float(meta.get("k", 1.0)) - t * float(meta["tier"]))


func _lift_size(sz: Vector2) -> Vector2:
	return Vector2(sz.x, sz.y * float(meta.get("k", 1.0)))


## 불투명(알파>32) 외곽 상자. region = 이미지 안에서 볼 영역(NPC 한 프레임)
func _bbox(im: Image, region: Rect2i) -> Rect2i:
	var x0 := 100000
	var y0 := 100000
	var x1 := -1
	var y1 := -1
	for y in range(region.position.y, region.end.y):
		for x in range(region.position.x, region.end.x):
			if im.get_pixel(x, y).a > 0.125:
				x0 = mini(x0, x)
				y0 = mini(y0, y)
				x1 = maxi(x1, x)
				y1 = maxi(y1, y)
	if x1 < 0:
		return Rect2i()
	return Rect2i(x0, y0, x1 - x0 + 1, y1 - y0 + 1)


func _add_sprite(kind: String, nm: String, im: Image, region: Rect2i, origin: Vector2, foot: Vector2, note: String) -> void:
	# origin = 화면 좌표에서 region 왼쪽 위가 놓이는 곳
	var bb := _bbox(im, region)
	ents.append({"kind": kind, "name": nm, "img": im, "region": region, "origin": origin, "foot": foot,
		"rect": Rect2(origin + Vector2(bb.position - region.position), Vector2(bb.size)), "note": note})


func _pix_overlap(a: Dictionary, b: Dictionary) -> int:
	var r: Rect2 = (a["rect"] as Rect2).intersection(b["rect"])
	if r.size.x <= 0 or r.size.y <= 0:
		return 0
	var n := 0
	var ia: Image = a["img"]
	var ib: Image = b["img"]
	var oa: Vector2 = a["origin"]
	var ob: Vector2 = b["origin"]
	var ra: Rect2i = a["region"]
	var rb: Rect2i = b["region"]
	for y in range(int(floor(r.position.y)), int(ceil(r.end.y))):
		for x in range(int(floor(r.position.x)), int(ceil(r.end.x))):
			var ax := x - int(oa.x) + ra.position.x
			var ay := y - int(oa.y) + ra.position.y
			var bx := x - int(ob.x) + rb.position.x
			var by := y - int(ob.y) + rb.position.y
			if ax < ra.position.x or ay < ra.position.y or ax >= ra.end.x or ay >= ra.end.y:
				continue
			if bx < rb.position.x or by < rb.position.y or bx >= rb.end.x or by >= rb.end.y:
				continue
			if ia.get_pixel(ax, ay).a > 0.125 and ib.get_pixel(bx, by).a > 0.125:
				n += 1
	return n


func _hit(im: Image, region: Rect2i, origin: Vector2, p: Vector2) -> bool:
	var x := int(floor(p.x - origin.x)) + region.position.x
	var y := int(floor(p.y - origin.y)) + region.position.y
	if x < region.position.x or y < region.position.y or x >= region.end.x or y >= region.end.y:
		return false
	return im.get_pixel(x, y).a > 0.125


func _allowed(a: String, b: String) -> bool:
	return ALLOW.has("%s|%s|%s" % [map_id, a, b]) or ALLOW.has("%s|%s|%s" % [map_id, b, a])


func _find(kind: String, a: String, b: String, detail: String) -> void:
	if _allowed(a, b):
		return
	findings.append([kind, a, b, detail])


func _main() -> void:
	def = load("res://scripts/levels.gd").DATA[map_id]
	meta = JSON.parse_string(FileAccess.get_file_as_string("res://assets/levels/%s.json" % def["ground"]))
	var blockers: Array = []   # [label, Rect2 충돌(화면 좌표)]
	var pi := 0
	for p in def.get("props", []):
		var nm: String = p[0]
		var im := _img("res://assets/props/%s.png" % nm)
		var at := _lift(Vector2(p[1], p[2]))
		var cond := ""
		if p.size() > 4:
			cond = str(p[4])
		var label := "%s#%d@%d,%d" % [nm, pi, p[1], p[2]]
		pi += 1
		_add_sprite("prop", label, im, Rect2i(0, 0, im.get_width(), im.get_height()),
			at + Vector2(-im.get_width() / 2.0, -im.get_height() + 1), at, ("조건:" + cond) if cond != "" else "")
		var half: Vector2 = OCCLUDE.get(nm, Vector2(3, 3))
		var csz := Vector2(half.x * 2, maxf(2.0, round(half.y * 2 * float(meta.get("k", 1.0)))))
		blockers.append([label, Rect2(at.x - csz.x / 2.0, at.y - csz.y, csz.x, csz.y)])
	for n in def.get("npcs", []):
		var sheet: String = n[1]
		var im := _img("res://assets/sprites/%s.png" % sheet)
		var ch := im.get_height()
		var cw := ch * 2 / 3
		var hf := maxi(1, im.get_width() / cw)
		var frame := 1 if hf >= 5 else 0
		var at := _lift(Vector2(n[2], n[3]))
		var hid: bool = n.size() > 5 and n[5] == "hidden"
		var label := "%s(%s)" % [n[0], n[4]]
		_add_sprite("npc", label, im, Rect2i(frame * cw, 0, cw, ch), at + Vector2(-cw / 2.0, 4 - ch), at, "등장 시" if hid else "")
		blockers.append([label, Rect2(at.x - 6, at.y - 6, 12, 6)])
	# --- 스프라이트 쌍 겹침
	for i in ents.size():
		for j in range(i + 1, ents.size()):
			var a: Dictionary = ents[i]
			var b: Dictionary = ents[j]
			var n := _pix_overlap(a, b)
			if n >= PIX_MIN:
				var d := "%s-%s 불투명 %dpx 겹침 (발 %s / %s)" % [a["kind"], b["kind"], n, a["foot"], b["foot"]]
				_find("OVERLAP", a["name"], b["name"], d)
	# --- 상호작용 지점
	var talk: Array = []   # [label, pos, 등장시]
	for e in ents:
		if e["kind"] == "npc":
			talk.append([e["name"], e["foot"], e["note"]])
	for it in def.get("interact", []):
		var at := _lift(Vector2(it[1], it[2]))
		var lab := "[상호작용]%s@%d,%d" % [it[0], it[1], it[2]]
		talk.append([lab, at, ""])
		for e in ents:
			var inside := _hit(e["img"], e["region"], e["origin"], at) or _hit(e["img"], e["region"], e["origin"], at + Vector2(0, -8))
			if inside and e["foot"].distance_to(at) > 3.0:
				_find("LABEL", lab, e["name"], "상호작용 지점이 %s 스프라이트 위 (거리 %.0fpx)" % [e["name"], e["foot"].distance_to(at)])
	for i in talk.size():
		for j in range(i + 1, talk.size()):
			var dd: float = (talk[i][1] as Vector2).distance_to(talk[j][1])
			if dd < AMBIG_DIST:
				_find("AMBIGUOUS", talk[i][0], talk[j][0], "말 걸기 대상 간격 %.0fpx (< %.0f)" % [dd, AMBIG_DIST])
	# --- 출구·트리거·스폰이 충돌에 막히는지
	var zones: Array = []
	for ex in def.get("exits", []):
		zones.append(["출구→" + str(ex[1]), Rect2(_lift(ex[0].position), _lift_size(ex[0].size))])
	for g in def.get("gates", {}).values():
		zones.append(["문→" + str(g[1]), Rect2(_lift(g[0].position), _lift_size(g[0].size))])
	for tr in def.get("triggers", []):
		zones.append(["트리거:" + str(tr[1]), Rect2(_lift(tr[0].position), _lift_size(tr[0].size))])
	for sp in def.get("spawns", {}).keys():
		var s := _lift(def["spawns"][sp])
		zones.append(["스폰:" + sp, Rect2(s.x - 5, s.y - 3, 10, 3)])
	for z in zones:
		for bl in blockers:
			if (z[1] as Rect2).intersects(bl[1]) :
				_find("BLOCKED", z[0], bl[0], "%s 가 %s 충돌과 겹침" % [z[0], bl[0]])
	# --- 출력
	var out := []
	for f in findings:
		out.append("| %s | %s | %s | %s |" % [f[0], f[1], f[2], f[3]])
		print("FINDING %s | %s | %s | %s" % [f[0], f[1], f[2], f[3]])
	if md_path != "":
		var fa := FileAccess.open(md_path, FileAccess.WRITE)
		fa.store_string("\n".join(out) + ("\n" if out.size() > 0 else ""))
		fa.close()
	print("OVERLAP_RESULT %s %d (소품 %d·NPC %d·상호작용 %d·구역 %d)" % [map_id, findings.size(), pi, def.get("npcs", []).size(), def.get("interact", []).size(), zones.size()])
	quit(0 if findings.is_empty() else 1)
