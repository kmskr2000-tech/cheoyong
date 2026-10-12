# 팀 편성 — 4부서 (2026-10-12)

총괄 디렉터: Claude(Sonnet 5.5 주도, Opus 어드바이저). 사용자가 세부 결정을 위임했고, 막히는 것만 사용자에게 묻는다.
에이전트는 템플릿(`.claude/agents/`) 역할을 쓴다. 각 에이전트는 **자기 부서의 작업 구역에서만** 쓴다.

| 부서 | 템플릿 역할 | 작업 구역 (쓰기) | 인계받는 곳 |
|---|---|---|---|
| 기획팀 | game-designer, systems-designer, economy-designer, level-designer, narrative-director | `design/gdd/`, `design/levels/`, `design/ux/`, `docs/GDD.md`(상태), 기획안 v2.0 | 프로그래밍·아트·QA에 인계 목록 |
| 프로그래밍팀 | gameplay-programmer, ui-programmer, engine-programmer, devops-engineer, lead-programmer | `src/scripts/`, `src/scenes/`, `src/export_presets.cfg`, `src/web/`, `tools/` | 기획 GDD를 구현 기준으로 |
| 아트팀 | art-director, technical-artist | `art/`, `src/assets/`(재생성 산출물), `design/art/` | 기획 인계 자산 목록을 기준으로 |
| QA팀 | qa-lead, qa-tester | `tests/`, `docs/qa/`, `production/qa/` | 모든 부서 PR의 검증·회귀 |

| 감사팀 | (감사 전담) | `production/audit/` | 전 팀 에이전트 진전·산출물 검증, 헛도는 에이전트 적발 |

## 규칙
1. **구역 침범 금지.** 다른 부서 파일에서 문제를 발견하면 수정하지 말고 보고에 적는다.
2. 한 라운드에 `src/scripts/`를 쓰는 프로그래머는 파일 단위로 겹치지 않게 배정한다.
3. 모든 작업은 별도 브랜치·워크트리, PR까지만 올리고 **머지는 총괄만** 한다(문서 → 아트 → 코드 순, 코드 머지마다 `tests/smoke_godot.sh` 6/6 재확인).
4. 코드·스프라이트 작업은 `claude -p --model opus --add-dir <워크트리> --allowedTools Read`(프롬프트는 stdin)로 교차검토하고 반영/기각을 PR 본문에 적는다.
5. GDD는 `Status: In Review`로 올리고, 총괄이 확인해 `Approved`로 바꾼다(사용자 위임).
6. 스토리 바이블·성장 시스템 문서는 직접 수정하지 않고 제안만 한다(Muse 영역).
7. tmux 세션에 입력하지 않는다. 미추적 `art/hero_*.py`는 건드리지 않는다.
8. "완료"는 실행 결과로 확인한 것만 말한다. 폰 확인 전에는 사용자 기준 완료가 아니다.

## 현재 배정 (라운드 2)
| 부서 | 담당 | 브랜치 |
|---|---|---|
| 기획팀 | 성장 시스템 GDD 4건(장비·마스터리·제작·스킬 체계) | `design/gdd-m2-growth` |
| 기획팀 | 2장 레벨 설계서 + 보스 프레임워크 GDD | `design/ch2-level-boss-framework` |
| 프로그래밍팀 | 웹 로딩·PWA 캐시 | `prog/web-pwa-loading` |
| 프로그래밍팀 | 세이브 버전·견고성 | `prog/save-versioning` |
| 아트팀 | 외부 에셋 임포트 도구·시안 | `art/external-import-tool` |
| QA팀 | Godot 시나리오 회귀 | `qa/godot-scenarios` |
| QA팀 | 폰 체크리스트·커버리지·성능 계획 | `qa/phone-checklist-matrix` |
| QA팀 | **유저 역할 플레이테스트**(정식 배정, 에이전트 `QA팀-유저플레이테스트`): 일반 유저처럼 플레이해 버그·플레이 소감(재미·지루한 구간·난이도·조작감·그림 가독성) 리포트 | `qa/user-playtest` |

완료된 라운드 1: 문서 정합(#25)·GDD 역산(#29)·아트 바이블(#28)·복식 교체(#30)·터치 HUD(#27)·배포(#26).

## 에이전트 이름 규칙 (2026-10-12)
에이전트는 `팀명-작업명`으로 이름 짓는다(예: 아트팀-스프라이트교체, QA팀-유저플레이테스트).
