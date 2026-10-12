"""1장 일반 적 가독성 후처리 (hero-detail 5번). art/enemies.py 가 만든 plague_dog.png 는 어두운 해변 위에서 윤곽이 묻혀
(1) 암부 감마 리프트 (2) 윗면 1px 림라이트 를 얹는다. enemies.py 재실행 후에는 이 스크립트를 다시 돌릴 것.
사용: python3 art/enemy_readability.py  (원본은 art/out/plague_dog_orig.png 에 보관, 항상 원본에서 재생성 = 멱등)"""
import pathlib, shutil, numpy as np
from PIL import Image
R = pathlib.Path(__file__).parent; P = R.parent / 'src/assets/sprites/plague_dog.png'; O = R / 'out/plague_dog_orig.png'
O.parent.mkdir(exist_ok=True)
if not O.exists(): shutil.copy(P, O)
a = np.array(Image.open(O).convert('RGBA')).astype(float)
op = a[..., 3] > 0
a[..., :3] = np.where(op[..., None], 255 * (a[..., :3] / 255) ** 0.72, 0)
H, W = op.shape
for x0 in range(0, W, 44):                       # 프레임별 윗면 림
    sub = op[:, x0:x0 + 44]
    top = sub & ~np.roll(sub, 1, 0)
    top[0] = sub[0]
    ys, xs = np.where(top)
    for y, x in zip(ys, xs):
        a[y, x0 + x, :3] = np.minimum(a[y, x0 + x, :3] * 1.0 + np.array([70, 62, 50]), 255)
Image.fromarray(a.astype(np.uint8), 'RGBA').save(P); print('ok')
