# 1장 자동 회귀 커버리지 (tests/chapter1_playthrough.sh)

실행: `tests/chapter1_playthrough.sh [chain|save_mid|continue_mid|corrupt_save|death|boss_retry]` (헤드리스 Godot 4.4.1, 전체 약 40~60초).
실패 기준: 종료 코드 비-0, `SCRIPT ERROR`/`Parse Error`, 시간 초과, 결과 줄(`SCN_RESULT ... PASS`) 없음.
세이브는 `XDG_DATA_HOME` 임시 디렉터리로 격리(실제 save.json 불변). 하네스: `tests/godot/harness.gd`.

## 하네스가 대신하는 입력 (= 자동 증명의 한계)
대사 넘김(confirm 연타) · 순간이동(트리거/출구/NPC 앞) · 전투(`take_hit` 직접 호출) · 노래(`Player.sing()`) · 플레이어 체력 고정(chain/boss_retry).
따라서 **실제 조작감·터치·전투 난이도·보스 패턴 회피는 증명하지 않는다.**

## 표
| 구간 | 자동 증명 | 사람(폰) 확인 필요 |
|---|---|---|
| 타이틀 → 처음부터 → 인트로 완주 → 개운포 | 장면 체인, 오류 없음, 세이브 없을 때 메뉴 | 인트로 연출·자막 타이밍·건너뛰기 터치 |
| SC1-01~04 기상·피리·요괴 출현 | 플래그(logo_shown, flute), 갯귀 출현 | 3초 무음·카드 연출 |
| SC1-05~07 첫 전투·정화·수령·경주 이동 | 튜토리얼 안내 전환(attack→song), 정화, beach_done/arrived, 체크포인트 | 베기/구르기 학습 체감, 빛나는 버튼 |
| SC1-08~10 난영·아이 치유·휴식·혼례 | 플래그 체인, 세이브 기록(married) | 대사 톤, 컷 연출 |
| SC1-11~12 밤 호출·관아 의뢰 | summoned/briefed/nanyeong_fallen, 지급 아이템, 출구 이동 | NPC 보행 연출 |
| SC1-13~14 폐가 마당·다락 | 레벨 전환, 방 소탕(정화 경로), 트리거 | 적 AI·난이도·미아즈마 체감 |
| SC1-15~20 역신전 | 각성, 2페이즈, 무릎, 정화, boss_done, 장신구, 도감, 봉쇄벽, rescued 세이브 | 패턴 회피, 480HP 소요시간, 타격감 |
| SC1-20~21 새벽·소문·처용탈 | nanyeong_woke, rumor, 탈 획득 | 연출 |
| SC1-22~23 왕의 부름·임명 | king_call, palace 도착, appointed | 대사·카메라 |
| SC1-24~25 작별·1절·타이틀 | chapter1_done, 세이브, 타이틀 복귀+이어하기 노출 | 카드/음악 연출 |
| 세이브/이어하기 | 프로세스 재시작 후 복원(플래그·재화·스킬·탈), 낮/밤 스폰, 망가진 세이브에서 크래시 없음 | 실기기 저장소(웹 IndexedDB) |
| 사망·리스폰 | died 시그널, 스폰 복귀, 체력 회복, 진행도 보존, 연속 사망 | 연출·체감 |
| 보스 재도전 | 사망→계단 재시작, 역신 만피·변장 재배치, 재각성, 이후 격파 가능 | 재도전 템포 |
| 렌더링/셰이더/오디오/터치 UI | 불가(헤드리스: 렌더·사운드 없음) — 기존 `smoke_godot.sh` 캡처가 일부 대체 | 전부 |

## 발견된 결함 (src 수정 금지 구역 — 프로그래밍팀 전달)
1. `src/scripts/player.gd:441-444` `_die()`가 `state="dead"` 후 `_end_attack()`이 `state="move"`로 되돌림 → 죽는 연출(약 2.3초) 동안 조작 가능, 사망 중 추가 피격 시 `died` 중복 발생. 하네스에 `KNOWN-BUG`로 표시(고쳐지면 `FIXED?` 출력).
2. 보스방 입구 트리거(`inner`)의 `add_barrier`가 물리 콜백 안에서 실행되어 엔진 ERROR "Can't change this state while flushing queries"가 매번 발생(SCRIPT ERROR 아님, 봉쇄벽은 실제로 막음 — 검증됨). `call_deferred` 권장.
3. `_boss_phase_two`가 끝에 무조건 `boss._begin("idle")` → 한 번의 타격이 2페이즈와 무릎을 동시에 넘기면(`--boss-kneel` 훅 등) 무릎 꿇은 보스가 idle로 되돌아감. 정상 플레이에선 어려운 조건.
4. `appointed` 플래그가 남아 있어 1장 완료 후 '이어하기'를 하면 작별 장면이 다시 재생될 수 있음(2장 미구현이라 의도 여부 확인 필요 — 자동화는 하지 않음).
