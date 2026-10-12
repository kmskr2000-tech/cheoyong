extends RefCounted
## 전투 전략 신호 이펙트 (아트팀, 2026-10-12). 모든 스프라이트는 art/fx.py 가 도트 격자·공용 팔레트로 그린 시트다 (가산 혼합).
## 호출: `const CFX := preload("res://scripts/fx/combat_fx.gd")` → `CFX.parry(player)` 등. 전투 수치는 다루지 않는다 — 보이는 것만.
##   parry · charge_aura · full_flash · pierce · guard · pop_text · open_mark · bind_mark · synergy · purify · downed_sigil
## 시트 규격: parry 6×48 / aura 4×3 행×40 / fullflash 5×48 / pierce 6×2 행×56 / guard 6×40 / weak 4×16 / open 3×2 행×48×24 /
##            bindmark 4×2 행×20 / purify 8×48×64 / downed 4×40×20 / tellock 5×32

const MARK := preload("res://scripts/fx/weak_mark.gd")
const BMARK := preload("res://scripts/fx/bind_mark.gd")
const FONT := "res://assets/fonts/Galmuri11.ttf"
const COL_KI := Color(0.55, 0.9, 1.0)        # 소리 (파랑)
const COL_GUARD := Color(1.0, 0.86, 0.45)    # 수호부 (금)
const COL_FIRE := Color(1.0, 0.62, 0.25)     # 화염 (주황)
const COL_OPEN := Color(1.0, 0.8, 0.4)

static var _add: CanvasItemMaterial
static var _tex := {}
static var _syn_ms := -9999


static func additive() -> CanvasItemMaterial:
	if _add == null:
		_add = CanvasItemMaterial.new()
		_add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		_add.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	return _add


static func tex(name: String) -> Texture2D:
	if not _tex.has(name):
		_tex[name] = load("res://assets/fx/%s.png" % name)
	return _tex[name]


## 시트 스프라이트: 중심 pos(월드). frames=열 수, rows=행 수.
static func sheet(name: String, frames: int, rows := 1, row := 0) -> Sprite2D:
	var s := Sprite2D.new()
	s.texture = tex(name)
	s.hframes = frames
	s.vframes = rows
	s.frame = row * frames
	s.material = additive()
	s.z_index = 42
	s.z_as_relative = false
	return s


## 한 번 재생하고 사라진다. real=true 면 슬로모션(Engine.time_scale)에 영향받지 않는다 — 시간이 멈춘 순간에도 번쩍임은 흐른다.
static func play_once(parent: Node, at: Vector2, name: String, frames: int, fps: float, scale := 1.0, rows := 1, row := 0, real := false, rot := 0.0) -> Sprite2D:
	var s := sheet(name, frames, rows, row)
	s.global_position = at
	s.scale = Vector2(scale, scale)
	s.rotation = rot
	parent.add_child(s)
	var tw := s.create_tween()
	if real:
		tw.set_ignore_time_scale(true)
	var t0 := row * frames
	tw.tween_method(func(v: float): s.frame = t0 + mini(frames - 1, int(v)), 0.0, float(frames), float(frames) / fps)
	tw.tween_callback(s.queue_free)
	return s


static func font() -> Font:
	return DialogBox._pixel_font(FONT)


## 도트 글씨 팝업(+8 소리 같은 수치 표시). 세로로 떠올라 사라진다.
static func pop_text(parent: Node, at: Vector2, text: String, col: Color, size := 11, real := false) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", font())
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_outline_color", Color(0.02, 0.02, 0.07))
	l.add_theme_constant_override("outline_size", 4)
	l.size = Vector2(70, 14)
	l.position = at - Vector2(35, 7)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.z_index = 49
	l.z_as_relative = false
	l.scale = Vector2(1.5, 1.5)
	l.pivot_offset = Vector2(35, 7)
	parent.add_child(l)
	var tw := l.create_tween().set_parallel()
	if real:
		tw.set_ignore_time_scale(true)
	tw.tween_property(l, "scale", Vector2.ONE, 0.12)
	tw.tween_property(l, "position:y", l.position.y - 16, 1.1)
	tw.tween_property(l, "modulate:a", 0.0, 0.4).set_delay(0.7)
	tw.chain().tween_callback(l.queue_free)
	return l


## 전체 화면 번쩍임/가림막: 색, 최대 알파, 길이(실시간 초). 시간 정지감용 흰 섬광과 푸른 가림막.
static func screen_flash(tree: SceneTree, col: Color, sec: float) -> void:
	var layer := CanvasLayer.new()
	layer.layer = 80
	var r := ColorRect.new()
	r.color = col
	r.size = Vector2(480, 270)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(r)
	tree.current_scene.add_child(layer)
	var tw := r.create_tween()
	tw.set_ignore_time_scale(true)
	tw.tween_property(r, "color:a", 0.0, sec).set_ease(Tween.EASE_OUT)
	tw.tween_callback(layer.queue_free)


## 가장자리에서 안쪽으로 이름표 클램프: 화면 밖으로 잘리지 않게 라벨의 가로 위치를 보정한다 (margin: 화면 가장자리 여백, px)
static func clamp_label(lbl: Control, margin := 3.0) -> void:
	if not lbl.is_inside_tree():
		return
	var vp := lbl.get_viewport_rect().size
	var r := lbl.get_global_transform_with_canvas()
	var left: float = r.origin.x
	var right: float = left + lbl.size.x * r.get_scale().x
	var top: float = r.origin.y
	var dy := 0.0
	if top < margin:
		dy = margin - top
	if dy != 0.0:
		lbl.position.y += dy / r.get_scale().y
	var dx := 0.0
	if left < margin:
		dx = margin - left
	elif right > vp.x - margin:
		dx = (vp.x - margin) - right
	if dx != 0.0:
		lbl.position.x += dx / r.get_scale().x


## 역신 열림: 화면 가장자리에 약한 금빛 비네트가 깃들었다 걷힌다 (시선이 보스의 열린 몸으로 모인다)
static func vignette(tree: SceneTree, sec: float) -> void:
	var layer := CanvasLayer.new()
	layer.layer = 79
	var g := GradientTexture2D.new()
	g.fill = GradientTexture2D.FILL_RADIAL
	g.fill_from = Vector2(0.5, 0.5)
	g.fill_to = Vector2(1.0, 0.5)
	g.width = 120
	g.height = 68
	var grad := Gradient.new()
	grad.colors = PackedColorArray([Color(1.0, 0.75, 0.3, 0.0), Color(1.0, 0.75, 0.3, 0.0), Color(1.0, 0.7, 0.25, 0.22)])
	grad.offsets = PackedFloat32Array([0.0, 0.62, 1.0])
	g.gradient = grad
	var tr := TextureRect.new()
	tr.texture = g
	tr.size = Vector2(480, 270)
	tr.stretch_mode = TextureRect.STRETCH_SCALE
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tr.modulate.a = 0.0
	layer.add_child(tr)
	tree.current_scene.add_child(layer)
	var tw := tr.create_tween()
	tw.tween_property(tr, "modulate:a", 1.0, 0.12)
	tw.tween_interval(maxf(0.0, sec - 0.3))
	tw.tween_property(tr, "modulate:a", 0.0, 0.18)
	tw.tween_callback(layer.queue_free)


# ---------------------------------------------------------------- 받아넘기기 성공
## 흰 섬광 + 시간 정지감(화면 푸른 가림막) + "+8 소리". 플레이어가 호출한다.
static func parry(pl: Node2D, ki_gain: float) -> void:
	var par := pl.get_parent()
	var at := pl.global_position + Vector2(0, -16)
	play_once(par, at, "parry", 6, 22.0, 0.8, 1, 0, true)   # 작은 중심 섬광
	play_once(par, at, "parry", 6, 16.0, 1.5, 1, 0, true)   # 바깥 파문: 가장자리 위주 링
	screen_flash(pl.get_tree(), Color(1, 1, 1, 0.16), 0.12)
	screen_flash(pl.get_tree(), Color(0.2, 0.3, 0.7, 0.12), 0.4)   # 시간이 멈춘 듯한 푸른 가라앉음
	# 글자 분리: "받아넘기기"(player.gd, 머리 위)가 먼저, "+8 소리"는 섬광이 걷힌 0.18초(실시간) 뒤 옆으로
	pl.get_tree().create_timer(0.18, true, false, true).timeout.connect(func():
		if is_instance_valid(pl) and pl.is_inside_tree():
			pop_text(pl.get_parent(), pl.global_position + Vector2(34, -30), "+%d 소리" % int(ki_gain), COL_KI, 11, true))


# ---------------------------------------------------------------- 강 베기 충전
## 발치 충전 오라 (Line2D 링 아래에 붙인다). 충전 단계 row: 0 모으는 중 · 1 발동 가능(≥CHARGE_MIN) · 2 만충.
static func make_aura(parent: Node, material: Material) -> Sprite2D:
	var s := sheet("aura", 4, 3, 0)
	s.material = material
	s.position = Vector2(0, -12)
	s.z_index = 0
	s.z_as_relative = true
	s.scale = Vector2(1.25, 1.25)
	parent.add_child(s)
	return s


static func aura_step(s: Sprite2D, c: float, ready_at: float, full_at: float) -> void:
	var row := 2 if c >= full_at else 1 if c >= ready_at else 0
	s.frame = row * 4 + int(c * 12.0) % 4
	s.scale = Vector2(1.25, 1.25) * (1.0 + (0.08 if row == 2 else 0.0) * sin(c * 30.0))


## 만충 번쩍임: 황금 해 + 몸이 잠깐 밝아진다
static func full_flash(pl: Node2D, body: CanvasItem) -> void:
	play_once(pl.get_parent(), pl.global_position + Vector2(0, -14), "fullflash", 5, 18.0, 1.1)
	var tw := body.create_tween()
	tw.tween_property(body, "modulate", Color(1.7, 1.55, 1.15), 0.05)
	tw.tween_property(body, "modulate", Color(1.35, 1.25, 1.0), 0.2)


# ---------------------------------------------------------------- 강 베기 적중 (장갑 무시)
## pos: 적 중심, dir: 베는 방향, tt: 충전 0~1, armored: 장갑이 있는 적(껍질이 깨져 튄다)
static func pierce(parent: Node, pos: Vector2, dir: Vector2, tt: float, armored: bool) -> void:
	var sc := 0.8 + 0.5 * tt
	play_once(parent, pos, "pierce", 6, 20.0, sc, 2, 1 if armored else 0, false, dir.angle())
	if armored:
		pop_text(parent, pos + Vector2(0, -34), "관통", COL_GUARD, 11)


# ---------------------------------------------------------------- 수호부
## 막았다. last=true 면 마지막 충전이 깨진 것(큰 육각 부적 파편 + 소리 환급 표시).
static func guard(pl: Node2D, last: bool, refund := 0.0) -> void:
	var par := pl.get_parent()
	var at := pl.global_position + Vector2(0, -16)
	play_once(par, at, "guard", 6, 16.0 if last else 22.0, 1.5 if last else 1.0)
	if last and refund > 0.0:
		pop_text(par, pl.global_position + Vector2(0, -68), "+%d 소리" % int(refund), COL_GUARD, 11)


# ---------------------------------------------------------------- 열림(후딜) 단서
## host(Enemy/PlagueGod)가 sec 초 동안 열린다: 발밑 금붉은 고리 + 머리 위 약점 표식. big=역신.
static func open_mark(host: Node2D, sec: float, big := false) -> void:
	var old := host.get_node_or_null("OpenMark")
	if old:
		old.queue_free()
	var m: Node2D = MARK.new()
	m.name = "OpenMark"
	m.sec = sec
	m.big = big
	host.add_child(m)


# ---------------------------------------------------------------- 결박 · 시너지
## 결박된 적 머리 위 사슬 표식 (이미 있으면 그대로).
static func bind_mark(host: Node2D) -> void:
	if host.get_node_or_null("BindMark") != null:
		return
	var m: Node2D = BMARK.new()
	m.name = "BindMark"
	host.add_child(m)


## 결박 위 화염 ×1.6: 사슬이 달아오르고 불꽃이 터진다. 글자는 적마다 0.9초에 한 번만.
static func synergy(host: Node2D, mult_text: String) -> void:
	bind_mark(host)
	host.set_meta("syn_t", 0.7)
	var now := Time.get_ticks_msec()
	if now - _syn_ms >= 900:   # 군집전: 적이 여럿이어도 글자는 0.9초에 한 번, 시너지 중인 적 수만 덧붙인다
		_syn_ms = now
		var n := 0
		for e in host.get_tree().get_nodes_in_group("enemy"):
			if e.has_meta("syn_t") and float(e.get_meta("syn_t")) > 0.0:
				n += 1
		var par := host.get_parent()
		play_once(par, host.global_position + Vector2(18, -34), "bindmark", 4, 14.0, 1.0, 2, 1).modulate.a = 0.7
		pop_text(par, host.global_position + Vector2(0, -66), mult_text, COL_FIRE, 12)


# ---------------------------------------------------------------- 예고 굳음 (tell_lock, 진행 50%)
## 예고가 굳는 순간의 단서: 몸이 한 번 하얗게 점멸하고 작은 빛 틱이 몸으로 모여 잠긴다. 신호 연결은 prog/balance-apply 병합 후:
##   enemy.tell_lock.connect(func(): CFX.tell_lock(self, sprite))
static func tell_lock(host: Node2D, body: CanvasItem, head_y := -18.0) -> void:
	play_once(host.get_parent(), host.global_position + Vector2(0, head_y), "tellock", 5, 30.0, 1.0)
	if body:
		var tw := body.create_tween()
		tw.tween_property(body, "self_modulate", Color(1.3, 1.3, 1.3), 0.05)
		tw.tween_property(body, "self_modulate", Color.WHITE, 0.1)


# ---------------------------------------------------------------- 정화
static func purify(parent: Node, pos: Vector2, scale := 1.0) -> void:
	play_once(parent, pos + Vector2(0, -22 * scale), "purify", 8, 9.0, 1.1 * scale)


static func downed_sigil(host: Node2D) -> void:
	if host.get_node_or_null("DownedSigil"):
		return
	var s := sheet("downed", 4)
	s.name = "DownedSigil"
	s.position = Vector2(0, -3)
	s.z_index = -1
	s.z_as_relative = true
	host.add_child(s)
	var tw := s.create_tween().set_loops()
	tw.tween_method(func(v: float): s.frame = int(v) % 4, 0.0, 4.0, 0.6)


static func clear_sigil(host: Node2D) -> void:
	var s := host.get_node_or_null("DownedSigil")
	if s:
		s.queue_free()
