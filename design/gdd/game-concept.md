# Game Concept: 신 처용가

*Created: 2026-10-12 (v1.0 기획안 2026-10-09 기반 · brownfield 채택)*
*Status: Draft — 사용자 확정 대기 항목은 하단 "Open Questions"*

> 전체 비전·보스·범위의 정본은 `~/workspace/goals/rpg/files/기획안-한국신화RPG.md` v2.0. 이 문서는 템플릿 파이프라인(`/map-systems`, `/gate-check`)이 읽는 요약본이다. 충돌 시 `docs/story-bible.md` → `docs/growth-system.md` → 기획안 → 이 문서 순으로 따른다.

## Elevator Pitch

> 동해 용왕의 아들이 신라의 비밀 어사가 되어, 노래와 춤으로 요괴를 죽이지 않고 정화하며 역병의 근원을 추적하는 모바일 가로 화면 탑다운 액션 RPG.

## Core Identity

| Aspect | Detail |
| ---- | ---- |
| **Genre** | 탑다운 실시간 액션 RPG (웨이워드 소울즈식 전투 + 위쳐식 의뢰·준비 루프) |
| **Platform** | 모바일 웹(GitHub Pages) 우선, Android 후보 |
| **Target Audience** | 한국 설화·다크 판타지·도트 액션을 좋아하는 모바일 플레이어. 세션 10~20분 |
| **Player Count** | 싱글 |
| **Session Length** | 10~20분 (체크포인트 단위), 1장 전체 40~60분 |
| **Monetization** | 없음 (프로젝트 목표상 무료 웹 게임) |
| **Estimated Scope** | 중간. 5챕터 완결, 총 약 5~7시간 (기획안 §12.1 제안, 확인 필요) |
| **Comparable Titles** | Wayward Souls(전투), The Witcher 3(의뢰·준비 루프), Sea of Stars·Octopath(화풍) |

## Core Fantasy

이름 없는 어사가 되어, 부수는 대신 **풀어준다**. 노래와 춤으로 한(恨)을 걷어내면 괴물이 원래 모습으로 돌아가고, 그 한풀이가 이야기가 된다.

## Unique Hook

"웨이워드 소울즈식 전투, **그리고** 쓰러뜨린 요괴를 죽이지 않고 노래로 정화한다." 정화가 곧 보상 구조(정기·덕망·한풀이 1.5배)이자 이야기의 주제다.

## Game Pillars

| # | Pillar | 막는 것 |
|---|---|---|
| 1 | 정화, 처치가 아니다 | 학살 보상, 시체 전리품 |
| 2 | 노래가 무기다 (처용가 1~5절) | 말 많은 주인공, 리듬 게임화 |
| 3 | 손가락으로 배운다 (글 없는 튜토리얼, 빛나는 버튼 하나) | 텍스트 튜토리얼, 키보드 전제 UI |
| 4 | 신라, 그러나 귀신이 보이는 (조선 요소 금지) | 갓·도포 외형, 사극 클리셰 |

## Core Loop

의뢰 확인 → 탐험(용패 길잡이) → 전투·정화 → 보상(정기·덕망·엽전·재료) → 준비(제작·퇴치향·강화·수련) → 귀환·보고 → 다음 의뢰.

## Player Goal & Fail State

- 목표: 5장에 걸쳐 처용가 5절을 완성하고 역신왕의 경계 붕괴를 봉인한다.
- 실패: 영구 사망 없음. 사망 시 던전 입구(보스방이면 다락)에서 재시작.

## MVP / Vertical Slice

**Vertical Slice = 챕터 1 (구현됨, 폰 검증 대기).** 인트로 → 백사장 튜토리얼 → 경주 일상 → 폐가 → 역신 → 임명 → 1절 완성. 완료 기준은 `production/milestones/m1-chapter1-validated.md`.

## Out of Scope

멀티플레이, 과금, 보이스, 패스트트래블(4장 이전), 인물록·설화 조각 수집(보류), 세이브 슬롯 다중화(보류), 필드 채집(권장: 안 함), PC·콘솔 포팅.

## Open Questions

기획안 부록 "확인 필요" 10건 — 특히 #1 코드 루트, #2 챕터 분량, #4 3장 분기와 정화 철학.

## 보완 요청

2026-10-12 검토(`design/gdd/REVIEW-2026-10-12.md`) 결과. Status는 Draft로 둔다. 아래 1~4를 반영하고 5의 사용자 결정이 나면 Approved로 올린다.

1. **Open Questions가 낡았다(위 "기획안 부록 10건, #1 코드 루트")** — 기획안 v2.0 부록은 14건이고 #1(코드 루트)은 "결정 완료(템플릿 규약 채택, ADR-0001)", #10(Godot 4.4.1 설치)은 완료다. 미결은 12건(#2~#9, #11~#14). 표로 다시 써서 항목·권장안·막는 일을 이 문서에 직접 둘 것(참조만 하면 구현자가 기획안을 열어야 한다).
2. **Out of Scope에 미결 항목이 섞여 있다** — "필드 채집(권장: 안 함)"(#8), "인물록·설화 조각 수집(보류)"(#11), "세이브 슬롯 다중화(보류)"(#12)는 사용자 결정 전이다. 확정 제외 목록과 분리하고 결정 대기로 표시할 것.
3. **출처 없는 주장** — `Monetization: 없음`, `Session Length: 10~20분`, `Out of Scope: 과금·PC·콘솔 포팅`은 GOAL.md·기획안·BRIEF-ch1 어디에도 근거가 없다(기획안에는 "세션 30분에서 30fps"뿐). 근거를 달거나 사용자 확인 항목으로 옮길 것. `보이스 없음`은 기획안 §11에 근거가 있다.
4. **템플릿 누락** — 기준은 `.claude/docs/templates/game-concept.md`다. 빠진 것: Player Experience(MDA), Player Motivation, Target Player Profile, Technical Considerations, Risks(디자인·기술·범위), Anti-Pillars(현재 "막는 것" 열이 일부 대신함), Inspiration, Scope Tiers, Next Steps. 요약본 취지에 맞게 기획안 §13(위험·성공 기준)·§10(기술)을 가져와 요약해도 된다. `/map-systems`는 "MVP Definition" 제목의 섹션을 읽으므로 "MVP / Vertical Slice"에 그 이름을 병기할 것.
5. **사용자 결정 필요(Approved 전에 결정/확인)** — 챕터 2~5 분량(기획안 부록 #2, 이 문서 Estimated Scope의 "확인 필요"), 3장 "처단"과 정화 철학(#4), 수익 모델, 세션 길이.
