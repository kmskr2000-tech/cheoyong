# 저사양 폴백 (prog/lowend-fallback) 검증 보고

작성 2026-10-13. 코드 기준 커밋: src 는 `b9edaed`(main `a09fdd4` 병합 후)와 동일, 이후 변경은 tests/ 뿐.
증거 로그 원본: `~/workspace/goals/rpg/hidden_files/evidence/lowend/` (아래 파일명 참조).

## 변경 요약
- `Quality` autoload(`src/scripts/quality.gd`): 프레임 EMA 가 34.8ms 를 3초 넘으면 상(2)→중(1)→하(0), 22ms 미만 20초면 한 단계 복귀, 복귀 직후 30초 안에 재하락하면 그 등급 위로는 이번 실행 동안 복귀 안 함. `--quality=N` 고정, 캡처 중 자동 off.
- `level.gd`: 시야 밖 라이트 컬링(0.1초 간격, 마진 48px), 등급별 라이트 상한(중6/하3)·블룸·노멀맵·파티클·그림자·빛줄기. `post.gdshader`: `bloom > 0` 분기.
- 이번 작업에서 찾아 고친 버그: 핑퐁 방지 `_ceiling = tier` → `tier - 1` (off-by-one: 핑퐁이 감지돼도 2로 복귀해 버렸음. quality_fallback 시나리오 6 이 잡음).

## 1. 기본(상) 등급 화면이 바뀌지 않음 — 증거
기본 경로 = 폴백이 한 번도 작동하지 않은 상태(tier 2). 상 등급에서 달라질 수 있는 지점은 두 곳뿐이다(코드 diff 로 확인: `git diff origin/main -- src`): ① 시야 컬링 ② post 셰이더 `bloom>0` 분기. 나머지(상한·노멀맵·파티클·그림자·빛줄기)는 `t>=2`/`LIGHT_CAP[2]=9999` 로 상에선 무변경이며 ③ 상태 수치로 확인한다.

| 항목 | 방법 | 허용 오차 | 결과 | 로그 |
|---|---|---|---|---|
| ① 컬링 | `tests/lowend_pixels.gd`: 같은 프로세스에서 컬링 상태 화면 vs 컬링된 라이트를 전부 켠 화면, 시간(`time_scale=0`)·`paused`·플리커·귀화 정지 | 0 px | gyeongju 9지점 전부 0px, 컬링된 라이트 합계 4(증명 유효) PASS | pixels.log |
| ① (그 외 맵) | 같은 테스트 `--allow-nocull` | 0 px | pyega1·pyega2·palace·beach·gwana: 컬링 대상 0개 — 컬링 증명은 해당 없음(전부 0px 이긴 하나 의미 없음) | pixels.log, run1-full-raw.log |
| ② 셰이더 | `tests/lowend_shader_main.gd`: 같은 프로세스·같은 정지 프레임에서 브랜치 post 셰이더(bloom 기본값) vs main 의 post 셰이더(`tests/fixtures/post_main.gdshader` = `git show origin/main:src/shaders/post.gdshader`) | 0 px (동일 상태 재캡처 노이즈 0px 확인) | gyeongju·beach·palace 모두 0px PASS | shader_vs_main_*.log |
| ③ 상태 수치 | `tests/quality_fallback.gd` 시나리오 8: 상에서 그림자=원래값, 블룸 0.9, 노멀맵 스프라이트>0; 중·하 후 상으로 복귀하면 활성 라이트·그림자·노멀맵·파티클 수·빛줄기·블룸이 상 최초 상태와 완전히 동일 | 정확히 동일 | PASS | quality_fallback.log |

### 기준을 바꾼 부분(투명 공개)
- `lowend_pixels.gd`: 이전 비교(스크린샷 전/후 base-vs-base)는 시간 의존 노이즈 6만~11만 px 로 무의미해 버렸고, 위 방식(프로세스 내 정지 비교)으로 교체. 중간에 `total_off==0 → FAIL` 을 삭제했다가 **복원**했다. 컬링 대상이 없는 맵은 `--allow-nocull` 을 명시한 때만 통과하며 출력에 "컬링 증명 대상 아님"을 남긴다. 상 등급 컬링 불변 증명의 실질 근거는 gyeongju(컬링 4개)뿐이다 — 한계로 명시.
- 시도했다 버린 방법: main worktree 와 브랜치를 **별도 프로세스**로 같은 프레임 캡처해 비교. 셰이더 `TIME`(엔진 시작 후 누적)이 프로세스마다 달라 같은 코드끼리도 1~5만 px 가 달라져(분리 증명 불가) 폐기했다(증거 `evidence/lowend/abandoned/`). 대신 ②처럼 같은 프로세스 내 비교로 대체.
- 한계: 파티클(귀화)·적·플리커는 정지/제외 상태에서 비교했다. 상 등급에서 파티클 수는 `_ash.amount == 원래값`(시나리오 8 의 복귀=상 동일 검사)으로만 확인.

## 2. tests/quality_fallback.sh — PASS
`quality_fallback.log` 끝: `QUALITY_RESULT PASS` / `PASS quality_fallback`. 시나리오: 정상 프레임 불변, 히치 무시, 2→1→0 하락·0 에서 정지, 20초 여유 시 한 단계씩 복귀, 25~30ms 경계 유지, **핑퐁 방지(2→1→2→1 후 60초 여유에도 1 유지)**, 고정 모드, 이벤트 로그 8줄, 레벨 적용(상/중/하 수치·복귀 동일).
첫 실행에서 FAIL 2건(핑퐁 off-by-one 버그, 레벨 검사의 시야 가정 오류)이 나왔고 앞의 것은 제품 버그라 코드를 고쳤다.

## 3. 회귀 5종 (src = b9edaed 와 동일 상태에서 실행) — `regression5-at-b9edaed.log`
- smoke_godot: 7/7 PASS (title·intro·beach·pyega·boss·kneel·endcont)
- save_check: 42 checks PASS
- combat_strategy: 11/11 PASS
- art_walk: 6/6 PASS
- chapter1_playthrough: 6/6 PASS (chain 88 checks 등)
참고: smoke 의 ERR_CANT_OPEN 7줄은 헤드리스 오디오 장치 없음(기존과 동일). beach 맵 테스트 실행 중 `crab.gd:48 null has_method` 로그는 테스트가 플레이어를 순간이동시킬 때 나오는 기존 코드 경고로 이 브랜치와 무관(폴백 코드 미관여, 회귀 5종은 통과).

## 남은 위험
- 실기기(폰)에서의 실제 프레임 시간 임계(34.8ms/22ms)와 하락 체감은 미측정 — VM(llvmpipe)에서만 단위 검증했다.
- 컬링 마진 48px 는 카메라 속도가 매우 빠른 컷에서 라이트 팝인 가능성이 이론상 있다(0.1초 주기).
