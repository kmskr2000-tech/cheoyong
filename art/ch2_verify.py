"""2장 M1 에셋 검증: 고유 색 수·알파 집합·평균 채도/명도·'흰 판' 비율 + 4배 NEAREST 비교 이미지.
사용: python3 art/ch2_verify.py   → production/qa/asset-import/ch2-m1/{compare_*_4x.png, metrics.txt}
"""
import pathlib, colorsys
import numpy as np
from PIL import Image

ROOT = pathlib.Path(__file__).parent.parent
LV, PR = ROOT / 'src/assets/levels', ROOT / 'src/assets/props'
QA = ROOT / 'production/qa/asset-import/ch2-m1'


def stats(path):
    im = Image.open(path).convert('RGBA')
    a = np.asarray(im)
    rgb = a[..., :3].astype(np.float32) / 255
    mx, mn = rgb.max(-1), rgb.min(-1)
    sat = np.where(mx > 0, (mx - mn) / np.maximum(mx, 1e-6), 0)
    opaque = a[..., 3] > 0
    lum = rgb @ np.array([.3, .59, .11], np.float32)
    cols = np.unique(a[opaque][:, :3].reshape(-1, 3), axis=0)
    return dict(size=im.size, colors=len(cols), alpha=sorted(set(np.unique(a[..., 3]).tolist())),
                mean_s=float(sat[opaque].mean()), mean_v=float(mx[opaque].mean()),
                white_ratio=float((lum[opaque] > 0.82).mean()), maxlum=float(lum[opaque].max()))


def side_by_side(a_path, a_box, b_path, b_box, out, label_a, label_b):
    A = Image.open(a_path).convert('RGB').crop(a_box).resize(((a_box[2] - a_box[0]) * 4, (a_box[3] - a_box[1]) * 4), Image.NEAREST)
    B = Image.open(b_path).convert('RGB').crop(b_box).resize(((b_box[2] - b_box[0]) * 4, (b_box[3] - b_box[1]) * 4), Image.NEAREST)
    sh = Image.new('RGB', (A.width + B.width + 12, max(A.height, B.height)), (255, 0, 255))
    sh.paste(A, (0, 0)); sh.paste(B, (A.width + 12, 0))
    sh.save(out)


if __name__ == '__main__':
    QA.mkdir(parents=True, exist_ok=True)
    lines = ['# 2장 M1 에셋 지표 (art/ch2_verify.py)', '이름 | 크기 | 고유색 | 알파 집합 | 평균 S | 평균 V | 밝은(L>0.82) 비율 | 최대 L']
    for n in ('village', 'pyega1', 'hwagae', 'jiri'):
        s = stats(LV / f'{n}.png')
        lines.append(f"level/{n} | {s['size']} | {s['colors']} | {s['alpha']} | {s['mean_s']:.2f} | {s['mean_v']:.2f} | {s['white_ratio']:.4f} | {s['maxlum']:.2f}")
    for n in ('stall', 'rockwall', 'tent', 'burnt_stall', 'sansingak'):
        s = stats(PR / f'{n}.png')
        lines.append(f"prop/{n} | {s['size']} | {s['colors']} | {s['alpha']} | {s['mean_s']:.2f} | {s['mean_v']:.2f} | {s['white_ratio']:.4f} | {s['maxlum']:.2f}")
    (QA / 'metrics.txt').write_text('\n'.join(lines) + '\n')
    print('\n'.join(lines))
    side_by_side(LV / 'hwagae.png', (200, 150, 400, 250), LV / 'village.png', (200, 150, 400, 250), QA / 'compare_hwagae_vs_village_4x.png', 'hwagae', 'village')
    side_by_side(LV / 'jiri.png', (100, 130, 300, 230), LV / 'pyega1.png', (200, 150, 400, 250), QA / 'compare_jiri_vs_pyega1_4x.png', 'jiri', 'pyega1')
    side_by_side(LV / 'jiri.png', (780, 60, 980, 160), LV / 'hwagae.png', (400, 60, 600, 160), QA / 'compare_jiri_east_vs_hwagae_4x.png', 'jiri-east', 'hwagae')
