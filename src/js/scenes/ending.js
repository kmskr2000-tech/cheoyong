// 엔딩: 탈이 걸린 새벽 거리, 처용가 여덟 구절, 마무리 대사, 끝
import { drawPaper, drawStreet, COLORS } from '../render/paper.js';
import { drawCheoyong, drawHouse } from '../render/puppet.js';
import { brushTitle, verticalText, dialogBox, FONT } from '../render/text.js';
import { STORY } from '../story.js';

const COUNT = 9, GAP = 190, LOOP = COUNT * GAP; // 탈 걸린 집 아홉 채가 돌며 흐른다
const SCROLL = 40;                               // px/s
const VERSE_START = 1.0, VERSE_EVERY = 3.0;
const CPS = 28;

let api, tt, last, lastC, phase, verseEnd, idx, chars, endT;

const stepDt = (now) => { const d = Math.min(0.25, Math.max(0, now - last)); last = now; return d; };
const clamp = (v, a, b) => Math.max(a, Math.min(b, v));

function showEnd() {
  phase = 'end'; endT = tt;
  api.G.reachedEnding = true;
  console.log('REACHED ENDING');
}

function confirm() {
  const now = api.Audio.now();
  if (now - lastC < 0.15) return;
  lastC = now;
  if (phase === 'talk') {
    const cur = STORY.ending[idx];
    if (chars < cur.text.length) { chars = cur.text.length; return; }
    api.Audio.play('confirm');
    idx++; chars = 0;
    if (idx >= STORY.ending.length) showEnd();
  } else if (phase === 'end' && tt - endT > 0.8) {
    api.Audio.play('confirm');
    api.setScene('title', {});
  }
}

export default {
  enter(params, a) {
    api = a;
    tt = 0; lastC = -9; phase = 'verses'; idx = 0; chars = 0; endT = 0;
    verseEnd = VERSE_START + VERSE_EVERY * STORY.verses.length;
    last = api.Audio.now();
    api.fx.clear();
  },
  exit() {},
  update(dt, now) {
    const d = stepDt(now);
    tt += d;
    if (phase === 'verses' && tt >= verseEnd) phase = 'talk';
    if (phase === 'talk') {
      const cur = STORY.ending[idx];
      if (cur && chars < cur.text.length) chars = Math.min(cur.text.length, chars + CPS * d);
    }
  },
  draw(ctx, now) {
    const W = 960, H = 540;
    drawPaper(ctx, W, H, tt, { moon: 0, lantern: null, redMoon: false });

    // 집 아홉 채가 왼쪽으로 흐른다
    const scroll = tt * SCROLL;
    const hs = [];
    for (let i = 0; i < COUNT; i++) {
      const x = ((((i * GAP - scroll) % LOOP) + LOOP) % LOOP) - 100;
      if (x > -120 && x < W + 120) hs.push({ x, w: 120 });
    }
    drawStreet(ctx, W, H, tt, { houses: hs, horizonY: 420 });
    hs.forEach((h) => drawHouse(ctx, h.x, 430, h.w, tt, { lit: true, haunted: false, masked: true, home: false }));

    // 새벽 빛
    const g = ctx.createLinearGradient(0, 0, 0, H);
    g.addColorStop(0, 'rgba(255,196,128,0.38)');
    g.addColorStop(0.6, 'rgba(255,170,100,0.14)');
    g.addColorStop(1, 'rgba(255,232,196,0)');
    ctx.fillStyle = g;
    ctx.fillRect(0, 0, W, H);

    // 걷는 처용
    const pose = Math.floor(tt / 0.3) % 2 === 0 ? 'step' : 'idle';
    drawCheoyong(ctx, 480, 490, 0.95, pose, tt, { phase: (tt / 0.3) % 1 });

    if (phase === 'verses') {
      const k = tt - VERSE_START;
      if (k >= 0) {
        const vi = Math.floor(k / VERSE_EVERY);
        if (vi < STORY.verses.length) {
          const local = k - vi * VERSE_EVERY;
          const a = Math.min(clamp(local / 0.7, 0, 1), clamp((VERSE_EVERY - local) / 0.6, 0, 1));
          ctx.save();
          ctx.globalAlpha = a;
          verticalText(ctx, STORY.verses[vi], 840, 60, 42, COLORS.black);
          ctx.restore();
          ctx.save();
          ctx.font = `18px ${FONT}`;
          ctx.textAlign = 'right';
          ctx.fillStyle = COLORS.black;
          ctx.globalAlpha = 0.5;
          ctx.fillText(`${vi + 1} / ${STORY.verses.length}`, 930, 520);
          ctx.restore();
        }
      }
    } else if (phase === 'talk') {
      const cur = STORY.ending[Math.min(idx, STORY.ending.length - 1)];
      const prog = cur.text.length ? Math.min(1, chars / cur.text.length) : 1;
      if (cur.who === STORY.names.cheoyong) drawCheoyong(ctx, 170, 410, 0.8, 'idle', tt, { phase: 0 });
      dialogBox(ctx, W, H, cur.who, cur.text, tt, { progress: prog });
    } else {
      const a = clamp((tt - endT) / 1.2, 0, 1);
      ctx.save();
      ctx.globalAlpha = a;
      brushTitle(ctx, '처용무 — 끝', 480, 250, 120, COLORS.black, { align: 'center', jitter: 1 });
      ctx.font = `18px ${FONT}`;
      ctx.textAlign = 'center';
      ctx.fillStyle = COLORS.black;
      ctx.globalAlpha = a * 0.6;
      ctx.fillText('Space — 처음으로', 480, 300);
      ctx.restore();
    }
  },
  onAction(name) {
    if (name === 'confirm') confirm();
    else if (name === 'back' && phase === 'verses') phase = 'talk';
  },
  onPointer(x, y, type) { if (type === 'down') confirm(); },
  debug() { return { phase, idx }; },
};
