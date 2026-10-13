# 시점 1단계(A+ 가로 확장 + 카메라 보강) 검증 기록

> 브랜치 `prog/view-stage1` (design/view-camera d991497 기준) · 프로그래밍팀 · 2026-10-13
> 구현 범위: design/gdd/view-camera.md §5.1·§12 의 1단계만. 2단계(논리 360·지형 재굽기)·에셋 변경 없음.

## 구현 요약
- `src/scripts/view.gd`(오토로드 `View`): 레벨은 논리 높이 270 고정, 폭 = `clamp(floor(270·창W/창H), 480, min(640, 맵 폭))`. `content_scale_size` 로 직접 설정(aspect keep, 정수 배율 유지). 창 크기 변경 시 재계산. 타이틀·인트로·회상(overlay)은 480x270 고정(`set_fixed`/`lock_base`). 맵 폭 상한은 `level.gd` 가 `View.set_cap(size[0])`(palace 512). `floor` 인 이유: 반올림하면 `창W/폭`이 `창H/270` 아래로 떨어져 정수 배율이 한 단계 내려갈 수 있다.
- HUD: 우측 버튼·링·부적 이름표는 `_right` 컨테이너로 묶어 `View.extra()` 만큼 우측 앵커, 토스트는 뷰 폭, 보스 막대·대화창은 가운데(`View.pad()`), 좌측 상태 막대·조이스틱 대기 위치 불변. 회상 배경은 전체 앵커. 버튼 좌표·크기·터치 반경 값은 그대로.
- 카메라(`level.gd _update_camera`): 처용 자식 Camera2D 의 `position` 만 사용(`offset` 은 연출 트윈 전용이라 불변). 데드존 ±16 + 정지 0.4초 후 서서히 중앙 복귀, 룩어헤드 (64,40) 보간 0.06(놓으면 0.14), 전투 프레이밍(추격·공격 중 가장 가까운 요괴 방향 최대 24px, 보스 포함), 연출(`locked`) 중 해제, 80px 이상 순간이동은 즉시 스냅. 맵 밖은 Camera2D limit 이 막는다. 안개 먼지 방출폭은 뷰 폭에 맞춰 확장.
- `--view=` 프로토 플래그(a2/b576/b640/c75/bkh)와 `Capture.view_*` 제거(기본 동작으로 승격). `--winsize=WxH`(창 크기 흉내)는 `View` 가 처리해 계속 쓸 수 있다.
- 불변: 어그로 130, 전투·구르기 타이밍 상수, 지형 PNG·에셋, 천지울림 판정 사각형(`player.gd:1163`, 480x270 고정, 카메라 중심 기준).

## 자동 검증
| 항목 | 결과 |
|---|---|
| `tests/hud_layout.sh` (480/585/600/640 폭 × 겹침·가장자리·이름표 + 타이틀) | PASS |
| `tests/view_range.sh` (신규: 12맵 × 폭 4종 × 8방향 = 맵 밖 빈 공간 0, 뷰포트 높이 270·폭 상한·정수 배율, 룩어헤드 0.5초 복귀 ≤2px) | PASS 504/504 |
| `tests/art_walk.sh` 12맵 | PASS 12/12 |
| `tests/combat_strategy.sh` | PASS 11/11 |
| `tests/chapter1_playthrough.sh` | PASS 6/6 (chain·save_mid·continue_mid·corrupt_save·death·boss_retry) |
| `tests/save_check.sh` | SAVE_CHECK_PLACEHOLDER |
| `tests/smoke_godot.sh` | SMOKE_PLACEHOLDER |

smoke 의 boss(400프레임)는 부하 12~15 상황에서 180초 제한에 걸려 1회 rc=124 가 났다. 같은 장면을 제한 없이 돌리면 변경 트리 285초·베이스라인(d991497) 305초로 둘 다 정상 종료(SCRIPT ERROR 0)라 부하 탓이다(재실행 결과는 위 표).

## 12맵 캡처 확인 (이미지를 직접 열어 확인)
`production/qa/view-stage1/capture.sh` 로 아이폰 2556x1179(뷰포트 585x270, 배율 4.0)·갤럭시 2400x1080(600x270, 배율 4.0) 창을 흉내내 맵마다 스폰/좌상단/우하단(갤럭시는 우하단)을 촬영. 원본 `raw/`, 모음 `iphone_sheet1.png`·`iphone_sheet2.png`·`galaxy_sheet.png`.
- 12맵 전부 맵 밖 빈 공간·잘림 없음(구석 위치 포함). palace 는 512 폭 상한이라 좌우 검정 레터박스(의도).
- HUD: 좌측 상태 막대 유지, 터치 UI 는 우측 가장자리에 붙고 크기·모양 동일(`touch_compare.png`: 위 585 폭, 아래 480 폭).
- 480 폭(창 960x540): 뷰포트 480x270, 배율 2.0, 처용 화면 위치 (240,160) 로 d991497 과 동일.

## 남은 위험·미검증
- 폰 실기: 캔버스 px 가 기기 px 인지 CSS px 인지(R7), ≥30fps(R4)는 미확인. `perf.sh` 는 이번에 돌리지 않았다(AC1-7 미측정; 라이트 컬링은 뷰 크기를 이미 쓴다).
- 카메라 보강은 정지 직후 처용이 중앙에서 최대 16px 벗어날 수 있다(0.4초 뒤 복귀). 천지울림 판정 사각형은 카메라 중심 기준이라 룩어헤드만큼 이동하나 크기는 480x270 그대로.
- 안개 먼지(`ash`)는 방출폭만 넓혔고 개수는 그대로라 넓은 뷰에서 밀도가 약간 낮다.
- 위·아래 어그로 여유(세로 시야)는 이 단계로 개선되지 않는다(설계 한계, 2단계 과제).
- 캡처는 xvfb 소프트웨어 렌더, 보스·전투 중 프레이밍은 정적 캡처로만 확인(동작은 view_range·5종 회귀가 보증).
