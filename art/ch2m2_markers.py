"""2장 M2 마커(footprint 좌표) — README 제안 좌표와 같은 값. (kind, label, fx, fy, color)"""
SP, NP, IT, PR, EN, RC = 'spawn', 'npc', 'int', 'prop', 'enemy', 'rect'
Y_, G_, C_, B_, O_, M_ = (255, 255, 60), (80, 255, 120), (80, 255, 255), (90, 160, 255), (255, 150, 40), (255, 60, 255)
MARKERS = {
    'old_village': [
        (SP, 'fromPath', 690, 345, Y_), (RC, 'exit_S', 690, 358, M_),
        (NP, 'girl_soul', 290, 53, G_), (IT, 'grave', 540, 340, C_), (IT, 'doll', 742, 40, C_),
        (EN, 'fire1', 530, 296, O_), (EN, 'fire2', 520, 227, O_), (EN, 'fire3', 600, 138, O_), (EN, 'oneeye', 745, 160, O_),
        (RC, 'trail_N', 752, 36, M_),
    ],
    'den1': [
        (SP, 'start', 30, 181, Y_), (SP, 'fromDen2', 765, 200, Y_), (RC, 'exit_W', 5, 181, M_), (RC, 'exit_E', 786, 200, M_),
        (EN, 'oneeye_A', 190, 181, O_), (EN, 'oneeye_B1', 385, 38, O_), (EN, 'fire_B1', 480, 55, O_), (EN, 'oneeye_alcove', 360, 200, O_),
        (EN, 'fire_B2', 505, 205, O_), (EN, 'sangun', 690, 195, O_), (EN, 'jangseung', 735, 250, O_),
        (IT, 'altar', 772, 200, C_), (RC, 'sight', 190, 181, M_), (RC, 'deep', 740, 200, M_),
        (SP, 'north_link', 225, 90, Y_), (SP, 'east_hall', 500, 185, Y_), (SP, 'north_room', 420, 60, Y_), (SP, 'alcove', 350, 190, Y_),
    ],
    'den2': [
        (SP, 'start', 24, 200, Y_), (SP, 'fromDen3', 600, 200, Y_), (RC, 'exit_W', 5, 200, M_), (RC, 'exit_E', 634, 200, M_),
        (EN, 'jangsanbeom', 320, 200, O_), (EN, 'oneeye1', 215, 190, O_), (EN, 'oneeye2', 215, 290, O_), (EN, 'fire', 430, 200, O_),
        (SP, 'door_E', 452, 200, Y_),
    ],
    'den3': [
        (SP, 'start', 40, 200, Y_), (RC, 'exit_W', 5, 200, M_), (RC, 'gate', 90, 200, M_),
        (EN, 'dueoksini', 460, 200, O_), (IT, 'mortar_altar', 320, 200, C_),
        (SP, 'sm0', 450, 200, Y_), (SP, 'sm45', 412, 292, Y_), (SP, 'sm90', 320, 330, Y_), (SP, 'sm135', 228, 292, Y_),
        (SP, 'sm180', 190, 200, Y_), (SP, 'sm225', 228, 108, Y_), (SP, 'sm270', 320, 70, Y_), (SP, 'sm315', 412, 108, Y_),
    ],
}
PROPS = {'old_village': [],
         'den2': [('pillar', 210, 140), ('pillar', 430, 140), ('pillar', 210, 260), ('pillar', 430, 260)],
         'den3': [('pillar', 180, 130), ('pillar', 460, 130), ('pillar', 180, 270), ('pillar', 460, 270), ('mortar_altar', 320, 200)],
         'den1': [('pillar', 350, 25), ('pillar', 430, 25), ('pillar', 510, 25), ('pillar', 350, 60), ('pillar', 430, 60), ('pillar', 510, 60)]}
REACH = {'den2': ('start', ['exit_W', 'exit_E', 'fromDen3', 'jangsanbeom', 'oneeye1', 'oneeye2', 'fire', 'door_E']),
         'den3': ('start', ['exit_W', 'gate', 'dueoksini', 'mortar_altar', 'sm0', 'sm45', 'sm90', 'sm135', 'sm180', 'sm225', 'sm270', 'sm315']),
         'den1': ('start', ['exit_W', 'exit_E', 'fromDen2', 'oneeye_A', 'oneeye_B1', 'fire_B1', 'oneeye_alcove', 'fire_B2', 'sangun', 'jangseung', 'altar', 'sight', 'deep',
                            'north_link', 'east_hall', 'north_room', 'alcove']),
         'old_village': ('fromPath', ['exit_S', 'girl_soul', 'grave', 'doll', 'fire1', 'fire2', 'fire3', 'oneeye', 'trail_N'])}
# 우회로(고리) 검사: (이름, [막을 footprint 사각형(x0,y0,x1,y1)], 시작 마커, 끝 마커)
LOOPS = {
    'old_village': [('마당 한가운데(우물 남쪽 열린 길)를 막아도 동쪽 샛길로 인형까지', [(440, 220, 640, 320)], 'fromPath', 'doll')],
}
LOOPS['den1'] = [('북쪽 방(우회 샛길)을 막아도 무너진 기둥벽 쪽 중앙 복도로 동쪽 안쪽까지', [(150, -40, 300, 140), (300, -40, 548, 60)], 'start', 'altar'),
                 ('중앙 복도를 막아도 북쪽 방으로 돌아 동쪽 안쪽까지', [(300, 140, 440, 230)], 'start', 'altar')]
LOOPS['den2'] = []
BOXES = {'den3': (300, 300)}      # 걸을 수 있는 면에 이 크기(footprint)의 빈 사각이 들어가는지 (소품 제외/포함 둘 다 보고)
CHOKES = {}
