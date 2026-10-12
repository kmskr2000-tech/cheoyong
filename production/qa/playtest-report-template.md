# Playtest Report — 1장 폰 플레이 (템플릿)

> `/playtest-report` 형식(`.claude/skills/playtest-report/SKILL.md` Phase 2A)에 1장 폰 검증 항목을 더한 것. 사용자 체크리스트(`phone-checklist-ch1.md`)를 옮겨 적는다. 저장 위치: `production/qa/playtests/playtest-[date]-[tester].md`

## Session Info
- **Date**: [Date]
- **Build**: [gh-pages 버전 폴더명(주소의 숫자) / 커밋]
- **Duration**: [Time played]
- **Tester**: [Name/ID]
- **Platform**: Mobile — [기기명 / OS / 브라우저]
- **Input Method**: Touch
- **Session Type**: [First time / Returning / Targeted test]
- **Launch Mode**: [Safari 탭 / 홈 화면 추가 앱]

## Test Focus
1장 「처용가」 완주(SC1-01~25), 보스 역신(HP 480), 터치 HUD, 오디오, 성능, 세이브·이어하기, 홈 화면 업데이트.

## First Impressions (First 5 minutes)
- **Understood the goal?** [Yes/No/Partially]
- **Understood the controls?** [Yes/No/Partially]
- **Emotional response**: [Engaged/Confused/Bored/Frustrated/Excited]
- **Notes**: [Observations]

## Gameplay Flow
### What worked well
- [Observation 1]

### Pain points
- [Issue 1 -- Severity: High/Medium/Low]

### Confusion points
- [Where the player was confused and why]

### Moments of delight
- [What surprised or pleased the player]

## Bugs Encountered
(크래시·소프트락·프레임 급락·화면 깨짐은 Pain points가 아니라 여기에 적는다.)

| # | Description | Severity | Reproducible |
|---|-------------|----------|-------------|

## Feature-Specific Feedback
### 완주 / 진행
- **완주 여부**: [완주 / 중단(장면 ID: SC1-__) / 불가]
- **총 시간**: [분]
### 보스 역신 (HP 480)
- **사망 횟수**: [__회]  (시도별: 위치/패턴/남은 체력 막대)
- **Understood purpose?** [Yes/No]   **무릎 꿇음→노래 정화 이해**: [Yes/No]
- **Suggestions**: 
### 터치 HUD
- **조이스틱 반응**: [좋음/보통/나쁨]   **장면 전환 후 혼자 걷는 현상**: [없음/있음]
- **버튼 겹침·오입력** (공격/구르기/부적/노래/메뉴): [없음/있음 — 어느 버튼]
- **모서리·노치 가림**: [없음/있음]
- **선택지(상점·휴식) 오탭/중복 선택**: [없음/있음]
### 오디오 (iOS 소리 켜기)
- **첫 터치 전 소리**: [없음/있음]   **첫 터치 후 음악**: [나옴/안 나옴]
- **효과음**: [나옴/안 나옴]   **백그라운드 복귀 후**: [유지/끊김]
### 신라 복식 (필러 4)
- **위화감**: [없음/있음 — 대상: 수령/형방·포졸/왕/역신 변장/난영/기타]
### 세이브·이어하기
- **이어하기 표시**: [Y/N]   **복원 상태 정확**: [Y/N]   **1장 종료 후 이어하기 동작**: [서술]
### 홈 화면 추가·업데이트
- **전체 화면 실행**: [Y/N]   **홈 화면판 이어하기(저장 분리)**: [서술]
- **새 버전 반영**: [재실행만으로 반영 / 사파리로 열어야 반영 / 반영 안 됨]

## Quantitative Data (if available)
- **Deaths**: [구간별: 백사장 __ / 폐가 마당 __ / 다락 __ / 보스 __]
- **Time per area**: [개운포 __분 / 경주 __분 / 관아·폐가 __분 / 보스 __분 / 편전·작별 __분]
- **체감 프레임**: [매끄러움 / 싸울 때만 끊김 / 자주 끊김] — 가장 끊긴 곳: 
- **Items used**: [인삼정기탕 __ / 구기자환 __ / 정화부 __]
- **Features discovered vs missed**: [구르기, 부적 교체, 춤, 행낭, 도감, 수련]

## Overall Assessment
- **Would play again?** [Yes/No/Maybe]
- **Difficulty**: [Too Easy / Just Right / Too Hard]
- **Pacing**: [Too Slow / Good / Too Fast]
- **Session length preference**: [Shorter / Good / Longer]

## Top 3 Priorities from this session
1. [Most important finding]
2. [Second priority]
3. [Third priority]

## Action Routing (Phase 3)
- Design changes: 
- Balance adjustments: 
- Bug reports (`/bug-report`): 
- Polish items: 

## Creative Director Assessment
(review_mode가 full일 때만 CD-PLAYTEST 결과 기록. lean/solo는 "skipped" 명시.)
