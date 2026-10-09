"""한국 설화 요괴 — 챕터별 일반 몹·정예 스프라이트 (enemies.py와 같은 셰이딩 캔버스: 빛은 왼쪽 위, 잉크 외곽선 자동).

Every sheet uses the same 7-frame layout so Enemy KINDS can share it:
    move0..move3 (idle / walk / float cycle), tell (예고 동작), strike (공격), hurt (피격·쓰러짐)
Projectiles and extras get their own small sheets (e.g. mama_boil).
Output: godot/assets/sprites/<name>.png  +  art/out/monsters_preview.png (contact sheet per chapter)
"""
import importlib.util, math, pathlib
from PIL import Image

ROOT = pathlib.Path(__file__).parent
spec = importlib.util.spec_from_file_location('enemies', ROOT / 'enemies.py')
en = importlib.util.module_from_spec(spec); spec.loader.exec_module(en)
props = en.props
Canvas, R, hx, limb, sheet = props.Canvas, props.R, props.hx, en.limb, en.sheet
INK = props.INK
POSES = ['move', 'move', 'move', 'move', 'tell', 'strike', 'hurt']

# ---------------------------------------------------------------- shared palettes
SOBOK = R('#2e323e', '#4a4e5c', '#6a6e7e', '#8e92a2', '#b4b8c6', '#d6dae2')   # 소복 (mourning white, cold)
HAIR = R('#040308', '#0a0810', '#13101a', '#1e1a28')
PALE = R('#3e4454', '#62687a', '#8a90a0', '#b2b8c4', '#d4d8e0')                # dead skin
HONG = R('#24060a', '#480e14', '#741a1c', '#9c2824', '#c03a2e')                # 홍포 red cloth
BOIL = R('#4a1e0c', '#8e4416', '#d0782a', '#f4b448', '#fff0a0')
BONE, EYE = en.BONE, en.EYE
GHOSTEYE = hx('#c8f0ff')
BLOOD = hx('#5a0a12')


def robe(c, cx, top, bottom, wt, wb, ramp, sway=0, ragged=True, base=2.4):
    """A hanging robe/skirt: trapezoid lit from the left, vertical folds, ragged ghost hem."""
    for y in range(top, bottom):
        t = (y - top) / max(1, bottom - top - 1)
        hw = wt + (wb - wt) * t
        off = round(sway * t * t)
        for x in range(int(cx - hw), int(cx + hw) + 1):
            u = (x - (cx - hw)) / max(1, 2 * hw)
            fold = 0.5 * math.sin((x - cx) * 0.9 + t * 2) if t > 0.2 else 0
            if ragged and y >= bottom - 4 and ((x * 7 + y * 3) % 5 < (y - (bottom - 4))):
                continue
            c.set(x + off, y, c.ramp_at(ramp, base + 1.3 - u * 2.4 + fold - t * 0.4))


def hair_curtain(c, cx, top, bottom, hw, sway=0, part=0):
    """Long black hair falling over the face and shoulders; part = gap width in the middle."""
    for x in range(int(cx - hw), int(cx + hw) + 1):
        if part and abs(x - cx) < part:
            continue
        end = bottom - (abs(x - cx) * 3 + x * 7) % 4
        for y in range(top + abs(x - cx) // 3, end):
            t = (y - top) / max(1, bottom - top)
            c.set(x + round(sway * t * t), y, c.ramp_at(HAIR, 2.4 - abs(x - cx) * 0.12 - t * 0.6 + (0.9 if (x + 1) % 4 == 0 else 0)))


def sheet7(name, fn, cell):
    frames = [fn(i, 'move') for i in range(4)] + [fn(0, p) for p in ('tell', 'strike', 'hurt')]
    return sheet(name, frames, cell)


# ================================================================ 1장 경주 역병
# 마마귀신 (호구별성): 천연두를 몰고 다니는 '손님'. 앞으로 굽은 부푼 몸에 해진 홍포, 종기로 울퉁불퉁한 머리,
#   찌그러진 갓, 한쪽 눈은 부어 감기고 다른 눈은 노랗게 튀어나왔다. 정예 — 예고: 종기가 달아오른다 → 종기를 던짐.
POX = R('#2a1a18', '#4a2e28', '#6e4838', '#94664c', '#b88a66', '#d4ac84')
HONGD = R('#14030a', '#2c0610', '#4a0e16', '#6a181c', '#8c2622', '#b0382c')


def boil(c, x, y, hot=False):
    c.set(x, y, BOIL[4] if hot else BOIL[3], outline=False)
    c.set(x + 1, y, BOIL[2]); c.set(x, y + 1, BOIL[1]); c.set(x + 1, y + 1, POX[0])


def mama(phase, pose):
    W, H = 48, 58
    c = Canvas(W, H)
    bob = (0, -1, -2, -1)[phase] if pose == 'move' else 0
    tell, strike, hurt = pose == 'tell', pose == 'strike', pose == 'hurt'
    cx = 24 + (2 if hurt else 0)
    by = 16 + bob + (3 if hurt else 0)
    sway = (-1, 0, 1, 0)[phase] if pose == 'move' else 0
    # the hump of the back rising above the head, and a long tattered robe trailing to the ground
    robe(c, cx + 2, by + 6, 55 + bob, 12, 19, HONGD, sway=sway, base=2.3)
    c.dome(cx + 3, by + 6, 13, 10, HONGD, 2.5, top_only=False)
    for (dx, dy) in ((-6, 2), (7, 0), (2, 8), (11, 6), (-9, 12), (9, 16), (-3, 22), (6, 28)):
        boil(c, cx + 3 + dx, by + dy, tell)
    for y in range(by + 14, 54 + bob, 3):                      # dark stains running down the cloth
        c.set(cx - 4 + (y % 5), y, HONGD[0]); c.set(cx + 8 - (y % 4), y + 1, HONGD[1])
    # head thrust forward and down: a lumpy skull of three swellings
    hx_, hy = cx - 5, by + 9
    c.dome(hx_, hy, 8, 7.5, POX, 2.6, top_only=False)
    c.dome(hx_ - 5, hy - 3, 4, 4, POX, 3.0, top_only=False)
    c.dome(hx_ + 4, hy + 4, 4.5, 4, POX, 2.4, top_only=False)
    for (dx, dy) in ((-6, -4), (-2, -6), (3, -5), (6, -1), (-8, 1), (5, 5), (-4, 6), (1, 2), (7, 3), (-1, -2)):
        boil(c, hx_ + dx, hy + dy, tell)
    # eyes: left swollen shut, right bulging yellow ringed with red
    for x in range(hx_ - 5, hx_ - 2):
        c.set(x, hy, INK)
    c.set(hx_ + 2, hy - 1, BLOOD); c.set(hx_ + 3, hy - 1, EYE, outline=False); c.set(hx_ + 3, hy, EYE, outline=False); c.set(hx_ + 4, hy, BLOOD)
    # mouth: slack and drooling; on the strike it gapes and spits
    my = hy + 4
    mw = 4 if strike else 2
    for x in range(hx_ - mw, hx_ + mw):
        c.set(x, my, INK)
        if strike:
            c.set(x, my + 1, BLOOD); c.set(x, my + 2, INK)
    c.set(hx_ - 1, my + 1 + (2 if strike else 0), BOIL[2]); c.set(hx_ - 1, my + 2 + (2 if strike else 0), BOIL[1])
    # crushed 갓 slipping off the side of the head
    for x in range(hx_ - 12, hx_ + 6):
        c.set(x, hy - 9 + (x - hx_) // 6, INK if (x * 3) % 7 else HAIR[2])
    for y in range(hy - 14, hy - 9):
        for x in range(hx_ - 6, hx_ + 1 - (y - hy + 14) // 2):
            c.set(x, y, HAIR[1] if x > hx_ - 5 else HAIR[2])
    # thin long arms out of the sleeves, hooked fingers; tell holds a glowing boil up, strike flings it
    for s in (-1, 1):
        sh = (cx + s * 9, by + 14)
        if strike and s < 0:
            el, hand = (cx - 14, by + 6), (cx - 22, by + 2)
        elif tell and s < 0:
            el, hand = (cx - 13, by + 10), (cx - 15, by + 2)
        else:
            el, hand = (cx + s * 14, by + 24), (cx + s * 15 + sway, by + 34)
        limb(c, *sh, *el, POX, 2, 2.0)
        limb(c, *el, *hand, POX, 2, 1.8)
        for k in (-1, 0, 1):
            c.set(hand[0] + k, hand[1] + 2, POX[4]); c.set(hand[0] + k, hand[1] + 3, INK)
        if tell and s < 0:
            c.dome(hand[0], hand[1] - 3, 3, 3, BOIL, 3.2, top_only=False)
    return c


def mama_boil(phase):
    """종기 투사체: a glowing pus-bulb, pulsing."""
    c = Canvas(10, 10)
    r = 3.5 + (phase % 2) * 0.6
    c.dome(5, 5, r, r, BOIL, 2.8, top_only=False)
    c.set(4, 3, BOIL[4], outline=False)
    return c


# 달걀귀신: 얼굴이 없는 귀신 — 지나치게 긴 목 위에 매끈한 알 머리, 얼룩진 소복, 무릎까지 늘어진 손가락.
#   은신형 — 어둠에서 나타나 덮친다. 예고: 매끈한 얼굴에 세로 금이 가며 입이 갈라진다.
EGG = R('#4a4e58', '#7a7e88', '#a6a8b0', '#cccdd2', '#e6e6e8', '#fafafa')
SOBOKD = R('#1a1c24', '#2c2f3a', '#424654', '#5c6070', '#7a7e8e', '#9a9eac')


def egg(phase, pose):
    W, H = 34, 56
    c = Canvas(W, H)
    bob = (0, -1, -1, 0)[phase] if pose == 'move' else 0
    tell, strike, hurt = pose == 'tell', pose == 'strike', pose == 'hurt'
    cx = 17
    sy = 22 + bob + (3 if hurt else 0)                       # shoulder line
    sway = (-2, -1, 1, 2)[phase] if pose == 'move' else (-3 if strike else 0)
    robe(c, cx, sy, 54 + bob, 6, 11, SOBOKD, sway=sway, base=2.5)
    for y in range(sy + 18, 54 + bob):                         # grave-dirt stains rising from the hem
        if (y * 5) % 7 < 3:
            c.set(cx - 6 + (y % 4), y, SOBOKD[0]); c.set(cx + 4 + (y % 3), y, SOBOKD[1])
    c.dome(cx, sy + 1, 8, 3.5, SOBOKD, 2.8, top_only=False)
    lean = 2 if strike else (1 if tell else 0)
    for y in range(sy - 8, sy):                                # the long thin neck
        k = (sy - y) / 8
        for x in range(cx - 1, cx + 2):
            c.set(x + round(lean * k), y, c.ramp_at(EGG, 2.2 - (x - cx) * 0.8))
    hy = sy - 15
    ex = cx + lean * 2
    for y in range(hy - 8, hy + 8):
        for x in range(ex - 7, ex + 8):
            dy = (y - hy) / (8.0 if y < hy else 7.0)
            dx = (x - ex) / (6.0 - max(0, -dy) * 1.4)
            if dx * dx + dy * dy <= 1:
                nz = math.sqrt(max(0, 1 - dx * dx - dy * dy))
                c.set(x, y, c.ramp_at(EGG, 2.6 + (-dx * 0.6 - dy * 0.7 + nz * 0.5) * 2.0))
    if tell or strike:                                         # the face splits into a black vertical mouth
        for y in range(hy - 5, hy + 6):
            w = (0 if abs(y - hy) > 3 else 1) if tell else (2 if abs(y - hy) < 3 else 1)
            for x in range(ex - w, ex + w + 1):
                c.set(x, y, INK)
        if strike:
            for y in (hy - 3, hy - 1, hy + 1, hy + 3):
                c.set(ex - 2, y, BONE); c.set(ex + 2, y, BONE)
    # long arms, fingers dangling past the knees; strike lunges both forward
    for s in (-1, 1):
        sh = (cx + s * 7, sy + 2)
        if strike:
            el, hand = (cx + s * 9, sy + 10), (cx + s * 4 + 4, sy + 18)
        else:
            el, hand = (cx + s * 10, sy + 12), (cx + s * 10 + sway // 2, sy + 24)
        limb(c, *sh, *el, SOBOKD, 2, 2.6)
        limb(c, *el, *hand, PALE, 1, 2.6)
        for k in range(4):                                     # long fingers
            c.set(hand[0] + (k % 2) * s, hand[1] + 1 + k, PALE[3 - k // 2])
            c.set(hand[0] - s, hand[1] + 1 + k, PALE[2])
    return c


# 처녀귀신: 시집 못 가고 죽은 처녀의 원혼. 소복, 얼굴을 반쯤 가린 긴 머리, 가르마 사이로 한쪽 눈.
#   상태이상형 — 예고: 고개를 젖히고 숨을 들이켬. 공격: 찢어지는 울음(스턴 파동은 엔진 이펙트).
def maiden(phase, pose):
    W, H = 34, 56
    c = Canvas(W, H)
    bob = (0, -1, -2, -1)[phase] if pose == 'move' else 0
    tell, strike, hurt = pose == 'tell', pose == 'strike', pose == 'hurt'
    cx = 17
    hy = 12 + bob + (2 if hurt else 0) + (-2 if tell else 0)
    sway = (1, 0, -1, 0)[phase] if pose == 'move' else 0
    # hair behind, falling to the waist on both sides
    for x in range(cx - 8, cx + 9):
        for y in range(hy - 4, hy + 26 - abs(x - cx) // 2):
            c.set(x + round(sway * (y - hy) / 26), y, c.ramp_at(HAIR, 1.4 + (0.8 if x % 3 == 0 else 0)))
    robe(c, cx, hy + 9, 54 + bob, 5, 12, SOBOK, sway=sway)
    c.dome(cx, hy + 11, 7, 3.5, SOBOK, 2.8, top_only=False)
    c.set(cx - 1, hy + 14, HONG[3]); c.set(cx, hy + 15, HONG[2]); c.set(cx - 2, hy + 16, HONG[2]); c.set(cx - 1, hy + 19, HONG[1])
    c.dome(cx, hy, 5, 6, PALE, 2.6, top_only=False)
    if strike or tell:   # head thrown back: hollow black eyes with pinpoint pupils, a long black mouth
        for (ex_) in (cx - 2, cx + 2):
            c.set(ex_, hy - 2, INK); c.set(ex_, hy - 1, INK)
        c.set(cx - 2, hy - 1, GHOSTEYE, outline=False); c.set(cx + 2, hy - 1, GHOSTEYE, outline=False)
        for y in range(hy + 1, hy + (6 if strike else 4)):
            c.set(cx, y, INK)
            if strike and y < hy + 5:
                c.set(cx - 1, y, INK); c.set(cx + 1, y, INK)
        for x in range(cx - 5, cx + 6):  # hair swept back off the face
            c.set(x, hy - 6, HAIR[2]); c.set(x, hy - 5, HAIR[1])
    else:  # front hair falls over the face; one eye through the parting
        for x in range(cx - 5, cx + 6):
            if x == cx:
                continue
            for y in range(hy - 6, hy + 8 + (x * 7) % 4):
                c.set(x, y, c.ramp_at(HAIR, 2.2 - abs(x - cx) * 0.15 + (0.8 if x % 3 == 0 else 0)))
        c.set(cx + 1, hy, GHOSTEYE, outline=False); c.set(cx + 1, hy + 1, PALE[1])
        c.set(cx + 1, hy + 4, BLOOD); c.set(cx + 1, hy + 5, BLOOD)
    for s in (-1, 1):
        sh = (cx + s * 6, hy + 11)
        if strike:
            el, hand = (cx + s * 11, hy + 8), (cx + s * 15, hy + 3)
        elif hurt:
            el, hand = (cx + s * 8, hy + 18), (cx + s * 7, hy + 25)
        else:  # clawing at her own face / clutching the hair
            el, hand = (cx + s * 8, hy + 12), (cx + s * 4, hy + 4)
        limb(c, *sh, *el, SOBOK, 2, 2.6)
        limb(c, *el, *hand, PALE, 1, 2.6)
        for k in (-1, 0, 1):
            c.set(hand[0] + k, hand[1] - 1, PALE[3])
    return c


# 물귀신: 물가에 숨어 있다가 발목을 잡아 끌어들이는 익사자의 넋. 물 밖으로는 상반신만.
#   move = 수면 아래 잠복 → 떠오름, tell = 몸을 일으키며 두 팔을 치켜듦, strike = 길게 늘어난 팔로 낚아챔.
WATERDEAD = R('#14222a', '#24383e', '#365058', '#4e6c72', '#6e8e90', '#94b0ae')
WETHAIR = R('#020406', '#040a0a', '#081412', '#0e1e1c')


def mulgwi(phase, pose):
    W, H = 56, 46
    c = Canvas(W, H)
    tell, strike, hurt = pose == 'tell', pose == 'strike', pose == 'hurt'
    cx, wl = 20, 36
    rise = {0: 12, 1: 9, 2: 6, 3: 9}[phase] if pose == 'move' else (0 if (tell or strike) else 9)
    hy = 12 + rise
    # dark pool spreading around it
    for y in range(wl - 2, wl + 6):
        for x in range(cx - 18, cx + 19):
            if ((x - cx) / 18.0) ** 2 + ((y - wl - 2) / 4.0) ** 2 <= 1:
                c.set(x, y, hx('#0a1424') if (x + y + phase) % 7 else hx('#1e3450'), outline=False)
    # bloated drowned torso
    for y in range(hy + 5, wl):
        hw = 8 + (y - hy - 5) * 0.2
        for x in range(int(cx - hw), int(cx + hw) + 1):
            c.set(x, y, c.ramp_at(WATERDEAD, 3.0 - (x - cx) / hw * 1.4 - (y - hy) * 0.05))
    c.dome(cx, hy, 6.5, 7, WATERDEAD, 3.0, top_only=False)
    # sockets and one cold eye; slack mouth
    c.set(cx - 3, hy, INK); c.set(cx - 2, hy, INK); c.set(cx + 2, hy, INK)
    c.set(cx + 3, hy, GHOSTEYE, outline=False)
    c.set(cx, hy + 4, INK); c.set(cx - 1, hy + 4, INK)
    # wet hair plastered down over the head and shoulders, strands to the water
    for x in range(cx - 9, cx + 10):
        if -2 <= x - cx <= 4:
            top_y, end = hy - 7, hy - 2 + (x % 2)
        else:
            top_y, end = hy - 6 + abs(x - cx) // 3, wl - (x * 5) % 4
        for y in range(top_y, end):
            c.set(x, y, c.ramp_at(WETHAIR, 2.4 - abs(x - cx) * 0.1 + (0.9 if x % 3 == 0 else 0)))
    # arms: on the strike one arm stretches impossibly long across the bank to grab an ankle
    for s in (-1, 1):
        sh = (cx + s * 8, hy + 8)
        if strike and s > 0:
            el, hand = (cx + 22, hy + 10), (cx + 33, wl - 1)
        elif tell:
            el, hand = (cx + s * 13, hy + 1), (cx + s * 16, hy - 7)
        else:
            el, hand = (cx + s * 12, hy + 14), (cx + s * 13, wl - 1)
        limb(c, *sh, *el, WATERDEAD, 3, 2.6)
        limb(c, *el, *hand, WATERDEAD, 2, 2.4)
        for k in range(-2, 3):                                   # splayed long fingers
            fx, fy = hand[0] + k, hand[1] + (2 if not tell else -2) + (abs(k) == 2)
            c.set(fx, fy, PALE[3]); c.set(fx, fy + (1 if not tell else -1), PALE[2])
    for x in range(cx - 14, cx + 15):                             # bright ripple ring at the surface
        if (x + phase * 2) % 6 < 4:
            c.set(x, wl, hx('#5a7a9c') if abs(x - cx) > 10 else hx('#8aaac8'), outline=False)
    if hurt:
        for x in range(cx - 7, cx + 8, 2):
            c.set(x, wl - 2, hx('#8aaac8'), outline=False)
    return c

# ================================================================ 2장 지리산
DOK = R('#0a100e', '#141e1a', '#202e26', '#2e4034', '#3e5444', '#526a56')      # 이끼 낀 도깨비 피부
CLUB = R('#1a100a', '#2e1c10', '#4a2e18', '#6a4424', '#8c5e34')
STRAW = props.THATCH


def club(c, x0, y0, x1, y1, ramp, studs=True):
    """도깨비방망이: a knobbly club thickening toward the head."""
    n = int(max(abs(x1 - x0), abs(y1 - y0)) * 1.5) + 1
    for i in range(n + 1):
        t = i / n
        x = x0 + (x1 - x0) * t; y = y0 + (y1 - y0) * t
        r = 1.0 + t * 2.6
        for dy in range(-3, 4):
            for dx in range(-3, 4):
                if dx * dx + dy * dy <= r * r:
                    c.set(round(x + dx), round(y + dy), c.ramp_at(ramp, 2.4 - dx * 0.5 - dy * 0.4))
    if studs:
        for t in (0.6, 0.75, 0.9):
            x = x0 + (x1 - x0) * t; y = y0 + (y1 - y0) * t
            c.set(round(x) - 2, round(y) - 1, BONE)


def dokkaebi(phase, pose, skin=DOK, one_eye=True, gamtu=True, fire=False):
    W, H = 48, 56
    c = Canvas(W, H)
    G = 54
    tell, strike, hurt = pose == 'tell', pose == 'strike', pose == 'hurt'
    bob = (0, 1, 0, 1)[phase] if pose == 'move' else 0
    step = (1, 0, -1, 0)[phase] if pose == 'move' else 0
    cx = 22 + (2 if hurt else 0)
    by = 18 + bob + (1 if tell else 0)
    # stocky bowed legs
    for s in (-1, 1):
        hip, knee, foot = (cx + s * 5, by + 22), (cx + s * 9, by + 28), (cx + s * 7 + step * s, G - 1)
        limb(c, *hip, *knee, skin, 4, 2.0)
        limb(c, *knee, *foot, skin, 4, 2.0)
        c.rect(foot[0] - 2, G - 1, 6, 1, skin[1])
    # big round belly, broad shoulders
    c.dome(cx, by + 15, 12, 11, skin, 2.6, top_only=False)
    c.dome(cx, by + 6, 14, 6, skin, 2.8, top_only=False)
    # 짚 허리띠 and a ragged straw skirt
    for x in range(cx - 11, cx + 12):
        c.set(x, by + 22, STRAW[4] if x % 3 else STRAW[2])
        for y in range(by + 23, by + 27 + (x * 5) % 3):
            c.set(x, y, STRAW[2 if x < cx else 1])
    # head sunk into the shoulders, horn(s), wild hair
    hy = by - 2
    c.dome(cx, hy, 8, 7, skin, 2.8, top_only=False)
    if fire:
        for i, x in enumerate(range(cx - 9, cx + 10)):       # hair of blue-and-orange flame
            hgt = 5 + (i * 7 + phase * 3) % 5
            for k in range(hgt):
                col = FIRE[min(4, 4 - k * 4 // hgt)] if (i + k) % 3 else FIREB[min(3, k * 3 // hgt)]
                c.set(x, hy - 6 - k + abs(x - cx) // 3, col, outline=False)
    else:
        for x in range(cx - 8, cx + 9):
            for y in range(hy - 8 + abs(x - cx) // 2, hy - 4):
                c.set(x, y, HAIR[2] if (x + y) % 3 else HAIR[1])
    if gamtu:  # 감투: a small black stiff cap perched askew on the head; the horn pokes through it
        c.rect(cx - 6, hy - 11, 9, 4, HAIR[1]); c.rect(cx - 7, hy - 8, 11, 1, HAIR[2])
        c.set(cx - 5, hy - 11, HAIR[3])
    for (hx0, hlen) in ((cx + 1, 8),) if one_eye else ((cx - 5, 5), (cx + 5, 5)):
        for k in range(hlen):
            c.set(hx0 + (k // 3) * (1 if hx0 >= cx else -1), hy - 7 - k, BONE if k < hlen - 2 else hx('#fff4d0'))
            c.set(hx0 + 1 + (k // 3) * (1 if hx0 >= cx else -1), hy - 7 - k, props.hx('#9a9078') if k < hlen - 3 else BONE)
    # face: one huge eye (or two), a wide grin of tusks
    eye_col = FIRE[4] if fire else hx('#f0e070')
    if one_eye:
        c.dome(cx, hy - 1, 3.5, 3, R('#c8c0a0', '#ece6cc', '#ffffff'), 2.0, top_only=False)
        c.set(cx, hy - 1, INK); c.set(cx + 1, hy - 1, INK); c.set(cx, hy, eye_col, outline=False)
        if tell:
            c.set(cx - 1, hy - 1, BLOOD); c.set(cx + 2, hy - 1, BLOOD)
    else:
        for ex in (cx - 3, cx + 3):
            c.set(ex, hy - 1, eye_col, outline=False); c.set(ex, hy, INK)
    my = hy + 4
    for x in range(cx - 4, cx + 5):
        c.set(x, my, INK)
    c.set(cx - 3, my - 1, BONE); c.set(cx + 3, my - 1, BONE); c.set(cx - 3, my - 2, BONE); c.set(cx + 3, my - 2, BONE)
    # arms; the right one holds the club — raised high on the tell, smashed down on the strike
    ramp = CLUB if not fire else R('#1a0c06', '#3a1608', '#6a2a0c', '#a84a14', '#e07a20')
    limb(c, cx - 12, by + 4, cx - 16, by + 16 + bob, skin, 3, 2.4)
    c.dome(cx - 16, by + 18 + bob, 2.5, 2.5, skin, 2.6, top_only=False)
    if tell:
        limb(c, cx + 12, by + 4, cx + 17, by - 6, skin, 3, 2.4)
        club(c, cx + 17, by - 6, cx + 12, by - 22, ramp)
    elif strike:
        limb(c, cx + 12, by + 4, cx + 20, by + 12, skin, 3, 2.4)
        club(c, cx + 20, by + 12, cx + 24, by + 30, ramp)
    else:
        limb(c, cx + 12, by + 4, cx + 17, by + 15 + bob, skin, 3, 2.4)
        club(c, cx + 17, by + 15 + bob, cx + 24, by + 4 + bob, ramp)
    if fire:   # glowing cracks in the charcoal skin
        for (dx, dy) in ((-6, 10), (-5, 11), (4, 14), (5, 15), (6, 16), (-2, 18), (8, 8), (-9, 4)):
            c.set(cx + dx, by + dy, FIRE[3], outline=False)
    return c


FIRE = R('#5a1a08', '#a8380c', '#e8701a', '#ffb040', '#fff0a0')
FIREB = R('#0a1a5a', '#1a40a8', '#3a7ae8', '#8ac8ff')
CHAR = R('#0c0808', '#1a1210', '#2a1c16', '#3c2a20', '#523a2a', '#6a4c34')


# 외눈박이 도깨비: 이끼 낀 거구, 외눈, 외뿔, 감투. 감투를 쓰면 사라진다(은신은 엔진). 예고: 방망이를 치켜듦.
def oneeye(phase, pose):
    return dokkaebi(phase, pose, DOK, one_eye=True, gamtu=True)


# 불도깨비: 숯처럼 검은 몸에 금이 가 붉게 달아오르고, 머리칼은 도깨비불. 불붙은 방망이로 내리치면 불 장판이 남는다.
def firedok(phase, pose):
    return dokkaebi(phase, pose, CHAR, one_eye=False, gamtu=False, fire=True)


def fire_patch(phase):
    """불 장판: a low ring of flames on the ground (loops 4 frames)."""
    c = Canvas(28, 14)
    for i, x in enumerate(range(2, 26)):
        hgt = 3 + (i * 5 + phase * 3) % 6
        for k in range(hgt):
            c.set(x, 12 - k - (abs(x - 14) < 6) * 0, FIRE[min(4, 4 - k * 5 // max(1, hgt))] if (i + k + phase) % 4 else FIRE[1], outline=False)
    return c


# ---------------------------------------------------------------- tigers (side view, facing right)
def big_cat(phase, pose, fur, dark, shaggy=False, spirit=False, haetae=False, canine=False, flame=None):
    W, H = 66, 48 if flame else 44
    c = Canvas(W, H)
    G = H - 2
    tell, strike, hurt = pose == 'tell', pose == 'strike', pose == 'hurt'
    a = phase * math.pi / 2
    sw = (math.sin(a), math.sin(a + math.pi))
    low = 5 if tell else 0
    stretch = 6 if strike else 0
    lift = -3 if hurt else 0
    bx, by = 30 - (3 if hurt else 0), H - 21 + low + lift
    # tail: long and curling up (lashing on the tell)
    tail = [(bx - 16, by - 2)]
    for k in range(1, 10):
        tail.append((bx - 16 - k * 1.6, by - 2 - k * (1.4 if tell else 0.8) + math.sin(k * 0.7 + phase) * 1.4))
    for (x0, y0), (x1, y1) in zip(tail, tail[1:]):
        limb(c, x0, y0, x1, y1, fur, 2, 2.4)
    # far legs (darker), then body, then near legs
    def leg(hip, swing, near, front):
        if strike:
            foot = (hip[0] + (12 if front else -12), G - (6 if front else 1))
        elif tell:
            foot = (hip[0] + (3 if front else -2), G - 1)
        else:
            foot = (hip[0] + swing * 6, G - 1 - max(0, swing) * 2)
        knee = ((hip[0] + foot[0]) / 2 + (2 if front else -3), (hip[1] + foot[1]) / 2)
        ramp = fur if near else dark
        limb(c, *hip, *knee, ramp, 4, 2.2)
        limb(c, *knee, *foot, ramp, 3, 2.2)
        c.rect(int(foot[0]) - 1, G - 1 if not (strike and front) else int(foot[1]), 5, 1, ramp[1])
    leg((bx + 13 + stretch, by + 3), sw[1], False, True)
    leg((bx - 12, by + 3), sw[0], False, False)
    thin = 0.78 if shaggy else 1.0
    x0, x1 = bx - 17, bx + 18 + stretch
    for x in range(x0, x1 + 1):                              # body: haunch, a waist, a high shoulder hump
        t = (x - x0) / (x1 - x0)
        r = (5.4 + 2.4 * math.exp(-((t - 0.15) / 0.14) ** 2) + 3.0 * math.exp(-((t - 0.82) / 0.13) ** 2)) * thin
        cy = by - 1.5 * math.exp(-((t - 0.82) / 0.15) ** 2) + (0.8 * math.sin(t * math.pi) if not strike else 0)
        for y in range(int(cy - r), int(cy + r * 0.85) + 1):
            ny = (y - cy) / r
            nz = math.sqrt(max(0.0, 1 - ny * ny))
            c.set(x, y, c.ramp_at(fur, 2.3 + (-ny * 0.8 + nz * 0.5) * 1.8 - (0.4 if t < 0.1 else 0)))
        if shaggy and int(t * 30) % 4 == 0 and 0.3 < t < 0.75:       # ribs showing through
            for y in range(int(cy), int(cy + r * 0.7)):
                c.set(x, y, fur[1])
    leg((bx + 11 + stretch, by + 4), sw[0], True, True)
    leg((bx - 14, by + 4), sw[1], True, False)
    # head
    hx_, hy = bx + 24 + stretch, by - 6 + (2 if tell else 0) - (3 if hurt else 0)
    c.dome(hx_ - 2, hy + 1, 7, 6, fur, 2.6, top_only=False)                # cheek ruff
    c.dome(hx_, hy, 7.5, 7, fur, 2.9, top_only=False)
    c.dome(hx_ + 6, hy + 2, 4.5, 4, fur, 3.1, top_only=False)              # muzzle
    c.set(hx_ + 7, hy + 3, fur[5] if len(fur) > 5 else fur[-1])
    if canine:   # long snout and tall pointed ears
        c.dome(hx_ + 9, hy + 3, 5, 3, fur, 3.0, top_only=False)
        for ex in (hx_ - 3, hx_ + 1):
            for k in range(5):
                c.set(ex + k // 3, hy - 6 - k, fur[3] if k < 4 else INK); c.set(ex + 1 + k // 3, hy - 6 - k, dark[1])
    else:
        for ex in (hx_ - 4, hx_ + 1):
            c.set(ex, hy - 7, fur[3]); c.set(ex, hy - 8, fur[2]); c.set(ex + 1, hy - 7, dark[1])  # ears
    eye = hx('#ff5040') if shaggy else (hx('#8ae8ff') if spirit else hx('#f0d040'))
    c.set(hx_ + 2, hy - 1, eye, outline=False); c.set(hx_ + 3, hy - 1, INK)
    c.set(hx_ + 10, hy + 1, INK)                                            # nose
    if strike or tell:   # open jaws
        for x in range(hx_ + 3, hx_ + 10):
            c.set(x, hy + 4, INK); c.set(x, hy + 5, BLOOD if not shaggy else hx('#3a1a1a'))
        c.set(hx_ + 8, hy + 3, BONE); c.set(hx_ + 5, hy + 6, BONE)
        if shaggy:   # 장산범's mouth is uncannily human: a row of flat teeth
            for x in range(hx_ + 4, hx_ + 9):
                c.set(x, hy + 4, hx('#e8e0d0'))
    # markings
    if shaggy:   # long white hair hanging from neck, belly and haunch
        for x in range(bx - 18, bx + 26 + stretch, 2):
            top = by + 4 if x < bx + 16 + stretch else hy + 4
            ln = 4 + (x * 7) % 4
            for k in range(ln):
                c.set(x + (k // 3) * (-1 if x < bx else 1), top + k + (2 if x < bx + 14 + stretch else 0), fur[2 if k < ln - 1 else 1])
        for x in range(hx_ - 6, hx_ + 1):   # a mane over the head
            for k in range(3):
                c.set(x, hy - 7 - k + abs(x - hx_ + 3) // 2, fur[4 - k])
    elif flame:   # 불개: embers glowing in cracks of the charcoal hide
        for (dx, dy) in ((-12, 0), (-8, 3), (-3, -2), (2, 2), (7, -1), (11, 3), (15, 0), (-5, 4), (4, -3)):
            if c.get(bx + dx, by + dy):
                c.set(bx + dx, by + dy, FIRE[3], outline=False); c.set(bx + dx + 1, by + dy, FIRE[1], outline=False)
    elif not haetae:
        for i in range(-14, 20 + stretch, 5):    # stripes
            for k in range(-6, 3):
                x = bx + i + k // 3
                if c.get(x, by + k):
                    c.set(x, by + k, dark[0] if not spirit else hx('#0a1a3a'))
        for (dx, dy) in ((-3, -3), (-1, -5), (2, -4)):
            c.set(hx_ + dx, hy + dy, dark[0])
    if haetae:   # 해태: a single horn, a curly golden mane, scales on the flank; tell = drawing fire into the jaws
        for k in range(6):
            c.set(hx_ - 1 + k // 3, hy - 8 - k, BONE if k < 5 else hx('#fff4d0'))
        # full curly mane around the head and down the neck (only where it doesn't cover the face)
        for y in range(hy - 10, hy + 12):
            for x in range(hx_ - 14, hx_ + 4):
                d = ((x - hx_ + 3) / 10.0) ** 2 + ((y - hy - 1) / 10.0) ** 2
                face = ((x - hx_) / 7.0) ** 2 + ((y - hy) / 6.5) ** 2 < 1 or x > hx_ + 2
                if d <= 1 and not face:
                    curl = math.sin(x * 1.3) * math.sin(y * 1.3)
                    c.set(x, y, c.ramp_at(MANE, 2.6 + curl * 1.4 - (x - hx_ + 3) * -0.03 - (y - hy) * 0.06))
        for i in range(-12, 14 + stretch, 4):
            for k in (-2, 2):
                if c.get(bx + i + (k > 0) * 2, by + k):
                    c.set(bx + i + (k > 0) * 2, by + k, dark[1]); c.set(bx + i + 1 + (k > 0) * 2, by + k + 1, fur[4])
        if tell:
            for k in range(8):
                c.set(hx_ + 11 + k, hy + 4 + (k % 3) - 1, FIRE[min(4, k // 2)], outline=False)
    if spirit or flame:   # 산군: blue spirit-fire licking along the spine / 불개: a mane of real fire
        fl = flame or FIREB
        for i, x in enumerate(range(bx - 14, bx + 20 + stretch)):
            hgt = (2 + (i * 5 + phase * 3) % 4) * (2 if flame else 1) + (int(3 * math.sin(i * 0.35 + phase)) + 3 if flame else 0)
            top = by - 8 - (1 if bx + 8 + stretch < x else 0)
            for k in range(hgt):
                c.set(x, top - k, fl[min(len(fl) - 1, len(fl) - 1 - k * (len(fl) - 1) // hgt)], outline=False)
    return c


TIGER = R('#24100a', '#44200e', '#683414', '#8c4c1e', '#ac682c', '#c88a44')
TIGERD = R('#140804', '#2a1408', '#42200c', '#5a3012', '#74421a')
WHITE = R('#3a3c48', '#5e6070', '#848898', '#aaaebc', '#cccfda', '#e8eaf0')
WHITED = R('#2a2a34', '#4a4a56', '#6a6a78', '#8a8a98', '#a8a8b4')


# 장산범: 사람 목소리를 흉내 내어 유인하는 흰 짐승. 깡마르고 긴 흰 털, 붉은 눈, 사람 이빨. (정예·중간보스)
def jangsanbeom(phase, pose):
    return big_cat(phase, pose, WHITE, WHITED, shaggy=True)


# 산군: 산의 주인 호랑이의 넋. 등줄기에 푸른 영기가 타오른다. 돌진형 — 예고: 몸을 낮추고 꼬리를 친다.
def sangun(phase, pose):
    return big_cat(phase, pose, TIGER, TIGERD, spirit=True)

# ================================================================ 3장 경주 귀족가
FOX = R('#1a0a08', '#3a160c', '#622a12', '#8a441c', '#b0622a', '#d08a44')
FOXL = R('#4a4048', '#7a7078', '#a8a0a4', '#d0c8c8', '#ece6e2')               # cream chest / tail tip
FOXFIRE = R('#3a0a3a', '#7a1a7a', '#c040c0', '#f08af0', '#ffd8ff')


# 여우 졸개: 연화의 권속. 두 발로 선 여우가 비단 장옷을 걸쳤다. 예고: 여우불을 손에 피움. 공격: 환술 분신(엔진에서 반투명 복제).
def fox(phase, pose):
    W, H = 36, 50
    c = Canvas(W, H)
    G = 48
    tell, strike, hurt = pose == 'tell', pose == 'strike', pose == 'hurt'
    bob = (0, -1, 0, -1)[phase] if pose == 'move' else 0
    step = (1, 0, -1, 0)[phase] if pose == 'move' else 0
    cx = 17 + (2 if hurt else 0)
    by = 20 + bob
    # bushy tail curling up behind
    for k in range(14):
        t = k / 13
        x = cx + 8 + math.sin(t * 2.4) * 7
        y = by + 18 - t * 22 + (phase % 2 if pose == 'move' else 0)
        r = 2.5 + math.sin(t * math.pi) * 2.5
        for dy in range(-3, 4):
            for dx in range(-4, 5):
                if dx * dx + dy * dy <= r * r:
                    c.set(round(x + dx), round(y + dy), FOXL[3] if t > 0.82 else c.ramp_at(FOX, 3.2 - dx * 0.3 - dy * 0.2))
    # legs (digitigrade), then the silk 장옷 robe
    for s in (-1, 1):
        limb(c, cx + s * 3, by + 16, cx + s * 4 + step * s, G - 3, FOX, 2, 2.4)
        c.rect(cx + s * 4 + step * s - 1, G - 2, 3, 2, FOX[1])
    robe(c, cx, by + 2, by + 20, 5, 9, R('#1a0c22', '#2c1438', '#44205a', '#5e3078', '#7a4498'), ragged=False, base=2.6)
    for y in range(by + 3, by + 20):  # gold hem line
        c.set(cx - 1, y, hx('#c9a24a') if y % 2 else hx('#8a6a28'))
    # head: pointed snout, tall ears, slit eyes
    hy = by - 6
    c.dome(cx, hy, 5.5, 5, FOX, 2.9, top_only=False)
    for k in range(5):
        c.set(cx - 6 - k, hy + 2 + k // 3, c.ramp_at(FOX, 3.2 - k * 0.2))
        c.set(cx - 6 - k, hy + 3 + k // 3, FOXL[2])
    c.set(cx - 11, hy + 3, INK)
    for ex in (cx - 4, cx + 3):
        for k in range(5):
            c.set(ex + (k // 2) * (1 if ex > cx else -1) * 0, hy - 4 - k, FOX[3] if k < 4 else INK)
            c.set(ex + 1, hy - 4 - k + 1, FOX[1])
    c.set(cx - 3, hy - 1, hx('#ffd84a'), outline=False); c.set(cx - 2, hy - 1, INK)
    # arms: on the tell a fox-fire blooms in the palm
    for s in (-1, 1):
        sh = (cx + s * 5, by + 3)
        if tell and s < 0:
            hand = (cx - 9, by - 2)
        elif strike:
            hand = (cx + s * 10, by + 4)
        else:
            hand = (cx + s * 7, by + 12)
        limb(c, *sh, *hand, R('#2c1438', '#44205a', '#5e3078', '#7a4498'), 2, 2.4)
        c.set(hand[0], hand[1] + 1, FOXL[2])
        if (tell and s < 0) or strike:
            c.dome(hand[0], hand[1] - 3, 2.5 + strike, 3 + strike, FOXFIRE, 3.4, top_only=False)
    return c


# 손각시: 혼례를 치르지 못한 신부의 원혼. 활옷/원삼에 족두리, 연지곤지, 얼굴은 하얗게 질렸다.
#   혼례 소재 — 예고: 붉은 소매로 얼굴을 가림. 공격: 소매를 펼치며 붉은 실(인연의 끈)을 던진다.
WONSAM = R('#1a0610', '#3a0c1e', '#621628', '#8c2232', '#b43440', '#d8505a')
WONSAMG = R('#0a1a14', '#123024', '#1c4a36', '#2a644a')


def songaksi(phase, pose):
    W, H = 40, 56
    c = Canvas(W, H)
    tell, strike, hurt = pose == 'tell', pose == 'strike', pose == 'hurt'
    bob = (0, -1, -2, -1)[phase] if pose == 'move' else 0
    cx = 20
    hy = 13 + bob + (2 if hurt else 0)
    sway = (1, 0, -1, 0)[phase] if pose == 'move' else 0
    # long black hair in a 쪽 down the back, the 원삼 robe floating above the ground
    robe(c, cx, hy + 8, 54 + bob, 7, 14, WONSAM, sway=sway, base=2.4)
    for y in range(hy + 12, 52 + bob, 3):  # scattered gold 금박 flowers
        for x in range(cx - 10, cx + 11, 4):
            xx = x + (y // 3) % 2 * 2
            if c.get(xx, y) and (xx * 3 + y) % 5 < 2:
                c.set(xx, y, hx('#d8b048')); c.set(xx + 1, y, hx('#8a6a28'))
    c.dome(cx, hy + 10, 9, 3.5, WONSAMG, 2.6, top_only=False)
    c.dome(cx, hy, 5, 6, R('#8a8e98', '#b4b8c0', '#d8dce2', '#eef0f4', '#ffffff'), 2.6, top_only=False)
    # 족두리: a small black crown with jewels and dangling ornaments
    c.rect(cx - 4, hy - 9, 9, 4, HAIR[1])
    for x in (cx - 3, cx, cx + 3):
        c.set(x, hy - 10, hx('#d8b048')); c.set(x, hy - 8, hx('#4ab0a0'))
    c.set(cx - 5, hy - 6, hx('#d8b048')); c.set(cx + 5, hy - 6, hx('#d8b048'))
    for y in range(hy - 6, hy + 4):
        c.set(cx - 6, y, HAIR[2]); c.set(cx + 6, y, HAIR[2])
    # 연지곤지 and closed / hollow eyes
    c.set(cx, hy - 3, hx('#d02030'), outline=False)
    c.set(cx - 3, hy + 2, hx('#e04050'), outline=False); c.set(cx + 3, hy + 2, hx('#e04050'), outline=False)
    if strike:
        for ex in (cx - 2, cx + 2):
            c.set(ex, hy, INK); c.set(ex, hy + 1, INK)
        c.set(cx, hy + 4, INK); c.set(cx, hy + 5, BLOOD)
    else:
        c.set(cx - 2, hy, PALE[1]); c.set(cx - 3, hy, PALE[1]); c.set(cx + 2, hy, PALE[1]); c.set(cx + 3, hy, PALE[1])
        c.set(cx, hy + 4, hx('#a02030'))
    # great red sleeves (한삼): raised to hide the face on the tell, flung wide on the strike
    for s in (-1, 1):
        sh = (cx + s * 8, hy + 10)
        if tell:
            pts = [sh, (cx + s * 6, hy + 2), (cx + s * 2, hy - 1), (cx + s * 2, hy + 7)]
        elif strike:
            pts = [sh, (cx + s * 19, hy + 4), (cx + s * 19, hy + 13), (cx + s * 10, hy + 18)]
        else:
            pts = [sh, (cx + s * 12, hy + 14), (cx + s * 13, hy + 28 + sway * s), (cx + s * 8, hy + 22)]
        c.poly(pts, lambda x, y: c.ramp_at(WONSAM, 3.4 - (y - hy) * 0.04 - (0.6 if s > 0 else 0)))
        tip = pts[2]
        for k in range(3):   # white 한삼 cuffs
            c.set(tip[0] - s * k, tip[1], hx('#e8e4ec')); c.set(tip[0] - s * k, tip[1] - 1, hx('#c8c4d0'))
    if strike:   # the red thread of fate
        for k in range(14):
            c.set(cx + 19 + k, hy + 6 + round(math.sin(k * 0.6) * 2), hx('#e83040'), outline=False)
    return c


# 장승: 탁기에 오염된 돌장승 (원래 마을 수호자). 금 간 돌 몸, 검게 번진 탁기, 붉게 타는 눈. 탱커 — 느리고 단단하다.
#   예고: 몸을 뒤로 젖힘. 공격: 앞으로 쓰러지듯 박치기(지면 충격파는 엔진).
JSTONE = R('#0e0e14', '#1a1b24', '#282a36', '#383b4a', '#4a4e60', '#5e6276', '#767b90')


def jangseung_m(phase, pose):
    W, H = 34, 64
    c = Canvas(W, H)
    G = 62
    tell, strike, hurt = pose == 'tell', pose == 'strike', pose == 'hurt'
    hop = (0, -2, 0, 0)[phase] if pose == 'move' else 0     # it hops — no legs
    lean = -4 if tell else (8 if strike else 0)
    cx = 17
    top = 6 + hop
    # pole body (a slight taper), leaning by shifting rows
    for y in range(top, G + hop):
        t = (y - top) / (G - top)
        hw = 6.5 + t * 1.5
        off = round(lean * (1 - t))
        for x in range(int(cx - hw), int(cx + hw) + 1):
            u = (x - cx) / hw
            crack = ((x * 7 + y * 3) % 23 == 0) or (abs(x - cx - 2 - y // 9) < 1 and 30 < y < 50)
            tone = 3.4 - u * 1.8 + math.sin(y * 0.8) * 0.15 - (2.4 if crack else 0)
            c.set(x + off, y, c.ramp_at(JSTONE, tone))
    # 관모 on top
    for y in range(top - 6, top + 2):
        for x in range(cx - 7 + (top + 2 - y) // 2, cx + 8 - (top + 2 - y) // 2):
            c.set(x + lean, y, c.ramp_at(JSTONE, 2.0 - (x - cx) * 0.15))
    fy = top + 11
    off = round(lean * 0.85)
    # the carved face fills the top third: heavy brows, bulging eyes burning red, flat nose, a grimace of teeth
    for x in range(cx - 7, cx + 8):
        c.set(x + off, fy - 5 + abs(x - cx) // 4, JSTONE[6]); c.set(x + off, fy - 4 + abs(x - cx) // 4, JSTONE[1])
    for ex in (cx - 4, cx + 4):
        c.dome(ex + off, fy, 3.5, 3.5, JSTONE, 4.0, top_only=False)
        for dy in (-1, 0):
            for dx in (-1, 0, 1):
                c.set(ex + off + dx, fy + dy, hx('#ff4020') if not hurt else hx('#4a2a24'), outline=False)
        c.set(ex + off, fy, hx('#ffd080') if not hurt else hx('#4a2a24'), outline=False)
    c.dome(cx + off, fy + 5, 2.5, 3.5, JSTONE, 3.8, top_only=False)
    c.set(cx - 1 + off, fy + 7, INK); c.set(cx + 1 + off, fy + 7, INK)
    for x in range(cx - 6, cx + 7):                                       # wide mouth with two rows of teeth
        c.set(x + off, fy + 10, INK); c.set(x + off, fy + 13, INK)
        c.set(x + off, fy + 11, JSTONE[6] if x % 2 else JSTONE[3]); c.set(x + off, fy + 12, JSTONE[5] if x % 2 == 0 else JSTONE[2])
    c.set(cx - 6 + off, fy + 9, JSTONE[6]); c.set(cx + 6 + off, fy + 9, JSTONE[6])
    # carved inscription band (천하대장군) and black 탁기 seeping down the cracks
    for y in range(fy + 17, G - 6 + hop):
        if y % 4:
            c.set(cx + round(lean * (1 - (y - top) / (G - top))), y, JSTONE[1])
    for (dx, dy) in ((-5, 24), (4, 30), (-3, 38), (5, 44), (-6, 48), (2, 34)):
        for k in range(5):
            c.set(cx + dx + (k % 2) + round(lean * 0.4), top + dy + k, hx('#0a0410'))
    return c

# ================================================================ 4장 동해·용궁
HAETAE = R('#0a1a1a', '#123030', '#1c4a46', '#286660', '#38847a', '#52a094')
HAETAED = R('#061010', '#0c2020', '#123430', '#1a4842', '#246058')
MANE = R('#3a2408', '#6a4210', '#9a6418', '#c88a28', '#ecb648')


# 해태: 불을 먹는 정의의 수호수. 시험 미니보스(중립) — 예고: 입 앞으로 불기운을 빨아들임. 공격: 돌진·들이받기.
def haetae(phase, pose):
    return big_cat(phase, pose, HAETAE, HAETAED, haetae=True)


# 어둑시니: 어둠의 정령. 바라볼수록 커진다. 형체 없는 그림자 덩어리에 흰 눈들이 떠 있다.
#   시야 방해 — 예고: 높이 부풀어 오름. 공격: 그림자 망토를 펼쳐 화면을 덮음(엔진에서 비네트 강화).
SHADE = R('#010103', '#04040a', '#080812', '#0e0e1c', '#161628')


def eodukssini(phase, pose):
    W, H = 52, 64
    c = Canvas(W, H)
    tell, strike, hurt = pose == 'tell', pose == 'strike', pose == 'hurt'
    grow = (0, 1, 2, 1)[phase] if pose == 'move' else (8 if tell else (4 if strike else -6))
    cx, G = 26, 62
    top = 20 - grow
    widen = 10 if strike else 0
    for y in range(top, G):
        t = (y - top) / (G - top)
        hw = 6 + t * (12 + widen) + math.sin(y * 0.5 + phase) * 1.5
        for x in range(int(cx - hw), int(cx + hw) + 1):
            edge = abs(x - cx) / hw
            if edge > 0.85 and (x * 3 + y * 5 + phase) % 4 == 0:
                continue  # frayed smoky edge
            c.set(x, y, c.ramp_at(SHADE, 3.6 - edge * 2.6 - t * 0.8))
    for k in range(5):   # wisps rising off the head
        x = cx - 6 + k * 3
        for j in range(3 + (k + phase) % 3):
            c.set(x + (j % 2), top - 1 - j, SHADE[2], outline=False)
    # many small eyes opening in the dark
    eyes = [(-3, 8), (3, 7), (0, 13), (-7, 17), (6, 16), (-2, 22), (8, 25), (-9, 28)]
    n = 3 if hurt else (8 if (tell or strike) else 4 + phase % 2)
    for (dx, dy) in eyes[:n]:
        c.set(cx + dx, top + dy, hx('#e8ecff'), outline=False)
        c.set(cx + dx + 1, top + dy, hx('#8a90b0'), outline=False)
    if strike:   # arms of shadow sweeping out
        for s in (-1, 1):
            for k in range(14):
                x = cx + s * (12 + k)
                y = top + 18 - int(math.sin(k / 13 * math.pi) * 8)
                for j in range(4 - k // 5):
                    c.set(x, y + j, SHADE[2])
    return c


# 파도 요괴: 파도 등을 타고 돌진하는 바다 요괴. 물마루 속에 거품으로 된 얼굴, 해초 수염.
#   move = 출렁이며 다가옴, tell = 물마루가 높이 솟음, strike = 낮고 길게 미끄러지는 돌진, hurt = 흩어지는 물보라.
SEA = R('#020814', '#06142a', '#0c2444', '#163a62', '#245682', '#3c78a4', '#6a9ec4')
FOAM = R('#6a86a8', '#9ab4cc', '#c8dae8', '#eef6fc')


def pado(phase, pose):
    W, H = 60, 44
    c = Canvas(W, H)
    tell, strike, hurt = pose == 'tell', pose == 'strike', pose == 'hurt'
    G = 42
    crest = (10, 8, 6, 8)[phase] if pose == 'move' else (2 if tell else (20 if strike else 14))
    length = 34 if not strike else 50
    x0 = 6
    for x in range(x0, x0 + length):
        t = (x - x0) / length
        # wave profile: a long back slope rising to a curling crest at the front
        top = G - 4 - (G - 4 - crest) * (t ** 1.6 if t < 0.85 else (1 - (t - 0.85) * 3))
        for y in range(int(top), G):
            d = (y - top) / max(1, G - top)
            c.set(x, y, c.ramp_at(SEA, 5.4 - d * 4.4 - (0.4 if x % 5 == 0 else 0)))
        for k in range(2):  # foam cap
            if (x + phase * 2) % 3:
                c.set(x, int(top) + k, FOAM[3 - k], outline=False)
    # the curl: foam lip curling over the face
    lx = x0 + int(length * 0.85)
    for k in range(13):
        ang = k / 12 * math.pi * 1.1
        for r_, col in ((7, FOAM[3]), (6, FOAM[2]), (5, FOAM[1])):
            c.set(lx + 1 + round(math.cos(ang) * r_), crest + 6 - round(math.sin(ang) * r_), col, outline=False)
    # face in the water: foam eyes and a dark gaping mouth
    fx, fy = lx - 4, crest + 9
    if not hurt:
        for ex in (fx - 4, fx + 3):          # ringed foam eyes with a dark pupil
            for (dx, dy) in ((0, -1), (-1, 0), (1, 0), (0, 1), (-1, -1), (1, 1), (1, -1), (-1, 1)):
                c.set(ex + dx, fy + dy, FOAM[3] if dy < 1 else FOAM[1], outline=False)
            c.set(ex, fy, INK)
        mh = 6 if (tell or strike) else 3
        for y in range(fy + 4, fy + 4 + mh):
            for x in range(fx - 3, fx + 3):
                c.set(x, y, SEA[0] if 0 < y - fy - 4 < mh - 1 or abs(x - fx + 0.5) < 2 else SEA[1])
        for x in range(fx - 3, fx + 3, 2):   # foam teeth
            c.set(x, fy + 4, FOAM[3], outline=False)
    # seaweed beard trailing
    for k in range(3):
        bx = fx - 4 + k * 3
        for j in range(6):
            c.set(bx + (j % 2), fy + 8 + j, hx('#1a4a2a') if j < 5 else hx('#0a2a14'))
    if hurt:   # scattered spray
        for (dx, dy) in ((0, -6), (6, -10), (-6, -8), (12, -4), (-10, -2), (4, -14)):
            c.set(lx + dx, crest + dy, FOAM[3], outline=False)
    return c

# ================================================================ 5장 저승 경계
SUUI = R('#2a2620', '#443e34', '#625a4a', '#847a64', '#a89c80', '#c8bc9c')   # 삼베 수의 (hemp burial shroud)


# 망자: 원혼 무리의 한 몸. 삼베 수의에 묶인 발목, 텅 빈 얼굴, 앞으로 뻗은 손. 떼로 몰려온다(소형).
def mangja(phase, pose):
    W, H = 28, 44
    c = Canvas(W, H)
    G = 42
    tell, strike, hurt = pose == 'tell', pose == 'strike', pose == 'hurt'
    bob = (0, 1, 0, 1)[phase] if pose == 'move' else 0
    lean = (1, 0, -1, 0)[phase] if pose == 'move' else (2 if strike else 0)
    cx = 13
    hy = 10 + bob + (3 if hurt else 0)
    robe(c, cx, hy + 6, G, 5, 8, SUUI, sway=lean, ragged=False, base=2.4)
    for y in (hy + 14, hy + 22, G - 4):              # the binding cords of the shroud
        for x in range(cx - 7, cx + 8):
            if c.get(x, y):
                c.set(x, y, SUUI[0])
    c.dome(cx, hy + 7, 6, 3, SUUI, 2.6, top_only=False)
    c.dome(cx, hy, 5, 6, SUUI, 2.8, top_only=False)                  # hooded head
    for y in range(hy - 1, hy + 4):                                   # the face: a hollow
        for x in range(cx - 2, cx + 3):
            c.set(x, y, hx('#08070a') if abs(x - cx) < 2 or y > hy else SUUI[1])
    c.set(cx - 1, hy + 1, hx('#7ab0d0'), outline=False); c.set(cx + 1, hy + 1, hx('#7ab0d0'), outline=False)
    for s in (-1, 1):                                                 # arms reaching forward
        sh = (cx + s * 5, hy + 8)
        hand = (cx + s * 3 + 4, hy + 12) if strike else ((cx + s * 7, hy + 4) if tell else (cx + s * 6, hy + 16 + bob))
        limb(c, *sh, *hand, SUUI, 2, 2.4)
        c.set(hand[0], hand[1] + 1, PALE[2]); c.set(hand[0] + 1, hand[1] + 1, PALE[1])
    return c


# 불개: 해와 달을 물어뜯어 일식을 일으킨다는 불의 개. 숯처럼 검은 몸에 불갈기. 정예·중간보스(일식 연출).
#   예고: 몸을 낮추고 입에 불이 고임. 공격: 도약해 물어뜯기.
BULGAE = R('#060404', '#100a08', '#1c120e', '#2a1a14', '#3c261c', '#523424')
BULGAED = R('#030202', '#080504', '#100a08', '#1a1210', '#26180e')


def bulgae(phase, pose):
    c = big_cat(phase, pose, BULGAE, BULGAED, canine=True, flame=FIRE)
    return c


# 저승 파수꾼: 저승 문을 지키는 장수. 검은 비늘 갑옷, 투구, 창백한 탈, 푸른 눈, 삼지창. 중립 또는 적.
#   예고: 삼지창을 치켜듦. 공격: 앞으로 길게 찌름.
ARMOR = R('#06070c', '#0e1018', '#181c28', '#24293a', '#343a50', '#4a5268')
MASK = R('#6a6e78', '#9a9ea8', '#c4c6cc', '#e2e2e6')
TRI = R('#1a1a22', '#3a3a48', '#6a6a7a', '#9a9aac', '#c8c8d4')


def jeoseung_guard(phase, pose):
    W, H = 54, 72
    c = Canvas(W, H)
    G = 70
    tell, strike, hurt = pose == 'tell', pose == 'strike', pose == 'hurt'
    bob = (0, 0, 1, 1)[phase] if pose == 'move' else 0
    step = (1, 0, -1, 0)[phase] if pose == 'move' else 0
    cx = 22 + (2 if hurt else 0)
    hy = 20 + bob
    # legs in armored greaves
    for s in (-1, 1):
        limb(c, cx + s * 4, hy + 30, cx + s * 5 + step * s, G - 2, ARMOR, 4, 2.2)
        c.rect(cx + s * 5 + step * s - 2, G - 2, 6, 2, ARMOR[1])
    # scale-armour skirt and torso
    for y in range(hy + 10, hy + 34):
        t = (y - hy - 10) / 24
        hw = 8 + t * 4
        for x in range(int(cx - hw), int(cx + hw) + 1):
            scale_ = ((x + (y // 3) % 2 * 2) % 4 == 0) or y % 3 == 0
            c.set(x, y, c.ramp_at(ARMOR, 3.2 - (x - cx) / hw * 1.4 - (1.0 if scale_ else 0)))
    for x in range(cx - 9, cx + 10):                                # red belt cord
        c.set(x, hy + 22, HONG[3] if x % 2 else HONG[2])
    c.dome(cx, hy + 11, 11, 4, ARMOR, 3.0, top_only=False)            # pauldrons
    # helmet with a tall crest, pale expressionless mask, cold blue eyes
    c.dome(cx, hy + 1, 6, 6, MASK, 2.6, top_only=False)
    for y in range(hy - 7, hy + 1):
        for x in range(cx - 7, cx + 8):
            if ((x - cx) / 7.0) ** 2 + ((y - hy + 1) / 7.0) ** 2 <= 1:
                c.set(x, y, c.ramp_at(ARMOR, 3.4 - (x - cx) * 0.2))
    for k in range(8):
        c.set(cx, hy - 8 - k, HONG[3] if k < 6 else HONG[4])
    for ex in (cx - 2, cx + 2):
        c.set(ex, hy + 1, hx('#7ad8ff'), outline=False); c.set(ex, hy, INK)
    c.set(cx, hy + 3, MASK[0]); c.set(cx - 1, hy + 5, MASK[1]); c.set(cx, hy + 5, INK); c.set(cx + 1, hy + 5, MASK[1])
    # trident
    if tell:
        p0, p1 = (cx + 10, hy + 26), (cx + 16, hy - 16)
    elif strike:
        p0, p1 = (cx - 4, hy + 16), (cx + 28, hy + 14)
    else:
        p0, p1 = (cx + 12, G - 2), (cx + 12, hy - 14)
    c.line(*p0, *p1, TRI[2])
    c.line(p0[0] + 1, p0[1], p1[0] + 1, p1[1], TRI[1])
    dx, dy = p1[0] - p0[0], p1[1] - p0[1]
    L = math.hypot(dx, dy); ux, uy = dx / L, dy / L; px_, py_ = -uy, ux
    for o in (-3, 0, 3):                                              # three prongs
        bx_, by_ = p1[0] + px_ * o, p1[1] + py_ * o
        c.line(round(bx_), round(by_), round(bx_ + ux * 5), round(by_ + uy * 5), TRI[4] if o == 0 else TRI[3])
    c.line(round(p1[0] - px_ * 3), round(p1[1] - py_ * 3), round(p1[0] + px_ * 3), round(p1[1] + py_ * 3), TRI[3])
    # gauntlet on the shaft
    hand = (round(p0[0] + dx * 0.45), round(p0[1] + dy * 0.45))
    limb(c, cx + 10, hy + 12, *hand, ARMOR, 3, 2.6)
    c.dome(hand[0], hand[1], 2, 2, ARMOR, 3.2, top_only=False)
    limb(c, cx - 10, hy + 12, cx - 13, hy + 26, ARMOR, 3, 2.4)
    return c


# ================================================================ build
CHAPTERS = {
    1: [('mama', mama, (48, 58)), ('egg_ghost', egg, (34, 56)), ('maiden_ghost', maiden, (34, 56)), ('mulgwi', mulgwi, (56, 46))],
    3: [('fox_minion', fox, (36, 50)), ('songaksi', songaksi, (40, 56)), ('jangseung_taki', jangseung_m, (34, 64))],
    4: [('haetae', haetae, (66, 44)), ('eodukssini', eodukssini, (52, 64)), ('pado', pado, (60, 44))],
    5: [('mangja', mangja, (28, 44)), ('bulgae', bulgae, (66, 48)), ('jeoseung_guard', jeoseung_guard, (54, 72))],
    2: [('dokkaebi_oneeye', oneeye, (48, 56)), ('dokkaebi_fire', firedok, (48, 56)), ('jangsanbeom', jangsanbeom, (66, 44)), ('sangun', sangun, (66, 44))],
}
EXTRAS = {1: [('mama_boil', [mama_boil(i) for i in range(2)], (10, 10))],
          2: [('fire_patch', [fire_patch(i) for i in range(4)], (28, 14))]}


def preview(chapters):
    rows = []
    for ch in chapters:
        ims = [Image.open(en.OUT / f'{n}.png') for n, _, _ in CHAPTERS[ch]] + [Image.open(en.OUT / f'{n}.png') for n, _, _ in EXTRAS.get(ch, [])]
        rows.append(ims)
    W = max(max(i.width for i in r) for r in rows) + 8
    H = sum(sum(i.height + 4 for i in r) for r in rows) + 8
    out = Image.new('RGBA', (W, H), (64, 72, 92, 255))
    y = 4
    for r in rows:
        for im in r:
            out.alpha_composite(im, (4, y)); y += im.height + 4
    out = out.resize((W * 3, H * 3), Image.NEAREST)
    out.save(ROOT / 'out' / 'monsters_preview.png')


def main(chapters=None):
    chapters = chapters or sorted(CHAPTERS)
    for ch in chapters:
        for name, fn, cell in CHAPTERS[ch]:
            sheet7(name, fn, cell)
        for name, frames, cell in EXTRAS.get(ch, []):
            sheet(name, frames, cell)
    preview(chapters)
    print('monsters:', ', '.join(n for ch in chapters for n, _, _ in CHAPTERS[ch]))


if __name__ == '__main__':
    import sys
    main([int(a) for a in sys.argv[1:]] or None)
