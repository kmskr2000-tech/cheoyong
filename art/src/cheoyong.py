# 처용 — 퇴마사 재해석: 검푸른 철릭(주름치마), 붉은 댕기·안감·허리띠, 청록 용비늘 숄, 등에 멘 대금,
# 팔목 토시와 목 긴 신. 32x48 cells, feet (bottom outline) on row 44. Light from the upper left.
PALETTE = {
    'o': '#0d0a12', 'k': '#08060c',
    '1': '#4a2a2e', '2': '#8a5a52', '3': '#c08a72', '4': '#e6b896',
    'h': '#0e0c16', 'i': '#1e1a2c', 'j': '#34304c', 'J': '#5a5a82',
    'd': '#0d0e1c', 'e': '#171930', 'f': '#232848', 'g': '#363e66', 'G': '#56608e',
    'r': '#3a0c14', 'R': '#6a1620', 'q': '#a02a2a', 'Q': '#d04838',
    't': '#0b272b', 'T': '#134046', 'u': '#1f6266', 'U': '#3a9088',
    'y': '#6a4a1c', 'Y': '#b88a32', 'Z': '#f0cc6a',
    'b': '#120e16', 'B': '#2a2234',
    'w': '#d8d2c0', 'W': '#8e8a96',
    'p': '#5a4420', 'P': '#a08640',
}

DOWN = [
    '................................',
    '...............oo...............',
    '..............ojJo..............',
    '..............oiho..............',
    '.............oQqRroRRo..........',
    '............ojJjiiho.Rro........',
    '...........ojJjiiiiho..ro.......',
    '..........ojiiihhiihho..ro......',
    '..........oih4433332ho..ro......',
    '...........o3kk33kk2o...........',
    '...........o3wk33kW2o...........',
    '.......o...o33332322o...........',
    '......oPo..o43332321o...........',
    '......oPpo..o331122o............',
    '.......oPo...o3221o.............',
    '.......opo....o21o..............',
    '........ooooowQqqRwooooo........',
    '.......oGgfffwqRRwuUuTTo........',
    '......oGggfffwRRwuUuTTTto.......',
    '......oGgffffwRwuUuTTTtdo.......',
    '......oGgfffffwuUuTTtTtddo......',
    '.....oGgofffwuUuTTteddoedo......',
    '.....oGgoffwuUuTTteeddoedo......',
    '.....oGgoQQqRYZYRRRrrroedo......',
    '.....oGgoqqRRyYyRrrrrroedo......',
    '.....owWogfegfYfedfdedoWwo......',
    '.....owWogfegfyfedfdedoWwo......',
    '.....o43ogfegfefedfdedo32o......',
    '......ooogfegfYfedfdedooo.......',
    '........ogfegfegfedfdddo........',
    '.......ogfegfegfedfdeddo........',
    '.......ogfegfegfeedfdeddo.......',
    '......ogfegfegfefedfdeddo.......',
    '......ogfegfegfefedfdedddo......',
    '......ogfegfegfefedfdedddo......',
    '.....ogfegfegfefefedfdeddo......',
    '.....ogfegfegfefefedfdedddo.....',
    '.....oQqQqQqqRqRRrRrRrrrrro.....',
    '.....oooooooooooooooooooooo.....',
    '..........oBBbo..oBbbo..........',
    '..........oBBbo..oBbbo..........',
    '..........oYyyo..oYyyo..........',
    '..........oBBbo..oBbbo..........',
    '.........oBBBbo..oBbbbo.........',
    '.........oooooo..oooooo.........',
    '................................',
    '................................',
    '................................',
]
UP = [
    '................................',
    '...............oo...............',
    '..............ojJo..............',
    '..............oiho..............',
    '.............oQqRroRRo..........',
    '............ojJjiiho.Rro........',
    '...........ojJjiiiiho..ro.......',
    '..........ojiiihhiihho..ro......',
    '..........oiiihhhhihho..ro......',
    '...........oihhhhhhho...........',
    '...........oihhhhhhho...........',
    '...........o2hhhhhh1o.ooo.......',
    '...........o3hhhhhh1o.oPo.......',
    '............o32hh21o...Po.......',
    '.............o3221o..oPo........',
    '..............o21o...oPo........',
    '........oooooooooooooPoo........',
    '.......oUuTTffffffffPpeo........',
    '......oUuTTtfffffffPpeedo.......',
    '......oUuTtfffffffPpeeedo.......',
    '......oGuTtffffffPpffeeddo......',
    '.....oGgofffffffPpfeddoedo......',
    '.....oGgoffffffPpffeddoedo......',
    '.....oGgoQQqRRPpRRRrrroedo......',
    '.....oGgoqqRRPpRRrrrrroedo......',
    '.....owWogfePpYfedfdedoWwo......',
    '.....owWogfepfyfedfdedoWwo......',
    '.....o43ogfegfefedfdedo32o......',
    '......ooogfegfYfedfdedooo.......',
    '........ogfegfegfedfdddo........',
    '.......ogfegfegfedfdeddo........',
    '.......ogfegfegfeedfdeddo.......',
    '......ogfegfegfefedfdeddo.......',
    '......ogfegfegfefedfdedddo......',
    '......ogfegfegfefedfdedddo......',
    '.....ogfegfegfefefedfdeddo......',
    '.....ogfegfegfefefedfdedddo.....',
    '.....oQqQqQqqRqRRrRrRrrrrro.....',
    '.....oooooooooooooooooooooo.....',
    '..........oBBbo..oBbbo..........',
    '..........oBBbo..oBbbo..........',
    '..........oYyyo..oYyyo..........',
    '..........oBBbo..oBbbo..........',
    '.........oBBBbo..oBbbbo.........',
    '.........oooooo..oooooo.........',
    '................................',
    '................................',
    '................................',
]
SIDE = [
    '................................',
    '..............oo................',
    '.............ojJo...............',
    '.............oiho...............',
    '.........oRRoQqRro..............',
    '.......orRo.ojJjiiho............',
    '......oro..ojJjiiiiho...........',
    '......o...ojiiihh443o...........',
    '..........oiiihh4433o...........',
    '..........oihh233kk33o..........',
    '..........oihh1233k33o..........',
    '......o...oihh23333333o.........',
    '.....oPo..oihh3333332o..........',
    '.....oPpo..oih333312o...........',
    '......oPo...oh33332o............',
    '......opo....oh221o.............',
    '.........ooooowRooo.............',
    '........oGgfffwqRuUo............',
    '........oGgffffwRuUuo...........',
    '........oGgfffffwuUuTo..........',
    '........oGgofgfouUuTo...........',
    '........oGgofgfotTuTo...........',
    '........oGgogffotTTdo...........',
    '........oQqoggfoRrrro...........',
    '........oqRoggfoRYrro...........',
    '........ofeowWWoeYfdo...........',
    '........ofeowWWofyddo...........',
    '........ogfeo43ofeddo...........',
    '........ogfefoofedddo...........',
    '........ogfegfegfeddo...........',
    '.......ogfegfegfedddo...........',
    '.......ogfegfegfefdddo..........',
    '......ogfegfegfefedddo..........',
    '......ogfegfegfefefdddo.........',
    '......ogfegfegfefefdddo.........',
    '.....ogfegfegfefefedddo.........',
    '.....ogfegfegfefefefdddo........',
    '.....oQqQqQqqRqRRrRrrrro........',
    '.....ooooooooooooooooooo........',
    '.........oBbo.oBBbo.............',
    '.........oBbo.oBBbo.............',
    '.........oYyo.oYYyo.............',
    '.........oBbo.oBBbo.............',
    '........oBBbo.oBBBBBo...........',
    '........ooooo.ooooooo...........',
    '................................',
    '................................',
    '................................',
]

EMPTY = '.' * 32
LEGS = range(39, 45)  # boots/legs rows; the hem sits right above
HEM = range(35, 39)


def shift_x(r, d):
    return ('.' * d + r[:len(r) - d]) if d > 0 else (r[-d:] + '.' * -d) if d < 0 else r


def move_cols(rows, x0, x1, dx, dy):
    """Move the pixels of columns x0..x1 within the leg rows by (dx, dy)."""
    out = list(rows)
    patch = {}
    for y in LEGS:
        for x in range(x0, x1 + 1):
            if rows[y][x] != '.':
                patch[(x + dx, y + dy)] = rows[y][x]
            out[y] = out[y][:x] + '.' + out[y][x + 1:]
    for (x, y), c in patch.items():
        if 0 <= y < len(out):
            out[y] = out[y][:x] + c + out[y][x + 1:]
    return out


def walk(idle, legs_a, legs_b):
    """contact A, passing (body up 1px), contact B, passing. legs_* = list of (x0, x1, dx, dy)."""
    frames = []
    for legs, sway in ((legs_a, 1), (None, 0), (legs_b, -1), (None, 0)):
        f = list(idle)
        if legs is None:
            f = f[1:] + [EMPTY]
        else:
            for (x0, x1, dx, dy) in legs:
                f = move_cols(f, x0, x1, dx, dy)
            for i in HEM:
                f[i] = shift_x(f[i], sway)
        frames.append(f)
    return frames


FB_A = [(9, 15, 0, 1), (16, 23, 0, -1)]
FB_B = [(9, 15, 0, -1), (16, 23, 0, 1)]
SIDE_A = [(8, 13, -2, 0), (14, 21, 2, 0)]
SIDE_B = [(8, 13, 1, 0), (14, 21, -2, 0)]

FRAMES = {'down_idle': DOWN, 'up_idle': UP, 'right_idle': SIDE}
for name, base, a, b in (('down', DOWN, FB_A, FB_B), ('up', UP, FB_A, FB_B), ('right', SIDE, SIDE_A, SIDE_B)):
    for i, f in enumerate(walk(base, a, b)):
        FRAMES[f'{name}_walk{i}'] = f


# ---------------------------------------------------------------- combat: body without the weapon arm
# The weapon arm (sleeve + 토시 + hand + 대금) is a separate part (cheoyong_arm.py) that Godot swings
# around the shoulder, cut-out style. Here the arm is removed from each facing.
def _erase(rows, x0, x1, y0, y1, fill=None):
    out = list(rows)
    for y in range(y0, y1 + 1):
        r = out[y]
        for x in range(x0, x1 + 1):
            c = '.' if fill is None else fill(x, y)
            r = r[:x] + c + r[x + 1:]
        out[y] = r
    return out


def _coat(x, y):
    return 'gfe'[(x + y) % 3] if x < 18 else 'ed'[(x + y) % 2]


DOWN_ARMLESS = _erase(DOWN, 4, 8, 21, 28)
DOWN_ARMLESS = _erase(DOWN_ARMLESS, 9, 9, 21, 28, lambda x, y: 'o')
UP_ARMLESS = _erase(UP, 22, 26, 21, 28)
UP_ARMLESS = _erase(UP_ARMLESS, 22, 22, 21, 28, lambda x, y: 'o')
SIDE_ARMLESS = _erase(SIDE, 11, 15, 20, 28, _coat)  # the near arm hid the torso: paint coat back in

FRAMES['down_attack'] = DOWN_ARMLESS
FRAMES['up_attack'] = UP_ARMLESS
FRAMES['right_attack'] = SIDE_ARMLESS


# in attack poses the 대금 is in hand, so it leaves the back
def _no_flute(rows, coat_fill):
    out = []
    for y, r in enumerate(rows):
        s = ''
        for x, c in enumerate(r):
            if c in 'Pp':
                s += coat_fill(x, y) if 16 <= y <= 30 else '.'
            elif c == 'o' and 10 <= y <= 15 and (x <= 9 or x >= 21):
                s += '.'  # outline that only belonged to the flute tip
            else:
                s += c
        out.append(s)
    return out


FRAMES['down_attack'] = _no_flute(DOWN_ARMLESS, _coat)
FRAMES['up_attack'] = _no_flute(UP_ARMLESS, _coat)
FRAMES['right_attack'] = _no_flute(SIDE_ARMLESS, _coat)
