# Sprint 1 — 2026-10-12 to 2026-10-18

## Sprint Goal

사용자가 폰에서 여는 게임이 개발 중인 Godot판이 되도록 배포 경로를 열고, 그 위에 안전망(스모크)과 정본 문서를 세운다.

## Milestone Context

- **Current Milestone**: M0 기반 정리 (`production/milestones/m0-foundation.md`)
- **Milestone Deadline**: 2026-10-25
- **Sprints Remaining**: 2 (이 스프린트 포함)

## Capacity

- **용량은 측정 전**이다. 1장 구현 속도(핵심 약 2일)는 신기록 구간이라 기준으로 쓰지 않는다. 이 스프린트의 실제 완료량이 첫 속도 기준선이 된다.
- 버퍼 20% 확보. 병목은 개발 시간이 아니라 **사용자 결정·폰 확인** 두 가지다.

## Tasks

### Must Have (Critical Path)

| ID | Task | Agent/Owner | Est. | Dependencies | Acceptance Criteria | Status |
|----|------|-------------|------|-------------|-------------------|--------|
| S1-001 | ADR-0001: 코드 루트·엔진 버전 | technical-director | S | 사용자 결정 #1·#10 | ADR Accepted, `resolve_code_root`=src | **Done 2026-10-12** (`docs/architecture/adr-0001-code-root.md`) |
| S1-002 | ADR-002 + Godot 웹 빌드 배포 (경로 후보: `play/` 하위, 별도 레포, 루트 교체) | devops-engineer | M | S1-001 | 배포 URL이 Godot 타이틀을 연다 (Playwright 헤드리스 + 사용자 폰). 빌드 크기·로딩 시간 기록 | In Progress — 4.4.1 설치·웹 내보내기·Chromium 타이틀 로드 확인(wasm 43.7MB, 총 48MB), 배포 경로 미정 |
| S1-003 | 배포 버전 표시 + 자가 업데이트 (AGENTS.md "GitHub Pages 배포 캐시 대책") | devops-engineer | S | S1-002 | 새 배포가 홈화면 웹앱에서 수동 새로고침 없이 반영 | Not Started |
| S1-004 | `tests/smoke_godot.sh`: 타이틀·인트로·백사장·폐가+적·보스·무릎 6장면을 `--capture`로 실행, 종료 코드와 `SCRIPT ERROR`·`Parse Error` 검사 | qa-lead, godot-gdscript-specialist | S | — | 6장면 통과. 실패 시 비-0 종료. 로그에서 `ERR_CANT_OPEN`은 별도 집계 | **Done** (`tests/smoke_godot.sh`, 4.4.1에서 6/6 PASS) |
| S1-005 | `README.md`·`DEVLOG.md`(Godot 시기 소급 요약)·`BRIEF-ch1.md`·`docs/GDD.md` 상태 오류 정정 | producer | S | — | 웹판 서술에 "옛 웹판" 표기, Godot 기준 실행·조작·테스트 설명, GDD PLATFORM.EXPORT 정정 | Not Started |

### Should Have

| ID | Task | Agent/Owner | Est. | Dependencies | Acceptance Criteria | Status |
|----|------|-------------|------|-------------|-------------------|--------|
| S1-010 | `/reverse-document`: 전투 코어 GDD (`design/gdd/combat-core.md`) | game-designer | M | — | 8섹션 중 standard 요건(5+Formulas), 수치는 코드 값에 링크, `/design-review` 통과 | Not Started |
| S1-011 | `/reverse-document`: 정화 시스템 GDD (`design/gdd/purification.md`) | game-designer | M | S1-010 | 동일 | Not Started |
| S1-012 | `ERR_CANT_OPEN` 원인 조사 (캡처 종료 시 로그) | godot-gdscript-specialist | S | S1-004 | 원인 문서화, 실제 저장 버그면 수정 이슈 생성 | **Done** — ALSA 사운드카드 없음(VM) 로그. 저장 버그 아님 |
| S1-013 | 사용자 결정 수집: 기획안 부록 #1·#2·#3·#10 | producer | S | — | 결정 기록이 `docs/decisions` 또는 ADR에 남음 | Not Started |

### Nice to Have (Cut First)

| ID | Task | Agent/Owner | Est. | Dependencies | Acceptance Criteria | Status |
|----|------|-------------|------|-------------|-------------------|--------|
| S1-020 | `/art-bible` (신라 복식 규칙·팔레트·3D 인형 → 도트 파이프라인) | art-director | M | — | `design/art/art-bible.md` | Not Started |
| S1-021 | 사모·도포·삿갓·갓 사용 스프라이트 목록 (`art/people.py`·`hero*.py`·`monsters.py`) | art-director | S | S1-013 | 목록과 교체 비용 추정 | Not Started |

## Carryover from Sprint 0

| Original ID | Task | Reason | New Estimate | Priority Change |
|------------|------|--------|-------------|----------------|
| — | 점검·기획안 v2.0·계획 수립 (이 문서 세트) | 스프린트 0으로 완료 | — | — |

## Risks to This Sprint

| Risk | Probability | Impact | Mitigation | Owner |
|------|------------|--------|-----------|-------|
| 사용자 결정 지연으로 S1-001·002 정지 | 중 | 높음 | 권장안(`기획안 부록`)으로 ADR 초안을 먼저 쓰고 Proposed 상태로 진행, 승인 시 Accepted | producer |
| Godot 웹 빌드가 4.6 에디터에서 호환 문제 | 중 | 중 | 4.4.1 설치 승인 요청, 그 전까지 스크래치 복사본에서 시험 | devops-engineer |
| 활성 개발 세션(claude-cheoyong)과 파일 충돌 | 중 | 중 | 브랜치 분리, 첫 주는 `tests/`·`docs/`·`production/`·배포 스크립트 위주 | producer |
| 템플릿 훅이 커밋·푸시를 의도치 않게 차단 | 낮음 | 중 | 차단은 "검증 불가 JSON" 한정임을 확인함(validate-commit). 오작동 시 훅을 고치지 말고 보고 | lead-programmer |

## External Dependencies

- 사용자: 결정 #1·#2·#3·#10, 폰에서 배포 URL 확인.
- 환경: Godot 4.4.1 에디터·내보내기 템플릿 모두 이 VM에 없음(`~/.local/share/godot/export_templates/` 부재 확인) — 다운로드에 사용자 승인 필요. 승인 전에는 S1-002를 "설계·측정 계획"까지만 진행.
- 도구 제약: `gh` 토큰에 `workflow` 스코프 없음 → CI 대신 로컬 스크립트.

## Definition of Done

- [ ] 각 Must 항목의 Acceptance Criteria 충족을 **실행 결과로** 확인 (캡처·테스트 출력)
- [ ] `/gate-check` 대상 아티팩트가 디스크에 존재
- [ ] 문서 정합 변경은 PR로, 사용자 폰 확인이 필요한 항목은 "확인 대기"로 표기하고 완료로 세지 않음
