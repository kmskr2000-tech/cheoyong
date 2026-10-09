"""Pixel-map sources (art/src/*.py) -> PNG sprite sheets (art/out/).

Each source module defines PALETTE {char: '#rrggbb'} and FRAMES {name: [rows]}.
'.' is transparent. Rows must all be the same width; the build fails loudly otherwise.
Usage: python3 art/build.py [--preview N]   (preview writes an N-times upscale for review)
"""
import importlib.util, pathlib, sys
from PIL import Image

ROOT = pathlib.Path(__file__).parent
SRC, OUT = ROOT / 'src', ROOT / 'out'
GODOT = ROOT.parent / 'godot' / 'assets' / 'sprites'


def load(path):
    spec = importlib.util.spec_from_file_location(path.stem, path)
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


def frame_image(rows, pal, name):
    w = len(rows[0])
    for i, r in enumerate(rows):
        if len(r) != w:
            raise SystemExit(f'{name}: row {i} is {len(r)} wide, expected {w}: {r!r}')
    img = Image.new('RGBA', (w, len(rows)), (0, 0, 0, 0))
    for y, r in enumerate(rows):
        for x, ch in enumerate(r):
            if ch == '.':
                continue
            if ch not in pal:
                raise SystemExit(f'{name}: unknown palette key {ch!r} at ({x},{y})')
            h = pal[ch].lstrip('#')
            img.putpixel((x, y), (int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16), 255))
    return img


def main():
    sys.path.insert(0, str(SRC))
    scale = int(sys.argv[sys.argv.index('--preview') + 1]) if '--preview' in sys.argv else 0
    OUT.mkdir(exist_ok=True)
    for path in sorted(SRC.glob('*.py')):
        mod = load(path)
        frames = [(n, frame_image(r, mod.PALETTE, f'{path.stem}:{n}')) for n, r in mod.FRAMES.items()]
        fw = max(f.width for _, f in frames); fh = max(f.height for _, f in frames)
        sheet = Image.new('RGBA', (fw * len(frames), fh), (0, 0, 0, 0))
        for i, (_, f) in enumerate(frames):
            sheet.paste(f, (i * fw, 0))
        sheet.save(OUT / f'{path.stem}.png')
        GODOT.mkdir(parents=True, exist_ok=True)
        sheet.save(GODOT / f'{path.stem}.png')  # the Godot project reads its own copy
        print(f'{path.stem}.png  {len(frames)} frames of {fw}x{fh}: {", ".join(n for n, _ in frames)}')
        if scale:
            bg = Image.new('RGBA', sheet.size, (34, 40, 52, 255))
            bg.alpha_composite(sheet)
            bg.resize((sheet.width * scale, sheet.height * scale), Image.NEAREST).save(OUT / f'{path.stem}_preview.png')


if __name__ == '__main__':
    main()
