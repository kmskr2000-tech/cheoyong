# 1장 커버리지 매트릭스 (SC1-01 ~ 25)

작성: qa-tester, 2026-10-12. 기준: `main` @ a19357a. 근거는 `src/` 읽기 + 아래 실행 2건. 코드는 수정하지 않았다.

## 현재 자동 테스트가 실제로 하는 일 (`tests/smoke_godot.sh`, 6종)
| 이름 | 인자 | 실제로 거치는 곳 | 한계 |
|---|---|---|---|
| title | `--title` | 타이틀 생성, 메뉴 | 입력 없음 |
| intro | `--intro` | 인트로 60프레임 | 끝까지 안 감 |
| beach | `--level=beach` | `level.gd:_ready` → `Story.on_enter` → `_beach_wake`(SC1-01 시작) | 60프레임(1초) — 3초 무음 구간도 못 넘김 |
| pyega1 | `--level=pyega1 --test-enemies` | 폐가 마당 로드 + 개·귀 2마리 소환 300프레임 | 전투 결과 검증 없음, 입력 없음 |
| boss | `--boss` | **beach 레벨**에 `PlagueGod` 직접 소환(`level.gd:95`) 400프레임 | 스토리 비트(SC1-15~19) 미경유 |
| kneel | `--boss-kneel` | `--level` 없음 → **beach 레벨**만 로드 | **SC1-19 무릎꿇음을 실행하지 않는다** (아래 실측) |

실측(2026-10-12, 이 워크트리): `--boss-kneel` 단독 → `level: beach  enemies left: 0  flags: {logo_shown}` (보스 없음). `--level=pyega2 --boss-kneel` → 420프레임 후 `boss … wait hp 480.0` (보스가 변장 대기 상태. `story.gd:478`의 훅은 `_inner_room`(트리거 x≥530) 안에 있어 플레이어가 그 구역에 들어가야 발동). 즉 smoke의 6/6 PASS는 "SCRIPT ERROR 없이 켜진다"는 뜻이지 스토리 검증이 아니다.
`--flags=…`로 중간 레벨에 바로 진입하는 훅(`game.gd:222`)은 있으나 smoke에는 쓰이지 않는다. `qa/godot-scenarios` 브랜치(별도 작업)가 늘릴 예정이면 이 표의 "자동" 칸을 갱신할 것.

범례: 자동 = smoke가 해당 코드 경로를 **실행**(검증은 SCRIPT ERROR 부재뿐) / 로드 = 레벨만 로드 / 없음 = 자동 경로 없음. 사람 = `phone-checklist-ch1.md` 구간.

| SC | 장면 | 구현 위치(근거) | 자동 | 사람 확인 | 비고·위험 |
|---|---|---|---|---|---|
| 01 | 파도 소리, 눈을 뜸 | `story.gd:85 _beach_wake` | 로드(시작 1초) | 구간1 | 3초 무음 후 로고 카드. `beach_done` 전엔 매번 재생 |
| 02 | 게가 도망 | `levels.gd:128 crabs`, `crab.gd` | 로드(생성만) | 구간1 | 행동은 눈으로만 |
| 03 | 대나무 피리 획득 | `story.gd:108 _pick_flute`, `levels.gd:127` | 없음 | 구간1 | 반경 26 안에서 공격(말하기) 버튼 필요 |
| 04 | 마을 비명, 갯귀 출현 | `story.gd:115-133` | 없음 | 구간1 | 카메라 이동 연출 후 `fight` 트리거 추가 |
| 05 | 튜토리얼 전투 | `story.gd:150 _fight`, `_test_fight` | 없음(`--beach-fight` 훅은 있으나 smoke 미사용) | 구간1 | 빛나는 버튼 가이드 = 터치 전용 표시 |
| 06 | 환호, 수령 | `story.gd:180 _after_fight` | 없음 | 구간1 | 정화 `purified` 신호 의존 |
| 07 | 끄덕임, 경주 전환 | `story.gd:208-211` | 없음 | 구간1 | `Game.change_level`; **세이브 없음** (체크포인트 변수만 변경) |
| 08 | 약방, 난영 첫 등장 | `story.gd:244 _talk_nanyeong` | 없음 | 구간2 | 진입 `--level=gyeongju`는 가능하나 smoke 미포함 |
| 09 | 아이 정화 | `story.gd:263-293` | 없음 | 구간2 | 노래 버튼이 저절로 빛남(`can_sing`) |
| 10 | 상점·휴식·혼례 몽타주 | `story.gd:295 _shop`, `319 _rest` | 없음 | 구간2 | 첫 **세이브**(`Game.save`). 선택지 터치 |
| 11 | 밤, 관아 사람 방문 | `story.gd:356 _night_summons` | 없음 | 구간2 | `summoned` 플래그 후 관아 출구 개방 |
| 12 | 형방 의뢰, 난영 쓰러짐 | `story.gd:385 _briefing` | 없음 | 구간3 | 세이브. 인삼정기탕 +2 |
| 13 | 폐가 1층 | `levels.gd:62-80` | **자동**(pyega1 로드+적 소환, 레벨 데이터 적 6종은 `--test-enemies`가 대체) | 구간3 | 실제 적 배치는 사람이 |
| 14 | 폐가 2층, 독기 함정 | `levels.gd:82 vents`, `story.gd:417 _close` | 없음 | 구간3 | `pyega2` 직접 진입은 가능, 트리거 `close` 필요 |
| 15 | 최심부, 변장 역신 | `story.gd:430 _pyega2_enter`, `443 _inner_room` | 로드만 가능(`--level=pyega2`, 실측: boss wait) | 구간4 | 트리거 통과는 사람만 |
| 16 | 도발 | `story.gd:460-463` | 없음 | 구간4 | |
| 17 | 처용가 연주 | `story.gd:470 p.sing()` | 없음 | 구간4 | |
| 18 | 보스전 3패턴+2페이즈 | `boss.gd` (MAX_HP 480, `phase_two`) | **자동(부분)**: `--boss`로 보스 AI 400프레임 | 구간4 | 입력 없는 보스 AI 구동 확인뿐. 사망·재시도 흐름 없음 |
| 19 | 무릎 꿇음, "왕이… 오신다" | `boss.gd:_kneel`, `story.gd:494` | **실질 없음**(smoke `kneel`은 beach만 로드) | 구간4 | 가장 큰 구멍 |
| 20 | 난영 깨어남 | `story.gd:501 _boss_defeated`, `522 _nanyeong_wakes` | 없음 | 구간4~5 | 세이브 + `rescued` |
| 21 | 처용탈 소문 | `story.gd:540`, `levels.gd:154`(tal props), `RUMOR` | 없음 | 구간5 | 처용탈 지급 |
| 22 | 왕의 부름 | `story.gd:319 _rest`(king_call), `564 _royal_summons`, `579 _audience` | 없음 | 구간5 | 밤 전환·팰리스 트리거 |
| 23 | 퇴마어사 임명 | `story.gd:590-607` | 없음 | 구간5 | 세이브 |
| 24 | 난영과 작별 | `story.gd:611 _farewell` | 없음 | 구간5 | |
| 25 | 1절 완성, 자막 | `story.gd:636-646` | 없음 | 구간5 | `chapter1_done` + 타이틀 복귀 |

## 시스템 항목 (SC 밖)
| 항목 | 자동 | 사람 | 근거 |
|---|---|---|---|
| 터치 HUD 버튼 겹침 | 없음 | 구간1·3 | `hud.gd:61-64` 버튼 중심·반경으로 계산(아래 표) |
| 가상 조이스틱 | 없음 | 구간1 | `hud.gd:_input`, 좌측 x<220 |
| 오디오(iOS 언락) | 없음(로그에 `ERR_CANT_OPEN`만 셈) | 타이틀·구간3·확인C | `audio.gd` 자체엔 언락 코드 없음 — 엔진 기본 동작 의존(미확인) |
| 세이브/이어하기 | 없음 | 확인A | `game.gd:453 save`, `title.gd:143` |
| 홈 화면 업데이트 | 없음 | 확인B | `tools/deploy-web.sh` 로더 + `version.json` |
| 프레임 | 없음 | 구간3~4 | 성능 계획은 별도 |
| 신라 복식 | 없음 | 구간2 | `art/people.py:54-62`(복두·금관), `design/art/costume-audit.md` |

버튼 터치 영역 겹침 계산(`hud.gd:61-64`, 480x270 좌표, 반경 합 > 중심 거리면 겹침):
공격(430,222,r30)–부적(394,196,r22): 거리 44.4 < 52 → **약 7.6px 겹침**. 공격–구르기(384,244,r22): 51.0 < 52 → 1px. 공격–노래(438,172,r22): 50.6 < 52 → 1.4px. 부적–노래: 44.2 vs 44 → 접함. 교체(360,186,r13)–부적: 35.4 vs 35 → 접함. `passby_press=true`라 겹침 구역·손가락 미끄러짐으로 두 버튼이 동시에 눌릴 수 있다(읽기 추정, 폰 검증 필요).
