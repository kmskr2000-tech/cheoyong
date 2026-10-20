# Global helpers: constants, math, seeded random, value noise, launch parameters (test hooks).
extends Node

const TILE := 32
const VIEW_H := 600.0
const DIR8 := ["east", "south-east", "south", "south-west", "west", "north-west", "north", "north-east"]

var params := {}
var view_w := 1280.0
var game = null   # set by main: the Game node
var world = null  # World (map data)
var state := "loading"

func _ready() -> void:
	# --key=value after "--" on the command line, or ?key=value on the web
	for a in OS.get_cmdline_user_args():
		var s: String = a.trim_prefix("--")
		var i := s.find("=")
		if i >= 0:
			params[s.substr(0, i)] = s.substr(i + 1)
		else:
			params[s] = ""
	if OS.has_feature("web"):
		var q = JavaScriptBridge.eval("location.search", true)
		if q is String and q.length() > 1:
			for kv in (q as String).substr(1).split("&"):
				var p = kv.split("=")
				params[p[0]] = p[1].uri_decode() if p.size() > 1 else ""

func has(k: String) -> bool:
	return params.has(k)

func param(k: String, def := "") -> String:
	return str(params.get(k, def))

# ---------- math ----------
func angdiff(a: float, b: float) -> float:
	var d := b - a
	while d > PI: d -= TAU
	while d < -PI: d += TAU
	return d

func ease_out(t: float) -> float:
	return 1.0 - (1.0 - t) * (1.0 - t)

func dir_from_angle(a: float) -> String:
	return DIR8[posmod(int(round(a / (PI / 4.0))), 8)]

# ---------- 32-bit integer hash and noise ----------
func _i32(v: int) -> int:
	v = v & 0xFFFFFFFF
	return v - 0x100000000 if v >= 0x80000000 else v

func _imul(a: int, b: int) -> int:
	return _i32((a & 0xFFFFFFFF) * (b & 0xFFFFFFFF))

func hash2(x: int, y: int, seed := 0) -> float:
	var h := _i32(x * 374761393 + y * 668265263 + seed * 2147483647)
	h = _imul(h ^ ((h & 0xFFFFFFFF) >> 13), 1274126177)
	return float((h ^ ((h & 0xFFFFFFFF) >> 16)) & 0xFFFFFFFF) / 4294967296.0

func noise(x: float, y: float, seed := 0) -> float:
	var xi := int(floor(x)); var yi := int(floor(y))
	var xf := x - xi; var yf := y - yi
	var u := xf * xf * (3.0 - 2.0 * xf); var v := yf * yf * (3.0 - 2.0 * yf)
	var a := hash2(xi, yi, seed); var b := hash2(xi + 1, yi, seed)
	var c := hash2(xi, yi + 1, seed); var d := hash2(xi + 1, yi + 1, seed)
	return lerpf(lerpf(a, b, u), lerpf(c, d, u), v)

func fbm(x: float, y: float, seed := 0) -> float:
	return noise(x, y, seed) * 0.6 + noise(x * 2.1, y * 2.1, seed + 9) * 0.3 + noise(x * 4.3, y * 4.3, seed + 17) * 0.1

# xorshift32 generator, same sequence on every platform
class Rng:
	var s: int
	func _init(seed: int) -> void:
		s = seed & 0xFFFFFFFF
		if s == 0: s = 1
	func next() -> float:
		s ^= (s << 13) & 0xFFFFFFFF
		s ^= s >> 17
		s ^= (s << 5) & 0xFFFFFFFF
		s &= 0xFFFFFFFF
		return float(s) / 4294967296.0
