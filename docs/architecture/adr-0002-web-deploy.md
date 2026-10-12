# ADR-0002: Godot 웹 빌드 배포 — gh-pages 고아 브랜치 + 버전 폴더 + no-store 로더

## Status

Accepted — 총괄 디렉터(Claude) 결정, 사용자 위임(2026-10-12 "세부 결정은 네가 알아서").

## Date

2026-10-12

## Summary

Godot 웹 빌드(약 48MB)를 main에 커밋하지 않고 `gh-pages` 브랜치로 배포한다. 매 배포는 고아 커밋 1개(히스토리 누적 없음)이고, 빌드는 `/<버전>/` 폴더에 두며 루트 로더가 `version.json`(no-store)을 읽어 최신 폴더로 보낸다.

## Decision

- Pages 소스를 `main /` → `gh-pages /`로 변경.
- 구조: `/index.html`(로더), `/version.json`, `/<YYYYMMDDHHMMSS>/`(Godot 빌드), `/legacy-web/`(옛 웹판 사본).
- 배포: `tools/deploy-web.sh` (빌드→조립→기존 gh-pages ref 삭제→고아 브랜치 push). force push를 쓰지 않는다(프로젝트 설정이 금지).
- 캐시: Godot가 고정 파일명(`index.pck`·`index.wasm`)을 쓰므로 버전 폴더로 우회. 로더는 `fetch(..., {cache:'no-store'})`. 홈화면 웹앱도 로더를 거치면 새 버전을 받는다.
- 모바일 렌더 성능·로딩은 M1 실측(wasm 43.7MB가 첫 로딩 병목 후보).

## Consequences

- main에 바이너리가 쌓이지 않는다. 롤백 = 이전 소스(`main /`)로 Pages 소스 되돌리기.
- gh-pages가 매번 재생성되므로 이전 빌드는 남지 않는다(필요하면 태그/릴리스에 별도 보관).
- main의 루트 `index.html`(legacy-web 리다이렉트)은 Pages 소스 변경 후 쓰이지 않는다. 롤백용으로 유지.

## Alternatives Considered

- `main`의 `play/`에 빌드 커밋: 배포마다 48MB가 히스토리에 영구 누적 → 기각.
- 별도 Pages 레포: 동일한 누적 문제, 관리 대상 증가 → 기각.
- GitHub Actions: `gh` 토큰에 workflow 스코프 없음 → 불가.

## Validation Criteria

헤드리스 Chromium(모바일 뷰포트)에서 루트→`/<버전>/` 이동·타이틀 캔버스 렌더(확인함, 로컬 staging). 실제 URL 배포 후 동일 확인 + 사용자 폰 확인.
