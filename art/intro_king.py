"""용왕이 병석에 누운 모습 — 인트로 샷 2~3 의 전용 스프라이트 (80x36, 옆모습).

옛 구현은 서 있는 NPC 시트(npc_dragonking)를 -90° 로 돌려 썼다 → 회전 픽셀이 뭉개지고 머리·팔·관이 엉뚱한 곳에 붙었다.
여기서는 '침상에 누운 사람' 을 처음부터 그린다: 왼쪽 끝 베개에 머리(얼굴은 카메라 쪽으로 살짝 돌림),
용뿔·금 머리띠, 가슴 위로 흐르는 흰 수염, 침구를 덮은 몸(어깨→배→무릎→발 순으로 낮아지는 둔덕), 이불 앞자락이 침상 앞으로 드리워짐,
카메라 쪽 팔은 이불 위에 올려 손에 용인(龍印)을 쥠.
Output: src/assets/intro/intro_king.png  (좌표계: x 0 = 머리 쪽, 침상 윗면 = y 27)
"""
import pathlib
import numpy as np
from PIL import Image

OUT = pathlib.Path(__file__).parent.parent / 'src' / 'assets' / 'intro'
W, H = 80, 36
TOP = 27          # 침상 윗면 높이(몸이 닿는 선)
HAND = (47, 17)   # 용패를 쥔 손 (스프라이트 좌표)


def hx(h):
    h = h.lstrip('#'); return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4)) + (255,)


img = np.zeros((H, W, 4), np.uint8)


def put(x, y, c):
    if 0 <= x < W and 0 <= y < H:
        img[y, x] = c


def fill(mask, shader):
    ys, xs = np.nonzero(mask)
    for y, x in zip(ys, xs):
        put(x, y, shader(x, y))


YY, XX = np.mgrid[0:H, 0:W]


def ell(cx, cy, rx, ry):
    return ((XX - cx) / rx) ** 2 + ((YY - cy) / ry) ** 2 <= 1.0


# ---- 1. 베개 (비단, 금 술)
pil = ell(12, 22.5, 12, 5.2) & (YY <= TOP)
fill(pil, lambda x, y: hx('#a9c0c4') if y < 20 else hx('#7e9aa2') if y < 24 else hx('#566e7a'))
for x in range(2, 24):        # 윗선 하이라이트
    if pil[19, x] or pil[18, x]:
        put(x, 18 if pil[18, x] else 19, hx('#d4e4e4'))
for y in (22, 24):            # 베개 수놓은 금실
    for x in range(4, 22, 2):
        if pil[y, x]: put(x, y, hx('#c8a050'))
for (x, y) in ((1, 24), (1, 25), (1, 26), (0, 26)):   # 술
    put(x, y, hx('#d8b45a'))

# ---- 2. 몸(이불) — 어깨에서 발끝으로 낮아지는 둔덕
def body_top(x):
    if x < 22: return 99
    pts = [(22, 17), (28, 15.2), (36, 15.4), (46, 17.6), (54, 19.4), (60, 18.6), (66, 20.4), (74, 22.4), (77, 25)]
    for (x0, y0), (x1, y1) in zip(pts, pts[1:]):
        if x0 <= x <= x1:
            return y0 + (y1 - y0) * (x - x0) / (x1 - x0)
    return 99

top = np.vectorize(body_top)(XX)
body = (YY >= top) & (YY <= TOP + 3) & (XX >= 22) & (XX <= 77)
# 이불: 청록 바탕, 금 테두리, 물결 수
def quilt(x, y):
    t = top[y, x]
    d = y - t
    base = hx('#2c6a74') if d < 2 else hx('#235a66') if d < 6 else hx('#1b4854')
    if y >= TOP:     # 앞으로 드리운 이불 앞자락
        base = hx('#17404c') if y < TOP + 2 else hx('#0f2e3a')
        if y == TOP + 3: base = hx('#c8a050')
        return base
    # 수놓은 물결(청해파): 비스듬한 반원 줄
    if ((x * 2 + y * 3) % 11 == 0) and d > 2: base = hx('#4a949a')
    if ((x + (y // 3) * 4) % 13 == 0) and d > 3 and y % 3 == 1: base = hx('#d0a850')
    if d < 1: base = hx('#7ab8b4')   # 능선 하이라이트
    return base
fill(body, quilt)
for x in range(22, 78):           # 이불 앞자락 금 테두리(지그재그 단)
    if body[TOP + 2, x] and (x % 4 in (0, 1)): put(x, TOP + 3, hx('#e0bc60'))
    elif body[TOP + 2, x]: put(x, TOP + 3, hx('#8a6a28'))
for x in range(22, 78):           # 이불과 몸 사이 금실 띠
    y = int(top[TOP, x]) + 6
    if y < TOP and body[y, x] and x % 2 == 0: put(x, y, hx('#b89040'))
# 발끝 (이불 끝이 솟음)
fill(ell(76, 24.5, 3, 3) & (XX >= 74), lambda x, y: hx('#2c6a74') if y < 25 else hx('#235a66'))

# ---- 3. 수염 — 턱에서 가슴 위로 흐름
beard_len = 24
for k in range(beard_len):
    x = 16 + k
    t = k / beard_len
    ytop = 18 + 2.2 * np.sin(t * 3.0) + t * 1.6
    wid = int(5 - 4 * t) + 1
    for j in range(wid):
        y = int(ytop + j)
        c = hx('#f0f2f4') if j == 0 else hx('#d0d6dc') if j < wid - 1 else hx('#9aa6b4')
        if (k + j) % 5 == 2: c = hx('#b4bec8')    # 올 무늬
        put(x, y, c)
# 콧수염 / 구레나룻
for (x, y) in ((11, 19), (12, 19), (13, 20), (14, 20), (15, 20)):
    put(x, y, hx('#e6eaee'))

# ---- 4. 머리 — 얼굴을 카메라 쪽(아래)으로 살짝 돌림
head = ell(10.5, 16.5, 6.2, 6.0)
fill(head, lambda x, y: hx('#d8c4a8') if (x - 10) < 2 and y < 17 else hx('#bda88c') if y < 19 else hx('#98846c'))
# 윤곽 아래쪽 그림자
for x in range(6, 16):
    if head[21, x]: put(x, 21, hx('#6c5a4a'))
# 흰 머리·상투 틀어올린 머리카락 (베개 위로 흩어짐)
hair = ell(6.0, 14.0, 5.0, 4.6) & ~ell(11.5, 17.5, 4.6, 4.8)
fill(hair, lambda x, y: hx('#e8ecf0') if y < 13 else hx('#b4bcc8'))
# 눈(감음), 눈썹, 코 그림자, 입
for (x, y, c) in ((11, 16, '#5a4a3e'), (12, 16, '#4a3a2e'),   # 눈 감음
                  (11, 15, '#dcdfe2'), (12, 15, '#dcdfe2'), (13, 15, '#dcdfe2'),   # 흰 눈썹
                  (14, 17, '#8e7862'), (14, 18, '#8e7862'),                         # 코
                  (12, 20, '#7a4a44'), (13, 20, '#7a4a44'),                         # 입
                  (9, 18, '#9a8068'), (10, 19, '#9a8068')):                          # 병색 그늘
    put(x, y, hx(c))
for (x, y) in ((11, 17), (12, 17), (13, 17)):   # 병색: 눈 밑 그늘
    put(x, y, hx('#86706a'))
# 금 머리띠 + 가운데 진주
for x in range(5, 14):
    y = 12 + int((x - 9) ** 2 / 14)
    put(x, y, hx('#e0bc60') if x % 2 else hx('#a68030'))
put(9, 11, hx('#d8f0ec')); put(9, 10, hx('#8ac0c4'))
def line(p0, p1, c, c2=None):
    n = max(abs(p1[0] - p0[0]), abs(p1[1] - p0[1]), 1)
    for i in range(n + 1):
        x = round(p0[0] + (p1[0] - p0[0]) * i / n); y = round(p0[1] + (p1[1] - p0[1]) * i / n)
        put(x, y, c)
        if c2: put(x, y + 1, c2)

# ---- 5. 어깨 옷깃 (붉은 비단, 금 단)
col = (XX >= 17) & (XX <= 27) & (YY >= 16) & (YY <= 26) & (YY >= 24 - (XX - 17) * 0.1 - 7 + 0) & ~head
col &= ((XX - 22) / 6.4) ** 2 + ((YY - 21.5) / 5.6) ** 2 <= 1
fill(col, lambda x, y: hx('#8a2e36') if y < 20 else hx('#6a2028') if y < 24 else hx('#4a141c'))
for y in range(16, 27):
    for x in range(17, 28):
        if col[y, x] and (x + y) % 3 == 0 and y > 19: put(x, y, hx('#c8a050'))
# 수염이 옷깃 위로 (다시 덮음)
for k in range(2, 10):
    x = 16 + k; ytop = 18 + 2.2 * np.sin(k / beard_len * 3.0) + k / beard_len * 1.6
    for j in range(max(1, int(5 - 4 * k / beard_len) + 1)):
        put(x, int(ytop + j), hx('#f0f2f4') if j == 0 else hx('#d0d6dc'))

# ---- 6. 팔 — 카메라 쪽 팔이 이불 위에 얹힘, 손에 용인
sleeve = ((XX - 38) / 12.0) ** 2 + ((YY - 18.2) / 3.0) ** 2 <= 1
sleeve &= (XX >= 29) & (XX <= 48)
fill(sleeve, lambda x, y: hx('#4a68a8') if y < 17 else hx('#3a528a') if y < 19 else hx('#26386a'))
for x in range(30, 48):   # 소매 위 금실
    ys = np.nonzero(sleeve[:, x])[0]
    if len(ys) and x % 3 == 0: put(x, ys[0] + 1, hx('#d4b058'))
hand = ell(47.5, 17.4, 2.6, 2.1)
fill(hand, lambda x, y: hx('#d8c4a8') if y < 18 else hx('#a8947a'))
for (x, y) in ((46, 16), (47, 16), (48, 16), (49, 17)): put(x, y, hx('#e8d6bc'))
# 손가락 사이 용인의 금빛 눈물방울이 반쯤 보임
for (x, y, c) in ((49, 18, '#f0d070'), (50, 18, '#c89830'), (49, 19, '#f8e898'), (50, 19, '#a87820')):
    put(x, y, hx(c))

# ---- 7. 외곽선: 알파 경계를 짙은 색으로
a = img[..., 3] > 0
edge = a & ~(np.roll(a, 1, 0) & np.roll(a, -1, 0) & np.roll(a, 1, 1) & np.roll(a, -1, 1))
for y, x in zip(*np.nonzero(edge)):
    r, g, b, _ = img[y, x]
    img[y, x] = (int(r * 0.42), int(g * 0.42), int(b * 0.46), 255)
# 용뿔 (외곽선 뒤에 그려 밝은 색 유지)
HORN, HORN2, HORN_D = hx('#d89a58'), hx('#f0c880'), hx('#8a5430')
line((8, 11), (5, 6), HORN, HORN_D); line((5, 6), (2, 2), HORN2, HORN)
line((5, 6), (7, 3), HORN); line((6, 8), (3, 8), HORN_D); line((3, 8), (1, 6), HORN)
line((10, 11), (13, 6), HORN, HORN_D); line((13, 6), (17, 3), HORN2, HORN); line((13, 6), (12, 3), HORN)

# 침상 위에 닿는 그림자(몸 아래 1px)
for x in range(2, 78):
    if a[TOP + 3, x] or a[TOP + 2, x]:
        pass

if __name__ == '__main__':
    OUT.mkdir(parents=True, exist_ok=True)
    Image.fromarray(img).save(OUT / 'intro_king.png')
    print('intro_king.png', img.shape, 'hand', HAND)
