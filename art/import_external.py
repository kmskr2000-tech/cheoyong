"""외부 도트풍 에셋(AI 생성 일러스트) → 현행 요괴 시트 규격 시안 변환기.

사용: python3 art/import_external.py <키|all>      키: plagueking onedokkaebi firedokkaebi sangun jangsanbeom
산출(전부 art/out/external/, 게임 에셋 src/assets/ 는 건드리지 않는다):
    <키>.png            7프레임 시트 (move0-3, tell, strike, hurt) — Enemy.KINDS 규약, 셀·feet 는 현행 요괴 기준
    <키>_alt_atk3.png   strike 후보 2 (atk_3) 단일 셀
    compare_<키>.png    현행 스프라이트(위) / 임포트 시안(가운데) / 팔레트 정규화 전 원본 4프레임(아래), 4x 확대

처리 순서 (design/art/asset-integration.md §(d) 의 통합 방법을 코드로 옮긴 것):
  (a) 알파: 원본 WEBP(검은 배경 RGB)에서 테두리와 이어진 어두운 영역만 flood-fill 로 배경 제거 → 이진 알파.
      공격 WEBP 는 한 장에 3프레임(2736x912)이라 세로로 비어 있는 가장 알맞은 두 열에서 3등분.
  (b) 정수 배율: 한 원본 그림(idle 한 장 / 공격 한 장)의 모든 프레임에 같은 정수 N 을 쓴다.
      N = ceil(max(bbox 높이/목표 높이, bbox 폭/목표 폭)) — 결과가 목표 칸 안에 들어가는 최소 정수.
      축소는 N x N 상자 평균(coverage>=0.5 → 불투명, 색은 불투명 화소의 평균). 원본 1 픽셀이 수십 배라
      최근접 표본은 앨리어싱·잡음이 심해 상자 평균으로 대체했다(비정수 보간은 쓰지 않음).
  (c) 팔레트: 결과 화소 전체를 OKLab K-means(K=21) → 아트바이블 규칙으로 조정
      (고명도 어깨 눌림·채도 상한·그림자는 청보라/빛은 황색 쪽·기존 램프로 부분 당김) → 최근접 매핑(디더 없음)
      + 1px 외곽선 INK #07060b. 시트 전체 ≤ 24색 (21 + INK + 피격 플래시 2).
  (d) 프레임: move0-3 = idle 의 1px 바운스 복제, tell = atk_1, strike = atk_2, hurt = idle + 흰 플래시 + 넉백.
"""
import colorsys
import pathlib
import sys

import numpy as np
from PIL import Image, ImageDraw
from scipy import ndimage

ROOT = pathlib.Path(__file__).parent
REPO = ROOT.parent
SPRITES = REPO / 'src' / 'assets' / 'sprites'
OUT = ROOT / 'out' / 'external'
SRC = pathlib.Path('/home/hatch/workspace/goals/rpg/files/game-assets/yokai')

INK = (7, 6, 11)
K_COLORS = 21
BG_THRESH = 14          # 배경색(테두리 중앙값)과 채널 차 ≤14(순흑 배경) / ≤22(남색 배경)이고 테두리와 이어진 화소 = 배경

# 키: 원본 이름, 현행 시트 이름, 셀, feet(발끝/기준선 행), 현행 시트 프레임 수, 부유 여부,
#     src_faces_right: 원본 그림이 향한 방향(눈으로 확인), game_faces_right: enemy.gd KINDS 의 faces_right
SPECS = {
    'plagueking': dict(src='boss-plagueking', current='plague_god', cell=(120, 164), feet=158, float=True,
                       src_right=False, game_right=False),
    'onedokkaebi': dict(src='ch2-onedokkaebi', current='dokkaebi_oneeye', cell=(48, 56), feet=54, float=False,
                        src_right=False, game_right=False),
    'firedokkaebi': dict(src='ch2-firedokkaebi', current='dokkaebi_fire', cell=(48, 56), feet=54, float=False,
                         src_right=False, game_right=False),
    'sangun': dict(src='ch2-sangun', current='sangun', cell=(66, 44), feet=42, float=False,
                   src_right=False, game_right=True),
    'jangsanbeom': dict(src='ch2-jangsanbeom', current='jangsanbeom', cell=(66, 44), feet=42, float=False,
                        src_right=False, game_right=True),
}

# ------------------------------------------------------------------ 아트바이블 램프 (design/art/art-bible.md §4.1)
BIBLE_RAMPS = {
    'ink': ['#07060b'],
    'navy': ['#2d3349', '#3b4259', '#4d546b'],
    'stone': ['#0f0f16', '#1a1b25', '#262836', '#353849', '#474b5e', '#5e6378', '#222636', '#59607a'],
    'water': ['#0b1526', '#17304a', '#2a4668'],
    'brass': ['#695330', '#8a7142', '#bba372'],
    'gold': ['#82632e', '#a98544', '#d8bc78'],
    'sore': ['#3a5a20', '#5c8238', '#82ac50'],
    'red': ['#4f2c2c', '#7a463d', '#925f52', '#3a0a0c', '#a32e28', '#e05a3a'],
    'wood': ['#140e0d', '#22181a', '#33241f', '#4a3528', '#644a35', '#7e6244'],
    'pine': ['#08100e', '#0e1a16', '#152620', '#1e352a', '#2a4836', '#3c5e44'],
    'paper': ['#5a5868', '#86848e', '#aeaaa8', '#d0cabc'],
    'glow': ['#6a3a1a', '#b86a2a', '#e8a048', '#ffd27a'],
    'violet': ['#2a1f45', '#4a3a78', '#7a62b0'],     # 보라 귀화 (CLAUDE.md "보랏빛 귀화")
}
S_CAP = 0.78          # HLS 채도 상한
V_SHOULDER = 0.62     # HSV 명도 어깨(이상은 절반으로 눌림)
PULL = 0.30           # 가장 가까운 바이블 색으로 당기는 비율


# ------------------------------------------------------------------ OKLab
def srgb_to_lin(c):
    c = c / 255.0
    return np.where(c <= 0.04045, c / 12.92, ((c + 0.055) / 1.055) ** 2.4)


def lin_to_srgb(c):
    c = np.clip(c, 0, 1)
    return np.where(c <= 0.0031308, c * 12.92, 1.055 * c ** (1 / 2.4) - 0.055) * 255.0


def rgb_to_oklab(rgb):
    r, g, b = (srgb_to_lin(rgb[..., i]) for i in range(3))
    l = np.cbrt(0.4122214708 * r + 0.5363325363 * g + 0.0514459929 * b)
    m = np.cbrt(0.2119034982 * r + 0.6806995451 * g + 0.1073969566 * b)
    s = np.cbrt(0.0883024619 * r + 0.2817188376 * g + 0.6299787005 * b)
    return np.stack([0.2104542553 * l + 0.7936177850 * m - 0.0040720468 * s,
                     1.9779984951 * l - 2.4285922050 * m + 0.4505937099 * s,
                     0.0259040371 * l + 0.7827717662 * m - 0.8086757660 * s], -1)


def oklab_to_rgb(lab):
    L, a, b = lab[..., 0], lab[..., 1], lab[..., 2]
    l = (L + 0.3963377774 * a + 0.2158037573 * b) ** 3
    m = (L - 0.1055613458 * a - 0.0638541728 * b) ** 3
    s = (L - 0.0894841775 * a - 1.2914855480 * b) ** 3
    r = 4.0767416621 * l - 3.3077115913 * m + 0.2309699292 * s
    g = -1.2684380046 * l + 2.6097574011 * m - 0.3413193965 * s
    bb = -0.0041960863 * l - 0.7034186147 * m + 1.7076147010 * s
    return lin_to_srgb(np.stack([r, g, bb], -1))


def hex2rgb(h):
    return tuple(int(h[i:i + 2], 16) for i in (1, 3, 5))


BIBLE_RGB = np.array([hex2rgb(h) for r in BIBLE_RAMPS.values() for h in r], np.float64)
BIBLE_LAB = rgb_to_oklab(BIBLE_RGB)


def kmeans(lab, w, k, iters=40, seed=7):
    """가중 K-means++ (OKLab). 화소가 k개 이하면 그대로."""
    rng = np.random.default_rng(seed)
    uniq, inv = np.unique(np.round(lab, 4), axis=0, return_inverse=True)
    uw = np.bincount(inv.ravel(), weights=w)
    if len(uniq) <= k:
        return uniq
    cen = [uniq[rng.choice(len(uniq), p=uw / uw.sum())]]
    d2 = ((uniq - cen[0]) ** 2).sum(1)
    for _ in range(k - 1):
        p = d2 * uw
        cen.append(uniq[rng.choice(len(uniq), p=p / p.sum())])
        d2 = np.minimum(d2, ((uniq - cen[-1]) ** 2).sum(1))
    cen = np.array(cen)
    for _ in range(iters):
        idx = ((uniq[:, None, :] - cen[None]) ** 2).sum(2).argmin(1)
        new = cen.copy()
        for j in range(k):
            sel = idx == j
            if sel.any():
                new[j] = (uniq[sel] * uw[sel, None]).sum(0) / uw[sel].sum()
        if np.allclose(new, cen, atol=1e-5):
            break
        cen = new
    return cen


def bible_adjust(rgb):
    """K-means 중심색 하나를 아트바이블 규칙으로 조정. rgb: 0-255 float 3-vector."""
    lab = rgb_to_oklab(np.asarray(rgb, np.float64))
    # 1) 가장 가까운 바이블 색으로 PULL 만큼 당김 (밤 청색 쪽으로 조화)
    j = ((BIBLE_LAB - lab) ** 2).sum(1).argmin()
    lab = lab * (1 - PULL) + BIBLE_LAB[j] * PULL
    r, g, b = np.clip(oklab_to_rgb(lab), 0, 255) / 255.0
    h, l, s = colorsys.rgb_to_hls(r, g, b)
    # 2) 채도 상한
    s = min(s, S_CAP)
    r, g, b = colorsys.hls_to_rgb(h, l, s)
    # 3) 고명도 어깨 (전 프레임 공통, v>0.62 를 1/4 로 눌러 최대 0.72)
    hh, ss, vv = colorsys.rgb_to_hsv(r, g, b)
    if vv > V_SHOULDER:
        vv = V_SHOULDER + (vv - V_SHOULDER) * 0.25   # 최대 0.72
    r, g, b = colorsys.hsv_to_rgb(hh, ss, vv)
    # 4) 그림자 → 청보라, 빛 → 황색 (people.py:ramp 규칙)
    h, l, s = colorsys.rgb_to_hls(r, g, b)
    if l < 0.35 and s > 0.04:
        d = ((0.70 - h + 0.5) % 1.0) - 0.5
        h = (h + d * 0.12 * (1 - l / 0.35)) % 1.0
    elif l > 0.60 and s > 0.04:
        d = ((0.12 - h + 0.5) % 1.0) - 0.5
        h = (h + d * 0.08) % 1.0
    r, g, b = colorsys.hls_to_rgb(h, l, s)
    return np.array([r, g, b]) * 255.0


# ------------------------------------------------------------------ (a) 알파
def load_cutout(path):
    """검은 배경 RGB → (rgb uint8, bg 제거된 bool mask)."""
    rgb = np.array(Image.open(path).convert('RGB'))
    edge = np.concatenate([rgb[0], rgb[-1], rgb[:, 0], rgb[:, -1]]).astype(int)
    bg_col = np.median(edge, 0)         # 배경색: 대부분 순흑, 불도깨비 idle 은 남색(≈19,17,29) 그라데이션
    dark = np.abs(rgb.astype(int) - bg_col).max(2) <= (BG_THRESH if bg_col.max() < 6 else BG_THRESH + 8)
    lab, _ = ndimage.label(dark)
    border = set(np.unique(np.concatenate([lab[0], lab[-1], lab[:, 0], lab[:, -1]]))) - {0}
    bg = np.isin(lab, list(border)) if border else np.zeros_like(dark)
    mask = ~bg
    # 작은 얼룩(배경 잔티) 제거: 가장 큰 덩어리의 0.2% 미만이면 버림
    lab2, n = ndimage.label(mask)
    if n > 1:
        sizes = ndimage.sum(mask, lab2, range(1, n + 1))
        keep = [i + 1 for i, s in enumerate(sizes) if s >= sizes.max() * 0.002]
        mask = np.isin(lab2, keep)
    return rgb, mask


def split_strip(rgb, mask, parts=3):
    """한 장에 3프레임 — 균등 분할선 근처에서 불투명 화소가 가장 적은 열을 경계로."""
    h, w = mask.shape
    col = mask.sum(0)
    cuts = [0]
    for i in range(1, parts):
        c = int(round(w * i / parts))
        lo, hi = c - w // 12, c + w // 12
        cuts.append(lo + int(col[lo:hi].argmin()))
    cuts.append(w)
    return [(rgb[:, a:b], mask[:, a:b]) for a, b in zip(cuts[:-1], cuts[1:])]


def crop_bbox(rgb, mask):
    ys, xs = np.where(mask)
    y0, y1, x0, x1 = ys.min(), ys.max() + 1, xs.min(), xs.max() + 1
    return rgb[y0:y1, x0:x1], mask[y0:y1, x0:x1]


# ------------------------------------------------------------------ (b) 정수 배율
def box_down(rgb, mask, n):
    """정수 N 상자 평균. 가로는 중앙, 세로는 아래 기준으로 N 의 배수까지 투명 패딩."""
    h, w = mask.shape
    H, W = -(-h // n) * n, -(-w // n) * n
    pt, pl = H - h, (W - w) // 2
    m = np.zeros((H, W), np.float64)
    c = np.zeros((H, W, 3), np.float64)
    m[pt:pt + h, pl:pl + w] = mask
    c[pt:pt + h, pl:pl + w] = rgb * mask[..., None]
    m4 = m.reshape(H // n, n, W // n, n)
    cov = m4.mean((1, 3))
    csum = c.reshape(H // n, n, W // n, n, 3).sum((1, 3))
    msum = m4.sum((1, 3))
    col = csum / np.maximum(msum, 1)[..., None]
    alpha = cov >= 0.5
    return col, alpha


def choose_n(frames, max_w, max_h):
    n = 1
    for rgb, mask in frames:
        h, w = mask.shape
        n = max(n, -(-h // max_h), -(-w // max_w))
    return n


# ------------------------------------------------------------------ (c)(d)
def outline_pad(img):
    """RGBA 배열에 1px INK 외곽선(4방향)."""
    a = img[..., 3] > 0
    grow = np.zeros_like(a)
    grow[1:] |= a[:-1]; grow[:-1] |= a[1:]; grow[:, 1:] |= a[:, :-1]; grow[:, :-1] |= a[:, 1:]
    edge = grow & ~a
    img[edge] = (*INK, 255)
    return img


def place(col_alpha, cell, feet, dx=0, dy=0, flip=False):
    """(color, alpha) 를 셀에 배치: 가로 중앙, 몸통 하단을 feet-1 행(그 아래 1px 이 외곽선 = feet)."""
    col, alpha = col_alpha
    cw, ch = cell
    if flip:
        col, alpha = col[:, ::-1], alpha[:, ::-1]
    ys, xs = np.where(alpha)
    col, alpha = col[ys.min():ys.max() + 1, xs.min():xs.max() + 1], alpha[ys.min():ys.max() + 1, xs.min():xs.max() + 1]
    h, w = alpha.shape
    x0 = (cw - w) // 2 + dx
    y0 = feet - 1 - h + 1 + dy          # 마지막 몸통 행 = feet-1
    cellrgb = np.zeros((ch, cw, 3))
    cella = np.zeros((ch, cw), bool)
    sx0, sy0 = max(0, -x0), max(0, -y0)
    ex, ey = min(w, cw - x0), min(h, ch - y0)
    if ex > sx0 and ey > sy0:
        cellrgb[y0 + sy0:y0 + ey, x0 + sx0:x0 + ex] = col[sy0:ey, sx0:ex]
        cella[y0 + sy0:y0 + ey, x0 + sx0:x0 + ex] = alpha[sy0:ey, sx0:ex]
    return cellrgb, cella


def to_rgba(rgb, alpha):
    out = np.zeros(alpha.shape + (4,), np.uint8)
    out[..., :3] = np.clip(np.round(rgb), 0, 255)
    out[..., 3] = np.where(alpha, 255, 0)
    return out


def quantize(bodies, k=K_COLORS):
    """bodies: [(rgb float HxWx3, alpha bool)] — 전 프레임 공통 팔레트를 만들고 최근접 매핑."""
    pix = np.concatenate([c[a] for c, a in bodies])
    lab = rgb_to_oklab(pix)
    cen = kmeans(lab, np.ones(len(lab)), k)
    pal = np.clip(np.round(np.array([bible_adjust(oklab_to_rgb(c)) for c in cen])), 0, 255)
    out = []
    for c, a in bodies:
        q = np.zeros_like(c)
        if a.any():
            # 군집 번호는 조정 전 중심(cen) 기준으로 매기고, 색만 조정색으로 치환 (조정이 군집 경계를 흔들지 않게)
            d = ((rgb_to_oklab(c[a])[:, None, :] - cen[None]) ** 2).sum(2)
            q[a] = pal[d.argmin(1)]
        out.append((q, a))
    return out, pal


def flash(q, alpha):
    """피격 플래시: 밝은 쪽 절반은 거의 흰색, 어두운 쪽 절반은 옅은 청회색 (2색 추가)."""
    lum = q[alpha].mean(1)
    thr = np.median(lum)
    out = np.zeros_like(q)
    idx = np.where(alpha)
    out[idx] = np.where((q[alpha].mean(1) >= thr)[:, None], np.array([242, 238, 246]), np.array([186, 190, 206]))
    return out


def count_colors(rgba_list):
    s = set()
    for im in rgba_list:
        px = im.reshape(-1, 4)
        s |= {tuple(p[:3]) for p in px if p[3]}
    return len(s)


def sheet_stats(rgba_list):
    semi = sum(int(((im[..., 3] > 0) & (im[..., 3] < 255)).sum()) for im in rgba_list)
    return count_colors(rgba_list), semi


# ------------------------------------------------------------------ 한 종 처리
def run(key):
    sp = SPECS[key]
    cw, ch = sp['cell']
    feet = sp['feet']
    idle_p = next(SRC.glob(f"media-generation-{sp['src']}-0-*.webp"))
    atk_p = next(SRC.glob(f"media-generation-{sp['src']}-atk-0-*.webp"))
    # 몸통이 차지할 수 있는 최대 칸: 셀에서 외곽선 1px 양쪽, 위쪽 여유 1px 을 뺀다
    # 외곽선 1px + 바운스(부유 2px/보행 1px) + 넉백 3px 여유. 보스는 문서 §d-3 상한 136px.
    max_w, max_h = cw - 2 - 6, min(feet - 3, 136)
    flip = sp['src_right'] != sp['game_right']   # 공격 프레임에만 적용 (idle 은 정면 그림)

    irgb, imask = load_cutout(idle_p)
    idle_c = crop_bbox(irgb, imask)
    argb, amask = load_cutout(atk_p)
    atk_c = [crop_bbox(r, m) for r, m in split_strip(argb, amask)]

    n_idle = choose_n([idle_c], max_w, max_h)
    idle_b = box_down(*idle_c, n_idle)
    # 공격 그림은 같은 캐릭터가 더 작게 그려져 있다 → idle 결과 높이와 가장 큰 공격 프레임 높이가 같아지는 정수 N
    # (단 모든 프레임이 칸 안에 들어가는 최소 N 이상)
    idle_out_h = idle_b[1].any(1).sum()
    atk_maxh = max(f[1].shape[0] for f in atk_c)
    n_atk = max(choose_n(atk_c, max_w, max_h), int(round(atk_maxh / idle_out_h)))
    atk_b = [box_down(*f, n_atk) for f in atk_c]

    # 팔레트는 이 종의 4프레임(idle + atk 3) 전체로 하나
    bodies, pal = quantize([idle_b] + atk_b)
    qi, qa = bodies[0], bodies[1:]

    bounce = [0, -1, -2, -1] if sp['float'] else [0, -1, 0, -1]
    cells = []
    for dy in bounce:
        cells.append(place(qi, sp['cell'], feet, dy=dy))
    cells.append(place(qa[0], sp['cell'], feet, flip=flip))
    cells.append(place(qa[1], sp['cell'], feet, flip=flip))
    # hurt: 플래시 + 넉백(바라보는 반대쪽으로 3px, 아래로 1px)
    knock = -3 if sp['game_right'] else 3
    fq = (flash(qi[0], qi[1]), qi[1])
    cells.append(place(fq, sp['cell'], feet, dx=knock, dy=1))
    alt = place(qa[2], sp['cell'], feet, flip=flip)

    def finish(cc):
        im = to_rgba(*cc)
        return outline_pad(im)

    frames = [finish(c) for c in cells]
    alt_im = finish(alt)

    OUT.mkdir(parents=True, exist_ok=True)
    sheet = np.zeros((ch, cw * 7, 4), np.uint8)
    for i, f in enumerate(frames):
        sheet[:, i * cw:(i + 1) * cw] = f
    Image.fromarray(sheet, 'RGBA').save(OUT / f'{key}.png')
    Image.fromarray(alt_im, 'RGBA').save(OUT / f'{key}_alt_atk3.png')

    # --- 접촉 시트
    cur = Image.open(SPRITES / f"{sp['current']}.png").convert('RGBA')
    cur_cw = cur.size[0] // (8 if key == 'plagueking' else 7)
    cur7 = cur.crop((0, 0, cur_cw * 7, cur.size[1]))
    pre = []  # 팔레트 정규화 전 (같은 배치, 외곽선 없음, 플래시 없음)
    for i, src_b in enumerate([idle_b] + atk_b):
        c, a = place(src_b, sp['cell'], feet, flip=flip and i > 0)
        pre.append(to_rgba(c, a))
    S = 4
    gap, lab_h = 8, 14
    total_w = max(cur7.size[0], cw * 7) * S
    rows = [('CURRENT (src/assets/sprites/%s.png, first 7 cells)' % sp['current'], cur7),
            ('IMPORT (idle bounce x4 | tell=atk_1 | strike=atk_2 | hurt)', Image.fromarray(sheet, 'RGBA')),
            ('PRE-PALETTE (idle | atk_1 | atk_2 | atk_3) after cut+integer downscale, %d:1 / %d:1' % (n_idle, n_atk),
             Image.fromarray(np.concatenate(pre, 1), 'RGBA'))]
    H = sum(r[1].size[1] * S + lab_h + gap for r in rows) + gap
    cmp_im = Image.new('RGBA', (total_w + 2 * gap, H), (26, 30, 44, 255))
    d = ImageDraw.Draw(cmp_im)
    y = gap
    for title, im in rows:
        d.text((gap, y), title, fill=(220, 220, 230, 255))
        y += lab_h
        big = im.resize((im.size[0] * S, im.size[1] * S), Image.NEAREST)
        cmp_im.alpha_composite(big, (gap, y))
        cell_w = (cur_cw if im is cur7 else cw) * S
        for i in range(1, im.size[0] // (cell_w // S)):
            d.line([(gap + i * cell_w, y), (gap + i * cell_w, y + big.size[1])], fill=(70, 78, 104, 255))
        y += big.size[1] + gap
    cmp_im.convert('RGB').save(OUT / f'compare_{key}.png')

    ncol, semi = sheet_stats(frames)
    assert count_colors(frames + [alt_im]) <= 24 and semi == 0, 'palette/alpha budget exceeded'
    hs = [colorsys.rgb_to_hsv(*(np.array(p[:3]) / 255))[1:] for f in frames[:6] for p in f.reshape(-1, 4) if p[3] and tuple(p[:3]) != INK]
    mean_s, max_v = float(np.mean([x[0] for x in hs])), max(x[1] for x in hs)
    cur_arr = np.array(cur7)
    cur_cols = len({tuple(p[:3]) for p in cur_arr.reshape(-1, 4) if p[3]})
    bb = [np.where(f[..., 3] > 0) for f in frames[:6]]
    print(f"{key:13s} N idle={n_idle}:1 atk={n_atk}:1  idle src bbox {idle_c[1].shape[::-1]} -> "
          f"{tuple(int(v) for v in (frames[0][..., 3] > 0).sum(0).nonzero()[0][[0, -1]])}  "
          f"colors={ncol} (cur {cur_cols}) semi-alpha={semi} body_h(idle)={int(bb[0][0].max() - bb[0][0].min() + 1)} "
          f"mean_S(HSV)={mean_s:.2f} max_V={max_v:.2f} flip={flip} -> art/out/external/{key}.png")
    return dict(colors=ncol, cur_colors=cur_cols, n_idle=n_idle, n_atk=n_atk)


def main():
    if len(sys.argv) < 2 or sys.argv[1] not in list(SPECS) + ['all']:
        sys.exit('usage: python3 art/import_external.py <%s|all>' % '|'.join(SPECS))
    keys = list(SPECS) if sys.argv[1] == 'all' else [sys.argv[1]]
    for k in keys:
        run(k)


if __name__ == '__main__':
    main()
