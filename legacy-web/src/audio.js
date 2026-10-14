// Small WebAudio synth: 국악풍 타악·피리 단음 effects and a light ambient loop.
// Everything is synthesized; no sample files.
// TODO: replace with recorded 국악기 samples once a licensing-safe source is settled.

let ac = null;
let master = null;
let musicGain = null;
let muted = false;
let musicTimer = null;
let musicMode = null;

export function initAudio() {
  if (ac) { if (ac.state === 'suspended') ac.resume(); return; }
  const AC = window.AudioContext || window.webkitAudioContext;
  if (!AC) return;
  ac = new AC();
  master = ac.createGain();
  master.gain.value = 0.5;
  master.connect(ac.destination);
  musicGain = ac.createGain();
  musicGain.gain.value = 0.35;
  musicGain.connect(master);
}

export function toggleMute() {
  muted = !muted;
  if (master) master.gain.value = muted ? 0 : 0.5;
  return muted;
}
export function isMuted() { return muted; }

function env(g, t, a, d, peak) {
  g.gain.setValueAtTime(0.0001, t);
  g.gain.exponentialRampToValueAtTime(peak, t + a);
  g.gain.exponentialRampToValueAtTime(0.0001, t + a + d);
}

function tone(freq, dur, type = 'sine', vol = 0.3, slideTo = null, dest = null, when = 0) {
  if (!ac) return;
  const t = ac.currentTime + when;
  const o = ac.createOscillator();
  const g = ac.createGain();
  o.type = type;
  o.frequency.setValueAtTime(freq, t);
  if (slideTo) o.frequency.exponentialRampToValueAtTime(slideTo, t + dur);
  env(g, t, 0.01, dur, vol);
  o.connect(g); g.connect(dest || master);
  o.start(t); o.stop(t + dur + 0.05);
}

let noiseBuf = null;
function noise(dur, vol = 0.3, filterFreq = 2000, type = 'bandpass', dest = null, when = 0) {
  if (!ac) return;
  if (!noiseBuf) {
    noiseBuf = ac.createBuffer(1, ac.sampleRate, ac.sampleRate);
    const d = noiseBuf.getChannelData(0);
    for (let i = 0; i < d.length; i++) d[i] = Math.random() * 2 - 1;
  }
  const t = ac.currentTime + when;
  const s = ac.createBufferSource();
  s.buffer = noiseBuf;
  const f = ac.createBiquadFilter();
  f.type = type; f.frequency.value = filterFreq; f.Q.value = 1.2;
  const g = ac.createGain();
  env(g, t, 0.005, dur, vol);
  s.connect(f); f.connect(g); g.connect(dest || master);
  s.start(t); s.stop(t + dur + 0.05);
}

// 피리 단음: slightly breathy square-ish tone with vibrato.
function piri(freq, dur, vol = 0.12, dest = null, when = 0) {
  if (!ac) return;
  const t = ac.currentTime + when;
  const o = ac.createOscillator();
  const lfo = ac.createOscillator();
  const lg = ac.createGain();
  const g = ac.createGain();
  const f = ac.createBiquadFilter();
  o.type = 'sawtooth';
  o.frequency.setValueAtTime(freq * 0.97, t);
  o.frequency.linearRampToValueAtTime(freq, t + 0.06);
  lfo.frequency.value = 5.5; lg.gain.value = freq * 0.012;
  lfo.connect(lg); lg.connect(o.frequency);
  f.type = 'lowpass'; f.frequency.value = 1800;
  g.gain.setValueAtTime(0.0001, t);
  g.gain.exponentialRampToValueAtTime(vol, t + 0.04);
  g.gain.setValueAtTime(vol, t + dur * 0.7);
  g.gain.exponentialRampToValueAtTime(0.0001, t + dur);
  o.connect(f); f.connect(g); g.connect(dest || master);
  o.start(t); lfo.start(t); o.stop(t + dur + 0.05); lfo.stop(t + dur + 0.05);
}

const SFX = {
  slash: () => { noise(0.12, 0.25, 3500, 'highpass'); piri(880, 0.1, 0.06); },
  slash3: () => { noise(0.18, 0.3, 2500, 'highpass'); piri(1046, 0.16, 0.08); },
  heavy: () => { noise(0.3, 0.35, 1200); tone(220, 0.3, 'triangle', 0.25, 110); piri(1318, 0.2, 0.08); },
  hit: () => { tone(180, 0.12, 'sine', 0.35, 70); noise(0.05, 0.15, 800); },
  phit: () => { tone(120, 0.2, 'square', 0.18, 60); noise(0.1, 0.2, 500, 'lowpass'); },
  dodge: () => { noise(0.18, 0.18, 900, 'bandpass'); },
  parry: () => { // 꽹과리
    tone(1600, 0.35, 'square', 0.08); tone(2380, 0.3, 'square', 0.05); noise(0.25, 0.2, 5000, 'highpass');
  },
  bell: () => { tone(1320, 0.5, 'sine', 0.15); tone(1980, 0.4, 'sine', 0.07); },
  fire: () => { noise(0.5, 0.3, 600, 'lowpass'); tone(300, 0.4, 'sawtooth', 0.06, 150); },
  bind: () => { tone(400, 0.6, 'sine', 0.15, 200); tone(600, 0.5, 'triangle', 0.08); },
  shield: () => { tone(660, 0.4, 'sine', 0.15, 990); },
  shieldBreak: () => { noise(0.2, 0.3, 4000, 'highpass'); tone(990, 0.2, 'square', 0.06, 300); },
  song: () => { [0, 0.18, 0.36, 0.6].forEach((w, i) => piri([587, 659, 784, 880][i], 0.3, 0.12, null, w)); },
  ult: () => { [0, 0.12, 0.24].forEach((w) => tone(90, 0.3, 'sine', 0.4, 50, null, w)); piri(1174, 0.8, 0.1); },
  purify: () => { // 대금 상행 음
    if (!ac) return;
    const t = ac.currentTime;
    const o = ac.createOscillator(); const g = ac.createGain();
    o.type = 'sine'; o.frequency.setValueAtTime(440, t); o.frequency.exponentialRampToValueAtTime(1175, t + 0.6);
    env(g, t, 0.05, 0.8, 0.18); o.connect(g); g.connect(master); o.start(t); o.stop(t + 1);
  },
  kill: () => { tone(160, 0.25, 'sawtooth', 0.12, 50); noise(0.2, 0.2, 400, 'lowpass'); },
  enemyAtk: () => { noise(0.1, 0.1, 1500); },
  spit: () => { tone(300, 0.15, 'sine', 0.12, 600); },
  blip: () => { tone(880, 0.05, 'square', 0.05); },
  select: () => { tone(660, 0.06, 'square', 0.06); tone(990, 0.08, 'square', 0.05, null, null, 0.06); },
  coin: () => { tone(1500, 0.08, 'square', 0.05); tone(2000, 0.12, 'square', 0.05, null, null, 0.07); },
  levelup: () => { [523, 659, 784, 1046].forEach((f, i) => tone(f, 0.25, 'triangle', 0.15, null, null, i * 0.1)); },
  door: () => { tone(110, 0.3, 'triangle', 0.2, 80); noise(0.3, 0.1, 300, 'lowpass'); },
  cough: () => { noise(0.25, 0.35, 350, 'lowpass'); noise(0.2, 0.3, 300, 'lowpass', null, 0.25); },
  boss: () => { tone(55, 1.2, 'sawtooth', 0.2, 40); noise(1.0, 0.15, 200, 'lowpass'); },
  trap: () => { noise(0.4, 0.2, 250, 'lowpass'); },
  denied: () => { tone(200, 0.15, 'square', 0.08, 150); },
};

export function sfx(name) {
  if (!ac || muted) return;
  const f = SFX[name];
  if (f) try { f(); } catch (e) { /* audio errors must never break the game */ }
}

// Ambient loop: 장구 굿거리풍 박 + 피리 선율 (pentatonic). Modes: village, field, dungeon, boss, null.
const PENTA = [293.7, 329.6, 392, 440, 493.9, 587.3, 659.3, 784];
const MELO = {
  village: [3, -1, 4, 3, 1, -1, 0, -1, 1, 3, -1, 2, 1, -1, -1, -1],
  field: [0, -1, 2, -1, 3, 2, -1, 0, 1, -1, -1, 2, 0, -1, -1, -1],
  dungeon: [0, -1, -1, 1, -1, -1, 0, -1, -1, -1, 2, -1, 1, -1, -1, -1],
  boss: [5, 4, 3, -1, 5, 4, 6, -1, 3, 2, 3, 4, 2, -1, 0, -1],
  title: [3, -1, -1, 4, 3, -1, 1, -1, 0, -1, -1, 1, 3, -1, -1, -1],
};
export function playMusic(mode) {
  if (musicMode === mode) return;
  musicMode = mode;
  if (musicTimer) { clearInterval(musicTimer); musicTimer = null; }
  if (!mode || !ac) return;
  let step = 0;
  const bpm = mode === 'boss' ? 150 : mode === 'dungeon' ? 80 : 96;
  const stepDur = 60 / bpm / 2;
  musicTimer = setInterval(() => {
    if (!ac || muted || document.hidden) { step++; return; }
    const s = step % 16;
    // 장구: 덩(low) on 0, 쿵 on 6, 덕(rim) on 3/9/12
    if (s === 0 || s === 8) tone(mode === 'boss' ? 90 : 70, 0.25, 'sine', 0.3, 45, musicGain);
    if (s === 6 || s === 14) tone(110, 0.18, 'sine', 0.2, 60, musicGain);
    if (s === 3 || s === 11 || (mode === 'boss' && s % 2 === 1)) noise(0.06, 0.1, 3000, 'highpass', musicGain);
    const m = MELO[mode][s];
    if (m >= 0) piri(PENTA[m] * (mode === 'dungeon' ? 0.5 : 1), stepDur * 1.8, 0.05, musicGain);
    step++;
  }, stepDur * 1000);
}
