"""Pixellab helper. Token is read in-process from ~/.claude.json (never written/printed)."""
import json, time, base64, io, os, sys, requests
from PIL import Image
BASE = 'https://api.pixellab.ai/v1'
def _tok():
    return json.load(open(os.path.expanduser('~/.claude.json')))['projects']['/home/hatch']['mcpServers']['pixellab']['headers']['Authorization']
def b64(img):
    b = io.BytesIO(); img.save(b, 'PNG'); return {'type': 'base64', 'base64': base64.b64encode(b.getvalue()).decode()}
def unb64(d):
    s = d['base64']; s = s.split(',', 1)[1] if s.startswith('data:') else s
    return Image.open(io.BytesIO(base64.b64decode(s))).convert('RGBA')
def post(path, body, timeout=300):
    t = time.time()
    for _ in range(8):
        r = requests.post(BASE + path, json=body, headers={'Authorization': _tok()}, timeout=timeout)
        if r.status_code == 429 and 'concurrent' in r.text: time.sleep(5); continue  # free plan: 1 job at a time
        break
    print(path, r.status_code, round(time.time() - t), 's', file=sys.stderr)
    if r.status_code != 200:
        print('ERROR', r.status_code, r.text[:500], file=sys.stderr); sys.exit(2)
    j = r.json(); print('usage', j.get('usage'), file=sys.stderr); return j
