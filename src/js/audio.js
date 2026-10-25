// WebAudio 합성 전용(파일 없음). 장구·박·피리. AudioContext가 없어도 절대 throw 하지 않는다.
const PENTA = [311.13, 349.23, 415.30, 466.16, 523.25]; // Eb F Ab Bb C
const LOOKAHEAD = 0.1;   // 초
const TICK_MS = 25;

let ctx = null, master = null, noiseBuf = null;
let bias = 0;                         // now() = 원천 시계 + bias (원천이 바뀌어도 끊김 없게)
let userOff = 0;                      // 사용자 보정(초). Audio.setOffset
let lat = 0;                          // 출력 지연(초). init·재개·장단 시작 때만 표본(rebase 안에서)
let speed = 1;
let fakeBase = 0, perfBase = perfNow();
let frozen = false, paused = false;   // 탭 숨김·창 포커스 잃음 → 시계 정지
const pending = new Map();            // 예약만 된 소스 노드 → 시작 시각(ctx 원시 시간)
let jd = null;                        // 장단 상태
let pluckN = 0;

function perfNow() { return (typeof performance !== 'undefined' ? performance.now() : Date.now()) / 1000; }
const fakeT = () => (frozen ? fakeBase : fakeBase + (perfNow() - perfBase) * speed);
const useCtx = () => !!(ctx && Audio.ready && !Audio.muted);
// ctx 시계는 출력 지연과 사용자 보정만큼 뒤로 민다(들리는 시각 = 판정 기준 시각). 가짜 시계는 보정 없음.
const srcT = () => (useCtx() ? ctx.currentTime - lat - userOff : fakeT());
// 시계 원천이 바뀌는 변경(fn) 전후로 now()가 점프하지 않게 보정
function rebase(fn) { const before = Audio.now(); fn(); bias += before - Audio.now(); }
// now() 시각 → ctx 원시 시간(예약용). now() = ctx.currentTime - lat - userOff + bias 의 역.
const toRaw = (at) => at + lat + userOff - bias;
function sampleLat() { try { lat = (ctx && (ctx.outputLatency || ctx.baseLatency)) || 0; } catch (e) { lat = 0; } }
// 소스 노드 시작·정지 예약. 시작이 아직 안 된 것만 cancelPending 이 끊는다.
function startNode(n, t, stopT) {
  n.start(t); n.stop(stopT);
  pending.set(n, t);
  n.onended = () => pending.delete(n);
}
const pitch = (i) => PENTA[((i % 5) + 5) % 5] * Math.pow(2, Math.floor(i / 5));

// ---------- 소리 부품 ----------
function env(g, t, peak, attack, decay) {
  g.gain.setValueAtTime(0.0001, t);
  g.gain.linearRampToValueAtTime(peak, t + attack);
  g.gain.exponentialRampToValueAtTime(0.0001, t + attack + decay);
}
function tone(type, f0, f1, t, dur, peak, dest = master, attack = 0.004) {
  const o = ctx.createOscillator(), g = ctx.createGain();
  o.type = type;
  o.frequency.setValueAtTime(f0, t);
  if (f1 && f1 !== f0) o.frequency.exponentialRampToValueAtTime(f1, t + dur);
  env(g, t, peak, attack, dur);
  o.connect(g); g.connect(dest);
  startNode(o, t, t + attack + dur + 0.05);
  return o;
}
function noise(t, dur, peak, ftype, f0, q = 1, f1 = null, attack = 0.002) {
  const s = ctx.createBufferSource(), fl = ctx.createBiquadFilter(), g = ctx.createGain();
  s.buffer = noiseBuf;
  fl.type = ftype; fl.Q.value = q; fl.frequency.setValueAtTime(f0, t);
  if (f1) fl.frequency.exponentialRampToValueAtTime(f1, t + dur);
  env(g, t, peak, attack, dur);
  s.connect(fl); fl.connect(g); g.connect(master);
  s.start(t, Math.random() * 0.5); s.stop(t + attack + dur + 0.05);
  pending.set(s, t); s.onended = () => pending.delete(s);
}

const VOICES = {
  kung: (t, v) => { tone('sine', 92, 58, t, 0.38, 0.95 * v); noise(t, 0.03, 0.12 * v, 'lowpass', 300); },
  deok: (t, v) => { noise(t, 0.05, 0.55 * v, 'bandpass', 2000, 1.6); tone('triangle', 1700, 1200, t, 0.03, 0.08 * v); },
  deong: (t, v) => { VOICES.kung(t, v); VOICES.deok(t, v * 0.9); },
  roll: (t, v) => { for (let i = 0; i < 4; i++) VOICES.deok(t + i * 0.045, v * (0.5 + i * 0.1)); },
  bak: (t, v) => { noise(t, 0.07, 0.8 * v, 'bandpass', 1200, 3); tone('triangle', 900, 700, t, 0.04, 0.2 * v); },
  hit: (t, v) => { const f = pitch([0, 2, 4, 3, 1, 2][pluckN++ % 6] + 5); tone('triangle', f, f, t, 0.22, 0.28 * v, lp(2400)); },
  miss: (t, v) => { tone('sine', 78, 48, t, 0.16, 0.8 * v); noise(t, 0.07, 0.18 * v, 'lowpass', 500); },
  kneel: (t, v) => { [4, 2, 0].forEach((n, i) => tone('triangle', pitch(n + 5), pitch(n + 5), t + i * 0.2, 0.45, 0.3 * v, lp(2000))); },
  mask: (t, v) => {
    [0, 1, 2, 3, 4, 5, 7].forEach((n, i) => tone('triangle', pitch(n + 5), pitch(n + 5), t + i * 0.075, 0.5, 0.2 * v, lp(5000)));
    for (let i = 0; i < 6; i++) tone('sine', 2093 + i * 80, 2093 + i * 80, t + 0.5 + i * 0.05, 0.4, 0.04 * v);
  },
  step: (t, v) => { tone('sine', 170, 110, t, 0.07, 0.5 * v); noise(t, 0.03, 0.1 * v, 'lowpass', 700); },
  confirm: (t, v) => { tone('triangle', pitch(7), pitch(7), t, 0.16, 0.3 * v, lp(3000)); },
  flee: (t, v) => { noise(t, 0.6, 0.35 * v, 'bandpass', 400, 2.5, 2600, 0.15); },
};
function lp(freq) { const f = ctx.createBiquadFilter(); f.type = 'lowpass'; f.frequency.value = freq; f.connect(master); return f; }

function melodyNote(idx, t, dur) {
  const o = ctx.createOscillator(), f = ctx.createBiquadFilter(), g = ctx.createGain();
  const lfo = ctx.createOscillator(), lg = ctx.createGain();
  o.type = 'square'; o.frequency.value = pitch(idx);
  f.type = 'lowpass'; f.frequency.value = 1300; f.Q.value = 0.7;
  lfo.frequency.value = 5.5; lg.gain.value = 5; lfo.connect(lg); lg.connect(o.frequency);
  g.gain.setValueAtTime(0.0001, t);
  g.gain.linearRampToValueAtTime(0.07, t + 0.04);
  g.gain.setValueAtTime(0.07, t + dur * 0.7);
  g.gain.linearRampToValueAtTime(0.0001, t + dur);
  o.connect(f); f.connect(g); g.connect(master);
  startNode(o, t, t + dur + 0.02); startNode(lfo, t, t + dur + 0.02);
}

// ---------- 장단 ----------
function seg(beat) { let s = jd.segs[0]; for (const x of jd.segs) if (x.beat <= beat) s = x; return s; }
function tick() {
  if (!jd) return;
  try {
    const now = Audio.now();
    const horizon = now + LOOKAHEAD * (Audio.muted ? Math.max(1, speed) : 1);
    let guard = 2000;
    while (jd.pattern.length && guard--) {
      const ev = jd.pattern[jd.i];
      const t = Audio.timeAt(jd.bar * 4 + ev.beat);
      if (t > horizon) break;
      if (t >= now - 0.05) Audio.play(ev.name, t);
      if (++jd.i >= jd.pattern.length) { jd.i = 0; jd.bar++; }
    }
    while (jd.melody && jd.melody.length && guard--) {
      const t = Audio.timeAt(jd.mb);
      if (t > horizon) break;
      if (t >= now - 0.05 && useCtx()) {
        const dur = (Audio.timeAt(jd.mb + 1) - t) * 0.85;
        melodyNote(jd.melody[jd.mb % jd.melody.length], Math.max(ctx.currentTime, toRaw(t)), dur);
      }
      jd.mb++;
    }
  } catch (e) { /* 소리 실패가 게임을 멈추지 않게 */ }
}

export const Audio = {
  ready: false,
  muted: false,

  // 사용자 제스처(keydown·pointerup·touchend·click) 안에서 호출. 여러 번 불러도 안전.
  // ctx 가 running 이 아니면 매번 resume() 을 다시 부른다(대기 중인 promise 를 캐시하지 않는다).
  async init() {
    try {
      if (!ctx) {
        const AC = globalThis.AudioContext || globalThis.webkitAudioContext;
        if (!AC) return;
        ctx = new AC();
        master = ctx.createGain();
        master.gain.value = Audio.muted ? 0 : 0.6;
        master.connect(ctx.destination);
        noiseBuf = ctx.createBuffer(1, ctx.sampleRate, ctx.sampleRate);
        const d = noiseBuf.getChannelData(0);
        for (let i = 0; i < d.length; i++) d[i] = Math.random() * 2 - 1;
        ctx.onstatechange = () => rebase(() => { Audio.ready = ctx.state === 'running'; if (Audio.ready) sampleLat(); });
      }
      let ok = ctx.state === 'running';
      if (!ok && !paused) { try { await ctx.resume(); ok = true; } catch (e) { /* 자동재생 차단: 다음 제스처에서 다시 */ } }
      rebase(() => { Audio.ready = ctx.state === 'running' || ok; if (Audio.ready) sampleLat(); });
    } catch (e) { ctx = null; Audio.ready = false; }
  },

  now() { return srcT() + bias; },

  // 사용자 보정(초). 양수 = 판정 기준을 소리보다 늦춘다. 저장은 호출자 몫. 춤 밖에서 바꿀 것.
  get offset() { return userOff; },
  setOffset(sec) { userOff = Math.max(-0.5, Math.min(0.5, +sec || 0)); },
  get paused() { return paused; },

  // 탭 숨김·포커스 잃음: ctx 를 멈춰 currentTime 이 서게 하고 가짜 시계도 세운다.
  pause() {
    if (paused) return;
    rebase(() => { fakeBase = fakeT(); perfBase = perfNow(); frozen = true; paused = true; });
    try { if (ctx && ctx.state === 'running') ctx.suspend(); } catch (e) { /* 무시 */ }
  },
  resume() {
    if (!paused) return;
    const go = () => { if (!paused) return; rebase(() => { perfBase = perfNow(); frozen = false; paused = false; }); };
    // ctx 가 다시 돌기 시작한 뒤에 가짜 시계를 푼다(재개 도중 now() 가 앞서가지 않게)
    try {
      if (ctx && ctx.state !== 'running') ctx.resume().then(go, go); else go();
    } catch (e) { go(); }
  },

  // 아직 시작 전인 예약음을 모두 끊고 장단을 지운다(춤 장면 퇴장 때 카운트인이 다음 장면으로 새지 않게).
  cancelPending() {
    Audio.stopJangdan();
    if (!ctx) { pending.clear(); return; }
    const cur = ctx.currentTime;
    for (const [n, t] of [...pending]) {
      if (t > cur) { try { n.stop(); n.disconnect(); } catch (e) { /* 무시 */ } pending.delete(n); }
    }
  },

  setMuted(b) {
    rebase(() => { Audio.muted = !!b; });
    try { if (master) master.gain.value = Audio.muted ? 0 : 0.6; } catch (e) { /* 무시 */ }
  },
  setSpeed(k) {
    const before = Audio.now();
    fakeBase = fakeT(); perfBase = perfNow();
    speed = Math.max(0.1, +k || 1);
    bias += before - Audio.now();
  },

  play(name, at = Audio.now(), gain = 1) {
    try {
      if (!useCtx() || !VOICES[name]) return;
      VOICES[name](Math.max(ctx.currentTime, toRaw(at)), gain);
    } catch (e) { /* 무시 */ }
  },

  startJangdan({ bpm, startAt, pattern = [], melody = null }) {
    Audio.stopJangdan();
    if (ctx) rebase(sampleLat);
    jd = { segs: [{ beat: 0, time: startAt, bpm }], pattern, melody, i: 0, bar: 0, mb: 0, timer: setInterval(tick, TICK_MS) };
    tick();
  },
  stopJangdan() { if (jd) { clearInterval(jd.timer); jd = null; } },

  // atBeat 이후 템포를 바꾼다. 오름차순으로, 가능하면 0.2초 이상 앞서 불러야 예약된 소리와 어긋나지 않는다.
  setBpm(bpm, atBeat) {
    if (!jd) return;
    if (atBeat == null) atBeat = Math.ceil(Audio.beatAt(Audio.now()) + 0.5);
    const t = Audio.timeAt(atBeat);
    jd.segs = jd.segs.filter((s) => s.beat < atBeat);
    jd.segs.push({ beat: atBeat, time: t, bpm });
  },
  beatAt(time) {
    if (!jd) return 0;
    let s = jd.segs[0];
    for (const x of jd.segs) if (x.time <= time) s = x;
    return s.beat + (time - s.time) * s.bpm / 60;
  },
  timeAt(beat) {
    if (!jd) return 0;
    const s = seg(beat);
    return s.time + (beat - s.beat) * 60 / s.bpm;
  },
};
