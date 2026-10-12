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


def finish(gid, img, tone, w, h):
    out = ti.process(None, None, tone, (w, h), img=img)
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


BUILDERS = {'old_village': build_old_village}

if __name__ == '__main__':
    for n in [a for a in sys.argv[1:] if not a.startswith('--')] or list(BUILDERS):
        BUILDERS[n]()
