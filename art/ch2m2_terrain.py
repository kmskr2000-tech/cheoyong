"""2장 M2 지형 4종(old_village·den1·den2·den3) — 소스 일러스트에서 '빈 바닥'만 뽑아 퀼팅하고, 걷기 마스크(ch2m2_maps)에 맞춰
바깥(막힘)은 덤불·숲·벽으로 칠한다. 그림과 충돌이 같은 마스크에서 나오므로 '그림에서 막혀 보이는 곳 = 막힘'이 구조적으로 보장된다.
사용: python3 art/ch2m2_terrain.py [old_village den1 den2 den3 ...]
"""
import sys, pathlib, json
import numpy as np
from PIL import Image, ImageDraw
from scipy import ndimage as ndi

ROOT = pathlib.Path(__file__).parent
sys.path.insert(0, str(ROOT))
import ch2m2_lib as L
import ch2m2_maps as M
import terrain_import as ti

S = 2.4
OUT = ti.OUT
OFFSET, TIER, TS, K = 82, 26, 16, 0.75


def walk_mask(name, scale=1.0, grow=0.0):
    """걷기 마스크(float 0/1). scale: 소스 해상도 배율, grow: walk 를 키울 px(최종 해상도)"""
    spec = M.MAPS[name]
    w, h = spec['size']
    im = Image.new('L', (round(w * scale), round(h * scale)), 0)
    d = ImageDraw.Draw(im)
    for p in spec['walk'] + M.TRAILS.get(name, []):
        d.polygon([(x * scale, y * scale) for x, y in p], fill=255)
    m = np.asarray(im, np.float32) / 255
    for p in spec.get('block', []):
        im2 = Image.new('L', im.size, 0)
        ImageDraw.Draw(im2).polygon([(x * scale, y * scale) for x, y in p], fill=255)
        m = m * (1 - np.asarray(im2, np.float32) / 255)
    return m


def finish(gid, img, tone, w, h, post=None):
    out = ti.process(None, None, tone, (w, h), img=img)
    if post is not None:
        out = Image.fromarray(post(np.asarray(out).copy()))
    out.convert('RGBA').save(OUT / f'{gid}.png')
    ti.normal(out).save(OUT / f'{gid}_n.png')
    Image.new('RGBA', (w, h), (0, 0, 0, 0)).save(OUT / f'{gid}_water.png')
    meta_p = OUT / f'{gid}.json'
    if not meta_p.exists():
        meta = {'offset': OFFSET, 'tier': TIER, 'ts': TS, 'k': K, 'size': [w, h - OFFSET], 'footprint': [w, 400],
                'heights': ['2' * (w // TS)] * 25, 'collision': [], 'land_tier': 2}
        meta_p.write_text(json.dumps(meta, separators=(',', ':')))
    print('ok', gid, (w, h))
    return out


def overgrowth(name, cv, fol, seed, inner=10, outer=22):
    """걷기 마스크 바깥을 fol(어두운 숲/덤불 텍스처)로 덮는다. 경계는 노이즈로 울퉁불퉁하게, 안쪽 가장자리는 이끼 띠."""
    H, W = cv.shape[:2]
    wm = walk_mask(name, S)
    dist = ndi.distance_transform_edt(wm < 0.5)                  # 걷기 바깥에서 걷기까지 거리(src px)
    n = L.noise(H, W, 18, seed) - 0.5
    edge = np.clip((dist + n * 16 * S / 2.4 - 2) / (6 * S), 0, 1)   # 0: 걷기, 1: 막힘
    edge = ndi.gaussian_filter(edge, 1.2)
    out = cv * (1 - edge[..., None]) + fol * edge[..., None]
    return out, wm, dist


# ---------------------------------------------------------------- old_village
# 소스: village 일러스트(하단 782행)를 좌우 반전. 1장 경주와 같은 일러스트이므로 '버려진 마을'로 읽히게 네 가지를 한다.
#  1) 조명 반전: 등롱·창호 불빛(따뜻한 주황)을 보랏빛 귀화로, 바닥에 번진 등불 온기는 꺼 둔다 — 사람 없는 집에 귀화만 떠 있다
#  2) 지붕 파손: 기와 구멍·드러난 서까래·이끼·잡초, 마당엔 그을음·깨진 기와·짚
#  3) 길 파내기: 동쪽 덤불 속에 흙길을 새로 깔아(퀼팅 흙+풀 가장자리) 마당을 도는 우회로(고리)를 만든다
#  4) 걷기 마스크(ch2m2_maps)가 지형·충돌의 단일 원천
def ov_base():
    v = L.load('village')
    return v[430:1212, :][:, ::-1].copy()


def relight(c):
    R, G, B = c[..., 0], c[..., 1], c[..., 2]
    Lm = L.lum(c) / 255
    warm = np.clip((R - B - 25) / 70, 0, 1)
    bulb = ndi.gaussian_filter(np.clip((Lm - 0.64) / 0.10, 0, 1) * warm, 0.8)           # 전구·창호 같은 아주 밝은 곳만
    halo = ndi.gaussian_filter(np.clip((Lm - 0.20) / 0.25, 0, 1) * warm, 22)            # 바닥에 번진 온기
    k = np.clip(halo * 2.2, 0, 1)
    c = c * (1 - 0.40 * k[..., None])
    gray = (L.lum(c))[..., None] * np.array([0.9, 0.95, 1.12], np.float32)
    c = c * (1 - 0.32 * halo[..., None] * 1.5).clip(0, 1) + gray * (0.32 * halo[..., None] * 1.5).clip(0, 1)
    vio = np.clip(np.stack([0.50 * R + 0.02 * G, 0.16 * G, 0.78 * R + 0.30 * B], -1) * 1.0, 0, 255)
    return c * (1 - bulb[..., None]) + vio * bulb[..., None]


def roof_holes(cv, pts, seed=3):
    """pts: 최종 해상도 좌표의 (x,y,r) — 기와가 무너진 구멍. 어두운 속 + 서까래 + 깨진 기와 조각"""
    rng = np.random.default_rng(seed)
    H, W = cv.shape[:2]
    for (x, y, r) in pts:
        cx, cy, rr = x * S, y * S, r * S
        L.blob(cv, cx, cy, rr * 1.25, rr * 0.8, (7, 6, 12), alpha=0.95, seed=int(x + y), rough=0.55)
        L.blob(cv, cx + rr * 0.1, cy + rr * 0.12, rr * 0.8, rr * 0.45, (3, 3, 6), alpha=0.9, seed=int(x * y) % 97, rough=0.4)
        for k in range(3):                                           # 서까래(갈색 막대)
            ax = cx - rr * 0.9 + rng.random() * rr * 1.8
            for t in range(int(rr * 1.3)):
                px, py = int(ax + t * 0.6), int(cy - rr * 0.7 + t * 0.9)
                if 0 <= px < W - 2 and 0 <= py < H - 2:
                    cv[py:py + 3, px:px + 2] = (74, 50, 36) if (t // 6) % 2 == 0 else (52, 36, 28)
        for k in range(14):                                          # 가장자리 깨진 기와
            a = rng.random() * 6.28
            px, py = int(cx + np.cos(a) * rr * 1.25), int(cy + np.sin(a) * rr * 0.8)
            if 0 <= px < W - 5 and 0 <= py < H - 3:
                cv[py:py + 3, px:px + 5] = (70, 82, 112) if k % 3 else (44, 56, 82)
        L.blob(cv, cx - rr * 0.9, cy + rr * 0.6, rr * 0.5, rr * 0.25, (46, 74, 52), alpha=0.8, seed=int(x) % 53, rough=0.6)   # 이끼


def dirt_pool():
    v = L.load('village')
    crops = [v[1100:1280, 330:700], v[1130:1280, 20:300]]
    ref_m, ref_s = crops[0].mean((0, 1)), crops[0].std((0, 1))
    ps = [np.clip((c - c.mean((0, 1))) / (c.std((0, 1)) + 1e-3) * ref_s + ref_m, 0, 255) for c in crops]
    ph = min(p.shape[0] for p in ps)
    return np.concatenate([p[:ph] for p in ps], axis=1)


def carve_trail(cv, polys, seed=9):
    """polys(최종 좌표) 안쪽을 흙길로 덮는다. 가장자리는 노이즈로 울퉁불퉁 + 풀 띠."""
    H, W = cv.shape[:2]
    dirt = L.quilt(dirt_pool(), (H, W), block=90, overlap=26, seed=21, tries=150)
    # 근처 길과 밝기를 맞춘다(마당 흙 평균)
    ref = cv[int(272 * S):int(296 * S), int(560 * S):int(690 * S)].mean((0, 1))
    dirt = np.clip(dirt * (ref / dirt.mean((0, 1))) * 0.80, 0, 255)
    dirt = dirt * (0.80 + 0.40 * L.noise(H, W, 40, seed + 5))[..., None]
    im = Image.new('L', (W, H), 0)
    d = ImageDraw.Draw(im)
    for p in polys:
        d.polygon([(x * S, y * S) for x, y in p], fill=255)
    m = np.asarray(im, np.float32) / 255
    n = L.noise(H, W, 14, seed) - 0.5
    dist_in = ndi.distance_transform_edt(m > 0.5)
    dist_out = ndi.distance_transform_edt(m < 0.5)
    sd = (dist_in - dist_out) + n * 26
    mm = np.clip(sd / 5 + 0.5, 0, 1)
    fringe = np.clip(1 - np.abs(sd - 8) / 14, 0, 1) * np.clip(sd / 4, 0, 1)      # 가장자리 풀 띠
    grass = np.array([44, 66, 44], np.float32) * (0.8 + 0.4 * L.noise(H, W, 5, seed + 2))[..., None]
    out = cv * (1 - mm[..., None]) + dirt * mm[..., None]
    out = out * (1 - fringe[..., None] * 0.65) + grass * fringe[..., None] * 0.65
    # 가장자리에 덤불·대나무 잎을 몇 군데 덮어 '풀이 길을 먹어 들어가는' 느낌 (주변 덤불 크롭을 스탬프)
    rng = np.random.default_rng(seed)
    foli = cv[int(250 * S):int(300 * S), int(748 * S):int(792 * S)].copy()
    ys, xs = np.where((mm > 0.15) & (mm < 0.5))
    if len(ys):
        for k in rng.choice(len(ys), size=min(36, len(ys)), replace=False):
            y, x = ys[k], xs[k]
            fh, fw = foli.shape[:2]
            L.paste(out, foli[:, ::-1] if k % 2 else foli, int(x - fw / 2), int(y - fh / 2), L.soft_mask(fh, fw, 'ellipse', 0.5) * 0.9)
    return out


def old_village_source():
    c = ov_base()
    H, W = c.shape[:2]
    c = relight(c)
    c = carve_trail(c, M.TRAILS['old_village'])
    roof_holes(c, [(215, 138, 22), (268, 158, 14), (322, 142, 12), (72, 38, 16), (128, 20, 10),
                   (640, 24, 18), (728, 34, 14), (470, 8, 9), (190, 175, 10)])
    rng = np.random.default_rng(17)
    # 그을음·깨진 기와·짚 (마당 위)
    for (x, y, rx, ry) in [(560, 205, 24, 8), (470, 255, 30, 10), (640, 255, 26, 8), (380, 150, 20, 7), (590, 285, 22, 7)]:
        L.blob(c, x * S, y * S, rx * S, ry * S, (24, 20, 26), alpha=0.5, seed=int(x), rough=0.5)
    for k in range(70):
        x, y = rng.uniform(340, 740) * S, rng.uniform(150, 296) * S
        if M.is_walk('old_village', x / S, y / S):
            col = [(66, 78, 108), (40, 50, 78), (150, 124, 70), (120, 98, 58)][k % 4]
            c[int(y):int(y) + 3, int(x):int(x) + (5 if k % 4 < 2 else 4)] = col
    wm = walk_mask('old_village', S)
    return c, wm, None


OV_TONE = dict(bright=1.04, sat=0.95, tint=(26, 26, 74), mix=0.14)


def build_old_village():
    img, wm, dist = old_village_source()
    return finish('old_village', Image.fromarray(np.clip(img, 0, 255).astype(np.uint8)), OV_TONE, 800, 326)


# ---------------------------------------------------------------- den1 : dungeon 일러스트 하단 782행(긴 복도·북쪽 방·덩굴 방)
# 소굴 톤: 푸른 귀화 불꽃을 보랏빛으로(색 반전: 1장·화개의 따뜻한 등불과 대비), 이끼는 눌러 둔다.
def violet_flames(c, strength=1.0, halo_r=11, halo_k=0.55):
    """푸른 귀화(청록 고휘도)를 보랏빛으로. 불꽃 둘레 번진 푸른 바닥빛도 보라로 기울인다."""
    R, G, B = c[..., 0], c[..., 1], c[..., 2]
    Lm = L.lum(c) / 255
    cy = np.clip((B - R - 40) / 50, 0, 1) * np.clip((Lm - 0.28) / 0.12, 0, 1) * np.clip((B - 150) / 40, 0, 1)
    cy = ndi.gaussian_filter(cy, 0.6)
    vio = np.stack([0.72 * B + 0.05 * R, 0.10 * G + 0.04 * B, B * 1.0], -1)
    out = c * (1 - cy[..., None] * strength) + vio * cy[..., None] * strength
    halo = np.clip(ndi.gaussian_filter(cy, halo_r) * 5, 0, 1) * halo_k
    soft = np.stack([0.55 * B + 0.30 * R, 0.62 * G, B * 1.0], -1)
    return out * (1 - halo[..., None]) + soft * halo[..., None]


FLAME_RAMP = [(46, 14, 96), (92, 36, 170), (146, 76, 232), (196, 130, 255), (236, 196, 255)]


def flame_mask(c):
    """소스 해상도에서 귀화 불꽃 마스크(청록 고휘도)"""
    R, G, B = c[..., 0], c[..., 1], c[..., 2]
    Lm = L.lum(c) / 255
    return (((B - R) > 40) & (Lm > 0.30) & (B > 150)).astype(np.float32)


def flame_post(mask_src, w, h):
    """최종 해상도에서 불꽃 픽셀을 보라 램프로 다시 칠한다(양자화 뒤라 채도가 살아남는다)."""
    m = np.asarray(Image.fromarray((mask_src * 255).astype(np.uint8)).resize((w, h), Image.BOX), np.float32) / 255
    m = m > 0.22

    def post(a):
        lum = (a.astype(np.float32) @ np.array([.3, .59, .11], np.float32)) / 255
        idx = np.clip(((lum - 0.22) / 0.55 * 5).astype(int), 0, 4)
        ramp = np.array(FLAME_RAMP, np.uint8)
        a[m] = ramp[idx[m]]
        return a
    return post


def den1_source():
    v = L.load('dungeon')
    c = v[498:498 + 782, :].copy()
    global _FLAME
    _FLAME = flame_mask(c)
    c = violet_flames(c)
    # 기둥벽(x430~448)을 무너뜨려 중앙 복도와 동쪽 복도를 잇는다: 중앙 복도 판석 바닥을 덮어 얹고 잔해를 흩는다
    fl = c[int(140 * S):int(190 * S), int(352 * S):int(430 * S)]
    for k, xx in enumerate((428, 436)):
        L.paste(c, fl[:, :int(18 * S)], int((xx - 2) * S), int(135 * S), L.soft_mask(fl.shape[0], int(18 * S), 'rect', 0.3))
    fl2 = c[int(145 * S):int(196 * S), int(500 * S):int(530 * S)]                    # 동쪽 복도 ↔ 덩굴 방 사이 벽도 같은 방식으로
    for xx in (540, 548):
        L.paste(c, fl2[:, :int(14 * S)], int(xx * S), int(143 * S), L.soft_mask(fl2.shape[0], int(14 * S), 'rect', 0.3))
    rng = np.random.default_rng(31)
    for k in range(22):                                   # 무너진 돌 조각
        x, y = (rng.uniform(424, 452) if k < 14 else rng.uniform(536, 562)) * S, rng.uniform(150, 190) * S
        w_, h_ = int(rng.integers(5, 12)), int(rng.integers(4, 8))
        col = [(52, 66, 72), (84, 100, 108), (34, 44, 50)][k % 3]
        c[int(y):int(y) + h_, int(x):int(x) + w_] = col
        c[int(y) + h_ - 1:int(y) + h_, int(x):int(x) + w_] = (14, 20, 26)
    return c, None, None


DEN1_TONE = dict(bright=1.22, sat=1.0, tint=(34, 22, 70), mix=0.14)


def build_den1():
    img, _, _ = den1_source()
    return finish('den1', Image.fromarray(np.clip(img, 0, 255).astype(np.uint8)), DEN1_TONE, 800, 326, post=flame_post(_FLAME, 800, 326))


# ---------------------------------------------------------------- den2/den3 : 코드로 그린 판석 바닥 + 2D 석축 + den1 일러스트 장식 스탬프
import ch2m2_walls as WL

DARK_SLAB = [(18, 24, 30), (24, 31, 38), (30, 39, 47), (38, 48, 58), (46, 58, 68)]
LIGHT_SLAB = [(52, 64, 72), (62, 76, 86), (72, 88, 98), (84, 102, 112), (98, 116, 124)]


def den1_png():
    return np.asarray(Image.open(OUT / 'den1.png').convert('RGB'), np.float32)


def decals(cv, rng, items, d1):
    """den1 일러스트에서 뜬 장식(항아리·물웅덩이·잔해) 스탬프. items: [(키, x, y, flip)] — (x,y)는 그림 속 중심."""
    SRC = {
        'pots_a': (236, 130, 294, 162),     # 깨진 큰 항아리 + 물웅덩이 끝
        'pots_b': (250, 168, 290, 194),     # 항아리 둘
        'pot_c': (108, 132, 142, 154),
        'pile': (3, 164, 46, 188),          # 항아리 더미
        'puddle': (196, 146, 262, 172),     # 물웅덩이
        'mushroom': (452, 158, 494, 180),
    }
    for key, x, y, flip in items:
        x0, y0, x1, y1 = SRC[key]
        p = d1[y0:y1, x0:x1]
        if flip:
            p = p[:, ::-1]
        m = L.soft_mask(p.shape[0], p.shape[1], 'ellipse', 0.45)
        m = (m > 0.55).astype(np.float32)         # 번짐 방지: 부드러운 알파 대신 단단한 경계
        L.paste(cv, p, int(x - p.shape[1] / 2), int(y - p.shape[0] / 2), m)


def den2_source():
    W, H = 640, 326
    rng = np.random.default_rng(12)
    outer = L.grime(L.flagstones(W, H, seed=21, pal=DARK_SLAB, moss=0.5), seed=7, strength=0.45)
    floor = L.grime(L.flagstones(W, H, seed=22, pal=LIGHT_SLAB, moss=0.45, cracks=0.5, hole=0.05), seed=9, strength=0.4)
    wm = walk_mask('den2', 1.0)
    # 안쪽(걷기) = 밝은 바닥, 바깥 = 어두운 돌덩이. 벽 갓돌·앞면은 아래에서 그린다
    ww = np.asarray(Image.fromarray((wm * 255).astype(np.uint8)).filter(__import__('PIL.ImageFilter', fromlist=['x']).MaxFilter(9)))
    cv = np.where((ww > 127)[..., None], floor, outer).astype(np.float32)
    d1 = den1_png()
    # 중앙 문양 석판(den1 의 북서 문양 바닥)
    sl = d1[36:98, 20:132]
    L.paste(cv, sl, 320 - 56, 168 - 31, None)
    decals(cv, rng, [('pots_a', 232, 112, False), ('pots_b', 408, 232, True), ('pot_c', 252, 236, False), ('puddle', 392, 128, True),
                     ('mushroom', 214, 150, False), ('pile', 420, 150, True), ('pots_b', 120, 196, False)], d1)
    L.rubble(cv, rng, [(rng.uniform(190, 450), rng.uniform(90, 270)) for _ in range(12)])
    # 의식용 상감: 광장 바닥에 두 겹 타원 띠 + 여덟 방향 살(청동빛 돌) — 소굴 광장이 '의식 마당'으로 읽히게
    yy, xx = np.mgrid[0:H, 0:W].astype(np.float32)
    for rr in (92, 124):
        dd = np.abs(np.sqrt(((xx - 320) / rr) ** 2 + ((yy - 184) / (rr * 0.75)) ** 2) - 1)
        band = dd < (2.2 / rr)
        cv[band & (wm > 0.5)] = (92, 86, 78) if rr == 92 else (74, 70, 66)
        edge = (dd >= (2.2 / rr)) & (dd < (3.4 / rr))
        cv[edge & (wm > 0.5)] = (22, 26, 32)
    for a in range(0, 360, 45):
        t_ = np.arange(34, 140, 1.0)
        for r_ in t_:
            x_, y_ = 320 + np.cos(np.radians(a)) * r_, 184 + np.sin(np.radians(a)) * r_ * 0.75
            if 0 <= x_ < W - 2 and 0 <= y_ < H - 2 and wm[int(y_), int(x_)] > 0.5 and abs(((r_ - 34) % 12)) > 1.5:
                cv[int(y_):int(y_) + 2, int(x_):int(x_) + 2] = (70, 66, 62)
    # 귀화 불빛 자국
    L.glow_pools(cv, [(320, 184), (190, 150), (450, 150), (190, 228), (450, 228)], radii=(18, 40, 70), adds=((10, 4, 20), (8, 3, 14), (6, 2, 10)))
    # 담: 원형 광장 갓돌 + 문(동·서) 문설주, 복도 담
    cap, bid = WL.ring_cap(W, H, 320, 180, 150, 112, 16, [(0, 17), (180, 17)])
    posts = np.zeros((H, W), bool)
    for px in (166, 474):
        posts[128:140, px - 8:px + 8] = True; posts[220:232, px - 8:px + 8] = True
    WL.draw_wall(cv, cap, 18, seed=4, bid=bid, tall=posts, tall_h=24)
    corr = np.zeros((H, W), bool)
    for x0, x1 in ((0, 160), (480, 640)):
        corr[142:150, x0:x1] = True
    WL.draw_wall(cv, corr, 16, seed=8, block=14)
    corr2 = np.zeros((H, W), bool)
    for x0, x1 in ((0, 160), (480, 640)):
        corr2[218:226, x0:x1] = True
    WL.draw_wall(cv, corr2, 16, seed=9, block=14)
    L.roots(cv, rng, [(x, y, a) for (x, y, a) in [(150, 76, -2.4), (500, 72, -0.7), (110, 280, 2.3), (540, 290, 0.8), (60, 120, 3.2), (590, 250, 0.1), (30, 30, 0.6), (610, 20, 2.6)]], n=46)
    return cv, None, None


DEN2_TONE = dict(bright=1.05, sat=1.0, tint=(34, 22, 70), mix=0.14)


def build_den2():
    img, _, _ = den2_source()
    return finish('den2', Image.fromarray(np.clip(img, 0, 255).astype(np.uint8)), DEN2_TONE, 640, 326)


def den3_source():
    """두억시니의 방: 사각 큰 방(걷는 면 ≥ 300x300 footprint) + 서쪽 입구 복도, 중앙 절구 제단 자리(문양 석판 + 의식 원)."""
    W, H = 640, 326
    rng = np.random.default_rng(33)
    outer = L.grime(L.flagstones(W, H, seed=31, pal=DARK_SLAB, moss=0.5), seed=17, strength=0.45)
    floor = L.grime(L.flagstones(W, H, seed=32, pal=LIGHT_SLAB, moss=0.4, cracks=0.55, hole=0.04), seed=19, strength=0.4)
    wm = walk_mask('den3', 1.0)
    ww = np.asarray(Image.fromarray((wm * 255).astype(np.uint8)).filter(__import__('PIL.ImageFilter', fromlist=['x']).MaxFilter(9)))
    cv = np.where((ww > 127)[..., None], floor, outer).astype(np.float32)
    d1 = den1_png()
    yy, xx = np.mgrid[0:H, 0:W].astype(np.float32)
    # 의식 원(소환진 후보 원, 반경 130 footprint = 가로 130 / 세로 97) + 안쪽 원
    for rr, col in ((130, (84, 78, 72)), (98, (70, 66, 62)), (40, (96, 88, 80))):
        dd = np.abs(np.sqrt(((xx - 320) / rr) ** 2 + ((yy - 180) / (rr * 0.75)) ** 2) - 1)
        band = dd < (2.4 / rr)
        cv[band & (wm > 0.5)] = col
        edge = (dd >= (2.4 / rr)) & (dd < (3.6 / rr))
        cv[edge & (wm > 0.5)] = (22, 26, 32)
    for a in range(0, 360, 30):                                                    # 소환진 8점 + 4점 표식(십이방위)
        r_ = 130
        x_, y_ = 320 + np.cos(np.radians(a)) * r_, 180 + np.sin(np.radians(a)) * r_ * 0.75
        cv[int(y_) - 2:int(y_) + 3, int(x_) - 2:int(x_) + 3] = (110, 62, 150) if a % 90 else (170, 90, 220)
    # 중앙 문양 석판(절구 제단 밑)
    sl = d1[36:98, 20:132]
    L.paste(cv, sl, 320 - 56, 180 - 28, None)
    decals(cv, rng, [('pots_b', 118, 100, False), ('pile', 520, 260, True), ('pot_c', 140, 250, False), ('pots_a', 500, 100, True),
                     ('puddle', 215, 260, False), ('mushroom', 450, 250, True)], d1)
    L.rubble(cv, rng, [(rng.uniform(70, 570), rng.uniform(70, 290)) for _ in range(14)])
    L.glow_pools(cv, [(320, 180), (60, 120), (580, 120), (60, 260), (580, 260), (320, 70)], radii=(18, 40, 70), adds=((10, 4, 20), (8, 3, 14), (6, 2, 10)))
    # 담: 사각 방 갓돌 + 앞면(북쪽 안쪽면, 남쪽 바깥면), 서쪽 입구 문
    cap = np.zeros((H, W), bool)
    cap[34:44, 30:610] = True            # 북벽
    cap[300:310, 30:610] = True          # 남벽
    cap[44:310, 30:40] = True            # 서벽
    cap[44:310, 600:610] = True          # 동벽
    gate = np.zeros((H, W), bool); gate[150:212, 30:42] = True
    cap &= ~gate
    posts = np.zeros((H, W), bool); posts[136:150, 26:46] = True; posts[212:226, 26:46] = True
    bid = ((np.arange(W)[None, :] + np.arange(H)[:, None] * 0) // 14)
    WL.draw_wall(cv, cap, 18, seed=6, bid=bid, tall=posts, tall_h=24)
    L.roots(cv, rng, [(x, y, a) for (x, y, a) in [(60, 20, 0.4), (260, 12, 1.4), (500, 18, 1.8), (610, 40, 2.4), (20, 300, -0.4), (600, 316, -2.6)]], n=40)
    return cv, None, None


DEN3_TONE = dict(bright=1.05, sat=1.0, tint=(34, 22, 70), mix=0.14)


def build_den3():
    img, _, _ = den3_source()
    return finish('den3', Image.fromarray(np.clip(img, 0, 255).astype(np.uint8)), DEN3_TONE, 640, 326)


BUILDERS = {'old_village': build_old_village, 'den1': build_den1, 'den2': build_den2, 'den3': build_den3}

if __name__ == '__main__':
    for n in [a for a in sys.argv[1:] if not a.startswith('--')] or list(BUILDERS):
        BUILDERS[n]()
