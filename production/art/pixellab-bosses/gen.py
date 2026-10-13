"""Boss gen helpers (no token handling here; pxl.py reads it in-process)."""
import sys, json, os
from PIL import Image
sys.path.insert(0, os.path.dirname(__file__))
import pxl
RAW = os.path.join(os.path.dirname(__file__), 'raw')
LOG = os.path.join(os.path.dirname(__file__), 'usage_log.jsonl')
def _log(name, j, body):
    b = {k: v for k, v in body.items() if k != 'reference_image'}
    open(LOG, 'a').write(json.dumps({'name': name, 'usage': j.get('usage'), 'params': b}, ensure_ascii=False) + '\n')
def base(name, desc, seed, size=64, **kw):
    body = dict(description=desc, image_size={'width': size, 'height': size}, no_background=True,
                view='low top-down', direction='east', outline='single color black outline',
                shading='basic shading', detail='medium detail', seed=seed); body.update(kw)
    j = pxl.post('/generate-image-pixflux', body); _log(name, j, body)
    im = pxl.unb64(j['image']); im.save(f'{RAW}/{name}.png'); return im
def anim(name, base_img, action, seed, guidance=None, neg='', n=4, desc=''):
    body = dict(description=desc, action=action, reference_image=pxl.b64(base_img), image_size={'width': 64, 'height': 64},
                view='side', direction='east', n_frames=n, seed=seed, negative_description=neg)
    if guidance: body['text_guidance_scale'] = guidance
    j = pxl.post('/animate-with-text', body); _log(name, j, body)
    ims = [pxl.unb64(x) for x in j['images']]
    for i, im in enumerate(ims): im.save(f'{RAW}/{name}_{i}.png')
    return ims
