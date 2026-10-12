#!/usr/bin/env bash
# SB-29: 대화 큐 회귀 테스트. 사용: tests/dialog_queue.sh
GODOT="${GODOT:-$HOME/workspace/tools/godot-4.4.1/Godot_v4.4.1-stable_linux.x86_64}"
HERE="$(cd "$(dirname "$0")/.." && pwd)"
out=$(timeout 120 xvfb-run -a "$GODOT" --path "$HERE/src" --rendering-driver opengl3 --script "$HERE/tests/dialog_queue.gd" 2>&1); rc=$?
echo "$out" | grep -E "^(PASS|FAIL)"
if echo "$out" | grep -qE "SCRIPT ERROR|Parse Error"; then echo "FAIL script errors"; echo "$out" | grep -E "SCRIPT ERROR|Parse Error" | head -3; exit 1; fi
exit $rc
