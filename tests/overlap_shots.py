#!/usr/bin/env python3
"""겹침 지점 4배 확대 캡처. 사용: tests/overlap_shots.py <출력폴더> <접두어> <맵>:<footprint x>:<footprint y>[:<flags>] ...
footprint 좌표를 level.lift 규칙으로 화면 좌표로 바꾸고, 처용을 대상에서 떨어진 곳에 세워(대상이 가려지지 않게) 한 장 찍은 뒤
대상 주변 160x90 을 4배(640x360)로 잘라 저장한다. 전후 비교용이므로 같은 좌표로 같은 장면을 찍는다."""
import json, os, subprocess, sys
from PIL import Image

HERE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
GODOT = os.environ.get("GODOT", os.path.expanduser("~/workspace/tools/godot-4.4.1/Godot_v4.4.1-stable_linux.x86_64"))
LOCK = os.path.expanduser("~/workspace/goals/rpg/hidden_files/godot.lock")
GROUND = {"gyeongju": "village"}
FLAGS = {"gyeongju": "summoned,briefed,arrived"}


def lift(meta, x, y):
    ts = meta["ts"]
    rows = meta["heights"]
    cy = min(max(int(y / ts), 0), len(rows) - 1)
    cx = min(max(int(x / ts), 0), len(rows[0]) - 1)
    c = rows[cy][cx]
    t = float(c) if c.isdigit() else 1.0
    return x, y * meta.get("k", 1.0) - t * meta["tier"]


def main():
    out, prefix = sys.argv[1], sys.argv[2]
    os.makedirs(out, exist_ok=True)
    for spec in sys.argv[3:]:
        parts = spec.split(":")
        m, fx, fy = parts[0], float(parts[1]), float(parts[2])
        flags = parts[3] if len(parts) > 3 else FLAGS.get(m, "")
        meta = json.load(open(f"{HERE}/src/assets/levels/{GROUND.get(m, m)}.json"))
        tx, ty = lift(meta, fx, fy)
        W = meta["size"][0]
        top = -meta["tier"] * 2
        bot = meta["size"][1] - meta["tier"]
        px = tx + 120 if tx < W / 2 else tx - 120   # 처용은 대상 옆에 세운다
        py = ty
        cx = min(max(px, 240), W - 240)
        cy = min(max(py, top + 135), bot - 135)
        sx, sy = tx - (cx - 240), ty - (cy - 135)
        raw = f"{out}/_raw_{m}_{int(fx)}_{int(fy)}.png"
        cmd = ([] if os.environ.get("NOLOCK") else ["flock", LOCK]) + ["xvfb-run", "-a", GODOT, "--path", f"{HERE}/src", "--", f"--capture={raw}", "--frames=45",
               f"--level={m}", f"--at={px},{py}"] + ([f"--flags={flags}"] if flags else [])
        subprocess.run(cmd, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, timeout=1500)
        im = Image.open(raw).convert("RGB")
        cw, ch = (int(v) for v in os.environ.get("CROP", "160,90").split(","))   # 기본 160x90 → 4배 640x360
        box = (int(sx - cw / 2), int(sy - ch * 0.69), int(sx + cw / 2), int(sy + ch * 0.31))
        crop = Image.new("RGB", (cw, ch), (0, 0, 0))
        crop.paste(im.crop(box), (0, 0))
        dst = f"{out}/{prefix}_{m}_{int(fx)}_{int(fy)}.png"
        crop.resize((cw * 4, ch * 4), Image.NEAREST).save(dst)
        os.remove(raw)
        print(dst, "target_screen", (round(sx), round(sy)), "box", box)


main()
