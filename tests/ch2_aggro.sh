#!/usr/bin/env bash
# 2장 연출 전 전투 확정 방지 검증: 요괴를 살린 채(어그로 130, lift 좌표) 스폰·연출 지점·상호작용 지점까지 '실제 보행 경로'로 걸어가
# 요괴가 한 번도 idle 을 벗어나지 않는지 본다 (tests/godot/walkability.gd --live, LIVE 표). god/tp 를 쓰지 않는다.
# 사용: tests/ch2_aggro.sh [맵:스폰 ...]   GODOT=/path/to/godot OUT=/path/to/logdir
set -u
GODOT="${GODOT:-$HOME/workspace/tools/godot-4.4.1/Godot_v4.4.1-stable_linux.x86_64}"
HERE="$(cd "$(dirname "$0")/.." && pwd)"
OUT="${OUT:-$(mktemp -d)}"
KEYS=("$@"); [ ${#KEYS[@]} -eq 0 ] && KEYS=(jiri_path:fromHwagae jiri_path:fromVillage jiri_path:fromDen old_village:start den1:start den1:fromDen2 den2:start den2:fromDen3 den3:start)
fail=0
for k in "${KEYS[@]}"; do
  m="${k%%:*}"; sp="${k##*:}"
  flags=ch2_start,raided,ch2_old_man,village_seen,girl_heard,q_b,den_sight,den_deep,den2_seen,den2_gate_cleared,boss2_intro_seen,shrine_seen,jangseung_seen
  log="$OUT/aggro_${m}_${sp}.log"
  timeout 300 "$GODOT" --headless --fixed-fps 60 --path "$HERE/src" -s "$HERE/tests/godot/walkability.gd" -- --map="$m" --spawn="$sp" --flags="$flags" --live >"$log" 2>&1
  rc=$?
  if [ $rc -ne 0 ] || grep -qE "SCRIPT ERROR|Parse Error" "$log" || ! grep -q "^LIVE_RESULT $k PASS" "$log"; then
    echo "FAIL $k (rc=$rc)  log: $log"; grep -E "SCRIPT ERROR|Parse Error|^FAIL" "$log" | head -6; fail=1
  else
    echo "PASS $k  ($(grep -E '^INFO live .* 최소' "$log" | sed 's/.*최소/최소/'))"
  fi
done
exit $fail
