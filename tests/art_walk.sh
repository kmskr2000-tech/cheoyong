#!/usr/bin/env bash
# 1장 지형 걷기 검증 (아트팀): 맵마다 실제 충돌 물리로 NPC·출구·소품 지점 도달 + 시작→목적지 직접 걷기.
# 사용: tests/art_walk.sh [맵...]   (기본: 6개 전부)   GODOT=/path/to/godot OUT=/path/to/logdir
set -u
GODOT="${GODOT:-$HOME/workspace/tools/godot-4.4.1/Godot_v4.4.1-stable_linux.x86_64}"
HERE="$(cd "$(dirname "$0")/.." && pwd)"
OUT="${OUT:-$(mktemp -d)}"
MAPS=("$@"); [ ${#MAPS[@]} -eq 0 ] && MAPS=(beach gyeongju gwana pyega1 pyega2 palace)
fail=0
for m in "${MAPS[@]}"; do
  extra=()
  case "$m" in
    gyeongju) extra=(--flags=summoned,briefed,arrived) ;;
  esac
  log="$OUT/walk_$m.log"
  timeout 300 "$GODOT" --headless --fixed-fps 60 --path "$HERE/src" -s "$HERE/tests/godot/walkability.gd" -- --map="$m" "${extra[@]}" >"$log" 2>&1
  rc=$?
  if [ $rc -ne 0 ] || grep -qE "SCRIPT ERROR|Parse Error" "$log" || ! grep -q "^WALK_RESULT $m PASS" "$log"; then
    echo "FAIL $m (rc=$rc)  log: $log"; grep -E "SCRIPT ERROR|Parse Error|^FAIL" "$log" | head -8; fail=1
  else
    echo "PASS $m  ($(grep -c '^  ok' "$log") 지점, $(grep -c '^  walk' "$log") 구간 걷기)"
  fi
done
exit $fail
