# 신 처용가 — GDD 현황표

> 진행 추적용 문서다. 스토리·대사의 기준은 `docs/story-bible.md`, 성장·경제의 기준은 `docs/growth-system.md` — 충돌하면 그쪽을 따른다.
> 부록 A의 표가 현황판(`.claude/skills/board`)의 '기능' 칸이 된다. 상태: 동기(구현됨) · 미구현 · 불일치(구현했지만 문제) · 폐기.

## 1. 타이틀·인트로
타이틀 화면과 인트로 「떠나는 자」(바이블 제4부 PART 1). 샷 5가 곧 게임 첫 화면.

## 2. 백사장·해안 마을
개운포. SC1-01~07 — 깨어남, 게, 피리, 비명, 갯귀 튜토리얼 전투, 수령의 천거.

## 3. 경주 일상
SC1-08~11 — 난영, 아이 정화, 상점·휴식, 혼례 몽타주, 그날 밤의 호출.

## 4. 관아·서쪽 폐가
SC1-12~15 — 형방의 의뢰, 난영이 쓰러짐, 폐가 마당·다락, 독기 함정, 최심부.

## 5. 역신 보스전
SC1-16~20 — 도발, 처용가, 2페이즈, 무릎 꿇음, "왕이… 오신다", 난영이 깨어남.

## 6. 임명·작별·1절
SC1-21~25 — 처용탈 소문, 왕의 부름, 퇴마어사 임명, 작별, 1절 완성.

## 7. 전투·정화
베기 3타·구르기·부적·처용가, 쓰러진 요괴의 정화, 요괴 기믹과 정예.

## 8. 성장
정화 보상(정기·덕망·엽전), 레벨, 한풀이, 도감, 탈·장신구, 스킬·마스터리·장비 강화.

## 9. 소리
합성 음악·효과음·환경음과 전투곡 전환.

## 10. 플랫폼·빌드
모바일 가로 화면, 터치 조작, 실기기 빌드.

## 11. 2~5장
도깨비골·경주 귀족가·동해 용궁·저승 경계. 요괴 스프라이트·기믹은 준비됨.

## 12. 미정
- **1장 난이도**: 역신 체력 600→480, 관아 브리핑에서 인삼정기탕 ×2 지급으로 1차 조정. 폐가 6·7마리 밀도는 실기기 플레이로 재확인
- **스킬 트리**: 소리·춤·가호 3계열의 구체 스킬 목록 (기획안 §9.2 확인 필요)
- **피리 강화·퇴치향 수치**: 문서 수치를 그대로 쓸지, 1장 분량에 맞게 줄일지
- **실기기 빌드 방식**: 웹 빌드(폰 브라우저) / 안드로이드 APK — 내보내기 템플릿 필요
- **2장 지도**: 화개 장터 → 도깨비 소굴 구성

## 부록 A. 현황표

| ID | 내용 | 출처 | 위치 | 상태 | 비고 |
|---|---|---|---|---|---|
| TITLE.MENU | 타이틀: 처음부터·이어하기·회상 | 1 | title.gd | 동기 | |
| INTRO.SHOT1 | 바닷속 탁기, 용궁 실루엣 | 1 | intro.gd | 동기 | |
| INTRO.SHOT2 | 병석의 용왕, 맏형의 봉쇄론 | 1 | intro.gd | 동기 | |
| INTRO.SHOT3 | 용패를 쥐여 주는 유언 | 1 | intro.gd | 동기 | |
| INTRO.SHOT4 | 수면 위로, 내레이션 | 1 | intro.gd | 동기 | |
| INTRO.LOGO | 샷 5·6: 백사장에서 로고와 "노래가 완성되면 —" | 1 | story.gd | 동기 | |
| INTRO.SKIP | 인트로 건너뛰기 | 1 | intro.gd | 동기 | |
| INTRO.REPLAY_INGAME | 게임 중 '회상' 메뉴에서 인트로 다시 보기 | 1 | hud.gd, intro.gd | 동기 | 행낭 → 회상: 레벨을 멈춘 채 위에 덮어 재생, 끝나면 그 자리로 |
| BEACH.SC1_01 | 모래 위에서 깨어남 (무음) | 2 | story.gd | 동기 | |
| BEACH.SC1_02 | 다가가면 도망가는 게 | 2 | crab.gd | 동기 | |
| BEACH.SC1_03 | 대나무 피리 획득 | 2 | story.gd | 동기 | |
| BEACH.SC1_04 | 비명과 카메라 팬 | 2 | story.gd | 동기 | |
| BEACH.SC1_05 | 갯귀 튜토리얼 전투 (베기→구르기→정화, 빛나는 버튼 하나) | 2 | story.gd | 동기 | |
| BEACH.SC1_06 | 수령 한기의 천거 | 2 | story.gd | 동기 | |
| BEACH.SC1_07 | 고개 끄덕임 → '서라벌' | 2 | story.gd | 동기 | |
| BEACH.WET_FEET | 물가에서 발이 젖는 물보라 | 2 | level.gd | 동기 | |
| TOWN.SC1_08 | 약방 앞, 난영 첫 만남 | 3 | story.gd | 동기 | |
| TOWN.SC1_09 | 아픈 아이 정화, 난영이 목격 | 3 | story.gd | 동기 | |
| TOWN.SC1_10 | 상점(엽전)·행낭·휴식·저장 | 3 | story.gd · hud.gd | 동기 | |
| TOWN.MONTAGE | 혼례 몽타주 (봄·여름·가을) | 3 | story.gd | 동기 | |
| TOWN.SC1_11 | 그날 밤, 관아의 호출 | 3 | story.gd | 동기 | |
| TOWN.GUIDE | 용패 길잡이 (목표 쪽으로 흐르는 빛) | 3 | level.gd | 동기 | |
| PYEGA.SC1_12 | 형방 박문의 의뢰, 난영이 쓰러졌다는 소식 | 4 | story.gd | 동기 | |
| PYEGA.SC1_13 | 폐가 마당: 들개·역귀·물귀신·처녀귀신 | 4 | levels.gd | 동기 | |
| PYEGA.SC1_14 | 다락: 독기 함정, 달걀귀신·처녀귀신, "…가깝다." | 4 | levels.gd · vent.gd | 동기 | |
| PYEGA.ELITE | 최심부 문 앞 정예 마마귀신 | 4 | levels.gd | 동기 | |
| PYEGA.SC1_15 | 최심부: 사람 모습의 역신, 난영의 넋 | 4 | story.gd | 동기 | |
| BOSS.SC1_16 | 역신의 도발 | 5 | story.gd | 동기 | |
| BOSS.SC1_17 | 대답 없이 처용가 → 보스전 시작 | 5 | story.gd | 동기 | |
| BOSS.SC1_18 | 3패턴 + 2페이즈, 2페이즈 대사 | 5 | boss.gd | 동기 | |
| BOSS.SC1_19 | 무릎 꿇음, "왕이… 오신다" | 5 | boss.gd · story.gd | 동기 | |
| BOSS.SC1_20 | 넋이 돌아감, "…노래가 들렸소." | 5 | story.gd | 동기 | |
| BOSS.ROOM_SEAL | 보스방 결계 | 5 | story.gd, level.gd | 동기 | 결계가 닫힐 때 안에 들어온 요괴는 문 밖으로 밀려난다 |
| BOSS.RETRY | 보스방에서 쓰러지면 다락부터 재도전 | 5 | story.gd | 동기 | |
| END.SC1_21 | 며칠 뒤, 대문마다 처용탈 | 6 | levels.gd · story.gd | 동기 | |
| END.SC1_22 | 내관의 부름, 월성 편전 | 6 | story.gd | 동기 | |
| END.SC1_23 | 퇴마어사 임명 | 6 | story.gd | 동기 | |
| END.SC1_24 | 난영과 작별 | 6 | story.gd | 동기 | |
| END.SC1_25 | 1절 가사 자막 → 1장 끝 → 타이틀 | 6 | story.gd | 동기 | |
| COMBAT.COMBO | 대금 3타 콤보, 자동 조준 | 7 | player.gd | 동기 | |
| COMBAT.ROLL | 구르기 (무적, 끌림 해제) | 7 | player.gd | 동기 | |
| COMBAT.TALISMAN | 부적(정화부 파동) | 7 | player.gd | 동기 | |
| COMBAT.SONG | 처용가: 쓰러진 요괴 정화 | 7 | player.gd | 동기 | |
| COMBAT.DOWNED | 쓰러진 요괴는 탁기에 덮여 기다리다 다시 일어남 | 7 | enemy.gd | 동기 | |
| COMBAT.GUIDE | 해야 할 버튼 하나만 빛남 | 7 | hud.gd | 동기 | |
| COMBAT.STATUS | 처용 기절·둔화·끌림 | 7 | player.gd | 동기 | |
| COMBAT.GIMMICKS | 요괴 17종 개별 기믹 | 7 | enemy.gd | 동기 | |
| COMBAT.ELITE | 장마다 정예 1체 (이름표·게이지) | 7 | enemy.gd | 동기 | |
| COMBAT.DIALOG_FREEZE | 대사 중 요괴 정지 | 7 | level.gd | 동기 | |
| GROW.REWARD | 정화 보상: 정기·덕망·엽전 소량·계열 재료 | 8 | game.gd · bestiary.gd | 동기 | |
| GROW.LEVEL | 덕망 레벨업, 위쳐식 자동 성장 | 8 | game.gd | 동기 | |
| GROW.HANPURI | 한풀이 (구역 정화율 100% → 1.5배) | 8 | level.gd | 동기 | |
| GROW.DOGAM | 요괴 도감 21종 + 보상 | 8 | hud.gd · bestiary.gd | 동기 | |
| GROW.TAL_CHEOYONG | 처용탈 (받는 피해 -10%) | 8 | story.gd · game.gd | 동기 | |
| GROW.TAL_REST | 오방탈·여우탈·용탈·신선탈 | 8 | — | 미구현 | 2~5장 |
| GROW.ACCESSORY | 장신구 효과 (역신의 눈물 등) | 8 | — | 미구현 | 획득만 됨 |
| GROW.SKILLTREE | 스킬 트리 (소리·춤·가호) | 8 | — | 미구현 | 포인트만 적립 |
| GROW.MASTERY | 마스터리 (피리·부적·춤·노래) | 8 | — | 미구현 | |
| GROW.PIRI | 피리 5단계·강화 (정기) | 8 | — | 미구현 | |
| GROW.TALISMAN_CRAFT | 부적 제작 (화염·결박·수호) | 8 | — | 미구현 | |
| GROW.INCENSE | 퇴치향 (계열 특효 30타) | 8 | — | 미구현 | |
| GROW.SET | 장비 세트 효과 | 8 | — | 미구현 | |
| SOUND.MUSIC | 음악 5곡 (타이틀·밤·폐가·전투·보스) | 9 | sound.py · audio.gd | 동기 | 실제 청취 미확인 |
| SOUND.SFX | 효과음 19종 | 9 | sound.py · audio.gd | 동기 | |
| SOUND.AMB | 환경음 (파도·바람) | 9 | audio.gd | 동기 | |
| SOUND.COMBAT_SWITCH | 요괴가 쫓아오면 전투곡, 보스·엔딩 override | 9 | audio.gd · level.gd | 동기 | |
| PLATFORM.TOUCH | 플로팅 조이스틱·터치 버튼 | 10 | hud.gd | 동기 | 캡처로만 확인 |
| PLATFORM.DEVICE | 실기기(폰) 테스트 | 10 | — | 미구현 | |
| PLATFORM.EXPORT | 웹/안드로이드 빌드 | 10 | — | 미구현 | |
| NEXT.CH2_LEVELS | 2장 「도깨비골」 지도·장면 | 11 | — | 미구현 | |
| NEXT.CH3_LEVELS | 3장 「경주 귀족가」 | 11 | — | 미구현 | |
| NEXT.CH4_LEVELS | 4장 「동해·용궁」 | 11 | — | 미구현 | |
| NEXT.CH5_LEVELS | 5장 「저승 경계」 | 11 | — | 미구현 | |
| NEXT.MONSTERS | 2~5장 요괴 스프라이트·기믹 | 11 | monsters.py · enemy.gd | 동기 | 배치 전 |
