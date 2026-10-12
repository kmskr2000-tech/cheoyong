# Systems Index: 신 처용가

> **Status**: Draft (brownfield — 구현에서 역산)
> **Created**: 2026-10-12
> **Last Updated**: 2026-10-12
> **Source Concept**: design/gdd/game-concept.md

---

## Overview

1장이 Godot에 구현돼 있으므로 이 표는 "앞으로 설계할 것"이 아니라 **이미 있는 시스템에 GDD가 없다는 사실**을 기록한다. `Design Doc` 칸의 `GDD.md`·`growth-system.md`는 템플릿 형식(8섹션)이 아닌 기존 문서다. 템플릿 파이프라인이 요구하는 형식의 GDD는 `/reverse-document`로 코드에서 역산해 만든다(스프린트 1~2). `Status`는 **템플릿 형식 GDD의 상태**(템플릿이 허용하는 값만 사용 — 괄호·자유 문구 금지)이고, 코드 구현 현황은 `Implementation` 열에 따로 둔다. 템플릿 형식 GDD가 없으므로 전부 `Not Started`다.

원본 현황표: `docs/GDD.md` 부록 A (ID 단위 상태). 스토리·장면: `docs/story-bible.md`.

---

## Systems Enumeration

| # | System Name | Category | Layer | Priority | Status | Implementation (코드 현황) | Design Doc | Depends On |
|---|-------------|----------|-------|----------|--------|--------------------------|------------|------------|
| 1 | 입력·터치 컨트롤 (조이스틱, 버튼, 빛나는 버튼 가이드) | Core | Foundation | MVP | Not Started | Implemented (GDD 없음) | docs/GDD.md §10 | — |
| 2 | 플레이어 컨트롤러 (이동·구르기·상태이상) | Core | Core | MVP | Not Started | Implemented (GDD 없음) | docs/GDD.md §7 | 1 |
| 3 | 레벨 시스템 (레벨 데이터·지형·충돌·출입구·카메라) | Core | Foundation | MVP | Not Started | Implemented (GDD 없음) | CLAUDE.md "엔진·구조" | — |
| 4 | 세이브·체크포인트 | Persistence | Core | MVP | Not Started | Implemented (단일 슬롯) | — | 3, 9 |
| 5 | 전투 코어 (대금 3연타·강 베기·받아넘기기·신명) | Gameplay | Core | MVP | Not Started | Implemented (GDD 없음) | 기획안 §6 | 2 |
| 6 | 정화 시스템 (쓰러짐→처용가→한풀이) | Gameplay | Feature | MVP | Not Started | Implemented (GDD 없음) | growth-system.md §1 | 5 |
| 7 | 부적 (화염·결박·수호·파동) | Gameplay | Feature | MVP | Not Started | Implemented, 현혹·뇌성 미구현 | 기획안 §6.3 | 5, 18 |
| 8 | 적 AI·요괴 기믹 (17종) | Gameplay | Feature | MVP | Not Started | Implemented (GDD 없음) | story-bible.md 부록 E | 5, 6 |
| 9 | 스토리 비트·진행 플래그·대화 (SC ID) | Narrative | Core | MVP | Not Started | Implemented | story-bible.md | 3 |
| 10 | 컷신·인트로·타이틀 | Narrative | Presentation | MVP | Not Started | Implemented | story-bible.md 제4부 | 9 |
| 11 | 보스 프레임워크 (패턴·페이즈·무릎 연출) | Gameplay | Feature | MVP | Not Started | Implemented (1체) | 기획안 §7 | 5, 6, 9 |
| 12 | 의뢰 게시판·상점·휴식 | Economy | Presentation | MVP | Not Started | Implemented (1장분) | story-bible.md SC1-10·12 | 9, 14 |
| 13 | 성장 코어 (정기·덕망·엽전·레벨·한풀이 보너스) | Progression | Feature | MVP | Not Started | Implemented | growth-system.md §1~2·6 | 6 |
| 14 | 스킬 트리 (28수) | Progression | Feature | Vertical Slice | Not Started | Partial (20/28 동작) | growth-system.md §4 | 13 |
| 15 | 요괴 도감 (21종) | Progression | Feature | Vertical Slice | Not Started | Implemented | growth-system.md §5 | 6 |
| 16 | 장비 (피리 5단계·탈 6종·장신구·세트) | Progression | Feature | Alpha | Not Started | Partial (처용탈·역신의 눈물 획득만) | growth-system.md §3·8 | 13 |
| 17 | 마스터리 4종 | Progression | Feature | Alpha | Not Started | Not Started | growth-system.md §9 | 5, 7 |
| 18 | 제작 (부적·퇴치향) | Economy | Feature | Alpha | Not Started | Not Started | growth-system.md §11 | 13, 16 |
| 19 | HUD·메뉴 (행낭·수련·도감·일시정지) | UI | Presentation | MVP | Not Started | Implemented | docs/GDD.md §10 | 1 |
| 20 | 오디오 (합성 음악 5곡·환경음·효과음, 전투곡 전환) | Audio | Presentation | MVP | Not Started | Implemented (청취 미확인) | docs/GDD.md §9 | 3 |
| 21 | HD-2D 후처리·화질 폴백 | Presentation | Presentation | Vertical Slice | Not Started | Implemented (실기기 성능 미확인) | CLAUDE.md "아트" | 3 |
| 22 | 엔딩 분기 추적 (한풀이 누적) (inferred) | Narrative | Feature | Alpha | Not Started | Not Started | story-bible.md 5-4 | 9 |
| 23 | 해상전 (4장 갑판 전투) (inferred) | Gameplay | Feature | Full Vision | Not Started | Not Started | 기획안 §7 BOSS4 | 5, 11 |
| 24 | 분신·아군화·속성·상태이상·탐지 체계 (inferred) | Gameplay | Feature | Alpha | Not Started | Not Started | growth-system.md §4 ⏳ 8수 | 5, 8 |
| 25 | 낮/밤 사이클 (inferred, 확인 필요) | Gameplay | Feature | Full Vision | Not Started | Not Started | 기획안 §5 | 3, 9 |
| 26 | 챕터 콘텐츠 2~5 (레벨·요괴·보스·의뢰) | Narrative | Polish | Full Vision | Not Started | Not Started | 기획안 §3.3·§7 | 3, 8, 9, 11 |
| 27 | 아트 파이프라인 도구 (art/*.py) | Meta | Foundation | MVP | Not Started | Implemented | CLAUDE.md "아트" | — |
| 28 | 테스트·캡처 하네스 | Meta | Foundation | MVP | Not Started | Capture만 (회귀 없음) | CLAUDE.md "검증" | — |
| 29 | 빌드·배포 (웹 내보내기·Pages) | Meta | Foundation | MVP | Not Started | **Gap** — 배포는 옛 웹판(루트가 legacy-web로 리다이렉트). 웹 내보내기는 4.4.1에서 성공 | docs/GDD.md PLATFORM.EXPORT | — |

---

## Categories

Core · Gameplay · Progression · Economy · Persistence · UI · Audio · Narrative · Presentation · Meta (템플릿 기본에 Presentation 추가).

## Priority Tiers

- **MVP**: 1장이 돌아가기 위한 것 (전부 구현됨, 29번 배포만 Gap).
- **Vertical Slice**: 1장을 "완성된 한 구역"으로 만드는 것.
- **Alpha**: 5챕터 전체에 필요한 기계적 범위 (장비·마스터리·제작·분기·체계).
- **Full Vision**: 2~5장 콘텐츠와 폴리시.

---

## Dependency Map

### Foundation Layer
1. 입력·터치 컨트롤 — 모든 조작의 기반
2. 레벨 시스템 — 모든 장면의 기반
3. 아트 파이프라인 도구 — 모든 시각 에셋의 원천
4. 테스트·캡처 하네스, 빌드·배포

### Core Layer
1. 플레이어 컨트롤러 — depends on: 입력
2. 전투 코어 — depends on: 플레이어 컨트롤러
3. 세이브 — depends on: 레벨, 스토리 플래그
4. 스토리 비트·플래그 — depends on: 레벨

### Feature Layer
1. 정화 — 전투 코어 · 2. 부적 — 전투, 제작 · 3. 적 AI·기믹 — 전투, 정화
4. 보스 프레임워크 — 전투, 정화, 스토리 · 5. 성장 코어 — 정화
6. 스킬 트리·도감·장비·마스터리·제작 — 성장 코어(+전투)

### Presentation Layer
HUD·메뉴, 오디오, HD-2D 후처리, 컷신·타이틀, 의뢰·상점

### Polish Layer
챕터 콘텐츠 2~5, 해상전, 엔딩 분기, 낮/밤

---

## Recommended Design Order

GDD가 없는 구현 시스템은 **위험이 큰 것부터 역산**한다 (확장 시 가장 많이 건드릴 곳).

| Order | System | Priority | Layer | Agent(s) | Est. Effort |
|-------|--------|----------|-------|----------|-------------|
| 1 | 전투 코어 + 정화 (5·6) | MVP | Core/Feature | game-designer, systems-designer | M |
| 2 | 성장 코어 + 장비 (13·16) — 미구현 부분은 설계 | Progression | Feature | economy-designer, systems-designer | L |
| 3 | 적 AI·기믹 (8) | MVP | Feature | game-designer, ai-programmer | M |
| 4 | 보스 프레임워크 (11) — 2~5장 보스를 담을 확장점 | MVP | Feature | game-designer | M |
| 5 | 부적 + 제작 (7·18) | Alpha | Feature | systems-designer | M |
| 6 | 마스터리 (17) | Alpha | Feature | systems-designer | S |
| 7 | 스킬 체계 8수 (24) | Alpha | Feature | systems-designer | L |
| 8 | 엔딩 분기 (22) | Alpha | Feature | narrative-director | S |
| 9 | 레벨 시스템 (3), 세이브 (4) | Core | Core | lead-programmer | M |
| 10 | 해상전 (23) | Full Vision | Feature | game-designer, level-designer | L |

Effort: S = 1 세션, M = 2~3, L = 4+.

---

## Circular Dependencies

- 부적(7) ↔ 제작(18): 제작이 부적을 만들고 부적 효과가 제작 재료 수요를 정한다. 설계를 동시에 한다 (순서 5).
- 정화(6) ↔ 성장 코어(13): 정화가 보상을 주고 성장(퇴치향·정화력)이 정화 속도를 바꾼다. 보상 공식을 성장 코어 GDD에 한 곳에 두고 정화 GDD가 참조한다.

## High-Risk Systems

| 시스템 | 위험 | 조치 |
|---|---|---|
| 29 빌드·배포 | 사용자 눈에 보이는 빌드가 개발 빌드가 아님 | 스프린트 1 최우선 |
| 21 HD-2D 후처리 | 모바일 성능 미측정 | M1 실기기 측정, 화질 폴백 확인 |
| 23 해상전 | 신규 전투 모드, 기존 코드 재사용 불확실 | 4장 착수 전 프로토타입(`/prototype`) |
| 24 분신·아군화·속성 체계 | 스킬 8수와 현혹부·그림자춤의 선행 조건 | 알파 전 설계 |
| 28 테스트 하네스 | Godot에 회귀 테스트 없음 | 스프린트 1 |

---

## Progress Tracker

| Metric | Count |
|--------|-------|
| Total systems identified | 29 |
| 코드 Implemented | 17 (1·2·3·4·5·6·8·9·10·11·12·13·15·19·20·21·27) |
| 코드 Partial | 4 (7·14·16·28) |
| 코드 Not Started | 7 (17·18·22·23·24·25·26) |
| Template-format GDD 완료 | 0 |
| Gap | 1 (배포) |

## Next Steps

- [ ] 스프린트 1: `/reverse-document` — 전투 코어·정화 GDD
- [ ] `/design-review` 각 GDD → `/review-all-gdds`
- [ ] ADR-001(코드 루트·엔진 버전) → `/create-architecture`
