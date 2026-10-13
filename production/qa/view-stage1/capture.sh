#!/usr/bin/env bash
# 시점 1단계 12맵 캡처: 아이폰 가로(2556x1179)·갤럭시(2400x1080) 창 크기를 흉내내 맵마다 스폰/좌상단/우하단 구석을 찍는다.
# 사용: production/qa/view-stage1/capture.sh [OUTDIR]   (짧은 단일 캡처라 flock 예외, nice 로 순차 실행)
set -u
GODOT="${GODOT:-$HOME/workspace/tools/godot-4.4.1/Godot_v4.4.1-stable_linux.x86_64}"
HERE="$(cd "$(dirname "$0")/../../.." && pwd)"
OUT="${1:-$HERE/production/qa/view-stage1/raw}"
mkdir -p "$OUT"
cap() {  # name winsize frames args...
  local name="$1" win="$2" frames="$3"; shift 3
  [ -f "$OUT/$name.png" ] && return
  nice -n 10 timeout 200 xvfb-run -a -s "-screen 0 2700x1300x24" "$GODOT" --path "$HERE/src" --rendering-driver opengl3 -- --capture="$OUT/$name.png" --frames="$frames" --winsize="$win" "$@" >"$OUT/$name.log" 2>&1
  echo "$name $(grep -m1 VIEWPORT "$OUT/$name.log" | cut -c1-90)"
}
# 맵 id | 추가 인자 | 가동 범위 W | 아래 끝(size[1]-tier)
MAPS=(
"beach||640|286" "gyeongju|--flags=summoned,briefed,arrived|640|250" "gwana||640|262" "pyega1||640|286" "pyega2||768|262" "palace||512|238"
"hwagae|--flags=ch2_start,raided,ch2_old_man|800|218" "jiri_path|--flags=ch2_start,raided,ch2_old_man|1120|218" "old_village|--flags=ch2_start,village_seen,girl_heard,q_b|800|218"
"den1|--flags=ch2_start,den_sight,den_deep|800|218" "den2|--flags=ch2_start,den2_seen,den2_gate_cleared|640|218" "den3|--flags=ch2_start|640|218"
)
for row in "${MAPS[@]}"; do
  IFS='|' read -r m extra w b <<<"$row"
  ex=(); [ -n "$extra" ] && ex=("$extra")
  for dev in iphone:2556x1179 galaxy:2400x1080; do
    d=${dev%%:*}; win=${dev#*:}
    if [ "$d" = iphone ]; then   # 아이폰: 스폰·좌상단·우하단 구석, 갤럭시: 우하단 구석(가장 넓은 폭 600)
      cap "${m}_${d}_spawn" "$win" 40 --level="$m" "${ex[@]}"
      cap "${m}_${d}_tl" "$win" 40 --level="$m" "${ex[@]}" --at=30,-30
    fi
    cap "${m}_${d}_br" "$win" 40 --level="$m" "${ex[@]}" --at=$((w-30)),$((b-16))
  done
done
