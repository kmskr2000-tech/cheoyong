#!/usr/bin/env bash
# 적용 후 캡처 (prog/ch2-m2-assets). 사용: production/qa/asset-import/ch2-m2/applied/capture.sh  (flock 으로 감싸 실행)
HERE="$(cd "$(dirname "$0")/../../../../.." && pwd)"; OUT="$HERE/production/qa/asset-import/ch2-m2/applied"
GODOT="${GODOT:-$HOME/workspace/tools/godot-4.4.1/Godot_v4.4.1-stable_linux.x86_64}"
FL=ch2_start,raided,ch2_old_man,village_seen,girl_heard,q_b,den_sight,den_deep,den2_seen,den2_gate_cleared,boss2_intro_seen,shrine_seen,jangseung_seen
cap() { # name level spawn x,y
  xvfb-run -a "$GODOT" --path "$HERE/src" --rendering-driver opengl3 -- --level=$2 --spawn=$3 --at=$4 --flags=$FL --capture="$OUT/$1.png" --frames=120 >"$OUT/$1.log" 2>&1; grep -c captured "$OUT/$1.log" | sed "s/^/$1 captured=/"; }
cap old_village_spawn old_village start 650,345
cap old_village_plaza old_village start 560,215
cap old_village_trail old_village start 735,150
cap den1_start den1 start 30,181
cap den1_north den1 start 400,60
cap den1_east den1 start 690,190
cap den2_start den2 start 24,200
cap den2_plaza den2 start 320,200
cap den3_start den3 start 40,200
cap den3_arena den3 start 320,200
