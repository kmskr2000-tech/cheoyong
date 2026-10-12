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

# ------------------------------------------------------------------ 마커 (footprint) — 제안값
MARKERS = {'hwagae': [], 'jiri': []}


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


if __name__ == '__main__':
    names = [a for a in sys.argv[1:] if not a.startswith('--')] or ['hwagae', 'jiri']
    names = [n for n in names if n in ca.MAPS]
    QA.mkdir(parents=True, exist_ok=True)
    build(names)
