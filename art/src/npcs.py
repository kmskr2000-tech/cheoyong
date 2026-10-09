# Village NPCs, derived from 처용's front frame so they share his proportions and shading:
# the shawl, ribbon and flute are stripped, then hair / beard / clothing are swapped per character.
# Front idle only (NPCs stand and breathe; Godot adds the bob). 32x48 cells, feet on row 44.
from cheoyong import DOWN

BASE = {
    'o': '#0d0a12', 'k': '#08060c',
    '1': '#4a2a2e', '2': '#8a5a52', '3': '#c08a72', '4': '#e6b896',
    'w': '#d8d2c0', 'W': '#8e8a96', 'B': '#2a2234', 'b': '#120e16',
}


def strip(rows):
    """Remove the flute, shawl and trailing ribbon; the shawl area becomes plain coat."""
    out = []
    for y, r in enumerate(rows):
        s = ''
        for x, c in enumerate(r):
            if c in 'Pp':
                c = '.' if y < 16 else 'f'
            elif c == 'o' and 10 <= y <= 15 and x <= 9:
                c = '.'
            elif c in 'uUtT':
                c = {'u': 'f', 'U': 'g', 't': 'e', 'T': 'e'}[c]
            elif c in 'QqRr' and y <= 8:
                c = '.' if x >= 19 else 'i'
            elif c == 'o' and y <= 8 and x >= 20:
                c = '.'
            s += c
        out.append(s)
    return out


def put(rows, y, x, text):
    r = rows[y]
    rows[y] = r[:x] + text + r[x + len(text):]


def pal(**over):
    p = dict(BASE)
    p.update(over)
    return p


PLAIN = strip(DOWN)

# 촌주 박노인: grey topknot, long white beard, faded brown 도포
ELDER = list(PLAIN)
for y, x, t in ((12, 12, 'wwwwww'), (13, 12, 'wwwWww'), (14, 13, 'wwWw'), (15, 13, 'wWww'), (16, 14, 'ww')):
    put(ELDER, y, x, t)
ELDER_P = pal(h='#5a5a62', i='#7a7a84', j='#9a9aa4', J='#c0c0c8',
              d='#1c1712', e='#2c241c', f='#3e342a', g='#54483a', G='#6e604e',
              r='#2a221a', R='#3e3428', q='#5a4a36', Q='#7a6648', y='#3a3020', Y='#6a5a3a', Z='#9a8858')

# 난영: long black hair, deep plum chima, pale jade jeogori trim, gold hairpin
NANYEONG = list(PLAIN)
for y in range(8, 24):  # hair falling past the shoulders on both sides
    r = NANYEONG[y]
    for x in (10, 11, 20, 21):
        if r[x] in 'o.fgedG' and y > 9:
            put(NANYEONG, y, x, 'h' if x in (11, 20) else 'o')
put(NANYEONG, 4, 18, 'ZZo')
NANYEONG_P = pal(h='#0e0c16', i='#1e1a2c', j='#34304c', J='#5a5a82',
                 d='#1e0c1a', e='#341428', f='#4e1e3a', g='#6c2a50', G='#8e3c6a',
                 r='#2a3a34', R='#3e5a4e', q='#6a9a84', Q='#9ac8b0', y='#6a4a1c', Y='#b88a32', Z='#f0cc6a')

# 석구 (약방): bald-ish with a headband, short beard, ochre work clothes
SEOKGU = list(PLAIN)
for y, x, t in ((13, 13, 'hhhh'), (14, 13, 'hhh'),):
    put(SEOKGU, y, x, t)
SEOKGU_P = pal(h='#2a1c16', i='#3a2a20', j='#7a5a3a', J='#a88050',
               d='#2a1c10', e='#3e2a18', f='#5a4024', g='#7a5a34', G='#9a7848',
               r='#2a1a10', R='#4a3018', q='#6a4a2a', Q='#8a6a40', y='#3a2a18', Y='#6a5030', Z='#9a7a48')

# 마을 아낙: kerchief, muted indigo
VILLAGER_F = list(PLAIN)
VILLAGER_F_P = pal(h='#6e6a62', i='#5a5650', j='#86807a', J='#9e988c',
                   d='#121626', e='#1c2238', f='#283050', g='#38426a', G='#4a5682',
                   r='#3a2a2a', R='#5a3e38', q='#7a5a4a', Q='#9a7a62', y='#3a3020', Y='#6a5a3a', Z='#9a8858')

# 나무꾼 돌쇠: rough hemp clothes, sun-dark skin
DOLSOE = list(PLAIN)
DOLSOE_P = pal(**{'2': '#7a4a40', '3': '#a8705a', '4': '#c89478'}, h='#14100e', i='#241c18', j='#3a2e26', J='#54443a',
               d='#1c1a14', e='#2a2820', f='#3e3a2e', g='#565040', G='#706852',
               r='#2a2018', R='#3e3024', q='#5a4834', Q='#7a6448', y='#2a2018', Y='#4a3a28', Z='#6a5a40')

# 기침하는 사내: sickly green-grey skin, threadbare clothes
SICK = list(PLAIN)
SICK_P = pal(**{'1': '#3a4436', '2': '#6a7a5e', '3': '#93a080', '4': '#b4c09e'}, h='#121410', i='#20241c', j='#343a2c', J='#4a5240',
             d='#181a16', e='#24261f', f='#34372c', g='#484c3c', G='#5e6450',
             r='#1e2018', R='#2e3224', q='#464c36', Q='#5e664a', y='#2a2a1e', Y='#4a4a34', Z='#6a6a4c')

# 보리 (아이 원혼): a small child, pale and blue — the head on a shortened body
GHOST = ['.' * 32] * 9 + PLAIN[0:30] + PLAIN[39:48]
GHOST = GHOST[:48]
GHOST_P = pal(**{'1': '#4a5a7a', '2': '#7a8ab0', '3': '#a8b8d8', '4': '#d0dcf0'},
              h='#2a3048', i='#3a4462', j='#56628a', J='#7a88b0', o='#141a2c',
              d='#3a4466', e='#4e5a82', f='#6a78a0', g='#8a98c0', G='#aab6d8',
              r='#3a4466', R='#4e5a82', q='#6a78a0', Q='#8a98c0', y='#4e5a82', Y='#6a78a0', Z='#aab6d8',
              w='#e0e8f8', W='#a0aac8', B='#3a4466', b='#2a3048')

# 개운포 수령 한기: 사모(紗帽) with side wings, deep green 관복 with a gold 흉배 and belt, trim beard
SURYEONG = list(PLAIN)
for y, x, t in ((1, 13, 'ooooo'), (2, 13, 'ojJjio'), (3, 13, 'ojiihho'), (5, 7, 'oJJjj'), (5, 20, 'iihho'), (6, 7, 'ooooo'), (6, 21, 'oooo')):
    put(SURYEONG, y, x, t)
for y, x, t in ((13, 14, 'hhh'), (14, 14, 'hh')):
    put(SURYEONG, y, x, t)
for y, x, t in ((20, 14, 'ZYZ'), (21, 14, 'YZY')):
    put(SURYEONG, y, x, t)
SURYEONG_P = pal(h='#07070c', i='#101018', j='#1e1e2a', J='#34344a',
                 d='#0a1612', e='#10241c', f='#18382a', g='#225038', G='#2e6a4a',
                 r='#2a2010', R='#4a3a18', q='#8a6a28', Q='#c9a24a', y='#6a4a1c', Y='#b88a32', Z='#f0cc6a')

# 관아 사람 / 관리: indigo 단령, black hat
OFFICIAL = list(SURYEONG)
OFFICIAL_P = pal(h='#07070c', i='#101018', j='#1e1e2a', J='#34344a',
                 d='#0a0c1e', e='#121834', f='#1c2650', g='#28366c', G='#36488a',
                 r='#1a1a26', R='#2a2a3a', q='#44445a', Q='#5e5e78', y='#2a2a3a', Y='#44445a', Z='#6a6a84')

# 어부: salt-faded indigo, straw headband, sun-dark skin
FISHER = list(PLAIN)
FISHER_P = pal(**{'2': '#6e4438', '3': '#9a6852', '4': '#bc8a70'}, h='#3a3018', i='#5a4a26', j='#7a6838', J='#9a8650',
               d='#10141c', e='#18202c', f='#22303e', g='#2e4052', G='#3e5468',
               r='#2a2018', R='#3e3024', q='#5a4834', Q='#7a6448', y='#2a2018', Y='#4a3a28', Z='#6a5a40')


# 역병 걸린 아이: the child's short body, sallow fevered skin, faded undyed hemp
CHILD = list(GHOST)
CHILD_P = pal(**{'1': '#4a3a34', '2': '#7e6658', '3': '#a88e7a', '4': '#c4ac94'}, h='#100c10', i='#1e1820', j='#342c34', J='#4a4048',
              d='#1e1c1a', e='#2c2a26', f='#3e3a34', g='#524c44', G='#686058',
              r='#2a2420', R='#3e3630', q='#5a5046', Q='#7a6e60', y='#3a3020', Y='#6a5a3a', Z='#9a8858')

# 왕: 익선관 (wings standing up behind), deep red 곤룡포 with a gold dragon roundel, jade belt
KING = list(PLAIN)
for y, x, t in ((1, 13, 'ooooo'), (2, 13, 'ojJjio'), (3, 13, 'ojiihho'), (0, 11, 'oo'), (1, 10, 'ojo'), (0, 20, 'oo'), (1, 20, 'ojo'), (2, 10, 'oo'), (2, 21, 'oo')):
    put(KING, y, x, t)
for y, x, t in ((13, 14, 'hhh'),):
    put(KING, y, x, t)
for y, x, t in ((18, 14, 'YZZY'), (19, 13, 'YZYYZY'), (20, 14, 'YZZY')):
    put(KING, y, x, t)
KING_P = pal(h='#07070c', i='#101018', j='#1e1e2a', J='#34344a',
             d='#2a060a', e='#4a0e14', f='#6a161c', g='#8e2026', G='#b0302e',
             r='#1a3a30', R='#2a5a4a', q='#4a8a72', Q='#7ab89a', y='#6a4a1c', Y='#b88a32', Z='#f0cc6a')

# 용왕: the elder's long white beard, a gold crown tipped with coral, sea-green robe gone grey with sickness
DRAGONKING = list(ELDER)
for y, x, t in ((0, 13, 'Z.Z.Z'), (1, 12, 'ZYZYZYZ'), (2, 12, 'YZZZZZY')):
    put(DRAGONKING, y, x, t)
DRAGONKING_P = pal(h='#8a8a90', i='#a8a8b0', j='#c8c8d0', J='#e8e8f0',
                   d='#0a1a18', e='#12302a', f='#1c463c', g='#2a5e50', G='#3e7a68',
                   r='#3a0e14', R='#6a1a22', q='#a83a3a', Q='#d86a5a', y='#6a4a1c', Y='#b88a32', Z='#f0cc6a',
                   **{'1': '#3a3a40', '2': '#6a6670', '3': '#948e98', '4': '#b4aeb6'})

# 맏형: stern, steel-dark robe, hair bound high
BROTHER1 = list(PLAIN)
BROTHER1_P = pal(h='#06060a', i='#101018', j='#1c1c2a', J='#2e2e44',
                 d='#0a0e16', e='#141c2a', f='#1e2a3e', g='#2a3a54', G='#3a4e6e',
                 r='#2a2a3a', R='#40405a', q='#5e5e80', Q='#8080a8', y='#3a3020', Y='#6a5a3a', Z='#9a8858')
# 둘째: deep teal robe
BROTHER2 = list(PLAIN)
BROTHER2_P = pal(h='#08080c', i='#12121a', j='#20202e', J='#323246',
                 d='#061614', e='#0c2622', f='#123a34', g='#1a5048', G='#246a5e',
                 r='#1a2a28', R='#2a423e', q='#3e625a', Q='#5a8a7e', y='#3a3020', Y='#6a5a3a', Z='#9a8858')

# 산신령: 산의 주인. 긴 흰 수염과 흰 눈썹, 바랜 흰 도포, 옹이진 지팡이 끝에 호리병.
SANSIN = list(ELDER)
for y, x, t in ((9, 12, 'J'), (9, 19, 'J'), (17, 14, 'ww'), (18, 15, 'w')):
    put(SANSIN, y, x, t)
for y in range(4, 45):
    put(SANSIN, y, 25, 'y' if y > 8 else ('Y' if y > 5 else 'Q'))
for y, x, t in ((2, 25, 'Z'), (3, 24, 'ZJZ'), (4, 24, 'YZY'), (5, 25, 'Y')):
    put(SANSIN, y, x, t)
SANSIN_P = pal(h='#8a8a96', i='#b4b4be', j='#d8d8e0', J='#f2f2f6',
               d='#3a3e4a', e='#5a5e6c', f='#7e8292', g='#a4a8b6', G='#c8ccd6',
               r='#3a5a2a', R='#5a8a3a', q='#8ab85a', Q='#b8e080', y='#3a2414', Y='#6a4422', Z='#9a6a3a')

# One sheet per character (each has its own palette).
SHEETS = {
    'npc_elder': (ELDER_P, {'idle': ELDER}),
    'npc_nanyeong': (NANYEONG_P, {'idle': NANYEONG}),
    'npc_seokgu': (SEOKGU_P, {'idle': SEOKGU}),
    'npc_villager_f': (VILLAGER_F_P, {'idle': VILLAGER_F}),
    'npc_dolsoe': (DOLSOE_P, {'idle': DOLSOE}),
    'npc_sick': (SICK_P, {'idle': SICK}),
    'npc_ghost': (GHOST_P, {'idle': GHOST}),
    'npc_suryeong': (SURYEONG_P, {'idle': SURYEONG}),
    'npc_official': (OFFICIAL_P, {'idle': OFFICIAL}),
    'npc_fisher': (FISHER_P, {'idle': FISHER}),
    'npc_child': (CHILD_P, {'idle': CHILD}),
    'npc_king': (KING_P, {'idle': KING}),
    'npc_sansin': (SANSIN_P, {'idle': SANSIN}),
    'npc_dragonking': (DRAGONKING_P, {'idle': DRAGONKING}),
    'npc_brother1': (BROTHER1_P, {'idle': BROTHER1}),
    'npc_brother2': (BROTHER2_P, {'idle': BROTHER2}),
}
