"""Combat effects (pixel art, additive in-game): slash crescents and hit sparks.

slash.png  4 frames of 64x64: a crescent of spirit-wind swept by the 대금, opening then thinning out,
           pointing right (+x) — Godot rotates it to the swing direction. Core white, cyan body, blue rim.
spark.png  3 frames of 16x16: a four-pointed star burst for hits.
Combat-strategy cues (CS fx, 2026-10-12) — every sheet is drawn on the pixel grid with the shared palette below
(additive in game, so only bright colours): parry.png, aura.png, fullflash.png, pierce.png, guard.png, weak.png,
open.png, bindmark.png, purify.png, downed.png.  Frame sizes are noted on each function.
Output: src/assets/fx/
"""
import math, pathlib
from PIL import Image

OUT = pathlib.Path(__file__).parent.parent / 'src' / 'assets' / 'fx'
CORE, BODY, RIM, DEEP = (255, 255, 255, 255), (170, 235, 255, 255), (80, 150, 255, 230), (40, 70, 200, 170)


def slash():
    S = 64
    im = Image.new('RGBA', (S * 4, S), (0, 0, 0, 0))
    p = im.load()
    for f in range(4):
        spread = (0.55, 1.0, 1.25, 1.35)[f]   # how far round the arc has swept (radians each side)
        thick = (4.5, 6.5, 4.5, 2.0)[f]
        r0 = (20, 22, 24, 26)[f]
        for y in range(S):
            for x in range(S):
                dx, dy = x + 0.5 - S / 2, y + 0.5 - S / 2
                a = math.atan2(dy, dx)
                if abs(a) > spread:
                    continue
                r = math.hypot(dx, dy)
                taper = 1 - (abs(a) / spread) ** 2       # thick in the middle, pointed tips
                w = thick * taper
                d = r - r0
                if d < -w * 0.4 or d > w:
                    continue
                t = (d + w * 0.4) / (w * 1.4)          # 0 inner edge → 1 outer edge
                col = CORE if t > 0.55 and taper > 0.5 else BODY if t > 0.3 else RIM if t > 0.12 else DEEP
                if f == 3 and (x + y) % 2:
                    continue                            # dissolving
                p[f * S + x, y] = col
    im.save(OUT / 'slash.png')


def spark():
    S = 16
    im = Image.new('RGBA', (S * 3, S), (0, 0, 0, 0))
    p = im.load()
    for f in range(3):
        L = (4, 7, 5)[f]
        for i in range(-L, L + 1):
            for (x, y) in ((8 + i, 8), (8, 8 + i)):
                c = CORE if abs(i) < 2 else BODY if abs(i) < L - 1 else RIM
                if f == 2 and abs(i) < 2:
                    c = BODY
                p[f * S + x, y] = c
        if f == 1:
            for (x, y) in ((6, 6), (10, 6), (6, 10), (10, 10)):
                p[f * S + x, y] = BODY
    im.save(OUT / 'spark.png')




# ---------------------------------------------------------------------------------------------- combat-strategy cues
W = (255, 255, 255, 255)
IC = (205, 245, 255, 255)
CY = (120, 215, 255, 255)
BL = (70, 140, 240, 255)
DB = (40, 80, 190, 255)
G1 = (255, 246, 175, 255)
G2 = (255, 206, 92, 255)
G3 = (232, 142, 52, 255)
OR = (255, 120, 40, 255)
RD = (214, 56, 52, 255)
PU = (160, 100, 220, 255)
PL = (226, 196, 255, 255)
LM = (190, 255, 120, 255)
LG = (110, 200, 80, 255)
PK = (255, 226, 240, 255)
ST = (214, 194, 160, 255)   # shell / armour shard
ST2 = (150, 128, 100, 255)


class Sheet:
    def __init__(self, w, h, cols, rows=1):
        self.w, self.h, self.cols, self.rows = w, h, cols, rows
        self.im = Image.new('RGBA', (w * cols, h * rows), (0, 0, 0, 0))
        self.p = self.im.load()

    def put(self, f, x, y, c, row=0):
        x, y = int(round(x)), int(round(y))
        if 0 <= x < self.w and 0 <= y < self.h:
            self.p[f * self.w + x, row * self.h + y] = c

    def line(self, f, x0, y0, x1, y1, c, row=0, thick=1):
        n = int(max(abs(x1 - x0), abs(y1 - y0))) * 2 + 1
        for i in range(n + 1):
            t = i / n
            x, y = x0 + (x1 - x0) * t, y0 + (y1 - y0) * t
            self.put(f, x, y, c, row)
            if thick > 1:
                for dx, dy in ((1, 0), (0, 1), (-1, 0), (0, -1))[:thick * 2 - 2 if thick < 3 else 4]:
                    self.put(f, x + dx, y + dy, c, row)

    def disc(self, f, cx, cy, r, c, row=0):
        for y in range(int(cy - r) - 1, int(cy + r) + 2):
            for x in range(int(cx - r) - 1, int(cx + r) + 2):
                if (x - cx) ** 2 + (y - cy) ** 2 <= r * r + 0.3:
                    self.put(f, x, y, c, row)

    def ring(self, f, cx, cy, rx, ry, c, row=0, dotted=0, phase=0.0):
        n = max(24, int((rx + ry) * 5))
        for i in range(n):
            if dotted and (i // dotted) % 2:
                continue
            a = i * math.tau / n + phase
            self.put(f, cx + math.cos(a) * rx, cy + math.sin(a) * ry, c, row)

    def save(self, name):
        self.im.save(OUT / name)


def parry():
    """6 frames of 48x48: a white razor-flash (cross + diagonals) that rings out — the instant of 받아넘기기."""
    import random
    rnd = random.Random(7)
    sp = [(rnd.uniform(0, math.tau), rnd.uniform(0.75, 1.0)) for _ in range(9)]
    sh = Sheet(48, 48, 6)
    core = (6, 8, 5, 3, 1, 0)
    L = (9, 23, 20, 15, 9, 4)
    R = (0, 9, 15, 19, 22, 23)
    for f in range(6):
        c = 24
        if core[f]:
            sh.disc(f, c, c, core[f], W)
        col = W if f < 3 else IC if f == 3 else CY
        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            sh.line(f, c + dx * 2, c + dy * 2, c + dx * L[f], c + dy * L[f], col, thick=2 if f < 3 else 1)
        for dx, dy in ((1, 1), (-1, 1), (1, -1), (-1, -1)):
            sh.line(f, c + dx * 3, c + dy * 3, c + dx * (L[f] * 0.55), c + dy * (L[f] * 0.55), IC if f < 4 else CY)
        if R[f]:
            sh.ring(f, c, c, R[f], R[f], W if f == 1 else IC if f == 2 else CY if f == 3 else BL, dotted=0 if f < 3 else 1)
            if f >= 2:
                sh.ring(f, c, c, R[f] - 3, R[f] - 3, BL, dotted=2)
        if f >= 2:
            for a, k in sp[: 3 + f]:
                r = R[f] * k
                sh.put(f, c + math.cos(a) * r, c + math.sin(a) * r, W if f < 5 else IC)
    sh.save('parry.png')


def aura():
    """4 frames x 3 rows of 40x40, loop: rising charge aura around the feet.
    row 0 charging (cool blue) · row 1 ready >= CHARGE_MIN (gold) · row 2 full (white-gold flame)."""
    sh = Sheet(40, 40, 4, 3)
    cx, cy = 20, 32
    cols = ((CY, BL, IC), (G2, G1, G3), (W, G1, G2))

    def flame(f, row, x0, base_y, h, wmax, c_hi, c_mid, c_lo, sway):
        for k in range(h):
            t = k / h
            w = max(0.0, wmax * (1 - t) ** 0.8 * (1.0 if t > 0.12 else 0.7))
            x = x0 + math.sin((k * 0.5) + sway) * 1.3 * t
            col = c_hi if t < 0.3 else c_mid if t < 0.65 else c_lo
            for off in range(-int(w), int(w) + 1):
                if abs(off) < w - 0.2 or off == 0:
                    sh.put(f, x + off, base_y - k, col, row=row)

    for row in range(3):
        a, b, hi = cols[row]
        for f in range(4):
            rx, ry = (13, 6) if row == 0 else (15, 7)
            pul = 1 if f % 2 else 0
            sh.ring(f, cx, cy, rx + pul * (row > 0), ry + pul * 0.5 * (row > 0), b if row < 2 else G1, row=row, dotted=2 if row == 0 else 0, phase=f * 0.4)
            sh.ring(f, cx, cy, rx - 1, ry - 0.7, a if row else BL, row=row, dotted=1 if row == 0 else 0, phase=f * 0.4)
            if row == 2:
                sh.ring(f, cx, cy, rx - 5, ry - 2.3, W, row=row, dotted=1, phase=-f * 0.5)
            nm = (4, 6, 9)[row]
            for i in range(nm):
                ang = i * math.tau / nm + f * 0.35
                bx = cx + math.cos(ang) * rx * 0.85
                by = cy + math.sin(ang) * ry * 0.85
                rise = (f * 5 + i * 7) % 22
                y = by - rise
                for (dx, dy, cc) in ((0, 0, hi), (0, -1, a if rise < 14 else b), (0, 1, a)) if row else ((0, 0, hi), (0, -1, a)):
                    sh.put(f, bx + dx, y + dy, cc, row=row)
            if row == 2:
                for i, ang in enumerate((-2.55, -2.0, -1.57, -1.14, -0.6)):
                    x0 = cx + math.cos(ang) * 12
                    h = (18 if i == 2 else 13) + 3 * ((f + i) % 3)
                    flame(f, row, x0, cy - 2, h, 2.2 if i == 2 else 1.6, W, G1, G2, f * 1.1 + i)
                sh.put(f, cx, 5 + (f % 2), W, row=row)
            if row == 1:
                for i, ang in enumerate((-2.4, -1.57, -0.74)):
                    x0 = cx + math.cos(ang) * 11
                    h = 9 + 3 * ((f + i) % 2)
                    flame(f, row, x0, cy - 2, h, 1.4, G1, G2, G3, f + i)
    sh.save('aura.png')


def fullflash():
    """5 frames of 48x48: the gold sunburst at 만충 (full charge)."""
    sh = Sheet(48, 48, 5)
    c = 24
    for f in range(5):
        k = (0.4, 1.0, 0.85, 0.55, 0.3)[f]
        for i in range(8):
            a = i * math.tau / 8
            L = (22 if i % 2 == 0 else 13) * k
            col = W if f < 2 else G1 if f < 4 else G2
            sh.line(f, c + math.cos(a) * 3, c + math.sin(a) * 3, c + math.cos(a) * L, c + math.sin(a) * L, col, thick=2 if (f in (1, 2) and i % 2 == 0) else 1)
        sh.disc(f, c, c, (5, 7, 5, 3, 1)[f], W)
        if f >= 1:
            sh.ring(f, c, c, 8 + f * 4, 8 + f * 4, G2 if f < 3 else G3, dotted=1 if f > 2 else 0)
    sh.save('fullflash.png')


def pierce():
    """6 frames x 2 rows of 56x56: charged-slash impact. row 0 plain (cool), row 1 armour-ignoring (gold X-crack + shell shards)."""
    import random
    for _ in range(1):
        pass
    sh = Sheet(56, 56, 6, 2)
    c = 28
    for row in range(2):
        rnd = random.Random(11 + row)
        shards = [(rnd.uniform(0, math.tau), rnd.uniform(0.7, 1.15), rnd.choice((2, 3))) for _ in range(11)]
        for f in range(6):
            k = f / 5
            if f < 2:
                sh.disc(f, c, c, (9, 6)[f], W, row=row)
            body = (W, G1, G2, G3, G3, G3) if row else (W, IC, CY, BL, BL, DB)
            # crossing slashes (X) — the cut that goes straight through the shell
            for sgn in (1, -1):
                Lx = (10, 22, 26, 24, 18, 10)[f]
                sh.line(f, c - sgn * Lx, c - Lx * 0.6, c + sgn * Lx, c + Lx * 0.6, body[f], row=row, thick=2 if f < 3 else 1)
            for a, v, sz in shards:
                if f == 0:
                    continue
                r = 6 + v * 20 * (1 - (1 - k) ** 2)
                x, y = c + math.cos(a) * r, c + math.sin(a) * r * 0.85 + f * 0.8 * (1 if row else 0)
                col = (ST if f < 3 else ST2) if row and sz == 3 else (G1 if row else CY)
                for dx in range(sz if f < 4 else 1):
                    for dy in range(2 if f < 4 else 1):
                        sh.put(f, x + dx, y + dy, col, row=row)
            if row == 1 and f in (1, 2, 3):   # chevrons: the blow goes through
                for i in range(3):
                    sh.line(f, c - 14 + i * 4, c - 8 - i, c - 8 + i * 4, c, G1, row=row)
                    sh.line(f, c - 8 + i * 4, c, c - 14 + i * 4, c + 8 + i, G1, row=row)
    sh.save('pierce.png')


def guard():
    """6 frames of 40x40: the 수호부 hexagon flares gold, then bursts into paper-talisman shards."""
    sh = Sheet(40, 40, 6)
    c = 20
    for f in range(6):
        r = (10, 13, 15, 16, 17, 18)[f]
        verts = [(c + math.cos(math.tau * i / 6 + math.pi / 6) * r, c + math.sin(math.tau * i / 6 + math.pi / 6) * r) for i in range(6)]
        if f < 4:
            for i in range(6):
                if f == 3 and i in (1, 4):
                    continue
                a, b = verts[i], verts[(i + 1) % 6]
                sh.line(f, a[0], a[1], b[0], b[1], W if f == 0 else G1 if f < 3 else G2, thick=2 if f < 2 else 1)
            if f < 3:
                sh.line(f, c, c - r * 0.55, c, c + r * 0.55, G2)   # a rune: vertical stroke + two bars
                sh.line(f, c - 3, c - r * 0.25, c + 3, c - r * 0.25, G2)
                sh.line(f, c - 3, c + r * 0.25, c + 3, c + r * 0.25, G2)
            if f == 0:
                sh.disc(f, c, c, 5, W)
        for i in range(6):
            if f >= 2:
                a = math.tau * i / 6 + math.pi / 6
                d = r * 0.9 + (f - 2) * 3.0
                x, y = c + math.cos(a) * d, c + math.sin(a) * d
                for dx in range(2 if f < 5 else 1):
                    for dy in range(3 if f < 5 else 1):
                        sh.put(f, x + dx, y + dy, G1 if f < 4 else G2)
        if f >= 3:
            sh.ring(f, c, c, 6 + (f - 3) * 5, 6 + (f - 3) * 5, G3 if f == 5 else G2, dotted=1)
    sh.save('guard.png')


def weak():
    """4 frames of 16x16: the exposed weak-point mark floating over a stunned enemy (cracked shell, hot core)."""
    sh = Sheet(16, 16, 4)
    for f in range(4):
        c = 8
        r = (5, 6, 6, 5)[f]
        for i in range(-r, r + 1):
            for j in range(-r, r + 1):
                d = abs(i) + abs(j)
                if d == r:
                    sh.put(f, c + i, c + j, G2 if f % 2 == 0 else G1)
                elif d == r - 1:
                    sh.put(f, c + i, c + j, RD)
        for k in range(-r + 2, r - 1):   # the crack
            sh.put(f, c + (k % 2), c + k, W if f % 2 else G1)
        sh.disc(f, c, c, (1.0, 1.0, 1.5, 1.0)[f], W)
        if f in (1, 2):
            sh.put(f, c, 1, G1)
            sh.put(f, c, 14, G1)
    sh.save('weak.png')


def open_ring():
    """3 frames x 2 rows of 48x24: a ground ellipse that breathes. row 0 small enemy · row 1 boss (double ring)."""
    sh = Sheet(48, 24, 3, 2)
    for row in range(2):
        for f in range(3):
            rx = (14 + f, 15 + f, 16 + f)[f] if row == 0 else (19 + f, 20 + f, 21 + f)[f]
            ry = rx * 0.45
            sh.ring(f, 24, 12, rx, ry, G2 if f != 1 else G1, row=row, dotted=1, phase=f * 0.5)
            sh.ring(f, 24, 12, rx - 3, ry - 1.3, RD, row=row, dotted=2, phase=-f * 0.4)
            if row == 1:
                sh.ring(f, 24, 12, rx - 7, ry - 3, G3, row=row, dotted=1, phase=f * 0.8)
    sh.save('open.png')


def bindmark():
    """4 frames x 2 rows of 20x20: the chain over a bound enemy. row 0 lime (결박) · row 1 hot orange + flame (결박 위 화염 ×1.6)."""
    sh = Sheet(20, 20, 4, 2)
    for row in range(2):
        a, b, hi = (LM, LG, W) if row == 0 else (G1, OR, W)
        for f in range(4):
            for (cx, cy) in ((6, 15), (11, 15), (16, 15)):   # three interlocked links
                for dx in range(-3, 4):
                    for dy in range(-2, 3):
                        if (abs(dx) == 3 or abs(dy) == 2) and not (abs(dx) == 3 and abs(dy) == 2):
                            sh.put(f, cx + dx - 1, cy + dy, a if (f + dx + dy) % 5 else hi, row=row)
            if row == 1:   # a flame licking above the chain
                for i, x0 in enumerate((5, 9, 13, 16)):
                    h = 5 + ((f + i) % 3) * 2
                    for k in range(h):
                        w = 1 if k < h - 2 else 0
                        for off in range(-w, w + 1):
                            sh.put(f, x0 + off + (1 if (f + i + k // 3) % 2 else 0), 11 - k, W if k < 2 else G1 if k < 4 else OR, row=row)
            elif f % 2:
                sh.put(f, 9, 8, LM, row=row)
                sh.put(f, 10, 7, W, row=row)
    sh.save('bindmark.png')


def purify():
    """8 frames of 48x64: a lotus blooms on the ground, a pale spirit-orb lifts out and goes up."""
    sh = Sheet(48, 64, 8)
    cx, base = 24, 52
    for f in range(8):
        k = min(1.0, f / 4.0)
        sh.ring(f, cx, base, 18 * (0.5 + 0.5 * k), 7 * (0.5 + 0.5 * k), G1 if f < 5 else G2, dotted=0 if f < 4 else 1)
        for ang in (-72, -36, 0, 36, 72):   # five petals fanning up
            a = math.radians(ang - 90)
            Lp = 5 + 15 * k - (f - 5) * 2.0 * (f > 5)
            if Lp < 2:
                continue
            for s in range(int(Lp * 2)):
                t = s / (Lp * 2)
                w = math.sin(t * math.pi) * (2.2 if f > 1 else 1.2)
                x = cx + math.cos(a) * Lp * t + (ang / 90.0) * t * 7 * k
                y = base + math.sin(a) * Lp * t * 1.0 - 1
                col = W if t > 0.55 and f in (3, 4) else PK if t > 0.3 else G1
                for off in range(-int(w), int(w) + 1):
                    sh.put(f, x + off, y, col if abs(off) < w - 0.4 else G2)
        if f >= 2:   # the orb of cleared 탁기 rising
            oy = base - 8 - (f - 2) * 6.5
            sh.disc(f, cx, oy, 3.2 if f < 7 else 2.0, W)
            sh.ring(f, cx, oy, 5.5, 5.5, CY, dotted=2, phase=f)
            for j in range(1, 5):
                sh.put(f, cx + math.sin(j + f) * 1.5, oy + 5 + j * 2, IC if j < 3 else CY)
        for i in range(7):   # drifting motes
            a = i * 0.9 + f * 0.5
            sh.put(f, cx + math.cos(a) * (6 + 2 * i), base - 4 - ((f * 5 + i * 9) % 30), G1 if i % 2 else W)
    sh.save('purify.png')


def downed():
    """4 frames of 40x20: the violet sigil under a collapsed 요괴 — it is waiting for the song."""
    sh = Sheet(40, 20, 4)
    for f in range(4):
        sh.ring(f, 20, 10, 15, 6.5, PU, dotted=1, phase=f * 0.5)
        sh.ring(f, 20, 10, 10, 4.2, PL, dotted=2, phase=-f * 0.7)
        for i in range(4):
            a = i * math.pi / 2 + f * 0.3
            sh.put(f, 20 + math.cos(a) * 15, 10 + math.sin(a) * 6.5, W)
    sh.save('downed.png')


def tellock():
    """5 frames of 32x32: 예고가 굳는 순간(진행 50%) — 몸 위로 작은 빛 틱(네 점 + 십자 눈금)이 모여 '딸깍' 잠긴다."""
    sh = Sheet(32, 32, 5)
    c = 16
    for f in range(5):
        r = (13, 10, 7, 6, 8)[f]
        col = (IC, W, W, G1, G2)[f]
        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):   # four ticks converge on the body
            for k in range(2 if f < 4 else 1):
                sh.put(f, c + dx * (r + k), c + dy * (r + k), col)
        if f >= 2:
            for dx, dy in ((1, 1), (-1, 1), (1, -1), (-1, -1)):
                sh.put(f, c + dx * (r - 2), c + dy * (r - 2), G2 if f == 2 else G1)
        if f in (2, 3):
            sh.ring(f, c, c, 5, 5, W if f == 2 else G1, dotted=1)
            sh.put(f, c, c, W)
    sh.save('tellock.png')


if __name__ == '__main__':
    OUT.mkdir(parents=True, exist_ok=True)
    slash(); spark()
    for fn in (parry, aura, fullflash, pierce, guard, weak, open_ring, bindmark, purify, downed, tellock):
        fn()
    print('fx: slash, spark, parry, aura, fullflash, pierce, guard, weak, open, bindmark, purify, downed, tellock')
