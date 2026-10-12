# 2장 M1 에셋 임포트 (아트팀 → 프로그래밍팀)

브랜치 `asset/ch2-m1` (base = `prog/ch2-m1` bb72493). 정본 설계: `design/levels/ch2-dokkaebigol.md` §4.1~4.2·§11, 요청서 `production/qa/ch2-asset-needs.md`.
**levels.gd 는 건드리지 않았다.** 아래 '교체 방법'대로 프로그래밍팀이 적용한다. 좌표는 전부 footprint(발밑) 좌표이고, 이 그림에 맞게 설계서 §4 값을 조정한 **제안**이다.

## 1. 만든 것

| 구분 | 파일 | 비고 |
|---|---|---|
| 지형 hwagae | `src/assets/levels/hwagae.png`(800×326) `_n.png` `_water.png` `.json` | footprint 800×400, 저녁 장터 광장 + 동쪽(북동) 산길 문 |
| 지형 jiri | `src/assets/levels/jiri.png`(1120×326) `_n.png` `_water.png` `.json` | footprint 1120×400(설계 384 → 아래 §5-1), 길목 폭 64 |
| 소품 | `src/assets/props/{rockwall,tent,burnt_stall,sansingak}.png` + `_n.png`(+`burnt_stall_glow`, `sansingak_glow`) | `art/ch2_props.py`(vox.py 렌더러, 1장 소품과 같은 카메라·외곽선) |
| 생성 코드 | `art/ch2_terrain.py` `art/ch2_collision.py` `art/ch2_props.py` `art/ch2_verify.py` (`art/terrain_import.py` 는 `process(img=)` 인자만 추가) | 1장 6맵 파일은 건드리지 않음 |

재생성: `python3 art/ch2_terrain.py && python3 art/ch2_collision.py && python3 art/ch2_props.py` / 검증 `python3 art/ch2_collision.py --check` · `python3 art/ch2_verify.py`.

## 2. levels.gd 교체 방법

1. `hwagae.ground` `"village"` → `"hwagae"`, `jiri_path.ground` `"pyega1"` → `"jiri"`. 레벨 시간(`time`)·`ambient` 는 그대로.
2. 아래 §3·§4 의 스폰·출입구·NPC·적·소품 좌표로 교체. 그림 y 와 footprint 의 관계: `그림 y = 0.75·fy + 30`, `fy = (그림 y − 30)/0.75`, 그림 x = fx. 맵 가장자리 벽 때문에 걸을 수 있는 최대 그림 y = 300(fy 360).
3. `level.gd` `OCCLUDE`(소품 충돌 반크기, footprint)에 추가: `"rockwall": Vector2(32, 20), "tent": Vector2(26, 12), "burnt_stall": Vector2(26, 8), "sansingak": Vector2(40, 18)`. (없으면 기본 3×3 이라 충돌이 거의 없다.)
4. 소품 목록에서 **빼야 할 것**: hwagae 의 `lantern`×6·`house`×2 (그림에 등롱 8개·기와집이 이미 있다), jiri 의 `pine`×10·`seonang`(큰 소나무·숲이 그림에 있다)·산신각 소품(그림에 산신각·제상이 있다 — `sansingak` 은 다른 산신 터용 예비).
5. hwagae `lights`(그림에 그려진 등롱 위치, `[x, fy, 색, 에너지, 크기]` 중 x, fy): (122,329) (400,157) (533,68) (619,8) (673,45) (617,103) (500,209) (362,360). 기존 값은 village 기준이라 틀리다.
6. jiri 는 그림이 어둡다(평균 V 0.22, 최대 명도 0.48). `ambient` 를 `Color(0.40, 0.44, 0.60)` 안팎으로 올려 1장 마을 수준 밝기를 맞출 것(캡처에서 폴백 ambient 0.26/0.29/0.42 로는 길목이 거의 안 보인다).
7. `heights` 는 두 맵 모두 전부 `'2'`(1장 6맵과 같은 flat 구움, `land_tier: 2`). **2단차는 시각(절벽·돌길)과 충돌로만 표현**한다(heights 로 높이를 표현하지 않음).

## 3. hwagae 화개 저자 (800×400)

그림: Drive `village` 일러스트(저녁 푸른 밤, 따뜻한 등롱)를 가로 800 이 되게 정규화. 걸을 수 있는 곳 = 우물 오른쪽 광장(남서 입구) + 북동쪽으로 오르는 산길 → 동문. 광장 중심부는 비워 두고 좌판·천막은 소품으로 얹는다.

**스폰**

| 키 | footprint (x, y) | 그림 px |
|---|---|---|
| start | (300, 340) | (300, 285) |
| fromPath | (706, 14) | (706, 40) |
| fromBoss | (360, 320) | (360, 270) |

**출입구·트리거 중심**

| 키 | footprint (x, y) | 그림 px |
|---|---|---|
| gate_E | (706, 9) | (706, 37) |
| exit_SW(3장) | (270, 354) | (270, 296) |
| raid | (365, 325) | (365, 274) |

**NPC·interact**

| 키 | footprint (x, y) | 그림 px |
|---|---|---|
| sangin | (330, 330) | (330, 278) |
| jumo | (190, 262) | (190, 226) |
| victim | (290, 335) | (290, 281) |
| elder | (580, 120) | (580, 120) |
| dok_jangsu | (420, 300) | (420, 255) |
| sansin | (680, 45) | (680, 64) |
| board | (430, 230) | (430, 202) |
| juma | (200, 262) | (200, 226) |
| dok_shop | (400, 300) | (400, 255) |

**적**

| 키 | footprint (x, y) | 그림 px |
|---|---|---|


**소품**

| 키 | footprint (x, y) | 그림 px |
|---|---|---|
| stall | (300, 296) | (300, 252) |
| stall | (345, 296) | (345, 252) |
| stall | (390, 290) | (390, 248) |
| stall | (500, 190) | (500, 172) |
| tent | (270, 352) | (270, 294) |
| tent | (420, 347) | (420, 290) |
| burnt | (320, 318) | (320, 268) |
| burnt | (395, 318) | (395, 268) |

- 동쪽 출구(`gates.path`)는 설계서의 `Rect2(794,176,6,88)`(동쪽 가장자리)이 아니라 **북동 문**이다: `Rect2(690, 2, 32, 14)`. 서쪽(3장용) 출구는 남서 길 끝 `Rect2(210, 350, 120, 8)`.
- 습격 트리거 `raid`: `Rect2(280, 290, 170, 70)`(설계서 `Rect2(300,160,200,100)` 은 이 그림에서 담벼락 안이다). `raiders` 앵커 (330,320)·(390,300).
- 설계서 §4.1 의 서→광장→동 동선은 유지(남서 입구 → 광장 → 북동 문). 광장 반경·거리 관계는 가로 약 270 / 세로 약 55(그림 px)로, 설계 의도보다 좁다 — 좌판 5개를 모두 광장에 놓으면 빽빽하다(좌판 3 은 담벼락 쪽, 1 은 산길 어귀).

## 4. jiri 지리산 산길 (1120×400)

그림: Drive `shrine`(산신각·제상·금줄 돌길·거송·절벽·돌탑) 800px + `forest`(어두운 숲 마당) 320px 합성. 서쪽 입구 돌길은 소스에서 복제해 왼쪽 끝까지 이었다.

**스폰**

| 키 | footprint (x, y) | 그림 px |
|---|---|---|
| fromHwagae | (24, 205) | (24, 184) |
| fromVillage | (655, 6) | (655, 34) |
| fromDen | (1090, 80) | (1090, 90) |

**출입구·트리거 중심**

| 키 | footprint (x, y) | 그림 px |
|---|---|---|
| exit_W | (3, 205) | (3, 184) |
| exit_N | (657, 10) | (657, 38) |
| exit_E | (1117, 77) | (1117, 88) |

**NPC·interact**

| 키 | footprint (x, y) | 그림 px |
|---|---|---|
| sansin | (250, 175) | (250, 161) |
| shrine | (258, 158) | (258, 148) |

**적**

| 키 | footprint (x, y) | 그림 px |
|---|---|---|
| sangun1 | (355, 165) | (355, 154) |
| fire1 | (580, 215) | (580, 191) |
| jangseung_taki | (665, 95) | (665, 101) |
| sangun2 | (765, 260) | (765, 225) |
| sangun3 | (940, 100) | (940, 105) |
| fire2 | (960, 260) | (960, 225) |

**소품**

| 키 | footprint (x, y) | 그림 px |
|---|---|---|
| rockwallN | (556, 152) | (556, 144) |
| rockwallN | (604, 152) | (604, 144) |
| rockwallS | (556, 310) | (556, 262) |
| rockwallS | (604, 310) | (604, 262) |
| cairn | (430, 240) | (430, 210) |

- 서쪽 출구 `Rect2(0, 181, 6, 50)`, 북 출구 `Rect2(625, 0, 64, 8)`(설계서 x520 이 아니라 돌탑 북쪽 산길), 동쪽 출구 `Rect2(1114, 42, 6, 70)`(설계서 y150~240 이 아니라 숲 마당 북동쪽).
- **좁은 길목**: 걸을 수 있는 폭 = 그림 y 168~215 = **footprint 폭 약 64**(x 538~625, 북은 거송 뿌리·남은 양치 덤불과 절벽). 검증 `reach_check.txt`: 길목 열(x540~620)을 막으면 서↔동이 끊긴다.
- **rockwall**: 설계서 4곳(540/620 × 150/250)을 이 그림에 맞춰 옮겼다. 소품 스프라이트가 깊이 27px 의 윗면을 가지므로, 길 위에 얹으면 길의 절반을 가린다. 그래서 북쪽 둘은 거송 뿌리 위(`fy 152`), 남쪽 둘은 양치 덤불 아래(`fy 310`)에 두고 길 폭은 땅그림 충돌(64)이 보장한다. `OCCLUDE rockwall` 반깊이 20 → 충돌 `fy 132~172` / `290~330` 가 길(185~245)을 침범하지 않는다. 필요하면 폭 60 을 정확히 하려고 북 `fy 165`, 남 `fy 265` 로 옮길 수도 있으나 그러면 가림이 생긴다.
- 적 배치: 설계서 §4.2 표의 의도(산군을 북쪽 벽 쪽에서 돌진시키기, 길목 한가운데 불도깨비, 길목 직후 단독 장승)를 이 그림에서 걸을 수 있는 자리로 옮겼다. `jangseung_taki`(665,95)는 돌탑 때문에 길목 직후가 아니라 북쪽 산길 쪽이다. 도착 후 x≈360 까지 적 없음은 유지.
- `sansin`/`shrine` 은 제상 앞 돌길(그림에 산신각 본채·제상이 있음).

## 5. 알려진 한계 (솔직히)

1. jiri footprint 가 384 가 아니라 **400**이다. 카메라 가동 범위(PNG 높이 − 56)가 뷰포트 270 이상이려면 H ≥ 326 이고, H=326 이면 footprint 가 400 줄이 된다. 맨 아래 줄은 맵 가장자리 벽(그림 y>300) 밖이다.
2. hwagae 는 1장 `village` 와 **같은 Drive 일러스트**(다르게 자르고 저녁 톤을 얹음)라 지붕·담이 비슷해 보인다. 장터다운 개성은 소품(좌판·천막·불탄 좌판)이 맡는다. Drive 에서 장터 일러스트를 새로 생성하면 `art/ch2_terrain.py hwagae_source()` 한 곳만 바꾸면 된다.
3. jiri 동쪽 숲 마당(x>800)은 서쪽(shrine)보다 대비가 낮고 덜 정교하다(forest 일러스트를 푸른 밤으로 눌러 이음). 길은 마당 안 열린 이끼 땅을 따라간다. 서쪽 입구의 금줄은 복제 이음새가 보인다.
4. 소품 4종은 1장 소품과 같은 렌더러지만 손으로 다듬은 `stall`·`house` 만큼 정교하진 않다(`burnt_stall`·`sansingak` 은 단순).
5. 전투 시나리오·`art_walk`·`smoke_godot` 전체는 돌리지 않았다. 검증은 §6.

## 6. 검증 증거 (`production/qa/asset-import/ch2-m1/`)

- 전/후 캡처(480×270 원본): `before_hwagae.png` `before_jiri.png`(폴백) ↔ `after_hwagae_start/gate/market.png` `after_jiri_start/pass/east/shrineyard.png`. 후 캡처는 levels.gd 를 임시 패치(커밋 안 함)해 땅그림·좌표만 바꿔 찍었다.
- 4배 NEAREST 비교: `compare_hwagae_vs_village_4x.png` `compare_jiri_vs_pyega1_4x.png` `compare_jiri_east_vs_hwagae_4x.png` — 도트 크기·경계 선명도가 1장과 같은 수준(번짐 없음, 확대는 보간 없음).
- 지표 `metrics.txt`: 알파 {255} 만(지형), 소품 {0,255} 만(반투명 없음), 고유 색 지형 ≈1200(1장 village 1091 과 같은 56색 양자화+비네트 파이프라인), 밝은 픽셀(L>0.82) 비율 0 → 흰 판 없음.
- 충돌: `overlay_hwagae.png` `overlay_jiri.png`(붉은 곳 = 막힘, 마커 = 위 제안 좌표), `reach_check.txt`(플레이어 발판 10×6 으로 부풀린 충돌에서 BFS: hwagae 14/14, jiri 모든 마커 도달 + 길목 봉쇄 시 단절).
