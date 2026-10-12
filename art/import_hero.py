"""주인공 처용: Drive 도트 시트(신처용가-게임에셋/주인공) -> src/assets/sprites/cheoyong.png (64x64 셀, 발 기준선 58).

사용: python3 art/import_hero.py [--preview]
입력: ~/workspace/goals/rpg/assets-drive/hero/{walk,run,8dir,attack,attack8,hurt,die}.png (Drive webp 디코드본, repo 밖)
처리: (a) 균일한 남색 배경(33,30,45)을 테두리에서 flood-fill 로 제거 -> 이진 알파
      (b) 시트마다 한 배율(머리~발 38px 기준)로 BOX 평균 축소 (프레임별 개별 배율 없음 → 크기 통일)
      (c) 몸통(푸른 이펙트 제외) 발 중심을 셀 가운데·발 바닥을 58행에 정렬
      (d) 전체 시트 팔레트 32색 통일(디더 없음) + 1px 잉크 외곽선
프레임 순서는 player.gd(SHEET/ATK/SPIN/SONG/HURT/DIE/RUN 상수)가 기대하는 순서.
이 스크립트가 src/assets/sprites/cheoyong.png 를 새로 쓴다. (art/hero.py 의 3D 렌더 출력은 더 이상 쓰지 않음)
"""
import pathlib, sys
import numpy as np
from PIL import Image
from scipy import ndimage

ROOT = pathlib.Path(__file__).parent
REPO = ROOT.parent
OUT = REPO / 'src' / 'assets' / 'sprites' / 'cheoyong.png'
SRC = pathlib.Path.home() / 'workspace/goals/rpg/assets-drive/hero'
CELL = 64
FEET = 58
BG_TOL = 6   # 검은 도포(≈배경색)가 배경으로 번지지 않도록 좁게
INK = (7, 6, 11, 255)
PAL_N = 32
MUL = 1.22      # 전 시트 공통 배율 보정: 머리~발 38px -> 46px (얼굴 눈코가 읽히는 최소 크기)
GAMMA = 0.12    # 검은 도포 암부 들어올림
BLUE_THR = 0.18 # 푸른 문양 픽셀 보존 임계

_cache = {}
def load(name):
    if name not in _cache:
        a = np.array(Image.open(SRC / f'{name}.png').convert('RGB')).astype(int)
        edge = np.concatenate([a[:6].reshape(-1, 3), a[-6:].reshape(-1, 3), a[:, :6].reshape(-1, 3), a[:, -6:].reshape(-1, 3)])
        bg = np.median(edge, axis=0)          # 시트마다 배경색이 조금씩 다르다
        near = np.abs(a - bg).max(2) <= BG_TOL
        lab, _ = ndimage.label(near)
        border = set(lab[0]) | set(lab[-1]) | set(lab[:, 0]) | set(lab[:, -1]); border.discard(0)
        fg = ~np.isin(lab, list(border))
        fg = ndimage.binary_opening(fg, iterations=1)
        _cache[name] = (a, fg)
    return _cache[name]

DRAGON = ["..111..", ".12211.", ".1222..", "..11...", "...11..", "..122..", ".122...", ".12211.", "..111.."]
DR_COL = {'1': (64, 112, 232), '2': (150, 205, 255)}
def stamp_dragon(res, bm):
    """푸른 용 문양: 가슴 위 작은 덩어리(검기 이펙트 아님)는 도트가 뭉개지므로 손으로 그린 9x7 용 글리프로 다시 찍는다."""
    lab, n = ndimage.label(ndimage.binary_dilation(bm, iterations=1))
    for k in range(1, n + 1):
        m = lab == k
        ys, xs = np.where(m & bm)
        if len(ys) < 5 or len(ys) > 60 or ys.max() - ys.min() > 12 or xs.max() - xs.min() > 10:
            continue
        cy, cx = int(round(ys.mean())), int(round(xs.mean()))
        for r, line in enumerate(DRAGON):
            for c, ch in enumerate(line):
                if ch in DR_COL:
                    y, x = cy - 4 + r, cx - 3 + c
                    if 0 <= y < res.shape[0] and 0 <= x < res.shape[1] and res[y, x, 3]:
                        res[y, x, :3] = DR_COL[ch]
    return res

def grab(name, box, scale, flip=False):
    scale = scale * MUL
    """crop box from sheet -> RGBA image downscaled by `scale`, feet-aligned into a CELL x CELL tile."""
    a, fg = load(name)
    x0, y0, x1, y1 = box
    f = fg[y0:y1, x0:x1].copy()
    # keep only components of real size inside the box (drops neighbour fragments)
    lab, n = ndimage.label(ndimage.binary_dilation(f, iterations=6))
    if n > 1:
        areas = ndimage.sum(f, lab, range(1, n + 1))
        keep = [i + 1 for i, ar in enumerate(areas) if ar > 0.08 * max(areas)]
        f &= np.isin(lab, keep)
    rgb = a[y0:y1, x0:x1].astype(np.uint8)
    ys, xs = np.where(f)
    cy0, cy1, cx0, cx1 = ys.min(), ys.max() + 1, xs.min(), xs.max() + 1
    rgb = rgb[cy0:cy1, cx0:cx1]; f = f[cy0:cy1, cx0:cx1]
    blue = (rgb[..., 2].astype(int) - rgb[..., 0] > 70) & (rgb[..., 2] > 150)   # 푸른 이펙트/문양
    body = f & ~blue
    ys, xs = np.where(body)
    bottom = ys.max()
    low = body & (np.arange(body.shape[0])[:, None] > bottom - 0.12 * body.shape[0])
    lx = np.where(low.any(0))[0]
    fx = (lx.min() + lx.max()) / 2.0   # foot centre
    # v2 (2026-10-12 hero-detail): bg 제거 영역을 가장 가까운 전경색으로 채운 뒤 LANCZOS 축소(경계 헤일로 방지),
    # 알파는 BOX>=0.5, 푸른 문양은 별도 마스크를 max-pool 식으로 살려 밝게 유지, 어두운 도포는 감마로 살짝 들어올려 주름·윤곽이 읽히게
    idx = ndimage.distance_transform_edt(~f, return_distances=False, return_indices=True)
    filled = rgb[idx[0], idx[1]]
    if GAMMA:
        filled = (255 * (filled / 255.0) ** (1 - GAMMA)).astype(np.uint8)
    w, h = max(1, round(f.shape[1] * scale)), max(1, round(f.shape[0] * scale))
    small = np.array(Image.fromarray(filled).resize((w, h), Image.LANCZOS)).astype(float)
    al = np.array(Image.fromarray((f * 255).astype(np.uint8)).resize((w, h), Image.BOX)).astype(float) / 255
    bl = (blue & f)
    bcnt = np.array(Image.fromarray((bl * 255).astype(np.uint8)).resize((w, h), Image.BOX)).astype(float) / 255
    bcol = np.array(Image.fromarray(np.where(bl[..., None], rgb, 0).astype(np.uint8)).resize((w, h), Image.BOX)).astype(float)
    bcol = bcol / np.maximum(bcnt[..., None], 0.05)
    bm = bcnt > BLUE_THR
    small = np.where(bm[..., None], np.clip(bcol * 1.12 + 8, 0, 255), small)
    res = np.dstack([np.clip(small, 0, 255), (al >= 0.5) * 255]).astype(np.uint8)
    stamp_dragon(res, bm)
    sm = Image.fromarray(res, 'RGBA')
    fxs, bys = int(round(fx * scale)), int(round((bottom + 1) * scale))
    tile = Image.new('RGBA', (CELL, CELL), (0, 0, 0, 0))
    if flip:
        sm = sm.transpose(Image.FLIP_LEFT_RIGHT); fxs = sm.width - fxs
    ox, oy = CELL // 2 - fxs, FEET - bys
    ox = max(min(ox, CELL - sm.width), 0) if sm.width <= CELL else ox
    tile.alpha_composite(sm, (max(ox, 0), max(oy, 0))) if (ox >= 0 and oy >= 0) else tile.paste(sm.crop((max(-ox, 0), max(-oy, 0), sm.width, sm.height)), (max(ox, 0), max(oy, 0)))
    return tile

def row(name, boxes, scale, flip=False):
    return [grab(name, b, scale, flip) for b in boxes]

def breath(t):
    """idle frame B: 1px lower head (squash 1px from the top, feet fixed)."""
    a = t.crop((0, 0, CELL, FEET + 1))
    bb = a.getbbox()
    top = a.crop((0, bb[1], CELL, FEET + 1))
    sq = top.resize((CELL, top.height - 1), Image.NEAREST)
    n = Image.new('RGBA', (CELL, CELL), (0, 0, 0, 0)); n.paste(sq, (0, bb[1] + 1)); return n

def build():
    S = {'walk': 0.103, 'run': 0.10, '8dir': 0.060, 'attack': 0.105, 'attack8': 0.10, 'hurt': 0.10, 'die': 0.105}
    F = {}
    # ---- idle (8dir views)
    f8 = lambda b, fl=False: grab('8dir', b, S['8dir'], fl)
    front = f8((100, 20, 420, 650)); r34 = f8((600, 20, 860, 650)); right = f8((1080, 20, 1350, 650))
    backr = f8((1500, 20, 1860, 650)); l34 = f8((100, 650, 420, 1275)); left = f8((560, 650, 860, 1275))
    back = f8((1020, 650, 1360, 1275)); back2 = f8((1480, 650, 1860, 1275))
    F['idle'] = {'down': front, 'up': back, 'right': right, 'downl': l34}
    # ---- walk / run (3-frame cycles -> a,b,c,b)
    W = S['walk']
    F['walk'] = {'down': row('walk', [(100, 10, 360, 430), (380, 10, 620, 430), (640, 10, 880, 430)], W),
                 'up': row('walk', [(100, 440, 360, 850), (380, 440, 620, 850), (640, 440, 880, 850)], W),
                 'right': row('walk', [(1020, 10, 1300, 430), (1300, 10, 1580, 430), (1580, 10, 1880, 430)], W)}
    R = S['run']
    F['run'] = {'down': row('run', [(60, 10, 360, 430), (350, 10, 620, 430), (620, 10, 900, 430)], R),
                'up': row('run', [(100, 440, 360, 850), (380, 440, 640, 850), (640, 440, 900, 850)], R),
                'right': row('run', [(1000, 10, 1300, 430), (1280, 10, 1580, 430), (1560, 10, 1880, 430)], R)}
    # ---- attacks: [dir][combo] -> 3 frames
    A, A8 = S['attack'], S['attack8']
    F['atk'] = {
        'down': [row('attack', [(90, 0, 350, 425), (350, 0, 600, 425), (580, 0, 950, 425)], A),
                 row('attack8', [(60, 40, 330, 410), (330, 40, 640, 410), (620, 40, 960, 410)], A8),
                 row('attack8', [(50, 890, 330, 1240), (330, 890, 620, 1240), (620, 890, 960, 1240)], A8)],
        'up': [row('attack', [(100, 425, 360, 850), (400, 425, 620, 850), (650, 425, 950, 850)], A),
               row('attack8', [(60, 490, 330, 850), (330, 490, 640, 850), (640, 490, 960, 850)], A8),
               row('attack', [(100, 425, 360, 850), (400, 425, 620, 850), (650, 425, 950, 850)], A)],
        'right': [row('attack', [(1030, 0, 1290, 425), (1290, 0, 1560, 425), (1560, 0, 1920, 425)], A),
                  row('attack', [(1010, 425, 1290, 850), (1290, 425, 1560, 850), (1560, 425, 1920, 850)], A),
                  row('attack8', [(990, 890, 1290, 1240), (1290, 890, 1590, 1240), (1590, 890, 1910, 1240)], A8)],
    }
    F['atk']['left'] = [[t.transpose(Image.FLIP_LEFT_RIGHT) for t in c] for c in F['atk']['right']]
    # ---- song (flute at the lips)
    F['song'] = {'down': F['atk']['down'][1][0], 'up': F['atk']['up'][1][0], 'right': grab('attack8', (1000, 30, 1290, 410), A8)}
    F['song']['left'] = F['song']['right'].transpose(Image.FLIP_LEFT_RIGHT)
    # ---- spin (처용무): the eight views
    F['spin'] = [front, r34, right, backr, back, backr.transpose(Image.FLIP_LEFT_RIGHT), left, l34]
    # ---- hurt
    H = S['hurt']
    F['hurt'] = {'down': grab('hurt', (60, 30, 370, 430), H), 'up': grab('hurt', (100, 470, 350, 840), H),
                 'right': grab('hurt', (1010, 30, 1290, 400), H)}
    F['hurt']['left'] = F['hurt']['right'].transpose(Image.FLIP_LEFT_RIGHT)
    # ---- die (kneel, kneel, collapse, lying)
    D = S['die']
    F['die'] = [grab('die', b, D) for b in [(60, 90, 330, 400), (340, 90, 610, 400), (580, 190, 950, 410), (930, 230, 1310, 390)]]
    return F

# sheet index plan (must match player.gd)
def layout(F):
    cells = [None] * 100
    idle = F['idle']
    cells[0] = idle['down']
    cells[1] = idle['up']; cells[2] = idle['right']
    for k, d in enumerate(['down', 'up', 'right']):
        w = F['walk'][d]
        for i, j in enumerate([0, 1, 2, 1]):
            cells[3 + k * 4 + i] = w[j]
    cells[15], cells[16], cells[17] = idle['down'], idle['up'], idle['right']
    cells[18] = idle['down']; cells[19] = breath(idle['down'])
    cells[20] = idle['downl']; cells[21] = breath(idle['downl'])
    for d, dn in enumerate(['down', 'up', 'right', 'left']):
        for c in range(3):
            for i in range(3):
                cells[22 + d * 9 + c * 3 + i] = F['atk'][dn][c][i]
    for i in range(8):
        cells[58 + i] = F['spin'][i]
    for i, d in enumerate(['down', 'up', 'right', 'left']):
        cells[66 + i] = F['song'][d]
    for i, d in enumerate(['down', 'up', 'right', 'left']):
        cells[70 + i] = F['hurt'][d]
    for i in range(4):
        cells[74 + i] = F['die'][i]
    for k, d in enumerate(['down', 'up', 'right']):
        for i in range(3):
            cells[78 + k * 3 + i] = F['run'][d][i]
    return cells[:87]

def finish(cells):
    sheet = Image.new('RGBA', (CELL * len(cells), CELL), (0, 0, 0, 0))
    for i, c in enumerate(cells):
        sheet.alpha_composite(c, (i * CELL, 0))
    a = np.array(sheet)
    op = a[..., 3] > 0
    # palette unify (32 colours, no dither)
    # 푸른 이펙트(검기·용 문양)는 따로 8색, 나머지 28색 — 한 팔레트로 합치면 푸른빛이 회색으로 죽는다
    blue = op & (a[..., 2].astype(int) - a[..., 0] > 40) & (a[..., 2] > 110)
    for mask, n in ((~blue & op, 40), (blue, 12)):
        px = a[mask][:, :3]
        if len(px) == 0:
            continue
        im = Image.fromarray(px.reshape(1, -1, 3))
        qq = np.array(im.quantize(n, method=Image.MEDIANCUT, dither=Image.NONE).convert('RGB')).reshape(-1, 3)
        a[mask, :3] = qq
    # 1px ink outline (4-neighbour) per cell only
    dil = ndimage.binary_dilation(op, structure=ndimage.generate_binary_structure(2, 1)) & ~op
    # keep outline inside each cell
    for i in range(len(cells)):
        pass
    a[dil] = INK
    return Image.fromarray(a, 'RGBA')

if __name__ == '__main__':
    F = build()
    cells = layout(F)
    sheet = finish(cells)
    sheet.save(OUT)
    print('saved', OUT, sheet.size, len(cells), 'frames')
    prev = ROOT / 'out' / 'hero_import_preview.png'
    prev.parent.mkdir(exist_ok=True)
    cols = 10; rows = (len(cells) + cols - 1) // cols
    P = Image.new('RGBA', (cols * CELL, rows * CELL), (60, 70, 60, 255))
    for i in range(len(cells)):
        t = sheet.crop((i * CELL, 0, (i + 1) * CELL, CELL))
        P.alpha_composite(t, ((i % cols) * CELL, (i // cols) * CELL))
    P.resize((P.width * 2, P.height * 2), Image.NEAREST).save(prev)
    print('preview', prev)
