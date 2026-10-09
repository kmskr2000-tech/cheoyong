class_name MiasmaVent
extends Node2D
## 독기 함정 (SC1-14): a crack in the floorboards that breathes 탁기 on a cycle —
## quiet, then a few warning wisps, then a choking burst that hurts anyone standing in it.

const R := 18.0
const QUIET := 2.4
const WARN := 0.7
const BURST := 1.3
var t := 0.0
var phase_off := 0.0
var _puff: CPUParticles2D
var _cloud: CPUParticles2D
var _hit_cd := 0.0
var _glow: PointLight2D


func _ready() -> void:
	t = phase_off
	_puff = _particles(4, 0.9, Vector2(4, 2), 6.0, Color(0.4, 0.2, 0.55, 0.6), 1.5)
	_cloud = _particles(40, 1.1, Vector2(R * 0.8, R * 0.35), 20.0, Color(0.32, 0.12, 0.42, 0.7), 4.0)
	# the crack itself
	var crack := Line2D.new()
	crack.points = PackedVector2Array([Vector2(-8, 1), Vector2(-3, -1), Vector2(1, 1), Vector2(6, -1), Vector2(9, 0)])
	crack.width = 1.0
	crack.default_color = Color(0.05, 0.02, 0.08)
	crack.z_index = -4
	crack.z_as_relative = false
	add_child(crack)
	_glow = PointLight2D.new()
	var g := Gradient.new()
	g.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0)])
	var gt := GradientTexture2D.new()
	gt.gradient = g
	gt.fill = GradientTexture2D.FILL_RADIAL
	gt.fill_from = Vector2(0.5, 0.5)
	gt.fill_to = Vector2(1.0, 0.5)
	gt.width = 64
	gt.height = 64
	_glow.texture = gt
	_glow.color = Color(0.6, 0.3, 0.9)
	_glow.energy = 0.5
	add_child(_glow)


func _particles(n: int, life: float, ext: Vector2, vel: float, col: Color, size: float) -> CPUParticles2D:
	var p := CPUParticles2D.new()
	p.amount = n
	p.lifetime = life
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.emission_rect_extents = ext
	p.direction = Vector2(0, -1)
	p.spread = 30.0
	p.gravity = Vector2(0, -6)
	p.initial_velocity_min = vel * 0.4
	p.initial_velocity_max = vel
	p.scale_amount_min = size * 0.6
	p.scale_amount_max = size
	p.color = col
	p.emitting = false
	p.z_index = 30
	p.z_as_relative = false
	add_child(p)
	return p


func _physics_process(delta: float) -> void:
	t = fmod(t + delta, QUIET + WARN + BURST)
	_puff.emitting = t >= QUIET and t < QUIET + WARN
	var bursting := t >= QUIET + WARN
	_cloud.emitting = bursting
	_glow.energy = 1.6 if bursting else (1.0 if _puff.emitting else 0.5)
	_hit_cd -= delta
	if bursting and _hit_cd <= 0.0:
		var p: Node2D = get_tree().current_scene.get_node_or_null("Player")
		if p and p.global_position.distance_to(global_position) < R and p.has_method("hurt"):
			p.hurt(6, (p.global_position - global_position).normalized())
			_hit_cd = 0.6
