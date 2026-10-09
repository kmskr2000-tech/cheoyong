"""Dialogue UI pieces (pixel art, 9-slice friendly): 옻칠 자개 panel, 낙관 name seal, 매듭 tassel.

panel.png   48x48, 9-slice margins 14: black lacquer with faint grain, a brass double rule, and
            mother-of-pearl cloud (구름문) inlays in the corners that shimmer pink/cyan/white.
seal.png    24x20, 9-slice margins 6: a vermilion seal stamp with a carved light border and worn edges.
knot.png    2 frames of 9x14: a red 매듭 knot with a tassel, swaying (continue indicator).
HUD:        emblem (처용탈), brush-stroke gauges, lacquer touch buttons, brass-ring joystick.
Output: godot/assets/ui/
"""
import pathlib, random
from PIL import Image

OUT = pathlib.Path(__file__).parent.parent / 'godot' / 'assets' / 'ui'


def hx(h, a=255):
    h = h.lstrip('#')
    return (int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16), a)


INK = hx('#06050a')
LACQ = [hx('#0a0a12', 238), hx('#0e0e18', 238), hx('#12131e', 238)]
BRASS = [hx('#4a3418'), hx('#8a6a30'), hx('#c9a24a'), hx('#f0d488')]
PEARL = [hx('#7fb8c8'), hx('#c8a0c8'), hx('#e8f0f0'), hx('#9ad0d8'), hx('#f0c8d8')]
SEAL = [hx('#4a0e12'), hx('#7a1a1c'), hx('#a8282a'), hx('#c8443a')]
CREAM = hx('#e8dcc0')

# 구름문 (cloud scroll) corner inlay, 10x10: 'p' pearl (cycled tones), '.' empty
CLOUD = [
    '..pppp....',
    '.p....p...',
    'p..pp..p..',
    'p.p..p.p..',
    'p.p.p..p..',
    'p..p..p...',
    '.p...pp.pp',
    '..ppp..p.p',
    '.......p.p',
    '........p.',
]


def panel():
    S, M = 48, 14
    im = Image.new('RGBA', (S, S), (0, 0, 0, 0))
    p = im.load()
    rnd = random.Random(3)
    for y in range(S):
        for x in range(S):
            if x in (0, S - 1) or y in (0, S - 1):
                p[x, y] = INK
                continue
            g = LACQ[(x * 7 + (y // 3) * 3 + rnd.randint(0, 1)) % 3]  # faint vertical grain
            p[x, y] = g
    # brass double rule
    for k, col in ((2, BRASS[2]), (4, BRASS[1])):
        for i in range(k, S - k):
            p[i, k] = col if k == 2 else BRASS[1]
            p[i, S - 1 - k] = BRASS[1] if k == 2 else BRASS[0]
            p[k, i] = col if k == 2 else BRASS[1]
            p[S - 1 - k, i] = BRASS[1] if k == 2 else BRASS[0]
    for i in range(3, S - 3, 6):  # brass highlights along the top rule
        p[i, 2] = BRASS[3]
    # pearl cloud inlays, mirrored into all four corners
    for cy, row in enumerate(CLOUD):
        for cx, ch in enumerate(row):
            if ch != 'p':
                continue
            col = PEARL[(cx + cy) % len(PEARL)]
            for (x, y) in ((cx + 3, cy + 3), (S - 4 - cx, cy + 3), (cx + 3, S - 4 - cy), (S - 4 - cx, S - 4 - cy)):
                p[x, y] = col
    im.save(OUT / 'panel.png')


def seal():
    W, H = 24, 20
    im = Image.new('RGBA', (W, H), (0, 0, 0, 0))
    p = im.load()
    rnd = random.Random(7)
    for y in range(H):
        for x in range(W):
            edge = x in (0, W - 1) or y in (0, H - 1)
            if edge and rnd.random() < 0.25:
                continue  # worn stamp edge
            if edge:
                p[x, y] = SEAL[0]
            elif x in (2, W - 3) or y in (2, H - 3):
                p[x, y] = CREAM if rnd.random() > 0.12 else SEAL[2]  # carved border
            else:
                p[x, y] = SEAL[2] if rnd.random() > 0.18 else SEAL[1 + rnd.randint(0, 2) // 2]
    im.save(OUT / 'seal.png')


def knot():
    rows_a = [
        '...ooo...',
        '..oRqRo..',
        '.oRqQqRo.',
        'oRqQoQqRo',
        '.oRqQqRo.',
        '..oRqRo..',
        '...oYo...',
        '...oyo...',
        '..oRRRo..',
        '..oRqRo..',
        '..oRqro..',
        '..oRqro..',
        '..oqrro..',
        '...ooo...',
    ]
    pal = {'o': INK, 'R': SEAL[2], 'q': SEAL[3], 'Q': hx('#f07a5a'), 'r': SEAL[1], 'Y': BRASS[3], 'y': BRASS[1]}
    im = Image.new('RGBA', (18, 14), (0, 0, 0, 0))
    p = im.load()
    for f in range(2):
        for y, row in enumerate(rows_a):
            dx = 1 if (f == 1 and y >= 8) else 0  # tassel swings
            for x, ch in enumerate(row):
                if ch in pal:
                    p[f * 9 + min(8, x + dx), y] = pal[ch]
    im.save(OUT / 'knot.png')




# ---------------------------------------------------------------- HUD + touch controls
JADE = [hx('#0c2a26'), hx('#16463e'), hx('#2a7a68'), hx('#5ac8a8'), hx('#b0f0dc')]
VERM = [hx('#3a0a0e'), hx('#6a1418'), hx('#a82a26'), hx('#e0503a'), hx('#ff9a78')]
MASK = {'o': INK, 'r': SEAL[2], 'R': SEAL[3], 'd': SEAL[1], 'k': hx('#14101a'), 'w': CREAM,
        'g': BRASS[2], 'G': BRASS[3], 'y': BRASS[1], 'p': PEARL[1], 'q': PEARL[0]}


def _grid(rows, pal, im=None, ox=0, oy=0):
    w, h = len(rows[0]), len(rows)
    im = im or Image.new('RGBA', (w, h), (0, 0, 0, 0))
    p = im.load()
    for y, r in enumerate(rows):
        for x, ch in enumerate(r):
            if ch in pal:
                p[ox + x, oy + y] = pal[ch]
    return im


def emblem():
    """처용탈: the red mask of 처용 (복두 hat with peony and peach, wide grin) — 22x22."""
    rows = [
        '......oooooooooo......',
        '....ookkkkkkkkkkoo....',
        '...okkkkpkkkkpkkkko...',
        '..okgGggggggggggGgko..',
        '..ooooooooooooooooo...',
        '..oRRRRRRRRRRRRRRRRo..',
        '.oRRrrRRRRRRRRRRrrRRo.',
        '.oRwwoRRRRRRRRRRowwRo.',
        '.oRwkoRRRRRRRRRRokwRo.',
        '.oRRooRRRRrrRRRRooRRo.',
        '.oRRRRRRRrRRrRRRRRRRo.',
        '.oRrRRRRRrRRrRRRRRrRo.',
        '.oRrRRRRrrRRrrRRRRrRo.',
        '..oRRwwwwwwwwwwwwRRo..',
        '..oRRowwowwowwowRRRo..',
        '...oRRoooooooooRRRo...',
        '...oRRRRRRRRRRRRRRo...',
        '....odRRRRRRRRRRdo....',
        '.....oddRRRRRRddo.....',
        '......ooddddddoo......',
        '........oooooo........',
        '......................',
    ]
    _grid(rows, MASK).save(OUT / 'emblem.png')


def gauge():
    """Brush-stroke gauge: frame (9-slice, 8px caps) + two fills drawn as ragged ink strokes."""
    W, H = 64, 10
    fr = Image.new('RGBA', (W, H), (0, 0, 0, 0))
    p = fr.load()
    for x in range(W):
        for y in range(H):
            edge = y in (0, H - 1) or x in (0, W - 1)
            if edge:
                p[x, y] = INK
            elif y in (1, H - 2) or x in (1, W - 2):
                p[x, y] = BRASS[1] if y != 1 else BRASS[2]
            else:
                p[x, y] = hx('#07070c', 230)
    fr.save(OUT / 'gauge_frame.png')
    rnd = random.Random(5)
    for name, ramp in (('gauge_hp', VERM), ('gauge_ki', JADE)):
        im = Image.new('RGBA', (W, 6), (0, 0, 0, 0))
        q = im.load()
        for x in range(W):
            for y in range(6):
                t = 3 if y == 1 else 4 if y == 0 else 2 if y < 4 else 1
                if rnd.random() < 0.12:
                    t -= 1  # dry-brush streaks
                q[x, y] = ramp[max(0, t)]
        im.save(OUT / f'{name}.png')


def button(name, icon_rows, icon_pal, size=40):
    """Round lacquer button: brass rim, pearl glints, an icon in the middle."""
    im = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    p = im.load()
    c = (size - 1) / 2
    for y in range(size):
        for x in range(size):
            d = ((x - c) ** 2 + (y - c) ** 2) ** 0.5
            if d > c:
                continue
            if d > c - 1:
                p[x, y] = INK
            elif d > c - 3:
                lit = (x + y) < size * 0.9
                p[x, y] = BRASS[3] if lit and d > c - 2 else BRASS[2] if lit else BRASS[1]
            elif d > c - 4:
                p[x, y] = INK
            else:
                p[x, y] = LACQ[(x * 3 + y) % 3][:3] + (215,)
    for (gx, gy) in ((int(c - c * 0.55), int(c - c * 0.6)), (int(c + c * 0.62), int(c + c * 0.5))):
        p[gx, gy] = PEARL[2]; p[gx + 1, gy] = PEARL[0]
    ih, iw = len(icon_rows), len(icon_rows[0])
    _grid(icon_rows, icon_pal, im, int(c - iw / 2 + 0.5), int(c - ih / 2 + 0.5))
    im.save(OUT / f'btn_{name}.png')


ICON_PAL = {'o': INK, 'w': CREAM, 'c': PEARL[3], 'C': PEARL[2], 'b': hx('#5a8ad8'), 'g': BRASS[2], 'G': BRASS[3],
            'y': BRASS[1], 'r': SEAL[2], 'R': SEAL[3], 'p': hx('#d8c89a'), 'P': hx('#efe2b8')}
ICON_ATTACK = [  # 대금 with a spirit-wind crescent
    '..............Cc',
    '............CCc.',
    '..........Ccc...',
    '.........cb.....',
    '........cb...oo.',
    '.......cb...oGo.',
    '......b....oGyo.',
    '..........oGyo..',
    '.........oGyo...',
    '........oGyo....',
    '.......oGyo.....',
    '......oGyo......',
    '.....oGyo.......',
    '....orRo........',
    '...orro.........',
    '....oo..........',
]
ICON_ROLL = [  # swirl of a dance step
    '.....cccccc.....',
    '...cc......cc...',
    '..c..CCCCC...c..',
    '.c..C.....C...c.',
    '.c.C..ccc..C..c.',
    'c..C.c...c.C...c',
    'c..C.c.C.c.C...c',
    'c..C.c..cc.C...c',
    '.c.C.c....C...c.',
    '.c..C.cccC....c.',
    '..c..CCCC....c..',
    '...cc......cc...',
    '.....cccccc.....',
    '................',
    '................',
    '................',
]
ICON_TALISMAN = [  # 부적: yellow paper with a red seal script
    '...oooooooooo...',
    '...oPPPPPPPPo...',
    '...oPprrrrpPo...',
    '...oPpppRppPo...',
    '...oPprrrrpPo...',
    '...oPppRpppPo...',
    '...oPprrRrpPo...',
    '...oPpppRppPo...',
    '...oPprRRrpPo...',
    '...oPppRpppPo...',
    '...oPpRrRppPo...',
    '...oPppRpppPo...',
    '...oPpppppPPo...',
    '...oPPPPPPPPo...',
    '...oooooooooo...',
    '................',
]
ICON_MENU = [
    '................',
    '..oooooooooooo..',
    '..oGGGGGGGGGGo..',
    '..oooooooooooo..',
    '................',
    '..oooooooooooo..',
    '..oGGGGGGGGGGo..',
    '..oooooooooooo..',
    '................',
    '..oooooooooooo..',
    '..oGGGGGGGGGGo..',
    '..oooooooooooo..',
    '................',
    '................',
    '................',
    '................',
]


ICON_SONG = [  # 처용가: the 대금 at the lips, notes rising
    '..........c.....',
    '.........cC..c..',
    '.........c..cC..',
    '.......ccc..c...',
    '.......CCc.cc...',
    '...........CC...',
    '................',
    '..oooooooooooo..',
    '.oGyGyGyGyGyGyo.',
    '.oGGGGGGGGGGGGo.',
    '..oooooooooooo..',
    '................',
    '..r.r.r.r.r.r...',
    '................',
    '................',
    '................',
]
ICON_TALK = [  # speech bubble with three dots
    '................',
    '...oooooooooo...',
    '..oPPPPPPPPPPo..',
    '.oPPPPPPPPPPPPo.',
    '.oPPoPPoPPoPPPo.',
    '.oPPPPPPPPPPPPo.',
    '..oPPPPPPPPPPo..',
    '...oooPPoooo....',
    '.....oPo........',
    '.....oo.........',
    '................',
    '................',
    '................',
    '................',
    '................',
    '................',
]


def glow_ring(size=56):
    """Pulsing pearl halo drawn behind the one button the player should press now."""
    im = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    p = im.load()
    c = (size - 1) / 2
    for y in range(size):
        for x in range(size):
            d = ((x - c) ** 2 + (y - c) ** 2) ** 0.5
            band = abs(d - (c - 3))
            if band < 1.0:
                p[x, y] = PEARL[2]
            elif band < 2.2:
                p[x, y] = PEARL[3][:3] + (170,)
            elif band < 3.6:
                p[x, y] = PEARL[0][:3] + (70,)
    im.save(OUT / 'glow_ring.png')


def stick():
    """Virtual joystick: brass ring base (translucent lacquer) and a pearl knob."""
    S = 56
    im = Image.new('RGBA', (S, S), (0, 0, 0, 0))
    p = im.load()
    c = (S - 1) / 2
    for y in range(S):
        for x in range(S):
            d = ((x - c) ** 2 + (y - c) ** 2) ** 0.5
            if d > c:
                continue
            if d > c - 1 or (c - 4 < d <= c - 3):
                p[x, y] = INK[:3] + (200,)
            elif d > c - 3:
                p[x, y] = (BRASS[2] if (x + y) < S else BRASS[1])[:3] + (220,)
            else:
                p[x, y] = (10, 10, 18, 110)
    im.save(OUT / 'stick_base.png')
    K = 22
    im = Image.new('RGBA', (K, K), (0, 0, 0, 0))
    p = im.load()
    c = (K - 1) / 2
    for y in range(K):
        for x in range(K):
            d = ((x - c) ** 2 + (y - c) ** 2) ** 0.5
            if d > c:
                continue
            if d > c - 1:
                p[x, y] = INK
            else:
                lit = (c - x) * 0.6 + (c - y) * 0.8
                p[x, y] = PEARL[2] if lit > 5 else PEARL[0] if lit > 0 else PEARL[3] if lit > -4 else hx('#4a7a90')
    im.save(OUT / 'stick_knob.png')


def hud():
    emblem(); gauge(); stick()
    button('attack', ICON_ATTACK, ICON_PAL, 44)
    button('roll', ICON_ROLL, ICON_PAL, 34)
    button('talisman', ICON_TALISMAN, ICON_PAL, 34)
    button('menu', ICON_MENU, ICON_PAL, 24)
    button('song', ICON_SONG, ICON_PAL, 34)
    button('talk', ICON_TALK, ICON_PAL, 44)
    glow_ring()


if __name__ == '__main__':
    OUT.mkdir(parents=True, exist_ok=True)
    panel(); seal(); knot(); hud()
    print('ui: panel, seal, knot, emblem, gauges, buttons, stick')
