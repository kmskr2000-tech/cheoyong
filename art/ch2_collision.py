"""2장 M1 지형(hwagae·jiri)의 충돌·높이 json + 검증 오버레이.
collision_author.build()를 그대로 쓰되, 1장 맵을 건드리지 않도록 이 파일의 MAPS 만 굽는다.
좌표는 collision_author 와 같다: 그림 좌표(png px). 화면 y = 그림 y - 82, fy = (그림 y - 30) / 0.75, fx = 그림 x.
(그림 맨 아래 26px 는 tier 여백이라 레벨 가장자리 벽 밖 = 걷기 불가)
사용: python3 art/ch2_collision.py [hwagae|jiri ...]   → json 갱신 + production/qa/asset-import/ch2-m1/overlay_<id>.png
      python3 art/ch2_collision.py --check   → 도달성(BFS) 검증
마커(MARKERS)는 설계서 §4.1~4.2 좌표를 이 그림에 맞게 조정한 '제안'이다(footprint 좌표). README 와 같은 값.
"""
import pathlib, sys, json, types
import numpy as np
from PIL import Image, ImageDraw

HERE = pathlib.Path(__file__).parent
sys.path.insert(0, str(HERE))
import collision_author as ca

ROOT = HERE.parent
QA = ROOT / 'production/qa/asset-import/ch2-m1'
ca.OUTQA = QA
rect, mp = ca.rect, ca.mp

# ------------------------------------------------------------------ 맵 정의 (그림 좌표)
mp('hwagae', ground='hwagae',
   walk=[
       # 광장(우물 오른쪽 아래~중앙) — 남서 입구 포함
       [(200, 300), (200, 252), (272, 248), (384, 246), (394, 236), (395, 215), (470, 230), (466, 252), (448, 270), (424, 286), (390, 300)],
       # 우물 위쪽 사랑채 마당(주막 앞)
       [(150, 224), (268, 226), (272, 250), (150, 254)],
       # 동쪽 산길: 광장 북동쪽 → 동문(그림 y≈30 이 footprint 0줄)
       [(395, 215), (397, 168), (455, 152), (500, 140), (524, 128), (526, 100), (545, 92), (585, 78), (602, 66), (640, 60),
        (664, 48), (676, 32), (694, 30), (722, 30), (722, 36), (700, 58), (692, 78), (676, 100), (650, 112), (626, 126),
        (596, 142), (560, 160), (525, 182), (490, 212), (470, 230)],
   ],
   block=[
       rect(206, 262, 264, 298),                                 # 우물 돌 테두리
       rect(348, 282, 364, 300),                                 # 등롱 기둥 밑동
       rect(498, 200, 510, 214), rect(606, 126, 618, 138), rect(678, 88, 690, 100),
   ])

# 지리산 산길: 산신각 마당(서) → 금줄 아래 돌길 → 거송 아래 좁은 길목(x540~620) → 돌탑 바위 지대 → 어두운 숲(동)
mp('jiri', ground='jiri',
   walk=[
       rect(0, 166, 125, 208),                                   # 서쪽 입구 돌길(그림을 왼쪽 끝까지 이어 붙임)
       # 산신각 마당 + 금줄 아래 돌길 + 금줄 남쪽 풀밭
       [(112, 212), (112, 150), (122, 118), (152, 100), (190, 98), (196, 66), (230, 66), (234, 98), (300, 96), (332, 92),
        (340, 130), (380, 158), (440, 165), (500, 168), (540, 170), (545, 213), (500, 246), (440, 262), (380, 258),
        (330, 246), (260, 232), (180, 226)],
       # 길목(540~620): 북 거송 뿌리·남 양치 덤불 사이 폭≈45px(=footprint 60)
       rect(538, 170, 625, 214),
       # 돌탑 바위 지대: 길목 동쪽 + 북쪽 산길(북 출구) + 돌탑 북·동쪽 우회로
       [(620, 168), (630, 130), (612, 92), (598, 50), (622, 32), (694, 32), (706, 62), (716, 100), (750, 118), (776, 122),
        (776, 250), (740, 262), (700, 268), (640, 266), (624, 214)],
       # [prog/ch2-assets 보강] 게임 충돌(발판 11x7·4px 격자)에서는 위 길목→북쪽 산길 연결(폭≈12px)과 돌탑 북쪽→동쪽 연결(높이≈6px)이
       # 너무 좁아 서↔동이 끊겼다. 그림의 흙길·이끼 땅은 실제로 더 넓다 → 그림에 맞춰 넓힌다(폭 약 26~32px).
       [(604, 178), (628, 178), (636, 128), (660, 90), (690, 62), (708, 40), (692, 32), (650, 50), (618, 90), (604, 130)],
       [(660, 86), (700, 72), (760, 92), (780, 110), (776, 127), (700, 127), (660, 110)],
       # 동쪽 어두운 숲 마당 → 소굴 쪽 동쪽 출구
       [(770, 110), (800, 84), (860, 66), (1000, 56), (1120, 60), (1120, 114), (1085, 120), (1040, 152), (1010, 182),
        (990, 218), (960, 246), (900, 266), (885, 262), (880, 150), (800, 130), (775, 134)],
   ],
   block=[
       rect(218, 76, 298, 144),                                  # 제상(돌 탁자)
       [(156, 4), (156, 62), (262, 62), (262, 4)],                # 산신각 본채(계단 위)
       rect(640, 128, 748, 258),                                 # 돌탑 기단
   ])

# ------------------------------------------------------------------ 마커 (footprint) — 제안값 (README 와 동일)
# (kind, label, fx, fy, color) ; kind: spawn npc int prop enemy rect(출입구·트리거 중심) light
SP, NP, IT, PR, EN, RC = 'spawn', 'npc', 'int', 'prop', 'enemy', 'rect'
Y_, G_, C_, B_, O_, M_ = (255, 255, 60), (80, 255, 120), (80, 255, 255), (90, 160, 255), (255, 150, 40), (255, 60, 255)
MARKERS = {
    'hwagae': [
        (SP, 'start', 300, 340, Y_), (SP, 'fromPath', 706, 14, Y_), (SP, 'fromBoss', 360, 320, Y_),
        (RC, 'gate_E', 706, 9, M_), (RC, 'exit_SW(3장)', 270, 354, M_), (RC, 'raid', 365, 325, M_),
        (NP, 'sangin', 330, 330, G_), (NP, 'jumo', 190, 262, G_), (NP, 'victim', 290, 335, G_), (NP, 'elder', 580, 120, G_),
        (NP, 'dok_jangsu', 420, 300, G_), (NP, 'sansin', 680, 45, G_),
        (IT, 'board', 430, 230, C_), (IT, 'juma', 200, 262, C_), (IT, 'dok_shop', 400, 300, C_),
        (PR, 'stall', 300, 296, B_), (PR, 'stall', 345, 296, B_), (PR, 'stall', 390, 290, B_), (PR, 'stall', 500, 190, B_),
        (PR, 'tent', 270, 352, B_), (PR, 'tent', 420, 347, B_), (PR, 'burnt', 320, 318, B_), (PR, 'burnt', 395, 318, B_),
    ],
    'jiri': [
        (SP, 'fromHwagae', 24, 205, Y_), (SP, 'fromVillage', 655, 6, Y_), (SP, 'fromDen', 1090, 80, Y_),
        (RC, 'exit_W', 3, 205, M_), (RC, 'exit_N', 657, 10, M_), (RC, 'exit_E', 1117, 77, M_),
        (NP, 'sansin', 250, 175, G_), (IT, 'shrine', 258, 158, C_),
        (EN, 'sangun1', 355, 165, O_), (EN, 'fire1', 580, 215, O_), (EN, 'jangseung_taki', 665, 95, O_),
        (EN, 'sangun2', 765, 260, O_), (EN, 'sangun3', 940, 100, O_), (EN, 'fire2', 960, 260, O_),
        (PR, 'rockwallN', 556, 152, B_), (PR, 'rockwallN', 604, 152, B_), (PR, 'rockwallS', 556, 310, B_), (PR, 'rockwallS', 604, 310, B_),
        (PR, 'cairn', 430, 240, B_),
    ],
}
# 도달성 검사 대상: (맵, 시작 마커, [도달해야 할 마커...])
REACH = {
    'hwagae': ('start', ['fromPath', 'fromBoss', 'gate_E', 'exit_SW(3장)', 'raid', 'sangin', 'jumo', 'victim', 'elder', 'dok_jangsu',
                         'sansin', 'board', 'juma', 'dok_shop']),
    'jiri': ('fromHwagae', ['fromVillage', 'fromDen', 'exit_W', 'exit_N', 'exit_E', 'sansin', 'shrine', 'sangun1', 'sangun2', 'sangun3', 'fire1', 'fire2',
                            'jangseung_taki']),
}
NOT_WALK = {'jiri': {'rockwallN', 'rockwallS', 'cairn'}, 'hwagae': {'stall', 'tent', 'burnt'}}


def _markers(name):
    out = []
    for kind, label, fx, fy, col in MARKERS.get(name, []):
        out.append((kind, label, fx, ca.K * fy + ca.OFFSET - ca.TIER * ca.T, col))
    return out


def build(names):
    lm = types.ModuleType('level_markers')
    lm.markers = _markers
    sys.modules['level_markers'] = lm
    for n in names:
        ca.build(n)


def check(names):
    """collision json(실제 충돌) 을 플레이어 발판 10x6 으로 부풀려 연결 성분을 구하고, 마커가 한 덩어리에 들어가는지 본다."""
    from scipy import ndimage as ndi
    lines = []
    for n in names:
        meta = json.load(open(ca.LV / f'{n}.json'))
        W = meta['size'][0]
        Hh = meta['size'][1] + ca.OFFSET
        blocked = np.zeros((Hh, W), bool)
        for x, y, w, h in meta['collision']:
            blocked[max(0, y + ca.OFFSET):y + ca.OFFSET + h, max(0, x):x + w] = True
        blocked[Hh - 26:, :] = True                               # 레벨 가장자리 벽(그림 맨 아래 tier 여백)
        blocked[:, :1] = False
        def free_of(b):
            return ~ndi.binary_dilation(b, structure=np.ones((6, 10), bool), origin=0)
        free = free_of(blocked)
        lab, _ = ndi.label(free)
        def pt(m):
            return int(round(m[2])), int(round(ca.K * m[3] + ca.OFFSET - ca.TIER * ca.T))
        ms = {m[1]: m for m in MARKERS[n]}
        start, targets = REACH[n]
        sx, sy = pt(ms[start]); sl = lab[sy, sx]
        lines.append(f'## {n}  (start {start} px=({sx},{sy}) label={sl})')
        for t in targets:
            x, y = pt(ms[t]); ok = sl != 0 and lab[min(y, Hh - 1), min(x, W - 1)] == sl
            lines.append(f'- {t:14s} fp=({ms[t][2]},{ms[t][3]}) px=({x},{y}) 도달 {"OK" if ok else "FAIL"}')
        for m in MARKERS[n]:
            if m[1] in NOT_WALK[n] or m[0] in (PR,):
                continue
        if n == 'jiri':                                           # 길목 봉쇄 시험: x540~620 를 막으면 동서가 끊겨야 한다
            b2 = blocked.copy(); b2[:, 540:621] = True
            lab2, _ = ndi.label(free_of(b2))
            a = lab2[sy, sx]; x, y = pt(ms['fromDen']); b = lab2[y, x]
            lines.append(f'- 길목(x540~620) 봉쇄 시 서↔동 {"끊김(OK)" if a != b else "이어짐(FAIL)"}')
            # 길목 폭: x=580 열에서 열린 구간 길이(px→footprint)
            col = free_of(blocked)[:, 580]
            ys_ = np.where(~blocked[:, 580])[0]
            seg = [(g[0], g[-1]) for g in np.split(ys_, np.where(np.diff(ys_) > 1)[0] + 1) if len(g)]
            lines.append(f'- x=580 열린 구간(px): {seg}  → footprint 폭 ≈ {[round((e - s0 + 1) / ca.K) for s0, e in seg]}')
    out = '\n'.join(lines)
    (QA / 'reach_check.txt').write_text(out + '\n')
    print(out)
    return 'FAIL' not in out


if __name__ == '__main__':
    if '--check' in sys.argv:
        sys.exit(0 if check([a for a in sys.argv[1:] if a in ca.MAPS] or ['hwagae', 'jiri']) else 1)
    names = [a for a in sys.argv[1:] if not a.startswith('--')] or ['hwagae', 'jiri']
    names = [n for n in names if n in ca.MAPS]
    QA.mkdir(parents=True, exist_ok=True)
    build(names)
