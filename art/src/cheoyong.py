# 처용 — 복두(幞頭) + 남색 단령 + 금빛 요대. 32x48 cells, feet on row 45.
# Light comes from the upper left; shadows shift toward violet, highlights toward warm.
PALETTE = {
    'o': '#120e1a',  # outline (violet-black)
    'k': '#0a0810',  # eyes / brows
    '1': '#5a3436', '2': '#9a6658', '3': '#c99878', '4': '#ecc6a2',  # skin
    'a': '#14121c', 'b': '#26243a', 'c': '#45436a',  # 복두 black silk
    'd': '#121a36', 'e': '#1d2a58', 'f': '#2c4180', 'g': '#4862a8',  # robe navy
    'w': '#e2dacb', 'W': '#9c92a6',  # inner collar
    'y': '#7a5220', 'Y': '#c8902e', 'Z': '#f2d27a',  # gold belt
    'R': '#8e3038', 'r': '#5a1c28',  # hem / cuff trim
    'S': '#4a3430', 's': '#2a1e1e',  # shoes
}

DOWN = [
    '................................',
    '.............oooooo.............',
    '............occcbbbo............',
    '...........ocbbbbbbbo...........',
    '...........obbbbbbbao...........',
    '..........oobbbbbbbaoo..........',
    '..........ocbbbbbbbbao..........',
    '.oooooooooaaaaaaaaaaaaooooooooo.',
    '.ocbbbbbbboaaaaaaaaaaobbbbbbbco.',
    '.ooooooooooa34443333aoooooooooo.',
    '...........o3kk33kk2o...........',
    '...........o3Wk33kW2o...........',
    '...........o43332322o...........',
    '...........o33322321o...........',
    '............o311122o............',
    '.............o3322o.............',
    '.............o1221o.............',
    '........oooofw1111weoooo........',
    '.......ogggffWwwwwWeeeedo.......',
    '......ogggfffeeeeeefeeeddo......',
    '......ogggffffffffdeeeeedo......',
    '......ogggfffffffffdeeeedo......',
    '.....ogffogfffffffffdeoeddo.....',
    '.....ogffogffffffffffdoeddo.....',
    '.....ogffogfffffffffeeoeddo.....',
    '....oggffogfffffffffeeoeeddo....',
    '....oggffoYZYYYZZYYYYyoeeddo....',
    '....oggffoyYyyyYYyyyyyoeeddo....',
    '....oggffogfgeffffdeedoeeddo....',
    '...ogggffogfgeffffdeedoeedddo...',
    '...oggffeogfgeffffdeedoeedddo...',
    '...oRRRRRogfgeffffdeedoRrrrro...',
    '....o43oogffgefffffdeedoo32o....',
    '.....oo.ogffgefffffdeedo.oo.....',
    '........ogffgefffffdeedo........',
    '.......ogfffgeffffffdeedo.......',
    '.......ogfffgeffffffdeedo.......',
    '.......ogfffgeffffffdeedo.......',
    '......ogffffgefffffffdeedo......',
    '......ogffffgefffffffdeedo......',
    '......ogffffgefffffffdeedo......',
    '.....ogfffffgeffffffffdeedo.....',
    '.....oRRRRRRRRRRRRRRRRrrrro.....',
    '.....oooooooooooooooooooooo.....',
    '.........oSSso....oSsso.........',
    '.........ooooo....ooooo.........',
    '................................',
    '................................',
]
UP = [
    '................................',
    '.............oooooo.............',
    '............occcbbbo............',
    '...........ocbbbbbbbo...........',
    '...........obbbbbbbao...........',
    '..........oobbbbbbbaoo..........',
    '..........ocbbbbbbbbao..........',
    '.oooooooooaaaaaaaaaaaaooooooooo.',
    '.ocbbbbbbboaaaaaaaaaaobbbbbbbco.',
    '.ooooooooooaaaaaaaaaaoooooooooo.',
    '...........oaaaaaaaao...........',
    '...........o2aaaaaa2o...........',
    '...........o32aaaa22o...........',
    '...........o33222211o...........',
    '............o322211o............',
    '.............o3221o.............',
    '.............o2211o.............',
    '........ooooffffffffoooo........',
    '.......ogggfffffffffeeedo.......',
    '......ogggffffffffeeeeeddo......',
    '......ogggffffffffeeeeeddo......',
    '......ogggffffffffeeeeeddo......',
    '.....ogffogffffeffffeeoeddo.....',
    '.....ogffogffffeffffeeoeddo.....',
    '.....ogffogffffeffffeeoeddo.....',
    '....oggffogffffeffffeeoeeddo....',
    '....oggffoYYYYYYYYYYYyoeeddo....',
    '....oggffoyyyyyyyyyyyyoeeddo....',
    '....oggffogfgeffffdeedoeeddo....',
    '...ogggffogfgeffffdeedoeedddo...',
    '...oggffeogfgeffffdeedoeedddo...',
    '...oRRRRRogfgeffffdeedoRrrrro...',
    '....o43oogffgefffffdeedoo32o....',
    '.....oo.ogffgefffffdeedo.oo.....',
    '........ogffgefffffdeedo........',
    '.......ogfffgeffffffdeedo.......',
    '.......ogfffgeffffffdeedo.......',
    '.......ogfffgeffffffdeedo.......',
    '......ogffffgefffffffdeedo......',
    '......ogffffgefffffffdeedo......',
    '......ogffffgefffffffdeedo......',
    '.....ogfffffgeffffffffdeedo.....',
    '.....oRRRRRRRRRRRRRRRRrrrro.....',
    '.....oooooooooooooooooooooo.....',
    '.........oSSso....oSsso.........',
    '.........ooooo....ooooo.........',
    '................................',
    '................................',
]
SIDE = [
    '................................',
    '..............ooooo.............',
    '.............occbbbo............',
    '...........oocbbbbbbo...........',
    '..........obbbbbbbbbo...........',
    '..........obbbbbbbbbao..........',
    '..........obbbbbbbbbao..........',
    '.......ooooaaaaaaaaaao..........',
    '.......ocbbaaaaaaaaaao..........',
    '.......ooooaa3444333o...........',
    '..........oaa3333kk3o...........',
    '..........oa213333k3o...........',
    '..........oa223333333o..........',
    '...........oa3333332o...........',
    '...........oa333331o............',
    '...........o233332o.............',
    '............o1221o..............',
    '..........ooooffwWoo............',
    '.........ogggfffwWeeo...........',
    '.........ogggffffeeedo..........',
    '.........oggogffffoedo..........',
    '.........oggogffffoedo..........',
    '.........ofgogffffoedo..........',
    '.........ofgogfffffoedo.........',
    '.........ofgogfffffoedo.........',
    '.........ofgogfffffoeeo.........',
    '.........oYYogfffffoYyo.........',
    '.........oyyogfffffoyyo.........',
    '.........ofgogfffffoedo.........',
    '.........ofgogffffffoedo........',
    '.........ofgogffffffoedo........',
    '.........ofgoRRRRRrroedo........',
    '.........ofgffo43oeedo..........',
    '.........ofgfffooffeddo.........',
    '........ofgfffffffeeddo.........',
    '.......ofgffffgefffeeddo........',
    '.......ofgffffgefffeeddo........',
    '.......ofgffffgefffeeddo........',
    '.......ofgfffffgeffffeddo.......',
    '.......ofgfffffgeffffeddo.......',
    '.......ofgfffffgeffffeddo.......',
    '......ofgffffffgefffffeddo......',
    '......oRRRRRRRRRRRRRRrrrro......',
    '......oooooooooooooooooooo......',
    '..........osSSo..oSSSSSo........',
    '..........ooooo..ooooooo........',
    '................................',
    '................................',
]

EMPTY = '.' * 32


def shift_x(r, d):
    return ('.' * d + r[:len(r) - d]) if d > 0 else (r[-d:] + '.' * -d) if d < 0 else r


def walk(idle, feet):
    """4-frame walk from an idle frame: contact, pass (body up 1px), other contact, pass.
    feet = (contactA_rows, contactB_rows) replacing rows 43.. of the idle frame; hem rows sway with the step."""
    hem = range(38, 44)
    out = []
    for k, (fr, sway) in enumerate([(feet[0], 1), (None, 0), (feet[1], -1), (None, 0)]):
        f = list(idle)
        if fr is None:  # passing pose: whole body rises a pixel
            f = f[1:] + [EMPTY]
        else:
            for i in hem: f[i] = shift_x(f[i], sway)
            f[44:44 + len(fr)] = fr
        out.append(f)
    return out


FEET_FB = (
    ['.........oSSso.....oooo.........', '.........oSSso..................', '.........ooooo..................'],
    ['.........oooo.....oSsso.........', '..................oSsso.........', '..................ooooo.........'],
)
FEET_SIDE = (
    ['........osSo.......oSSSSSo......', '........ooo........ooooooo......'],
    ['.........oSSSSo..osso...........', '.........oooooo..oooo...........'],
)

FRAMES = {'down_idle': DOWN, 'up_idle': UP, 'right_idle': SIDE}
for name, base, feet in (('down', DOWN, FEET_FB), ('up', UP, FEET_FB), ('right', SIDE, FEET_SIDE)):
    for i, f in enumerate(walk(base, feet)):
        FRAMES[f'{name}_walk{i}'] = f
