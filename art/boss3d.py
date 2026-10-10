"""역신(疫神) — 1장 보스를 처용·NPC와 같은 3D 인형 렌더러(art/hero.py)로, 사람의 3배 넘는 크기로 뽑는다.

A floating plague god: a curtain of black hair over a pale mask with ember eyes and a gaping mouth,
a tall rotting bell of a robe whose hem dissolves into nothing, long sleeves ending in bone claws,
sores weeping on the cloth. Modelled at a man's scale and rendered x3.1 (~136px against 처용's 44),
in the same muted palette and sel-out outline. The disguise frame ('human') is a pale scholar at
a man's size in the same cell, so the reveal reads as him swelling up.
Writes godot/assets/sprites/plague_god.png: idle0..3 (float), cast, swipe, hurt, human.
"""
import math, pathlib, sys
import numpy as np
from PIL import Image
import hero
from hero import Ell, Cone

ROOT = pathlib.Path(__file__).parent
CW, CH, FEET = 120, 164, 158          # cell; the hem floats on row FEET
SCALE = 3.1

RAMPS = {
    'grobe': hero.R('#121418', '#1a1e22', '#242a2c', '#2f3634', '#3c443e', '#4c5448'),
    'ginner': hero.R('#0c0a0e', '#120e14', '#18131a', '#1e1820', '#251d26', '#2c232c'),
    'mask': hero.R('#3a4038', '#56604f', '#727c68', '#8e9880', '#a8b096', '#c2c8ae'),
    'claw': hero.R('#2e2a24', '#46403a', '#605850', '#7a7266', '#948a7c', '#aca290'),
    'sore': hero.R('#1c2a14', '#2a4018', '#3a5a20', '#4e762a', '#66923a', '#82ac50'),
    'ember': hero.R('#4a3a10', '#7a5e16', '#a8841e', '#d0aa30', '#e8c858', '#f4e090'),
    'maw': hero.R('#080608', '#0c080c', '#120c12', '#180f16', '#1e141a', '#24181e'),
}


def god(pose):
    phase = pose.get('phase', 0)
    kind = pose.get('pose', 'idle')
    up = (0.0, 0.35, 0.7, 0.35)[phase] if kind == 'idle' else 0.35
    sway = math.sin(phase * math.pi / 2) * 0.5
    P = []
    # the robe: a tall bell, hem at the floor
    P.append(Cone((sway, 0.6 + up, 0), (0, 27 + up, 0), 12.5, 6.4, 'grobe', kz=0.8, tag='bell'))
    P.append(Cone((0, 26.5 + up, 0), (0, 33.5 + up, 0), 6.6, 8.2, 'grobe', kz=0.62, tag='chest'))
    for s in (-1, 1):
        P.append(Ell((s * 7.4, 32.4 + up, 0), (3.4, 2.6, 3.0), 'grobe', tag='chest'))
    # sleeves and claws
    for s in (-1, 1):
        sh = np.array([s * 8.6, 32.0 + up, 0.0])
        if kind == 'cast':
            el, hand = np.array([s * 13.5, 37.5 + up, 1.0]), np.array([s * 14.5, 45.0 + up, 1.5])
        elif kind == 'swipe' and s > 0:
            el, hand = np.array([s * 12.0, 27.0 + up, 4.5]), np.array([s * 4.0, 19.0 + up, 9.0])
        else:
            el, hand = np.array([s * 11.6, 22.5 + up, 1.0 + 0.3 * phase]), np.array([s * 12.4, 14.0 + up + (phase % 2) * 0.4, 1.6])
        P.append(Cone(sh, el, 2.6, 4.2, 'grobe', tag='sleeve'))
        wrist = el + (hand - el) * 0.18
        P.append(Ell(wrist, (1.6, 1.6, 1.6), 'mask'))
        for k in (-1, 0, 1):              # long bone claws
            tip = hand + np.array([k * 1.1, 0, k * 0.6])
            P.append(Cone(wrist, tip, 0.55, 0.15, 'claw', caps=False))
    # head: a pale mask under a curtain of hair
    hc = np.array([sway * 0.5, 38.4 + up, 0.6])
    P.append(Ell(hc + np.array([0, 0, 1.4]), (4.4, 5.6, 4.6), 'mask', tag='mask'))   # stands proud of the hair
    P.append(Ell(hc + np.array([0, 0.8, -1.0]), (6.0, 7.2, 5.6), 'hair', tag='curtain'))
    P.append(Cone(hc + np.array([0, -1.0, -2.2]), (sway, 23.0 + up, -3.4), 6.2, 8.6, 'hair', kz=0.7, tag='fall'))
    return P


def god_details(pr, p, n, tone, mat, lam, sp):
    x, y, z = p[:, 0], p[:, 1], p[:, 2]
    if pr.tag == 'bell':
        # the hem is eaten away: it frays into nothing toward the floor
        rnd = np.sin(np.floor(x * 0.9) * 12.9898 + np.floor(z * 0.9) * 78.233 + np.floor(y * 0.9) * 3.1) * 43758.5453 % 1.0
        eaten = rnd < np.clip((6.5 - y) / 6.0, 0, 1)
        mat = np.where(eaten, 'void', mat)
        tone = tone - np.clip((20 - y) / 18, 0, 1) * 1.0
        az = np.arctan2(x, z)
        fold = np.floor((az + np.pi) / (2 * np.pi) * 14).astype(int) % 2
        tone = tone + np.where(fold == 0, 0.3, -0.4)
        for (sx, sy, r) in ((-4.5, 16.0, 1.1), (5.0, 11.5, 0.9), (-1.5, 8.0, 0.8)):
            sore = ((x - sx) ** 2 + (y - sy) ** 2 < r * r) & (z > 0)
            mat = np.where(sore, 'sore', mat)
            tone = np.where(sore, tone - 1.5, tone)
    elif pr.tag == 'chest':
        opening = (z > 0) & (np.abs(x) < (33.5 - y) * 0.35)
        mat = np.where(opening, 'ginner', mat)
    elif pr.tag == 'mask':
        v = (p - pr.c) / pr.r
        az = np.arctan2(v[:, 0], v[:, 2]); el = v[:, 1]
        eye = (np.abs(np.abs(az) - 0.3) < 0.13) & (np.abs(el - 0.05) < 0.1)
        mat = np.where(eye, 'ember', mat); tone = np.where(eye, 5, tone)
        maw = (np.abs(az) < 0.22) & (el < -0.25) & (el > -0.62)
        mat = np.where(maw, 'maw', mat)
    elif pr.tag == 'curtain':
        v = (p - pr.c) / pr.r
        az = np.arctan2(v[:, 0], v[:, 2]); el = v[:, 1]
        gap = (np.abs(az) < 0.62 - np.clip(-el, 0, 1) * 0.2) & (el < 0.45)     # the parting over the face
        mat = np.where(gap, 'void', mat)
        tone = tone - 1.2 + np.where(((np.floor(x * 1.3) + np.floor(y * 0.4)) % 3) == 0, 0.6, 0.0)
    elif pr.tag == 'fall':
        tone = tone - 1.2 + np.where(((np.floor(x * 1.3) + np.floor(y * 0.4)) % 3) == 0, 0.6, 0.0)
    elif pr.tag == 'sleeve':
        tone = tone - 0.3
    return tone, mat


SPEC = {'parts': god, 'details': god_details, 'scale': SCALE, 'ramps': RAMPS}
# the disguise: a pale scholar in a black 사모, a man's size
DISGUISE = {'hat': 'samo', 'beard': 'short', 'scale': 0.82, 'ramps': {
    'robe': hero.R('#1c1a22', '#28252f', '#36323d', '#45404c', '#55505c', '#67626e'),
    'red': hero.R('#1a1a1e', '#26262c', '#33333a', '#404048', '#4e4e56', '#5e5e66'),
    'skin': hero.R('#4a4844', '#6e6a62', '#8e897e', '#aaa498', '#c2bcae', '#d6d0c2'),
}}


def main():
    np.seterr(all='ignore')
    frames = [hero.render(0, {'phase': i, 'pose': 'idle'}, SPEC, (CW, CH, FEET)) for i in range(4)]
    frames.append(hero.render(0, {'pose': 'cast'}, SPEC, (CW, CH, FEET)))
    frames.append(hero.render(0, {'pose': 'swipe'}, SPEC, (CW, CH, FEET)))
    frames.append(hero.render(0, {'pose': 'hurt'}, dict(SPEC, flash=1.6), (CW, CH, FEET)))
    frames.append(hero.render(0, {}, DISGUISE, (CW, CH, FEET)))
    sheet = Image.new('RGBA', (CW * len(frames), CH), (0, 0, 0, 0))
    for i, f in enumerate(frames):
        sheet.paste(Image.fromarray(f, 'RGBA'), (i * CW, 0))
    sheet.save(hero.GODOT / 'plague_god.png')
    print(f'plague_god.png  {len(frames)} frames of {CW}x{CH}, feet on row {FEET}')
    if '--preview' in sys.argv:
        k = int(sys.argv[sys.argv.index('--preview') + 1])
        bg = Image.new('RGBA', sheet.size, (38, 44, 58, 255))
        bg.alpha_composite(sheet)
        # 처용 beside him for scale
        cy = Image.open(hero.GODOT / 'cheoyong.png').crop((0, 0, 32, 48))
        bg.alpha_composite(cy, (CW * 7 + 70, FEET - 44))
        bg.resize((bg.width * k, bg.height * k), Image.NEAREST).save(ROOT / 'out' / 'plague_god_preview.png')


if __name__ == '__main__':
    main()
