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

## 부록: 로딩 화면·PWA 캐시·자가 업데이트 (S1-002/003)

- **로딩 화면**: `src/web/shell.html`(커스텀 셸, `export_presets.cfg`의 `html/custom_html_shell`). 진행률 바+MB 표시, 첫 방문 안내 문구, 실패 시 "다시 시도". `src/web/`은 `exclude_filter`로 pck에서 제외.
- **PWA 캐시**: Godot 내장 서비스 워커(`progressive_web_app/enabled`). 셸이 시작 전에 SW를 등록·claim해 첫 방문 다운로드가 바로 캐시에 저장된다. SW 범위는 `/<버전>/`뿐이라 루트 로더·`version.json`은 캐시되지 않는다. `index.manifest.json`의 `start_url`/`scope`는 배포 스크립트가 `../`(루트 로더)로 바꾼다 — 안 그러면 홈 화면 앱이 특정 버전 폴더에 고정된다.
- **자가 업데이트**: ① 시작 시 루트 로더가 `version.json`(no-store)을 읽어 최신 폴더로 이동(4초 타임아웃, 실패 시 마지막 성공 버전→배포 시점 버전). ② 버전 폴더가 직접 열렸으면 셸의 버전 가드가 더 새 버전이면 루트로 보낸다(다운그레이드 없음). ③ 실행 중 앱이 앞으로 돌아올 때(`visibilitychange`) 새 버전이 있으면 상단 배너 "눌러서 업데이트" 표시 — 플레이 중 강제 새로고침은 진행을 잃을 수 있어 자동 새로고침은 하지 않는다. ④ 우측 하단에 `v<배포버전>` 표시. 구버전 SW 등록은 로더가 정리한다.
- **검증 도구**: `src/web/serve.py`(Pages 흉내: gzip·ETag·max-age=600·회선 제한), `src/web/measure.py`(모바일 뷰포트 Chromium으로 다회 방문 측정).
- **측정(로컬, 4Mbps·RTT 100ms 가정, gzip 후)**: 첫 방문 전송 14.7MB(wasm 9.4MB+pck 5.2MB), 타이틀 렌더까지 약 51초. 재방문 전송 86B(version.json만), 타이틀까지 약 8~12초(엔진 기동 시간). 콘솔 에러 0(favicon 404 제거 후).
