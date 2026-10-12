#!/usr/bin/env bash
# 전투 신호 이펙트 캡처 (아트팀): tests/fx_shots.sh <src 경로> <태그 before|after> <출력 디렉터리> [장면...]
# 장면마다 새 프로세스(pyega1)로 돌려 레벨 재로딩 잡음을 피한다. 게임 코드는 건드리지 않는다.
SRC="$1"; TAG="$2"; OUT="$3"; shift 3
GODOT="${GODOT:-$HOME/workspace/tools/godot-4.4.1/Godot_v4.4.1-stable_linux.x86_64}"
HERE="$(cd "$(dirname "$0")" && pwd)"
SCNS=("$@"); [ ${#SCNS[@]} -eq 0 ] && SCNS=(parry charge guard open boss_open bindfire purify tell)
mkdir -p "$OUT"
for s in "${SCNS[@]}"; do
  timeout 900 xvfb-run -a "$GODOT" --rendering-driver opengl3 --fixed-fps 60 --path "$SRC" -s "$HERE/godot/fx_shots.gd" -- --level=pyega1 --out="$OUT" --tag="$TAG" --only="$s" >"$OUT/$TAG-$s.log" 2>&1
  echo "$s rc=$? $(grep -c 'SCRIPT ERROR' "$OUT/$TAG-$s.log") script-errors"
done
