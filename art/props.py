"""Village props (hand-drawn; 집·석등·장승·석축·돌담 are voxel models in vox.py): 금줄, 솟대, 서낭나무, 돌무더기, 석등, 소나무.

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


def tal():
    """처용탈 걸린 대문 기둥: a short gate post with the red 처용 mask hung on a nail — people hang it
    on their doors against plague (SC1-21)."""
    c = Canvas(18, 40)
    c.cylinder(6, 2, 6, 38, WOOD, 2.0, rings=9)
    MASK = R('#3a0a0c', '#6a1416', '#9a2420', '#c4382a', '#e05a3a')
    cx, cy = 9, 15
    c.dome(cx, cy, 6.5, 7.5, MASK, 2.6, top_only=False)
    for x in range(cx - 6, cx + 7):           # black 사모 brim on top, peony blossoms either side
        c.set(x, cy - 7, INK)
    for x in range(cx - 4, cx + 5):
        c.set(x, cy - 8, INK); c.set(x, cy - 9, INK)
    c.set(cx - 7, cy - 6, RED[4]); c.set(cx + 7, cy - 6, RED[4])
    for (x, y) in ((cx - 3, cy - 1), (cx + 2, cy - 1)):   # wide eyes
        c.set(x, y, INK); c.set(x + 1, y, INK)
    c.set(cx - 2, cy - 2, PAPER[4], outline=False); c.set(cx + 3, cy - 2, PAPER[4], outline=False)
    for x in range(cx - 3, cx + 4):            # broad grin with white teeth
        c.set(x, cy + 3, INK)
        c.set(x, cy + 4, PAPER[4] if x % 2 else PAPER[3])
    c.set(cx, cy + 1, MASK[1])
    c.line(cx, cy - 10, cx, cy - 12, INK)     # string to the nail
    c.save('tal')


def irworobong():
    """일월오봉도: the royal folding screen — red sun, white moon, five peaks, pines, waterfalls, waves.
    Drawn in deep night-dimmed colours; it stands behind the throne."""
    W, H = 104, 60
    c = Canvas(W, H)
    FRAME = R('#2a0a0e', '#4e1218', '#7a1e20', '#a32e28')
    SKY = R('#0a1430', '#122048', '#1a2c5e')
    PEAK = R('#0c2418', '#143a26', '#1e5234', '#2c6e44', '#3e8a56')
    WAVE = R('#0e1e3a', '#1a3460', '#3a5a8a', '#8aa8c8')
    for y in range(H):
        for x in range(W):
            panel = x // 26
            if y < 2 or y >= H - 2 or x % 26 in (0, 25):
                c.set(x, y, FRAME[2] if (y < 2 or x % 26 == 0) else FRAME[1])
                continue
            t = 1.2 + (y / H) * 1.2
            col = SKY[min(2, int(t))]
            # five peaks: one big centre, two each side
            peaks = [(52, 14, 20), (26, 24, 14), (78, 24, 14), (10, 32, 10), (94, 32, 10)]
            for (px, top, hw) in peaks:
                if y >= top + abs(x - px) * (H - 18 - top) / hw * 0.9 and y < H - 16:
                    col = PEAK[max(0, min(4, int(3.6 - (x - px) / hw * 1.4 - (y - top) * 0.05)))]
            if y >= H - 16:                    # waves
                k = (x + (y % 4) * 3) % 9
                col = WAVE[3] if k == 0 and y % 4 == 0 else WAVE[1 + (y % 4 == 1)]
            c.set(x, y, col)
    for (sx, sy, r, cl) in ((20, 10, 4, RED[4]), (84, 10, 4, PAPER[4])):    # sun (red) and moon (white)
        for y in range(sy - r, sy + r + 1):
            for x in range(sx - r, sx + r + 1):
                if (x - sx) ** 2 + (y - sy) ** 2 <= r * r:
                    c.set(x, y, cl, outline=False)
    for wx in (38, 66):                        # waterfalls
        for y in range(28, H - 16):
            c.set(wx, y, WAVE[3]); c.set(wx + 1, y, WAVE[2])
    for (tx, ty) in ((6, 40), (98, 40)):       # red-trunked pines at the edges
        c.line(tx, ty, tx, H - 16, RED[2])
        for k in range(3):
            for x in range(tx - 3 + k, tx + 4 - k):
                c.set(x, ty - 2 + k * 3, PEAK[3])
    c.save('irworobong')


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    geumjul(); sotdae('sotdae', 52); sotdae('sotdae_s', 40); seonang(); cairn(); pine(); tal(); irworobong()
    # contact sheet for review
    names = ['geumjul', 'sotdae', 'sotdae_s', 'seonang', 'cairn', 'pine']
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
