"""Synthesize all music and sound effects (daegeum, gayageum, janggu, jing, chimes) -> godot/audio/*.ogg

Same instruments and tracks as src/js/audio.js (A gyemyeonjo-flavoured scale).
Usage: python3 art/sound.py
"""
import os, subprocess, wave
import numpy as np
from scipy.signal import lfilter

SR = 44100
OUT = os.path.join(os.path.dirname(__file__), "..", "godot", "audio")
SCALE = [0, 3, 5, 7, 10]
rng = np.random.default_rng(7)
NOISE = rng.uniform(-1, 1, SR * 4)


def note(deg, oct=0):
    o, i = divmod(deg, 5)
    return 220 * 2 ** ((SCALE[i] + 12 * (o + oct)) / 12)


def env(n, a, dec, peak=1.0):
    t = np.arange(n) / SR
    e = np.where(t < a, t / max(a, 1e-4), np.exp(-(t - a) / max(dec / 5, 1e-4)))
    return e * peak


def _lp(x, f):
    a = float(np.exp(-2 * np.pi * min(f, SR * 0.45) / SR))
    return lfilter([1 - a], [1, -a], x)


def lowpass(x, cutoff):
    # one-pole low-pass; a sweeping cutoff is approximated by crossfading two fixed filters
    c = np.asarray(cutoff, dtype=float)
    if c.ndim == 0:
        return _lp(x, float(c))
    lo, hi = float(c.min()), float(c.max())
    if hi - lo < 1:
        return _lp(x, lo)
    k = (c - lo) / (hi - lo)
    return _lp(x, lo) * (1 - k) + _lp(x, hi) * k


def bandnoise(n, f, q=2.0, off=0):
    x = NOISE[off % SR: off % SR + n] if n <= SR * 3 else rng.uniform(-1, 1, n)
    hp = x - lowpass(x, f / q)
    return lowpass(hp, f * q)


def pluck(f, vol=0.3, dec=0.9):
    n = int(SR * (dec + 0.1)); t = np.arange(n) / SR
    fr = f * (1 + 0.012 * np.exp(-t * 40))
    ph = 2 * np.pi * np.cumsum(fr) / SR
    tri = 2 / np.pi * np.arcsin(np.sin(ph))
    saw = 2 * ((ph / (2 * np.pi)) % 1) - 1
    x = tri + 0.18 * saw
    x = lowpass(x, f * 1.2 + f * 5 * np.exp(-t / max(dec / 3, 0.05)))
    return x * env(n, 0.004, dec, vol)


def flute(f, ln, vol=0.16):
    n = int(SR * (ln + 0.3)); t = np.arange(n) / SR
    vib = 1 + 0.012 * np.minimum(1, t / max(ln * 0.6, 0.01)) * np.sin(2 * np.pi * 5.2 * t)
    fr = f * vib * np.where(t < 0.12, 0.97 + 0.03 * t / 0.12, 1)
    ph = 2 * np.pi * np.cumsum(fr) / SR
    x = np.sin(ph) + 0.12 * np.sin(2 * ph) + 0.25 * bandnoise(n, f * 2, 3, int(f))
    e = np.minimum(1, t / 0.09)
    e = np.where(t > ln * 0.7, np.exp(-(t - ln * 0.7) / 0.12), e)
    return x * e * vol


def drum(kind, vol=0.5):
    n = int(SR * 0.45); t = np.arange(n) / SR; out = np.zeros(n)
    if kind in ("kung", "deong"):
        f0 = 120 if kind == "deong" else 95
        fr = 48 + (f0 - 48) * np.exp(-t * 12)
        out += np.sin(2 * np.pi * np.cumsum(fr) / SR) * env(n, 0.003, 0.35, vol)
    if kind in ("deok", "deong"):
        m = int(SR * 0.15)
        out[:m] += bandnoise(m, 2600, 1.2, 99) * env(m, 0.002, 0.09, vol * 0.9)
    return out


def gong(vol=0.35, f=98, ln=3.8):
    n = int(SR * ln); t = np.arange(n) / SR; out = np.zeros(n)
    for m, v in [(1, 1), (2.02, 0.4), (2.76, 0.25), (4.1, 0.1)]:
        fr = f * m * (1 + 0.02 * np.exp(-t * 6))
        out += np.sin(2 * np.pi * np.cumsum(fr) / SR) * v
    return out * env(n, 0.01, 3.5, vol)


def chime(f, vol=0.12):
    n = int(SR * 1.5); t = np.arange(n) / SR
    return sum(np.sin(2 * np.pi * f * m * t) / m for m in (1, 2.76, 5.4)) * env(n, 0.002, 1.4, vol)


def noisehit(f, ln, vol, sweep=1.0):
    n = int(SR * (ln + 0.05)); t = np.arange(n) / SR
    x = rng.uniform(-1, 1, n)
    cut = f * sweep ** (t / ln)
    return lowpass(x - lowpass(x, cut / 3), cut) * env(n, 0.005, ln, vol * 1.6)


def tone(f0, f1, ln, vol, kind="sine"):
    n = int(SR * (ln + 0.05)); t = np.arange(n) / SR
    fr = f0 * (f1 / f0) ** np.minimum(1, t / ln)
    ph = 2 * np.pi * np.cumsum(fr) / SR
    x = {"sine": np.sin(ph), "square": np.sign(np.sin(ph)), "saw": 2 * ((ph / (2 * np.pi)) % 1) - 1,
         "tri": 2 / np.pi * np.arcsin(np.sin(ph))}[kind]
    return x * env(n, 0.005, ln, vol)


def mix(buf, x, at):
    i = int(at * SR)
    if i >= len(buf): return
    j = min(len(buf), i + len(x))
    buf[i:j] += x[: j - i]


def reverb(x, wet=0.25):
    y = x.copy()
    for d, g in [(0.13, 0.35), (0.29, 0.28), (0.41, 0.2), (0.53, 0.14)]:
        k = int(d * SR)
        z = np.zeros_like(x); z[k:] = x[:-k] * g
        y += lowpass(z, 2400) * wet * 3
    return y


def melody(seed, ln, lo, hi):
    r = np.random.default_rng(seed); m = []; d = (lo + hi) // 2
    for _ in range(ln):
        if r.random() < 0.35: m.append(None); continue
        d = int(np.clip(d + r.integers(0, 5) - 2, lo, hi)); m.append(d)
    return m


def track(name, spb, ln, fn, loops=2):
    total = spb * ln * loops
    buf = np.zeros(int(SR * (total + 4)))
    for s in range(ln * loops):
        fn(buf, s % ln, s * spb)
    # fold the tail into the start so the loop is seamless
    L = int(SR * total)
    out = buf[:L].copy(); out[: len(buf) - L] += buf[L:]
    return reverb(out, 0.22) * 0.9


def music():
    T = {}
    m = melody(3, 32, 4, 11); m2 = [d if d is not None else 2 for d in melody(65, 8, 0, 5)]
    def title(b, s, t):
        if s % 16 == 0: mix(b, gong(0.18, 73), t)
        if s % 4 == 0: mix(b, pluck(note(m2[(s // 4) % 8], -1), 0.18, 1.6), t)
        if m[s] is not None and s % 2 == 0: mix(b, flute(note(m[s]), 0.42 * 2.6, 0.12), t)
    T["title"] = track("title", 0.42, 32, title)
    ms = melody(11, 32, 5, 12)
    def sea(b, s, t):
        if s % 8 == 0: mix(b, drum("deong", 0.25), t)
        if s % 8 == 5: mix(b, drum("deok", 0.18), t)
        if s % 2 == 0: mix(b, pluck(note([0, 2, 4, 2, 3, 1, 4, 2][(s // 2) % 8], -1), 0.12, 0.9), t)
        if ms[s] is not None and s % 2 == 0: mix(b, flute(note(ms[s]), 0.36 * 2.2, 0.1), t)
    T["sea"] = track("sea", 0.36, 32, sea)
    mt = melody(21, 48, 5, 13)
    def town(b, s, t):
        p = s % 12
        if p == 0: mix(b, drum("deong", 0.35), t)
        if p in (3, 9): mix(b, drum("deok", 0.22), t)
        if p == 5: mix(b, drum("deok", 0.15), t)
        if p == 6: mix(b, drum("kung", 0.3), t)
        if s % 3 == 0:
            d = mt[s] if mt[s] is not None else (mt[(s + 1) % 48] or 5)
            mix(b, pluck(note(d), 0.2, 0.6), t)
        if s % 6 == 0: mix(b, pluck(note([0, 2, 0, 3][(s // 6) % 4], -1), 0.14, 1.2), t)
    T["town"] = track("town", 0.25, 48, town)
    me = melody(31, 32, 2, 9)
    def eerie(b, s, t):
        if s % 16 == 0: mix(b, gong(0.14, 62), t)
        if s % 8 == 4: mix(b, drum("kung", 0.18), t)
        if me[s] is not None and s % 3 == 0: mix(b, flute(note(me[s]) * 0.5, 1.5, 0.1), t)
        if s % 4 == 2: mix(b, pluck(note(me[s] if me[s] is not None else 3), 0.08, 1.4), t)
    T["eerie"] = track("eerie", 0.5, 32, eerie)
    mb = melody(41, 32, 6, 13)
    def battle(b, s, t):
        p = s % 8
        if p in (0, 3): mix(b, drum("deong", 0.38), t)
        if p in (2, 5, 7): mix(b, drum("deok", 0.25), t)
        if p == 4: mix(b, drum("kung", 0.3), t)
        if s % 2 == 0: mix(b, pluck(note([0, 0, 3, 2, 0, 0, 4, 3][(s // 2) % 8], -1), 0.2, 0.35), t)
        if mb[s] is not None and s % 2 == 0: mix(b, flute(note(mb[s]), 0.29, 0.11), t)
    T["battle"] = track("battle", 0.16, 32, battle, 4)
    mo = melody(51, 32, 3, 12)
    def boss(b, s, t):
        p = s % 8
        if p == 0: mix(b, drum("deong", 0.45), t)
        if p in (2, 3, 6): mix(b, drum("deok", 0.28), t)
        if p == 4: mix(b, drum("kung", 0.4), t)
        if s % 32 == 0: mix(b, gong(0.25, 55), t)
        if s % 2 == 0: mix(b, pluck(note([0, 1, 0, 1, 0, 3, 2, 1][(s // 2) % 8], -2), 0.24, 0.3), t)
        if mo[s] is not None and s % 2 == 1: mix(b, flute(note(mo[s]), 0.24, 0.12), t)
    T["boss"] = track("boss", 0.15, 32, boss, 4)
    sm = [7, None, 9, 8, 7, None, 5, None, 4, None, 5, 7, 8, None, 7, None, 9, None, 10, 9, 8, None, 7, None, 5, 7, 8, None, 7, None, None, None]
    def song(b, s, t):
        if s % 8 == 0: mix(b, drum("deong", 0.3), t)
        if s % 8 == 4: mix(b, drum("kung", 0.22), t)
        if s % 4 == 0: mix(b, pluck(note([0, 3, 2, 0][(s // 4) % 4], -1), 0.16, 1.4), t)
        if sm[s] is not None: mix(b, flute(note(sm[s]), 0.76, 0.15), t)
    T["song"] = track("song", 0.4, 32, song)
    return T


def seq(parts, ln):
    b = np.zeros(int(SR * ln))
    for t, x in parts: mix(b, x, t)
    return reverb(b, 0.18)


def sfx():
    S = {}
    S["swing"] = seq([(0, noisehit(1800, 0.12, 0.25, 0.4))], 0.3)
    S["hit"] = seq([(0, noisehit(900, 0.08, 0.4)), (0, tone(220, 90, 0.1, 0.25, "square"))], 0.3)
    S["hurt"] = seq([(0, tone(300, 120, 0.2, 0.25, "saw")), (0, noisehit(500, 0.15, 0.3))], 0.4)
    S["roll"] = seq([(0, noisehit(600, 0.22, 0.2, 2.5))], 0.4)
    S["purify"] = seq([(i * 0.09, chime(note(d + 10), 0.12)) for i, d in enumerate([0, 2, 4, 7])], 1.9)
    S["coin"] = seq([(0, chime(1760, 0.08)), (0.06, chime(2350, 0.07))], 0.8)
    S["level"] = seq([(i * 0.1, pluck(note(d + 5), 0.25, 0.9)) for i, d in enumerate([0, 2, 4, 5, 7])] + [(0, gong(0.15, 110, 2.5))], 2.6)
    S["skill1"] = seq([(0, tone(600, 1400, 0.25, 0.14, "tri")), (0, flute(note(12), 0.3, 0.12))], 0.7)
    S["skill2"] = seq([(i * 0.18, noisehit(1200, 0.15, 0.18, 0.5)) for i in range(6)], 1.3)
    S["skill3"] = seq([(0, noisehit(300, 0.6, 0.4, 4)), (0, tone(200, 500, 0.4, 0.15))], 0.9)
    S["ult"] = seq([(0, gong(0.4, 82, 3.5))] + [(0.3 + i * 0.32, flute(note(d), 0.4, 0.16)) for i, d in enumerate([7, 9, 8, 7, 5, 4])], 3.6)
    S["talk"] = seq([(0, tone(540, 480, 0.04, 0.05, "tri"))], 0.08)
    S["ui"] = seq([(0, pluck(note(9), 0.18, 0.4))], 0.5)
    S["item"] = seq([(0, pluck(note(7), 0.2, 0.5)), (0.08, pluck(note(9), 0.2, 0.5))], 0.7)
    S["quest"] = seq([(i * 0.12, chime(note(d + 5), 0.14)) for i, d in enumerate([5, 7, 9, 12])], 2.0)
    S["verse"] = seq([(0, gong(0.25, 98, 3))] + [(0.2 + i * 0.25, flute(note(d), 0.35, 0.14)) for i, d in enumerate([7, 9, 10, 12])], 3.2)
    S["slam"] = seq([(0, tone(120, 35, 0.5, 0.5)), (0, noisehit(400, 0.4, 0.45))], 0.7)
    S["fire"] = seq([(0, noisehit(2200, 0.3, 0.18, 0.3))], 0.5)
    S["roar"] = seq([(0, tone(90, 60, 0.9, 0.35, "saw")), (0, noisehit(300, 0.8, 0.3, 0.6))], 1.2)
    S["tell"] = seq([(0, tone(880, 880, 0.08, 0.08, "square"))], 0.15)
    S["death"] = seq([(0, tone(400, 60, 1.2, 0.3, "tri")), (0, gong(0.2, 65, 2.5))], 2.6)
    S["door"] = seq([(0, drum("kung", 0.3)), (0, noisehit(200, 0.3, 0.2))], 0.6)
    return S


def ambient():
    n = SR * 8; t = np.arange(n) / SR
    x = rng.uniform(-1, 1, n)
    sea = lowpass(x, 500) * (0.55 + 0.45 * np.sin(2 * np.pi * t / 8)) * 1.6
    wind = lowpass(x - lowpass(x, 300), 900) * (0.6 + 0.4 * np.sin(2 * np.pi * t / 8 + 1)) * 0.9
    return {"amb_sea": sea, "amb_wind": wind}


def write(name, x):
    x = x / max(1.0, np.max(np.abs(x)) / 0.95)
    tmp = os.path.join(OUT, name + ".wav")
    with wave.open(tmp, "wb") as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(SR)
        w.writeframes((x * 32767).astype(np.int16).tobytes())
    subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", tmp, "-c:a", "libvorbis", "-q:a", "4", os.path.join(OUT, name + ".ogg")], check=True)
    os.remove(tmp)


if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    for k, v in {**sfx(), **ambient()}.items():
        write(k, v); print("sfx", k)
    for k, v in music().items():
        write("music_" + k, v); print("music", k)
