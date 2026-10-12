#!/usr/bin/env bash
# 전투 전략(design/gdd/combat-strategy.md) 시나리오: tests/godot/harness.gd 의 cs_* 시나리오를 실행한다.
# 사용: tests/combat_strategy.sh [시나리오...]   기본: 전부.  GODOT=… OUT=… RENDER=xvfb
# chapter1_playthrough.sh 의 기본 목록과 분리해 두었다(QA 하네스와의 병합 면적 최소화). 규약은 그쪽과 같다:
# SCRIPT ERROR / Parse Error / 시간 초과 / "SCN_RESULT <이름> PASS" 없음 = 실패. 세이브는 임시 XDG_DATA_HOME.
set -u
GODOT="${GODOT:-$HOME/workspace/tools/godot-4.4.1/Godot_v4.4.1-stable_linux.x86_64}"
HERE="$(cd "$(dirname "$0")/.." && pwd)"
OUT="${OUT:-$(mktemp -d)}"
mkdir -p "$OUT"
HARNESS="$HERE/tests/godot/harness.gd"
TIMEOUT="${TIMEOUT:-300}"
fail=0
DEFAULT=(cs_parry)
SCNS=("$@"); [ ${#SCNS[@]} -eq 0 ] && SCNS=("${DEFAULT[@]}")
for name in "${SCNS[@]}"; do
  log="$OUT/$name.log"
  data="$OUT/data-$name"; rm -rf "$data"; mkdir -p "$data"
  cmd=("$GODOT")
  if [ "${RENDER:-headless}" = "xvfb" ]; then cmd=(xvfb-run -a "$GODOT" --rendering-driver opengl3); else cmd+=(--headless); fi
  args=()
  case "$name" in
    cs_boss*) args+=(--level=pyega2) ;;
    *) args+=(--level=pyega1) ;;
  esac
  t0=$SECONDS
  XDG_DATA_HOME="$data" timeout "$TIMEOUT" "${cmd[@]}" --fixed-fps 60 --path "$HERE/src" -s "$HARNESS" -- --scn="$name" "${args[@]}" >"$log" 2>&1
  rc=$?
  bad=0; why=""
  [ $rc -ne 0 ] && { bad=1; why="rc=$rc"; [ $rc -eq 124 ] && why="시간 초과(${TIMEOUT}s)"; }
  grep -qE "SCRIPT ERROR|Parse Error" "$log" && { bad=1; why="$why SCRIPT/Parse ERROR"; }
  grep -q "^SCN_RESULT $name PASS" "$log" || { bad=1; why="$why 결과줄 없음"; }
  if [ $bad -ne 0 ]; then
    echo "FAIL $name ($why, $((SECONDS-t0))s)  log: $log"
    grep -E "SCRIPT ERROR|Parse Error|^FAIL|^  FAIL" "$log" | head -8
    echo "  --- 마지막 STEP:"; grep -E "^STEP" "$log" | tail -2
    fail=1
  else
    echo "PASS $name ($(grep -c '^STEP' "$log") steps, $(grep -c '^  ok' "$log") checks, $((SECONDS-t0))s)"
  fi
done
echo "logs: $OUT"
exit $fail
