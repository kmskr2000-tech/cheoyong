// Audio: everything is synthesized with WebAudio (daegeum flute, gayageum pluck, janggu, jing, wind chime).
'use strict';
G.audio = (() => {
  let ctx = null, master = null, musicBus = null, sfxBus = null, ambBus = null;
  let current = null; // current music track name
  let timer = null, nextT = 0, step = 0, track = null;
  const A = {};
  const muted = G.params.has('mute');

  // A gyemyeonjo-flavoured scale (A C D E G) over several octaves, as semitone offsets from A3
  const SCALE = [0, 3, 5, 7, 10];
  const note = (deg, oct = 0) => {
    const o = Math.floor(deg / 5);
    const i = ((deg % 5) + 5) % 5;
    return 220 * Math.pow(2, (SCALE[i] + 12 * (o + oct)) / 12);
  };

  A.unlock = () => {
    if (muted) return;
    if (!ctx) {
      const AC = window.AudioContext || window.webkitAudioContext;
      if (!AC) return;
      ctx = new AC();
      master = ctx.createGain(); master.gain.value = 0.8; master.connect(ctx.destination);
      const comp = ctx.createDynamicsCompressor(); comp.connect(master);
      // simple reverb: feedback delay pair
      const rev = ctx.createGain(); rev.gain.value = 0.25;
      const d1 = ctx.createDelay(); d1.delayTime.value = 0.13;
      const d2 = ctx.createDelay(); d2.delayTime.value = 0.29;
      const fb = ctx.createGain(); fb.gain.value = 0.38;
      const lp = ctx.createBiquadFilter(); lp.type = 'lowpass'; lp.frequency.value = 2400;
      rev.connect(d1); d1.connect(d2); d2.connect(lp); lp.connect(fb); fb.connect(d1); lp.connect(comp);
      A.rev = rev;
      musicBus = ctx.createGain(); musicBus.gain.value = 0.42; musicBus.connect(comp); musicBus.connect(rev);
      sfxBus = ctx.createGain(); sfxBus.gain.value = 0.7; sfxBus.connect(comp); sfxBus.connect(rev);
      ambBus = ctx.createGain(); ambBus.gain.value = 0.25; ambBus.connect(comp);
      A.noiseBuf = ctx.createBuffer(1, ctx.sampleRate * 2, ctx.sampleRate);
      const d = A.noiseBuf.getChannelData(0);
      for (let i = 0; i < d.length; i++) d[i] = Math.random() * 2 - 1;
      if (track) startScheduler();
    }
    if (ctx.state === 'suspended') ctx.resume();
  };

  // ---------- instruments ----------
  const env = (g, t, a, peak, dec) => {
    g.gain.setValueAtTime(0.0001, t);
    g.gain.exponentialRampToValueAtTime(peak, t + a);
    g.gain.exponentialRampToValueAtTime(0.0001, t + a + dec);
  };
  function pluck(f, t, vol = 0.3, dec = 0.9, bus = musicBus) {
    const o = ctx.createOscillator(), o2 = ctx.createOscillator(), g = ctx.createGain();
    const lp = ctx.createBiquadFilter(); lp.type = 'lowpass';
    lp.frequency.setValueAtTime(f * 6, t); lp.frequency.exponentialRampToValueAtTime(f * 1.2, t + dec);
    o.type = 'triangle'; o2.type = 'sawtooth';
    o.frequency.setValueAtTime(f * 1.012, t); o.frequency.exponentialRampToValueAtTime(f, t + 0.06);
    o2.frequency.value = f;
    const g2 = ctx.createGain(); g2.gain.value = 0.18;
    o.connect(g); o2.connect(g2); g2.connect(g); g.connect(lp); lp.connect(bus);
    env(g, t, 0.004, vol, dec);
    o.start(t); o2.start(t); o.stop(t + dec + 0.1); o2.stop(t + dec + 0.1);
  }
  function flute(f, t, len, vol = 0.16, bus = musicBus) {
    const o = ctx.createOscillator(), g = ctx.createGain();
    const vib = ctx.createOscillator(), vg = ctx.createGain();
    o.type = 'sine'; o.frequency.setValueAtTime(f * 0.97, t); o.frequency.linearRampToValueAtTime(f, t + 0.12);
    vib.frequency.value = 5.2; vg.gain.setValueAtTime(0, t); vg.gain.linearRampToValueAtTime(f * 0.012, t + len * 0.6);
    vib.connect(vg); vg.connect(o.frequency);
    const h = ctx.createOscillator(); h.type = 'sine'; h.frequency.value = f * 2; const hg = ctx.createGain(); hg.gain.value = 0.12;
    h.connect(hg); hg.connect(g);
    // breath noise
    const n = ctx.createBufferSource(); n.buffer = A.noiseBuf;
    const bp = ctx.createBiquadFilter(); bp.type = 'bandpass'; bp.frequency.value = f * 2; bp.Q.value = 3;
    const ng = ctx.createGain(); ng.gain.value = 0.25; n.connect(bp); bp.connect(ng); ng.connect(g);
    o.connect(g); g.connect(bus);
    g.gain.setValueAtTime(0.0001, t);
    g.gain.exponentialRampToValueAtTime(vol, t + 0.09);
    g.gain.setValueAtTime(vol, t + len * 0.7);
    g.gain.exponentialRampToValueAtTime(0.0001, t + len + 0.25);
    for (const s of [o, vib, h, n]) { s.start(t); s.stop(t + len + 0.3); }
  }
  function drum(t, kind, vol = 0.5, bus = musicBus) {
    if (kind === 'kung' || kind === 'deong') {
      const o = ctx.createOscillator(), g = ctx.createGain();
      o.frequency.setValueAtTime(kind === 'deong' ? 120 : 95, t); o.frequency.exponentialRampToValueAtTime(48, t + 0.25);
      o.connect(g); g.connect(bus); env(g, t, 0.003, vol, 0.35); o.start(t); o.stop(t + 0.45);
    }
    if (kind === 'deok' || kind === 'deong') {
      const n = ctx.createBufferSource(); n.buffer = A.noiseBuf;
      const bp = ctx.createBiquadFilter(); bp.type = 'bandpass'; bp.frequency.value = 2600; bp.Q.value = 1.2;
      const g = ctx.createGain(); n.connect(bp); bp.connect(g); g.connect(bus);
      env(g, t, 0.002, vol * 0.7, 0.09); n.start(t, Math.random()); n.stop(t + 0.15);
    }
  }
  function gong(t, vol = 0.35, f = 98, bus = musicBus) {
    for (const [m, v] of [[1, 1], [2.02, 0.4], [2.76, 0.25], [4.1, 0.1]]) {
      const o = ctx.createOscillator(), g = ctx.createGain();
      o.frequency.setValueAtTime(f * m * 1.02, t); o.frequency.exponentialRampToValueAtTime(f * m, t + 0.6);
      o.connect(g); g.connect(bus); env(g, t, 0.01, vol * v, 3.5); o.start(t); o.stop(t + 3.8);
    }
  }
  function chime(t, f, vol = 0.12, bus = sfxBus) {
    for (const m of [1, 2.76, 5.4]) {
      const o = ctx.createOscillator(), g = ctx.createGain();
      o.type = 'sine'; o.frequency.value = f * m;
      o.connect(g); g.connect(bus); env(g, t, 0.002, vol / m, 1.4); o.start(t); o.stop(t + 1.5);
    }
  }
  function noiseHit(t, freq, len, vol, type = 'bandpass', bus = sfxBus, sweep = 0) {
    const n = ctx.createBufferSource(); n.buffer = A.noiseBuf;
    const f = ctx.createBiquadFilter(); f.type = type; f.frequency.setValueAtTime(freq, t);
    if (sweep) f.frequency.exponentialRampToValueAtTime(Math.max(40, freq * sweep), t + len);
    f.Q.value = 0.9;
    const g = ctx.createGain(); n.connect(f); f.connect(g); g.connect(bus);
    env(g, t, 0.005, vol, len); n.start(t, Math.random()); n.stop(t + len + 0.05);
  }
  function tone(t, f0, f1, len, vol, type = 'sine', bus = sfxBus) {
    const o = ctx.createOscillator(), g = ctx.createGain(); o.type = type;
    o.frequency.setValueAtTime(f0, t); o.frequency.exponentialRampToValueAtTime(f1, t + len);
    o.connect(g); g.connect(bus); env(g, t, 0.005, vol, len); o.start(t); o.stop(t + len + 0.05);
  }

  // ---------- music ----------
  // Each track: tempo (sec per step), length in steps, and a function(step, t) that schedules notes.
  const R = G.rng(77);
  const melody = (seed, len, lo, hi) => {
    const r = G.rng(seed); const m = []; let d = Math.floor((lo + hi) / 2);
    for (let i = 0; i < len; i++) {
      if (r() < 0.35) { m.push(null); continue; }
      d = G.clamp(d + Math.floor(r() * 5) - 2, lo, hi); m.push(d);
    }
    return m;
  };
  const TRACKS = {
    title: { spb: 0.42, len: 32, mel: melody(3, 32, 4, 11), fn(s, t, tr) {
      if (s % 16 === 0) gong(t, 0.18, 73);
      if (s % 4 === 0) pluck(note(tr.mel2[s / 4 % 8] ?? 0, -1), t, 0.18, 1.6);
      const n = tr.mel[s]; if (n != null && s % 2 === 0) flute(note(n), t, tr.spb * 2.6, 0.12);
    } },
    sea: { spb: 0.36, len: 32, mel: melody(11, 32, 5, 12), fn(s, t, tr) {
      if (s % 8 === 0) drum(t, 'deong', 0.25); if (s % 8 === 5) drum(t, 'deok', 0.18);
      if (s % 2 === 0) pluck(note([0, 2, 4, 2, 3, 1, 4, 2][(s / 2) % 8], -1), t, 0.12, 0.9);
      const n = tr.mel[s]; if (n != null && s % 2 === 0) flute(note(n), t, tr.spb * 2.2, 0.1);
    } },
    town: { spb: 0.25, len: 48, mel: melody(21, 48, 5, 13), fn(s, t, tr) {
      const p = s % 12; // semachi-like 12 beat cycle
      if (p === 0) drum(t, 'deong', 0.35); if (p === 3) drum(t, 'deok', 0.22); if (p === 5) drum(t, 'deok', 0.15);
      if (p === 6) drum(t, 'kung', 0.3); if (p === 9) drum(t, 'deok', 0.22);
      if (s % 3 === 0) pluck(note(tr.mel[s] ?? tr.mel[(s + 1) % 48] ?? 5), t, 0.2, 0.6);
      if (s % 6 === 0) pluck(note([0, 2, 0, 3][(s / 6) % 4], -1), t, 0.14, 1.2);
    } },
    eerie: { spb: 0.5, len: 32, mel: melody(31, 32, 2, 9), fn(s, t, tr) {
      if (s % 16 === 0) gong(t, 0.14, 62);
      if (s % 8 === 4) drum(t, 'kung', 0.18);
      const n = tr.mel[s]; if (n != null && s % 3 === 0) flute(note(n) * 0.5, t, tr.spb * 3, 0.1);
      if (s % 4 === 2) pluck(note(n ?? 3, 0) * 1.0, t, 0.08, 1.4);
    } },
    battle: { spb: 0.16, len: 32, mel: melody(41, 32, 6, 13), fn(s, t, tr) {
      const p = s % 8;
      if (p === 0 || p === 3) drum(t, 'deong', 0.38); if (p === 2 || p === 5 || p === 7) drum(t, 'deok', 0.25);
      if (p === 4) drum(t, 'kung', 0.3);
      if (s % 2 === 0) pluck(note([0, 0, 3, 2, 0, 0, 4, 3][(s / 2) % 8], -1), t, 0.2, 0.35);
      const n = tr.mel[s]; if (n != null && s % 2 === 0) flute(note(n), t, tr.spb * 1.8, 0.11);
    } },
    boss: { spb: 0.15, len: 32, mel: melody(51, 32, 3, 12), fn(s, t, tr) {
      const p = s % 8;
      if (p === 0) { drum(t, 'deong', 0.45); } if (p === 2 || p === 3 || p === 6) drum(t, 'deok', 0.28);
      if (p === 4) drum(t, 'kung', 0.4); if (s % 32 === 0) gong(t, 0.25, 55);
      if (s % 2 === 0) pluck(note([0, 1, 0, 1, 0, 3, 2, 1][(s / 2) % 8], -2), t, 0.24, 0.3);
      const n = tr.mel[s]; if (n != null && s % 2 === 1) flute(note(n), t, tr.spb * 1.6, 0.12);
    } },
    song: { spb: 0.4, len: 32, mel: [7, null, 9, 8, 7, null, 5, null, 4, null, 5, 7, 8, null, 7, null, 9, null, 10, 9, 8, null, 7, null, 5, 7, 8, null, 7, null, null, null], fn(s, t, tr) {
      if (s % 8 === 0) drum(t, 'deong', 0.3); if (s % 8 === 4) drum(t, 'kung', 0.22);
      if (s % 4 === 0) pluck(note([0, 3, 2, 0][(s / 4) % 4], -1), t, 0.16, 1.4);
      const n = tr.mel[s]; if (n != null) flute(note(n), t, tr.spb * 1.9, 0.15);
    } },
  };
  for (const k in TRACKS) TRACKS[k].mel2 = melody(k.length * 13, 8, 0, 5);

  function startScheduler() {
    if (!ctx || timer) return;
    nextT = ctx.currentTime + 0.1; step = 0;
    timer = setInterval(() => {
      if (!track) return;
      while (nextT < ctx.currentTime + 0.25) {
        try { track.fn(step % track.len, nextT, track); } catch (e) { /* keep going */ }
        nextT += track.spb; step++;
      }
    }, 60);
  }
  A.music = (name) => {
    if (current === name) return;
    current = name;
    track = TRACKS[name] || null;
    if (!ctx) return;
    // quick fade
    const now = ctx.currentTime;
    musicBus.gain.cancelScheduledValues(now);
    musicBus.gain.setValueAtTime(0.0001, now);
    musicBus.gain.linearRampToValueAtTime(0.42, now + 1.2);
    step = 0; nextT = Math.max(nextT, now + 0.05);
    startScheduler();
  };
  A.current = () => current;
  A.toggle = () => {
    if (!ctx) return;
    A.off = !A.off;
    master.gain.value = A.off ? 0 : 0.8;
  };

  // ambient: sea waves or wind
  let ambNode = null, ambName = null;
  A.ambient = (name) => {
    if (!ctx || ambName === name) return;
    ambName = name;
    if (ambNode) { try { ambNode.stop(); } catch (e) {} ambNode = null; }
    if (!name) return;
    const n = ctx.createBufferSource(); n.buffer = A.noiseBuf; n.loop = true;
    const f = ctx.createBiquadFilter(); f.type = 'lowpass'; f.frequency.value = name === 'sea' ? 500 : 900;
    const g = ctx.createGain(); g.gain.value = 0.5;
    const lfo = ctx.createOscillator(); lfo.frequency.value = name === 'sea' ? 0.12 : 0.07;
    const lg = ctx.createGain(); lg.gain.value = 0.45; lfo.connect(lg); lg.connect(g.gain);
    n.connect(f); f.connect(g); g.connect(ambBus); n.start(); lfo.start();
    ambNode = { stop() { n.stop(); lfo.stop(); } };
  };

  // ---------- sfx ----------
  const S = {
    swing: (t) => noiseHit(t, 1800, 0.12, 0.25, 'bandpass', sfxBus, 0.4),
    hit: (t) => { noiseHit(t, 900, 0.08, 0.4, 'lowpass'); tone(t, 220, 90, 0.1, 0.25, 'square'); },
    hurt: (t) => { tone(t, 300, 120, 0.2, 0.25, 'sawtooth'); noiseHit(t, 500, 0.15, 0.3, 'lowpass'); },
    roll: (t) => noiseHit(t, 600, 0.22, 0.2, 'bandpass', sfxBus, 2.5),
    purify: (t) => { [0, 2, 4, 7].forEach((d, i) => chime(t + i * 0.09, note(d + 10), 0.12)); },
    coin: (t) => { chime(t, 1760, 0.08); chime(t + 0.06, 2350, 0.07); },
    level: (t) => { [0, 2, 4, 5, 7].forEach((d, i) => pluck(note(d + 5), t + i * 0.1, 0.25, 0.9, sfxBus)); gong(t, 0.15, 110, sfxBus); },
    skill1: (t) => { tone(t, 600, 1400, 0.25, 0.14, 'triangle'); flute(note(12), t, 0.3, 0.12, sfxBus); },
    skill2: (t) => { for (let i = 0; i < 6; i++) noiseHit(t + i * 0.18, 1200, 0.15, 0.18, 'bandpass', sfxBus, 0.5); },
    skill3: (t) => { noiseHit(t, 300, 0.6, 0.4, 'lowpass', sfxBus, 4); tone(t, 200, 500, 0.4, 0.15); },
    ult: (t) => { gong(t, 0.4, 82, sfxBus); [7, 9, 8, 7, 5, 4].forEach((d, i) => flute(note(d), t + 0.3 + i * 0.32, 0.4, 0.16, sfxBus)); },
    talk: (t) => tone(t, 520 + Math.random() * 80, 480, 0.04, 0.04, 'triangle'),
    ui: (t) => pluck(note(9), t, 0.18, 0.4, sfxBus),
    item: (t) => { pluck(note(7), t, 0.2, 0.5, sfxBus); pluck(note(9), t + 0.08, 0.2, 0.5, sfxBus); },
    quest: (t) => { [5, 7, 9, 12].forEach((d, i) => chime(t + i * 0.12, note(d + 5), 0.14)); },
    verse: (t) => { gong(t, 0.25, 98, sfxBus); [7, 9, 10, 12].forEach((d, i) => flute(note(d), t + 0.2 + i * 0.25, 0.35, 0.14, sfxBus)); },
    slam: (t) => { tone(t, 120, 35, 0.5, 0.5); noiseHit(t, 400, 0.4, 0.45, 'lowpass'); },
    fire: (t) => noiseHit(t, 2200, 0.3, 0.18, 'highpass', sfxBus, 0.3),
    roar: (t) => { tone(t, 90, 60, 0.9, 0.35, 'sawtooth'); noiseHit(t, 300, 0.8, 0.3, 'bandpass', sfxBus, 0.6); },
    tell: (t) => tone(t, 880, 880, 0.08, 0.08, 'square'),
    death: (t) => { tone(t, 400, 60, 1.2, 0.3, 'triangle'); gong(t, 0.2, 65, sfxBus); },
    door: (t) => { drum(t, 'kung', 0.3, sfxBus); noiseHit(t, 200, 0.3, 0.2, 'lowpass'); },
  };
  let lastSfx = {};
  A.sfx = (name) => {
    if (!ctx || !S[name]) return;
    const now = ctx.currentTime;
    if (lastSfx[name] && now - lastSfx[name] < 0.04) return;
    lastSfx[name] = now;
    S[name](now + 0.01);
  };
  return A;
})();
