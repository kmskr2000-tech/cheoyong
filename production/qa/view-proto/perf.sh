#!/usr/bin/env bash
# 시점 안별 상대 비용(드로우콜·라이트·캔버스 아이템): capture.gd --perf. xvfb 소프트웨어 렌더라 wall ms 는 참고용(전후 비교만).
set -u
GODOT="${GODOT:-$HOME/workspace/tools/godot-4.4.1/Godot_v4.4.1-stable_linux.x86_64}"
HERE="$(cd "$(dirname "$0")/../../.." && pwd)"
LOCK="$HOME/workspace/goals/rpg/hidden_files/godot.lock"
OUT="$HERE/production/qa/view-proto/perf"; mkdir -p "$OUT"
for v in a bkh b640 c75; do
  x=(); [ "$v" = bkh ] && x=(--winsize=2556x1179)
  flock "$LOCK" timeout 280 xvfb-run -a -s "-screen 0 2600x1300x24" "$GODOT" --path "$HERE/src" --rendering-driver opengl3 -- --perf --capture="$OUT/gyeongju_$v.png" --frames=260 --view=$v --level=gyeongju --spawn=start --flags=summoned,briefed,arrived "${x[@]}" 2>&1 | grep -E "^(VIEW|PERF|  )" > "$OUT/gyeongju_$v.txt"
  echo "$v done"
done
