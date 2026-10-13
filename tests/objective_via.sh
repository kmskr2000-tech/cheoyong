#!/usr/bin/env bash
# T2(목표마커): 마커 대상이 스폰에서 실제 충돌 물리로 도달 가능한지, 직선이 막히는 곳은 어디(via 후보)인지. 사용: tests/objective_via.sh
# 출력 OBJ_VIA ... straight_free=False 이면 직선 마커가 벽을 가리킴 → story.gd objective_info 의 via 에 corner_fp 를 넣는다.
set -u
GODOT="${GODOT:-$HOME/workspace/tools/godot-4.4.1/Godot_v4.4.1-stable_linux.x86_64}"
HERE="$(cd "$(dirname "$0")/.." && pwd)"
fail=0
run() { # map spawn flags x,y
  local out
  out=$(XDG_DATA_HOME="$(mktemp -d)" timeout 200 "$GODOT" --headless --fixed-fps 60 --path "$HERE/src" -s "$HERE/tests/godot/walkability.gd" -- --map="$1" --spawn="$2" --flags="$3" --obj="$4" 2>&1 | grep -E "^OBJ_VIA|FAIL" | head -2)
  echo "${out:-FAIL(no output) $1 $2 $4}"
  echo "$out" | grep -qE "UNREACHABLE|FAIL" && fail=1
}
N="met_nanyeong,sang_child,night,summoned"
run beach start "" 205,427
run beach start "flute" 380,405
run gyeongju start "arrived" 220,314
run gyeongju start "arrived,met_nanyeong" 240,376
run gyeongju start "arrived,met_nanyeong,sang_child" 130,237
run gyeongju home "arrived,$N" 562,28
run gyeongju start "arrived,$N,briefed" 4,379
run gyeongju start "arrived,rumor,rescued" 318,213
run gyeongju start "arrived,rumor,rescued" 130,237
run gwana start "" 395,140
run pyega1 start "" 146,197
run pyega2 start "" 600,213
run palace start "" 256,228
[ $fail -ne 0 ] && echo "OBJECTIVE_VIA FAIL" || echo "OBJECTIVE_VIA DONE"
exit $fail
