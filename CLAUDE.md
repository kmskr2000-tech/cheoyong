# 신 처용가 — 작업 기준 (2026-10-20 리셋, 2.5D 웹 RPG)

- 설계 기준: `docs/game-design.md`. 코드 구조: `docs/architecture.md`.
- 이전 Godot/웹판은 git 기록(리셋 이전 커밋)에만 있다.
- 대사 톤: 가벼운 시대극(~하오/~소/~오). 처용은 한 문장, 말이 적다.
- 처용은 죽이지 않고 정화한다. 보스는 무릎 꿇는다.

## 그래픽
- 인물·요괴·지형·소품: PixelLab API로 생성(env `PIXELLAB_API_KEY`, `tools/pl.py`). 파이프라인은 `docs/architecture.md`.
  `art/gen_chars.py` · `art/gen_tiles.py` · `art/gen_props.py` → `art/raw/` → `python3 art/pack.py` → `src/assets/`.
- 다운로드는 `api.pixellab.ai`의 zip 내보내기만 쓴다(backblaze 호스트는 막힘). 동시 작업 8개 제한(429면 기다림).

## 실행·빌드·검증
- 개발: `npx http-server . -p 8080` → `http://localhost:8080/src/index.html` (논리 높이 600, UI는 따로 CSS 픽셀 기준 배율)
- 단일 HTML 빌드: `node tools/build.mjs` → `dist/index.html`
- 스모크 테스트: `node tests/smoke.mjs` (Playwright, 스크린샷 `tests/out/`)
- 끝까지 플레이: `node tests/playthrough.mjs [분]` — 자동 조종(`?auto&god&speed=6`)이 타이틀부터 엔딩까지 진행
- 한 장면: `node tests/shot.mjs "<query>" out.png <초> [KeyJ@1] [hold:KeyD@0.5-2]`
- URL 테스트 훅: `?play`, `?quest=n`(1~6), `?at=x,y`(타일), `?flags=a,b`, `?enemies=imp,snake`, `?boss=gumiho`, `?heung`, `?lvl=n`, `?touch`, `?ending`, `?mute`

## 작업 방식
- `main`에서 브랜치 → 커밋·푸시 → PR → 바로 머지(merge 커밋).
