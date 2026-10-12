#!/usr/bin/env bash
# 사용: design/balance/run_probe.sh <ttk|boss|econ> [출력파일]   (프로젝트 .godot 임포트가 먼저 필요: godot --headless --path src --import)
# /tmp(tmpfs)에 큰 로그를 만들지 않도록 RES 줄만 걸러 저장한다.
set -u
HERE="$(cd "$(dirname "$0")/../.." && pwd)"
G="${GODOT:-$HOME/workspace/tools/godot-4.4.1/Godot_v4.4.1-stable_linux.x86_64}"
DATA="${DATA:-$HOME/balwork/data}"; mkdir -p "$DATA"
OUT="${2:-$HERE/design/balance/raw/$1.txt}"
XDG_DATA_HOME="$DATA" timeout "${TIMEOUT:-3000}" "$G" --headless --fixed-fps 60 --path "$HERE/src" -s ../tests/godot/balance_probe.gd -- --scn="$1" --level=pyega1 2>&1 | grep -E "^(RES|FAIL|SCRIPT ERROR|SCN_RESULT)" > "$OUT"
