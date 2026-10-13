#!/usr/bin/env python3
"""raw/ 캡처 → 사장님 시안 비교 이미지. 사용: python3 production/qa/view-proto/compose.py
각 캡처를 '아이폰 가로(2556x1179 기기 픽셀)' 화면에 정수 배율 nearest 로 올려놓은 모습(검정 여백 포함)을 만들고,
같은 크기로 줄여 나란히 놓는다 → 안마다 캐릭터가 폰에서 실제로 얼마나 크게/작게 보이는지가 그대로 드러난다."""
import os, sys, glob
from PIL import Image, ImageDraw, ImageFont
HERE = os.path.dirname(os.path.abspath(__file__))
RAW = os.path.join(HERE, 'raw')
FONT = os.path.join(HERE, '..', '..', '..', 'src/assets/fonts/Galmuri11-Bold.ttf')
DEV = (2556, 1179)   # 393x852pt @3x 가로
VARS = [('a', 'A 현행 480×270'), ('bkh', 'A+ 가로만 확장(높이 270 유지)'), ('b576', 'B1 576×324'), ('b640', 'B2 640×360'), ('c75', 'C 줌아웃 0.75 (480×270 렌더)')]
f_big = ImageFont.truetype(FONT, 30)
f_mid = ImageFont.truetype(FONT, 22)


def on_device(im):
    s = max(1, min(DEV[0] // im.width, DEV[1] // im.height))
    up = im.convert('RGB').resize((im.width * s, im.height * s), Image.NEAREST)
    canvas = Image.new('RGB', DEV, (0, 0, 0))
    canvas.paste(up, ((DEV[0] - up.width) // 2, (DEV[1] - up.height) // 2))
    used = up.width * up.height / (DEV[0] * DEV[1]) * 100
    return canvas, s, used


def panel(key, label, scene, scale_out=0.34, aggro=False):
    p = os.path.join(RAW, '%s_%s.png' % (scene, key))
    if not os.path.exists(p):
        return None
    im = Image.open(p)
    dev, s, used = on_device(im)
    if aggro:   # 요괴 어그로 반경 130px(enemy.gd): 처용 발밑(화면 중심 +16px)이 중심. 줌 C는 월드가 0.75배라 반경도 0.75배
        z = 0.75 if key == 'c75' else 1.0
        up_w, up_h = im.width * s, im.height * s
        ox, oy = (DEV[0] - up_w) // 2, (DEV[1] - up_h) // 2
        cx, cy = ox + up_w // 2, oy + up_h // 2 + 16 * s * z
        import re
        lg = os.path.join(RAW, '%s_%s.log' % (scene, key))
        if os.path.exists(lg):   # 맵 가장자리에서는 카메라가 처용을 중심에 못 둔다 → 실제 화면 좌표(HERO_SCREEN) 사용
            m = re.search(r'HERO_SCREEN \(([-\d.]+), ([-\d.]+)\)', open(lg, errors='ignore').read())
            if m:
                cx, cy = ox + float(m.group(1)) * s, oy + float(m.group(2)) * s
        r = 130 * s * z
        d0 = ImageDraw.Draw(dev)
        d0.ellipse([cx - r, cy - r, cx + r, cy + r], outline=(255, 60, 60), width=10)
        d0.rectangle([ox, oy, ox + up_w - 1, oy + up_h - 1], outline=(90, 160, 255), width=6)
    sm = dev.resize((int(DEV[0] * scale_out), int(DEV[1] * scale_out)), Image.LANCZOS)
    cap_h = 64
    out = Image.new('RGB', (sm.width, sm.height + cap_h), (18, 18, 26))
    out.paste(sm, (0, 0))
    d = ImageDraw.Draw(out)
    d.rectangle([0, 0, sm.width - 1, sm.height - 1], outline=(70, 70, 90))
    d.text((8, sm.height + 4), label, font=f_big, fill=(255, 235, 170))
    d.text((8, sm.height + 36), '논리 %d×%d · %d배 · 폰 화면 사용 %d%%' % (im.width, im.height, s, used), font=f_mid, fill=(190, 200, 220))
    return out


def grid(scene, title, cols=2, aggro=False, out=None):
    ps = [panel(k, l, scene, aggro=aggro) for k, l in VARS]
    ps = [p for p in ps if p]
    if not ps:
        return
    w, h = ps[0].size
    rows = (len(ps) + cols - 1) // cols
    head = 70
    sheet = Image.new('RGB', (cols * w + (cols + 1) * 12, head + rows * (h + 12) + 12), (10, 10, 16))
    ImageDraw.Draw(sheet).text((12, 16), title + '  [아이폰 가로 2556×1179px 기준·정수배율]', font=f_big, fill=(255, 255, 255))
    for i, p in enumerate(ps):
        sheet.paste(p, (12 + (i % cols) * (w + 12), head + (i // cols) * (h + 12)))
    o = os.path.join(HERE, out or 'cmp_%s.png' % scene)
    sheet.save(o, optimize=True)
    print('wrote', o, sheet.size)


def hero_crop(scene, size=72, zoom=6):
    tiles = []
    for k, l in VARS:
        p = os.path.join(RAW, '%s_%s.png' % (scene, k))
        if not os.path.exists(p) or k == 'bkh':
            continue
        im = Image.open(p).convert('RGB')
        cx, cy = im.width // 2, im.height // 2 + 16   # 카메라는 발밑에서 16px 위 (맵 가장자리에서는 어긋남 → 로그의 HERO_SCREEN 우선)
        lg = os.path.join(RAW, '%s_%s.log' % (scene, k))
        if os.path.exists(lg):
            import re
            m = re.search(r'HERO_SCREEN \(([-\d.]+), ([-\d.]+)\)', open(lg, errors='ignore').read())
            if m:
                cx, cy = int(float(m.group(1))), int(float(m.group(2)))
        box = (cx - size // 2, cy - size // 2 - 18, cx + size // 2, cy + size // 2 - 18)
        c = im.crop(box).resize((size * zoom, size * zoom), Image.NEAREST)
        t = Image.new('RGB', (c.width, c.height + 34), (18, 18, 26))
        t.paste(c, (0, 0))
        ImageDraw.Draw(t).text((6, c.height + 4), l, font=f_mid, fill=(255, 235, 170))
        tiles.append(t)
    if not tiles:
        return
    sheet = Image.new('RGB', (len(tiles) * (tiles[0].width + 10) + 10, tiles[0].height + 70), (10, 10, 16))
    ImageDraw.Draw(sheet).text((10, 10), '처용 확대 (논리 %dpx 창을 ×%d nearest) — 줌아웃 C는 스프라이트 축소로 픽셀 열·행이 불규칙하게 빠진다' % (size, zoom), font=f_mid, fill=(255, 255, 255))
    for i, t in enumerate(tiles):
        sheet.paste(t, (10 + i * (t.width + 10), 60))
    o = os.path.join(HERE, 'cmp_hero_crop_%s.png' % scene)
    sheet.save(o, optimize=True)
    print('wrote', o, sheet.size)


if __name__ == '__main__':
    grid('s1_village', 'S1 경주 변두리(마을) — 같은 위치')
    grid('s3_palace', 'S3 월성 편전 — 맵 폭 512(가장 좁음)')
    grid('s4_combat', 'S4 전투 — 개·구울이 달려드는 순간')
    grid('s5_touch', 'S5 터치 UI(--touch)')
    grid('s2_hwagae', 'S2 화개 저자(2장, 폭 800)')
    grid('s1_village', 'S1 요괴 어그로 반경 130px(빨강 원) — 파랑 테두리 = 논리 화면', aggro=True, out='cmp_aggro.png')
    hero_crop('s1_village')
