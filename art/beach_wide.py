"""와이드 뷰(prog/view-overhaul)용 백사장 지형 'beach_w': 기존 beach 를 정확히 2배로 다시 굽는다.
그림은 Drive 원본(1920x1280)에서 1280x788 로 직접 다운스케일(박스 1.5배), 좌표계는 기존 beach.json 을 x2:
  footprint x2, ts 16->32(격자 칸 수 동일), tier 26->52, offset 82->164, size x2, 충돌 사각형 x2.
  => 화면 y = 0.75*fy - t*52 = 2 * (기존 화면 y), 기존 beach 의 모든 좌표(levels.gd)는 단순히 x2 하면 된다.
사용: python3 art/beach_wide.py
"""
import json, pathlib, sys
sys.path.insert(0, str(pathlib.Path(__file__).parent))
from terrain_import import process, normal, sea_mask, MAPS, OUT

S = 2
src, box, tone = MAPS['beach']
old = json.load(open(OUT / 'beach.json'))
W, H = 640 * S, 394 * S
img = process(src, box, tone, (W, H))
img.convert('RGBA').save(OUT / 'beach_w.png')
normal(img).save(OUT / 'beach_w_n.png')
sea_mask(img).save(OUT / 'beach_w_water.png')
m = dict(old)
m['size'] = [old['size'][0] * S, old['size'][1] * S]
m['footprint'] = [old['footprint'][0] * S, old['footprint'][1] * S]
m['ts'] = old['ts'] * S
m['tier'] = old['tier'] * S
m['offset'] = old['offset'] * S
m['collision'] = [[v * S for v in r] for r in old['collision']]
json.dump(m, open(OUT / 'beach_w.json', 'w'), separators=(',', ':'))
print('ok beach_w', (W, H), m['size'], m['footprint'], len(m['collision']))
