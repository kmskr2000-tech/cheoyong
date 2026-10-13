#!/usr/bin/env bash
# 에셋 겹침 전수 검출: 1장 6개 맵 (기본). 0건이면 통과. 사용: tests/overlap_check.sh [맵...]  GODOT=/path OUT=/path/to/logdir
set -u
GODOT="${GODOT:-$HOME/workspace/tools/godot-4.4.1/Godot_v4.4.1-stable_linux.x86_64}"
HERE="$(cd "$(dirname "$0")/.." && pwd)"
OUT="${OUT:-$(mktemp -d)}"
MAPS=("$@"); [ ${#MAPS[@]} -eq 0 ] && MAPS=(beach gyeongju gwana pyega1 pyega2 palace)
fail=0
for m in "${MAPS[@]}"; do
  log="$OUT/overlap_$m.log"
  timeout 120 "$GODOT" --headless --path "$HERE/src" -s "$HERE/tests/godot/overlap_check.gd" -- --map="$m" --md="$OUT/overlap_$m.md" >"$log" 2>&1
  if grep -qE "SCRIPT ERROR|Parse Error" "$log" || ! grep -q "^OVERLAP_RESULT $m " "$log"; then
    echo "ERROR $m  log: $log"; grep -E "SCRIPT ERROR|Parse Error" "$log" | head -5; fail=1; continue
  fi
  n=$(grep "^OVERLAP_RESULT $m " "$log" | awk '{print $3}')
  if [ "$n" -ne 0 ]; then echo "FAIL $m  ${n}건"; grep "^FINDING" "$log"; fail=1; else echo "PASS $m  0건 ($(grep "^OVERLAP_RESULT $m " "$log" | cut -d' ' -f4-))"; fi
done
exit $fail
