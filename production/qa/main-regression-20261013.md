# main 일괄 회귀 — 2026-10-13 (prog/view-stage1 머지 후)

기준 커밋: 3fe5145 (merge: prog/view-stage1). 워크트리 wt-merge2, godot 4.4.1 헤드리스, flock 직렬화. 배포 없음(라이브 20261013030331 유지).

| 테스트 | 결과 | 비고 |
|---|---|---|
| hud_layout.sh | PASS | 130 PASS / 0 FAIL, 4폭(480/585/600/640) + 목표 문구 검사 이관 |
| objective_hud.sh | PASS | 20/0 |
| objective_via.sh | PASS (DONE) | 정보 출력형, FAIL 0 |
| objective_targets.sh | PASS | 190/0 |
| smoke_godot.sh | PASS | 13/0 (정보: ERR_CANT_OPEN 13줄, 실패 기준 아님) |
| save_check.sh | PASS | 42 checks |
| combat_strategy.sh | PASS | 11/0 |
| art_walk.sh | PASS | 12/0 |
| chapter1_playthrough.sh | PASS | 6/0 (엔진 종료시 leak 경고만) |
| ch2_aggro.sh | PASS | 9/0 |
| view_range.sh | PASS | 504 checks, 0 fails |

충돌 해소 요약: level.gd `_process`는 `_update_camera(d)` 유지 + `if _beacon:`, GUIDE_VIEW 상수는 `View.size.x * 0.5` / `GUIDE_VIEW_Y=135`로 대체. hud.gd `_layout()`에서 목표 문구 띠를 `OBJ_RECT.position.x + View.pad()`로 중앙 정렬. tests/hud_layout.gd는 4폭 루프(_hud_checks)에 목표 문구 검사(h8~h10)를 이관, h8a는 pad 반영.

Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>
