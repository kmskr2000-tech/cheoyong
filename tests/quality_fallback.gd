extends SceneTree
## 화질 폴백 단위 시나리오 (프로그래밍). 헤드리스 Godot 에서 `-s` 로 실행:
##   godot --headless --path src -s ../tests/quality_fallback.gd
## 프레임 시간을 Quality.feed()로 인위적으로 먹여(실제로 지연시키지 않음) 등급 하락·복귀·핑퐁 방지를 확인하고,
## 레벨(gyeongju)을 실제로 올려 등급별로 라이트·그림자·블룸·파티클·노멀맵이 바뀌고 상(2)에서 원상 복귀하는지 확인한다.
## 성공하면 "QUALITY_RESULT PASS", 실패는 "FAIL:" 줄 + 비-0.

var Q: Node
var fails := 0


func _ok(cond: bool, msg: String) -> void:
	if cond:
		print("  ok   ", msg)
	else:
		print("FAIL: ", msg)
		fails += 1


func _run(ms: float, secs: float) -> void:
	for i in int(secs * 1000.0 / ms):
		Q.feed(ms)


func _initialize() -> void:
	Q = root.get_node("Quality")
	_main.call_deferred()


func _main() -> void:
	Q.auto = true
	print("-- 1. 정상 프레임(16.7ms)에서는 등급 불변")
	_run(16.7, 30)
	_ok(Q.tier == 2, "30초 16.7ms 후에도 등급 2 (tier=%d)" % Q.tier)
	print("-- 2. 짧은 끊김/히치는 무시")
	_run(60.0, 1.5)     # DROP_HOLD_S(3초) 미만
	_ok(Q.tier == 2, "60ms 프레임 1.5초: 아직 2 (tier=%d)" % Q.tier)
	Q.feed(1000.0); Q.feed(5000.0)
	_run(16.7, 10)
	_ok(Q.tier == 2, "히치 프레임(>250ms)과 회복 후에도 2")
	print("-- 3. 지속적으로 느리면 2 -> 1 -> 0, 0에서 멈춤")
	_run(50.0, 6)
	_ok(Q.tier == 1, "50ms 프레임 6초: 등급 1 (tier=%d, ema=%.1f)" % [Q.tier, Q.ema_ms])
	_run(50.0, 3)       # 쿨다운(5초) 동안 추가 하락 없음
	_ok(Q.tier == 1, "쿨다운 중에는 추가 하락 없음 (tier=%d)" % Q.tier)
	_run(50.0, 10)
	_ok(Q.tier == 0, "계속 느리면 등급 0 (tier=%d)" % Q.tier)
	_run(50.0, 30)
	_ok(Q.tier == 0, "0 아래로는 안 내려감")
	print("-- 4. 여유가 생기면 한 단계씩 복귀 (20초 유지 필요)")
	_run(16.7, 12)
	_ok(Q.tier == 0, "12초 여유: 아직 0 (복귀는 20초 유지)")
	_run(16.7, 14)
	_ok(Q.tier == 1, "26초 여유: 등급 1 로 복귀 (tier=%d)" % Q.tier)
	_run(16.7, 30)
	_ok(Q.tier == 2, "추가 30초 여유: 등급 2 로 복귀 (tier=%d)" % Q.tier)
	print("-- 5. 경계(25~30ms)에서는 낮추지도 올리지도 않음")
	_run(28.0, 40)
	_ok(Q.tier == 2, "28ms 40초: 2 유지 (tier=%d)" % Q.tier)
	print("-- 6. 핑퐁 방지: 올린 직후 다시 떨어지면 그 위로 복귀 안 함")
	_run(50.0, 9)
	_ok(Q.tier == 1, "다시 느려짐 -> 1 (tier=%d)" % Q.tier)
	_run(16.7, 26)
	_ok(Q.tier == 2, "여유 -> 2 로 복귀 (tier=%d)" % Q.tier)
	_run(50.0, 9)
	_ok(Q.tier == 1, "복귀 직후 재하락 -> 1 (tier=%d)" % Q.tier)
	_run(16.7, 60)
	_ok(Q.tier == 1, "핑퐁 감지 후 60초 여유에도 2 로 복귀하지 않음 (tier=%d)" % Q.tier)
	print("-- 7. 고정(--quality) 모드는 자동 조정 안 함 / 이벤트 로그")
	Q.set_tier(2, true)
	_run(50.0, 30)
	_ok(Q.tier == 2 and Q.pinned, "고정 모드: 느려도 2 유지")
	_ok(Q.events.size() >= 7, "이벤트 로그 기록 (%d줄)" % Q.events.size())
	for e in Q.events:
		print("     ", e)
	await _level_check()
	print("QUALITY_RESULT ", "PASS" if fails == 0 else "FAIL (%d)" % fails)
	quit(0 if fails == 0 else 1)


func _level_check() -> void:
	print("-- 8. 레벨 적용 (gyeongju)")
	var G: Node = root.get_node("Game")
	G.level_id = "gyeongju"
	G.spawn_name = "start"
	for f in ["summoned", "briefed", "arrived"]:
		G.flags[f] = 1
	Q.pinned = true
	Q.set_tier(2, true)
	var lv: Node = load("res://scenes/level.tscn").instantiate()
	root.add_child(lv)
	current_scene = lv
	for i in 5:
		await process_frame
	var base := _snap(lv)
	print("     상: ", base)
	_ok(base.lights_on <= base.lights, "상: 활성 라이트 %d / 전체 %d" % [base.lights_on, base.lights])
	_ok(base.shadow == base.shadow0, "상: 그림자 원래대로 (%d)" % base.shadow)
	_ok(is_equal_approx(base.bloom, 0.9), "상: 블룸 0.9")
	_ok(base.normal > 0, "상: 노멀맵 스프라이트 %d" % base.normal)
	# 플레이어를 맵 구석으로 옮기면 시야 컬링으로 화면 밖 라이트가 꺼진다 (카메라가 따라감)
	var player: Node2D = lv.get_node("Player")
	var home := player.position
	var far := false
	for L in lv.flicker:
		if L.global_position.distance_to(home) > 400:
			far = true
	_ok(far, "gyeongju 에 시작 위치에서 멀리 떨어진 라이트가 있음")
	_ok(base.lights_on < base.lights, "시야 컬링: 화면 밖 라이트가 꺼져 있음 (%d/%d)" % [base.lights_on, base.lights])
	var near_off := 0
	for L in lv.flicker:
		if not L.visible and L.global_position.distance_to(home) < 160:
			near_off += 1
	_ok(near_off == 0, "시야 안 가까운 라이트는 전부 켜져 있음")
	Q.set_tier(1, true)
	await process_frame
	var t1 := _snap(lv)
	print("     중: ", t1)
	_ok(t1.lights_on <= 6, "중: 활성 라이트 상한 6 (%d)" % t1.lights_on)
	_ok(t1.shadow == 0, "중: 그림자 0")
	_ok(t1.bloom == 0.0, "중: 블룸 끔")
	_ok(t1.ash < base.ash, "중: 파티클 감소 (%d -> %d)" % [base.ash, t1.ash])
	_ok(t1.normal == base.normal, "중: 노멀맵 유지")
	Q.set_tier(0, true)
	await process_frame
	var t0 := _snap(lv)
	print("     하: ", t0)
	_ok(t0.lights_on <= 3, "하: 활성 라이트 상한 3 (%d)" % t0.lights_on)
	_ok(t0.normal == 0, "하: 노멀맵 라이트 끔")
	_ok(not t0.shafts, "하: 빛줄기 끔")
	_ok(t0.ash < t1.ash, "하: 파티클 추가 감소 (%d)" % t0.ash)
	Q.set_tier(2, true)
	await process_frame
	var back := _snap(lv)
	print("     복귀(상): ", back)
	_ok(back.lights_on == base.lights_on and back.shadow == base.shadow and back.normal == base.normal \
		and back.ash == base.ash and back.shafts == base.shafts and is_equal_approx(back.bloom, base.bloom), "상으로 복귀하면 상 상태와 완전히 동일")
	lv.queue_free()


func _snap(lv: Node) -> Dictionary:
	var d := {"lights": lv.flicker.size(), "lights_on": 0, "shadow": 0, "shadow0": 0, "normal": 0,
		"ash": lv._ash.amount, "shafts": lv._shafts_layer.visible, "bloom": _bloom(lv)}
	for l in lv.flicker:
		if l.visible: d.lights_on += 1
		if l.shadow_enabled: d.shadow += 1
		if l.get_meta("sh0", l.shadow_enabled): d.shadow0 += 1
	for n in lv.find_children("*", "Sprite2D", true, false):
		if (n as Sprite2D).texture is CanvasTexture: d.normal += 1
	return d


func _bloom(lv: Node) -> float:
	var v: Variant = lv._post_mat.get_shader_parameter("bloom")
	return 0.9 if v == null else float(v)   # 한 번도 설정 안 했으면 셰이더 기본값(0.9)
