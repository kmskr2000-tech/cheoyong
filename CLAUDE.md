# 처용무 — 밤의 문 (2026-10-25 리셋, 리듬 액션 · 그림자극)

- 설계: `docs/game-design.md`. 모듈 계약: `docs/architecture.md`. 계약을 바꾸면 문서를 먼저 고친다.
- 이전 판(2.5D RPG, Godot)은 git 기록(이 리셋 이전 커밋)에만 있다.
- 대사 톤: 가벼운 시대극(~하오/~소/~오). 처용은 한 문장, 말이 적다.
- 처용은 치지 않고 춤춘다. 역신은 죽지 않고 무릎 꿇는다. 승리의 보상은 문에 걸리는 탈이다.

## 그래픽·소리
- 그림자극: 한지 역광 위의 검은 인형 실루엣 + 오방색. 이미지·오디오 파일 없음, 전부 Canvas 2D·WebAudio 절차 생성(`src/js/render/`, `src/js/audio.js`).
- 처용탈만 온색. 색 상수는 `render/paper.js`의 `COLORS`.

## 실행·검증
- 개발: `npx http-server . -p 8080` → `http://localhost:8080/src/index.html`
- 단위: `node tests/unit.mjs` · 스모크: `node tests/smoke.mjs`(Playwright, 스크린샷 `tests/out/`) · 한 장면: `node tests/shot.mjs "<query>" out.png <초> [KeyJ@1]`
- 빌드: `node tools/build.mjs` → `dist/index.html`
- URL 훅: `?night=n` `?dance=fever|chill|cough|pox|yeoksin` `?auto` `?mute` `?speed=k`(뮤트일 때만) `?ending` `?touch` `?seed=n`

## 작업 방식
- `main`에서 브랜치 → 커밋·푸시 → PR → 바로 머지(merge 커밋).
