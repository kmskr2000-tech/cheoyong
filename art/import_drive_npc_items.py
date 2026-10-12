# Drive 도트 에셋(NPC·아이템) -> 게임 시트/아이콘. 원본은 art/drive-src/ . 실행: python3 art/import_drive_npc_items.py
# NPC: 원본(정면 1컷, 64~96px)을 셀 높이에 맞게 축소 -> 팔레트 양자화 + 1px 외곽선 -> 5프레임 시트
#      (0 정면 / 1-2 오른쪽 자세+숨 / 3-4 왼쪽 거울). npc.gd 규칙: 셀 w = h*2/3, feet = h-4.
# 아이템: 시트를 열 단위로 잘라 HUD/필드용 아이콘으로 축소.
import os
from PIL import Image
HERE = os.path.dirname(os.path.abspath(__file__))
SRC = os.path.join(HERE, 'drive-src')
SPR = os.path.join(HERE, '..', 'src', 'assets', 'sprites')
ICO = os.path.join(HERE, '..', 'src', 'assets', 'ui', 'icons')
OUTLINE = (14, 10, 18, 255)


def load(p):
    return Image.open(os.path.join(SRC, p)).convert('RGBA')


def trim(im):
    return im.crop(im.getchannel('A').point(lambda a: 255 if a > 40 else 0).getbbox())


def split_cols(im, gap=1):
    a = im.getchannel('A').point(lambda v: 1 if v > 40 else 0)
    w, h = im.size
    occ = [any(a.getpixel((x, y)) for y in range(h)) for x in range(w)]
    out, x = [], 0
    while x < w:
        if occ[x]:
            s = x
            while x < w and occ[x]:
                x += 1
            out.append((s, x))
        else:
            x += 1
    return out


def shrink(im, max_w, max_h, colors=28, outline=True):
    im = trim(im)
    k = min(max_w / im.width, max_h / im.height, 1.0)
    w, h = max(1, round(im.width * k)), max(1, round(im.height * k))
    if (w, h) != im.size:
        im = im.resize((w, h), Image.LANCZOS)
    a = im.getchannel('A').point(lambda v: 255 if v > 110 else 0)
    q = im.convert('RGB').quantize(colors, method=Image.MEDIANCUT, dither=Image.NONE).convert('RGBA')
    q.putalpha(a)
    if outline:
        big = Image.new('RGBA', (w + 2, h + 2), (0, 0, 0, 0))
        big.alpha_composite(q, (1, 1))
        ol = Image.new('RGBA', big.size, (0, 0, 0, 0))
        px, op, bp = big.load(), ol.load(), big.load()
        for y in range(big.height):
            for x in range(big.width):
                if px[x, y][3] == 0:
                    for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                        nx, ny = x + dx, y + dy
                        if 0 <= nx < big.width and 0 <= ny < big.height and px[nx, ny][3] > 0:
                            op[x, y] = OUTLINE
                            break
        ol.alpha_composite(big)
        return ol
    return q


def sheet(figure, cell_h, name):
    cw = cell_h * 2 // 3
    fig = shrink(figure, cw - 2, cell_h - 4)
    feet = cell_h - 4
    frames = []
    for breath in (0, 0, 1):   # front, stance, breath
        f = fig
        if breath:   # 숨: stretch 1px taller from the feet up
            f = fig.resize((fig.width, fig.height + 1), Image.NEAREST)
        frames.append(f)
    cells = [frames[0], frames[1], frames[2]]
    cells += [ImageOps_mirror(frames[1]), ImageOps_mirror(frames[2])]
    out = Image.new('RGBA', (cw * 5, cell_h), (0, 0, 0, 0))
    for i, c in enumerate(cells):
        out.alpha_composite(c, (i * cw + (cw - c.width) // 2, feet + 1 - c.height))
    out.save(os.path.join(SPR, name + '.png'))
    return out.size


def ImageOps_mirror(im):
    return im.transpose(Image.FLIP_LEFT_RIGHT)


def icons(sheet_name, names, h, prefix):
    im = load(sheet_name)
    n = len(names)   # the glow of neighbours touches: cut into equal columns instead
    spans = [(round(im.width * i / n), round(im.width * (i + 1) / n)) for i in range(n)]
    for (x0, x1), n in zip(spans, names):
        ic = shrink(im.crop((x0, 0, x1, im.height)), h * 2, h, colors=24, outline=False)
        ic.save(os.path.join(ICO, '%s_%s.png' % (prefix, n)))


if __name__ == '__main__':
    os.makedirs(ICO, exist_ok=True)
    s = load('npc/npc-set.png')
    sp = split_cols(s)
    assert len(sp) == 3, sp
    set_names = ['npc_elder', 'npc_dolsoe', 'npc_child']   # 노파 / 삿갓 사내 / 인형 든 아이
    for (x0, x1), n in zip(sp, set_names):
        print(n, sheet(s.crop((x0, 0, x1, s.height)), 48, n))
    for src, n, ch in [('npc/char-king.png', 'npc_king', 48), ('npc/char-nanyeong.png', 'npc_nanyeong', 48),
                       ('npc/npc-sansin.png', 'npc_sansin', 48), ('npc/char-dragonking.png', 'npc_dragonking', 72),
                       ('npc/npc-seolmundae.png', 'npc_seolmundae', 72)]:
        print(n, sheet(load(src), ch, n))
    # 부적: 화염 / 파동(물결) / 결박(번개 문양) / 수호(산) / 다섯째(소용돌이 — 요괴를 내 편으로)
    icons('item/items-talismans.png', ['fire', 'wave', 'bind', 'guard', 'charm'], 24, 'tal')
    icons('item/items-key.png', ['flute', 'bell', 'quiver', 'jade', 'dagger'], 20, 'key')
    for src, n in [('item/item-mask.png', 'mask'), ('item/item-dragonseal.png', 'dragonseal')]:
        ic = shrink(load(src), 20, 20, colors=24, outline=False)
        ic.save(os.path.join(ICO, 'item_%s.png' % n))
    print('ok', sorted(os.listdir(ICO)))
