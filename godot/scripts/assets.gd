# Assets: the packed PixelLab sprites (manifest from art/pack.py) and frame lookup by animation and direction.
extends Node

var chars := {}   # name -> {tex, w, h, foot, top, cx, scale, anims}
var tiles := {}   # name -> {tex, size, by_corners}
var props := {}   # name -> {tex, w, h, ax, ay, bw, scale}
var font: Font
var font_bold: Font
var font_black: Font
var font_dmg: Font
var font_serif: Font       # Gowun Batang: dialogue, narration, story text
var font_serif_bold: Font
var font_title: Font       # Song Myung: chapter titles, verses, the title screen

const DIR_IDX := {"east": 0, "south-east": 1, "south": 2, "south-west": 3, "west": 4, "north-west": 5, "north": 6, "north-east": 7}
const MIRROR := {"east": "west", "west": "east", "south-east": "south-west", "south-west": "south-east", "north-east": "north-west", "north-west": "north-east"}

func _ready() -> void:
	font = load("res://fonts/Pretendard-Regular.otf")
	font_bold = load("res://fonts/Pretendard-Bold.otf")
	font_black = load("res://fonts/Pretendard-Black.otf")
	# MSDF keeps text sharp when the canvas is scaled down on phones or up on tablets
	font_serif = load("res://fonts/GowunBatang-Regular.ttf")
	font_serif_bold = load("res://fonts/GowunBatang-Bold.ttf")
	font_title = load("res://fonts/SongMyung-Regular.ttf")
	for f in [font, font_bold, font_black, font_serif, font_serif_bold, font_title]:
		f.multichannel_signed_distance_field = true
		f.msdf_pixel_range = 16
		f.msdf_size = 48
	var fv := FontVariation.new()
	fv.base_font = font_black
	fv.variation_transform = Transform2D(Vector2(1, 0), Vector2(0.22, 1), Vector2.ZERO)  # slanted damage numbers
	font_dmg = fv
	var man: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/manifest.json"))
	for n in man.chars:
		var c: Dictionary = man.chars[n]
		c.tex = load("res://assets/" + c.file)
		c.white = load("res://assets/" + c.white)
		c.scale = float(c.get("scale", 1.0))
		chars[n] = c
	for n in man.tiles:
		var t: Dictionary = man.tiles[n]
		var by := {}
		for i in t.tiles.size():
			var k: String = t.tiles[i]
			if not by.has(k): by[k] = []
			by[k].append(i)
		tiles[n] = {"tex": load("res://assets/" + t.file), "size": int(t.get("size", 32)), "by": by}
	for n in man.props:
		var p: Dictionary = man.props[n]
		p.tex = load("res://assets/" + p.file)
		p.scale = float(p.get("scale", 1.0))
		props[n] = p

func has_anim(name: String, anim: String) -> bool:
	return chars.has(name) and chars[name].anims.has(anim)

func anim_len(name: String, anim: String, dir: String) -> int:
	if not has_anim(name, anim): return 0
	var a: Dictionary = chars[name].anims[anim]
	return a[dir].size() if a.has(dir) else a.values()[0].size()

# -> {c, src: Rect2, mirror, n, i} or {} when the character is missing
func frame(name: String, anim: String, dir: String, t: float, fps := 10.0, loop := true) -> Dictionary:
	if not chars.has(name): return {}
	var c: Dictionary = chars[name]
	var a: Dictionary = c.anims.get(anim, c.anims.idle)
	var fr = a.get(dir)
	var mirror := false
	if fr == null:
		if MIRROR.has(dir) and a.has(MIRROR[dir]):
			fr = a[MIRROR[dir]]; mirror = true
		else:
			var want: int = DIR_IDX.get(dir, 2)
			var best = null; var bd := 9
			for d in a:
				var k: int = DIR_IDX[d]
				var dd: int = min(abs(k - want), 8 - abs(k - want))
				if dd < bd: bd = dd; best = d
			fr = a[best]
			if bd > 2:
				a = c.anims.idle
				fr = a.get(dir, a.get("south"))
	var n: int = fr.size()
	var i := int(t * fps)
	i = i % n if loop else min(i, n - 1)
	return {"c": c, "src": Rect2(fr[i][0], fr[i][1], c.w, c.h), "mirror": mirror, "n": n, "i": i}
