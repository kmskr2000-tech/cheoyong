// 이야기 장면: 레터박스 대사, 타자 효과
import { drawPaper, drawStreet } from '../render/paper.js';
import { drawCheoyong, drawHouse } from '../render/puppet.js';
import { dialogBox } from '../render/text.js';
import { STORY } from '../story.js';

const CPS = 28; // 초당 글자 수
let api, lines, idx, chars, next, night, tt, last, done, houses;

const stepDt = (now) => { const d = Math.min(0.25, Math.max(0, now - last)); last = now; return d; };
const layout = (n) => (n === 1
  ? [{ x: 480, w: 300 }]
  : Array.from({ length: n }, (_, i) => ({ x: Math.round(120 + (i * 720) / (n - 1)), w: 110 })));

function finish() {
  if (done) return;
  done = true;
  api.setScene(...(next || ['title', {}]));
}

function skipAll() { idx = lines.length; finish(); }

function confirm() {
  const cur = lines[idx];
  if (!cur) return finish();
  if (chars < cur.text.length) { chars = cur.text.length; return; }
  api.Audio.play('confirm');
  idx++; chars = 0;
  if (idx >= lines.length) finish();
}

export default {
  enter(params, a) {
    api = a;
    lines = params.lines || [];
    next = params.next;
    night = params.night;
    idx = 0; chars = 0; tt = 0; done = false;
    last = api.Audio.now();
    houses = night ? layout(STORY.nights[night - 1].houses) : [];
  },
  exit() {},
  update(dt, now) {
    const d = stepDt(now);
    tt += d;
    if (!lines.length) return finish();
    const cur = lines[idx];
    if (cur && chars < cur.text.length) chars = Math.min(cur.text.length, chars + CPS * d);
  },
  draw(ctx, now) {
    const W = 960, H = 540;
    const red = night ? STORY.nights[night - 1].redMoon : false;
    drawPaper(ctx, W, H, tt, { moon: 1, lantern: null, redMoon: red });
    drawStreet(ctx, W, H, tt, { houses, horizonY: 420 });
    houses.forEach((h) => drawHouse(ctx, h.x, 430, h.w, tt, { lit: true, haunted: false, masked: false, home: night === 5 }));
    const cur = lines[Math.min(idx, lines.length - 1)];
    if (!cur) return;
    if (cur.who === STORY.names.cheoyong) drawCheoyong(ctx, 170, 410, 0.8, 'idle', tt, { phase: 0 });
    const prog = cur.text.length ? Math.min(1, chars / cur.text.length) : 1;
    dialogBox(ctx, W, H, cur.who, cur.text, tt, { progress: prog });
  },
  onAction(name) {
    if (name === 'confirm') confirm();
    else if (name === 'back') skipAll();
  },
  onPointer(x, y, type) { if (type === 'up') confirm(); },
  debug() { return { idx, total: lines.length }; },
};
