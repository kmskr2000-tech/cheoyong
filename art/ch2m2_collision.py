"""2장 M2 지형 4종의 충돌·높이 json + 검증.
 - json: ch2m2_maps 의 걷기 마스크(walk+TRAILS, block) → art/collision_author.build() (4px 격자, 절반 미만 걷기 = 막힘). 1장·M1 json 은 건드리지 않는다.
 - 검증(--check): 실제 게임 충돌(src/scripts/level.gd + tests/godot/walkability.gd)을 그대로 재현한다.
     발판 질의 모양 11x7, 중심 = (x, y-3), 4px 격자, 8방향 BFS, 충돌 = 레벨 json 사각형 + 월드 가장자리 벽(16px) + 소품 충돌 사각형.
     소품 충돌: 몸통 위치 = lift(fp) = (fx, 0.75*fy-52), 크기 (2*hx, max(2, round(2*hy*0.75))), 위로 올라가 앉음. OCCLUDE 는 level.gd 값 + 신규 소품 제안값.
   (M1 에서 마스크 BFS 가 게임 충돌과 달랐던 사례 — 길목 연결이 게임에선 끊김 — 를 막으려고, 마스크가 아니라 '구운 json 의 실제 사각형'으로 검사한다.)
사용: python3 art/ch2m2_collision.py [맵...]            → json 갱신 + overlay_<맵>.png
      python3 art/ch2m2_collision.py --check [맵...]    → reach_check.txt
"""
import pathlib, sys, json, types
import numpy as np
from PIL import Image, ImageDraw
from scipy import ndimage as ndi

HERE = pathlib.Path(__file__).parent
sys.path.insert(0, str(HERE))
import collision_author as ca
import ch2m2_maps as M

ROOT = HERE.parent
QA = ROOT / 'production/qa/asset-import/ch2-m2'
ca.OUTQA = QA
OFFSET, TIER, K = 82, 26, 0.75

for n, spec in M.MAPS.items():
    ca.mp(n, ground=n, walk=spec['walk'] + M.TRAILS.get(n, []), block=spec.get('block', []))

SP, NP, IT, PR, EN, RC = 'spawn', 'npc', 'int', 'prop', 'enemy', 'rect'
Y_, G_, C_, B_, O_, M_ = (255, 255, 60), (80, 255, 120), (80, 255, 255), (90, 160, 255), (255, 150, 40), (255, 60, 255)

# 소품 충돌 반크기(footprint) — level.gd OCCLUDE 값 + 이번에 새로 만든 소품 제안값(README 와 동일)
OCCLUDE = {'pillar': (7, 5), 'jars': (16, 6), 'beam': (24, 6), 'altar': (20, 6), 'house': (50, 28), 'dodam': (32, 6), 'cairn': (3, 3),
           'rockwall': (32, 20), 'seonang': (8, 6), 'lantern': (8, 6),
           'hut_ruin': (40, 16), 'hut_ruin_b': (40, 16), 'old_tools': (10, 4), 'dok_torch': (4, 3), 'mortar_altar': (30, 12), 'doll': (3, 3)}

MARKERS, PROPS, REACH = {}, {}, {}   # 맵별 정의는 ch2m2_markers.py 에서 채운다
import ch2m2_markers as MK
MARKERS.update(MK.MARKERS); PROPS.update(MK.PROPS); REACH.update(MK.REACH)


def _markers(name):
    return [(k, l, fx, K * fy + OFFSET - TIER * 2, c) for k, l, fx, fy, c in MARKERS.get(name, [])]


def build(names):
    lm = types.ModuleType('level_markers')
    lm.markers = _markers
    sys.modules['level_markers'] = lm
    QA.mkdir(parents=True, exist_ok=True)
    for n in names:
        ca.build(n)


def blocked_grid(name, with_props=True):
    """2배 해상도 png 좌표계의 막힘 마스크(+사방 16px 가장자리 벽). 반환 (mask2x, pad)"""
    meta = json.load(open(ca.LV / f'{name}.json'))
    W = meta['size'][0]
    H = meta['size'][1] + OFFSET
    pad = 16
    m = np.zeros(((H + 2 * pad) * 2, (W + 2 * pad) * 2), bool)

    def fill(x, y, w, h):          # png 좌표 사각형
        x0, y0 = int(round((x + pad) * 2)), int(round((y + pad) * 2))
        x1, y1 = int(round((x + w + pad) * 2)), int(round((y + h + pad) * 2))
        m[max(0, y0):max(0, y1), max(0, x0):max(0, x1)] = True
    for x, y, w, h in meta['collision']:
        fill(x, y + OFFSET, w, h)
    fill(-pad, -pad, W + 2 * pad, pad)                       # 위 벽(png y<0)
    fill(-pad, H - TIER, W + 2 * pad, TIER + pad)            # 아래 벽(png y>=H-26)
    fill(-pad, -pad, pad, H + 2 * pad)
    fill(W, -pad, pad, H + 2 * pad)
    if with_props:
        for prop, fx, fy in PROPS.get(name, []):
            hx, hy = OCCLUDE.get(prop, (3, 3))
            h = max(2, round(2 * hy * K))
            py = K * fy - TIER * 2 + OFFSET                  # 몸통 위치(png y)
            fill(fx - hx, py - h, 2 * hx, h)
    return m, pad, meta, W, H


def free_grid(name, with_props=True, foot=(11, 7)):
    """walkability.gd 의 _free 와 같은 판정: 4px 격자 칸마다 발판(11x7, 중심 (x,y-3))이 막힘과 겹치면 불가."""
    m, pad, meta, W, H = blocked_grid(name, with_props)
    ii = np.pad(m.cumsum(0).cumsum(1), ((1, 0), (1, 0))).astype(np.int64)
    gw, gh = W // 4, H // 4
    free = np.zeros((gh, gw), bool)
    for iy in range(gh):
        for ix in range(gw):
            x2 = int(round((4 * ix + pad) * 2)); y2 = int(round((4 * iy + pad) * 2))     # 격자 점(png)
            # 발판: x∈[x-5.5,x+5.5], y(screen)∈[y-6.5, y+0.5] → png 동일 이동. 2배 해상도 정수 경계
            xa, xb = x2 - 11, x2 + 11
            ya, yb = y2 - 13, y2 + 1
            if xa < 0 or ya < 0 or xb > m.shape[1] or yb > m.shape[0]:
                continue
            s = ii[yb, xb] - ii[ya, xb] - ii[yb, xa] + ii[ya, xa]
            free[iy, ix] = (s == 0)
    return free, W, H


def pt(fx, fy):
    return int(round(fx / 4)), int(round((K * fy + OFFSET - TIER * 2) / 4))


def components(free):
    return ndi.label(free, structure=np.ones((3, 3)))[0]


def check(names):
    lines = []
    ok_all = True
    for n in names:
        free, W, H = free_grid(n)
        lab = components(free)
        ms = {m[1]: m for m in MARKERS[n]}
        start, targets = REACH[n]
        sx, sy = pt(ms[start][2], ms[start][3])
        sl = lab[sy, sx]
        lines.append(f'## {n}  (게임 충돌 재현 BFS: 격자 {free.shape[1]}x{free.shape[0]}, 자유 칸 {int(free.sum())}, start {start} 칸=({sx},{sy}) 성분={sl})')
        if sl == 0:
            lines.append('- FAIL: 시작 칸이 막혀 있음'); ok_all = False
        for t in targets:
            x, y = pt(ms[t][2], ms[t][3])
            # walkability.gd 의 _near 와 같이 반경 안 가장 가까운 도달 칸을 허용(npc·상호작용 26px, 그 외 6px)
            rad = 26 if ms[t][0] in (NP, IT) else (14 if ms[t][0] == RC else 6)
            r = int(rad / 4) + 1
            hit = False
            for dy in range(-r, r + 1):
                for dx in range(-r, r + 1):
                    yy, xx = y + dy, x + dx
                    if 0 <= yy < lab.shape[0] and 0 <= xx < lab.shape[1] and lab[yy, xx] == sl and sl != 0 and (dx * 4) ** 2 + (dy * 4) ** 2 <= rad ** 2:
                        hit = True
            ok_all &= hit
            lines.append(f'- {t:14s} fp=({ms[t][2]},{ms[t][3]}) 칸=({x},{y}) 도달 {"OK" if hit else "FAIL"}  (허용 반경 {rad}px)')
        # 고리(우회로) 검사: spec 의 LOOPS = [(이름, 막을 footprint 사각형들, 시작, 끝)] — 해당 사각형을 막아도 이어지면 우회로 있음
        for (label, rects, a, b) in MK.LOOPS.get(n, []):
            m2, pad, meta, W2, H2 = blocked_grid(n)
            for (x0, y0, x1, y1) in rects:     # footprint 사각형 → png
                yy0, yy1 = K * y0 + OFFSET - TIER * 2, K * y1 + OFFSET - TIER * 2
                m2[int((yy0 + pad) * 2):int((yy1 + pad) * 2), int((x0 + pad) * 2):int((x1 + pad) * 2)] = True
            ii = np.pad(m2.cumsum(0).cumsum(1), ((1, 0), (1, 0))).astype(np.int64)
            gw, gh = W2 // 4, H2 // 4
            f2 = np.zeros((gh, gw), bool)
            for iy in range(gh):
                for ix in range(gw):
                    x2 = int(round((4 * ix + pad) * 2)); y2 = int(round((4 * iy + pad) * 2))
                    xa, xb, ya, yb = x2 - 11, x2 + 11, y2 - 13, y2 + 1
                    if xa < 0 or ya < 0 or xb > m2.shape[1] or yb > m2.shape[0]:
                        continue
                    f2[iy, ix] = (ii[yb, xb] - ii[ya, xb] - ii[yb, xa] + ii[ya, xa]) == 0
            l2 = components(f2)
            ax, ay = pt(ms[a][2], ms[a][3]); bx, by = pt(ms[b][2], ms[b][3])
            conn = l2[ay, ax] != 0 and l2[ay, ax] == l2[by, bx]
            lines.append(f'- 우회로 [{label}] {a}→{b} 막은 채로 {"이어짐 (OK)" if conn else "끊김 (FAIL)"}')
            ok_all &= conn
        if n in MK.BOXES:
            bw, bh = MK.BOXES[n]
            for with_props in (False, True):
                fr, _, _ = free_grid(n, with_props)
                lab_ = components(fr)
                fr = fr & (lab_ == lab_[sy, sx])
                cw, ch = int(bw / 4), int(bh * K / 4)          # footprint 폭 → 칸, 깊이 → 화면 칸(K 보정)
                ii = np.pad((~fr).cumsum(0).cumsum(1), ((1, 0), (1, 0)))
                best = None
                for y in range(fr.shape[0] - ch):
                    for x in range(fr.shape[1] - cw):
                        if ii[y + ch, x + cw] - ii[y, x + cw] - ii[y + ch, x] + ii[y, x] == 0:
                            best = (x * 4, round((y * 4 - OFFSET + TIER * 2) / K)); break
                    if best: break
                lines.append(f'- {bw}x{bh} footprint 빈 사각({"소품 포함" if with_props else "지형만"}): ' + (f'있음, 왼쪽위 footprint≈{best} → OK' if best else ('없음 → FAIL' if not with_props else '없음 (기둥·제단 엄폐물이 일부러 쪼갠다 — 정상)')))
                if not best and not with_props:
                    ok_all = False
                # 가장 큰 정사각(footprint) 도 함께 보고
                lines.append(f'  · 최대 정사각 한 변 ≈ {largest_square(fr)} footprint')
    out = '\n'.join(lines)
    (QA / 'reach_check.txt').write_text(out + '\n')
    print(out)
    return ok_all


def largest_square(fr):
    """자유 칸 마스크에서 footprint 단위(가로 4px·세로 4px/K) 기준 최대 정사각 변 길이 근사"""
    best = 0
    h, w = fr.shape
    dp = np.zeros((h + 1, w + 1), int)
    # 가로 cw 칸 × 세로 ch 칸이 같은 footprint 길이가 되도록 비율 보정: 한 변 s(footprint) → 가로 s/4 칸, 세로 s*K/4 칸
    ii = np.pad((~fr).cumsum(0).cumsum(1), ((1, 0), (1, 0)))
    for s in range(40, 400, 8):
        cw, ch = int(s / 4), max(1, int(s * K / 4))
        ok = False
        for y in range(0, h - ch, 2):
            for x in range(0, w - cw, 2):
                if ii[y + ch, x + cw] - ii[y, x + cw] - ii[y + ch, x] + ii[y, x] == 0:
                    ok = True; break
            if ok: break
        if ok: best = s
    return best


def width_report(name, y_png):
    """진단: png 행 y 에서 발판이 설 수 있는 구간(자유 칸) 목록"""
    free, W, H = free_grid(name)
    row = free[int(y_png / 4)]
    segs, s = [], None
    for i, v in enumerate(row):
        if v and s is None: s = i
        if not v and s is not None: segs.append((s * 4, (i - 1) * 4)); s = None
    if s is not None: segs.append((s * 4, (len(row) - 1) * 4))
    return segs


if __name__ == '__main__':
    args = [a for a in sys.argv[1:] if not a.startswith('--')]
    names = [a for a in args if a in M.MAPS] or list(M.MAPS)
    if '--check' in sys.argv:
        sys.exit(0 if check(names) else 1)
    build(names)
