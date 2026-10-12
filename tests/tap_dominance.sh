#!/usr/bin/env bash
# 지배 전략 회귀: 탭 연타만으로 1장 요괴 7종을 무피해 클리어할 수 없다(평균 피해 > 0). design/balance/run_probe.sh 재사용.
# 사용: tests/tap_dominance.sh   (사전 조건: godot --headless --path src --import)
set -u
HERE="$(cd "$(dirname "$0")/.." && pwd)"
OUT="${OUT:-$(mktemp -d)}"
TIMEOUT="${TIMEOUT:-900}" "$HERE/design/balance/run_probe.sh" tapclear "$OUT/tapclear.txt"
cat "$OUT/tapclear.txt" | grep -E "^RES|^FAIL"
grep -q "^SCN_RESULT tapclear PASS" "$OUT/tapclear.txt" && { echo "PASS tap_dominance"; exit 0; }
echo "FAIL tap_dominance  log: $OUT/tapclear.txt"; exit 1
