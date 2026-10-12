#!/usr/bin/env bash
# prog/bugfix2 회귀: SB-29 대화 큐, B02 개운포 북쪽 경계, B03 정화 체인 선연결. 사용: tests/regress_bugfix2.sh
HERE="$(cd "$(dirname "$0")/.." && pwd)"
GODOT="${GODOT:-$HOME/workspace/tools/godot-4.4.1/Godot_v4.4.1-stable_linux.x86_64}"
fail=0
"$HERE/tests/dialog_queue.sh" || fail=1
python3 "$HERE/tests/beach_bounds.py" || fail=1
log=$(timeout 120 xvfb-run -a "$GODOT" --path "$HERE/src" --rendering-driver opengl3 -- --level=beach --beach-fight --beach-early-purify --capture=/tmp/b03.png --frames=40 2>&1)
if echo "$log" | grep -q "EARLY_PURIFY_ARMED=1" && ! echo "$log" | grep -qE "SCRIPT ERROR|Parse Error"; then echo "PASS B03 purify chain armed at spawn"; else echo "FAIL B03"; fail=1; fi
exit $fail
