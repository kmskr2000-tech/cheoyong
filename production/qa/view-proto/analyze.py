#!/usr/bin/env python3
"""시점·카메라 설계: 맵별 뷰포트 점유율 표 + 지형 PNG 위 뷰포트 사각형 오버레이.
사용: python3 production/qa/view-proto/analyze.py   (레포 루트에서)
카메라 가동 범위 규칙(level.gd): 화면 가장자리가 left=0, right=size[0], top=-2*tier, bottom=size[1]-tier 를 넘지 못한다
 → 가로 W=size[0], 세로 H=size[1]+tier=PNG높이-56. 지형 PNG는 (0,-offset)에 놓인다(offset=82).
"""
import json, re, struct, os, sys
from PIL import Image, ImageDraw, ImageFont
ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..', '..'))
SRC = os.path.join(ROOT, 'src')
OUT = os.path.dirname(os.path.abspath(__file__))
levels = open(os.path.join(SRC, 'scripts/levels.gd'), encoding='utf-8').read()
CH1 = ['beach', 'gyeongju', 'gwana', 'pyega1', 'pyega2', 'palace']
CH2 = ['hwagae', 'jiri_path', 'old_village', 'den1', 'den2', 'den3']
VIEWS = [('A 480x270', 480, 270), ('B1 576x324', 576, 324), ('B2 640x360', 640, 360)]
rows = []
for lid in CH1 + CH2:
    m = re.search(r'"%s": \{.*?"ground": "(\w+)"' % lid, levels, re.S)
    g = m.group(1)
    meta = json.load(open(os.path.join(SRC, 'assets/levels/%s.json' % g)))
    png = os.path.join(SRC, 'assets/levels/%s.png' % g)
    w, h = Image.open(png).size
    tier, off = meta['tier'], meta['offset']
    W, H = meta['size'][0], h - 56
    assert H == meta['size'][1] + tier
    rows.append(dict(id=lid, ground=g, png=(w, h), W=W, H=H, tier=tier, off=off))
if __name__ == '__main__':
    print('| 장 | 맵 id | 지형 PNG | 카메라 가동 범위 W×H | A 480×270 가로/세로/면적 | B1 576×324 | B2 640×360 | B2가 되려면 부족한 PNG 폭/높이 |')
    print('|---|---|---|---|---|---|---|---|')
    for i, r in enumerate(rows):
        cells = []
        for _, vw, vh in VIEWS:
            cells.append('%d%% / %d%% / %d%%%s' % (min(100, vw / r['W'] * 100), min(100, vh / r['H'] * 100), min(1, vw / r['W']) * min(1, vh / r['H']) * 100,
                                                  ' (가로 초과)' if vw > r['W'] else ''))
        short = '폭 %+d / 높이 %+d' % (max(0, 640 - r['W']), max(0, 360 - r['H']))
        print('| %d | %s | %s | %d×%d | %s | %s | %s | %s |' % (1 if i < 6 else 2, r['id'], '%dx%d' % r['png'], r['W'], r['H'], cells[0], cells[1], cells[2], short))
    # 오버레이: 맵 별로 지형 PNG 위에 뷰포트 사각형(세 가지), 중심은 맵 중앙
    font = ImageFont.truetype(os.path.join(SRC, 'assets/fonts/Galmuri11.ttf'), 12)
    tiles = []
    for r in rows:
        im = Image.open(os.path.join(SRC, 'assets/levels/%s.png' % r['ground'])).convert('RGBA')
        bg = Image.new('RGBA', (im.width + 200, im.height + 200), (8, 10, 18, 255))
        bg.paste(im, (100, 100))
        d = ImageDraw.Draw(bg)
        # 카메라 범위: x 0..W, y -2tier..size[1]-tier  → PNG y = world y + off
        x0, y0 = 100, 100 + (-2 * r['tier'] + r['off'])
        d.rectangle([x0, y0, x0 + r['W'], y0 + r['H']], outline=(255, 255, 255, 140))
        cx, cy = x0 + r['W'] / 2, y0 + r['H'] / 2
        for (name, vw, vh), col in zip(VIEWS, [(255, 80, 80), (255, 200, 60), (80, 220, 255)]):
            d.rectangle([cx - vw / 2, cy - vh / 2, cx + vw / 2, cy + vh / 2], outline=col, width=2)
        d.text((104, 104), '%s (%s.png %dx%d)  빨강 480x270 / 노랑 576x324 / 하늘 640x360' % (r['id'], r['ground'], *r['png']), font=font, fill=(255, 255, 255))
        tiles.append(bg)
    W = max(t.width for t in tiles)
    cols = 2
    rws = (len(tiles) + cols - 1) // cols
    hs = [max(t.height for t in tiles[i * cols:(i + 1) * cols]) for i in range(rws)]
    sheet = Image.new('RGBA', (W * cols, sum(hs)), (8, 10, 18, 255))
    y = 0
    for i in range(rws):
        for j in range(cols):
            k = i * cols + j
            if k < len(tiles):
                sheet.paste(tiles[k], (j * W, y))
        y += hs[i]
    sheet = sheet.convert('RGB'); sheet = sheet.resize((sheet.width // 2, sheet.height // 2), Image.LANCZOS); sheet.save(os.path.join(OUT, 'map-coverage.png'))
    print('wrote map-coverage.png', sheet.size)
