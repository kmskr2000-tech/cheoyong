// 타이틀: 붓글씨 제목, 천천히 춤추는 처용 그림자, 메뉴
import { drawPaper, COLORS } from '../render/paper.js';
import { drawCheoyong, drawLantern, POSES } from '../render/puppet.js';
import { brushTitle, FONT } from '../render/text.js';
import { STORY } from '../story.js';
import { Save } from '../save.js';

const SEQ = ['idle', 'armL', 'step', 'spin', 'armR', 'bow'].filter((p) => POSES.includes(p));
const PERIOD = 1.6; // 포즈 하나당 초
const MENU_X = 770, MENU_Y = 350, MENU_DY = 66;

let api, items, sel, tt, last, lastC;

const ease = (x) => (x < 0.5 ? 2 * x * x : 1 - Math.pow(-2 * x + 2, 2) / 2);
const stepDt = (now) => { const d = Math.min(0.25, Math.max(0, now - last)); last = now; return d; };

function loadSave() {
  try { return Save.load() || { night: 1 }; } catch (e) { return { night: 1 }; }
}

function confirm() {
  const now = api.Audio.now();
  if (now - lastC < 0.15) return; // 탭이 확인 행동으로도 오는 경우의 중복 방지
  lastC = now;
  api.Audio.play('confirm');
  const it = items[sel];
  if (it.id === 'new') {
    api.G.night = null;
    api.setScene('story', { lines: STORY.nights[0].intro, night: 1, next: ['night', { n: 1 }] });
  } else {
    const n = it.night;
    api.setScene('story', { lines: STORY.nights[n - 1].intro, night: n, next: ['night', { n }] });
  }
}

export default {
  enter(params, a) {
    api = a;
    const s = loadSave();
    items = [{ id: 'new', label: '새로 시작' }];
    if (s.night > 1 && s.night <= STORY.nights.length) {
      items.push({ id: 'cont', label: '이어하기', night: s.night });
    }
    sel = 0; tt = 0; lastC = -9; last = api.Audio.now();
  },
  exit() {},
  update(dt, now) { tt += stepDt(now); },
  draw(ctx, now) {
    const W = 960, H = 540;
    drawPaper(ctx, W, H, tt, { moon: 1, lantern: { x: 96, y: 96, r: 260 }, redMoon: false });
    drawLantern(ctx, 96, 96, 56, tt);

    // 제목
    brushTitle(ctx, '처용무', 480, 190, 190, COLORS.black, { align: 'center', jitter: 1.2 });
    brushTitle(ctx, '밤의 문', 480, 262, 44, COLORS.red, { align: 'center' });

    // 느리게 춤추는 처용
    const k = tt / PERIOD;
    const i = Math.floor(k) % SEQ.length;
    drawCheoyong(ctx, 480, 500, 1.0, SEQ[i], tt, { phase: ease(k - Math.floor(k)) });

    // 메뉴
    items.forEach((it, j) => {
      const y = MENU_Y + j * MENU_DY;
      const on = j === sel;
      ctx.save();
      ctx.globalAlpha = on ? 1 : 0.55;
      if (on) {
        ctx.fillStyle = COLORS.red;
        ctx.beginPath(); ctx.arc(MENU_X - 100, y - 14, 6, 0, Math.PI * 2); ctx.fill();
      }
      brushTitle(ctx, it.label, MENU_X, y, on ? 50 : 42, on ? COLORS.red : COLORS.black, { align: 'center' });
      ctx.restore();
    });

    ctx.save();
    ctx.font = `16px ${FONT}`;
    ctx.textAlign = 'center';
    ctx.fillStyle = COLORS.black;
    ctx.globalAlpha = 0.65;
    ctx.fillText('조작: ←↓↑→ 춤사위 · Space 확인', 480, 526);
    ctx.restore();
  },
  onLane(lane) {
    if (lane === 1) sel = Math.min(items.length - 1, sel + 1); // ↓
    else if (lane === 2) sel = Math.max(0, sel - 1);           // ↑
  },
  onAction(name) {
    if (name === 'left') sel = Math.max(0, sel - 1);
    else if (name === 'right') sel = Math.min(items.length - 1, sel + 1);
    else if (name === 'confirm') confirm();
  },
  onPointer(x, y, type) {
    if (type !== 'down') return;
    items.forEach((it, j) => {
      if (Math.abs(x - MENU_X) < 120 && Math.abs(y - (MENU_Y + j * MENU_DY - 14)) < 32) sel = j;
    });
    confirm();
  },
  debug() { return { items, sel }; },
};
