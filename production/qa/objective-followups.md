# 목표·마커 후속 QA 항목 (프로그래밍팀-목표마커구현, 2026-10-13)

설계서: `design/gdd/objective-marker.md` §10 ③ — 디렉터 결정으로 이번 구현 범위 밖. QA 가 확인한다.

## F-1 관아 스폰 ↔ 출구 5px
- 현상 의심: `levels.gd` gwana `spawns.start` = (95,395), 마당 남쪽 출구 `Rect2(50,400,100,19)` → 스폰 발끝과 출구 사각형 위 변이 **5px**. 입장 직후 출구 `body_entered` 가 반응해 곧장 경주로 되돌아가지 않는지 확인 요청.
- 지금 알려진 완충: 레벨 전환 중 `Game._busy` 로 `change_level` 이 무시되고, 출구 Area2D 는 `add_child.call_deferred` 로 늦게 붙는다. 이 완충이 입장 직후 몇 프레임 동안만 유효한지가 불확실.
- 확인 방법: `--level=gwana` 스폰 직후 1~3초 캡처로 레벨 id 유지 확인 · 하네스 chain 의 gwana 구간에서 `free_player` 직후 `G.level_id == "gwana"` 단언 추가 · 실제 입력으로 위쪽(북)으로 한 걸음 걸은 뒤 되돌아 남쪽으로 걸어 출구가 의도대로 동작하는지.
- 새 목표 마커와의 관계: `ch1.gwana.leave` 의 출구 빔(100,410)은 스폰에서 약 15px 떨어져 있어 `briefed` 후 복귀 시에는 핸드오프(32px) 안쪽이라 빛이 안 뜬다. 문제 아님(출구는 그대로 밟으면 이동).
