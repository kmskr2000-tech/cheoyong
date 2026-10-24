# 신 처용가 — 코드 구조

순수 JS(전역 네임스페이스 `G`) + Canvas2D. 빌드 도구 없이 `src/index.html`이 스크립트를 순서대로 읽는다.
`node tools/build.mjs`가 스크립트와 PNG를 한 파일(`dist/index.html`)로 묶는다.

## 스크립트 (로드 순서)
| 파일 | 역할 |
|---|---|
| `js/core.js` | 수학·난수·노이즈, 입력(왼쪽 플로팅 조이스틱, 오른쪽 버튼, 키보드) |
| `js/audio.js` | WebAudio 합성: 대금·가야금·장구·징·풍경, 구역 음악(계면조), 효과음 |
| `js/assets.js` | `assets/manifest.json` 로드, 프레임 선택(8방향, 없는 서쪽은 좌우 반전), 흰색·탁기 실루엣 |
| `js/world.js` | 120×90 타일 맵 생성: 꼭짓점 지형 → Wang 코너 타일, 구역·길·관문, 소품 배치, 16px 충돌 격자, 지면 청크 굽기 |
| `js/fx.js` | 파티클(탁기 연기, 넋), 피해 숫자, 고리, 화면 흔들림·번쩍임 |
| `js/entities.js` | 처용(콤보·구르기·스킬 3종·처용가·탈·아이템), 요괴 AI(근접·돌진·강타·내려찍기·원거리), NPC, 투사체, 지면 위험, 엽전 |
| `js/boss.js` | 보스 패턴: 도깨비 대장·구미호·이무기·역신 (모두 예고 표시 후 공격, 쓰러지면 무릎) |
| `js/story.js` | 퀘스트 단계·목표, NPC 대사, 왕 이벤트, 보스 등장·패배 대사, 역신 30% 전환 |
| `js/ui.js` | HUD, 터치 버튼(빛나는 버튼은 하나), 대화창·초상, 구절 배너, 상점, 쉬어 가기 메뉴, 미니맵, 길잡이 화살표 |
| `js/game.js` | 게임 상태, 스폰·재스폰, 보스전 영역, 컷신, 저장, 2.5D 렌더(발밑 y 정렬 + 밤 조명) |
| `js/main.js` | 캔버스 크기(논리 높이 600), 상태 기계(타이틀 → 인트로 → 플레이 → 엔딩), 프레임 루프, URL 훅 |

## 그래픽 파이프라인
1. `python3 art/gen_chars.py <이름…>` — PixelLab `create-character-v3`(8방향 회전) + 애니메이션(템플릿 걷기, v3 공격·춤·무릎). 결과는 `art/raw/chars/<이름>/`.
   - 크레딧이 없을 때: `python3 art/anim_proc.py <이름…>` — 치비의 Idle 8방향 그림을 발 기준으로 휘고 늘여 걷기·공격·무릎 프레임을 만든다(현재 그슨대·꼭두각시). 메타데이터에 `procedural`이 붙으며, 나중에 `gen_chibi.py`로 진짜 애니메이션을 만들면 덮어쓴다.
   - Blender로 직접 만들기(크레딧 0): `sh tools/setup_blender.sh`(bpy 5.2 + `blender` 래퍼 + blender-* 스킬, Cycles만 동작) → `blender -b -P art/b3d/<이름>.py -- <렌더폴더>` → `python3 art/b3d/post.py <이름> <렌더폴더>`. 기본 도형으로 짠 단단한 부품 모델을 피벗별로 포즈 잡아 8방향·걷기 5방향·공격 3방향을 렌더하고(`art/b3d/common.py`, 서 있는 키 100px·발 y=122 자동 맞춤), post.py가 128px로 줄이고 40색으로 줄인 뒤 1px 외곽선을 그려 PixelLab 내보내기와 같은 구조로 쓴다(현재 석장승).
2. `python3 art/gen_tiles.py` — Wang 타일셋 8종. 모래·풀은 base tile id로 이어 붙여 세트끼리 색이 같다.
3. `python3 art/gen_props.py` — 소품(`/map-objects`, low top-down).
4. `python3 art/pack.py` — 캐릭터 아틀라스(발 위치 정렬), 타일 시트(밤 색보정), 소품 트림 → `src/assets/`.

모든 PixelLab 호출은 `tools/pl.py`(env `PIXELLAB_API_KEY`). 이미지 다운로드는 `api.pixellab.ai`의 zip 내보내기만 쓴다(Backblaze 호스트는 네트워크에서 막힘).

## 테스트 훅 (URL)
`?play` 바로 시작 · `?quest=n` 진행 단계(1~6) · `?at=x,y` 타일 위치 · `?flags=a,b` · `?enemies=imp,snake` 요괴 소환 · `?boss=gumiho` 보스전 · `?heung` 흥 100 · `?lvl=n` · `?ending` · `?mute` · `?touch` 터치 버튼 표시 · `?skipintro`

`node tests/shot.mjs "<query>" out.png <초> [KeyJ@1.2] [hold:KeyD@0.5-2]` — 헤드리스 크롬으로 실행·입력·스크린샷, 결과 줄에 상태(구역·남은 요괴·무릎 꿇은 요괴·체력·레벨·플래그·보스)가 찍힌다.
`node tests/smoke.mjs` — 주요 시나리오 묶음.
