# 2장 M2 에셋 임포트 (아트팀 → 프로그래밍팀)

브랜치 `asset/ch2-m2` (base = origin/main af5757a). 정본 설계 `design/levels/ch2-dokkaebigol.md` §4.3~4.6·§11, 요청서 `production/qa/ch2-m2-asset-needs.md`(브랜치 prog/ch2-m2).
**levels.gd·level.gd 는 건드리지 않았다.** 적용은 프로그래밍팀. 좌표는 전부 footprint(발밑) 좌표이고 아래 그림에 맞춰 설계서 §4 를 고친 **제안**이다.
**실제 적용 예시(전부 작동하는 levels.gd 교체 텍스트)는 `preview_patch.py` 가 만든다** — prog/ch2-m2 worktree 에 임시로 적용해 godot 걷기 검증·캡처를 돌렸고(커밋 안 함), 그대로 참고하면 된다: `python3 production/qa/asset-import/ch2-m2/preview_patch.py <prog/ch2-m2 worktree> <이 worktree>`.

## 0. 먼저 읽을 것 — 설계서와 달라진 점·한계 (솔직히)

1. **크기**: den1 800×326(설계 960×400), old_village 800×326(설계 800×384), den2·den3 640×326(설계 384·400). 그림 높이 326 은 M1 과 같은 이유(카메라 가동 범위 270 확보). footprint 높이는 모두 400.
2. **old_village 는 1장 `village` 일러스트를 좌우 반전·하단 782행으로 잘라 쓴 재가공**이다(1장 경주·M1 hwagae 와 같은 소스). 설계서의 '무너진 초가 4채·북쪽 담 우회로'가 아니다 — 지붕 기와 집이 그림에 박혀 있고(기와 구멍·이끼·서까래만 얹음), 우회로는 **동쪽 담·덤불 속에 새로 깐 샛길 고리**다. 같은 소스 재사용 때문에 '재방문 느낌'은 줄었지만(조명을 따뜻한 주황→보랏빛 귀화로 반전, 바닥 온기 제거) 완전히 없지는 않다. `hut_ruin` 소품은 그림에 이미 있는 집 때문에 걸을 수 없는 덤불 쪽에 장식으로만 놓았다. 소스 일러스트 없이 만드는 v2(맨 바닥 + 초가 소품)는 퀼팅 실험이 반복 얼룩으로 실패해 하지 못했다.
3. **den2·den3 바닥은 코드로 그린 판석**(`art/ch2m2_lib.py flagstones`)이고 벽은 2D 석축 페인터(`art/ch2m2_walls.py`)다. 일러스트(den1)보다 단조롭다. 대신 원형 광장(반경 150)·아레나(≥300×300)라는 설계 형태는 정확히 지켰다. 두 맵의 장식(항아리·물웅덩이·문양 석판)은 den1 일러스트에서 뜬 스탬프다.
4. **den1 은 dungeon 일러스트 하단**이라 설계서의 'A 입구 홀→B 기둥열 곳간→C 통로' 형태가 아니다: **A 서쪽 복도 → (북서 문양 바닥) → B 북쪽 큰 방 → 동쪽 복도 → C 덩굴 방**, 그리고 중앙 복도가 막다른 곁방이다. 기둥벽 두 군데(x430~448, x540~558)는 일러스트의 벽을 그림에서 지워 '무너진 벽'으로 만들어 길을 냈다. 우회 샛길 = 북쪽 큰 방.
5. 문(동문 `add_barrier`)은 그림에 문짝이 없고 문설주(석주)만 있다 — 막 그대로 쓴다.
6. 4배 확대로 번짐·흰 판·팔레트 이탈은 확인되지 않았다. **타일 반복 이음새는 없다(타일 아님) — 단, den2/den3 의 판석이 일정한 벽돌 같다는 인상은 4배 비교로도 확인된다.** 인게임에서는 ambient 와 점광원이 겹쳐 den 계열이 상당히 파랗다 — ambient 를 아래 값보다 더 낮추지 말 것(어두워지면 판석 질감이 죽는다).
7. 전투·`ch2_aggro`·smoke 는 돌리지 않았다(아래 §6 은 지형·충돌·무전투 동선만).

## 1. 만든 것

| 구분 | 파일 | 비고 |
|---|---|---|
| 지형 | `src/assets/levels/{old_village,den1,den2,den3}.png` `_n.png` `_water.png` `.json` | `land_tier 2`(M1 과 같은 flat 구움), 충돌 json = 아래 걷기 마스크에서 굽는다 |
| 소품 11종 | `src/assets/props/{hut_ruin,hut_ruin_b,old_tools,old_tools_mortar,old_tools_broom,old_tools_pot,old_tools_sandals,dok_torch,mortar_altar,doll,rockwall}.png` + `_n.png` + `dok_torch_glow` `mortar_altar_glow` `hut_ruin_b_glow` | `rockwall` 은 M1 파일을 개선판으로 **교체**(같은 이름·같은 크기 64×52, 충돌 OCCLUDE 그대로) |
| 코드 | `art/ch2m2_terrain.py`(지형) `ch2m2_maps.py`(걷기 마스크=지형·충돌 단일 원천) `ch2m2_collision.py`(충돌 json + 게임 충돌 재현 검증) `ch2m2_markers.py`(좌표) `ch2m2_props.py`(소품) `ch2m2_walls.py`(석축) `ch2m2_lib.py` `ch2m2_verify.py` | `art/vox.py` 는 `last_r0` 한 줄만 추가(동작 변화 없음) |

재생성: `python3 art/ch2m2_terrain.py && python3 art/ch2m2_collision.py && python3 art/ch2m2_props.py` (※ den3 는 art/ch2den3_terrain.py 가 정본 — ch2m2_terrain.py 의 den3 는 그쪽으로 위임) / 검증 `python3 art/ch2m2_collision.py --check` · `python3 art/ch2m2_verify.py`.

## 2. levels.gd 교체 방법

1. ground 교체: `old_village.ground "village"→"old_village"`, `den1 "pyega1"→"den1"`, `den2 "gwana"→"den2"`, `den3 "pyega2"→"den3"`.
2. 그림 y 와 footprint: `그림 y = 0.75·fy + 30` (fy = (그림 y−30)/0.75, 그림 x = fx). 걸을 수 있는 최대 그림 y = 300(fy 360).
3. `level.gd` OCCLUDE(소품 충돌 반크기, footprint)에 추가: `"hut_ruin": Vector2(40,16), "hut_ruin_b": Vector2(40,16), "old_tools": Vector2(14,5), "old_tools_mortar": Vector2(10,4), "old_tools_broom": Vector2(3,2), "old_tools_pot": Vector2(11,4), "old_tools_sandals": Vector2(8,3), "dok_torch": Vector2(4,3), "mortar_altar": Vector2(30,12), "doll": Vector2(3,3)`. (`mortar_altar` 가 den3 엄폐 대상, `dok_torch`·`doll` 은 사실상 장식.)
4. 소품 별칭: `old_tools` 는 '모아 둔 더미', 나머지 4종(`_mortar`·`_broom`·`_pot`·`_sandals`)은 변형 — `_prop()` 이 이름당 PNG 하나를 읽으므로 이름을 그대로 쓴다. 광원: `dok_torch` `[-46, GHOSTFIRE, 0.8, 0.9]`, `mortar_altar` `[-36, GHOSTFIRE, 1.0, 1.4]` (5번째 칸).
5. ambient(캡처로 고른 값): old_village `Color(0.34,0.36,0.54)`, den1·den2·den3 `Color(0.34,0.33,0.50)`.
6. **story.gd 하드코딩 좌표 주의**: `story.gd:766` 의 den2 길잡이 `Vector2(272, 228)`(장산범 정화 전 목표)는 옛 폴백 지형 좌표다 → 새 그림에서는 장산범 위치 `(320,200)` 부근으로 바꿔야 한다. `walkability.gd` ROUTES/LIVE 의 4맵 항목도 `preview_patch.py` 의 새 값(`ch2m2_markers.py ROUTES`)으로 교체. 폴백 시절의 `anchors`(doll/grave/exit/door/hall)는 아래 표 값으로.

## 3. old_village (800×326 / footprint 800×400)

그림: village 일러스트(반전)에서 조명 반전·지붕 파손(8곳)·그을음·깨진 기와·짚. 길 = 남쪽 어귀 → 우물 마당 → 북서 길, 그리고 **우물 북쪽 풀밭 → 동쪽 덤불 속 샛길(고리) → 남쪽 길**. 걷기 면은 `art/ch2m2_maps.py`.

| 키 | footprint (x,y) | 비고 |
|---|---|---|
| spawn start / fromPath | (650,345) | |
| exit(남) → jiri_path/fromVillage | `Rect2(618,350,90,8)` | 중심 (650,352) |
| girl_soul(npc_ghost) | (748,160) | 동쪽 샛길 가운데 — 마당 요괴 어그로 밖 |
| grave(interact) | (722,335) | 어귀 오른쪽 |
| doll(interact, 의뢰 B) | (742,40) | 샛길 끝 (anchors.doll) |
| 적 | fire1 (510,288) · fire2 (470,200) · fire3 (565,140 우물 앞) · oneeye (330,53 북서 길 어귀) | 우회로(샛길)는 요괴 어그로 130 밖 |
| 소품 | hut_ruin (268,317)·(70,247) · hut_ruin_b (40,360) · old_tools_mortar (500,227) · _broom (625,320) · _pot (585,269) · _sandals (690,347) · old_tools (448,131) · doll (742,40) | 초가 3채는 막힌 덤불 쪽 장식 |
| lights(귀화) | (300,60)(425,205)(695,165)(188,8)(300,255) | 그림의 보랏빛 등롱 위치 |
| anchors | doll (742,40) · grave (722,335) · exit (650,352) | |

우회로: 마당 한가운데를 막아도 동쪽 샛길로 인형까지 이어진다. 무전투 동선: 어그로 130px 안을 모두 지워도 start→grave·girl_soul·doll 도달(`reach_check.txt`). 즉 의뢰 B 는 샛길만으로 무전투 가능, 마당(적 4)·북서 길(oneeye)은 선택.

## 4. den1 (800×326)

그림: dungeon 일러스트 하단. 푸른 귀화 → 보라(양자화 뒤 램프로 다시 칠함). 기둥벽 2곳 철거. 걷기 면 A 서쪽 복도(항아리·귀화) / 북서 연결 / B 북쪽 큰 방 / 중앙·동쪽 복도 / C 덩굴 방.

| 키 | footprint | 비고 |
|---|---|---|
| spawn start / fromDen2 | (30,181) / (765,200) | |
| exit 서 → jiri_path/fromDen | `Rect2(0,164,6,34)` | |
| exit 동 → den2/start | `Rect2(778,180,8,40)` | |
| 적 | oneeye_A (190,181) 학습용 단독 · oneeye_B1 (385,38) · fire_B1 (480,55) · oneeye 매복 (360,200 곁방) · fire_B2 (505,205) · sangun (690,195) · jangseung_taki (735,250) | |
| triggers | sight `Rect2(160,160,60,40)` · deep `Rect2(715,170,50,60)` | |
| vents | (160,181)(430,60)(640,200) | |
| 소품 | pillar×6 (350,52)(430,52)(510,52)(350,84)(430,84)(510,84) · dok_torch×8 · old_tools 10(변형 섞음) | PROPS 전체는 `ch2m2_markers.py` |
| altar | (772,200) (C 끝) | 기존 `altar` 소품을 쓰거나 interact |

우회로 2종: 북쪽 큰 방을 막아도(무너진 기둥벽 쪽 중앙 복도로) · 중앙 복도를 막아도(북쪽 방으로) 동쪽 안쪽까지 이어진다.

## 5. den2 (640×326) · den3 (640×326)

**den2**: 원형 광장 — 담 안쪽 반지름 150(footprint), 중심 (320,200). 서·동 복도. 문양 석판 + 상감 원 두 겹 + 귀화 불빛 자국.
spawn start (24,200)/fromDen3 (600,200) · exit 서 `Rect2(0,176,6,48)`→den1/fromDen2 · exit 동 `Rect2(628,176,8,48)`→den3/start · **door(장산범 정화 전 막)** `Rect2(446,170,14,60)`(동쪽 담 문설주 사이, 복도 입구) · 적 jangsanbeom (320,200) · oneeye1 (215,190) · oneeye2 (220,285) · fire (430,200) · pillar×4 (210,140)(430,140)(210,260)(430,260) · dok_torch×6 · old_tools 6.

**den3**: 걷는 면 footprint ≈ 554×316 (x44~598, 그림 y62~299). 서쪽 입구 복도 + 문. 의식 원(반경 130·98·40) 바닥 표시, 소환진 8점 표식(r=130).
spawn start (40,200) · exit `Rect2(0,176,6,48)`→den2/fromDen3 · trigger gate `Rect2(70,170,40,60)` · anchors door `Rect2(26,170,16,60)`, hall (460,200) · mortar_altar (320,200) (광원 5번째 칸) · pillar×4 (180,130)(460,130)(180,270)(460,270) · dok_torch×6 · old_tools 8 · 소환진 후보 8점: (450,200)(412,292)(320,330)(228,292)(190,200)(228,108)(320,70)(412,108).

## 6. 검증 증거 (이 폴더)

- **게임 충돌 기준 걷기**: `walk_<맵>.log` — prog/ch2-m2 worktree 에 임시 패치(`preview_patch.py`, 커밋 안 함)를 적용하고 실제 `tests/godot/walkability.gd`(발판 11×7 물리 질의, 4px 격자, 실제로 걸어서 도착)를 `flock` 로 실행: **old_village PASS(15지점·5구간) · den1 PASS(19·6) · den2 PASS(13·5) · den3 PASS(7·4)**. 이 실제 게임 검증은 처음 시도에서 3맵이 FAIL 했다(NPC·도깨비 소품 자리를 ROUTE 로 잡아 자기 충돌에 막힘) → ROUTE 를 빈 칸 옆으로 옮겨 통과. M1 의 'reach_check ≠ 게임 충돌' 문제를 피하려 `ch2m2_collision.py` 는 마스크가 아니라 **구운 json 의 실제 사각형 + 월드 가장자리 벽 + 소품 충돌 사각형**으로 같은 질의를 재현한다(`reach_check.txt`).
- `reach_check.txt`: 모든 마커 도달 OK · old_village 우회로·무전투 동선 OK · den1 우회로 2종 OK · den3 지형만 300×300 빈 사각 OK(최대 정사각 한 변 ≈304 footprint; 기둥·제단 포함 시 ≈120 — 엄폐물이 일부러 쪼갠다).
- 오버레이 `overlay_<맵>.png`(붉은 곳 = 막힘, 마커 = 위 제안).
- 전/후 캡처(480×270): `before_*`(prog/ch2-m2 폴백) ↔ `after_*`(임시 패치 + 새 에셋). 4배 NEAREST 비교 `compare_*_4x.png`.
- `metrics.txt`: 지형 알파 {255}만, 소품 {0,255}만, 밝은 픽셀 L>0.82 0% → 흰 판 없음, 지형 고유색 ≈1100~1200(1장과 같은 56색 양자화 파이프라인).
