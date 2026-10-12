#!/usr/bin/env bash
# HUD/터치/타이틀 고지 문구 배치 검사 (헤드리스). 사용: GODOT=/path/to/godot tests/hud_layout.sh
set -u
GODOT="${GODOT:-$HOME/workspace/tools/godot-4.4.1/Godot_v4.4.1-stable_linux.x86_64}"
HERE="$(cd "$(dirname "$0")/.." && pwd)"
TMP="$(mktemp -d)"
XDG_DATA_HOME="$TMP/data" timeout 120 "$GODOT" --headless --path "$HERE/src" --script "$HERE/tests/hud_layout.gd" -- --touch >"$TMP/out.log" 2>&1
rc=$?
grep -E "^(PASS|FAIL|HUD_LAYOUT)" "$TMP/out.log"
if grep -qE "SCRIPT ERROR|Parse Error" "$TMP/out.log"; then echo "FAIL script errors:"; grep -E "SCRIPT ERROR|Parse Error" "$TMP/out.log" | head -5; rc=1; fi
[ $rc -ne 0 ] && echo "log: $TMP/out.log"
exit $rc
