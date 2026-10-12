# 2장 M1 부족 에셋 목록 (프로그래밍팀 → 아트팀)

M1(hwagae + jiri_path)은 기존 에셋으로 폴백해 동작한다. 아래가 채워지면 `levels.gd`의 `ground`·소품·좌표를 교체한다(새 아트 제작은 아트팀 몫). 정본: `design/levels/ch2-dokkaebigol.md` §4.1~4.2, §11.

| 구분 | 필요 | 현재 폴백 | 비고 |
|---|---|---|---|
| 지형 | `hwagae` (800×400, dusk/night, 장터 광장 + 동쪽 산길 출구) | 1장 `village` 땅그림(640×448) | 폴백 때문에 동쪽 출구가 NE 모서리(`gates.path`), 시작이 서쪽(140,245). 새 지형 후 설계서 좌표(§4.1)로 복귀 |
| 지형 | `jiri` (1120×384, 2단차, 좁은 길목 x540~620 폭≈60) | 1장 `pyega1` 땅그림(640×496) | 길목 학습(산군 벽 충돌)은 폴백 지형에선 성립하지 않음. 지형 교체 후 `jiri_path` 적 배치를 §4.2 표대로 |
| 소품 | `tent`×2, `burnt_stall`×2(`raided` 후), `dok_stall`·`dok_banner`(M2 SC2-12) | 없음(생략) | 화개 저자 |
| 소품 | `rockwall`×4 (좁은 길목 양옆) | 없음 | 충돌체 필요(T9) |
| 소품 | 산신각 (`shrine` interact, 300,324) | `seonang`(150,215) 로 대체 | |
| NPC | `dok_jangsu` 도깨비 장수 (`dokkaebi_extra` 프레임 4~7 파생) | — | M2(SC2-11) |
| NPC | 주모·장사치·털린 짐꾼 전용 스프라이트 | `npc_villager_f`·`npc_dolsoe`·`npc_sick` | 1장 NPC 재사용 |
| 음악 | `market`(화개), `mountain`(산길) | `night`, `dread` 로 임시 | `art/sound.py` |
| 환경음 | — | `wind` | 충분 |
| 이펙트 | `yongpae_trace`(SC2-05, M2) | — | M2 |
