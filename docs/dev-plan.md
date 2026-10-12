# 신 처용가 — 개발 계획 (Game Studios 템플릿 기준)

작성 2026-10-12. 근거: `docs/audit-2026-10-12.md`(점검), `files/기획안-한국신화RPG.md` v2.0(기획), 템플릿 `.claude/`(Donchitos/Claude-Code-Game-Studios, framework 1.1.3).

## 1. 현재 위치

| 항목 | 상태 |
|---|---|
| 템플릿 스테이지 | **Systems Design** (`project.yaml`, `production/stage.txt`) — 기존 GDD는 있으나 아키텍처 문서(ADR)가 없다는 템플릿 기준 |
| 실제 제품 상태 | 1장 구현 완료(Godot), 웹판은 구버전이 배포 중 |
| 리고르·자동화 | `standard` / `guided` (`project.yaml`; 바꾸려면 `/settings`) |
| 엔진 | Godot 4.4.1 GDScript, 에디터 `~/workspace/tools/godot-4.4.1/` (설치 완료) |

## 2. 템플릿 7단계와 이 프로젝트의 대응

`bash .claude/scripts/artifact-check.sh`가 각 단계의 필수 산출물 유무를 보여 준다. 아래는 이 프로젝트에서 **누가 어떻게 채우는지**다.

| 단계 | 필수 산출물(템플릿) | 이 프로젝트의 계획 | 마일스톤 |
|---|---|---|---|
| Concept | game-concept, art-bible, systems-index | game-concept ✅·systems-index ✅(이번에 작성), art-bible → `/art-bible` | M0 |
| Systems Design | 시스템별 GDD, design-review, review-all-gdds | 기존 문서에서 **`/reverse-document`로 역산**(전투·정화부터), 신규 시스템(장비·마스터리·제작)은 `/design-system` | M0~M2 |
| Technical Setup | architecture, ADR, architecture-review, control-manifest, accessibility, interaction-patterns, test-setup(CI) | ADR-001·002 먼저. CI는 `workflow` 스코프 부재로 **로컬 스크립트 대체** | M0 |
| Pre-Production | UX 스펙, epics, stories, sprint-plan, vertical-slice | 에픽 **초안**(`production/roadmap/epics-draft/`, 정식 EPIC.md는 GDD+ADR 후 `/create-epics`)·스프린트 1 ✅(이번에 작성), 버티컬 슬라이스 = 1장 (M1에서 폰 검증으로 확정) | M1 |
| Production | 스프린트 반복, story-done, code-review, qa-plan | M2~M6 | M2~M6 |
| Polish | perf, balance, playtest, security, release-checklist | M7 | M7 |
| Release | launch-checklist | M7 | M7 |

> 에픽을 `production/epics/`가 아니라 `roadmap/epics-draft/`에 둔 이유: `/create-epics` 계약(Governing ADRs·GDD Requirements 표 등)을 충족하려면 승인된 GDD·ADR이 먼저 필요하고, 형식이 다른 파일이 `production/epics/`에 있으면 `/create-stories`가 조용히 오파싱한다 (`.claude/skills/create-epics/CONTRACT.md` Known Fragile Points).

> 템플릿 전체를 문자 그대로 따르면 1인+AI 프로젝트에는 무겁다. `standard`에서도 필수인 것만 지키고(ADR 핵심 2건, GDD 5섹션), 나머지는 해당 단계에서 `/gate-check`가 CONCERNS로 알려 주면 그때 판단한다.

## 3. 스프린트 순서

| 스프린트 | 기간(1주) | 마일스톤 | 핵심 |
|---|---|---|---|
| 0 (완료) | ~10-11 | — | 점검·기획안 v2.0·이 계획 |
| 1 | 10-12~10-18 | M0 | 배포 경로·ADR·스모크·문서 정합 (`production/sprints/sprint-01.md`) |
| 2 | 10-19~10-25 | M0 | 전투·정화 GDD, 아트 바이블, 복식 감사, 잔여 |
| 3 | 10-26~11-01 | M1 | 폰 플레이테스트·성능·터치 HUD·오디오 |
| 4~5 | 11-02~11-15 | M2 | 장비·마스터리·제작·스킬 체계·분기 |
| 6~ | 11-16~ | M3~M7 | 챕터 2~5, 폴리시·출시 (`production/milestones/m3-m7-*.md`) |

날짜는 **용량 측정 전의 추정**이다. 스프린트 1·3 종료 시 `/estimate`·`/sprint-status`로 재산정한다.

## 4. 작업 방식 (템플릿 스킬 사용 순서)

레포 루트(`cheoyong/`)에서 Claude Code를 열면 `.claude/skills/`의 슬래시 명령이 잡힌다. (이번 점검 세션은 상위 `dev/`에서 열려 있어 스킬을 직접 호출하지 않았고, 각 스킬의 SKILL.md·템플릿·CONTRACT를 읽어 형식을 맞췄다. **슬래시 명령 자체는 실행해 보지 않았다.**)

1. 상태 확인: `/project-stage-detect` → `/help`
2. 설계: `/reverse-document <시스템>` 또는 `/design-system <시스템>` → `/design-review`
3. 구조: `/architecture-decision` → `/create-architecture` → `/architecture-review` → `/create-control-manifest`
4. 분해: `/create-epics <레이어>` → `/create-stories <에픽>` → `/sprint-plan`
5. 구현: `/dev-story` → `/code-review` → `/story-done`
6. 검증: `/smoke-check` → `/qa-plan` → `/playtest-report`
7. 단계 이동: `/gate-check <다음 단계>`

팀 단위 명령: 전투 `/team-combat`, 레벨 `/team-level`, 스토리 `/team-narrative`, 사운드 `/team-audio`, UI `/team-ui`, 폴리시 `/team-polish`, QA `/team-qa`, 릴리스 `/team-release`.

## 5. 이 레포 고유 규칙 (템플릿보다 우선)

- 스토리·대사: `docs/story-bible.md`. 성장·경제: `docs/growth-system.md`. (레포 `CLAUDE.md`)
- 작업은 `main`에서 브랜치 → 커밋·푸시 → PR → 머지 (레포 `CLAUDE.md`). 단, 사용자의 전역 규칙에 따라 **커밋·푸시는 사용자가 요청한 범위에서만** 한다.
- 스토리 대사 수정은 Muse 담당 영역 — 개발 계획은 제안만 하고 바이블을 직접 고치지 않는다.
- 사용자가 폰에서 확인하기 전에는 "완료"가 아니다.
- 템플릿 훅은 `settings.json`에 등록돼 있다(SessionStart·PreToolUse(Bash)·PostToolUse·Stop 등). 커밋 차단은 "검증 불가한 JSON 스테이징"에 한정됨을 확인했다. 이상 동작은 훅을 고치지 말고 보고한다.
- 코드 루트는 템플릿 규약대로 **`src/`(Godot)**. 옛 웹판은 `legacy-web/` (ADR-0001, 2026-10-12 실행 완료).

## 6. 사용자 결정 (진행 차단 순)

권장안과 근거는 기획안 v2.0 부록.

1. ~~#1 코드 루트~~ — 결정·실행 완료(ADR-0001). ~~#10 Godot 4.4.1~~ — 설치 완료.
2. **#2 챕터 2~5 분량** — M3 이후 전체 범위.
4. **#3 복식 교체 범위**, **#4 3장 처단 vs 정화 철학**, **#5 몬스터 확정**, #6~#9.

## 7. 위험

점검 보고 P1~P4와 마일스톤별 위험 표 참조. 가장 큰 세 가지: ① 배포 불일치(해결 대상 M0), ② Godot 회귀 테스트 부재, ③ 모바일 성능 미측정.

## 8. 이번 작업으로 생성·변경된 파일 (커밋 안 됨)

레포(`cheoyong/`, 전부 미커밋):
- 추가: `.claude/docs/`, `.claude/scripts/`, `project.yaml`, `production/`(stage.txt·milestones 4·roadmap/epics-draft 8+index·sprints 1), `design/gdd/`(game-concept·systems-index), `design/registry/entities.yaml`, `docs/engine-reference/`, `docs/registry/`, `docs/architecture/tr-registry.yaml`, `docs/audit-2026-10-12.md`, `docs/dev-plan.md`
- 수정: `.gitignore`(템플릿 항목 추가), `.claude/docs/technical-preferences.md`(엔진·플랫폼 기입)
- 기존 미추적 `art/hero_*.py` 등 41개는 손대지 않음.

레포 밖: `~/workspace/goals/rpg/files/기획안-한국신화RPG.md`(v2.0로 개정), `files/archive/기획안-한국신화RPG.v1.0.md`(원본).
