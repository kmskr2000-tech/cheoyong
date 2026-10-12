# 보스 처치 시간 실측 (프로그래밍팀, 2026-10-12) — 확정 2026-10-13

## 보스 봇 실측이 무효였던 원인 (수정 완료, tests/godot/balance_probe.gd · design/balance/run_probe.sh)
1. run_probe.sh 가 보스 시나리오에도 --level=pyega1 을 넘김 -> pyega1 에는 Boss 노드가 없음. 보스는 pyega2 (수정: boss* 시나리오는 pyega2).
2. 2페이즈 전환 대사(SC1-18) 동안 보스가 "wait" -> 봇이 대사를 안 넘김. (수정: pump)
3. 가상 사망 뒤 부활 좌표가 boss-110px = 입구 봉쇄문 밖이라 봇이 못 들어옴. (수정: anchors.boss_respawn)
4. 승리(무릎 꿇기) 뒤 대사가 플레이어를 잠그고 적 물리를 멈춤 -> 2판째부터 보스 영영 idle. (수정: 대사 pump 후 해제)
5. 무릎 꿇기가 보스를 "enemy" 그룹에서 빼 둠 -> 2판째 타격이 안 닿음. (수정: 그룹 복귀)
6. 요괴 프로브 고정 좌표(270,290)는 새 지형에서 오른쪽이 막혀 봇이 접근 못 함. (수정: 열린 바닥 + 상대 배치)

## 실측 (n=3, 정책별, 150초 제한, 가상 사망=누적 피해 >= 최대 HP 112)
| 설정 | 탭(안 읽음) | reader(숙련 봇) | window |
|---|---|---|---|
| HP1200, idle x1.0, open x1.5 | 25초 3/3 사망 0 | 60초 1/3 사망 2.0 | 0/3 |
| HP1200, idle x0.5, open x2.0 | 45초 3/3 사망 0.67 | 37초 1/3 사망 1.67 | 0/3 |
| HP1800, idle x0.5, open x2.0 | 0/3 사망 4.0 | 0/3 사망 2.3 | 0/3 |
| **HP1350, idle x0.5, open x2.0 (확정)** | 0/3 사망 4.67 | 0/3 사망 2.33 | 0/3 사망 2.00 |
원자료: design/balance/raw/boss_apply.txt (+ /tmp 임시)

## 확정 (2026-10-13)
- 최종 상수(src/scripts/combat_tuning.gd): BOSS_HP 1350 / BOSS_IDLE_MULT 0.5 / BOSS_OPEN_MULT 2.0 (cast 1.25 유지). harness BOSS_MAX 1350 일치.
- 재측정(n=3, 150초, 최종 상수): 탭 연타 0/3 처치·사망 4.67 > reader 2.33 > window 2.00. 탭 연타가 가장 불리 = 지배전략 해소(HP1200 구설정에서는 탭이 25초·사망 0으로 최적이었음). 원자료 design/balance/raw/boss_apply.txt.
- 한계: 봇은 150초 안에 못 깸(독 틱 피해 회피 한계) -> 60~90초 숙련 처치 시간은 봇으로 미검증, 실플레이 확인 필요. HP1500은 이전 실측에서 도달 불가 경향이라 1350 채택.
- QA 통합 빌드의 '연타 봇 ~21초·사망 0'은 IDLE_MULT 0.5/OPEN 2.0 이 반영되기 전(구 상수) 빌드의 결과로 추정; 이 브랜치 머지 후 재확인 필요.
- 회귀: combat_strategy 11/11, smoke_godot 7/7, chapter1_playthrough PASS, tap_dominance PASS(mean_dmg 2.86).
