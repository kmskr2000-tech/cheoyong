#!/usr/bin/env bash
# T5(숨김 규칙)·T8(설정 유지)·폴백/잠깐 모드 (헤드리스). 사용: GODOT=/path/to/godot tests/objective_hud.sh
set -u
GODOT="${GODOT:-$HOME/workspace/tools/godot-4.4.1/Godot_v4.4.1-stable_linux.x86_64}"
HERE="$(cd "$(dirname "$0")/.." && pwd)"
TMP="$(mktemp -d)"
XDG_DATA_HOME="$TMP/data" timeout 120 "$GODOT" --headless --path "$HERE/src" --script "$HERE/tests/objective_hud.gd" >"$TMP/out.log" 2>&1
rc=$?
grep -E "^(PASS|FAIL|OBJECTIVE_HUD)" "$TMP/out.log"
if grep -qE "SCRIPT ERROR|Parse Error" "$TMP/out.log"; then echo "FAIL script errors:"; grep -E "SCRIPT ERROR|Parse Error" "$TMP/out.log" | head -5; rc=1; fi
[ $rc -ne 0 ] && echo "log: $TMP/out.log"
exit $rc
