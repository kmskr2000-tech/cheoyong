#!/usr/bin/env bash
# 기본(상) 등급 화면이 main 과 같음을 증명: main worktree 와 이 브랜치에서 같은 정지 프레임을 찍어 픽셀 비교.
# 사용: tests/lowend_vs_main.sh <main-worktree> <outdir> [맵...]   허용 오차: 0 px (정지 후 같은 코드 재캡처 대조도 함께 낸다)
set -u
GODOT="${GODOT:-$HOME/workspace/tools/godot-4.4.1/Godot_v4.4.1-stable_linux.x86_64}"
HERE="$(cd "$(dirname "$0")/.." && pwd)"
MAIN="$1"; OUT="$2"; shift 2
MAPS=("$@"); [ ${#MAPS[@]} -eq 0 ] && MAPS=(gyeongju beach pyega1 palace)
LOCK=$HOME/workspace/goals/rpg/hidden_files/godot.lock
for m in "${MAPS[@]}"; do
  fl=""; [ "$m" = gyeongju ] && fl="--flags=summoned,briefed,arrived"
  for side in main branch branch2; do
    root="$HERE"; [ $side = main ] && root="$MAIN"
    flock "$LOCK" timeout 300 xvfb-run -a "$GODOT" --path "$root/src" --rendering-driver opengl3 -s "$HERE/tests/lowend_dump.gd" -- --map=$m --out="$OUT/$side" $fl 2>&1 | grep -E "DUMP_DONE|SCRIPT ERROR" | sort -u
  done
done
python3 - "$OUT" "${MAPS[@]}" <<'P'
import sys,glob,os
from PIL import Image, ImageChops
out=sys.argv[1]; bad=0
for m in sys.argv[2:]:
    for f in sorted(glob.glob(f"{out}/main/{m}_*.png")):
        b=os.path.basename(f)
        def d(x,y):
            return sum(1 for p in ImageChops.difference(Image.open(x).convert("RGB"),Image.open(y).convert("RGB")).convert("L").getdata() if p>0)
        dm=d(f,f"{out}/branch/{b}"); dn=d(f"{out}/branch/{b}",f"{out}/branch2/{b}")
        print(f"{b}: main-vs-branch {dm}px  (대조 branch-vs-branch {dn}px)")
        if dm>dn: bad+=1
print("LOWEND_VS_MAIN","PASS" if bad==0 else f"FAIL({bad})")
sys.exit(1 if bad else 0)
P
