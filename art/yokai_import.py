"""Drive 요괴 PNG(종당 idle + atk_1..3)를 게임용 8프레임 시트로 정리·변환한다 (2026-10-12).

입력  ~/workspace/goals/rpg/assets-drive/yokai/<name>_{idle,atk_1,atk_2,atk_3}.png (repo 밖)
정리  - 불투명 검은 배경(물귀신 등)을 테두리 flood-fill로 제거, 저알파 잔재(<24) 제거
      - idle 의 1~2px 낱알 잔재 제거, 아래 기준선 정렬, 가로 중앙 정렬(칸 너비 = 4프레임 중 최대 폭)
시트  move0..3 = idle 숨쉬기(0,-1,0,-1px) | 4 tell = atk_1 | 5 strike = atk_2 | 6 hurt = idle 뒤로 밀림+붉은 틴트 | 7 = atk_3(후속 동작)
출력  GAME: src/assets/sprites/<sheet>.png (1장에서 쓰는 종)  /  NEXT: src/assets/sprites/yokai/<name>.png (2장 이후, 아직 미연결)
      cfg(cell, feet)는 art/out/yokai_cfg.json + 표준출력.
"""
import json, pathlib, sys
from PIL import Image

ROOT = pathlib.Path(__file__).parent
SPR = ROOT.parent / 'src' / 'assets' / 'sprites'
SRC = pathlib.Path.home() / 'workspace/goals/rpg/assets-drive/yokai'

# Drive 이름 -> 게임 시트 이름 (src/scripts/enemy.gd KINDS 의 sheet)
GAME = {'ch1-mama': 'mama', 'ch1-egg': 'egg_ghost', 'ch1-maiden': 'maiden_ghost',
        'yokai-waterghost': 'mulgwi', 'enemy-seayokai': 'gaetgwi', 'enemy-wraith': 'ghoul'}
# 2장 이후에 쓸 종: 시트만 만들어 둔다
NEXT = {'ch2-onedokkaebi': 'dokkaebi_oneeye', 'ch2-firedokkaebi': 'dokkaebi_fire', 'ch2-jangsanbeom': 'jangsanbeom',
        'ch2-sangun': 'sangun', 'ch3-foxminion': 'fox_minion', 'ch3-jangseung': 'jangseung_taki', 'ch3-bride': 'songaksi',
        'ch4-haetae': 'haetae', 'ch4-darkspirit': 'eodukssini', 'ch4-waveyokai': 'pado', 'ch5-bulgae': 'bulgae',
        'ch5-deadlegion': 'mangja', 'ch5-underguard': 'jeoseung_guard', 'yokai-dokkaebi': 'dokkaebi_extra',
        'yokai-gumiho': 'gumiho', 'yokai-reaper': 'reaper', 'yokai-plague': 'plague_extra', 'boss-imugi': 'imugi'}


def clean(im, speck=False):
    im = im.convert('RGBA')
    w, h = im.size
    px = im.load()
    # 1) opaque dark background connected to the border
    def dark(x, y):
        r, g, b, a = px[x, y]
        return a > 0 and max(r, g, b) <= 30
    corners = sum(1 for p in [(0, 0), (w - 1, 0), (0, h - 1), (w - 1, h - 1)] if px[p][3] > 200 and max(px[p][:3]) <= 30)
    if corners >= 3:
        stack = [(x, y) for x in range(w) for y in (0, h - 1)] + [(x, y) for y in range(h) for x in (0, w - 1)]
        seen = set()
        while stack:
            x, y = stack.pop()
            if (x, y) in seen or not (0 <= x < w and 0 <= y < h) or not dark(x, y):
                continue
            seen.add((x, y)); px[x, y] = (0, 0, 0, 0)
            stack += [(x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)]
    # 2) faint alpha residue
    for y in range(h):
        for x in range(w):
            if 0 < px[x, y][3] < 24:
                px[x, y] = (0, 0, 0, 0)
    # 3) isolated specks (<=2px, 8-connected)
    if speck:
        seen = set()
        for y in range(h):
            for x in range(w):
                if px[x, y][3] and (x, y) not in seen:
                    comp, st = [], [(x, y)]
                    seen.add((x, y))
                    while st:
                        cx, cy = st.pop(); comp.append((cx, cy))
                        for dx in (-1, 0, 1):
                            for dy in (-1, 0, 1):
                                n = (cx + dx, cy + dy)
                                if 0 <= n[0] < w and 0 <= n[1] < h and n not in seen and px[n][3]:
                                    seen.add(n); st.append(n)
                    if len(comp) <= 2:
                        for c in comp: px[c] = (0, 0, 0, 0)
    return im


def tint(im, k=0.35):
    im = im.copy(); px = im.load()
    for y in range(im.height):
        for x in range(im.width):
            r, g, b, a = px[x, y]
            if a: px[x, y] = (int(r + (255 - r) * k), int(g * (1 - k * .6)), int(b * (1 - k * .6)), a)
    return im


def build(name):
    idle = clean(Image.open(SRC / f'{name}_idle.png'), speck=True)
    atk = [clean(Image.open(SRC / f'{name}_atk_{i}.png')) for i in (1, 2, 3)]
    H = max(i.height for i in [idle] + atk) + 2   # 2px headroom for the bob
    W = max(i.width for i in [idle] + atk)
    W += W % 2
    bb = idle.getchannel('A').point(lambda a: 255 if a > 40 else 0).getbbox()
    feet = H - 1 - (idle.height - bb[3]) if bb else H - 1   # last opaque row of the idle in cell coordinates
    def put(im, dx=0, dy=0):
        c = Image.new('RGBA', (W, H), (0, 0, 0, 0))
        c.alpha_composite(im, ((W - im.width) // 2 + dx, H - im.height + dy))
        return c
    frames = [put(idle, 0, dy) for dy in (0, -1, 0, -1)]
    frames += [put(atk[0]), put(atk[1]), put(tint(idle), 2, 0), put(atk[2])]
    sheet = Image.new('RGBA', (W * len(frames), H), (0, 0, 0, 0))
    for i, f in enumerate(frames):
        sheet.alpha_composite(f, (i * W, 0))
    return sheet, {'cell': [W, H], 'feet': feet}


def build_boss():
    """역신 boss (boss.gd ANIMS idle0-3, cast4, swipe5, hurt6, human7, pulse8). Frame 7 (human disguise) is kept from the
    previous sheet (git HEAD~: the old 120x164 cells) because the Drive set has no equivalent."""
    name = 'boss-plagueking'
    idle = clean(Image.open(SRC / f'{name}_idle.png'), speck=True)
    atk = [clean(Image.open(SRC / f'{name}_atk_{i}.png')) for i in (1, 2, 3)]
    H = max(i.height for i in [idle] + atk) + 2
    W = 120
    old = Image.open(ROOT / 'out' / 'plague_god_old_ref.png').convert('RGBA').crop((7 * 120, 0, 8 * 120, 164))
    hb = old.getbbox()
    human = old.crop(hb)
    def put(im, dx=0, dy=0):
        c = Image.new('RGBA', (W, H), (0, 0, 0, 0))
        c.alpha_composite(im, ((W - im.width) // 2 + dx, H - im.height + dy))
        return c
    frames = [put(idle, 0, dy) for dy in (0, -1, 0, -1)] + [put(atk[0]), put(atk[1]), put(tint(idle), 2, 0), put(human), put(atk[2])]
    sheet = Image.new('RGBA', (W * len(frames), H), (0, 0, 0, 0))
    for i, f in enumerate(frames):
        sheet.alpha_composite(f, (i * W, 0))
    sheet.save(SPR / 'plague_god.png')
    n = SPR / 'plague_god_n.png'
    if n.exists(): n.unlink()
    print('boss plague_god', (W, H), 'feet', H - 1)


def main(only=None):
    if not only or 'boss-plagueking' in only:
        build_boss()
    cfg = {}
    (SPR / 'yokai').mkdir(exist_ok=True)
    for table, sub in ((GAME, ''), (NEXT, 'yokai')):
        for name, out in table.items():
            if only and name not in only: continue
            sheet, c = build(name)
            p = SPR / sub / f'{out}.png'
            sheet.save(p)
            if not sub:
                n = p.with_name(out + '_n.png')   # old generated normal map no longer matches the new sheet
                if n.exists(): n.unlink()
            cfg[out] = c
            print(name, '->', p.relative_to(SPR.parent.parent.parent), c)
    (ROOT / 'out').mkdir(exist_ok=True)
    f = ROOT / 'out' / 'yokai_cfg.json'
    old = json.loads(f.read_text()) if f.exists() else {}
    old.update(cfg); f.write_text(json.dumps(old, indent=1))


if __name__ == '__main__':
    main(set(sys.argv[1:]) or None)
