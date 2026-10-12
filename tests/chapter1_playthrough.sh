#!/usr/bin/env bash
# 1장(SC1-01~25) 시나리오 회귀: 헤드리스 Godot 로 타이틀→인트로→백사장→경주→관아→폐가→역신전→임명→작별→1절→타이틀까지
# 실제 Story 체인을 끝까지 태우고, 세이브/이어하기·사망 리스폰·보스 재도전을 검증한다. (하네스: tests/godot/harness.gd)
# 사용: tests/chapter1_playthrough.sh [시나리오...]     기본: 전부
#   GODOT=/path/to/godot  OUT=/path/to/logdir  KEEP=1(데이터 디렉터리 보존)  RENDER=xvfb(헤드리스 대신 xvfb+opengl3)
# 종료 코드: 0 = 전부 통과, 비-0 = 실패(SCRIPT ERROR / Parse Error / 시간 초과 / 검증 실패 / 결과 줄 없음 하나라도)
# 세이브 격리: XDG_DATA_HOME 을 임시 디렉터리로 돌려서 실제 user://save.json 을 건드리지 않는다.
set -u
GODOT="${GODOT:-$HOME/workspace/tools/godot-4.4.1/Godot_v4.4.1-stable_linux.x86_64}"
HERE="$(cd "$(dirname "$0")/.." && pwd)"
OUT="${OUT:-$(mktemp -d)}"
mkdir -p "$OUT"
HARNESS="$HERE/tests/godot/harness.gd"
TIMEOUT="${TIMEOUT:-600}"
fail=0

# 같은 데이터 디렉터리를 공유하는 순서(세이브가 프로세스 재시작을 건너 이어진다)
DEFAULT=(chain save_mid continue_mid corrupt_save death boss_retry)
SCNS=("$@"); [ ${#SCNS[@]} -eq 0 ] && SCNS=("${DEFAULT[@]}")

run() { # name datadir
  local name=$1 data=$2 log="$OUT/$1.log"
  local -a cmd=("$GODOT")
  if [ "${RENDER:-headless}" = "xvfb" ]; then
    cmd=(xvfb-run -a "$GODOT" --rendering-driver opengl3)
  else
    cmd+=(--headless)
  fi
  local args=()
  case "$name" in
    death) args+=(--level=pyega1) ;;
    boss_retry) args+=(--level=pyega2) ;;
    ch2_farewell|ch2_continue) args+=(--ch2) ;;   # 2장 진입 스위치 켜짐 (기본 목록 밖: 'tests/chapter1_playthrough.sh ch2_farewell ch2_continue ch2_off_continue')
  esac
  local t0=$SECONDS
  XDG_DATA_HOME="$data" timeout "$TIMEOUT" "${cmd[@]}" --fixed-fps 60 --path "$HERE/src" -s "$HARNESS" -- --scn="$name" "${args[@]}" >"$log" 2>&1
  local rc=$?
  local bad=0 why=""
  [ $rc -ne 0 ] && { bad=1; why="rc=$rc"; [ $rc -eq 124 ] && why="시간 초과(${TIMEOUT}s)"; }
  if grep -qE "SCRIPT ERROR|Parse Error" "$log"; then bad=1; why="$why SCRIPT/Parse ERROR"; fi
  grep -q "^SCN_RESULT $name PASS" "$log" || { bad=1; why="$why 결과줄 없음"; }
  if [ $bad -ne 0 ]; then
    echo "FAIL $name ($why, $((SECONDS-t0))s)  log: $log"
    grep -E "SCRIPT ERROR|Parse Error|^FAIL|^  FAIL" "$log" | head -8
    echo "  --- 마지막 STEP:"; grep -E "^STEP" "$log" | tail -2
    fail=1
  else
    echo "PASS $name ($(grep -c '^STEP' "$log") steps, $(grep -c '^  ok' "$log") checks, $((SECONDS-t0))s)"
  fi
}

# chain → save_mid → continue_mid → corrupt_save 는 한 데이터 디렉터리를 공유(순서 의존). death/boss_retry 는 각자 새 디렉터리.
SHARED="$OUT/data-shared"
for s in "${SCNS[@]}"; do
  case "$s" in
    chain)
      rm -rf "$SHARED"; mkdir -p "$SHARED"; run "$s" "$SHARED" ;;
    save_mid)
      mkdir -p "$SHARED"; rm -f "$SHARED"/godot/app_userdata/*/save.json; run "$s" "$SHARED" ;;
    continue_mid|corrupt_save)
      mkdir -p "$SHARED"; run "$s" "$SHARED" ;;
    *)
      d="$OUT/data-$s"; rm -rf "$d"; mkdir -p "$d"; run "$s" "$d" ;;
  esac
done

# 엔진 ERROR 요약 (사운드카드 없음에서 나오는 ERR_CANT_OPEN·오디오 드라이버 줄은 정상으로 제외)
other=$(cat "$OUT"/*.log 2>/dev/null | grep -E "^(ERROR|WARNING):" | grep -vE "ERR_CANT_OPEN|audio|Audio|ALSA|PulseAudio|driver" | sort | uniq -c | sort -rn | head -5)
[ -n "$other" ] && { echo "참고: 엔진 ERROR/WARNING (실패 기준 아님):"; echo "$other"; }
echo "logs: $OUT"
[ -z "${KEEP:-}" ] || echo "data: $SHARED"
exit $fail
