#!/usr/bin/env bash
# 가로 확장·카메라 범위 검사 (헤드리스). 사용: GODOT=/path/to/godot tests/view_range.sh [맵,...]
set -u
GODOT="${GODOT:-$HOME/workspace/tools/godot-4.4.1/Godot_v4.4.1-stable_linux.x86_64}"
HERE="$(cd "$(dirname "$0")/.." && pwd)"
TMP="$(mktemp -d)"
args=(); [ $# -gt 0 ] && args=(--maps="$1")
XDG_DATA_HOME="$TMP/data" timeout 600 "$GODOT" --headless --path "$HERE/src" -s "$HERE/tests/view_range.gd" -- "${args[@]}" >"$TMP/out.log" 2>&1
rc=$?
grep -E "^(FAIL|VIEW_RANGE)" "$TMP/out.log" | head -40
if grep -qE "SCRIPT ERROR|Parse Error" "$TMP/out.log"; then echo "FAIL script errors:"; grep -E "SCRIPT ERROR|Parse Error" "$TMP/out.log" | head -5; rc=1; fi
[ $rc -ne 0 ] && echo "log: $TMP/out.log"
exit $rc
