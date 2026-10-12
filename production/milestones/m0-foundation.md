# Milestone: M0 — 기반 정리

## Overview

- **Target Date**: 2026-10-25 (스프린트 2개 끝)
- **Type**: Prototype → Vertical Slice 사이의 정비
- **Duration**: 2주
- **Number of Sprints**: 2 (`production/sprints/sprint-01.md`, sprint-02는 M0 잔여로 작성)

## Milestone Goal

"사용자가 폰으로 보는 게임 = 개발 중인 게임"으로 만든다. 지금은 Pages가 옛 JS 웹판을 서빙하고, 코드 루트·엔진 버전·문서 정본이 서로 어긋나 있다(`docs/audit-2026-10-12.md`). 이 마일스톤이 끝나면 어떤 문서·빌드·테스트를 믿어야 하는지가 하나로 정해진다.

## Success Criteria

- [ ] Godot 웹 빌드가 GitHub Pages(또는 결정된 경로)에서 폰 브라우저로 타이틀까지 열린다 (사용자 확인)
- [ ] 배포된 빌드에 버전이 표시되고, 새 배포가 홈화면 웹앱에서도 자동 반영된다 (AGENTS.md 캐시 대책)
- [x] ADR-0001(코드 루트·엔진 버전) Accepted (10-12) — [ ] ADR-0002(배포 경로)
- [ ] Godot 스모크 테스트(`tests/smoke_godot.sh`)가 타이틀·인트로·백사장·폐가·보스·무릎 장면에서 통과하고 `SCRIPT ERROR` 0
- [ ] `README.md`·`DEVLOG.md`·`BRIEF-ch1.md`가 Godot 줄기를 기준으로 갱신됨
- [ ] `docs/GDD.md` 상태 오류(PLATFORM.EXPORT 등) 정정
- [ ] 템플릿 형식 GDD 2건(전투 코어·정화) `/design-review` 통과
- [ ] 기획안 부록 "확인 필요" 중 #1·#2·#10에 사용자 결정 기록
- [ ] `/gate-check technical-setup` 결과가 NOT ASSESSED 없이 PASS 또는 CONCERNS

## Feature List

### Must Ship

| Feature | Design Doc | Owner | Sprint Target | Status |
|---------|-----------|-------|--------------|--------|
| Godot 웹 빌드 배포 | docs/adr/ADR-002 | devops-engineer | S1 | Not Started |
| ADR-0001 코드 루트·엔진 버전 | docs/architecture/adr-0001-code-root.md | technical-director | S1 | Done |
| Godot 스모크 하네스 | tests/smoke_godot.sh | qa-lead | S1 | Done (6/6) |
| 문서 정합 (README·DEVLOG·BRIEF·GDD) | — | producer | S1 | Not Started |
| GDD 역산: 전투 코어·정화 | design/gdd/ | game-designer | S1~S2 | Not Started |

### Should Ship

| Feature | Design Doc | Owner | Sprint Target | Cut Impact | Status |
|---------|-----------|-------|--------------|-----------|--------|
| 아트 바이블 (`/art-bible`) | design/art/art-bible.md | art-director | S2 | gate-check concept 단계 NOT PASS | Not Started |
| 복식 감사(사모·도포·삿갓 목록) | — | art-director | S2 | M1 아트 작업 지연 | Not Started |
| `ERR_CANT_OPEN` 원인 조사 | — | godot-gdscript-specialist | S2 | 숨은 저장 버그 가능성 | Not Started |

### Stretch Goals

| Feature | Design Doc | Owner | Value Add |
|---------|-----------|-------|----------|
| 적 AI·보스 프레임워크 GDD 역산 | design/gdd/ | game-designer | 2장 설계 착수 가속 |

## Quality Gates

| Gate | Threshold | Measurement Method |
|------|-----------|-------------------|
| 스모크 | 6장면 전부 크래시·SCRIPT ERROR 0 | `tests/smoke_godot.sh` |
| 웹 빌드 | 데스크톱 헤드리스 타이틀 로드 + 사용자 폰 확인 | Playwright + 사용자 |
| 문서 | 정본이 1곳 (files/ 사본에 "참고용" 표기) | 수동 diff |

## Risk Register

| Risk | Probability | Impact | Mitigation | Owner | Status |
|------|------------|--------|-----------|-------|--------|
| 4.4.1 에디터 없이 4.6으로 열어 `project.godot` 재작성 | 중 | 중 | 스크래치 복사본에서만 실행, 설치는 승인 후 | technical-director | Open |
| Godot 웹 빌드 크기(wasm ~수십 MB)가 Pages·모바일 로딩에 부담 | 중 | 중 | ADR-002에서 측정 후 결정, 로딩 화면 | devops-engineer | Open |
| 진행 중인 개발 세션과 변경 충돌 | 중 | 중 | 브랜치 분리, 문서·테스트·배포 스크립트 위주로 시작 | producer | Open |
| gh 토큰 `workflow` 스코프 없음 → CI 불가 | 확정 | 낮음 | 로컬 스크립트 + 크론 | devops-engineer | Accepted |

## Dependencies

- 사용자 결정: 기획안 부록 #1(코드 루트), #10(4.4.1 설치).
- 외부: Godot 4.4.1 에디터와 내보내기 템플릿. CLAUDE.md는 `~/.local/share/godot/export_templates/4.4.1.stable/`에 있다고 적지만 **이 VM에는 없음(2026-10-12 확인)** — 다운로드에 사용자 승인 필요.

## Retrospective Notes

(완료 후 작성)
