"""levels.gd 의 좌표(footprint)를 읽어 그림 좌표 마커로 바꿔 준다 (collision_author 오버레이용, 읽기 전용)."""
import re, pathlib
SRC = pathlib.Path(__file__).parent.parent / 'src/scripts/levels.gd'
T, K, OFFSET, TIER = 2, 0.75, 82, 26
GROUND_OF = {'gyeongju': 'village'}


def _level_text(name):
    txt = SRC.read_text()
    m = re.search(r'\n\t"%s": \{\n(.*?)\n\t\},?\n' % name, txt, re.S)
    return m.group(1) if m else ''


def _img(fx, fy):
    return fx, K * fy + OFFSET - TIER * T


def markers(name):
    lvl = {'village': 'gyeongju'}.get(name, name)
    t = _level_text(lvl)
    out = []
    for m in re.finditer(r'\["(\w+)", (\d+), (\d+)', t):  # props
        pass
    sect = None
    for line in t.split('\n'):
        s = line.strip()
        if s.startswith('"props"'): sect = 'props'
        elif s.startswith('"npcs"'): sect = 'npcs'
        elif s.startswith('"interact"'): sect = 'interact'
        elif s.startswith('"enemies"'): sect = 'enemies'
        elif s.startswith('"exits"'): sect = 'exits'
        elif s.startswith('"gates"'): sect = 'gates'
        elif s.startswith('"triggers"'): sect = 'triggers'
        elif s.startswith('"spawns"'): sect = 'spawns'
        elif s.startswith('"vents"'): sect = 'vents'
        if sect == 'props':
            for m in re.finditer(r'\["(\w+)", (-?\d+), (-?\d+)', s):
                out.append(('prop', m.group(1), *_img(int(m.group(2)), int(m.group(3))), (90, 160, 255)))
        elif sect == 'npcs':
            for m in re.finditer(r'\["(\w+)", "\w+", (-?\d+), (-?\d+)', s):
                out.append(('npc', m.group(1), *_img(int(m.group(2)), int(m.group(3))), (80, 255, 120)))
        elif sect == 'interact':
            for m in re.finditer(r'\["(\w+)", (-?\d+), (-?\d+)', s):
                out.append(('int', m.group(1), *_img(int(m.group(2)), int(m.group(3))), (80, 255, 255)))
        elif sect == 'enemies':
            for m in re.finditer(r'\["(\w+)", (-?\d+), (-?\d+)', s):
                out.append(('enemy', m.group(1), *_img(int(m.group(2)), int(m.group(3))), (255, 150, 40)))
        elif sect in ('exits', 'gates', 'triggers'):
            for m in re.finditer(r'Rect2\((-?\d+), (-?\d+), (-?\d+), (-?\d+)\)', s):
                x, y, w, h = map(int, m.groups())
                out.append(('rect', sect, *_img(x + w / 2, y + h / 2), (255, 60, 255)))
        elif sect == 'vents':
            for m in re.finditer(r'Vector2\((-?\d+), (-?\d+)\)', s):
                out.append(('vent', 'v', *_img(int(m.group(1)), int(m.group(2))), (170, 120, 255)))
        elif sect == 'spawns':
            for m in re.finditer(r'"(\w+)": Vector2\((-?\d+), (-?\d+)\)', s):
                out.append(('spawn', m.group(1), *_img(int(m.group(2)), int(m.group(3))), (255, 255, 60)))
    return out
