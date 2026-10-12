# 신 처용가 — 제1장 「처용가」

한국 신화 기반 도트 탑다운 액션 RPG. 동해 용왕의 아들 처용이 개운포에서 깨어나 서라벌의 역병을 쫓아 폐가의 역신과 맞선다.
본 게임은 삼국유사의 처용 설화를 재해석한 픽션입니다.

> **현재 개발 줄기는 Godot 4.4다.** 코드 루트는 `src/`(`src/project.godot`)이며 모바일 가로 화면(480x270, 정수 배율 픽셀 퍼펙트, GL Compatibility) 기준이다. 옛 JS Canvas 웹판은 `legacy-web/`로 옮겼고 참고용이다(ADR-0001, `docs/architecture/adr-0001-code-root.md`).
> 스토리·대사는 `docs/story-bible.md`, 성장·경제는 `docs/growth-system.md`가 기준이다. 작업 규칙은 `CLAUDE.md`, 진행 현황은 `docs/GDD.md` 부록 A, 계획은 `docs/dev-plan.md`.
> 레포 루트 `index.html`은 `legacy-web/`으로 보내는 임시 안내 페이지다. **GitHub Pages 배포 URL은 아직 옛 웹판을 가리킨다**(Godot 웹 빌드는 미배포, 스프린트 1 S1-002).

## 실행 (Godot)
엔진은 Godot 4.4.1(이 VM: `~/workspace/tools/godot-4.4.1/Godot_v4.4.1-stable_linux.x86_64`). 프로젝트 pin은 4.4이므로 다른 버전(예: 4.6)으로 열면 `project.godot`·`.uid`가 재작성될 수 있다.

```bash
GODOT=~/workspace/tools/godot-4.4.1/Godot_v4.4.1-stable_linux.x86_64

# 에디터에서 열기
$GODOT --editor --path src

# 바로 실행 (메인 씬 = scenes/title.tscn)
$GODOT --path src

# 헤드리스 import (오류 확인용)
$GODOT --headless --path src --import
```

흐름: `title.tscn` → `intro.tscn`(인트로 「떠나는 자」) → `level.tscn`(모든 레벨 공용, `Levels.DATA[Game.level_id]`). 스토리 비트는 오토로드 `Story`(`scripts/story.gd`), 진행 상태는 `Game.flags`.

### 화면 캡처·장면 바로 진입 (개발·검증용)
`xvfb-run`에서 사용자 인자(`--` 뒤)로 장면을 지정해 PNG로 남긴다. 캡처 중에는 60fps 고정(프레임 = 초×60).

```bash
xvfb-run -a $GODOT --path src --rendering-driver opengl3 -- --level=beach --capture=/tmp/out.png --frames=60
```

- 진입: `--title`, `--intro`, `--level=<id> [--spawn=<name>] [--flags=a,b]`
- 입력: `--hold=action`, `--seq=action:frame,...`(실제 입력 이벤트를 보내므로 대화도 넘긴다)
- 테스트 훅: `--test-enemies[=키,키]`, `--beach-fight`, `--boss`, `--boss-weak`, `--boss-kneel`, `--sin=100`, `--skills=id,id`, `--sp=N`, `--touch`
- 결과 줄에 남은 적·쓰러진 적·레벨·플래그·플레이어/보스 상태가 찍힌다. 자세한 설명은 `CLAUDE.md`의 "검증".

### 웹 내보내기 (시험판)
`src/export_presets.cfg`의 "Web" 프리셋(스레드 없음). 내보내기 템플릿 `4.4.1.stable`이 필요하다(`~/.local/share/godot/export_templates/4.4.1.stable/web_nothreads_release.zip`).

```bash
$GODOT --headless --path src --export-release Web ../build/web/index.html
```

`build/`는 gitignore 대상이라 산출물은 커밋되지 않는다. 4.4.1에서 내보내기 성공(wasm 약 43.7MB, 총 약 48MB), 헤드리스 Chromium에서 타이틀 로드·콘솔 에러 0을 확인했다(`docs/audit-2026-10-12.md`, `production/sprints/sprint-01.md`). **폰 실기기 확인과 배포는 아직이다.** 아티팩트 15MB 제한 대응(wasm 4조각 분할)은 `CLAUDE.md`의 "웹 빌드".

## 조작
기준은 `src/project.godot`의 입력 맵이다. **게임은 터치 우선**(모바일 가로 화면)이고 키보드는 개발 편의용이다.

### 터치 (휴대폰·태블릿)
터치스크린이 있는 기기에서 자동으로 켜지고, 데스크톱에서는 `--touch` 사용자 인자로 켠다(`scripts/hud.gd`). 왼쪽 화면에서 누른 곳이 중심이 되는 플로팅 조이스틱과 오른쪽의 버튼들로 이루어진다.

| 버튼 | 입력 액션 | 행동 |
|---|---|---|
| 왼쪽 플로팅 조이스틱 | `move_*` | 이동 |
| attack | `attack` | 대금 베기 (말을 걸 수 있는 대상이 가까우면 「말하기」 버튼으로 바뀐다) |
| roll | `roll` | 구르기 |
| talisman | `talisman` | 부적 발동 |
| swap | `swap` | 부적 전환 |
| song | `song` | 처용가 |
| dance | `dance` | 처용무 |
| menu (오른쪽 위) | `pause` | 일시정지 |

실기기(폰)에서의 조작감·성능은 **아직 확인하지 못했다**(캡처로만 확인).

### 키보드 (개발용)
| 액션 | 키 |
|---|---|
| 이동 (`move_*`) | 방향키 / WASD |
| 확인·대화 (`confirm`) | Z / Enter / Space |
| 공격 (`attack`) | X / J |
| 구르기 (`roll`) | Shift / K |
| 부적 발동 (`talisman`) | C / L |
| 부적 전환 (`swap`) | Q |
| 처용무 (`dance`) | F |
| 처용가 (`song`) | V / U |
| 일시정지 (`pause`) | Esc / P |

## 테스트
`tests/smoke_godot.sh` — 타이틀·인트로·백사장·폐가+적 소환·보스·무릎 꿇는 장면 6개를 `--capture`로 실행하고 종료 코드, `SCRIPT ERROR`·`Parse Error`, 캡처 PNG 생성을 검사한다. 하나라도 실패하면 비-0으로 끝난다. 마지막 줄에 `ERR_CANT_OPEN` 개수가 나오는데, 사운드카드가 없는 VM의 ALSA 로그일 뿐 저장 버그가 아니다.

```bash
GODOT=$GODOT tests/smoke_godot.sh      # 기본값: 위 4.4.1 경로
```

Godot 4.4.1에서 6/6 통과를 확인했다. 이 스크립트는 화면 캡처 기반 스모크이며 게임플레이 회귀 테스트는 아직 없다.

## 구조 (Godot, `src/`)
- `scenes/` 타이틀·인트로·레벨·플레이어, `scripts/` 게임 로직(`game.gd` 전역 상태, `story.gd` 스토리 비트, `levels.gd` 레벨 데이터, `player.gd`, `enemy.gd`, `boss.gd`, `hud.gd`, `audio.gd` 등), `scripts/fx/` 이펙트
- `assets/` 스프라이트·지형·UI·소리. 전부 코드로 생성한다(외부 에셋 없음): 생성 스크립트는 레포 루트 `art/`(`python3 art/build.py` 등, 자세한 파이프라인은 `CLAUDE.md`의 "아트 파이프라인")
- 템플릿 `.claude/`(Claude Code Game Studios)와 `production/`, `design/`는 개발 관리용이다.

---

## legacy-web (옛 웹판)

> 아래는 **옛 JS Canvas 웹판**(`legacy-web/`)의 설명이다. 현재 빌드와 다르다(조작 키·콤보·부적 구성·시작 장소 등). 참고용으로만 보존한다. 현재 배포된 GitHub Pages가 이 웹판이다.

### 실행
빌드 과정이 없다. 정적 파일만 서빙하면 된다 (ES 모듈이라 `file://`로는 열리지 않음).

```bash
cd legacy-web
python3 -m http.server 8000
# 브라우저에서 http://localhost:8000/
```

GitHub Pages에 이 폴더를 그대로 올리면 동작한다 (모든 경로가 상대경로).

### 화질
HD-2D 후처리는 Canvas 2D만으로 동작한다 (WebGL·엔진·외부 라이브러리 없음).
월드 렌더 시간이 평균 9ms를 넘으면 자동으로 한 단계씩 낮춘다 (2: 전체 → 1: 틸트시프트 끄고 블룸 약하게 → 0: 라이트맵·색보정만).
URL에 `?fx=2` / `?fx=1` / `?fx=0`을 붙이면 단계를 고정한다 (자동 조절 끔).
자동 조절은 CPU 렌더 시간만 보므로 GPU가 버거운 기기는 못 잡을 수 있다. 끊기면 `?fx=1`로 낮춘다.

### 조작 (키보드)
| 키 | 행동 |
|---|---|
| 방향키 / WASD | 이동 (8방향) |
| Z | 피리 베기 (연타 3단 콤보, 3타째 넉백) · 대화/조사 |
| Z 길게 눌렀다 떼기 | 강 베기 (차징, 원형 범위, 200%) |
| Shift / Space | 춤 구르기 (무적 0.4초) — 공격 직전에 구르면 받아넘기기 |
| X / C | 부적 전환 / 발동 (화염부·결박부·수호부) |
| V | 처용가 (교전마다 1회, 10초 공격력 +30%) |
| F | 처용무 (신명 100일 때, 6초 무적 난무) |
| 1 / 2 / 3 | 인삼정기탕 / 구기자환 / 정화부 |
| ESC | 일시정지 (조작법, 타이틀로) |
| M | 소리 켜기/끄기 |

### 조작 (터치 — 휴대폰·태블릿)
터치 기기(주 입력이 손가락인 기기)에서만 화면 위에 조작 버튼이 나온다. 데스크톱에서는 숨겨진다. 터치스크린 노트북은 화면을 한 번 만지면 나타난다.
URL에 `?touch=1`을 붙이면 강제로 켜고, `?touch=0`을 붙이면 강제로 끈다.

| 위치 | 버튼 | 행동 |
|---|---|---|
| 왼쪽 아래 | 조이스틱 | 왼쪽 화면 아무 데나 누른 채 끌기. 손가락이 닿은 곳이 중심이 된다 (8방향) |
| 오른쪽 아래 | 베기 | 탭 = 베기·대화/조사, 길게 눌렀다 떼기 = 강 베기 |
| | 구르기 · 전환 · 발동 · 처용가 · 처용무 | Shift · X · C · V · F 와 같음 |
| | 인삼 · 구기자 · 정화부 | 1 · 2 · 3 과 같음 (남은 개수 표시) |
| 오른쪽 위 | ☰ / ♪ | 일시정지 / 소리 켜기·끄기 |
| 컷신 중 오른쪽 위 | 건너뛰기 | ESC와 같음 |

- 대화·컷신: 화면 아무 데나 누르면 넘어간다.
- 메뉴·타이틀: 항목을 직접 누른다. 메뉴 바깥을 누르면 닫힌다.
- 상점: 한 번 누르면 설명이 나오고, 같은 항목을 한 번 더 누르면 산다 (실수 구매 방지).
- 가로 화면을 권장한다. 세로에서도 버튼이 게임 화면 아래에 배치되어 플레이할 수 있다.

### 진행
1. 인트로 (ESC로 건너뛰기 가능) → 경주 변두리 마을
2. 촌주 박노인에게 공문 듣기 → 게시판에서 의뢰 2개 (퇴마·한풀이) → 약방 노점
3. 동쪽 산길 → 폐가 입구 (체크포인트) → 1층 (독기 구멍 함정, 결박부 상자, 아이 원혼) → 2층 → 최심부 역신
4. 엔딩 → 퇴마어사 임명 → 제2장 「도깨비골」 예고

세이브: 브라우저 localStorage (`cheoyong.ch1.save`). 마을 진입·휴식, 폐가 입구에서 자동 저장. 타이틀의 "이어하기"로 마지막 체크포인트부터.

### 구조
- `legacy-web/src/main.js` 루프·씬·세이브·디버그 훅
- `legacy-web/src/world.js` 레벨(타일·충돌·카메라). 월드는 480×270 오프스크린 캔버스에 그린 뒤 2배 업스케일
- `legacy-web/src/post.js` HD-2D 연출: 컬러 라이트맵·동적 광원·블룸·틸트시프트·달빛 줄기·전경 패럴랙스·색보정·비네팅·환경 파티클·림 라이트·부드러운 그림자
- `legacy-web/src/entities.js` 처용·적·역신·부적 결계·이펙트
- `legacy-web/src/story.js` 컷신·대사·의뢰·상점·보스 연출·엔딩
- `legacy-web/src/maps.js` 맵 생성 (고정 시드)
- `legacy-web/src/gfx.js` 도트 스프라이트·타일·소품 (전부 코드로 그림, 외부 에셋 없음)
- `legacy-web/src/ui.js` HUD·대화창·메뉴 / `legacy-web/src/audio.js` WebAudio 합성 효과음 / `legacy-web/src/input.js` 키 입력 / `legacy-web/src/state.js` 전역 상태·밸런스 수치

### 테스트
Playwright 스크립트(`playthrough.py`·`scenarios.py`·`reach.py`·`boss_difficulty.py`·`hd2d_shots.py`)가 있었다. **현재 레포에는 들어 있지 않다**(`tests/`에는 `smoke_godot.sh`뿐이며, 이 스크립트들은 커밋된 이력이 없다). 아래는 당시 설명이다. 이 스크립트들은 `?debug=1` 모드로 실제 키 입력을 보내 플레이한다.
- `playthrough.py` 타이틀 → 엔딩 전체 (의뢰 2개·상점·보스 포함, 갓 모드 없이)
- `scenarios.py` 이어하기 / 사망 리스폰 / 보스전 사망 후 재도전 / 정화 없이 처치 엔딩
- `reach.py` 맵 도달 가능성 (BFS) · `boss_difficulty.py` 보스 난이도 측정
- `hd2d_shots.py` 고정 장면 스크린샷 + 렌더 시간 측정 (`GAME_URL`, `SHOTS` 환경변수)
