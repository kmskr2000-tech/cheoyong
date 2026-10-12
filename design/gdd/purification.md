# 정화 시스템 (Purification)

> **Status**: In Review
> **Author**: game-designer (reverse-document: 코드에서 역산)
> **Last Updated**: 2026-10-12
> **Last Verified**: 2026-10-12 — `src/scripts/enemy.gd`, `player.gd`, `level.gd`, `game.gd`, `bestiary.gd`, `boss.gd`(쓰러짐·정화 부분)를 커밋 `d6435c9` 기준으로 대조
> **Implements Pillar**: 1 정화, 처치가 아니다 / 2 노래가 무기다 (`design/gdd/game-concept.md`)
> **Rigor**: standard (`project.yaml` modes.rigor) — 필수 섹션 Overview·Player Fantasy·Detailed Rules·Dependencies·Tuning Knobs·Acceptance Criteria + 수치 규칙이 있으므로 Formulas. Edge Cases는 선택이지만 코드에서 읽은 것을 남겼다.

> **역산 문서 규칙**: 수치는 전부 코드에서 읽은 값이고 출처를 `파일:함수/상수`로 적었다. 코드에서 확인하지 못한 것은 "코드 미확인"이라 쓰고 지어내지 않았다. 의도(`docs/growth-system.md`·기획안 §6.2·`docs/GDD.md`)와 구현이 다른 곳은 [불일치](#불일치-의도-vs-구현) 섹션에만 기록했고 코드는 고치지 않았다.

## Summary

요괴는 HP가 0이 되어도 죽지 않고 탁기에 덮여 쓰러지며, 그대로 두면 9초 뒤 반쯤 회복해 다시 일어난다. 처용이 피리로 처용가(1.1초)를 부르면 근처의 쓰러진 요괴들이 한꺼번에 정화되고, 맑아진 탁기가 정기·덕망·엽전·재료가 된다. 한 구역의 요괴를 모두 정화하면 한풀이 보너스(그 구역에서 번 정기·덕망의 50%)가 붙는다. 이 게임의 "학살이 아니라 쓰러뜨리고 모아서 한 번에 노래한다"는 리듬과 보상 구조의 핵심이다.

> **Quick reference** — Layer: `Feature` · Priority: `MVP` · Key deps: `전투 코어(#5)`; 하류: `성장 코어(#13)`, `요괴 도감(#15)`, `적 AI(#8)`, `보스(#11)`

## Overview

전투 코어(`combat-core.md`)로 요괴의 HP를 0으로 만들면 요괴는 `downed` 상태가 된다 — 탁기가 피어오르는 채 누워서 기다리고, 어떤 공격도 받지 않는다. 플레이어는 피리를 가진 뒤부터 `song` 버튼으로 처용가를 부를 수 있고, 일정 거리 안의 쓰러진 요괴가 있으면 버튼이 빛난다(BotW식 가이드). 노래가 끝나는 순간 범위 안의 쓰러진 요괴가 전부 정화되어 사라지며 보상이 나온다. 이 시스템의 목적은 (1) 처치 대신 정화라는 주제를 규칙으로 만들고 (2) 보상 구조(성장 루프의 입구)를 정화에 묶는 것이다.

## Player Fantasy

부수는 대신 풀어준다. 쓰러진 요괴는 사라지지 않고 한(恨)을 안은 채 누워 있다. 처용이 피리를 입에 대면 오방색 물결이 번지고, 탁기가 맑은 빛이 되어 올라간다. 여러 마리를 쓰러뜨려 모아 놓고 한 번에 부르면 더 개운하다. 구역의 마지막 원혼까지 풀었을 때 "이곳의 원혼이 모두 풀렸다"는 한 번 더 큰 보답이 온다. 보스는 처치되지 않고 무릎을 꿇으며, 노래가 그 무릎 꿇음을 끝낸다(`CLAUDE.md` 전투 철학, `story-bible.md` §9.3).

## Detailed Rules

### Core Rules

**1. 쓰러짐** (`enemy.gd:take_hit`, `_down`)

1. 요괴(`Enemy`)는 피해로 `hp ≤ 0`이 되면 죽지 않고 `_down()`을 호출한다. 이 판정은 일반 피격과 지속 피해(화염·결박·처용무, `quiet=true`)에 똑같이 적용된다.
2. `_down()`: 상태 `downed`, 그룹 `enemy` 제거 → `downed` 추가, 피격 애니메이션·어두운 색·납작한 스케일, 탁기 입자(`miasma`), 신호 `collapsed`, 쓰러진 시간 `st_down = DOWN_TIME = 9.0`초.
3. 쓰러진 요괴는 `take_hit`을 받지 않고(상태 `downed`면 즉시 return), 그룹이 `downed`라 베기·부적·처용무 판정 목록(`enemy` 그룹)에 들어가지 않는다.
4. 망자(`mangja`): 쓰러지는 순간 60px 이내에 서 있는(`enemy` 그룹의) 다른 망자가 있으면 `st_down = 3.0`초(`enemy.gd:_down`). 나머지 요괴는 모두 9.0초.
5. 복제체(여우 환술, `is_clone`)는 쓰러지지 않고 어떤 피해든 맞으면 연기로 사라진다(`_poof`) — 보상 없음, 도감 없음.
6. 보스(`PlagueGod`)는 `hp ≤ 0`이면 `_kneel()`: 상태 `kneel`, 그룹 `enemy` → `downed`, 남은 `enemy` 전원에 `take_hit(999)`(→ 전부 쓰러짐), `knelt` 신호. **보스에는 일어나는 타이머가 없다**(`boss.gd`의 `kneel` 상태는 `_physics_process` 초반에서 return).

**2. 일어남** (`enemy.gd:_physics_process`, `_rise`)

7. 쓰러진 시간은 매 프레임 줄어든다. 단, 플레이어가 `song` 상태인 동안에는 멈춘다 — 대상 요괴가 노래 범위 안인지와 무관하게 모든 `downed` 요괴의 타이머가 멈춘다(`target.get("state") == "song"`).
8. `st_down ≤ 0`이면 `_rise()`: `downed` → `enemy` 그룹, 체력 `hp = int(최대HP) / 2`(정수 나눗셈), 상태 `chase`, 공격 대기 `cd = 0.6`. 일어난 요괴는 처음과 같은 요괴이며 다시 쓰러뜨려야 한다(체력이 절반이라 더 빨리 쓰러진다).
9. 대사 중(`level.gd:talk`)에는 `enemy`와 `downed` 모두 물리 처리가 멈춰 타이머도 멈춘다.

**3. 처용가** (`player.gd:can_sing`, `_start_song`, `_song`, `song_range`, `sing`)

10. 입력 `song`은 `locked`가 아니고, 기절 중이 아니며(기절하면 입력 처리 전에 return), 상태가 `move`이며, 피리를 가진(`Game.flag("flute")`) 때만 받는다. 소리(기력) 소모·쿨다운 없음.
11. 노래 시간 `SONG_TIME = 1.1`초. 그동안 이동 정지, 0.2초마다 음표 연출. 도중에 피해가 들어가는 피격(`hurt` → `_end_attack`), 기절(`stun`), 구르기 입력이 상태를 바꾸면 노래는 중단되고 **아무도 정화되지 않는다**. 수호부로 막은 피격, 피격 유예 중 피격, 구르기 무적 중 피격은 `hurt()`에서 먼저 return해 노래를 끊지 않는다. 튜토리얼 `gentle_hits` 피격(피해 0)은 끊는다. 처용무 중에는 시작할 수 없다.
12. 노래가 끝나는 순간(`t ≥ 1.1`) 플레이어 위치(`global_position`)에서 `song_range()` 이내(직선 거리, 타원 보정 없음)의 `downed` 그룹 전원에게 `purify()`를 호출한다. 범위 `SONG_RANGE = 90.0`px, 스킬 `gyeopnorae`(겹노래)면 ×2 = 180px. 끝나면 오방색 물결 5겹 연출, `sang(n)` 신호(n = 정화한 수). `sang`을 구독하는 코드는 현재 없다. 보스 `_defeat`가 같은 노래 중 다른 요괴를 먼저 정화해도 루프가 n을 그대로 세므로 n이 실제 정화 수와 다를 수 있다(`player.gd:_song`).
13. 범위 안에 아무도 없어도 노래는 끝까지 불린다(보상 없음). HUD의 `song` 버튼은 `can_sing()`(피리 + 범위 안 `downed` 존재)일 때 빛난다(`hud.gd:_process`).
14. 컷신에서는 `Player.sing()`이 같은 노래를 시작한다(`story.gd:_inner_room`의 `p.sing()` SC1-17, `story.gd:_farewell`의 `p.sing()` 작별 장면).

**4. 정화** (`enemy.gd:purify`, `_purify`)

15. `purify()`는 상태가 `downed`일 때만 동작한다. 탁기 입자를 지우고 `_purify()`: 상태 `dead`, 모든 그룹에서 제거, `purified` 신호, 효과음 `purify`, (복제체가 아니면) `Game.reward_purify(kind, 위치, 부모)` 호출 후 현재 씬의 `on_purified(보상, 위치)` 호출, 푸른 입자 24개, 0.8초 투명화 후 +0.6초 뒤 제거.
16. 보스는 `Boss.purify()`가 상태 `kneel`일 때만 `_defeat()`: `reward_purify("plague_god")`, 장신구 「역신의 눈물」 획득(이미 있으면 생략), 남은 `downed` 전원 `purify()`, `defeated` 신호, 소멸. 보스 보상은 `level.gd:on_purified`를 거치지 않는다.

**5. 보상** (`game.gd:reward_purify`, `bestiary.gd:TIERS/MATERIALS/ENTRIES`)

17. 요괴는 도감 항목(`Bestiary.ENTRIES`)의 `tier`(normal/elite/boss)로 보상 범위가 정해진다: 21종 중 normal 15, elite 5(마마귀신·장산범·손각시·해태·불개), boss 1(역신). 5개 elite는 `enemy.gd:EXTRA`의 이름표 달린 정예 5종과 일치한다.
18. 한 번의 정화에서: 정기·덕망·엽전을 각 범위에서 균등 정수 추첨(`randi_range`)하고, 스킬 `yeouiju`면 정기 ×1.2(소수 버림). 재료는 `tier.mat` 확률(여의주 ×1.2)로 계열 재료를 얻는데 수량은 normal 1, elite·boss 2. 정기·엽전을 더하고 도감 횟수 +1, 처음이면 "요괴 도감에 올랐다" 토스트·도감 이정표 검사, 마지막으로 덕망을 `Game.add_deok`에 넣는다.
19. 화면에는 "+N 정기"(재료가 나오면 재료 이름 줄 추가)가 떠오른다. 엽전·덕망 수치는 표시하지 않는다(`game.gd:float_text` 호출부에 정기·재료만 있음).
20. 재화 역할: 엽전 = 상점 구매 전용, 정기 = 강화·제작용, 덕망 = 레벨업 전용(`CLAUDE.md`; 정기 소비처는 아직 대부분 미구현 — `docs/GDD.md` 부록 A).

**6. 한풀이** (`level.gd:on_purified`, `game.gd:reward_bonus`)

21. 레벨 씬은 `on_purified`가 불릴 때마다 이번 씬에서 정화로 번 정기 합(`_earned_j`)·덕망 합(`_earned_d`)과 정화 횟수(`_purified_n`)를 누적한다(여의주 보정 후 값). 보스 보상은 누적되지 않는다.
22. 정화 직후 남은 수 `left = (enemy 그룹의 복제체 아닌 개체 수) + (downed 그룹 수)`가 0이고, `_purified_n ≥ 3`이고, 이 레벨의 한풀이 플래그(`hanpuri_<level_id>`)가 아직 없으면 한풀이: 플래그 설정, 토스트 "한풀이 — 이곳의 원혼이 모두 풀렸다", `Game.reward_bonus(_earned_j / 2, _earned_d / 2, 위치, 레벨)`.
23a. **전투 중 회복(CS-05)**: 처용가가 정화를 마칠 때 범위 안 각 마리(복제체·보스 제외)마다 체력 `floor(max_hp × 0.04)`(normal)/`× 0.11`(elite)와 소리 +8/+20을 준다(`player.gd:_song`, `combat_tuning.gd`). 한풀이가 성립하면 체력 `max_hp × 0.15`를 추가로 회복한다(`level.gd:on_purified`). 노래를 불러야 할 이유가 전투 안에 생긴다.
23. 한풀이 보너스는 정기와 덕망만 준다(엽전·재료·도감 없음, "한풀이 +N 정기" 표시). 정수 나눗셈이라 홀수는 버림. 레벨당 평생 1회(플래그는 세이브에 저장). 중립 `해태`도 `enemy` 그룹이므로 정화하지 않으면 `left`가 0이 되지 않는다.

**7. 도감 이정표** (`game.gd:_dogam_milestones`)

24. 도감 전체 21종 중 종류 수 n에 대해: `n × 2 ≥ 21`(즉 11종) 첫 달성 시 정기 +500(플래그 `dogam_half`), `n = 21` 첫 달성 시 칭호 「요괴의 벗」(플래그 `dogam_full`).

### States and Transitions

요괴(`Enemy`)의 정화 관련 상태:

| State | Entry Condition | Exit Condition | Behavior |
|-------|----------------|----------------|----------|
| chase/tell/strike/stagger/hurt/vanish/lure | 정상 전투 | `hp ≤ 0` → `downed` | 전투 코어·적 AI 참조 |
| downed | `hp ≤ 0` (`_down`) | (a) `st_down ≤ 0` → `chase`(`_rise`); (b) `purify()` → `dead` | 피격 불가, `downed` 그룹, 노래 중 타이머 정지 |
| dead | `purify()` | 약 1.4초 후 제거 | 보상·연출 |
| neutral | 해태(`EXTRA.neutral`) | 처음 맞거나 화염부를 먹으면 `chase` | `enemy` 그룹, 한풀이 `left`에 포함 |

보스(`PlagueGod`):

| State | Entry Condition | Exit Condition | Behavior |
|---|---|---|---|
| (전투 상태들) | 전투 | `hp ≤ 0` → `kneel` | |
| kneel | `_kneel()` | `purify()` → `dead` | 일어나지 않음, `downed` 그룹, 피해 무시 |
| dead | `_defeat()` | 소멸 | 보상·장신구, 남은 `downed` 정화 |

플레이어(`song` 상태): `move` → `song`(입력) → `move`(1.1초 후 또는 중단). 상세는 `combat-core.md` States and Transitions 표.

### Interactions with Other Systems

| 시스템 | 주고받는 것 | 인터페이스 |
|---|---|---|
| 전투 코어 (#5) | 피해로 `downed`가 생김; 노래 입력·`song` 상태 | `Enemy.take_hit`, `Player._start_song` |
| 성장 코어 (#13) | 덕망 → 레벨(`add_deok`), 정기 보관, 보상 호출 | `Game.reward_purify`, `Game.reward_bonus`, `Game.add_deok` |
| 요괴 도감 (#15) | 정화 횟수·신규 등록·이정표 | `Game.dogam`, `_dogam_milestones` |
| 적 AI (#8) | 망자 3초 규칙, 해태 중립, 복제체 | `enemy.gd` |
| 보스 (#11) | 무릎 꿇음 → 정화 → 장신구·남은 요괴 일괄 정화 | `boss.gd:_kneel/_defeat` |
| 스킬 트리 (#14) | `gyeopnorae`(범위 ×2), `yeouiju`(정기 ×1.2·재료 확률 ×1.2) | `Game.has_skill` |
| 스토리 비트 (#9) | 컷신의 `sing()`, 튜토리얼 가이드(`collapsed` → 노래 버튼 빛남, `purified` → 다음 비트), SC1-09 아이 정화 | `story.gd` |
| HUD (#19) | 노래 버튼 점등, 도감·수련 화면, 보상 텍스트 | `hud.gd`, `Game.float_text`, `say_toast` |

## Formulas

### 정화 보상 (한 마리)

```
정기   = int( randi_range(tier.jeonggi_min, tier.jeonggi_max) × 1.0 )
         → 여의주 공명이면 int(정기 × 1.2)
덕망   = int( randi_range(tier.deok_min,   tier.deok_max)   × 1.0 )
엽전   = int( randi_range(tier.money_min,  tier.money_max)  × 1.0 )
재료확률 p = tier.mat × (1.2 if 여의주 else 1.0)         # randf() < p 이면 획득
재료수량 = 1 (normal) | 2 (elite, boss)
```

| Variable | Type | Range | Source | Description |
|---|---|---|---|---|
| tier | enum | normal / elite / boss | `bestiary.gd:ENTRIES[kind].tier` | 요괴 종류별 등급 |
| 정기 범위 | int | normal 5~15, elite 30~50, boss 200 | `bestiary.gd:TIERS` | 정기·덕망·엽전의 `randi_range`는 양끝 포함(재료는 `randf()` 확률 비교) |
| 덕망 범위 | int | normal 18~26, elite 80~90, boss 360 | `bestiary.gd:TIERS` | |
| 엽전 범위 | int | normal 1~4, elite 10~16, boss 50 | `bestiary.gd:TIERS` | |
| mat | float | 0.35 / 1.0 / 1.0 | `bestiary.gd:TIERS` | 재료 확률 (1.0이면 여의주 보정이 있어도 항상 얻음) |
| mult | float | 1.0 | `game.gd:reward_purify` 매개변수 기본값 | 모든 호출처가 기본값(1.0)을 씀 — 확장용 자리 |
| 여의주 | bool | | `skills.gd:yeouiju` | 스킬 |
| 재료 이름 | string | 8종 | `bestiary.gd:MATERIALS` (계열 → 재료) | 역병→탁한 종기, 귀신→원혼의 머리카락, 물→물비린 해초, 도깨비→도깨비 털, 산→산짐승의 송곳니, 여우→여우 털, 용→비늘 조각, 저승→저승의 재 |

**여의주 적용 범위**: 정기 5~15 → 6~18, 30~50 → 36~60, 200 → 240. normal 재료 확률 0.35 → 0.42.
**기대값(여의주 없음)**: normal 정기 10 / 덕망 22 / 엽전 2.5 / 재료 0.35개; elite 정기 40 / 덕망 85 / 엽전 13 / 재료 2개.
**예시**: 역병 들개(normal)를 정화: 정기 5~15, 덕망 18~26, 엽전 1~4, 35% 확률로 "탁한 종기" 1개. 마마귀신(elite): 정기 30~50, 덕망 80~90, 엽전 10~16, "탁한 종기" 2개(확률 1.0).

### 덕망 → 레벨 (인접 공식, 소유: 성장 코어)

```
need(n) = n × 120          # Lv.n → n+1 에 필요한 덕망
Lv.1 → Lv.30 누적 = 120 × (1+2+…+29) = 52,200
```

출처 `game.gd:need`, `add_deok`, `MAX_LV = 30`. 레벨업마다 수련 점수 +1.
**예시**: Lv.1→2는 120덕망 = normal 5~7마리(5×26=130 ≥ 120 > 4×26, 7×18=126 ≥ 120 > 6×18). 한풀이·정예 제외.

### 한풀이 보너스

```
Σj = 이 씬에서 정화(보스 제외)로 번 정기 합,  Σd = 덕망 합,  N = 정화 횟수
조건: 남은 수 left = 0  and  N ≥ 3  and  hanpuri_<level_id> 플래그 없음
보너스 정기 = Σj / 2   (정수 나눗셈, 버림)
보너스 덕망 = Σd / 2   (정수 나눗셈, 버림)
```

**예시**: normal 4마리로 정기 40·덕망 88을 벌었다면 보너스 정기 20·덕망 44(합계 정기 60·덕망 132 = 약 1.5배). 보너스는 `reward_bonus`로 지급되며 엽전·재료·도감은 없다. **기대 범위**: 보너스는 구역에서 번 정화 보상의 정확히 절반(내림).

### 쓰러짐 지속과 일어남

```
st_down = 9.0   (망자: 곁에 선 망자가 있으면 3.0)
노래 중에는 감소하지 않음
일어날 때 hp = floor(최대HP / 2)
```

**예시**: 들개(30) → 15, 갯귀(44) → 22, 마마귀신(70) → 35, 해태(160) → 80, 망자(24) → 12. 출처 `enemy.gd:KINDS.hp`, `_rise`.
**한 번의 정화에 걸리는 시간**: 노래 1.1초(`SONG_TIME`), 범위 90px(겹노래 180px). 쓰러진 뒤 9.0초 안에 노래를 시작해 1.1초 동안 맞지 않아야 한다(노래 중에는 타이머가 멈추므로 시작만 하면 안전하지만, 피격으로 중단되면 타이머가 다시 흐른다).

### 도감 이정표

```
total = 21 (Bestiary.ENTRIES 개수)
n = 도감에 등록된 종류 수 (정화 1회 이상)
n × 2 ≥ total → 11종  : 정기 +500 (1회)
n = total     → 21종  : 칭호 「요괴의 벗」 (1회)
```

출처 `game.gd:_dogam_milestones`.

## Edge Cases

| Scenario | Expected Behavior | Rationale / 출처 |
|----------|------------------|-----------|
| 노래 범위(90px) 밖에 쓰러진 요괴가 있음 | 정화되지 않음. 단 노래 중에는 그 요괴의 타이머도 멈춤. 노래가 끝나면 타이머가 이어짐 | 규칙 7, 12 |
| 범위 안에 쓰러진 요괴가 여러 마리 | 한 번의 노래로 전부 정화, 각자 독립적으로 보상을 추첨 | `_song`: 범위 안 `downed` 순회 |
| 노래 중 피해가 들어가는 피격·기절·구르기 | 노래 중단, 정화 0건, 정지된 타이머가 다시 흐름. 수호부로 막은 피격은 중단시키지 않음 | 규칙 11 |
| 쓰러진 요괴가 일어나는 순간과 노래 시작이 겹침 | `st_down ≤ 0`이 먼저면 일어남. 노래 상태가 되면 이후 프레임부터 타이머 정지 | `_physics_process` 순서; 프레임 단위 경합은 코드 미확인 |
| 범위 안에 `downed`가 없는데 `song` 입력 | 1.1초 노래, 보상 없음(`sang(0)`) | 규칙 13 |
| 피리를 아직 못 얻음 | `song` 입력 무시 | `Game.flag("flute")` |
| 복제체(여우 환술) | 쓰러지지 않고 연기로 사라짐, 보상·도감·한풀이 집계 없음, 한풀이 `left`에서도 제외 | `enemy.gd`, `level.gd:on_purified` |
| 해태(중립) | `enemy` 그룹이라 한풀이를 위해서는 정화해야 함 | `level.gd:on_purified` |
| 마지막 쓰러진 요괴가 정화되는 순간 | 그 정화 보상 지급 → 그 직후 한풀이 보너스 지급(같은 호출 안) | `enemy.gd:_purify`에서 `reward_purify` 다음 `on_purified` |
| 정화 횟수 3 미만 | 모두 정화해도 한풀이 없음 | `_purified_n ≥ 3` |
| 보스방 | 무릎 꿇은 보스는 `downed` 그룹이라 한풀이 `left`에 포함된다. 보스 자신의 정화는 `on_purified`를 부르지 않는다. 따라서 보스방에서 한풀이는 **보스가 정화되는 순간 쓰러진 잡몹이 1마리 이상 남아 있고(`_defeat`의 일괄 정화) 이번 씬 정화 수가 3 이상일 때만** 나온다. 잡몹을 먼저 모두 정화했거나 잡몹이 없으면 한풀이는 나오지 않는다 | `level.gd:on_purified`, `boss.gd:_defeat` |
| 보스 `_kneel`의 `take_hit(999)` 대상 중 복제체 | 쓰러지지 않고 연기로 사라짐 | `enemy.gd:take_hit` |
| 같은 구역에 다시 들어옴 | 레벨 로드 때마다 `levels.gd` 정의의 요괴가 새로 생성된다(처치 영속화 코드는 읽은 범위에 없음). 한풀이 누적치는 씬마다 0부터, 플래그가 있으면 보너스는 다시 나오지 않음 | `level.gd:_ready`(적 생성 반복), `on_purified` — 재진입 시 실제 배치는 코드 미확인 |
| 새 게임 | 플래그·도감 초기화 → 한풀이·이정표 다시 가능 | `game.gd:new_game` |
| 레벨 30 도달 후 덕망 | 레벨은 오르지 않고 덕망 수치만 계속 쌓임 | `add_deok`: `while lv < MAX_LV` |
| 한풀이 합계가 홀수 | 정수 나눗셈으로 0.5 버림 | `_earned_j / 2` |
| 쓰러진 요괴에 정화부(소모품)·처용무·부적 | 맞지 않음. 정화부는 `enemy` 그룹에만 피해 | `player.gd:use_item` |
| 노래 중 대사 시작 | 요괴(`enemy`·`downed`) 물리만 멈춘다. 플레이어 `_song`은 `locked`와 무관하게 계속되어 1.1초 뒤 대사 도중에도 정화가 일어난다 | `level.gd:talk`는 `$Player.locked = true`만 세팅 |

## Dependencies

| System | Direction | Nature of Dependency |
|---|---|---|
| 전투 코어 (#5) | This depends on #5 | 요괴를 `downed`로 만드는 피해, 처용가 입력·상태. 전투 코어 문서도 정화를 참조 |
| 성장 코어 (#13) | #13 depends on this | 정기·덕망·엽전·재료의 유일한 대량 공급원, 한풀이 보너스 |
| 요괴 도감 (#15) | #15 depends on this | 정화가 곧 도감 등록·카운트·이정표 |
| 적 AI·요괴 기믹 (#8) | Both | 쓰러진 뒤 규칙(망자 3초), 정화 대상 목록, 해태 중립 |
| 보스 프레임워크 (#11) | Both | `kneel`·`purify`·`_defeat`, 보스 보상·장신구 |
| 스킬 트리 (#14) | This depends on #14 | `gyeopnorae`, `yeouiju` |
| 스토리 비트 (#9) | Both | 컷신 `sing()`, 튜토리얼 가이드(`collapsed`/`purified`) |
| HUD·메뉴 (#19) | #19 depends on this | 노래 버튼 점등, 도감 화면 |

> 양방향 규칙: #8·#9·#11·#13·#14·#15·#19의 템플릿 GDD는 아직 없다. 각 GDD 작성 시 이 문서를 역참조에 넣을 것. `combat-core.md`와는 서로를 가리킨다.

## Tuning Knobs

"안전 범위"는 코드에서 읽을 수 없는 값은 `코드 미확인`으로 적었다(플레이테스트로 결정).

| Parameter | Current Value (출처) | Safe Range | Effect of Increase | Effect of Decrease |
|---|---|---|---|---|
| `DOWN_TIME` | 9.0초 (`enemy.gd`) | 코드 미확인 | 모아서 노래할 여유↑, 학살 후 정리 쉬움 | 압박↑, 즉시 노래 강요 |
| 망자 단축 시간 | 3.0초, 반경 60 (`enemy.gd:_down`) | 코드 미확인 | | 한 번에 노래하게 강요하는 기믹 강화 |
| 일어날 때 체력 | 최대의 1/2 (`_rise`) | 코드 미확인 | 재전투 부담↑ | 쓰러뜨리기 쉬움 |
| `SONG_TIME` | 1.1초 (`player.gd`) | 코드 미확인 | 노래 중 위험(중단 가능성)↑ | 가벼워짐 |
| `SONG_RANGE` | 90px (겹노래 ×2) | 코드 미확인 | 모아 부르기 쉬움 | 개별 접근 필요 |
| 보상 범위 | `bestiary.gd:TIERS` 표 | 코드 미확인 | 성장 속도↑ | ↓ |
| 재료 확률 | 0.35/1.0/1.0 | 0.0~1.0 (`randf() <` 비교) | 재료 수급↑ | ↓ |
| 재료 수량 | 1 (normal) / 2 (그 외) (`reward_purify`) | 코드 미확인 | | |
| `need(n)` | n×120 (`game.gd`) | 코드 미확인 | 레벨 속도↓ | 레벨 속도↑ |
| 한풀이 비율 | 1/2 (`level.gd`) | 코드 미확인 | 전부 정화 동기↑ | ↓ |
| 한풀이 최소 정화 수 | 3 (`level.gd`) | 코드 미확인 | 작은 구역 보너스 제외 | |
| 도감 이정표 | 11종 → 정기 500 / 21종 → 칭호 | 코드 미확인 | | |
| `yeouiju` | 정기 ×1.2 / 재료 ×1.2 (`game.gd`) | 코드 미확인 | | |

## Acceptance Criteria

(검증 훅: `--test-enemies=키,키`, `--level=<id>`, `--flags=flute`, `--skills=id`)

- [ ] 피리 보유 시 HP를 0으로 만든 요괴(`--test-enemies=dog`)가 소멸하지 않고 `downed`(탁기 입자·납작한 모습)가 되며, 이후 베기·부적에 맞지 않는다.
- [ ] 쓰러진 뒤 9.0초(망자는 곁에 서 있는 망자가 있으면 3.0초) 동안 노래하지 않으면 최대 체력의 절반으로 다시 일어나 추격한다.
- [ ] 노래 중에는 모든 쓰러진 요괴의 타이머가 멈추고, 노래가 끝나면(또는 중단되면) 다시 흐른다.
- [ ] 쓰러진 요괴가 90px 이내일 때만 `song` 버튼이 빛난다(겹노래 시 180px).
- [ ] 노래 시작 후 1.1초 안에 피격·기절·구르기를 하면 정화가 일어나지 않는다.
- [ ] 한 번의 노래로 90px 이내의 쓰러진 요괴가 전부 정화되고, 범위 밖은 그대로 남는다.
- [ ] normal 요괴 정화 시 정기 5~15, 덕망 18~26, 엽전 1~4가 지급된다(수십 회 시행 후 범위 확인). 재료는 약 35%.
- [ ] 정예(마마귀신 등) 정화 시 정기 30~50, 덕망 80~90, 엽전 10~16, 재료 2개가 항상 지급된다.
- [ ] `--skills=yeouiju`에서 normal 정기가 6~18, 재료 확률이 약 42%다.
- [ ] 정화한 종류가 도감에 처음 오르면 토스트가 뜨고 도감 카운트가 오른다. 11종째에 정기 500이 한 번만, 21종째에 칭호가 한 번만 지급된다.
- [ ] 한 구역에서 3마리 이상을 정화하고 마지막 한 마리(해태 포함)까지 정화하면 "한풀이" 토스트와 함께 그 구역 정화 보상의 절반(내림)이 정기·덕망으로 추가된다. 같은 `level_id`에서 두 번째로는 나오지 않는다.
- [ ] 2마리만 있는 구역을 모두 정화해도 한풀이는 나오지 않는다.
- [ ] 복제체를 맞히면 보상 없이 연기로 사라진다.
- [ ] 보스는 HP 0에서 무릎 꿇고 일어나지 않으며, 노래를 부르면 정화되어 보상(정기 200·덕망 360·엽전 50, 재료 2개)과 「역신의 눈물」을 얻는다.
- [ ] 노래 중 대사가 시작되면 쓰러진 요괴의 타이머도 멈춘다.
- [ ] (알려진 갭) 보상 수치가 `bestiary.gd` 상수에 있어 데이터 외부화 기준은 미충족.

## 불일치 (의도 vs 구현)

기록만 하고 코드는 수정하지 않았다. 의도 출처: `docs/growth-system.md`, 기획안 §6.2, `docs/GDD.md`, `docs/story-bible.md`, `CLAUDE.md`.

| # | 항목 | 의도 | 구현 | 비고 |
|---|---|---|---|---|
| P1 (해소: 디렉터 D4 — 최소 정화 3 유지, `combat-strategy.md` §6 문서화) | 한풀이 최소 정화 수 | `growth-system.md` §2·§12: "정화율 100%"(구역의 요괴를 모두 정화) | 모두 정화해도 `_purified_n ≥ 3`이어야 함. 2마리 이하 구역은 한풀이 불가 | 어디에도 문서화된 적 없는 조건 |
| P2 | 한풀이 기준액에 보스 제외 | `growth-system.md` §12 "그 구역에서 번 정기·덕망의 50% 추가" | 보스 보상(`boss.gd:_defeat`)은 `on_purified`를 거치지 않아 합산에서 빠짐 | 문서에 보스 제외 명시 필요 |
| P3 | 도감 100% 보상 | `growth-system.md` §5·§6: 칭호 「요괴의 벗」 + **정화 속도 +10%** | 칭호만 지급. 정화 속도라는 변수가 코드에 없음(`SONG_TIME` 고정 1.1초) | 같은 "정화 속도/정화력" 효과가 오방탈(+20%)·처용 세트(+15%)·피리 강화(정화력 +5%)에도 문서에 있음 — 전부 미구현 |
| P4 | 한풀이 용어 중복 | `story-bible.md` §9.3은 "한풀이 연출(정화 100 달성)", §3-4 등은 서사 분기 "한풀이"(연화 등) | 구현된 한풀이는 구역 정화 보너스(`on_purified`)뿐. 분기형 한풀이는 2~5장 미구현 | 같은 단어를 두 가지 시스템이 씀 — 용어 정리 필요 |
| P5 | 보스 보상 하한 표기 | `growth-system.md` §2·§6 "보스 200~" | 보스는 200 고정 범위(`[200, 200]`) | 의도가 최소값인지 고정값인지 불명 |
| P6 | 도감 계열 vs 바이블 | `CLAUDE.md`: "요괴 계열은 바이블 부록 E와 맞춘다" | 부록 E 표에 계열(역병·귀신·물…) 열이 없어 대조 불가. 계열 매핑은 `bestiary.gd:ENTRIES`에만 있음 | 바이블에 열 추가하거나 `bestiary.gd`를 정본으로 선언 필요(바이블은 이번 작업에서 수정하지 않음) |
| P7 | 일어나는 요괴의 체력 | `GDD.md` COMBAT.DOWNED는 "탁기에 덮여 기다리다 다시 일어남"만 서술 | 일어나면 체력 절반으로 복귀(`_rise`) — 문서에 없음 | 수치 문서화 누락 |
| P8 | 노래 중 타이머 정지 범위 | 기획안 §6.2 "쓰러뜨리고, 모으고, 한 번에 노래한다" | 노래 중에는 **같은 레벨 씬의 모든** 쓰러진 요괴 타이머가 멈춤(범위와 무관) | 의도적인지 부수 효과인지 불명 |
| P9 | 정화 성공 여부와 재화 표시 | 보상 재화 3종 분리(`CLAUDE.md`) | 화면에는 정기·재료만 뜨고 덕망·엽전은 안 뜸(토스트 없음) | 플레이어가 덕망·엽전 획득을 인지하기 어려움 |
| P10 | 겹노래 연출 범위 | `gyeopnorae` 설명: 정화 범위 2배 | 정화 판정은 180px이지만 오방색 물결은 상수 `SONG_RANGE`(90)까지만 그려짐(`player.gd:_ripple`) | 판정과 연출의 어긋남 — 코드 버그인지 의도인지 불명 |

## 코드 미확인

- 레벨 재입장 시 요괴 재생성·영속화(`levels.gd` 정의가 매번 생성되는지, 처치/정화 상태가 플래그로 보존되는지): `level.gd:_ready`에서 적 생성 반복만 읽었다. 보스방 재도전의 요괴 상태 포함.
- 플레이어 사망·리스폰 시 `downed` 요괴의 타이머 처리: `Player._respawn`은 요괴를 건드리지 않는 것까지만 읽었다.
- SC1-09 아이 정화가 일반 정화 파이프라인(`Enemy.purify`)을 쓰는지 별도 처리인지: `story.gd:262` 부근 주석("탁기에 든 아이. 노래 버튼이 저절로 빛난다")만 읽었다.
- 쓰러진 요괴의 충돌(길을 막는지), 시각 연출 세부, 효과음 믹싱(`Audio.sfx("purify", -4.0, 0.03)`의 의미).
- 도감 화면 UI(`hud.gd:_bag_dogam`) 표시 방식.
- 정기의 소비처(피리 강화·제작·퇴치향)는 미구현(`docs/GDD.md` 부록 A) — 현재 정기는 쌓이기만 한다.
- 노래와 쓰러진 요괴 일어남이 같은 프레임에 겹칠 때의 순서.
- 난이도·밸런스 실측(정화 효율, 한풀이 도달률)은 플레이 테스트 자료 없음.

## Open Questions

| Question | Owner | Deadline | Resolution |
|---|---|---|---|
| 한풀이 최소 정화 수 3을 문서화할 것인가, 규칙을 "전부 정화"로 바꿀 것인가 (P1) | game-designer | 2026-10 중 | **해결**: 3 유지(D4), `combat-strategy.md` §6에 문서화. 구현 변경 없음 |
| 보스 보상을 한풀이 기준액에 넣을 것인가 (P2) | game-designer | | 미정 |
| "정화 속도/정화력" 효과를 구현할 것인가, 문서에서 지울 것인가 (P3) | game-designer | | 미정 |
| 한풀이 용어를 두 시스템 중 하나로 이름 바꿀 것인가 (P4) | narrative-director | | 미정 |
| 노래 중 전 맵 타이머 정지가 의도인가 (P8) | game-designer | | 미정 |
| 덕망·엽전 획득을 화면에 보여줄 것인가 (P9) | ux-designer | | 미정 |
