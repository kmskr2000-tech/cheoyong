"""Enemy sprite sheets drawn with the props.py shading canvas (light from the upper left, auto ink).

plague_dog.png  side view facing right, 44x30 cells, feet on row 28:
                run0..run3, lunge (jaws open, stretched), hurt (recoil)
ghoul.png       front view, 30x42 cells, feet on row 40:
                walk0..walk3 (shambling bob), claw0 (arms raised), claw1 (raking down)
plague_god.png  역신 boss, 56x76 cells, hem bottom ~row 70: idle0..3 (float), cast, swipe, hurt, human (disguise)
Output: godot/assets/sprites/
"""
import importlib.util, math, pathlib
from PIL import Image

ROOT = pathlib.Path(__file__).parent
spec = importlib.util.spec_from_file_location('props', ROOT / 'props.py')
props = importlib.util.module_from_spec(spec); spec.loader.exec_module(props)
Canvas, R, GREEN = props.Canvas, props.R, props.GREEN
OUT = ROOT.parent / 'godot' / 'assets' / 'sprites'
TMP = ROOT / 'out' / 'enemy_frames'

FUR = R('#100c10', '#1c161a', '#2c2328', '#3e3236', '#54464a', '#6a5a5a')
FURD = R('#0a080a', '#141014', '#1e181c', '#2a2226', '#3a3034')
CORPSE = R('#141814', '#222a22', '#34402f', '#4a5841', '#62725a', '#7e8e74')
CORPSED = R('#0e110e', '#181e18', '#252e23', '#34402f', '#465440')
RAG = R('#0e0c10', '#1a161c', '#282230', '#3a3244')
BONE = props.hx('#d8d0b8')
EYE = props.hx('#d6ff7a')
MAW = props.hx('#3a0c14')


def limb(c, x0, y0, x1, y1, ramp, w=2, base=2.0):
    """A thin shaded limb: lit on the upper-left edge of the stroke."""
    n = max(1, int(max(abs(x1 - x0), abs(y1 - y0)) * 2))
    for i in range(n + 1):
        x = x0 + (x1 - x0) * i / n; y = y0 + (y1 - y0) * i / n
        for k in range(w):
            c.set(round(x) + k, round(y), c.ramp_at(ramp, base + (0.8 if k == 0 else -0.6)))


def sheet(name, frames, cell):
    TMP.mkdir(parents=True, exist_ok=True)
    props.OUT = TMP
    imgs = []
    for i, c in enumerate(frames):
        imgs.append(c.save(f'{name}_{i}'))
    out = Image.new('RGBA', (cell[0] * len(imgs), cell[1]), (0, 0, 0, 0))
    for i, im in enumerate(imgs):
        out.paste(im, (i * cell[0], 0))
    out.save(OUT / f'{name}.png')
    return out


# ---------------------------------------------------------------- 역병 들개
def dog(phase, pose='run'):
    W, H = 44, 30
    c = Canvas(W, H)
    G = 28  # ground row
    lunge = pose == 'lunge'; hurt = pose == 'hurt'
    sx = 3 if lunge else (-2 if hurt else 0)  # head / chest shift
    a = phase * math.pi / 2
    sw = (math.sin(a), math.sin(a + math.pi))  # leg swing for the two diagonal pairs
    if lunge:
        sw = (1.2, -1.2)
    def hind(x, swing, ramp, base):   # hip → hock (bent backward) → paw
        limb(c, x, 16, x - 3 + swing * 2, 22, ramp, 2, base)
        limb(c, x - 3 + swing * 2, 22, x - 1 + swing * 3, G - 1, ramp, 1, base)
        c.set(x - 1 + swing * 3, G - 1, ramp[1]); c.set(x + swing * 3, G - 1, ramp[1])

    def fore(x, swing, ramp, base):   # shoulder → elbow → paw, straight and thin
        limb(c, x, 18, x + swing, 23, ramp, 2, base)
        limb(c, x + swing, 23, x + swing * 2, G - 1, ramp, 1, base)
        c.set(x + swing * 2 + 1, G - 1, ramp[1])
    hind(14, -sw[1], FURD, 1.5)
    fore(30 + sx, sw[0], FURD, 1.5)
    # tail: ragged, held low
    for i in range(8):
        c.set(9 - i, 11 + i * 0.7 + math.sin(i + phase) * 0.6, FUR[2 if i < 5 else 1])
    # arched back, tucked-up belly, deep chest
    c.dome(13, 12, 5, 5, FUR, 2.4, top_only=False)
    c.dome(20 + sx * 0.4, 11, 7, 3.5, FUR, 2.3, top_only=False)
    c.dome(27 + sx, 13, 5.5, 6, FUR, 2.5, top_only=False)
    for rx in range(24, 30, 2):  # ribs on the chest
        for ry in range(12, 17):
            if c.get(rx + sx, ry):
                c.set(rx + sx, ry, FUR[1] if ry % 2 else FUR[2])
    for (gx, gy, r) in ((15, 8, 1.5), (21, 8.5, 1.3), (11, 10, 1.0)):  # plague sores on the back
        c.dome(gx, gy, r, r, GREEN, 2.6, top_only=False)
    # neck and wolfish head carried low and forward
    hx = 36 + sx; hy = 14 + (1 if hurt else 0)
    c.dome(hx - 4, hy - 1, 3.2, 3.5, FUR, 2.4, top_only=False)
    c.dome(hx, hy - 1, 4, 3.5, FUR, 2.6, top_only=False)
    for i in range(6):  # long snout tapering to the nose
        for j in range(3 - i // 3):
            c.set(hx + 3 + i, hy - 1 + j, c.ramp_at(FUR, 2.8 - j * 0.9))
    c.set(hx + 8, hy - 1, FUR[0])
    for (ex, ey) in ((hx - 2, hy - 5), (hx - 2, hy - 6), (hx - 1, hy - 5), (hx - 3, hy - 5), (hx, hy - 5), (hx, hy - 6), (hx + 1, hy - 5)):  # pricked ears
        c.set(ex, ey, FUR[3])
    c.set(hx + 1, hy - 2, EYE, outline=False); c.set(hx + 2, hy - 2, EYE, outline=False)
    if lunge:  # jaws wide open
        for x in range(hx + 2, hx + 9):
            c.set(x, hy + 1, MAW); c.set(x, hy + 2, MAW)
        for x in range(hx + 3, hx + 9, 2):
            c.set(x, hy, BONE); c.set(x, hy + 3, BONE)
    else:
        c.set(hx + 6, hy + 1, BONE); c.set(hx + 4, hy + 1, BONE)
    # near legs on top (lit)
    hind(12, sw[0], FUR, 2.6)
    fore(28 + sx, -sw[1], FUR, 2.6)
    if hurt:
        for y in range(H):
            for x in range(W):
                p = c.get(x, y)
                if p and p != EYE:
                    c.set(x, y, tuple(min(255, int(v * 1.5)) for v in p[:3]) + (255,))
    return c


# ---------------------------------------------------------------- 역귀 졸개
def ghoul(phase, pose='walk'):
    W, H = 30, 42
    c = Canvas(W, H)
    G = 40
    bob = (0, 1, 0, 1)[phase] if pose == 'walk' else 0
    step = (1, 0, -1, 0)[phase] if pose == 'walk' else 0
    raise_ = pose == 'claw0'; rake = pose == 'claw1'
    cx = 15
    # bent legs
    for s in (-1, 1):
        hip = (cx + s * 3, 27 + bob)
        knee = (cx + s * 6, 32 + bob)
        foot = (cx + s * 4 + (step * s), G - 1)
        limb(c, *hip, *knee, CORPSED if s > 0 else CORPSE, 2, 2.0)
        limb(c, *knee, *foot, CORPSED if s > 0 else CORPSE, 2, 2.0)
        c.set(foot[0] - 1, G - 1, CORPSE[2]); c.set(foot[0] + 2, G - 1, CORPSE[2])
    # torso hunched forward: wide shoulders, sunken belly with ribs
    c.dome(cx, 21 + bob, 5.5, 8, CORPSE, 2.2, top_only=False)
    c.dome(cx, 16 + bob, 7, 3, CORPSE, 2.6, top_only=False)  # bony shoulders
    for ry in range(17, 26, 2):
        for rx in range(cx - 4, cx + 5):
            if c.get(rx, ry + bob) and abs(rx - cx) > 1:
                c.set(rx, ry + bob, CORPSE[1])
    # tattered loincloth with a straw rope
    for x in range(cx - 5, cx + 6):
        c.set(x, 27 + bob, props.THATCH[3])
        for y in range(28, 32 + (x * 7) % 3):
            c.set(x, y + bob, RAG[2 if x < cx else 1])
    # head sunk between the shoulders, small horns, glowing eyes, slit mouth
    hy = 13 + bob  # head thrust forward, sunk below the shoulder line
    c.dome(cx, hy, 4, 4.5, CORPSE, 2.5, top_only=False)
    c.set(cx - 4, hy - 5, BONE); c.set(cx - 5, hy - 6, BONE)
    c.set(cx + 4, hy - 5, BONE); c.set(cx + 5, hy - 6, BONE)
    for x in range(cx - 3, cx + 4):
        c.set(x, hy - 1, CORPSE[0])
    c.set(cx - 2, hy, EYE, outline=False); c.set(cx + 2, hy, EYE, outline=False)
    for x in range(cx - 2, cx + 3):
        c.set(x, hy + 3, MAW)
    c.set(cx - 1, hy + 3, BONE); c.set(cx + 1, hy + 3, BONE)
    # long arms
    for s in (-1, 1):
        sh = (cx + s * 7, 16 + bob)
        if raise_:
            el = (cx + s * 10, 9); hand = (cx + s * 8, 2)
        elif rake:
            el = (cx + s * 10, 22); hand = (cx + s * 5, 37)
        else:
            sway = step * s
            el = (cx + s * 10, 25 + bob); hand = (cx + s * 10 + sway, 36 + bob)
        ramp = CORPSE if s < 0 else CORPSED
        limb(c, *sh, *el, ramp, 2, 2.2)
        limb(c, *el, *hand, ramp, 2, 2.2)
        for k in (-1, 0, 1):  # claws
            c.set(hand[0] + k + (1 if s > 0 else 0), hand[1] + (2 if not raise_ else -2), BONE)
    return c


# ---------------------------------------------------------------- 역신 (boss)
ROBE = R('#0e1210', '#1a201c', '#28322a', '#3a4638', '#4e5c4a', '#66765e')
HAIR = R('#06050a', '#0e0c14', '#18151f', '#24202e')
FACE = R('#5a5e66', '#8a8e96', '#b4b8bc', '#d6d8d8', '#eeeeea')
HUMAN_ROBE = R('#1c1a24', '#2c2a38', '#403e52', '#58566e', '#727090')


def plague_god(phase, pose='idle'):
    """A floating plague god, 1.5x a man: hair curtain over a pale mask face, rotting robe whose
    hem dissolves into miasma, sleeves ending in long claws."""
    W, H = 56, 76
    c = Canvas(W, H)
    cx = 28
    sway = math.sin(phase * math.pi / 2) * 1.2
    lift = (0, -1, -2, -1)[phase] if pose == 'idle' else -1
    human = pose == 'human'
    robe = HUMAN_ROBE if human else ROBE
    top = 10 + lift
    # robe: a tall bell, the hem ragged and dissolving
    for y in range(top + 16, 70 + lift):
        k = (y - top - 16) / 52
        half = 8 + k * 13
        for x in range(int(cx - half + sway * k), int(cx + half + sway * k) + 1):
            u = (x - (cx - half)) / (2 * half)
            t = 3.0 - u * 2.4 - k * 0.6 + (0.7 if (x // 3 + y // 7) % 4 == 0 else 0)
            if not human and y > 56 + lift and props.hashf(x, y + phase * 3, 77) < (y - 56 - lift) / 16:
                continue  # hem eaten away
            c.set(x, y, c.ramp_at(robe, t))
    if not human:  # rot stains and sores on the robe
        for (gx, gy, r) in ((cx - 6, 44, 2.5), (cx + 7, 52, 2.0), (cx - 2, 60, 1.6)):
            c.dome(gx, gy + lift, r, r * 1.2, GREEN, 2.2, top_only=False)
    # sleeves and claws
    for s in (-1, 1):
        if pose == 'cast':
            el = (cx + s * 18, top + 18); hand = (cx + s * 24, top + 8)
        elif pose == 'swipe':
            el = (cx + s * 16, top + 28); hand = (cx + s * (6 if s < 0 else 26), top + 40)
        else:
            el = (cx + s * 13, top + 30); hand = (cx + s * 15, top + 42 + (phase % 2))
        sh = (cx + s * 8, top + 18)
        for i in range(12):  # wide sleeve tapering to the wrist
            t = i / 11
            x = sh[0] + (el[0] - sh[0]) * t; y = sh[1] + (el[1] - sh[1]) * t
            r = 4.5 - t * 1.5
            c.dome(x, y, r, r, robe, 2.0 if s < 0 else 1.4, top_only=False)
        if not human:
            for k in (-2, 0, 2):  # long claws
                limb(c, el[0], el[1], hand[0] + k, hand[1], FACE, 1, 3.0 if s < 0 else 2.0)
        else:
            c.dome(el[0], el[1] + 2, 2, 2, R('#8a6656', '#b08670', '#d0a88c'), 1.5, top_only=False)
    # head: long pale face, half hidden by a curtain of black hair
    hy = top + 8
    c.dome(cx + sway, hy, 5.5, 7, FACE, 2.6, top_only=False)
    if human:  # the disguise: a scholar's face under a 복두, a thin crooked smile
        for x in range(int(cx - 7), int(cx + 8)):
            c.set(x, hy - 7, HAIR[2]); c.set(x, hy - 6, HAIR[1])
        for x in range(int(cx - 13), int(cx + 14)):
            c.set(x, hy - 5, HAIR[1])
        c.set(cx - 2, hy, HAIR[0]); c.set(cx + 2, hy, HAIR[0])
        for x in range(int(cx - 1), int(cx + 3)):
            c.set(x, hy + 4, R('#5a2a2a')[0])
    else:
        for y in range(hy - 9, hy + 26):  # hair curtain falling past the shoulders
            for x in range(int(cx - 8 + sway), int(cx + 9 + sway)):
                gap = abs(x - (cx + sway + 1)) < 3 - max(0, (y - hy - 2) * 0.25) and y > hy - 3
                if gap or (y > hy + 6 and abs(x - cx) < 6 and (x * 5 + y) % 7 < 3):
                    continue
                c.set(x, y, HAIR[1 + ((x + y // 3) % 3 == 0)])
        c.set(cx - 1 + sway, hy, EYE, outline=False); c.set(cx + 2 + sway, hy, EYE, outline=False)
        for x in range(int(cx - 1 + sway), int(cx + 3 + sway)):  # gaping dark mouth
            c.set(x, hy + 4, MAW); c.set(x, hy + 5, MAW)
    if pose == 'hurt':
        for y in range(H):
            for x in range(W):
                p = c.get(x, y)
                if p and p != EYE:
                    c.set(x, y, tuple(min(255, int(v * 1.6)) for v in p[:3]) + (255,))
    return c


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    sheet('plague_dog', [dog(i) for i in range(4)] + [dog(1, 'lunge'), dog(0, 'hurt')], (44, 30))
    sheet('ghoul', [ghoul(i) for i in range(4)] + [ghoul(0, 'claw0'), ghoul(0, 'claw1')], (30, 42))
    sheet('plague_god', [plague_god(i) for i in range(4)] + [plague_god(0, p) for p in ('cast', 'swipe', 'hurt', 'human')], (56, 76))
    print('enemies: plague_dog (run0-3, lunge, hurt), ghoul (walk0-3, claw0, claw1), plague_god (idle0-3, cast, swipe, hurt, human)')


if __name__ == '__main__':
    main()
