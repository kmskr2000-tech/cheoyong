"""마을 사람들 — 처용과 같은 3D 인형 렌더러(art/hero.py)로 NPC 16명을 같은 화풍으로 뽑는다.

Each person is a spec: a few mid colours (turned into muted 6-tone ramps with cool shadows and warm
lights), a hat, hair, beard, 치마, rank badge, staff, body scale. Sheets keep the frame layout
npc.gd and intro.gd read: 0 front, 1-2 3/4 right + breath, 3-4 3/4 left + breath. 32x48, feet on 44.
Usage: python3 art/people.py [--preview N]
"""
import colorsys, pathlib, sys
import numpy as np
from PIL import Image
import hero

ROOT = pathlib.Path(__file__).parent


def ramp(mid, sat=0.78):
    """One mid colour → 6 tones, dark to light: shadows lean cool, lights lean warm, all muted."""
    r, g, b = (int(mid[i:i + 2], 16) / 255 for i in (1, 3, 5))
    h, l, s = colorsys.rgb_to_hls(r, g, b)
    out = []
    for k, (dl, dh) in enumerate(((-0.62, 0.035), (-0.42, 0.02), (-0.2, 0.01), (0.0, 0.0), (0.18, -0.012), (0.34, -0.024))):
        ll = max(0.03, min(0.92, l * (1 + dl) if dl < 0 else l + (1 - l) * dl * 0.7))
        hh = (h + dh) % 1.0                      # darker → toward blue-violet, lighter → toward yellow
        ss = s * sat * (0.85 if k in (0, 5) else 1.0)
        out.append([v * 255 for v in colorsys.hls_to_rgb(hh, ll, ss)])
    return np.array(out, np.float32)


def P(**cols):
    return {k: ramp(v) for k, v in cols.items()}


GREY_HAIR = '#8a8a90'
WHITE_HAIR = '#b8b8bc'
SKIN = '#b48a6e'
DARK_SKIN = '#9a6c52'

PEOPLE = {
    # 촌주 박노인: grey topknot, long white beard, faded brown 도포
    'npc_elder': {'beard': 'long', 'ramps': P(robe='#5a4c3c', red='#4a3e30', hair=GREY_HAIR, skin=SKIN, cuff='#3a3028')},
    # 난영: 쪽진 머리, deep plum 치마, pale jade 저고리, gold 비녀
    'npc_nanyeong': {'chima': True, 'long_hair': True, 'ramps': P(robe='#6a3450', top='#7e9a8c', red='#8a3a3a', skin='#c09a7e', cuff='#7e9a8c')},
    # 석구 (약방): headband, short beard, ochre work clothes
    'npc_seokgu': {'hat': 'headband', 'beard': 'short', 'ramps': P(robe='#7a5e3a', red='#4a3a26', hat='#c8b48a', skin=SKIN, cuff='#4a3a26')},
    # 마을 아낙: kerchief, muted indigo 치마
    'npc_villager_f': {'chima': True, 'hat': 'kerchief', 'ramps': P(robe='#3e4a68', top='#8a8478', hat='#9a948a', red='#5a4a46', skin=SKIN, cuff='#8a8478')},
    # 나무꾼 돌쇠: rough hemp, sun-dark skin
    'npc_dolsoe': {'ramps': P(robe='#6a6450', red='#4a4232', skin=DARK_SKIN, cuff='#4a4232')},
    # 기침하는 사내: sickly green-grey skin, threadbare clothes
    'npc_sick': {'ramps': P(robe='#545a48', red='#3e4236', skin='#8e9a7a', cuff='#3e4236')},
    # 보리 (아이 원혼): a small child, pale and blue
    'npc_ghost': {'scale': 0.72, 'ramps': P(robe='#8a9ac0', red='#6a7aa0', skin='#b4c0dc', hair='#4a5478', cuff='#6a7aa0', boot='#5a6488')},
    # 개운포 수령 한기: 사모, deep green 관복, gold 흉배, trim beard
    'npc_suryeong': {'hat': 'samo', 'beard': 'short', 'badge': 'gold', 'ramps': P(robe='#2e5a46', red='#3a3020', skin=SKIN, cuff='#1e3a2e')},
    # 관아 사람 / 관리: indigo 단령, black 사모
    'npc_official': {'hat': 'samo', 'badge': 'collar', 'ramps': P(robe='#2e3a6a', red='#2a2a3a', skin=SKIN, cuff='#1e2648')},
    # 어부: salt-faded indigo, straw headband, sun-dark skin
    'npc_fisher': {'hat': 'headband', 'ramps': P(robe='#3a5068', red='#4a3e30', hat='#b8a070', skin=DARK_SKIN, cuff='#2a3a4c')},
    # 역병 걸린 아이: the child's short body, sallow fevered skin, undyed hemp
    'npc_child': {'scale': 0.72, 'ramps': P(robe='#7a7464', red='#5a5446', skin='#b0967a', cuff='#5a5446')},
    # 왕: 익선관, deep red 곤룡포, gold roundel, jade belt
    'npc_king': {'hat': 'ikseon', 'badge': 'gold', 'ramps': P(robe='#8a2e2e', red='#4a7a66', skin=SKIN, cuff='#6a2020')},
    # 산신령: long white beard, faded white 도포, staff with a gourd
    'npc_sansin': {'beard': 'long', 'staff': True, 'ramps': P(robe='#b4b4b0', red='#6a8a52', hair=WHITE_HAIR, skin=SKIN, cuff='#8a8a86', beard='#d0d0cc')},
    # 용왕: the elder's beard, a gold crown tipped with coral, sea-green robe gone grey with sickness
    'npc_dragonking': {'beard': 'long', 'hat': 'crown', 'ramps': P(robe='#3e6a5e', red='#8a3a3a', hair=GREY_HAIR, skin='#a4988e', cuff='#2e4a42')},
    # 맏형: stern, steel-dark robe, hair bound high
    'npc_brother1': {'ramps': P(robe='#3a4458', red='#4a4a5e', skin=SKIN, cuff='#262e3c')},
    # 둘째: deep teal robe
    'npc_brother2': {'ramps': P(robe='#2e5a56', red='#3e5a54', skin=SKIN, cuff='#1e3c3a')},
}


def sheet(name, sp):
    frames = [hero.render(hero.DOWN, {}, sp),
              hero.render(hero.DIAG, {}, sp), hero.render(hero.DIAG, {'breath': True}, sp),
              hero.render(-hero.DIAG, {}, sp), hero.render(-hero.DIAG, {'breath': True}, sp)]
    im = Image.new('RGBA', (hero.W * len(frames), hero.H), (0, 0, 0, 0))
    for i, f in enumerate(frames):
        im.paste(Image.fromarray(f, 'RGBA'), (i * hero.W, 0))
    im.save(hero.GODOT / f'{name}.png')
    return im


def main():
    out = [sheet(n, sp) for n, sp in PEOPLE.items()]
    print('people:', ', '.join(PEOPLE))
    if '--preview' in sys.argv:
        k = int(sys.argv[sys.argv.index('--preview') + 1])
        row = Image.new('RGBA', (34 * len(out), 48), (38, 44, 58, 255))
        for i, im in enumerate(out):
            row.alpha_composite(im.crop((32, 0, 64, 48)), (i * 34, 0))
        row.resize((row.width * k, row.height * k), Image.NEAREST).save(ROOT / 'out' / 'people_preview.png')


if __name__ == '__main__':
    np.seterr(all='ignore')
    main()
