"""2장 M2 검증 보조: 지표(metrics.txt) + 4배 NEAREST 전/후 비교 이미지.
사용: python3 art/ch2m2_verify.py   (production/qa/asset-import/ch2-m2/ 의 before_/after_ 캡처를 쓴다)"""
import pathlib, numpy as np
from PIL import Image, ImageDraw
ROOT = pathlib.Path(__file__).parent.parent
QA = ROOT / 'production/qa/asset-import/ch2-m2'
LV = ROOT / 'src/assets/levels'
PR = ROOT / 'src/assets/props'
lines = []
for n in ('old_village', 'den1', 'den2', 'den3'):
    im = Image.open(LV / f'{n}.png').convert('RGBA'); a = np.asarray(im)
    rgb = a[..., :3].astype(np.float32) / 255
    L = rgb @ np.array([.3, .59, .11], np.float32)
    uniq = len({tuple(p) for p in a[..., :3].reshape(-1, 3)})
    lines.append(f'지형 {n} {im.size}: 알파 값 {sorted(set(a[...,3].ravel().tolist()))} · 고유색 {uniq} · 밝은 픽셀(L>0.82) {float((L>0.82).mean())*100:.3f}% · 평균 L {float(L.mean()):.3f} 최대 L {float(L.max()):.3f}')
for n in ('rockwall', 'hut_ruin', 'hut_ruin_b', 'old_tools', 'old_tools_mortar', 'old_tools_broom', 'old_tools_pot', 'old_tools_sandals', 'dok_torch', 'mortar_altar', 'doll'):
    im = Image.open(PR / f'{n}.png').convert('RGBA'); a = np.asarray(im)
    vis = a[..., 3] > 0
    rgb = a[..., :3].astype(np.float32) / 255
    L = rgb @ np.array([.3, .59, .11], np.float32)
    uniq = len({tuple(p) for p in a[vis][:, :3]})
    lines.append(f'소품 {n} {im.size}: 알파 {sorted(set(a[...,3].ravel().tolist()))} · 고유색 {uniq} · 밝은 픽셀 {float((L[vis]>0.82).mean())*100:.2f}%')
(QA / 'metrics.txt').write_text('\n'.join(lines) + '\n')
print('\n'.join(lines))


def pair(name, before, after, box, label):
    b = Image.open(QA / before).convert('RGB').crop(box); a = Image.open(QA / after).convert('RGB').crop(box)
    s = 4
    b = b.resize((b.width * s, b.height * s), Image.NEAREST); a = a.resize((a.width * s, a.height * s), Image.NEAREST)
    c = Image.new('RGB', (b.width + a.width + 8, b.height), (255, 0, 255))
    c.paste(b, (0, 0)); c.paste(a, (b.width + 8, 0))
    ImageDraw.Draw(c).text((6, 4), 'BEFORE (fallback)', fill=(255, 255, 0)); ImageDraw.Draw(c).text((b.width + 14, 4), 'AFTER ' + label, fill=(255, 255, 0))
    c.save(QA / name)


# 해상도 480x270 캡처에서 HUD·대사창을 피한 중앙 영역(120x68) 4배 확대
BOX = (180, 70, 300, 138)
for key in ('old_village_plaza', 'old_village_trail', 'den1_north', 'den1_east', 'den2_plaza', 'den3_arena'):
    if (QA / f'after_{key}.png').exists() and (QA / f'before_{key}.png').exists():
        pair(f'compare_{key}_4x.png', f'before_{key}.png', f'after_{key}.png', BOX, key)
