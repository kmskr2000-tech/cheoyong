"""2장 M2 마커(footprint 좌표) — README 제안 좌표와 같은 값. (kind, label, fx, fy, color)"""
SP, NP, IT, PR, EN, RC = 'spawn', 'npc', 'int', 'prop', 'enemy', 'rect'
Y_, G_, C_, B_, O_, M_ = (255, 255, 60), (80, 255, 120), (80, 255, 255), (90, 160, 255), (255, 150, 40), (255, 60, 255)
MARKERS = {
    'old_village': [
        (SP, 'fromPath', 650, 345, Y_), (RC, 'exit_S', 650, 358, M_),
        (NP, 'girl_soul', 748, 160, G_), (IT, 'grave', 722, 335, C_), (IT, 'doll', 742, 40, C_),
        (EN, 'fire1', 510, 288, O_), (EN, 'fire2', 470, 200, O_), (EN, 'fire3', 565, 140, O_), (EN, 'oneeye', 330, 53, O_),
        (RC, 'trail_N', 752, 36, M_), (SP, 'nw_road', 300, 60, Y_),
    ],
    'den1': [
        (SP, 'start', 30, 181, Y_), (SP, 'fromDen2', 765, 200, Y_), (RC, 'exit_W', 5, 181, M_), (RC, 'exit_E', 786, 200, M_),
        (EN, 'oneeye_A', 190, 181, O_), (EN, 'oneeye_B1', 385, 38, O_), (EN, 'fire_B1', 480, 55, O_), (EN, 'oneeye_alcove', 360, 200, O_),
        (EN, 'fire_B2', 505, 205, O_), (EN, 'sangun', 690, 195, O_), (EN, 'jangseung', 735, 250, O_),
        (IT, 'altar', 772, 200, C_), (RC, 'sight', 190, 181, M_), (RC, 'deep', 740, 200, M_),
        (SP, 'north_link', 225, 90, Y_), (SP, 'east_hall', 500, 185, Y_), (SP, 'north_room', 420, 56, Y_), (SP, 'alcove', 350, 190, Y_),
    ],
    'den2': [
        (SP, 'start', 24, 200, Y_), (SP, 'fromDen3', 600, 200, Y_), (RC, 'exit_W', 5, 200, M_), (RC, 'exit_E', 634, 200, M_),
        (EN, 'jangsanbeom', 320, 200, O_), (EN, 'oneeye1', 215, 190, O_), (EN, 'oneeye2', 220, 285, O_), (EN, 'fire', 430, 200, O_),
        (SP, 'door_E', 452, 200, Y_),
    ],
    'den3': [
        (SP, 'start', 40, 200, Y_), (RC, 'exit_W', 5, 200, M_), (RC, 'gate', 90, 200, M_),
        (EN, 'dueoksini', 460, 200, O_), (IT, 'mortar_altar', 320, 200, C_),
        (SP, 'sm0', 450, 200, Y_), (SP, 'sm45', 412, 292, Y_), (SP, 'sm90', 320, 330, Y_), (SP, 'sm135', 228, 292, Y_),
        (SP, 'sm180', 190, 200, Y_), (SP, 'sm225', 228, 108, Y_), (SP, 'sm270', 320, 70, Y_), (SP, 'sm315', 412, 108, Y_),
    ],
}
def _fy(y_png):
    return round((y_png - 30) / 0.75)


def _P(kind, pts):
    return [(kind, x, _fy(y)) for x, y in pts]


# 소품 제안 배치(그림 y 로 적고 footprint 로 변환). 덩치 큰 초가는 걸을 수 없는 덤불 쪽에 둬 길을 막지 않는다.
PROPS = {
    'old_village': (_P('hut_ruin', [(268, 268), (70, 215)]) + _P('hut_ruin_b', [(40, 300)]) +
                    _P('old_tools_mortar', [(500, 200)]) + _P('old_tools_broom', [(625, 270)]) + _P('old_tools_pot', [(585, 232)]) +
                    _P('old_tools_sandals', [(690, 290)]) + _P('old_tools', [(448, 128)]) + [('doll', 742, 40)]),
    'den1': (_P('pillar', [(350, 52), (430, 52), (510, 52), (350, 84), (430, 84), (510, 84)]) +
             _P('dok_torch', [(24, 146), (205, 146), (330, 150), (480, 150), (330, 40), (520, 44), (620, 128), (740, 128)]) +
             _P('old_tools_mortar', [(80, 175), (700, 200)]) + _P('old_tools_pot', [(280, 186), (740, 180)]) + _P('old_tools_broom', [(390, 186), (460, 70)]) +
             _P('old_tools_sandals', [(520, 188), (395, 80)]) + _P('old_tools', [(230, 60), (600, 220)])),
    'den2': (_P('pillar', [(210, 135), (430, 135), (210, 225), (430, 225)]) +
             _P('dok_torch', [(222, 108), (418, 108), (222, 262), (418, 262), (120, 148), (520, 148)]) +
             _P('old_tools_mortar', [(180, 190)]) + _P('old_tools_pot', [(470, 175)]) + _P('old_tools_broom', [(260, 250)]) +
             _P('old_tools_sandals', [(380, 258)]) + _P('old_tools', [(260, 112), (380, 112)])),
    'den3': (_P('pillar', [(180, 127), (460, 127), (180, 232), (460, 232)]) + [('mortar_altar', 320, 200)] +
             _P('dok_torch', [(70, 78), (570, 78), (70, 292), (570, 292), (230, 72), (410, 72)]) +
             _P('old_tools_mortar', [(100, 255)]) + _P('old_tools_pot', [(540, 110), (560, 200)]) + _P('old_tools_broom', [(110, 100), (75, 200)]) +
             _P('old_tools_sandals', [(520, 270)]) + _P('old_tools', [(260, 285), (390, 285)])),
}
REACH = {'den2': ('start', ['exit_W', 'exit_E', 'fromDen3', 'jangsanbeom', 'oneeye1', 'oneeye2', 'fire', 'door_E']),
         'den3': ('start', ['exit_W', 'gate', 'dueoksini', 'mortar_altar', 'sm0', 'sm45', 'sm90', 'sm135', 'sm180', 'sm225', 'sm270', 'sm315']),
         'den1': ('start', ['exit_W', 'exit_E', 'fromDen2', 'oneeye_A', 'oneeye_B1', 'fire_B1', 'oneeye_alcove', 'fire_B2', 'sangun', 'jangseung', 'altar', 'sight', 'deep',
                            'north_link', 'east_hall', 'north_room', 'alcove']),
         'old_village': ('fromPath', ['exit_S', 'girl_soul', 'grave', 'doll', 'fire1', 'fire2', 'fire3', 'oneeye', 'trail_N', 'nw_road'])}
# 우회로(고리) 검사: (이름, [막을 footprint 사각형(x0,y0,x1,y1)], 시작 마커, 끝 마커)
LOOPS = {
    'old_village': [('마당 한가운데(우물 남쪽 열린 길)를 막아도 동쪽 샛길로 인형까지', [(440, 220, 640, 320)], 'fromPath', 'doll')],
}
LOOPS['den1'] = [('북쪽 방(우회 샛길)을 막아도 무너진 기둥벽 쪽 중앙 복도로 동쪽 안쪽까지', [(150, -40, 300, 140), (300, -40, 548, 60)], 'start', 'altar'),
                 ('중앙 복도를 막아도 북쪽 방으로 돌아 동쪽 안쪽까지', [(300, 140, 440, 230)], 'start', 'altar')]
LOOPS['den2'] = []
BOXES = {'den3': (300, 300)}      # 걸을 수 있는 면에 이 크기(footprint)의 빈 사각이 들어가는지 (소품 제외/포함 둘 다 보고)
STEALTH = {'old_village': ('fromPath', ['grave', 'doll', 'girl_soul'], ['fire1', 'fire2', 'fire3', 'oneeye'], 130)}
CHOKES = {}

# 실제 godot 걷기 검증(tests/godot/walkability.gd ROUTES)용 경유 지점 — NPC·소품 자리는 그 자체가 충돌이라 바로 옆 빈 칸으로 잡는다
ROUTES = {
    'old_village': [(650, 345), (722, 335), (736, 176), (728, 60), (752, 36)],
    'den1': [(30, 181), (190, 181), (225, 90), (420, 56), (500, 185), (772, 200)],
    'den2': [(24, 200), (215, 190), (320, 230), (430, 200), (452, 200)],
    'den3': [(40, 200), (320, 235), (320, 330), (460, 200)],
}
