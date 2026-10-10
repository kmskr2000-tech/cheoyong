class_name PlagueGod
extends CharacterBody2D
## 역신 (疫神) boss. Floats toward 처용 and cycles patterns (as in the original web chapter):
##   fog    — marks 3 (phase 2: 4) circles, then they become lingering poison fog
##   cough  — a red cone tell aimed at 처용, then a plague breath down that cone (twice in phase 2)
##   clones — raises its arms and calls up 역귀 졸개
##   pulse  — if 처용 hugs it for too long: a ring tell, then a shockwave that throws him back
## Below half HP it enters phase 2 (faster, harsher). Defeat: purification, the god thins into light.

signal hp_changed(hp: float, max_hp: float)
signal defeated
signal knelt
signal phase_two

const CELL := Vector2i(120, 164)   # art/boss3d.py: over three times a man's height
const FEET_ROW := 158.0
const MAX_HP := 480.0  # 1장 첫 보스: 대금 콤보 열두어 번
const ANIMS := {"idle": [0, 1, 2, 3], "cast": [4], "swipe": [5], "hurt": [6], "human": [7]}

var hp := MAX_HP
var phase := 1
var state := "idle"
var st := 0.0
var pat_i := 0
var close_t := 0.0
var flash := 0.0
var knock := Vector2.ZERO
var bind_t := 0.0             # 결박부: held to a crawl
var aim := 0.0
var coughs := 0
var sprite: AnimatedSprite2D
var target: Node2D
var tells: Array[Node2D] = []


func _ready() -> void:
	add_to_group("enemy")
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	var col := CollisionShape2D.new()
	var sh := RectangleShape2D.new()
	sh.size = Vector2(52, 14)   # the hem of the robe
	col.shape = sh
	col.position = Vector2(0, -7)
	add_child(col)
	sprite = AnimatedSprite2D.new()
	var tex: Texture2D = Tex.lit("res://assets/sprites/plague_god.png")
	var frames := SpriteFrames.new()
	frames.remove_animation("default")
	for a in ANIMS:
		frames.add_animation(a)
		frames.set_animation_speed(a, 5.0)
		for i in ANIMS[a]:
			var at := AtlasTexture.new()
			at.atlas = tex
			at.region = Rect2(i * CELL.x, 0, CELL.x, CELL.y)
			frames.add_frame(a, at)
	sprite.sprite_frames = frames
	sprite.offset = Vector2(0, CELL.y / 2.0 - FEET_ROW)
	sprite.play("idle")
	add_child(sprite)
	# miasma always seeping from the hem
	var mi := CPUParticles2D.new()
	mi.amount = 60
	mi.lifetime = 2.0
	mi.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	mi.emission_rect_extents = Vector2(36, 4)
	mi.position = Vector2(0, -4)
	mi.direction = Vector2(0, -1)
	mi.gravity = Vector2(0, -12)
	mi.initial_velocity_min = 4.0
	mi.initial_velocity_max = 12.0
	mi.scale_amount_min = 2.0
	mi.scale_amount_max = 4.0
	mi.color = Color(0.45, 0.85, 0.35, 0.35)
	mi.z_index = -1
	add_child(mi)
	var aura := PointLight2D.new()
	aura.texture = _radial()
	aura.color = Color(0.45, 0.95, 0.4)
	aura.energy = 0.8
	aura.texture_scale = 1.8
	aura.position = Vector2(0, -80)
	add_child(aura)
	target = get_tree().current_scene.get_node_or_null("Player")


static func _radial() -> Texture2D:
	var g := Gradient.new()
	g.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0)])
	var t := GradientTexture2D.new()
	t.gradient = g
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.5)
	t.fill_to = Vector2(1, 0.5)
	t.width = 128
	t.height = 128
	return t


func _physics_process(delta: float) -> void:
	st += delta
	flash = maxf(0.0, flash - delta)
	knock = knock.move_toward(Vector2.ZERO, 500.0 * delta)
	sprite.modulate = Color(2.4, 2.4, 2.4) if flash > 0.0 else Color.WHITE
	if state == "dead" or state == "kneel" or state == "wait" or target == null:
		return
	var to := target.global_position - global_position
	var d := to.length()
	var fast := 1.35 if phase == 2 else 1.0
	var v := Vector2.ZERO
	close_t = close_t + delta if d < 58.0 else 0.0
	match state:
		"idle":
			sprite.play("idle")
			if d > 96.0:
				v = to.normalized() * 26.0 * fast
			if close_t > 1.6:
				_begin("pulse")
			elif st > (1.0 if phase == 2 else 1.4):
				_next_pattern()
		"fog":
			sprite.play("cast")
			if st > 0.9 / fast:
				for t in tells:
					_poison(t.position)
				_clear_tells()
				_begin("idle")
		"cough":
			sprite.play("swipe")
			if st > 1.0 / fast:
				_clear_tells()
				_breath()
				coughs += 1
				if phase == 2 and coughs < 2:
					_begin("cough_again")
				else:
					_begin("idle")
		"cough_again":
			_aim_cough()
			state = "cough"; st = 0.45
		"clones":
			sprite.play("cast")
			if st > 0.8:
				for i in (3 if phase == 2 else 2):
					var g := Enemy.new()
					g.kind = "ghoul"
					g.position = position + Vector2.from_angle(randf() * TAU) * 40.0
					get_parent().add_child(g)
					g.state = "chase"
				_begin("idle")
		"pulse":
			sprite.play("cast")
			if st > 0.6:
				_clear_tells()
				_ring(position, 80.0, Color(0.6, 1.0, 0.5))
				if d < 80.0 and target.has_method("hurt"):
					target.hurt(12, to.normalized())
				close_t = 0.0
				_begin("idle")
		"hurt":
			sprite.play("hurt")
			if st > 0.2:
				_begin("idle")
	bind_t = maxf(0.0, bind_t - get_physics_process_delta_time())
	velocity = v * (0.35 if bind_t > 0.0 else 1.0) + knock
	_slide()
	sprite.flip_h = to.x < 0


## SC1-15: sits in human guise (state "wait") until the story wakes it
func disguise() -> void:
	state = "wait"
	sprite.play("human")


func awaken() -> void:
	Audio.override("boss")
	_ring(position, 70.0, Color(0.6, 1.0, 0.5))
	sprite.play("idle")
	_begin("idle")


func _begin(s: String) -> void:
	state = s
	st = 0.0


func _next_pattern() -> void:
	var cycle := ["fog", "cough", "clones", "cough", "fog", "clones"] if phase == 2 else ["fog", "cough", "clones", "cough"]
	var p: String = cycle[pat_i % cycle.size()]
	pat_i += 1
	match p:
		"fog":
			for i in (4 if phase == 2 else 3):
				var at := target.global_position + Vector2.from_angle(randf() * TAU) * randf_range(0, 50)
				tells.append(_mark(at, 22.0))
			_begin("fog")
		"cough":
			coughs = 0
			_aim_cough()
			_begin("cough")
		"clones":
			_begin("clones")
		"pulse":
			_begin("pulse")


# ---------------------------------------------------------------- attacks and their tells
func _aim_cough() -> void:
	_clear_tells()
	aim = (target.global_position - global_position).angle()
	var cone := Polygon2D.new()
	var pts := PackedVector2Array([Vector2.ZERO])
	for i in 9:
		pts.append(Vector2.from_angle(aim - 0.5 + i * 0.125) * 120.0)
	cone.polygon = pts
	cone.color = Color(1.0, 0.25, 0.2, 0.28)
	cone.position = position + Vector2(0, -8)
	_world_fx(cone)
	tells.append(cone)


func _breath() -> void:
	for i in 26:
		var p := Sprite2D.new()
		p.texture = load("res://assets/fx/spark.png")
		p.hframes = 3
		p.frame = 1
		p.modulate = Color(0.5, 1.0, 0.35, 0.9)
		p.position = position + Vector2(0, -8)
		_world_fx(p)
		var dir := Vector2.from_angle(aim + randf_range(-0.45, 0.45))
		var tw := p.create_tween().set_parallel()
		tw.tween_property(p, "position", p.position + dir * randf_range(60, 120), 0.45)
		tw.tween_property(p, "modulate:a", 0.0, 0.5)
		tw.chain().tween_callback(p.queue_free)
	var to := target.global_position - global_position
	if to.length() < 125.0 and absf(wrapf(to.angle() - aim, -PI, PI)) < 0.55 and target.has_method("hurt"):
		target.hurt(14, to.normalized())


func _mark(at: Vector2, r: float) -> Node2D:
	var ring := Line2D.new()
	for i in 25:
		ring.add_point(Vector2.from_angle(i * TAU / 24) * Vector2(r, r * 0.55))
	ring.width = 1.0
	ring.default_color = Color(1.0, 0.3, 0.25, 0.9)
	ring.position = at
	_world_fx(ring)
	return ring


func _poison(at: Vector2) -> void:
	var z := Area2D.new()
	z.position = at
	var fog := CPUParticles2D.new()
	fog.amount = 24
	fog.lifetime = 1.4
	fog.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	fog.emission_sphere_radius = 16.0
	fog.gravity = Vector2(0, -6)
	fog.scale_amount_min = 3.0
	fog.scale_amount_max = 6.0
	fog.color = Color(0.45, 0.9, 0.35, 0.3)
	z.add_child(fog)
	_world_fx(z)
	var tw := z.create_tween()
	tw.tween_interval(4.5)
	tw.tween_callback(z.queue_free)
	# damage over time while 처용 stands in it
	var t := Timer.new()
	t.wait_time = 0.5
	t.autostart = true
	t.timeout.connect(func():
		if is_instance_valid(target) and target.global_position.distance_to(z.global_position) < 22.0 and target.has_method("hurt"):
			target.hurt(5, Vector2.ZERO))
	z.add_child(t)


func _ring(at: Vector2, r: float, col: Color) -> void:
	var ring := Line2D.new()
	for i in 33:
		ring.add_point(Vector2.from_angle(i * TAU / 32) * Vector2(1, 0.55))
	ring.width = 2.0
	ring.default_color = col
	ring.position = at + Vector2(0, -4)
	_world_fx(ring)
	var tw := ring.create_tween().set_parallel()
	tw.tween_property(ring, "scale", Vector2(r, r), 0.3)
	tw.tween_property(ring, "width", 0.05, 0.3)
	tw.tween_property(ring, "modulate:a", 0.0, 0.35)
	tw.chain().tween_callback(ring.queue_free)


func _world_fx(n: Node2D) -> void:
	var add := CanvasItemMaterial.new()
	add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	add.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	n.material = add
	n.z_index = 30
	n.z_as_relative = false
	get_parent().add_child(n)


func _clear_tells() -> void:
	for t in tells:
		if is_instance_valid(t):
			t.queue_free()
	tells.clear()


# ---------------------------------------------------------------- taking hits
func take_hit(dmg: int, dir: Vector2, heavy := false, quiet := false) -> void:
	if state not in ["dead", "kneel", "wait"] and not quiet:
		Audio.sfx("hit", -3.0)
	if state == "dead" or state == "kneel" or state == "wait":
		return
	hp -= dmg
	flash = 0.08
	knock = dir * (60.0 if heavy else 30.0)
	hp_changed.emit(hp, MAX_HP)
	if phase == 1 and hp <= MAX_HP * 0.5:
		phase = 2
		_ring(position, 90.0, Color(0.7, 1.0, 0.5))
		sprite.self_modulate = Color(1.1, 1.25, 1.0)
		phase_two.emit()
	if hp <= 0.0:
		_kneel()


## 무릎 꿇는 자: at 0 HP the god sinks to its knees; only the song ends it (purify()).
func _kneel() -> void:
	state = "kneel"
	_clear_tells()
	remove_from_group("enemy")
	add_to_group("downed")
	for e in get_tree().get_nodes_in_group("enemy"):
		e.take_hit(999, Vector2.ZERO)
	sprite.play("hurt")
	sprite.position.y = 8.0
	knelt.emit()


func purify() -> void:
	if state == "kneel":
		remove_from_group("downed")
		_defeat()


func _defeat() -> void:
	Audio.sfx("purify", 0.0, 0.0)
	Audio.override("")
	state = "dead"
	_clear_tells()
	remove_from_group("enemy")
	Game.reward_purify("plague_god", global_position, get_parent())
	if not "역신의 눈물" in Game.accessories:
		Game.accessories.append("역신의 눈물")
		Game.say_toast("장신구 「역신의 눈물」을 얻었다", Color(0.75, 0.95, 0.7))
	for e in get_tree().get_nodes_in_group("downed"):
		e.purify()
	defeated.emit()
	sprite.play("hurt")
	var tw := create_tween()
	for i in 6:
		tw.tween_callback(_ring.bind(position, 40.0 + i * 12.0, Color(0.7, 0.9, 1.0)))
		tw.tween_interval(0.25)
	tw.tween_callback(func(): sprite.play("human"))
	tw.tween_property(sprite, "modulate", Color(0.8, 0.95, 1.5, 0.0), 1.6)
	tw.tween_callback(queue_free)


## move_and_slide with the depth foreshortening: on the flattened ground, going up or down the
## screen covers fewer pixels than going sideways (velocity itself stays in footprint units)
func _slide() -> void:
	var vy := velocity.y
	velocity.y *= Game.depth_k
	move_and_slide()
	velocity.y = vy
