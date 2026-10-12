class_name TalismanZone
extends Node2D
## 부적이 땅에 남기는 기운 (웹판 Zone 이식).
##   fire — 화염부: 처용 앞 부채꼴 불길. 0.3초마다 5 피해.
##   bind — 결박부: 요괴 발밑 결계. 안의 요괴는 느려지고(bind_t) 0.5초마다 2 피해.

var kind := "fire"
var radius := 58.0
var angle := 0.0          # fire: facing of the cone
var half := 0.6           # fire: half-width of the cone (radians)
var life := 3.0
var _t := 0.0
var _tick := 0.0
var _fx: CPUParticles2D
var _fed := []            # 해태 eats a given fire once, not every tick


func _ready() -> void:
	z_index = 39
	z_as_relative = false
	_fx = CPUParticles2D.new()
	_fx.amount = 40 if kind == "fire" else 26
	_fx.lifetime = 0.6 if kind == "fire" else 1.2
	_fx.gravity = Vector2(0, -30 if kind == "fire" else -8)
	_fx.initial_velocity_min = 4.0
	_fx.initial_velocity_max = 14.0
	_fx.scale_amount_min = 1.5
	_fx.scale_amount_max = 3.0
	var add := CanvasItemMaterial.new()
	add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	add.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	_fx.material = add
	if kind == "fire":
		_fx.emission_shape = CPUParticles2D.EMISSION_SHAPE_POINTS
		var pts := PackedVector2Array()
		for i in 48:
			var a := angle + randf_range(-half, half)
			pts.append(Vector2.from_angle(a) * randf_range(8.0, radius) * Vector2(1.0, 0.6))
		_fx.emission_points = pts
		var g := Gradient.new()
		g.colors = PackedColorArray([Color(1.0, 0.85, 0.4, 0.9), Color(1.0, 0.45, 0.15, 0.7), Color(0.6, 0.1, 0.05, 0.0)])
		_fx.color_ramp = g
	else:
		_fx.emission_shape = CPUParticles2D.EMISSION_SHAPE_POINTS
		var pts := PackedVector2Array()
		for i in 48:
			pts.append(Vector2.from_angle(i * TAU / 48.0) * Vector2(radius, radius * 0.6) * randf_range(0.85, 1.0))
		_fx.emission_points = pts
		_fx.color = Color(0.7, 1.0, 0.45, 0.7)
	add_child(_fx)
	if kind == "bind":
		var ring := Line2D.new()
		for i in 41:
			ring.add_point(Vector2.from_angle(i * TAU / 40.0) * Vector2(radius, radius * 0.6))
		ring.width = 1.5
		ring.default_color = Color(0.75, 1.0, 0.5, 0.55)
		ring.material = add
		add_child(ring)


func _physics_process(delta: float) -> void:
	_t += delta
	_tick -= delta
	if kind == "bind":
		for e in get_tree().get_nodes_in_group("enemy"):
			if _inside(e) and "bind_t" in e:
				e.bind_t = 0.2
	if _tick <= 0.0:
		_tick = 0.3 if kind == "fire" else 0.5
		for e in get_tree().get_nodes_in_group("enemy"):
			if not _inside(e) or not e.has_method("take_hit"):
				continue
			if kind == "fire" and e.get("kind") == "haetae":
				if not e in _fed and e.absorb_talisman():
					_fed.append(e)   # 해태는 불을 먹는다
				continue
			e.take_hit(5 if kind == "fire" else 2, Vector2.ZERO, false, true)
	if _t >= life - 0.4:
		_fx.emitting = false
	if _t >= life:
		queue_free()


func _inside(e: Node2D) -> bool:
	var to := e.global_position - global_position
	var flat := Vector2(to.x, to.y / 0.6)   # the ground ellipse
	if flat.length() > radius + 6.0:
		return false
	return kind != "fire" or absf(wrapf(to.angle() - angle, -PI, PI)) < half + 0.2 or to.length() < 10.0
