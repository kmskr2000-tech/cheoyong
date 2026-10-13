extends SceneTree
## T5(숨김 규칙)·T8(설정 유지)·폴백/잠깐 모드 — design/gdd/objective-marker.md §8. 헤드리스. tests/objective_hud.sh 가 실행한다.
var fails := 0

func _ck(name: String, ok: bool, extra := "") -> void:
	print(("PASS " if ok else "FAIL ") + name + (" :: " + extra if extra != "" else ""))
	if not ok: fails += 1

func _gd(src: String) -> GDScript:
	var s := GDScript.new()
	s.source_code = src
	s.reload()
	return s

func _wait(sec: float) -> void:
	await create_timer(sec).timeout

func _initialize() -> void:
	var G = root.get_node("Game")
	var lvl := Node.new()
	lvl.set_script(_gd("extends Node\nvar _talking := 0\n"))
	root.add_child(lvl)
	var pl := Node.new()
	pl.set_script(_gd("extends Node\nvar locked := false\n"))
	lvl.add_child(pl)
	var hud = load("res://scripts/hud.gd").new()
	lvl.add_child(hud)
	hud.player = pl
	await process_frame
	var info := {"id": "ch1.gyeongju.rest", "text": "집에서 쉰다", "target": Vector2(130, 237), "kind": "interact", "follow": "", "via": [], "show": "normal"}
	DirAccess.remove_absolute("user://settings.json")
	G._settings = {}
	# (기본 "항상") 조작 가능 상태에서 문구가 뜬다
	_ck("T8 기본 노출 모드 = 항상", hud.objective_mode() == "always")
	hud.set_objective(info)
	await _wait(0.8)
	_ck("항상 모드: 문구 노출 (알파 %.2f)" % hud.objective_alpha(), hud.objective_alpha() >= 0.7 and hud.objective_text() == "◇ 집에서 쉰다", hud.objective_text())
	# T5: 튜토리얼 점등 중에는 알파 0
	hud.guide("roll")
	await _wait(0.6)
	_ck("T5 hud.guide('roll') 점등 중 문구 알파 0", hud.objective_alpha() < 0.01, str(hud.objective_alpha()))
	hud.guide("")
	await _wait(0.8)
	_ck("T5 점등이 꺼지면 문구 복귀", hud.objective_alpha() >= 0.7, str(hud.objective_alpha()))
	# T5: 보스 체력바 표시 중
	var boss := Node.new()
	boss.set_script(_gd("extends Node\nsignal hp_changed(hp, mx)\nsignal defeated\n"))
	lvl.add_child(boss)
	hud.show_boss(boss, "역신(疫神)")
	await _wait(0.6)
	_ck("T5 보스 체력바 표시 중 문구 알파 0", hud.objective_alpha() < 0.01, str(hud.objective_alpha()))
	boss.defeated.emit()
	await _wait(0.8)
	_ck("T5 체력바가 사라지면 문구 복귀", hud.objective_alpha() >= 0.7, str(hud.objective_alpha()))
	# 연출 중(locked)·대화 중(_talking)엔 숨고, 바뀐 목표는 조작이 돌아온 뒤에 적용된다
	pl.locked = true
	await _wait(0.5)
	_ck("연출(locked) 중 문구 알파 0", hud.objective_alpha() < 0.01)
	var info2 := info.duplicate()
	info2["id"] = "ch1.gyeongju.summoned"; info2["text"] = "관아로 간다"
	hud.set_objective(info2)
	await _wait(0.5)
	_ck("연출 중 바뀐 목표는 대기(문구 그대로 '집에서 쉰다')", hud.objective_text() == "◇ 집에서 쉰다", hud.objective_text())
	pl.locked = false
	await _wait(1.2)
	_ck("조작 복귀 후 새 목표 적용·노출", hud.objective_text() == "◇ 관아로 간다" and hud.objective_alpha() >= 0.7, "%s %.2f" % [hud.objective_text(), hud.objective_alpha()])
	lvl._talking = 1
	await _wait(0.5)
	_ck("대화 중 문구 알파 0", hud.objective_alpha() < 0.01)
	lvl._talking = 0
	await _wait(0.8)
	# T8: 끔
	G.set_setting("obj_text", "off")
	await _wait(0.8)
	_ck("T8 설정 '끔' 이면 문구 알파 0", hud.objective_alpha() < 0.01)
	G._settings = {}   # 메모리를 비우고 파일에서 다시 읽는다 (재시작 시뮬레이션)
	_ck("T8 user://settings.json 에서 복원 (재시작 후 유지)", G.setting("obj_text") == "off" and hud.objective_mode() == "off", str(G.setting("obj_text")))
	var raw: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("user://settings.json"))
	_ck("T8 settings.json 에 obj_text 저장", raw.get("obj_text", "") == "off")
	# 잠깐 모드: 5초 노출 후 페이드
	G.set_setting("obj_text", "brief")
	hud._obj_brief_t = 1.0   # 5초 대기를 줄이기 위해 남은 시간만 낮춘다
	hud._obj_flash_t = 0.0
	await _wait(0.5)
	_ck("잠깐 모드: 노출 중", hud.objective_alpha() >= 0.5, str(hud.objective_alpha()))
	await _wait(1.6)
	_ck("잠깐 모드: 시간이 지나면 사라짐", hud.objective_alpha() < 0.01, str(hud.objective_alpha()))
	hud._obj_idle_brief = hud.OBJ_BRIEF_IDLE - 0.3
	await _wait(1.0)
	_ck("잠깐 모드: 무입력 25초 뒤 재노출", hud.objective_alpha() >= 0.5, str(hud.objective_alpha()))
	G.set_setting("obj_text", "always")
	# 폴백(SC1-01 무음): 20초 무입력 전에는 숨김, 이후 5초 노출
	var fb := {"id": "ch1.beach.flute", "text": "반짝이는 것을 줍는다", "target": Vector2(205, 427), "kind": "interact", "follow": "", "via": [], "show": "fallback"}
	hud.set_objective(fb)
	await _wait(1.5)
	_ck("폴백 문구는 무입력 20초 전까지 숨김", hud.objective_alpha() < 0.01 and hud.objective_text() == "◇ 반짝이는 것을 줍는다", "%s %.2f" % [hud.objective_text(), hud.objective_alpha()])
	hud._obj_idle = hud.OBJ_FALLBACK_IDLE - 0.3
	await _wait(1.0)
	_ck("폴백: 20초 무입력 후 노출", hud.objective_alpha() >= 0.5, str(hud.objective_alpha()))
	hud._obj_fb_t = 0.2
	await _wait(1.2)
	_ck("폴백: 5초 노출 후 다시 숨김", hud.objective_alpha() < 0.01, str(hud.objective_alpha()))
	# 길잡이 빛 설정 저장
	G.set_setting("obj_light", false)
	G._settings = {}
	_ck("T8 길잡이 빛 끔 설정 유지", G.setting("obj_light") == false)
	DirAccess.remove_absolute("user://settings.json")
	print("OBJECTIVE_HUD ", "PASS" if fails == 0 else "FAIL %d" % fails)
	quit(1 if fails > 0 else 0)
