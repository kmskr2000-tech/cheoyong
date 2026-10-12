"""2장 M1 지형(hwagae·jiri) — Drive 지형 일러스트를 합성·정규화해 레벨 지면 한 장으로.
1장 6맵과 같은 화풍·같은 도트 크기(terrain_import.process: 박스 다운스케일 → 56색 양자화 → 밤 팔레트 톤 → 언샤프 → 비네트)를
쓰되, 800/1120 폭은 1920 한 장에서 정수배로 안 나오므로 소스 해상도에서 합성한 뒤 한 번에 줄인다.
두 맵의 배율은 같다(S=2.4: 원본 1px 도트 ≈ 1.7~2px). 1장 맵 파일은 건드리지 않는다.
사용: python3 art/ch2_terrain.py [hwagae|jiri ...]   (이름 없으면 둘 다) → src/assets/levels/<id>.png/_n.png/_water.png + 시드 json
충돌·높이 json 은 art/ch2_collision.py 가 만든다.
"""
import json, pathlib, sys
import numpy as np
from PIL import Image, ImageFilter

ROOT = pathlib.Path(__file__).parent
sys.path.insert(0, str(ROOT))
import terrain_import as ti

SRCDIR = ti.SRC
OUT = ti.OUT
S = 2.4                    # 소스 px / 최종 px
H = 326                    # 최종 PNG 높이: footprint 400줄(=25칸) + 카메라 가동 범위 270px 확보 (H-56 >= 270)
OFFSET, TIER, TS, K = 82, 26, 16, 0.75


def load(name):
    return Image.open(SRCDIR / f'{name}.png').convert('RGB')


def feather(w, h, edges, width):
    """edges 에 해당하는 가장자리로 갈수록 0 이 되는 알파(L). edges ⊂ {'l','r','t','b'}"""
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
    a = np.ones((h, w), np.float32)
    if 'l' in edges: a = np.minimum(a, xx / width)
    if 'r' in edges: a = np.minimum(a, (w - 1 - xx) / width)
    if 't' in edges: a = np.minimum(a, yy / width)
    if 'b' in edges: a = np.minimum(a, (h - 1 - yy) / width)
    return np.clip(a, 0, 1)


def paste(canvas, patch, x, y, mask=None):
    """canvas, patch: float32 HxWx3. mask: HxW(0..1) or None. 캔버스 밖은 잘라낸다."""
    ph, pw = patch.shape[:2]
    x0, y0 = max(0, x), max(0, y)
    x1, y1 = min(canvas.shape[1], x + pw), min(canvas.shape[0], y + ph)
    if x1 <= x0 or y1 <= y0:
        return
    p = patch[y0 - y:y1 - y, x0 - x:x1 - x]
    m = np.ones(p.shape[:2], np.float32) if mask is None else mask[y0 - y:y1 - y, x0 - x:x1 - x]
    canvas[y0:y1, x0:x1] = canvas[y0:y1, x0:x1] * (1 - m[..., None]) + p * m[..., None]


def finish(gid, src_img, tone, w):
    """합성 소스(S배 크기) → 레벨 PNG 3종 + 시드 json. 크기 w×H."""
    img = ti.process(None, None, tone, (w, H), img=src_img)
    img.convert('RGBA').save(OUT / f'{gid}.png')
    ti.normal(img).save(OUT / f'{gid}_n.png')
    Image.new('RGBA', (w, H), (0, 0, 0, 0)).save(OUT / f'{gid}_water.png')   # 물 없음(셰이더가 읽는 빈 마스크)
    meta_p = OUT / f'{gid}.json'
    if not meta_p.exists():
        meta = {'offset': OFFSET, 'tier': TIER, 'ts': TS, 'k': K, 'size': [w, H - OFFSET], 'footprint': [w, 400],
                'heights': ['2' * (w // TS)] * 25, 'collision': [], 'land_tier': 2}
        meta_p.write_text(json.dumps(meta, separators=(',', ':')))
    print('ok', gid, (w, H))
    return img


# ---------------------------------------------------------------- hwagae: 800x326, 저녁 장터 광장
def hwagae_source():
    w, h = round(800 * S), round(H * S)          # 1920 x 782
    v = load('village')
    y0 = 180
    return v.crop((0, y0, 1920, y0 + h))


HWAGAE_TONE = dict(bright=0.97, sat=0.95, tint=(34, 24, 62), mix=0.14)


def build_hwagae():
    return finish('hwagae', hwagae_source(), HWAGAE_TONE, 800)


# ---------------------------------------------------------------- jiri: 1120x326, 지리산 산길 (산신각 마당 → 길목 → 바위 지대)
# 소스: Drive shrine(산신각·제상·거송·금줄·절벽·돌탑) 한 장을 S배로 가로 800px 만큼 쓰고, 동쪽 320px 는 forest 의 어두운 숲으로 잇는다.
# 새벽 금빛 하늘/안개가 '흰 판'이 되지 않게: 하이라이트 압축 + 밤 톤(푸른 그림자) + 따뜻한 제상 촛불만 남긴다.
JIRI_ROW0 = 308          # shrine 에서 자를 첫 행 (그림 y 180 ↔ 소스 행 740 = 금줄 아래 돌길)
FOREST_ROW0 = 380


def compress(a, knee, k):
    lum = (a @ np.array([.3, .59, .11], np.float32))[..., None]
    over = np.maximum(lum - knee, 0)
    return a * ((lum - over * (1 - k)) / np.maximum(lum, 1e-3))


def jiri_source():
    w, h = round(1120 * S), round(H * S)         # 2688 x 782
    cv = np.zeros((h, w, 3), np.float32)
    sh = np.asarray(load('shrine').crop((0, JIRI_ROW0, 1920, JIRI_ROW0 + h)), np.float32)
    paste(cv, sh, 0, 0)
    ov = 288
    fo = np.asarray(load('forest').crop((0, FOREST_ROW0, w - 1920 + ov, FOREST_ROW0 + h)), np.float32)
    fo = compress(fo, 95, 0.35)                       # 빛줄기(흰 띠) 눌러 줌
    lum = (fo @ np.array([.3, .59, .11], np.float32))[..., None]
    fo = (lum + (fo - lum) * 0.62) * np.array([0.80, 0.86, 1.12], np.float32) * 0.84   # 이끼 초록을 푸른 밤으로
    # 숲 안개(푸른 저채도 띠)는 평평한 판처럼 보여서 이끼색으로 눌러 둔다
    r_, g_, b_ = fo[..., 0], fo[..., 1], fo[..., 2]
    from scipy import ndimage as ndi
    haze = ndi.gaussian_filter(((b_ > g_ + 4) & (b_ > r_ + 22)).astype(np.float32), 6)[..., None]
    moss = fo * np.array([0.62, 0.80, 0.70], np.float32)
    fo = fo * (1 - haze) + moss * haze
    paste(cv, fo, 1920 - ov, 0, feather(fo.shape[1], fo.shape[0], 'l', ov))
    # 서쪽 입구: 왼쪽 끝이 어두운 덤불이라, 돌길(그림 x125~185)을 소스 해상도로 복제해 x0까지 이어 붙인다
    x0, x1, y0, y1 = round(125 * S), round(185 * S), round(160 * S), round(212 * S)
    strip = cv[y0:y1, x0:x1].copy()
    sw = x1 - x0
    for k in range(1, 3):
        xx = x0 - k * sw
        if xx + sw <= 0:
            break
        m = feather(sw, y1 - y0, 'tb', 40)
        if k == 1:
            m = np.minimum(m, 1)
        paste(cv, strip[:, ::1], xx, y0, m)
    return Image.fromarray(np.clip(compress(cv, 150, 0.45), 0, 255).astype(np.uint8))


JIRI_TONE = dict(bright=0.78, sat=1.0, tint=(26, 26, 72), mix=0.22)


def build_jiri():
    return finish('jiri', jiri_source(), JIRI_TONE, 1120)


BUILDERS = {'hwagae': build_hwagae, 'jiri': build_jiri}

if __name__ == '__main__':
    names = [a for a in sys.argv[1:] if not a.startswith('--')] or list(BUILDERS)
    for n in names:
        BUILDERS[n]()
