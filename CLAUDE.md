# 신 처용가 — 작업 기준

## 스토리·세계관
- **`docs/story-bible.md`가 모든 스토리·대사·장면 구성의 최우선 기준이다.** 기획안·기존 웹판(`src/`)과 충돌하면 바이블을 따른다.
- 장면은 바이블의 장면 ID(SC1-01 …)로 구현하고, 코드·커밋에도 그 ID를 남긴다.
- 대사 톤: 가벼운 시대극(~하오/~소/~오). 처용은 한 문장, 말이 적다. 감정은 노래·춤으로.
- 전투 철학: 처용은 죽이지 않고 **정화**한다(쓰러진 요괴의 탁기를 처용가로 걷어냄). 보스는 '처치'가 아니라 '무릎 꿇는다'.
- 1장 복선 "왕이… 오신다", 인트로 자막 "노래가 완성되면 —"은 반드시 살린다.

## 플랫폼
- **모바일 게임(가로 화면).** 모든 UI·조작은 터치 우선: 왼쪽 플로팅 조이스틱, 오른쪽 버튼. 키보드는 개발 편의용.
- 튜토리얼은 BotW식: "○○를 눌러보세요" 텍스트 금지, **빛나는 버튼은 한 번에 하나**, 상호작용은 "다가가면 버튼이 빛난다"로 통일.

## 엔진·구조
- Godot 4.4, GL Compatibility, 480x270 정수 배율 픽셀 퍼펙트. 프로젝트는 `godot/`.
- 흐름: `title.tscn` → `intro.tscn`(인트로 샷 1~4) → `level.tscn`(모든 레벨 공용, `Levels.DATA[Game.level_id]`).
- 스토리 비트는 전부 `scripts/story.gd`(오토로드 Story): `on_enter` / `interact` / `trigger` / `objective`(용패 길잡이). 진행은 `Game.flags`.
- 레벨 데이터 `scripts/levels.gd`: props(5번째 칸 = 표시 조건 플래그), npcs(6번째 칸 "hidden"), interact, triggers, vents, exits, ambient.
- 이전 웹판(`index.html`, `src/`)은 참고용 원본이다. 새 작업은 Godot에서 한다.

## 아트 파이프라인 (전부 코드로 생성, 외부 에셋 없음)
- `art/src/*.py` 도트 격자 → `python3 art/build.py` (캐릭터·NPC 시트)
- `art/vox.py` 복셀 3D → 사선 3/4 도트 (건물·석등·장승·석축·돌담 등, 노멀맵 포함)
- `art/ground3d.py` 높이 지도 → 레벨 지형 한 장 (윗면·절벽 옆면·물·충돌)
- `art/props.py` 손그림 소품, `art/enemies.py` 적·보스, `art/fx.py` 이펙트, `art/ui.py` UI
- `art/normals.py` 노멀맵, `art/tiles.py` 지형 텍스처·팔레트
- 화풍: 시오브스타즈식 3/4 탑다운 + 옥토파스식 HD-2D 후처리(심도·블룸·색보정). 색조는 어두운 푸른 밤, 따뜻한 등불·보랏빛 귀화가 포인트.

## 검증
- 화면 확인: `xvfb-run` + `godot -- --capture=out.png --frames=N [--at=x,y] [--hold=action] [--seq=action:frame,...]`
  - 캡처 중엔 60fps 고정(프레임 ≈ 초×60). `--seq`는 실제 입력 이벤트를 보내므로 대화(confirm)도 넘길 수 있다.
  - 바로 진입: `--level=<id> [--spawn=<name>] [--flags=a,b]`, 타이틀 `--title`, 인트로 `--intro`.
  - 테스트 훅: `--test-enemies`(또는 `--test-enemies=키,키` 요괴 소환), `--beach-fight`(SC1-05), `--boss`, `--boss-weak`, `--boss-kneel`(SC1-19부터).
  - 결과 줄에 남은 적·쓰러진 적·레벨·플래그·플레이어/보스 상태가 찍힌다.
- 캡처 결과(남은 적 수 등)를 근거로 동작을 확인한 뒤에만 완료라고 보고한다.
