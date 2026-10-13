#!/usr/bin/env bash
# 시점 프로토타입 캡처: 같은 장면을 안(view)별로 찍는다. 사용: production/qa/view-proto/capture.sh [OUTDIR]
# 기본(--view 없음)은 현행 480x270. 캡처는 한 번에 하나씩 순차·nice(짧은 단일 캡처, 규칙 9 예외). 장시간 배치(perf.sh)는 flock.
set -u
GODOT="${GODOT:-$HOME/workspace/tools/godot-4.4.1/Godot_v4.4.1-stable_linux.x86_64}"
HERE="$(cd "$(dirname "$0")/../../.." && pwd)"
OUT="${1:-$HERE/production/qa/view-proto/raw}"
LOCK="$HOME/workspace/goals/rpg/hidden_files/godot.lock"
mkdir -p "$OUT"
cap() {  # name view frames args...
  local name="$1" view="$2" frames="$3"; shift 3
  [ -f "$OUT/$name.png" ] && return
  nice -n 10 timeout 200 xvfb-run -a -s "-screen 0 2600x1300x24" "$GODOT" --path "$HERE/src" --rendering-driver opengl3 -- --capture="$OUT/$name.png" --frames="$frames" --view="$view" "$@" >"$OUT/$name.log" 2>&1
  echo "$name $(file -b "$OUT/$name.png" 2>/dev/null | cut -c1-40)"
}
G1=(--level=gyeongju --spawn=start --flags=summoned,briefed,arrived)
HW=(--level=hwagae --flags=ch2_start,raided,ch2_old_man)
PA=(--level=palace)
PH=(--winsize=2556x1179)   # bkh 전용: 아이폰 가로(393x852pt @3x) 창 크기 흉내
# 우선순위 순: 마을(기준 장면) → 협소 맵(palace) → 전투 → 터치 HUD → 장터 → 이동(룩어헤드)
V=(a bkh b640 b576 c75)
run() {  # scene-name frames extra-args...
  local n="$1" f="$2"; shift 2
  for v in "${V[@]}"; do
    x=(); [ "$v" = bkh ] && x=("${PH[@]}")
    [ "$v" = b576 ] && [ "$n" = s5_touch ] && continue
    case "$n" in
      s1_village) cap ${n}_$v $v $f "${G1[@]}" "${x[@]}" ;;
      s2_hwagae) cap ${n}_$v $v $f "${HW[@]}" "${x[@]}" ;;
      s3_palace) cap ${n}_$v $v $f "${PA[@]}" "${x[@]}" ;;
      s4_combat) cap ${n}_$v $v $f "${G1[@]}" --test-enemies "${x[@]}" ;;
      s5_touch) cap ${n}_$v $v $f "${G1[@]}" --touch "${x[@]}" ;;
    esac
  done
}
run s1_village 100; run s3_palace 100; run s4_combat 40; run s5_touch 100; run s2_hwagae 100
cap s6_walk_a2 a2 150 "${G1[@]}" --hold=move_right
cap s6_walk_a a 150 "${G1[@]}" --hold=move_right
cap s6_walk_bkh bkh 150 "${G1[@]}" --hold=move_right "${PH[@]}"
