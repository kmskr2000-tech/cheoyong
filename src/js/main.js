// 부트·캔버스 배율·루프·장면 전환·URL 훅.
import { Audio } from './audio.js';
import { Input } from './input.js';
import { Save } from './save.js';
import { SPIRITS } from './chart.js';
import { fx } from './render/fx.js';
import * as AP from './autopilot.js';
import title from './scenes/title.js';
import story from './scenes/story.js';
import night from './scenes/night.js';
import dance from './scenes/dance.js';
import result from './scenes/result.js';
import ending from './scenes/ending.js';

// 에러 수집(테스트가 읽음)
const errors = (window.__errors = window.__errors || []);
window.addEventListener('error', (e) => errors.push(String(e.message || e.error || 'error') + (e.filename ? ` @${e.filename}:${e.lineno}` : '')));
window.addEventListener('unhandledrejection', (e) => errors.push('unhandledrejection: ' + String((e.reason && e.reason.stack) || e.reason)));

const W = 960, H = 540;
const SCENES = { title, story, night, dance, result, ending };
const q = new URLSearchParams(location.search);

export const G = {
  scene: null, sceneName: '', params: q, save: null, night: null,
  reachedEnding: false, auto: false, muted: false, speed: 1, seed: 1,
};
window.G = G;
export function ctxSize() { return { w: W, h: H }; }

const canvas = document.getElementById('game');
const ctx = canvas.getContext('2d');
let k = 1;                                    // 논리 → 캔버스 픽셀 배율

// ---------- 배율·레터박스 ----------
function resize() {
  const s = Math.min(window.innerWidth / W, window.innerHeight / H);
  const cssW = Math.max(1, Math.floor(W * s)), cssH = Math.max(1, Math.floor(H * s));
  const dpr = Math.min(window.devicePixelRatio || 1, 2);
  canvas.style.width = cssW + 'px';
  canvas.style.height = cssH + 'px';
  canvas.width = Math.round(cssW * dpr);
  canvas.height = Math.round(cssH * dpr);
  k = canvas.width / W;
}
window.addEventListener('resize', resize);
window.addEventListener('orientationchange', () => setTimeout(resize, 150));
resize();

// ---------- 장면 ----------
const api = { setScene, G, Audio, Input, fx };
export function setScene(name, params = {}) {
  const next = SCENES[name];
  if (!next) throw new Error('알 수 없는 장면: ' + name);
  if (G.scene && G.scene.exit) G.scene.exit();
  G.scene = next;
  G.sceneName = name;
  Input.laneZone = name === 'dance';
  if (next.enter) next.enter(params, api);
}

// ---------- 입력 → 장면 ----------
Input.init(canvas, Audio);
Input.onLane((lane, at) => { const s = G.scene; if (s && s.onLane) s.onLane(lane, at); });
Input.onAction((name, at) => { const s = G.scene; if (s && s.onAction) s.onAction(name, at); });
Input.onPointer((x, y, type) => { const s = G.scene; if (s && s.onPointer) s.onPointer(x, y, type); });

// 첫 사용자 입력에서 오디오 시작(막히면 다음 입력에서 재시도)
const unlock = () => Audio.init().then(() => {
  if (Audio.ready) for (const ev of ['keydown', 'pointerdown', 'touchend', 'click']) window.removeEventListener(ev, unlock, true);
});
for (const ev of ['keydown', 'pointerdown', 'touchend', 'click']) window.addEventListener(ev, unlock, true);
// M: 소리 끄기/켜기
window.addEventListener('keydown', (e) => {
  if (e.code === 'KeyM' && !e.repeat) { Audio.setMuted(!Audio.muted); G.muted = Audio.muted; }
});

// ---------- 루프 ----------
let last = 0, drawn = false, AutoMod = null;
const dprGuard = () => { ctx.setTransform(k, 0, 0, k, 0, 0); ctx.globalAlpha = 1; ctx.globalCompositeOperation = 'source-over'; };
function drawMutedGlyph() {
  ctx.save();
  ctx.globalAlpha = 0.65;
  ctx.fillStyle = '#15110f'; ctx.beginPath(); ctx.arc(W - 22, 22, 13, 0, Math.PI * 2); ctx.fill();
  ctx.strokeStyle = ctx.fillStyle = '#f3e9d2'; ctx.lineWidth = 2;
  ctx.beginPath(); ctx.moveTo(W - 29, 19); ctx.lineTo(W - 25, 19); ctx.lineTo(W - 20, 15); ctx.lineTo(W - 20, 29); ctx.lineTo(W - 25, 25); ctx.lineTo(W - 29, 25); ctx.closePath(); ctx.fill();
  ctx.beginPath(); ctx.moveTo(W - 31, 30); ctx.lineTo(W - 13, 14); ctx.stroke();
  ctx.restore();
}
function frame(ts) {
  requestAnimationFrame(frame);
  const real = last ? (ts - last) / 1000 : 1 / 60;
  last = ts;
  const dt = Math.min(real, 0.05) * (Audio.muted ? G.speed : 1);   // 배속은 오디오 시계와 같은 비율로
  const now = Audio.now();
  const s = G.scene;
  if (AutoMod && AutoMod.update && G.auto) AutoMod.update(dt, now);
  if (s && s.update) s.update(dt, now);
  fx.update(dt);
  dprGuard();
  ctx.clearRect(0, 0, W, H);
  ctx.save();
  try {
    const cur = G.scene;
    if (cur && cur.draw) cur.draw(ctx, now);
    fx.draw(ctx);
    if (G.sceneName === 'dance') Input.drawTouchLanes(ctx, Input.activeLane);
    if (Audio.muted) drawMutedGlyph();
  } finally { ctx.restore(); }
  if (!drawn) { drawn = true; window.__ready = true; }
}

// ---------- 부트 ----------
// 장면이 main.js 를 import 해도(순환) 번들에서 연결이 끝난 뒤 시작하도록 마이크로태스크로 미룬다.
function boot() {
  G.save = Save.load();
  G.seed = parseInt(q.get('seed'), 10) || 1;
  G.auto = q.has('auto');
  if (q.has('mute')) Audio.setMuted(true);
  G.muted = Audio.muted;
  if (G.muted && q.has('speed')) {
    const sp = parseFloat(q.get('speed'));
    if (sp > 0) { G.speed = sp; Audio.setSpeed(sp); }
  }
  AutoMod = AP.Autopilot || AP.default;
  if (G.auto && AutoMod && AutoMod.attach) AutoMod.attach(G);

  function firstScene() {
    if (q.has('ending')) return ['ending', {}];
    const nightN = Math.min(5, Math.max(1, parseInt(q.get('night'), 10) || 1));
    if (q.get('dance')) {
      const spirit = SPIRITS.includes(q.get('dance')) ? q.get('dance') : 'fever';
      return ['dance', { spirit, houseIdx: 0, night: spirit === 'yeoksin' ? 5 : (q.has('night') ? nightN : 1), direct: true }];
    }
    if (q.has('night')) return ['night', { n: nightN, direct: true }];
    return ['title', {}];
  }
  { const [n, p] = firstScene(); setScene(n, p); }

  requestAnimationFrame(frame);
}

Promise.resolve().then(boot);
