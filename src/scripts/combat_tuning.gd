class_name CombatTuning
extends RefCounted
## 전투 전략 상수 모음 (design/gdd/combat-strategy.md "Tuning Knobs", CS-08).
## 값을 바꿀 때는 여기서만 바꾼다. 소비자는 `const CT := preload("res://scripts/combat_tuning.gd")` 로 참조한다
## (새 class_name 이 전역 캐시에 오르기 전에도 로드되도록 preload 를 쓴다).
## "범위"는 설계서가 권하는 조정 폭이다 — 플레이테스트로 확정.

# ---- 받아넘기기 · 구르기 (§1)
const PARRY_WINDOW := 0.15          # 0.12~0.20  구르기 시작 후 받아넘기기 창
const PARRY_WINDOW_SKILL := 0.22    # 0.18~0.28  스킬 batanum(되받아치기)
const PARRY_CD := 0.3               # 받아넘기기 쿨다운 (현재 값 유지)
const PARRY_SHOVE_RANGE := 80.0     # 되받아치기: 정면 밀쳐내기 사거리
const SIN_PER_PARRY := 15.0         # 받아넘기기 신명 (현재 값 유지)
const KI_PER_PARRY := 8.0           # 0~12  받아넘기기 소리 (신규)
const ROLL_LOCK := 0.25             # 0.15~0.35  구르기 종료 후 재구르기 잠금
const ROLL_BUFFER := 0.10           # 0.06~0.15  구르기 선입력 유효 시간

# ---- 강 베기 (§1, Formulas)
const CHARGE_ENTER := 0.45          # 0.35~0.55  눌림 시점부터 충전 상태 진입까지
const CHARGE_MIN := 0.35            # 0.25~0.5   충전 상태 진입 후 발동 가능 최소
const CHARGE_FULL := 0.90           # 0.7~1.2    만충
const CHARGE_MAX := 2.00            # 자동 발동
const CHARGE_RECOVER := 0.35        # 발동 후 후딜
const CHARGE_BASE_DMG := 18.0       # 3타 기본 피해
const CHARGE_DMG_BASE := 1.3        # 피해 계수 1.3 + 1.2t (최대 2.5; 범위 2.0~3.0)
const CHARGE_DMG_SPAN := 1.2
const CHARGE_REACH_MIN := 44.0
const CHARGE_REACH_SPAN := 8.0
const CHARGE_ARC_MIN := 1.5
const CHARGE_ARC_SPAN := 0.2
const CHARGE_KNOCK_MIN := 280.0
const CHARGE_KNOCK_MAX := 320.0
const CHARGE_BOSS_KNOCK_MIN := 75.0
const CHARGE_BOSS_KNOCK_MAX := 90.0
const SIN_PER_CHARGED := 5.0        # 강 베기 적중 체 신명
const CHARGE_AUTOAIM := 80.0        # 발동 시점 자동 조준 반경

# ---- 수호부 (§1 D3)
const GUARD_T := 0.4                # 수호부가 막은 뒤 상태이상 차단 시간
const GUARD_REFUND := 10.0          # 0~15  파괴 환급 소리

# ---- 결박·화염·파동 시너지 (§3)
const FIRE_ON_BIND_MULT := 1.6      # 1.3~2.0  S1 장판 배율
const BIND_HIT_MULT := 1.2          # 1.1~1.4  결박된 적에 대한 베기
const BIND_HIT_MULT_SKILL := 1.4    # gyeolbak2
const BIND_PICK_RANGE := 110.0
const BIND_RADIUS := 40.0
const WAVE_BIND_DMG_MULT := 2.0     # S4
const WAVE_BIND_KNOCK_MULT := 0.5

# ---- 장갑 · 후딜 (§4)
const ARMOR := {"jangseung_taki": 0.4, "mama": 0.6}     # mama 0.5~0.8
const STAGGER_MULT := {"jangseung_taki": 2.0}
const STAGGER_DEFAULT_MULT := 1.5
const STAGGER_AFTER := {"dog": 0.5, "sea": 0.8, "mama": 1.2}   # 0.3~1.2

# ---- 자원 경제 (§2)
const KI_REGEN := 4.0               # 3.0~6.0  (현재 6.0)
const KI_PURIFY_NORMAL := 8.0       # 4~12
const KI_PURIFY_ELITE := 20.0       # 10~30
const HP_PURIFY_NORMAL := 0.04      # 2~6% max_hp
const HP_PURIFY_ELITE := 0.11       # 8~15%
const HP_HANPURI := 0.15            # 한풀이 성립 시 체력
const SIN_PENALTY_HIT := 12.0       # 0~20  피해를 입으면 신명 −

# ---- 역신 (§5)
const BOSS_OPEN_COUGH := 1.2        # 0.8~1.6  기침 후 열림
const BOSS_OPEN_COUGH_P2 := 0.9
const BOSS_OPEN_PULSE := 1.0
const BOSS_OPEN_MULT := 1.5         # 1.2~1.8  열림 배율
const BOSS_CAST_MULT := 1.25        # 시전 노출 배율
const BOSS_INTERRUPT_OPEN := 1.2    # 시전 중단 후 열림
const BOSS_PHASE_SHIFT := 1.2       # 2페이즈 전환 열림
const BOSS_PHASE_KI := 30.0         # 10~50  2페이즈 소리 보상
const BOSS_HP := 480.0              # 420~560

# ---- 터치 (§7)
const HAPTIC_MS := 25
