# 신 처용가 — 작업 기준 (2026-10-20 리셋, 2.5D 웹 RPG)

- 설계 기준: `docs/game-design.md`. 코드 구조: `docs/architecture.md`.
- 이전 Godot/웹판은 git 기록(리셋 이전 커밋)에만 있다.
- 대사 톤: 가벼운 시대극(~하오/~소/~오). 처용은 한 문장, 말이 적다.
- 처용은 죽이지 않고 정화한다. 보스는 무릎 꿇는다.

## 그래픽
- 인물·요괴·지형: PixelLab API로 새로 생성(`.mcp.json`, env `PIXELLAB_API_KEY`). 환경 네트워크에 `api.pixellab.ai` 허용 필요.

## 실행·빌드·검증
- 개발: `npx http-server . -p 8080` → `http://localhost:8080/src/index.html`
- 단일 HTML 빌드: `node tools/build.mjs` → `dist/index.html`
- 스모크 테스트: `node tests/smoke.mjs` (Playwright, 스크린샷 `tests/out/`)
- URL 테스트 훅: `?debug=1`, `?at=x,y`(타일), `?flags=a,b`, `?quest=n`

## 작업 방식
- `main`에서 브랜치 → 커밋·푸시 → PR → 바로 머지(merge 커밋).
