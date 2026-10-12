#!/usr/bin/env bash
# 화질 폴백 단위 시나리오: tests/quality_fallback.sh   (GODOT=/path/to/godot)
set -u
GODOT="${GODOT:-$HOME/workspace/tools/godot-4.4.1/Godot_v4.4.1-stable_linux.x86_64}"
HERE="$(cd "$(dirname "$0")/.." && pwd)"
log="$(mktemp)"
timeout 300 "$GODOT" --headless --path "$HERE/src" -s "$HERE/tests/quality_fallback.gd" >"$log" 2>&1
rc=$?
grep -E "^(--|  ok|FAIL|     |QUALITY_RESULT|\[Quality\])" "$log"
if [ $rc -ne 0 ] || grep -qE "SCRIPT ERROR|Parse Error" "$log" || ! grep -q "^QUALITY_RESULT PASS" "$log"; then
  echo "FAIL quality_fallback (rc=$rc) log: $log"; grep -E "SCRIPT ERROR|Parse Error" "$log" | head -5; exit 1
fi
rm -f "$log"; echo "PASS quality_fallback"
