#!/usr/bin/env bash
# Godot 스모크: 6장면을 --capture로 실행해 종료 코드·SCRIPT ERROR·Parse Error·결과 줄을 검사한다.
# 사용: GODOT=/path/to/godot tests/smoke_godot.sh   (기본: ~/workspace/tools/godot-4.4.1/...)
set -u
GODOT="${GODOT:-$HOME/workspace/tools/godot-4.4.1/Godot_v4.4.1-stable_linux.x86_64}"
HERE="$(cd "$(dirname "$0")/.." && pwd)"
OUT="${OUT:-$(mktemp -d)}"
fail=0
run() { # name frames args...
  local name=$1 frames=$2; shift 2
  local log="$OUT/$name.log"
  timeout 180 xvfb-run -a "$GODOT" --path "$HERE/src" --rendering-driver opengl3 -- "$@" --capture="$OUT/$name.png" --frames="$frames" >"$log" 2>&1
  local rc=$?
  if [ $rc -ne 0 ] || grep -qE "SCRIPT ERROR|Parse Error" "$log" || [ ! -s "$OUT/$name.png" ] || ! grep -q "captured" "$log"; then
    echo "FAIL $name (rc=$rc)"; grep -E "SCRIPT ERROR|Parse Error" "$log" | head -3; fail=1
  else
    echo "PASS $name :: $(grep -m1 'captured' "$log" | sed 's/.*captured [^ ]* *//')"
  fi
}
run title 30 --title
run intro 60 --intro
run beach 60 --level=beach
run pyega 300 --level=pyega1 --test-enemies
run boss 400 --boss
run kneel 300 --boss-kneel
run endcont 200 --level=gyeongju --flags=arrived,met_nanyeong,sang_child,briefed,summoned,rescued,rumor,king_call,appointed,chapter1_done
echo "ERR_CANT_OPEN lines: $(cat "$OUT"/*.log | grep -c ERR_CANT_OPEN)  (out: $OUT)"
exit $fail
