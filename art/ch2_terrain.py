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


BUILDERS = {'hwagae': build_hwagae}

if __name__ == '__main__':
    names = [a for a in sys.argv[1:] if not a.startswith('--')] or list(BUILDERS)
    for n in names:
        BUILDERS[n]()
