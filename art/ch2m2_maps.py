"""2장 M2 4맵의 '걷기 마스크'(그림 좌표, png px) — 지형 그림·충돌 json·검증이 전부 이 한 곳에서 나온다.
그림 좌표: x = footprint x, y = 0.75*fy + 30 (flat T=2 구움, art/collision_author 와 같음). 맨 아래 26px 는 레벨 가장자리 벽 밖.
각 맵: size=(w,h) 그림 크기, walk=[폴리곤...](합집합), block=[폴리곤...](walk 안의 막힘), marks=제안 좌표(footprint).
"""
import math


def rect(x0, y0, x1, y1):
    return [(x0, y0), (x1, y0), (x1, y1), (x0, y1)]


def ell(cx, cy, rx, ry, n=48):
    return [(cx + rx * math.cos(2 * math.pi * i / n), cy + ry * math.sin(2 * math.pi * i / n)) for i in range(n)]


def fy2y(fy):
    return 0.75 * fy + 30


MAPS = {}

# ------------------------------------------------------------------ old_village 800x326 (footprint 800x400)
# 소스 village 일러스트(반전)의 길·마당을 따라 걷기 마스크를 그렸다(art/ch2m2_terrain.py 의 ov_base 와 같은 좌표).
MAPS['old_village'] = dict(
    size=(800, 326),
    walk=[
        # 남쪽 길 + 우물 마당(그림의 흙바닥). 대나무 덤불(x440~500,y>245)·등롱 울타리(왼쪽)는 막힘
        [(412, 140), (470, 136), (520, 134), (562, 126), (612, 120), (732, 120), (734, 150), (624, 152), (622, 214), (690, 226), (740, 250),
         (742, 285), (702, 300), (505, 300), (502, 254), (470, 246), (436, 236), (430, 176), (414, 168)],
        # 북서 길(등롱 아래 흙길) — 마당 북서쪽에서 갈라져 올라간다
        [(200, 3), (335, 3), (350, 40), (385, 78), (410, 115), (440, 118), (440, 150), (380, 150), (345, 128), (320, 108), (290, 75),
         (250, 45), (215, 25)],
    ],
    block=[
        [(538, 146), (610, 146), (610, 202), (538, 202)],        # 우물 돌 테두리(윗길은 지붕 밑 통로)
    ],
)
# 길 파내기(그림에 새로 까는 흙길 = 우회로 고리) — 동쪽 담·덤불 사이로 난 샛길
TRAILS = {
    'old_village': [
        [(704, 245), (742, 252), (772, 236), (778, 196), (772, 140), (762, 108), (790, 80), (790, 44), (748, 24), (708, 44), (700, 72),
         (716, 108), (724, 140), (730, 196), (716, 236)],
    ],
}


def is_walk(name, x, y):
    from PIL import Image, ImageDraw
    spec = MAPS[name]
    w, h = spec['size']
    im = Image.new('L', (w, h), 0)
    d = ImageDraw.Draw(im)
    for p in spec['walk'] + TRAILS.get(name, []):
        d.polygon(p, fill=255)
    return im.getpixel((int(min(max(x, 0), w - 1)), int(min(max(y, 0), h - 1)))) > 0
