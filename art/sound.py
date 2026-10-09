"""소리 — 전부 코드로 합성 (외부 에셋 없음). numpy only.

Voices: 대금 (breathy bamboo flute with deep 농음 vibrato and 꺾는 소리 bends), 피리 (nasal reed), 아쟁풍 저음 드론,
장구 (궁·덕·덩), 북, 징 (beating partials), 풍경 (wind-chime bells), wind / waves noise.
Scale: A 계면조 (A C D E G) — D bends down toward C, A and E shake.

Music (seamless loops): title, night (탐색), dread (폐가), battle (자진모리 12/8), boss (휘모리풍)
SFX: slash hit block roll hurt song purify tell blip ui_move ui_ok pickup levelup throw wail fire splash stun door
Ambience loops: waves, wind
Output: godot/assets/audio/*.wav (22050 Hz mono 16-bit)
"""
import pathlib, wave
import numpy as np

SR = 22050
OUT = pathlib.Path(__file__).parent.parent / 'godot' / 'assets' / 'audio'
rng = np.random.default_rng(7)

NOTE = {'A2': 110.0, 'E3': 164.81, 'G3': 196.0, 'A3': 220.0, 'C4': 261.63, 'D4': 293.66, 'E4': 329.63, 'G4': 392.0,
        'A4': 440.0, 'C5': 523.25, 'D5': 587.33, 'E5': 659.25, 'G5': 783.99, 'A5': 880.0, 'C6': 1046.5, 'E6': 1318.5,
        'Bb2': 116.54, 'D3': 146.83, 'C3': 130.81}


# ---------------------------------------------------------------- DSP helpers
def t_(n):
    return np.arange(n) / SR


def env(n, a=0.02, r=0.1, curve=1.0):
    e = np.ones(n)
    na, nr = max(1, int(a * SR)), max(1, int(r * SR))
    na = min(na, n); nr = min(nr, n - na) if n - na > 0 else 1
    e[:na] = np.linspace(0, 1, na) ** curve
    if nr > 0:
        e[n - nr:] *= np.linspace(1, 0, nr) ** curve
    return e


def decay(n, tau):
    return np.exp(-t_(n) / tau)


def spectral(x, fn):
    """filter by shaping the spectrum: fn(freqs) -> gain"""
    X = np.fft.rfft(x)
    f = np.fft.rfftfreq(len(x), 1 / SR)
    return np.fft.irfft(X * fn(f), len(x))


def lowpass(x, fc):
    return spectral(x, lambda f: 1 / np.sqrt(1 + (f / fc) ** 4))


def bandpass(x, lo, hi):
    return spectral(x, lambda f: 1 / np.sqrt(1 + (lo / np.maximum(f, 1)) ** 4) / np.sqrt(1 + (f / hi) ** 4))


def noise(n, seed=None):
    r = np.random.default_rng(seed) if seed is not None else rng
    return r.standard_normal(n)


def reverb(x, secs=2.2, mix=0.3, bright=3500, seed=3):
    n_ir = int(secs * SR)
    ir = noise(n_ir, seed) * np.exp(-t_(n_ir) / (secs / 5.0))
    ir = lowpass(ir, bright)
    ir[: int(0.012 * SR)] = 0
    ir /= np.sqrt(np.sum(ir ** 2)) + 1e-9
    L = len(x) + n_ir
    nfft = 1 << (L - 1).bit_length()
    wet = np.fft.irfft(np.fft.rfft(x, nfft) * np.fft.rfft(ir, nfft), nfft)[:L]
    out = np.zeros(L)
    out[: len(x)] += x * (1 - mix)
    out += wet * mix * 0.9
    return out


def place(buf, sig, at):
    i = int(at * SR)
    if i >= len(buf):
        return
    m = min(len(sig), len(buf) - i)
    buf[i:i + m] += sig[:m]


def loopify(x, length_s):
    """wrap the reverb tail past the loop point back onto the start"""
    L = int(length_s * SR)
    out = x[:L].copy()
    tail = x[L:]
    k = 0
    while len(tail) > 0:
        m = min(len(tail), L)
        out[:m] += tail[:m]
        tail = tail[m:]
        k += 1
    return out


def crossloop(x, overlap_s=1.0):
    """for noise beds: crossfade the end into the start"""
    o = int(overlap_s * SR)
    y = x[:-o].copy()
    fade = np.linspace(0, 1, o)
    y[:o] = y[:o] * fade + x[-o:] * (1 - fade)
    return y


def add(*sigs):
    """sum signals of different lengths"""
    out = np.zeros(max(len(x) for x in sigs))
    for x in sigs:
        out[:len(x)] += x
    return out


def norm(x, peak=0.85):
    m = np.max(np.abs(x)) + 1e-9
    return x / m * peak


def save(name, x, peak=0.85):
    OUT.mkdir(parents=True, exist_ok=True)
    y = (norm(x, peak) * 32767).astype(np.int16)
    with wave.open(str(OUT / f'{name}.wav'), 'wb') as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(SR)
        w.writeframes(y.tobytes())


# ---------------------------------------------------------------- voices
def osc(freq, harm):
    """additive oscillator; freq is an array (Hz per sample)"""
    ph = 2 * np.pi * np.cumsum(freq) / SR
    return sum(a * np.sin(ph * (k + 1)) for k, a in enumerate(harm))


def pitch_curve(f0, dur, vib=0.012, vib_rate=5.0, vib_on=0.4, bend=None, scoop=0.0):
    n = int(dur * SR)
    t = t_(n)
    depth = vib * np.clip((t / dur - vib_on) / 0.3, 0, 1)
    f = f0 * (1 + depth * np.sin(2 * np.pi * vib_rate * t))
    if scoop:   # slide up into the note
        f *= 1 - scoop * np.exp(-t / 0.06)
    if bend is not None:   # 꺾는 소리: glide toward another pitch in the last third
        k = np.clip((t / dur - 0.62) / 0.3, 0, 1)
        f *= (bend / f0) ** (k * k * (3 - 2 * k))
    return f


def daegeum(f0, dur, vel=1.0, **kw):
    n = int(dur * SR)
    f = pitch_curve(f0, dur, **kw)
    body = osc(f, [1.0, 0.32, 0.14, 0.05, 0.03])
    breath = bandpass(noise(n), 1200, 5200) * 0.12
    buzz = osc(f * 2, [0.06]) * (1 + noise(n) * 0.5)   # the 청 membrane's buzz
    sig = (body + breath + buzz) * env(n, 0.09, 0.18, 1.6)
    return sig * vel


def piri(f0, dur, vel=1.0, **kw):
    kw.setdefault('vib_rate', 6.2)
    kw.setdefault('vib', 0.016)
    n = int(dur * SR)
    f = pitch_curve(f0, dur, **kw)
    body = osc(f, [1.0, 0.85, 0.7, 0.55, 0.4, 0.3, 0.2, 0.12, 0.08])
    sig = lowpass(body, 3200) * env(n, 0.035, 0.12, 1.3)
    return sig * vel * 0.7


def drone(f0, dur, vel=1.0, trem=0.25):
    n = int(dur * SR)
    t = t_(n)
    f = f0 * (1 + 0.002 * np.sin(2 * np.pi * 0.31 * t))
    body = osc(f, [1 / k for k in range(1, 9)])
    sig = lowpass(body, 900) * (1 + trem * np.sin(2 * np.pi * 0.23 * t)) * env(n, 1.5, 1.5)
    return sig * vel


def kung(vel=1.0):   # 궁편 (low side of the 장구)
    n = int(0.45 * SR)
    t = t_(n)
    f = 70 + 80 * np.exp(-t / 0.04)
    return (np.sin(2 * np.pi * np.cumsum(f) / SR) * decay(n, 0.16) + lowpass(noise(n), 400) * decay(n, 0.02) * 0.4) * vel


def deok(vel=1.0):   # 채편 (the whip-stick slap)
    n = int(0.12 * SR)
    return (bandpass(noise(n), 1800, 7000) * decay(n, 0.025) + np.sin(2 * np.pi * 520 * t_(n)) * decay(n, 0.02) * 0.4) * vel


def deong(vel=1.0):
    a, b = kung(vel), deok(vel * 0.9)
    a[:len(b)] += b
    return a


def buk(vel=1.0):
    n = int(0.6 * SR)
    t = t_(n)
    f = 52 + 50 * np.exp(-t / 0.05)
    return (np.sin(2 * np.pi * np.cumsum(f) / SR) * decay(n, 0.22) + lowpass(noise(n), 250) * decay(n, 0.03) * 0.6) * vel


def jing(vel=1.0, f0=98.0, dur=5.0):   # 징: beating pairs of partials, the pitch swelling upward ("우웅")
    n = int(dur * SR)
    t = t_(n)
    sw = 1 + 0.03 * (1 - np.exp(-t / 0.4))
    sig = np.zeros(n)
    for ratio, amp, tau in ((1.0, 1.0, 2.2), (1.003, 0.8, 2.0), (1.5, 0.45, 1.4), (1.51, 0.35, 1.3), (2.02, 0.3, 1.0), (2.76, 0.18, 0.7), (3.5, 0.08, 0.5)):
        sig += amp * np.sin(2 * np.pi * f0 * ratio * np.cumsum(sw) / SR) * decay(n, tau)
    return sig * env(n, 0.03, 0.5) * vel


def bell(f0, vel=1.0, dur=1.6):   # 풍경
    n = int(dur * SR)
    sig = sum(a * np.sin(2 * np.pi * f0 * r * t_(n)) * decay(n, tau) for r, a, tau in ((1, 1, 0.9), (2.76, 0.4, 0.35), (5.4, 0.2, 0.15), (8.9, 0.08, 0.06)))
    return sig * env(n, 0.002, 0.2) * vel


def wind(dur, seed=11, lo=200, hi=1200):
    n = int(dur * SR)
    x = bandpass(noise(n, seed), lo, hi)
    t = t_(n)
    sw = 0.55 + 0.45 * np.sin(2 * np.pi * 0.07 * t + 1) * np.sin(2 * np.pi * 0.031 * t)
    return x * sw


# ---------------------------------------------------------------- melody
def phrase(score, bpm, voice=daegeum, start=0.0, vel=1.0, octave=1.0):
    """score: list of (note, beats, ornament) — ornament: '' | 'v' (농음) | 'b' (꺾기: bend down a step) | 's' (scoop)"""
    beat = 60.0 / bpm
    out = []
    t = start
    for note, beats, orn in score:
        dur = beats * beat
        if note != '-':
            f0 = NOTE[note] * octave
            kw = {}
            if 'v' in orn:
                kw['vib'] = 0.022
                kw['vib_on'] = 0.25
            if 'b' in orn:
                kw['bend'] = f0 * 0.891   # about a whole step down
            if 's' in orn:
                kw['scoop'] = 0.06
            out.append((t, voice(f0, dur * 1.04, vel, **kw)))
        t += dur
    return out, t


# 처용가 주제 (leitmotif): A 계면조, ending on a shaking A
THEME = [('E4', 2, 's'), ('D4', 1, 'b'), ('C4', 1, ''), ('A3', 3, 'v'), ('-', 1, ''),
         ('C4', 1, ''), ('D4', 1, ''), ('E4', 2, 'v'), ('G4', 1, 's'), ('E4', 1, ''), ('D4', 3, 'b'), ('-', 1, ''),
         ('E4', 1, ''), ('G4', 1, ''), ('A4', 3, 'v'), ('G4', 1, ''), ('E4', 1, 'b'), ('D4', 1, ''), ('C4', 2, ''),
         ('A3', 4, 'v')]
THEME_B = [('A4', 2, 's'), ('G4', 1, ''), ('E4', 1, 'v'), ('D4', 2, 'b'), ('C4', 2, ''),
           ('D4', 1, ''), ('E4', 1, ''), ('C4', 1, ''), ('A3', 5, 'v')]


def mix_events(n, events):
    buf = np.zeros(n)
    for at, sig in events:
        place(buf, sig, at)
    return buf


# ---------------------------------------------------------------- music
def m_title():
    L = 48.0
    n = int((L + 4) * SR)
    buf = drone(NOTE['A2'], L + 4, 0.35) + drone(NOTE['E3'], L + 4, 0.2)
    ev, t = phrase(THEME, 56, start=2.0, vel=0.9)
    ev2, t = phrase(THEME_B, 56, start=t + 1.0, vel=0.85)
    buf += mix_events(n, ev + ev2)
    for at in (1.0, 13.0, 22.5, 37.0):
        place(buf, bell(NOTE['A5'] * (1.0 if at % 2 else 1.189), 0.18), at)
    buf += wind(L + 4, 5, 150, 900) * 0.06
    return loopify(reverb(buf, 3.0, 0.38), L)


def m_night():
    L = 54.0
    n = int((L + 4) * SR)
    buf = drone(NOTE['A2'], L + 4, 0.25) * 0.8
    ev, t = phrase(THEME[:5], 52, start=4.0, vel=0.7)
    ev2, _ = phrase(THEME_B, 52, start=22.0, vel=0.65)
    ev3, _ = phrase(THEME[5:12], 52, start=38.0, vel=0.6)
    buf += mix_events(n, ev + ev2 + ev3)
    for at, nt in ((9.0, 'E5'), (18.5, 'A5'), (31.0, 'D5'), (46.0, 'C5')):
        place(buf, bell(NOTE[nt], 0.15), at)
    buf += wind(L + 4, 9, 120, 700) * 0.08
    return loopify(reverb(buf, 3.2, 0.42), L)


def m_dread():
    L = 40.0
    n = int((L + 4) * SR)
    t = t_(n)
    buf = drone(NOTE['A2'], L + 4, 0.4, trem=0.4) + drone(NOTE['Bb2'], L + 4, 0.12, trem=0.6)   # a rubbing minor second
    for k in range(int(L / 1.7)):   # a slow heartbeat on the 북
        place(buf, buk(0.5), 1.0 + k * 1.7)
        place(buf, buk(0.3), 1.28 + k * 1.7)
    for at, nt in ((6.0, 'E5'), (21.0, 'D5'), (33.0, 'A4')):   # a distant 피리 crying downward
        place(buf, piri(NOTE[nt], 2.6, 0.35, bend=NOTE[nt] * 0.84, vib=0.03, vib_on=0.1), at)
    buf += wind(L + 4, 13, 80, 400) * 0.12 * (1 + 0.5 * np.sin(2 * np.pi * 0.05 * t))
    return loopify(reverb(buf, 3.5, 0.45, bright=2200), L)


def m_battle():
    bar = 2.4        # 자진모리: 12/8, four dotted beats a bar
    bars = 10
    L = bar * bars
    n = int((L + 3) * SR)
    e8 = bar / 12
    buf = drone(NOTE['A2'], L + 3, 0.35, trem=0.1)
    pat = ['덩', '', '', '덕', '', '덕', '쿵', '', '덕', '덕', '', '']
    alt = ['덩', '', '덕', '쿵', '', '덕', '쿵', '', '덕', '덩', '', '덕']
    for b in range(bars):
        p = alt if b % 4 == 3 else pat
        for i, s in enumerate(p):
            at = b * bar + i * e8
            if s == '덩': place(buf, deong(0.9), at)
            elif s == '덕': place(buf, deok(0.55), at)
            elif s == '쿵': place(buf, kung(0.7), at)
        if b % 4 == 0:
            place(buf, jing(0.5, dur=3.0), b * bar)
    riff = [('A4', 1.5, 's'), ('C5', 0.5, ''), ('D5', 1, 'b'), ('C5', 1, ''), ('A4', 2, 'v'),
            ('E5', 1.5, 's'), ('D5', 0.5, ''), ('C5', 1, ''), ('D5', 1, ''), ('A4', 2, 'v')]
    beat = bar / 4
    for rep in range(2):
        ev, _ = phrase(riff, 60 / beat, voice=piri, start=bar * (2 + rep * 4), vel=0.55)
        buf += mix_events(n, ev)
    return loopify(reverb(buf, 1.8, 0.25), L)


def m_boss():
    beat = 60 / 132
    bars = 12
    bar = beat * 4
    L = bar * bars
    n = int((L + 4) * SR)
    buf = drone(NOTE['A2'], L + 4, 0.45, trem=0.5) + drone(NOTE['Bb2'], L + 4, 0.15, trem=0.7)
    for b in range(bars):
        for i in range(8):
            at = b * bar + i * beat / 2
            if i in (0, 3, 6): place(buf, deong(1.0), at)
            elif i % 2: place(buf, deok(0.5), at)
            else: place(buf, kung(0.6), at)
        if b % 2 == 0:
            place(buf, jing(0.7, f0=92, dur=4.0), b * bar)
    wail = [('A5', 3, 'v'), ('G5', 1, 'b'), ('E5', 2, ''), ('D5', 2, 'b'), ('-', 1, ''), ('C5', 1, ''), ('D5', 2, 's'), ('A4', 4, 'v')]
    for rep in range(2):
        ev, _ = phrase(wail, 132, voice=piri, start=bar * (1 + rep * 6), vel=0.6)
        buf += mix_events(n, ev)
    return loopify(reverb(buf, 2.0, 0.3), L)


# ---------------------------------------------------------------- sfx
def sweep_noise(dur, f_hi, f_lo, vel=1.0, seed=None):
    n = int(dur * SR)
    x = noise(n, seed)
    # time-varying lowpass approximated by blending three bands
    a = bandpass(x, f_hi * 0.5, f_hi)
    b = bandpass(x, (f_hi + f_lo) / 4, (f_hi + f_lo) / 2)
    c = bandpass(x, f_lo * 0.5, f_lo)
    k = np.linspace(0, 1, n)
    return (a * (1 - k) ** 2 + b * 2 * k * (1 - k) + c * k ** 2) * vel


def sfx():
    out = {}
    out['slash'] = sweep_noise(0.16, 6000, 1200, seed=1) * env(int(0.16 * SR), 0.01, 0.08)
    h = buk(0.9)[: int(0.22 * SR)]
    h[: int(0.05 * SR)] += bandpass(noise(int(0.05 * SR), 2), 1500, 6000) * decay(int(0.05 * SR), 0.012) * 0.8
    out['hit'] = h
    out['block'] = add(bell(1400, 0.7, 0.35), bell(1980, 0.5, 0.3), bandpass(noise(int(0.35 * SR), 4), 2000, 8000) * decay(int(0.35 * SR), 0.02))
    out['roll'] = sweep_noise(0.3, 1800, 300, seed=5) * env(int(0.3 * SR), 0.05, 0.15)
    hu = buk(0.8)[: int(0.3 * SR)]
    hu += (np.sin(2 * np.pi * 180 * t_(len(hu))) + np.sin(2 * np.pi * 191 * t_(len(hu)))) * decay(len(hu), 0.08) * 0.3
    out['hurt'] = hu
    # 처용가 한 구절: a quick rising run up the 계면조, the last note held and shaking
    run = [('A3', 0.3, ''), ('C4', 0.3, ''), ('D4', 0.3, ''), ('E4', 0.3, ''), ('G4', 0.3, ''), ('A4', 1.6, 'v')]
    ev, t = phrase(run, 120, vel=0.9)
    out['song'] = reverb(mix_events(int((t + 0.5) * SR), ev), 2.0, 0.35)
    pur = np.zeros(int(1.6 * SR))
    for i, nt in enumerate(('A5', 'C6', 'E6', 'A5')):
        place(pur, bell(NOTE[nt] if nt in NOTE else 1760, 0.6), i * 0.09)
    out['purify'] = reverb(pur, 1.6, 0.35)
    out['tell'] = buk(0.5)[: int(0.25 * SR)] * 0.7
    out['blip'] = np.sin(2 * np.pi * 880 * t_(int(0.04 * SR))) * decay(int(0.04 * SR), 0.008) * 0.6
    out['ui_move'] = np.sin(2 * np.pi * 1320 * t_(int(0.05 * SR))) * decay(int(0.05 * SR), 0.01)
    uo = np.zeros(int(0.25 * SR))
    place(uo, bell(NOTE['E5'], 0.6, 0.2), 0); place(uo, bell(NOTE['A5'], 0.6, 0.2), 0.07)
    out['ui_ok'] = uo
    out['pickup'] = reverb(add(bell(NOTE['A5'], 0.8, 0.6), bell(NOTE['E6'], 0.4, 0.5)), 1.0, 0.3)
    lvl = jing(0.8, f0=110, dur=2.4)
    place(lvl, bell(NOTE['A5'], 0.5), 0.2); place(lvl, bell(NOTE['C6'], 0.5), 0.35); place(lvl, bell(NOTE['E6'], 0.5), 0.5)
    out['levelup'] = reverb(lvl, 1.8, 0.3)
    out['throw'] = sweep_noise(0.18, 1200, 400, seed=8) * env(int(0.18 * SR), 0.01, 0.1) * 0.8
    out['wail'] = reverb(daegeum(NOTE['E5'], 1.1, 0.8, vib=0.05, vib_on=0.0, vib_rate=7.5, bend=NOTE['A4']), 1.5, 0.4)
    fc = np.zeros(int(3.0 * SR))
    r = np.random.default_rng(21)
    for _ in range(90):   # crackles over a low roar
        place(fc, bandpass(noise(int(0.01 * SR), int(r.integers(1, 99))), 1500, 6000) * decay(int(0.01 * SR), 0.003) * r.uniform(0.3, 1.0), r.uniform(0, 2.95))
    fc += lowpass(noise(len(fc), 22), 300) * 0.25
    out['fire'] = fc
    out['splash'] = sweep_noise(0.4, 4000, 800, seed=12) * env(int(0.4 * SR), 0.005, 0.3)
    st = np.sin(2 * np.pi * 2100 * t_(int(0.8 * SR))) * (0.6 + 0.4 * np.sin(2 * np.pi * 9 * t_(int(0.8 * SR)))) * decay(int(0.8 * SR), 0.3)
    out['stun'] = st * 0.6
    out['door'] = sweep_noise(0.7, 900, 200, seed=14) * env(int(0.7 * SR), 0.2, 0.4)
    return out


def amb_waves():
    L = 16.0
    n = int((L + 1.5) * SR)
    t = t_(n)
    x = lowpass(noise(n, 31), 700)
    swell = np.clip(np.sin(2 * np.pi * t / 5.3) * 0.5 + 0.5, 0, 1) ** 2 + np.clip(np.sin(2 * np.pi * t / 8.0 + 2) * 0.5 + 0.5, 0, 1) ** 3 * 0.6
    hiss = bandpass(noise(n, 32), 2000, 6000) * swell ** 3 * 0.25
    return crossloop(x * (0.25 + swell) + hiss, 1.5)


def amb_wind():
    L = 16.0
    return crossloop(wind(L + 1.5, 41, 150, 1000) + wind(L + 1.5, 42, 600, 2400) * 0.3, 1.5)


def main():
    for name, fn in (('title', m_title), ('night', m_night), ('dread', m_dread), ('battle', m_battle), ('boss', m_boss)):
        save('music_' + name, fn(), 0.7)
        print('music', name)
    for k, v in sfx().items():
        f = int(0.008 * SR)   # short fade-out so cut-off sounds don't click
        v[-f:] *= np.linspace(1, 0, f)
        save('sfx_' + k, v, 0.8)
    save('amb_waves', amb_waves(), 0.5)
    save('amb_wind', amb_wind(), 0.5)
    print('sfx + ambience done')


if __name__ == '__main__':
    main()
