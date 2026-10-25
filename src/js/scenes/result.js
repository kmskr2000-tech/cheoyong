// 결과: 한 밤의 요약 카드 → 저장 → 이야기(밤 마무리·다음 밤 소개)
import { drawPaper, COLORS } from '../render/paper.js';
import { drawMask } from '../render/puppet.js';
import { brushTitle, FONT } from '../render/text.js';
import { STORY } from '../story.js';
import { Save } from '../save.js';

const RANK = { '하': 0, '중': 1, '상': 2 };
let api, n, cfg, kneels, avg, grade, tt, last, fled;

const stepDt = (now) => { const d = Math.min(0.25, Math.max(0, now - last)); last = now; return d; };

function calc(N) {
  const log = (N && N.deokLog) || [];
  avg = log.length ? log.reduce((a, b) => a + b, 0) / log.length : 100;
  fled = (N && N.fled) || 0;
  kneels = N ? N.houses.filter((h) => h.masked).length : 0;
  grade = avg >= 70 && fled === 0 ? '상' : avg >= 40 ? '중' : '하';
}

function save(N) {
  let s;
  try { s = Save.load() || {}; } catch (e) { s = {}; }
  const masks = { ...(s.masks || {}) };
  if (N) masks[n] = N.houses.map((h, i) => (h.masked ? i : -1)).filter((i) => i >= 0);
  const best = { ...(s.best || {}) };
  if (best[n] == null || RANK[grade] > RANK[best[n]]) best[n] = grade;
  const cleared = n >= STORY.nights.length; // 마지막 밤을 넘기면 night 는 5 에 두고 cleared 표시
  const night = cleared ? STORY.nights.length : Math.max(s.night || 1, n + 1);
  try { Save.write({ night, cleared, masks, best }); } catch (e) { /* 저장 불가 */ }
}

function go() {
  const outro = cfg.outro;
  if (n >= STORY.nights.length) {
    api.setScene('story', { lines: outro, night: n, next: ['ending', {}] });
  } else {
    const nx = STORY.nights[n];
    api.setScene('story', {
      lines: outro, night: n,
      next: ['story', { lines: nx.intro, night: n + 1, next: ['night', { n: n + 1 }] }],
    });
  }
}

function proceed() {
  if (tt < 1.8) { tt = 1.8; return; } // 첫 확인은 카드를 끝까지 펼친다
  api.Audio.play('confirm');
  go();
}

export default {
  enter(params, a) {
    api = a;
    const N = a.G.night;
    n = params.n || (N && N.n) || 1;
    cfg = STORY.nights[n - 1];
    calc(N);
    save(N);
    tt = 0; last = api.Audio.now();
    api.Audio.play('mask');
  },
  exit() {},
  update(dt, now) { tt += stepDt(now); },
  draw(ctx, now) {
    const W = 960, H = 540;
    drawPaper(ctx, W, H, tt, { moon: 0, lantern: null, redMoon: false });
    // 카드
    ctx.save();
    ctx.fillStyle = 'rgba(243,233,210,0.93)';
    ctx.strokeStyle = COLORS.black;
    ctx.lineWidth = 4;
    ctx.beginPath(); ctx.rect(170, 60, 620, 420); ctx.fill(); ctx.stroke();
    ctx.lineWidth = 1.5;
    ctx.beginPath(); ctx.rect(182, 72, 596, 396); ctx.stroke();
    ctx.restore();

    const row = (k, y, fn) => { if (tt >= k) { ctx.save(); ctx.globalAlpha = Math.min(1, (tt - k) / 0.3); fn(); ctx.restore(); } };
    row(0.2, 0, () => brushTitle(ctx, `${cfg.title} 지남`, 480, 150, 68, COLORS.black, { align: 'center' }));
    row(0.2, 0, () => brushTitle(ctx, cfg.sub, 480, 192, 26, COLORS.red, { align: 'center' }));
    row(0.7, 0, () => {
      brushTitle(ctx, `굴복  ${kneels}`, 300, 270, 44, COLORS.black, { align: 'left' });
      for (let i = 0; i < Math.min(kneels, 7); i++) drawMask(ctx, 360 + i * 36, 306, 28, tt, { glow: 0 });
    });
    row(1.1, 0, () => brushTitle(ctx, `덕 평균  ${Math.round(avg)}`, 300, 360, 44, COLORS.black, { align: 'left' }));
    row(1.6, 0, () => {
      brushTitle(ctx, '등급', 600, 280, 36, COLORS.black, { align: 'center' });
      brushTitle(ctx, grade, 620, 400, 130, COLORS.red, { align: 'center', jitter: 1 });
    });
    if (tt > 1.8) {
      ctx.save();
      ctx.font = `18px ${FONT}`;
      ctx.textAlign = 'center';
      ctx.fillStyle = COLORS.black;
      ctx.globalAlpha = 0.6 + 0.3 * Math.sin(tt * 4);
      ctx.fillText('Space — 이야기로', 480, 452);
      ctx.restore();
    }
  },
  onAction(name) { if (name === 'confirm') proceed(); },
  onPointer(x, y, type) { if (type === 'up') proceed(); },
  debug() { return { n, kneels, avg, grade }; },
};
