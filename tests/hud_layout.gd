extends SceneTree
## 폰 체크리스트 중 코드로 판정 가능한 항목 (HUD 겹침·터치 반경 겹침·허구 고지 위치·가장자리 여백). tests/hud_layout.sh 가 실행한다.
## 화면 좌표는 480x270 논리 해상도. 정수 배율 + 뷰포트 스트레치라 기기에서는 이 사각형이 그대로 확대된다.
var fails := 0
const SAFE := 6.0   # 가장자리 여백(논리 px). 4배율 기준 24 device px = 노치/둥근 모서리/홈 인디케이터 여유

func _ck(name: String, ok: bool, extra := "") -> void:
	print(("PASS " if ok else "FAIL ") + name + (" :: " + extra if extra != "" else ""))
	if not ok: fails += 1

func _initialize() -> void:
	var hud = load("res://scripts/hud.gd").new()
	root.add_child(hud)
	await process_frame
	var btns: Dictionary = hud._buttons
	_ck("h0 터치 버튼 7개", btns.size() == 7, str(btns.size()))
	var names: Array = btns.keys()
	# 1) 터치 반경(원) 쌍별 겹침 없음 + 화면 안
	var circles := {}
	for n in names:
		var tb: TouchScreenButton = btns[n]
		var tex := tb.texture_normal
		var c: Vector2 = tb.position + tex.get_size() / 2.0
		circles[n] = [c, (tb.shape as CircleShape2D).radius, Rect2(tb.position, tex.get_size())]
	var worst := 999.0
	for i in names.size():
		for j in range(i + 1, names.size()):
			var a: Array = circles[names[i]]
			var b: Array = circles[names[j]]
			var gap: float = (a[0] as Vector2).distance_to(b[0]) - (a[1] + b[1])
			worst = minf(worst, gap)
			if gap < 0.0:
				_ck("h1 터치 반경 겹침 %s/%s" % [names[i], names[j]], false, "겹침 %.1fpx" % -gap)
	_ck("h1 터치 반경 쌍별 겹침 없음", worst >= 0.0, "최소 간격 %.1fpx" % worst)
	for n in names:
		var c: Vector2 = circles[n][0]
		var r: float = circles[n][1]
		# 화면 밖으로 삐져나온 반경은 눌림에 해롭지 않지만(잘릴 뿐) 4px 넘게 나가면 손가락이 못 닿는 영역이 생긴다
		var spill := maxf(maxf(r - c.x, c.x + r - 480.0), maxf(r - c.y, c.y + r - 270.0))
		_ck("h2 터치 반경이 화면 밖으로 4px 넘게 안 나감 %s" % n, c.x >= 0.0 and c.y >= 0.0 and spill <= 4.0, "c=%s r=%.0f 삐져나감 %.0fpx" % [c, r, maxf(spill, 0.0)])
	# 2) 화면에 보이는 버튼 그림 사각형 쌍별 겹침 (누르는 곳이 아니라 눈에 보이는 겹침)
	var vw := 0.0
	for i in names.size():
		for j in range(i + 1, names.size()):
			# 버튼 그림은 둥글다: 사각형이 아니라 (그림 크기/2) 반지름 원으로 겹침을 본다
			var ra: Rect2 = circles[names[i]][2]
			var rb: Rect2 = circles[names[j]][2]
			var ov: float = (ra.get_center().distance_to(rb.get_center())) - (minf(ra.size.x, ra.size.y) + minf(rb.size.x, rb.size.y)) / 2.0
			if ov < 0.0:
				vw = maxf(vw, -ov)
				_ck("h3 버튼 그림 겹침 %s/%s" % [names[i], names[j]], false, "%.1fpx" % -ov)
	_ck("h3 버튼 그림 쌍별 겹침 없음", vw == 0.0)
	# 3) 가장자리 여백: 오른쪽 위 메뉴 버튼은 노치/모서리에 닿지 않아야
	for n in names:
		var rr: Rect2 = circles[n][2]
		var inside := rr.position.x >= SAFE and rr.end.x <= 480.0 - SAFE and rr.position.y >= SAFE - 2.0 and rr.end.y <= 270.0 - SAFE
		_ck("h4 가장자리 여백 %s" % n, inside, "rect=%s" % rr)
	# 4) 부적 이름표(_tal_label)는 어떤 버튼 그림과도 겹치지 않는다
	var tl: Label = hud._tal_label
	var tlr := Rect2(tl.position, tl.size)
	var okl := true
	for n in names:
		if tlr.intersects(circles[n][2]):
			okl = false
			_ck("h5 부적 이름표 겹침 %s" % n, false)
	_ck("h5 부적 이름표 버튼과 안 겹침", okl)
	# 5) 왼쪽 위 상태 막대/아이콘 vs 오른쪽 위 메뉴: 가로로 충분히 떨어짐
	var menu: Rect2 = circles["menu"][2]
	_ck("h6 메뉴 버튼이 상태 막대(좌측 130px 이내)와 안 겹침", menu.position.x > 140.0)
	# 5b) 왼쪽 위 상태 영역: Lv 글씨·휴대품 아이콘 3개·체력/기력/신명 막대가 서로 안 겹침
	var left: Dictionary = {}
	left["lv"] = Rect2(hud._lv.position, hud._lv.get_minimum_size())
	for k in ["_tal_icon", "_mask_icon", "_flute_icon"]:
		var ic: TextureRect = hud.get(k)
		left[k] = Rect2(ic.position, ic.texture.get_size())
	for k in ["_hp_fill", "_ki_fill", "_sin_fill"]:
		var g: TextureRect = hud.get(k)
		left[k] = Rect2(g.get_parent().get_child(g.get_index()).position, Vector2(g.size.x if g.size.x > 0 else 8.0, 8.0))
	var lk: Array = left.keys()
	var lok := true
	for i in lk.size():
		for j in range(i + 1, lk.size()):
			if (left[lk[i]] as Rect2).intersects(left[lk[j]]):
				# 막대 3개는 서로 11px 간격으로 쌓인다(높이 8) — 같은 열 막대끼리의 겹침만 판정
				lok = false
				_ck("h7 좌측 상단 겹침 %s/%s" % [lk[i], lk[j]], false, "%s %s" % [left[lk[i]], left[lk[j]]])
	_ck("h7 좌측 상단 HUD 요소끼리 안 겹침", lok)
	# 6) 타이틀: 메뉴 글씨 줄들과 허구 고지 문구가 안 겹치고 가장자리 여유가 있다
	var title = load("res://scripts/title.gd").new()
	root.add_child(title)
	await process_frame
	var layer: Node = null
	for c in title.get_children():
		if c is CanvasLayer: layer = c
	var note: Label = null
	var opts: Array = []
	for c in layer.get_children():
		if c is Label:
			if (c as Label).text.contains("픽션"): note = c
			elif c.mouse_filter == Control.MOUSE_FILTER_STOP: opts.append(c)
	_ck("t1 허구 고지 문구가 타이틀에 있다", note != null)
	if note:
		var font: Font = note.get_theme_font("font")
		var sz := font.get_string_size(note.text, HORIZONTAL_ALIGNMENT_LEFT, -1, note.get_theme_font_size("font_size"))
		var nr := Rect2(Vector2((480.0 - sz.x) / 2.0, note.position.y), sz)   # 글자 상자(Label의 최소 높이가 아니라 실제 글줄)
		_ck("t2 고지 문구 글자 폭이 화면 안(좌우 %.0fpx 여유)" % ((480.0 - sz.x) / 2.0), nr.position.x >= SAFE and nr.end.x <= 480.0 - SAFE)
		_ck("t3 고지 문구 아래 여백 >= %.0fpx" % (SAFE * 2.0), 270.0 - nr.end.y >= SAFE * 2.0 - 0.01, "아래 여백 %.0f" % (270.0 - nr.end.y))
		var clear := true
		for o in opts:
			if Rect2(o.position, o.size).intersects(nr): clear = false
		_ck("t4 고지 문구가 메뉴 글씨와 안 겹침", clear)
		# 메뉴 글씨 터치 영역(120x18)끼리도 안 겹침
		var gap_ok := true
		for i in opts.size():
			for j in range(i + 1, opts.size()):
				if Rect2(opts[i].position, opts[i].size).intersects(Rect2(opts[j].position, opts[j].size)): gap_ok = false
		_ck("t4b 메뉴 항목이 3개(처음부터·이어하기·회상)여도 고지 문구와 안 겹침", 168.0 + 2 * 20.0 + 18.0 <= nr.position.y)
		_ck("t5 메뉴 터치 영역끼리 안 겹침(항목 %d개)" % opts.size(), gap_ok)
	print("HUD_LAYOUT ", "PASS" if fails == 0 else "FAIL")
	quit(1 if fails > 0 else 0)
