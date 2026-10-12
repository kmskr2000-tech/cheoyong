extends Node
## 런타임 자동 화질 폴백 (autoload "Quality").
## 프레임 시간 이동평균(EMA)이 목표(33.3ms)를 일정 시간 넘으면 등급을 2(상) → 1(중) → 0(하)로 한 단계씩 낮추고,
## 한참 여유로우면 한 단계씩 되돌린다. 등급은 런타임 상태일 뿐 Game 설정·세이브에 저장하지 않는다.
## 기본(상=2) 등급에서는 화면이 절대 바뀌지 않는다 — 폴백은 프레임이 실제로 모자랄 때만 작동한다.
## 디버그 훅: `--quality=0|1|2` (고정, 자동 조정 끔), `--quality-auto` (캡처 중에도 자동 조정 켬).
## 캡처(--capture) 실행은 부하 큰 VM에서 화면이 달라지지 않도록 자동 조정이 꺼진다.

signal tier_changed(tier: int, old: int)

const TIER_MAX := 2
const TARGET_MS := 33.3          # 폰 ≥30fps
const DROP_MS := 34.8            # 30Hz 고정 기기(33.3±지터)가 오판되지 않도록 허용 오차 1.5ms
const DROP_HOLD_S := 3.0         # EMA가 DROP_MS를 이만큼 연속으로 넘으면 한 단계 낮춤
const DROP_RESET_MS := 31.0      # 이 밑으로 내려가면 낮춤 타이머 초기화
const RISE_MS := 22.0            # EMA가 이 밑(≈45fps 이상)으로
const RISE_HOLD_S := 20.0        # 이만큼 연속이면 한 단계 되돌림
const COOLDOWN_S := 5.0          # 등급이 바뀐 직후엔 이만큼 판정 보류(EMA도 새로 시작)
const RELOCK_S := 30.0           # 되돌린 뒤 이 안에 다시 떨어지면 그 등급 위로는 이번 실행 동안 되돌리지 않음(핑퐁 방지)
const HITCH_MS := 250.0          # 이보다 긴 프레임(로딩·탭 전환·일시정지)은 표본에서 제외
const EMA_TAU_S := 1.0

var tier := TIER_MAX
var pinned := false              # --quality=N 이면 true: 자동 조정 안 함
var auto := true
var ema_ms := 0.0
var events: Array[String] = []   # 로그 사본 (테스트·디버깅용)
var _clock := 0.0                # feed()로 누적한 가상 시간(초) — 벽시계가 아니라 표본 시간
var _over_s := 0.0
var _under_s := 0.0
var _cool_s := 0.0
var _has_ema := false
var _last_us := 0
var _rose_at := -1e9
var _rose_to := -1
var _ceiling := TIER_MAX         # 핑퐁이 감지되면 낮아지는 복귀 상한


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var args := OS.get_cmdline_user_args()
	var capturing := false
	for a in args:
		if a.begins_with("--quality="):
			set_tier(clampi(int(a.get_slice("=", 1)), 0, TIER_MAX), true)
		elif a.begins_with("--capture="):
			capturing = true
	if capturing and not ("--quality-auto" in args):
		auto = false
	_last_us = Time.get_ticks_usec()


func _process(_d: float) -> void:
	# Engine.time_scale 에 영향받지 않도록 벽시계로 프레임 간격을 잰다
	var now := Time.get_ticks_usec()
	var ms := (now - _last_us) / 1000.0
	_last_us = now
	if auto and not pinned:
		feed(ms)


## 프레임 시간 표본 하나(ms)를 먹인다. 테스트에서는 이걸 직접 호출해 프레임 지연을 흉내 낸다.
func feed(ms: float) -> void:
	if ms <= 0.0 or ms > HITCH_MS:
		return
	var dt := ms / 1000.0
	_clock += dt
	if not _has_ema:
		ema_ms = ms
		_has_ema = true
	else:
		ema_ms += (ms - ema_ms) * minf(1.0, dt / EMA_TAU_S)
	if pinned:
		return
	if _cool_s > 0.0:
		_cool_s -= dt
		return
	if ema_ms > DROP_MS:
		_over_s += dt
		_under_s = 0.0
		if _over_s >= DROP_HOLD_S and tier > 0:
			var rose_recently := tier == _rose_to and _clock - _rose_at < RELOCK_S
			if rose_recently:
				_ceiling = tier   # 방금 올렸다 다시 떨어짐: 그 등급 위로는 올라가지 않는다
			_change(tier - 1, "drop ema=%.1fms > %.1fms for %.1fs" % [ema_ms, DROP_MS, _over_s])
	else:
		if ema_ms < DROP_RESET_MS:
			_over_s = 0.0
		if ema_ms < RISE_MS and tier < _ceiling:
			_under_s += dt
			if _under_s >= RISE_HOLD_S:
				_rose_at = _clock
				_rose_to = tier + 1
				_change(tier + 1, "rise ema=%.1fms < %.1fms for %.1fs" % [ema_ms, RISE_MS, _under_s])
		else:
			_under_s = 0.0


## 등급을 직접 지정한다. pin=true 면 자동 조정을 멈춘다 (디버그 훅·테스트).
func set_tier(t: int, pin := false) -> void:
	pinned = pin or pinned
	_change(clampi(t, 0, TIER_MAX), "set%s" % (" (pinned)" if pinned else ""))


func _change(t: int, why: String) -> void:
	_over_s = 0.0
	_under_s = 0.0
	_cool_s = COOLDOWN_S
	_has_ema = false   # 새 등급의 프레임 시간으로 EMA를 다시 시작
	if t == tier:
		return
	var old := tier
	tier = t
	var line := "tier %d -> %d (%s)" % [old, t, why]
	events.append(line)
	print("[Quality] ", line)
	tier_changed.emit(t, old)
