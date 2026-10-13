#!/usr/bin/env python3
"""처용 주변 밝기 측정 (아트팀). 사용: measure.py <캡처.png> <캡처.log> [--json]
캡처 로그의 `player_screen` (발밑 화면 좌표)에 처용 idle 알파 마스크를 얹어 본체/주변 고리를 나눈다.
 L_frame = 화면 평균 밝기(HUD 제외), L_hero = 처용 본체 평균, L_near = 본체에서 4~16px 고리(외곽빛 영역),
 L_mid = 16~40px 고리, halo = L_near/L_frame, contrast = (L_hero-L_near)/(L_hero+L_near) (마이컬슨).
밝기 = 0.299R+0.587G+0.114B (0~255, 480x270 원본 해상도 캡처 기준)."""
import sys, re, json
import numpy as np
from PIL import Image, ImageFilter
from pathlib import Path

SPRITE = Path(__file__).resolve().parents[4] / "src/assets/sprites/cheoyong.png"


def luma(a):
    return a[..., 0] * 0.299 + a[..., 1] * 0.587 + a[..., 2] * 0.114


def hero_mask(px, py, shape):
    cell = np.array(Image.open(SPRITE).convert("RGBA"))[:, 0:64, 3] > 40   # down_idle 첫 프레임
    m = np.zeros(shape, bool)
    ox, oy = int(px) - 32, int(py) - 58
    for y in range(64):
        for x in range(64):
            if cell[y, x]:
                X, Y = ox + x, oy + y
                if 0 <= X < shape[1] and 0 <= Y < shape[0]:
                    m[Y, X] = True
    return m


def dilate(m, r):
    im = Image.fromarray((m * 255).astype(np.uint8))
    return np.array(im.filter(ImageFilter.MaxFilter(2 * r + 1))) > 0


def measure(png, log):
    t = Path(log).read_text()
    mm = re.search(r"player_screen \(([-\d.]+), ([-\d.]+)\)", t)
    px, py = float(mm.group(1)), float(mm.group(2))
    a = np.array(Image.open(png).convert("RGB")).astype(float)
    L = luma(a)
    hud = np.zeros(L.shape, bool)
    hud[:70, :150] = True
    hud[:, 400:] |= False
    hm = hero_mask(px, py, L.shape) & ~hud
    d4, d16, d40 = dilate(hm, 4), dilate(hm, 16), dilate(hm, 40)
    near = d16 & ~d4 & ~hud
    mid = d40 & ~d16 & ~hud
    frame = ~hud
    r = dict(hero_xy=(px, py), L_frame=L[frame].mean(), L_hero=L[hm].mean() if hm.any() else float("nan"),
             L_near=L[near].mean(), L_mid=L[mid].mean())
    r["halo"] = r["L_near"] / r["L_frame"]
    r["contrast"] = (r["L_hero"] - r["L_near"]) / (r["L_hero"] + r["L_near"] + 1e-9)
    r["dL"] = r["L_hero"] - r["L_near"]
    return r


if __name__ == "__main__":
    r = measure(sys.argv[1], sys.argv[2])
    if "--json" in sys.argv:
        print(json.dumps(r))
    else:
        print("  ".join(f"{k}={v:.3f}" if isinstance(v, float) else f"{k}={v}" for k, v in r.items()))
