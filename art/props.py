"""Village props (hand-drawn): 장승, 금줄, 솟대, 서낭나무, 돌무더기, 석등, 소나무.

Drawn pixel by pixel with a few shading rules (light from the upper left, violet-black ink outline
added automatically around every silhouette). Each prop is anchored at the bottom-centre of its
canvas (where it touches the ground). Output: godot/assets/props/<name>.png
"""
import math, pathlib, random
from PIL import Image

ROOT = pathlib.Path(__file__).parent
OUT = ROOT.parent / 'godot' / 'assets' / 'props'


def hx(h):
    h = h.lstrip('#')
    return (int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16), 255)


def R(*cs):
    return [hx(c) for c in cs]


INK = hx('#07060b')
WOOD = R('#140e0d', '#22181a', '#33241f', '#4a3528', '#644a35', '#7e6244')
THATCH = R('#17120d', '#251d13', '#382c19', '#4e3f22', '#66542c', '#82703c')
MUD = R('#1c1618', '#2a2224', '#3a2f2c', '#4c3f36', '#605042', '#766450')
STONE = R('#0f0f16', '#1a1b25', '#262836', '#353849', '#474b5e', '#5e6378')
PINE = R('#08100e', '#0e1a16', '#152620', '#1e352a', '#2a4836', '#3c5e44')
BARK = R('#1a0f0f', '#2a1816', '#3c221e', '#553028', '#6e4034')
RED = R('#2a0a0e', '#4e1218', '#7a1e20', '#a32e28', '#c8483a')
PAPER = R('#5a5868', '#86848e', '#aeaaa8', '#d0cabc', '#ece6d6')
GLOW = R('#6a3a1a', '#b86a2a', '#e8a048', '#ffd27a', '#fff2c0')
GREEN = R('#14301a', '#2a5a22', '#4e9a34', '#8ae04a', '#ccff88')


class Canvas:
    def __init__(self, w, h):
        self.w, self.h = w, h
        self.px = [[None] * w for _ in range(h)]
        self.nol = [[False] * w for _ in range(h)]  # pixels that skip the outline (glows)

    def set(self, x, y, c, outline=True):
        x, y = int(x), int(y)
        if 0 <= x < self.w and 0 <= y < self.h and c is not None:
            self.px[y][x] = c
            self.nol[y][x] = not outline

    def get(self, x, y):
        return self.px[y][x] if 0 <= x < self.w and 0 <= y < self.h else None

    def rect(self, x, y, w, h, c):
        for j in range(h):
            for i in range(w):
                self.set(x + i, y + j, c)

    def ramp_at(self, ramp, t):
        return ramp[max(0, min(len(ramp) - 1, int(round(t))))]

    def cylinder(self, x, y, w, h, ramp, base=2.0, rings=0):
        """Vertical log/post: lit left side, shadowed right, optional growth rings / grain."""
        for j in range(h):
            for i in range(w):
                u = (i + 0.5) / w
                t = base + 1.4 - u * 2.6 + (0.6 if i == 0 else 0)
                if rings and (j * 7 + i * 3) % rings == 0:
                    t -= 1
                self.set(x + i, y + j, self.ramp_at(ramp, t))

    def dome(self, cx, cy, rx, ry, ramp, base=2.0, top_only=True, tex=None):
        for y in range(int(cy - ry) - 1, int(cy + ry) + 2):
            for x in range(int(cx - rx) - 1, int(cx + rx) + 2):
                dx, dy = (x + 0.5 - cx) / rx, (y + 0.5 - cy) / ry
                r = dx * dx + dy * dy
                if r > 1 or (top_only and dy > 0):
                    continue
                nz = math.sqrt(1 - r)
                lam = -dx * 0.55 - dy * 0.75 + nz * 0.6
                t = base + lam * 2.2
                if tex:
                    t += tex(x, y)
                self.set(x, y, self.ramp_at(ramp, t))

    def poly(self, pts, cfn):
        xs = [p[0] for p in pts]; ys = [p[1] for p in pts]
        for y in range(int(min(ys)), int(max(ys)) + 1):
            for x in range(int(min(xs)), int(max(xs)) + 1):
                px, py = x + 0.5, y + 0.5
                ins = False
                j = len(pts) - 1
                for i in range(len(pts)):
                    xi, yi = pts[i]; xj, yj = pts[j]
                    if (yi > py) != (yj > py) and px < (xj - xi) * (py - yi) / (yj - yi) + xi:
                        ins = not ins
                    j = i
                if ins:
                    c = cfn(x, y)
                    if c is not None:
                        self.set(x, y, c)

    def line(self, x0, y0, x1, y1, c, outline=True):
        n = max(1, int(max(abs(x1 - x0), abs(y1 - y0)) * 1.5))
        for i in range(n + 1):
            self.set(round(x0 + (x1 - x0) * i / n), round(y0 + (y1 - y0) * i / n), c, outline)

    def save(self, name, outline=True):
        img = Image.new('RGBA', (self.w, self.h), (0, 0, 0, 0))
        p = img.load()
        for y in range(self.h):
            for x in range(self.w):
                if self.px[y][x] is not None:
                    p[x, y] = self.px[y][x]
        if outline:
            for y in range(self.h):
                for x in range(self.w):
                    if self.px[y][x] is not None:
                        continue
                    for dx, dy in ((0, -1), (-1, 0), (1, 0), (0, 1)):
                        nx, ny = x + dx, y + dy
                        if 0 <= nx < self.w and 0 <= ny < self.h and self.px[ny][nx] is not None and not self.nol[ny][nx]:
                            p[x, y] = INK
                            break
        img.save(OUT / f'{name}.png')
        # emissive pixels (paper windows, flames) also go to <name>_glow.png, drawn unlit in-game
        if any(any(r) for r in self.nol):
            glow = Image.new('RGBA', (self.w, self.h), (0, 0, 0, 0))
            g = glow.load()
            for y in range(self.h):
                for x in range(self.w):
                    if self.nol[y][x] and self.px[y][x] is not None:
                        g[x, y] = self.px[y][x]
            glow.save(OUT / f'{name}_glow.png')
        return img


def hashf(x, y, s=0):
    h = (x * 374761393 + y * 668265263 + s * 982451653) & 0xffffffff
    h = ((h ^ (h >> 13)) * 1274126177) & 0xffffffff
    return (h ^ (h >> 16)) / 4294967296


# ---------------------------------------------------------------- 초가집 (thatched house), 96x84
def house():
    c = Canvas(96, 84)
    # stone plinth (기단)
    for x in range(10, 86):
        for y in range(74, 82):
            row = (y - 74) // 4
            bx = (x + row * 5) // 9
            edge = (x + row * 5) % 9 == 0 or (y - 74) % 4 == 0
            t = 2 + hashf(bx, row, 3) * 1.4 - (0.6 if y >= 80 else 0) + (0.8 if (y - 74) % 4 == 1 else 0)
            c.set(x, y, STONE[0] if edge else c.ramp_at(STONE, t))
    # earthen walls between timber posts
    for x in range(14, 82):
        for y in range(46, 74):
            t = 2.2 + hashf(x // 2, y // 3, 5) * 0.8 - (y - 46) * 0.03 - (x - 14) * 0.012
            if hashf(x // 3, y // 3, 9) > 0.93:
                t -= 1.2  # cracks where the plaster flaked
            c.set(x, y, c.ramp_at(MUD, t))
    for px_ in (14, 34, 60, 78):
        c.cylinder(px_, 44, 4, 30, WOOD, base=2.2)
    c.cylinder(14, 50, 68, 3, WOOD, base=1.6)  # lintel beam (drawn as a flat log)
    for x in range(14, 82):
        c.set(x, 50, WOOD[4]); c.set(x, 52, WOOD[1])
    # paper-latticed door, faint warm light behind it
    for x in range(40, 56):
        for y in range(55, 74):
            lattice = (x - 40) % 5 == 0 or (y - 55) % 6 == 0 or x == 55
            if lattice:
                c.set(x, y, WOOD[1])
            else:
                c.set(x, y, GLOW[1] if y > 66 else GLOW[2], outline=False)
    # small window
    for x in range(64, 74):
        for y in range(57, 64):
            if (x - 64) % 3 == 0 or y in (57, 63):
                c.set(x, y, WOOD[1])
            else:
                c.set(x, y, GLOW[1], outline=False)
    # thatched roof: thick rounded mound with heavy eaves
    def thatch_tex(x, y):
        streak = (hashf(x, y // 3, 11) - 0.5) * 1.2
        if (y + (x // 6)) % 7 == 0:
            streak -= 0.8  # straw layers
        return streak
    c.dome(48, 46, 46, 34, THATCH, base=2.0, tex=thatch_tex)
    # eave lip: dark underside shadow and ragged straw ends
    for x in range(3, 94):
        dx = (x + 0.5 - 48) / 46
        if abs(dx) > 1:
            continue
        ye = 46
        for k in range(3):
            c.set(x, ye + k, THATCH[1] if k < 2 else THATCH[0])
        if hashf(x, 1, 13) > 0.45:
            c.set(x, ye + 3, THATCH[2])
    # straw ropes binding the roof (새끼줄 grid)
    for i, ax in enumerate((-30, -10, 10, 30)):
        for y in range(13, 46):
            dy = (y + 0.5 - 46) / 34
            x = 48 + ax * math.sqrt(max(0, 1 - dy * dy)) * 1.0
            if c.get(int(x), y):
                c.set(int(x), y, THATCH[4] if i < 2 else THATCH[3])
    for y in (24, 36):
        dy = (y + 0.5 - 46) / 34
        half = 46 * math.sqrt(max(0, 1 - dy * dy))
        for x in range(int(48 - half) + 2, int(48 + half) - 1):
            if c.get(x, y) and (x % 3):
                c.set(x, y, THATCH[3] if x < 48 else THATCH[2])
    # chimney smoke stain and a talisman pasted by the door (역병 막이)
    for y in range(58, 66):
        c.set(37, y, PAPER[3]); c.set(38, y, PAPER[2])
    c.set(37, 60, RED[3]); c.set(38, 61, RED[3]); c.set(37, 62, RED[2])
    return c.save('house')


# ---------------------------------------------------------------- 장승 pair element (one post), 16x48
def jangseung(name, red):
    c = Canvas(18, 50)
    wood = RED if red else WOOD
    c.cylinder(4, 14, 10, 34, WOOD, base=1.8, rings=11)
    # head block: bulging carved face
    c.dome(9, 10, 6.5, 9, wood, base=2.2, top_only=False)
    c.rect(3, 0, 12, 3, BARK[1]); c.rect(4, 0, 10, 1, BARK[2])  # 관모 cap
    # eyes: big round, staring
    for ex in (6, 11):
        c.set(ex, 8, PAPER[4]); c.set(ex + 1, 8, PAPER[3]); c.set(ex, 9, PAPER[3]); c.set(ex + 1, 9, INK)
    c.line(4, 6, 8, 7, INK); c.line(10, 7, 14, 6, INK)  # furious brows
    c.set(9, 11, WOOD[1]); c.set(9, 12, WOOD[1])  # nose
    # grinning fanged mouth
    for x in range(5, 14):
        c.set(x, 15, INK)
    c.set(6, 16, PAPER[4]); c.set(12, 16, PAPER[4]); c.set(6, 14, PAPER[3]); c.set(12, 14, PAPER[3])
    # carved inscription column (天下大將軍 / 地下女將軍 as abstract strokes)
    for y in range(22, 46, 4):
        c.line(8, y, 11, y, WOOD[0]); c.set(9, y + 1, WOOD[0]); c.set(10, y + 2, WOOD[0])
    return c.save(name)


# ---------------------------------------------------------------- 금줄 rope between two stakes, 56x34
def geumjul():
    c = Canvas(58, 36)
    for sx in (2, 52):
        c.cylinder(sx, 6, 4, 30, WOOD, base=2.0)
    # sagging straw rope, twisted (alternating tones)
    pts = []
    for i in range(49):
        x = 5 + i
        y = 9 + 7 * math.sin(math.pi * i / 48)
        pts.append((x, y))
        c.set(x, round(y), THATCH[4] if i % 2 else THATCH[2])
        c.set(x, round(y) + 1, THATCH[1])
    # hanging white paper strips, charcoal and red peppers (금줄 for warding)
    for k, i in enumerate(range(5, 46, 5)):
        x, y = pts[i]
        y = round(y) + 2
        kind = k % 3
        if kind == 0:
            for j in range(7):
                c.set(x, y + j, PAPER[4] if j < 2 else PAPER[3]); c.set(x + 1, y + j, PAPER[2])
            c.set(x, y + 7, PAPER[2])
        elif kind == 1:
            c.rect(x, y, 2, 3, STONE[0]); c.set(x, y, STONE[2])
        else:
            for j in range(4):
                c.set(x, y + j, RED[4] if j == 0 else RED[3]); c.set(x + 1, y + j + 1, RED[2])
    return c.save('geumjul')


# ---------------------------------------------------------------- 솟대 (wooden bird on a pole), 14x64
def sotdae(name, h):
    c = Canvas(16, h + 10)
    c.cylinder(7, 9, 2, h, WOOD, base=1.6)
    # carved duck facing right, wings tucked
    for (x, y, t) in [(3, 5, 3), (4, 5, 3), (5, 5, 3), (6, 5, 2), (7, 5, 2), (8, 5, 2), (9, 5, 2), (10, 5, 1),
                      (4, 6, 2), (5, 6, 2), (6, 6, 2), (7, 6, 1), (8, 6, 1), (9, 6, 1), (10, 6, 1),
                      (5, 7, 1), (6, 7, 1), (7, 7, 1), (8, 7, 0), (9, 7, 0),
                      (10, 4, 3), (11, 3, 3), (11, 4, 2), (12, 3, 2), (13, 4, 1), (14, 4, 1)]:
        c.set(x, y, WOOD[t + 1])
    c.set(2, 4, WOOD[3]); c.set(12, 3, INK)
    return c.save(name)


# ---------------------------------------------------------------- 서낭나무 (old dead tree with cloth strips), 72x88
def seonang():
    c = Canvas(76, 92)
    rnd = random.Random(7)
    # gnarled trunk widening at the roots
    for y in range(40, 90):
        t = (y - 40) / 50
        hw = 5 + 4 * t * t + (3 if y > 84 else 0)
        cx = 38 + math.sin(y * 0.15) * 2
        for x in range(int(cx - hw), int(cx + hw) + 1):
            u = (x + 0.5 - (cx - hw)) / (2 * hw)
            tone = 3.0 - u * 2.6 + (hashf(x, y // 2, 4) - 0.5) * 0.9
            if (y + x * 2) % 9 == 0:
                tone -= 0.8
            c.set(x, y, c.ramp_at(BARK, tone))
    # hollow
    for y in range(58, 66):
        for x in range(36, 41):
            if (x - 38) ** 2 / 6 + (y - 62) ** 2 / 16 < 1:
                c.set(x, y, INK)
    # bare twisted branches
    def branch(x, y, ang, length, w):
        if length < 4:
            return
        for i in range(int(length)):
            x += math.cos(ang); y += math.sin(ang)
            for k in range(int(w)):
                c.set(x + (k if abs(math.sin(ang)) > 0.5 else 0), y + (k if abs(math.sin(ang)) <= 0.5 else 0), BARK[2 if k == 0 else 1])
            ang += rnd.uniform(-0.18, 0.18)
        for d in (-0.6, 0.55):
            if rnd.random() < 0.85:
                branch(x, y, ang + d, length * 0.62, max(1, w - 1))
    for a, L in ((-1.1, 26), (-1.9, 30), (-2.5, 22), (-0.6, 22)):
        branch(38, 42, a, L, 3)
    # cloth strips (오방색 faded: red, white, blue-black) and a rope around the trunk
    for y in (52, 53):
        for x in range(31, 47):
            if c.get(x, y):
                c.set(x, y, THATCH[4] if (x + y) % 2 else THATCH[2])
    for k in range(9):
        x = 33 + k * 1.7
        col = (RED, PAPER, STONE)[k % 3]
        L = 6 + (k * 5) % 7
        for j in range(L):
            c.set(round(x + math.sin(j * 0.5 + k) * 0.6), 54 + j, col[3 if j < 2 else 2])
    for (bx, by) in ((20, 22), (52, 18), (14, 34), (60, 30), (30, 10)):
        col = (RED, PAPER)[(bx + by) % 2]
        for j in range(6):
            c.set(bx, by + j, col[3 if j < 2 else 2]); c.set(bx + 1, by + j + 1, col[2])
    return c.save('seonang')


# ---------------------------------------------------------------- 돌무더기 (서낭당 cairn), 30x24
def cairn():
    c = Canvas(30, 24)
    rnd = random.Random(3)
    stones = [(15, 18, 7, 5), (8, 19, 5, 4), (22, 19, 6, 4), (12, 13, 5, 4), (19, 13, 5, 4), (15, 8, 4, 3), (15, 4, 3, 2)]
    for (sx, sy, rx, ry) in stones:
        c.dome(sx, sy, rx, ry, STONE, base=2 + rnd.random(), top_only=False)
    return c.save('cairn')


# ---------------------------------------------------------------- 석등 (stone lantern, lit), 18x40
def lantern():
    c = Canvas(20, 42)
    c.cylinder(4, 36, 12, 5, STONE, base=2.0)   # base
    c.cylinder(8, 22, 4, 14, STONE, base=2.2)   # shaft
    c.cylinder(3, 19, 14, 3, STONE, base=2.0)   # fire chamber floor
    c.cylinder(4, 10, 12, 9, STONE, base=2.0)   # fire chamber
    for x in range(6, 14):
        for y in range(12, 18):
            c.set(x, y, GLOW[3] if 8 <= x <= 11 and 13 <= y <= 16 else GLOW[2], outline=False)
    c.cylinder(9, 10, 2, 9, STONE, base=1.5)    # mullion
    c.poly([(1, 10), (19, 10), (14, 4), (6, 4)], lambda x, y: c.ramp_at(STONE, 3.4 - (x - 1) * 0.12))  # roof
    c.rect(8, 1, 4, 3, STONE[3])
    return c.save('lantern')


# ---------------------------------------------------------------- 소나무 (twisted pine), 56x84
def pine():
    c = Canvas(60, 88)
    rnd = random.Random(21)
    # leaning red trunk
    for y in range(30, 86):
        t = (y - 30) / 56
        cx = 30 + math.sin(t * 2.4 + 0.5) * 6 - t * 4
        hw = 3 + t * 2.2
        for x in range(int(cx - hw), int(cx + hw) + 1):
            u = (x + 0.5 - (cx - hw)) / (2 * hw)
            tone = 3.0 - u * 2.6 + (0.8 if (y // 3 + x) % 5 == 0 else 0) - (0.7 if (y + x) % 7 == 0 else 0)
            c.set(x, y, c.ramp_at(BARK, tone))
    # cloud-like needle pads (layered, darker underneath)
    pads = [(30, 30, 18, 7), (14, 40, 12, 6), (44, 38, 13, 6), (24, 18, 15, 6), (38, 22, 12, 5), (30, 9, 10, 5), (18, 52, 9, 4)]
    for (px_, py_, rx, ry) in pads:
        def tex(x, y):
            return 0.9 if hashf(x // 2, y, 31) > 0.82 else (-0.9 if hashf(x, y // 2, 37) > 0.85 else 0)
        c.dome(px_, py_, rx, ry, PINE, base=2.0, top_only=False, tex=tex)
        for x in range(int(px_ - rx), int(px_ + rx)):
            if c.get(x, int(py_ + ry) - 1):
                c.set(x, int(py_ + ry) - 1, PINE[0])
    return c.save('pine')


# ---------------------------------------------------------------- 석축 (dry-stone retaining wall), w x 36
def seokchuk(name, w, stair_at=None):
    """Big dressed granite blocks in staggered courses, grass lip spilling over the top, dark wet foot.
    stair_at: x offset of a 32px stone stair cut into the wall."""
    H = 36
    c = Canvas(w, H)
    rnd = random.Random(w * 7 + 1)
    # courses of blocks (rows of varying height), joints staggered
    y = 4
    rows = []
    while y < H - 2:
        hgt = rnd.choice((7, 8, 9))
        rows.append((y, min(hgt, H - 2 - y)))
        y += hgt
    for ri, (y0, hh) in enumerate(rows):
        x = -rnd.randint(0, 10)
        while x < w:
            bw = rnd.randint(11, 20)
            shade = rnd.random()
            for yy in range(y0, y0 + hh):
                for xx in range(max(0, x), min(w, x + bw)):
                    lx, ly = xx - x, yy - y0
                    if lx == 0 or ly == 0:
                        col = STONE[0]
                    else:
                        t = 2.9 + shade * 1.2 - ly * 0.1 - (yy / H) * 1.1
                        if ly == 1 or lx == 1: t += 1.2  # lit bevel (upper left)
                        if ly == hh - 1 or lx == bw - 1: t -= 1.0
                        if hashf(xx, yy, 41) > 0.93: t -= 0.8  # pitting
                        col = c.ramp_at(STONE, t)
                    c.set(xx, yy, col)
            x += bw
    # coping: grass lip spilling over the top edge
    for xx in range(w):
        drop = 1 + int(hashf(xx // 2, 0, 43) * 3)
        for yy in range(0, 3 + drop):
            c.set(xx, yy, PINE[4] if yy < 2 else (PINE[3] if yy < 2 + drop - 1 else PINE[1]))
        if hashf(xx, 1, 44) > 0.6:
            c.set(xx, 0, PINE[4])
    # moss in the joints, dark damp foot
    for xx in range(w):
        for yy in range(H - 3, H):
            if c.get(xx, yy):
                c.set(xx, yy, STONE[0] if yy > H - 2 else STONE[1])
        if hashf(xx, 2, 45) > 0.85:
            for yy in range(4, H - 3):
                if c.get(xx, yy) == STONE[0] and hashf(xx, yy, 46) > 0.6:
                    c.set(xx, yy, PINE[2])
    if stair_at is not None:
        for xx in range(stair_at, stair_at + 32):
            for yy in range(H):
                step = yy // 6
                lx = xx - stair_at
                if lx == 0 or lx == 31:
                    col = STONE[1]
                else:
                    t = 1.8 + (yy % 6 == 0) * 1.6 - (yy % 6 == 5) * 0.8 + hashf(xx // 8, step, 47) * 0.6 + step * 0.15
                    col = c.ramp_at(STONE, t)
                c.set(xx, yy, col)
    return c.save(name)


def seokchuk_side(name, h):
    """East end of the terrace seen from above: a narrow column of stacked stones."""
    c = Canvas(9, h)
    y = 0
    k = 0
    while y < h:
        bh = 5 + (k * 7) % 4
        for yy in range(y, min(h, y + bh)):
            for xx in range(9):
                t = 2.2 - xx * 0.18 + (1.2 if yy == y + 1 else 0) - (0.9 if yy == y + bh - 1 else 0)
                c.set(xx, yy, STONE[0] if yy == y else c.ramp_at(STONE, t))
        y += bh; k += 1
    for yy in range(h):
        c.set(0, yy, PINE[2] if hashf(0, yy // 3, 48) > 0.5 else PINE[1])
    return c.save(name)


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    jangseung('jangseung_m', False); jangseung('jangseung_f', True)
    seokchuk('seokchuk', 240, stair_at=152); seokchuk_side('seokchuk_side', 118); geumjul(); sotdae('sotdae', 52); sotdae('sotdae_s', 40); seonang(); cairn(); lantern(); pine()
    # contact sheet for review
    names = ['seokchuk', 'jangseung_m', 'jangseung_f', 'geumjul', 'sotdae', 'sotdae_s', 'seonang', 'cairn', 'lantern', 'pine']
    ims = [Image.open(OUT / f'{n}.png') for n in names]
    W = sum(i.width for i in ims) + 6 * len(ims); H = max(i.height for i in ims)
    sheet = Image.new('RGBA', (W, H), (60, 66, 84, 255))
    x = 0
    for im in ims:
        sheet.alpha_composite(im, (x, H - im.height)); x += im.width + 6
    sheet.resize((W * 4, H * 4), Image.NEAREST).save(ROOT / 'out' / 'props_preview.png')
    print('props:', ', '.join(names))


if __name__ == '__main__':
    main()
