"""Drive 지형 일러스트(1920x1280 webp) -> 레벨 지면 한 장(+노멀맵+물 마스크)으로 정규화.
원본(~/workspace/goals/rpg/assets-drive/terrain/*.webp)은 repo 밖. 그대로 붙이지 않고:
  1) 3~4배 박스 다운스케일로 도트 격자에 맞춤  2) 적응 팔레트 양자화(디더 없음, 이음새 얼룩 방지)
  3) 밤 팔레트(푸른 그림자, 낮춘 채도/밝기)로 톤 정렬  4) 언샤프+국소 대비로 가독성
  5) 가장자리 비네트(캔버스 끝 이음새 숨김)  6) 휘도 기반 노멀맵, 바다 마스크(beach)
사용: python3 art/terrain_import.py
"""
import pathlib, numpy as np
from PIL import Image, ImageFilter, ImageEnhance

SRC = pathlib.Path.home() / 'workspace/goals/rpg/assets-drive/terrain'
OUT = pathlib.Path(__file__).parent.parent / 'src/assets/levels'
# level ground id -> (drive image, crop box in fractions (x0,y0,x1,y1), tone)
MAPS = {
    'beach':  ('beach',  (0, 0, 1, 1), dict(bright=0.80, sat=0.95, tint=(18, 26, 60), mix=0.18)),
    'village':('village',(0, 0, 1, 1), dict(bright=0.95, sat=0.95, tint=(14, 20, 48), mix=0.10)),
    'gwana':  ('village',(0.28, 0, 1, 0.85), dict(bright=0.92, sat=0.9, tint=(14, 20, 48), mix=0.12)),
    'pyega1': ('mansion',(0, 0, 1, 1), dict(bright=1.25, sat=0.95, tint=(24, 28, 70), mix=0.22)),
    'pyega2': ('mansion',(0.45, 0, 1, 0.9), dict(bright=1.25, sat=0.95, tint=(24, 28, 70), mix=0.22)),
    'palace': ('palace', (0.08, 0.06, 0.92, 0.94), dict(bright=1.0, sat=0.95, tint=(22, 30, 62), mix=0.14)),
}
# not used by a chapter-1 map; prepared at 640x394 for later chapters
SPARE = {'forest': 'forest', 'flowerfield': 'flowerfield', 'shrine': 'shrine', 'dungeon': 'dungeon', 'underworld': 'underworld'}
COLORS = 56


def process(name, box, tone, size, img=None):
    """img: 이미 합성한 PIL 이미지를 넘기면 name/box 는 무시한다(2장 지형 art/ch2_terrain.py 가 사용)."""
    w, h = size
    im = img.convert('RGB') if img is not None else Image.open(SRC / f'{name}.webp').convert('RGB')
    W, H = im.size
    if img is None:
        im = im.crop((int(box[0]*W), int(box[1]*H), int(box[2]*W), int(box[3]*H)))
    # cover-fit to (w,h), centre crop
    s = max(w / im.width, h / im.height)
    im = im.resize((round(im.width*s), round(im.height*s)), Image.BOX)
    l, t = (im.width - w)//2, (im.height - h)//2
    im = im.crop((l, t, l+w, t+h))
    im = ImageEnhance.Color(im).enhance(tone['sat'])
    a = np.asarray(im).astype(np.float32)
    a = a * tone['bright']
    tint = np.array(tone['tint'], np.float32)
    lum = (a @ np.array([.3, .59, .11], np.float32) / 255)[..., None]
    a = a * (1 - tone['mix']) + (tint + a * 0.6) * tone['mix'] * (1.2 - lum)   # shadows lean blue
    im = Image.fromarray(np.clip(a, 0, 255).astype(np.uint8))
    im = im.filter(ImageFilter.UnsharpMask(radius=1.2, percent=70, threshold=2))
    im = im.quantize(COLORS, method=Image.MEDIANCUT, dither=Image.NONE).convert('RGB')
    a = np.asarray(im).astype(np.float32)
    yy, xx = np.mgrid[0:h, 0:w]
    d = np.minimum.reduce([xx, w-1-xx, yy, h-1-yy]).astype(np.float32)
    v = np.clip(d / 24.0, 0, 1)[..., None] * 0.45 + 0.55
    a = a * v
    return Image.fromarray(np.clip(a, 0, 255).astype(np.uint8))


def normal(rgb):
    g = np.asarray(rgb.convert('L').filter(ImageFilter.GaussianBlur(1.0))).astype(np.float32) / 255
    dx = np.gradient(g, axis=1); dy = np.gradient(g, axis=0)
    k = 2.0
    n = np.dstack([-dx * k, dy * k, np.ones_like(g)])   # +Y up (OpenGL)
    n /= np.linalg.norm(n, axis=2, keepdims=True)
    out = ((n * 0.5 + 0.5) * 255).astype(np.uint8)
    return Image.fromarray(np.dstack([out, np.full(g.shape, 255, np.uint8)]), 'RGBA')


def sea_mask(rgb):
    """beach: the blue sea (water overlay shader reads alpha)"""
    a = np.asarray(rgb).astype(np.int32)
    r, g, b = a[..., 0], a[..., 1], a[..., 2]
    m = (b > r + 18) & (b > 40) & (g > r)
    m[: int(rgb.height * 0.30)] = False   # sky / distant mountains
    m = Image.fromarray((m * 255).astype(np.uint8)).filter(ImageFilter.MedianFilter(5))
    z = np.zeros((rgb.height, rgb.width, 4), np.uint8)
    z[..., :3] = 255
    z[..., 3] = np.asarray(m)
    return Image.fromarray(z, 'RGBA')


def main():
    for gid, (src, box, tone) in MAPS.items():
        size = Image.open(OUT / f'{gid}.png').size   # keep the baked canvas size (json/collision untouched)
        img = process(src, box, tone, size)
        img.convert('RGBA').save(OUT / f'{gid}.png')
        normal(img).save(OUT / f'{gid}_n.png')
        wm = sea_mask(img) if gid == 'beach' else Image.new('RGBA', size, (0, 0, 0, 0))
        wm.save(OUT / f'{gid}_water.png')
        print('ok', gid, size)
    for gid, src in SPARE.items():
        img = process(src, (0, 0, 1, 1), dict(bright=0.95, sat=0.95, tint=(20, 28, 60), mix=0.12), (640, 394))
        img.convert('RGBA').save(OUT / f'spare_{gid}.png')
        print('ok spare', gid)


if __name__ == '__main__':
    main()
