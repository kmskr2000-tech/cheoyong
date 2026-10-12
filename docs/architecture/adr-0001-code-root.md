# ADR-0001: 코드 루트를 `src/`(Godot)로 하고 옛 웹판을 `legacy-web/`로 이동

## Status

Accepted — 사용자 명시 결정(2026-10-12 "규약대로 진행해, 옛 웹판 src/를 legacy-web/으로 옮기고 Godot를 템플릿 규약(src/)에 맞춰").

## Date

2026-10-12

## Last Verified

2026-10-12 (Godot 4.4.1 헤드리스 import·스모크 6장면·웹 내보내기·Chromium 타이틀 로드로 확인)

## Decision Makers

사용자(결정), Claude(구현)

## Summary

템플릿은 Godot 코드 루트를 `src/`로 고정하고(`resolve_code_root`, 재정의 키 없음), 이 레포는 `src/`가 옛 JS 웹판, Godot는 `godot/`였다. Godot 프로젝트를 `src/`로, 웹판을 `legacy-web/`로 옮겨 훅·스킬이 올바른 코드를 보게 한다.

## Engine Compatibility

| 항목 | 값 |
|---|---|
| Engine | Godot 4.4.1 stable (프로젝트 `config/features` 4.4). 에디터 `~/workspace/tools/godot-4.4.1/`, 내보내기 템플릿 `~/.local/share/godot/export_templates/4.4.1.stable/` |
| `res://` | `src/` (project.godot 위치). 경로 재작성 불필요 |

## Decision

- `godot/` → `src/` (git mv, 이력 보존). `res://` 기준이 같아 스크립트·씬 수정 없음.
- 옛 `src/`·`index.html` → `legacy-web/`. 레포 루트 `index.html`은 `legacy-web/`로 보내는 임시 안내 페이지(Pages URL 유지용, Godot 웹 빌드 배포 후 교체).
- 아트 파이프라인 출력 경로(`art/*.py`, `art/_gen/*/asset.json`, `kit.config.json`) `godot/assets` → `src/assets`.
- 웹 내보내기: `godot --headless --path src --export-release Web ../build/web/index.html`.

## Consequences

- 템플릿 훅·`/dev-story`·`/code-review`가 `src/`(Godot)를 스캔한다. 이전의 "godot/ 직접 지정" 우회 불필요.
- 진행 중인 다른 브랜치·세션은 `godot/` 경로를 쓰므로 머지 시 rename 충돌 가능 — 머지 전 알림 필요.
- 옛 웹판 테스트(`dev/tests/`, Playwright)는 `legacy-web/` URL을 가리켜야 한다.
- 개발자 문서 `CLAUDE.md`·`README.md` 갱신됨. 외부 링크(Pages 루트)는 안내 페이지로 리다이렉트.

## Alternatives Considered

- 현 구조 유지·프로젝트 설정 예외: 템플릿에 재정의 키가 없어 훅·스킬이 죽은 JS를 계속 스캔 → 기각.
- 저장소 루트를 Godot 프로젝트 루트로(`res://src/...`): 모든 `res://` 경로 재작성 필요 → 기각.

## Validation Criteria

`bash .claude/hooks/yaml-helper.sh`의 `resolve_code_root`가 `src`를 반환하고 `src/project.godot`가 존재; `tests/smoke_godot.sh` 6/6; 웹 내보내기 후 타이틀 로드.
