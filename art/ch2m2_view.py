"""작업용 뷰어: 레벨 png 에 걷기 마스크(초록)·좌표 격자를 얹어 저장. python3 art/ch2m2_view.py old_village out.png [scale]"""
import sys, pathlib
import numpy as np
from PIL import Image, ImageDraw
sys.path.insert(0, str(pathlib.Path(__file__).parent))
import ch2m2_terrain as T
name, out = sys.argv[1], sys.argv[2]
sc = int(sys.argv[3]) if len(sys.argv) > 3 else 2
im = Image.open(T.OUT / f'{name}.png').convert('RGB')
wm = T.walk_mask(name, 1.0)
a = np.asarray(im).astype(np.float32)
a = a * (1 - 0.35 * wm[..., None]) + np.array([40, 255, 80], np.float32) * 0.35 * wm[..., None]
im = Image.fromarray(a.astype(np.uint8)).resize((im.width * sc, im.height * sc), Image.NEAREST)
d = ImageDraw.Draw(im)
for x in range(0, im.width // sc, 50):
    d.line([x * sc, 0, x * sc, im.height], fill=(255, 255, 0)); d.text((x * sc + 2, 2), str(x), fill=(255, 255, 0))
for y in range(0, im.height // sc, 50):
    d.line([0, y * sc, im.width, y * sc], fill=(0, 255, 255)); d.text((2, y * sc + 2), str(y), fill=(0, 255, 255))
im.save(out)
