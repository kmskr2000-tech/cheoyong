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
}
PROPS = {'old_village': []}
REACH = {'old_village': ('fromPath', ['exit_S', 'girl_soul', 'grave', 'doll', 'fire1', 'fire2', 'fire3', 'oneeye', 'trail_N'])}
# 우회로(고리) 검사: (이름, [막을 footprint 사각형(x0,y0,x1,y1)], 시작 마커, 끝 마커)
LOOPS = {
    'old_village': [('마당 한가운데(우물 남쪽 열린 길)를 막아도 동쪽 샛길로 인형까지', [(440, 220, 640, 320)], 'fromPath', 'doll')],
}
CHOKES = {}
