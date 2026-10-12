"""지형 그림(1장 6개 맵)에 맞춰 충돌(collision)·높이(heights) json 을 다시 만든다.
옛 json 은 절차 생성 지형 기준이라 Drive 일러스트와 어긋났다. 이제 맵마다 '그림 좌표(png 픽셀)'로 적은
걷기 가능 다각형(WALK) 에서 json 을 만든다.  사용: python3 art/collision_author.py [맵...] [--overlay]

좌표계: 레벨 png 는 화면 y = 그림 y - OFFSET(82) 에 놓인다. 게임 footprint 좌표 fy 는 화면 y = 0.75*fy - TIER*T.
모든 맵을 '평탄 tier T=2' 로 굽는다(그림은 한 장짜리 평면 그림이라 높이 단차가 없다)
  => 그림 y = 0.75*fy + 30  /  fy = (그림 y - 30) / 0.75,  그림 x = fx.
충돌은 4px 격자 사각형(그림 바깥·건물·담·나무·물 = 막힘). 플레이어 발판은 10x6.
heights: 걷는 땅 '2', 물 '0'(Level.is_water 와 물보라용).
"""
import json, pathlib, sys
import numpy as np
from PIL import Image, ImageDraw

ROOT = pathlib.Path(__file__).parent.parent
LV = ROOT / 'src/assets/levels'
OUTQA = ROOT / 'production/qa/art-collision'
OFFSET, TIER, K, TS, T = 82, 26, 0.75, 16, 2
CELL = 4
FOOT_W, FOOT_H = 10, 6


def fp(ix, iy):
    """그림 좌표 -> footprint(levels.gd 에 적는 좌표)"""
    return round(ix), round((iy - (OFFSET - TIER * T)) / K)


def img_of(fx, fy):
    return fx, K * fy + OFFSET - TIER * T


# ------------------------------------------------------------------ 맵 정의 (그림 좌표)
# walk: 걷기 가능(합집합) / block: 그 안의 막힘(건물·나무 밑동) / water: 물(heights '0')
MAPS = {}


def mp(name, **kw):
    MAPS[name] = kw


def rect(x0, y0, x1, y1):
    return [(x0, y0), (x1, y0), (x1, y1), (x0, y1)]


mp('beach', ground='beach',
   walk=[
       # A: 백사장(남) + 서쪽 모래띠
       [(122, 366), (535, 366), (520, 360), (480, 350), (440, 340), (400, 330), (350, 326), (300, 324), (250, 316),
        (200, 302), (150, 287), (110, 270), (82, 252), (66, 236), (58, 222), (28, 222), (22, 236), (22, 266),
        (50, 274), (78, 286), (78, 320), (108, 336), (122, 350)],
       # B: 서쪽 북행 통로
       [(28, 222), (58, 222), (58, 176), (100, 166), (106, 158), (106, 143), (28, 143)],
       # C: 해안 띠 + 마을 앞 모래톱
       [(100, 139), (236, 137), (256, 134), (258, 121), (330, 121), (340, 124), (338, 134), (320, 139), (290, 140),
        (264, 146), (240, 155), (200, 155), (150, 156), (104, 160), (100, 150)],
   ],
   sea_min_y=138,
   )


mp('village', ground='village',
   walk=[
       rect(0, 296, 392, 332),                                   # 남쪽 길 + 서쪽 출구길
       rect(100, 205, 392, 296),                                 # 우물 앞 광장
       rect(300, 125, 500, 205),                                 # 북쪽 광장
       [(418, 130), (418, 100), (440, 92), (470, 78), (486, 66), (500, 62), (500, 130)],     # 북동 골목
       [(486, 100), (486, 64), (520, 58), (556, 58), (566, 62), (566, 100)],                 # 관아 문 앞 길
       rect(550, 46, 574, 62),                                   # 관아 문 통로
       rect(100, 196, 150, 224),                                 # 처용의 집 앞
   ],
   block=[
       rect(150, 192, 216, 272),                                 # 우물
       rect(96, 222, 142, 280),                                  # 우물 왼쪽 낮은 담
       [(222, 216), (222, 186), (300, 150), (306, 150), (306, 205), (250, 215)],   # 중앙 돌담
       rect(297, 282, 309, 292), rect(404, 194, 414, 202), rect(414, 114, 422, 122), rect(496, 134, 504, 142),  # 등롱 기둥 밑동
       [(300, 300), (322, 284), (350, 268), (384, 252), (392, 262), (392, 332), (300, 332)],   # 남동 담+울타리
       rect(338, 236, 356, 262), rect(262, 310, 284, 332),       # 풀숲, 야자
       rect(356, 122, 418, 138), rect(472, 140, 500, 172),
       [(365, 224), (395, 203), (430, 168), (442, 170), (470, 184), (536, 184), (545, 205), (566, 205), (566, 332), (365, 332)],  # 큰 기와집
   ])


def raster(poly_lists, size):
    im = Image.new('L', size, 0)
    d = ImageDraw.Draw(im)
    for p in poly_lists:
        d.polygon(p, fill=255)
    return np.asarray(im) > 0


def build(name, overlay=True):
    spec = MAPS[name]
    meta_p = LV / f"{spec['ground']}.json"
    meta = json.load(open(meta_p))
    png = Image.open(LV / f"{spec['ground']}.png").convert('RGB')
    W, H = png.size
    walk = raster(spec['walk'], (W, H))
    if spec.get('block'):
        walk &= ~raster(spec['block'], (W, H))
    # ---- 충돌: 4px 격자에서 걷기 가능이 절반 미만인 칸 = 막힘 -> 같은 가로 구간끼리 세로로 합침
    cw, ch = W // CELL, H // CELL
    frac = walk[:ch * CELL, :cw * CELL].reshape(ch, CELL, cw, CELL).mean(axis=(1, 3))
    blocked = frac < 0.5
    rects, open_runs = [], {}
    for r in range(ch + 1):
        runs = {}
        if r < ch:
            c = 0
            while c < cw:
                if blocked[r, c]:
                    c0 = c
                    while c < cw and blocked[r, c]:
                        c += 1
                    runs[(c0, c)] = r
                else:
                    c += 1
        for key in list(open_runs):
            if key not in runs:
                r0 = open_runs.pop(key)
                rects.append([key[0] * CELL, r0 * CELL - OFFSET, (key[1] - key[0]) * CELL, (r - r0) * CELL])
        for key in runs:
            open_runs.setdefault(key, runs[key])
    # ---- heights: footprint 격자 칸 중심을 그림에 투영해 물이면 '0', 아니면 '2'
    fw = meta['footprint'][0]
    nrows = -(-int((H - (OFFSET - TIER * T)) / K) // TS)       # 그림 맨 아래까지 덮는 줄 수
    meta['footprint'] = [fw, nrows * TS]
    rows = []
    wmask = np.asarray(Image.open(LV / f"{spec['ground']}_water.png"))[..., 3] > 0   # 바다 마스크(beach 만 있음)
    if not wmask.any():
        wmask = None
    for r in range(nrows):
        s = ''
        for c in range(fw // TS):
            x0, y0 = c * TS, int(img_of(0, r * TS)[1])
            x1, y1 = min(x0 + TS, W), min(y0 + int(TS * K), H)
            if x1 <= x0 or y1 <= y0 or y0 < spec.get('sea_min_y', 0):
                s += str(T)
                continue
            sea = wmask is not None and wmask[y0:y1, x0:x1].mean() > 0.5
            s += '0' if sea and not walk[y0:y1, x0:x1].any() else str(T)   # 걸을 수 있는 칸은 항상 땅(높이 어긋남 방지)
        rows.append(s)
    meta['heights'] = rows
    meta['collision'] = rects
    meta['land_tier'] = T
    json.dump(meta, open(meta_p, 'w'), separators=(',', ':'))
    np.save(OUTQA / f'walk_{name}.npy', walk) if OUTQA.exists() else None
    print(f'{name}: {len(rects)} collision rects, walk px {int(walk.sum())}')
    if overlay:
        draw_overlay(name, png, walk, rects, spec)


def draw_overlay(name, png, walk, rects, spec):
    OUTQA.mkdir(parents=True, exist_ok=True)
    S = 2
    base = png.resize((png.width * S, png.height * S), Image.NEAREST).convert('RGBA')
    ov = Image.new('RGBA', base.size, (0, 0, 0, 0))
    d = ImageDraw.Draw(ov)
    for r in rects:
        x, y, w, h = r
        d.rectangle([x * S, (y + OFFSET) * S, (x + w) * S - 1, (y + OFFSET + h) * S - 1], fill=(255, 40, 40, 70))
    base = Image.alpha_composite(base, ov)
    d = ImageDraw.Draw(base)
    from level_markers import markers
    for kind, label, ix, iy, col in markers(name):
        X, Y = ix * S, iy * S
        d.ellipse([X - 4, Y - 4, X + 4, Y + 4], outline=col, width=2)
        d.text((X + 5, Y - 5), label, fill=col)
    base.convert('RGB').save(OUTQA / f'overlay_{name}.png')


if __name__ == '__main__':
    sys.path.insert(0, str(pathlib.Path(__file__).parent))
    names = [a for a in sys.argv[1:] if not a.startswith('--')] or list(MAPS)
    for n in names:
        build(n)
