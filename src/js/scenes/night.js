// 밤거리: 처용이 걷고, 역신 든 집 앞에서 춤을 시작한다
import { drawPaper, drawStreet, COLORS } from '../render/paper.js';
import { drawCheoyong, drawSpirit, drawHouse, drawMask } from '../render/puppet.js';
import { brushTitle, FONT } from '../render/text.js';
import { STORY } from '../story.js';

const SPEED = 260;              // 처용 걸음 px/s
const MINX = 60, MAXX = 900;
const HOUSE_Y = 430, CH_Y = 492, CH_SCALE = 0.85;
const NEAR = 40;                // 집 앞 판정 ±px

let api, G, N, cfg, held, target, autoStart, face, walkT, last, tt, leaving, rand, clearT;

const stepDt = (now) => { const d = Math.min(0.25, Math.max(0, now - last)); last = now; return d; };
const clamp = (v, a, b) => Math.max(a, Math.min(b, v));
const layout = (n) => (n === 1
  ? [{ x: 480, w: 300, home: true }]
  : Array.from({ length: n }, (_, i) => ({ x: Math.round(120 + (i * 720) / (n - 1)), w: 110, home: false })));

function mulberry(seed) {
  let a = seed >>> 0;
  return () => {
    a = (a + 0x6d2b79f5) >>> 0;
    let t = a;
    t = Math.imul(t ^ (t >>> 15), t | 1);
    t ^= t + Math.imul(t ^ (t >>> 7), t | 61);
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
}
const pick = (arr) => arr[Math.floor(rand() * arr.length)];

// N.spirits 를 집 상태에서 다시 만든다
function sync() {
  N.spirits = [];
  N.houses.forEach((h, i) => { if (h.haunted) N.spirits.push({ type: h.haunted, houseIdx: i }); });
}
const eligible = (i) => { const h = N.houses[i]; return !!h && !h.masked && !h.haunted && !h.home; };
const neighbours = (i) => [i - 1, i + 1].filter((j) => j >= 0 && j < N.houses.length);

function createNight(n) {
  cfg = STORY.nights[n - 1];
  rand = mulberry((G.seed | 0) + n * 7919);
  const houses = layout(cfg.houses).map((h) => ({ ...h, haunted: null, masked: false }));
  N = {
    n, houses, spirits: [], cheoyongX: 90, lastSpread: 0,
    cap: cfg.cap, spread: cfg.spread, types: cfg.spawn.slice(),
    deokLog: [], kneels: 0, fled: 0,
  };
  const idxs = houses.map((_, i) => i);
  cfg.spawn.forEach((type) => {
    const k = Math.floor(rand() * idxs.length);
    houses[idxs.splice(k, 1)[0]].haunted = type;
  });
  sync();
  G.night = N;
}

function spreadOnce() {
  const cand = [];
  N.houses.forEach((h, i) => {
    if (!eligible(i)) return;
    if (neighbours(i).some((j) => N.houses[j].haunted)) cand.push(i);
  });
  if (!cand.length) return;
  const i = pick(cand);
  N.houses[i].haunted = pick(N.types);
  sync();
  api.fx.ripple(N.houses[i].x, HOUSE_Y - 60);
}

function applyResult(res) {
  if (!res || N.houses[res.houseIdx] == null) return;
  const i = res.houseIdx;
  const h = N.houses[i];
  const type = h.haunted;
  if (!type) return;
  if (res.outcome === 'kneel') {
    h.masked = true; h.haunted = null; N.kneels++;
    api.fx.burst(h.x, HOUSE_Y - 110, 'mask');
    api.Audio.play('mask');
  } else if (res.outcome === 'flee') {
    N.fled++;
    N.lastSpread += 10; // 달아나게 두면 전파가 앞당겨진다
    h.haunted = null;
    const nb = neighbours(i).filter(eligible);
    let moved = i;
    if (nb.length) { moved = pick(nb); N.houses[moved].haunted = type; } else h.haunted = type; // 갈 곳 없으면 그대로
    sync();
    if (N.spirits.length < N.cap) {
      let cand = [];
      N.houses.forEach((hh, j) => {
        if (j === i || j === moved || !eligible(j)) return;
        if (neighbours(j).some((k) => N.houses[k].haunted)) cand.push(j);
      });
      if (!cand.length) cand = N.houses.map((_, j) => j).filter((j) => j !== i && j !== moved && eligible(j));
      if (cand.length) {
        const j = pick(cand);
        N.houses[j].haunted = pick(N.types);
        api.fx.ripple(N.houses[j].x, HOUSE_Y - 60);
      }
    }
  }
  sync();
}

// ±NEAR 안의 가장 가까운 역신 든 집 번호(없으면 -1)
function nearHaunted() {
  let best = -1, bd = NEAR + 0.01;
  N.houses.forEach((h, i) => {
    const d = Math.abs(h.x - N.cheoyongX);
    if (h.haunted && d <= bd) { best = i; bd = d; }
  });
  return best;
}

function startDance(i) {
  if (leaving || !N.houses[i] || !N.houses[i].haunted) return;
  leaving = true;
  api.Audio.play('confirm');
  api.setScene('dance', { spirit: N.houses[i].haunted, houseIdx: i });
}

export default {
  enter(params, a) {
    api = a; G = a.G;
    held = { left: false, right: false };
    target = null; autoStart = -1; face = 1; walkT = 0; tt = 0; leaving = false; clearT = 0;
    last = api.Audio.now();
    api.fx.clear();
    if (params.resume && G.night) {
      N = G.night;
      cfg = STORY.nights[N.n - 1];
      if (!rand) rand = mulberry((G.seed | 0) + N.n * 7919);
      applyResult(params.result); // lastSpread 는 춤을 다녀와도 이어서 쌓인다
    } else {
      createNight(params.n || 1);
    }
  },
  exit() { held = { left: false, right: false }; },
  update(dt, now) {
    const d = stepDt(now);
    tt += d;
    if (leaving) return;
    if (N.spirits.length === 0) { // 탈이 걸리는 장면을 잠깐 보여 준 뒤 결과로
      clearT += d;
      if (clearT > 1.3) { leaving = true; api.setScene('result', { n: N.n }); }
      return;
    }

    // 걷기
    let dir = (held.right ? 1 : 0) - (held.left ? 1 : 0);
    if (dir !== 0) { target = null; autoStart = -1; }
    let step = SPEED * d;
    if (dir === 0 && target != null) {
      const dx = target - N.cheoyongX;
      if (Math.abs(dx) <= 3) {
        N.cheoyongX = target; target = null;
        if (autoStart >= 0) { const i = autoStart; autoStart = -1; startDance(i); return; }
      } else { dir = Math.sign(dx); step = Math.min(step, Math.abs(dx)); }
    }
    if (dir !== 0) {
      N.cheoyongX = clamp(N.cheoyongX + dir * step, MINX, MAXX);
      face = dir; walkT += d;
    }

    // 전파
    if (N.spread > 0) {
      N.lastSpread += d;
      if (N.lastSpread >= N.spread) {
        N.lastSpread = 0;
        if (N.spirits.length < N.cap) spreadOnce();
      }
    }
  },
  draw(ctx, now) {
    const W = 960, H = 540;
    drawPaper(ctx, W, H, tt, { moon: 1, lantern: null, redMoon: !!cfg.redMoon });
    drawStreet(ctx, W, H, tt, { houses: N.houses.map((h) => ({ x: h.x, w: h.w })), horizonY: 420 });
    N.houses.forEach((h) => {
      drawHouse(ctx, h.x, HOUSE_Y, h.w, tt, { lit: true, haunted: !!h.haunted, masked: h.masked, home: h.home });
      if (h.haunted) drawSpirit(ctx, h.x, HOUSE_Y, h.home ? 0.95 : 0.75, h.haunted, 'lurk', tt, { phase: 0 });
    });

    // 처용 (왼쪽을 볼 땐 좌우 반전)
    const moving = (held.left !== held.right) || target != null;
    const pose = moving && Math.floor(walkT * 4) % 2 === 0 ? 'step' : 'idle';
    ctx.save();
    ctx.translate(N.cheoyongX, 0);
    ctx.scale(face, 1);
    drawCheoyong(ctx, 0, CH_Y, CH_SCALE, pose, tt, { phase: (walkT * 4) % 1 });
    ctx.restore();

    // 집 앞 안내
    const near = nearHaunted();
    if (near >= 0 && !leaving) {
      const touch = !!(api.Input && api.Input.touchMode);
      const label = (N.houses[near].home ? '노래한다' : '춤춘다') + ' — ' + (touch ? '탭' : '확인');
      const px = clamp(N.houses[near].x, 130, 830), py = 262;
      ctx.save();
      ctx.font = `26px ${FONT}`;
      const tw = ctx.measureText(label).width + 36;
      ctx.fillStyle = 'rgba(243,233,210,0.92)';
      ctx.strokeStyle = COLORS.black;
      ctx.lineWidth = 2;
      ctx.beginPath(); ctx.rect(px - tw / 2, py - 24, tw, 38); ctx.fill(); ctx.stroke();
      ctx.fillStyle = COLORS.red;
      ctx.textAlign = 'center';
      ctx.fillText(label, px, py + 5);
      ctx.restore();
    }


    // HUD
    brushTitle(ctx, `${cfg.title} · 남은 역신 ${N.spirits.length}`, 30, 48, 34, COLORS.black, { align: 'left' });
    const masks = N.houses.filter((h) => h.masked).length;
    drawMask(ctx, 880, 36, 30, tt, { glow: 0 });
    brushTitle(ctx, `${masks}`, 912, 48, 30, COLORS.black, { align: 'left' });

    if (N.n === 1) {
      const hint = STORY.tutorial[Math.floor(tt / 4) % STORY.tutorial.length];
      ctx.save();
      ctx.font = `20px ${FONT}`;
      ctx.textAlign = 'center';
      ctx.fillStyle = COLORS.black;
      ctx.globalAlpha = 0.75;
      ctx.fillText(hint, 480, 92);
      ctx.restore();
    }
  },
  onAction(name) {
    if (name === 'left') held.left = true;
    else if (name === 'right') held.right = true;
    else if (name === 'leftUp') held.left = false;
    else if (name === 'rightUp') held.right = false;
    else if (name === 'confirm') {
      const i = nearHaunted();
      if (i >= 0) startDance(i);
    }
  },
  onPointer(x, y, type) {
    if (type !== 'down' || leaving || y < 150) return;
    let hit = -1;
    N.houses.forEach((h, i) => { if (Math.abs(x - h.x) <= h.w / 2 + 10) hit = i; });
    if (hit >= 0) {
      const h = N.houses[hit];
      if (h.haunted && Math.abs(N.cheoyongX - h.x) <= NEAR) return startDance(hit);
      target = clamp(h.x, MINX, MAXX);
      autoStart = h.haunted ? hit : -1;
    } else {
      target = clamp(x, MINX, MAXX); autoStart = -1;
    }
  },
  debug() { return { night: G.night }; },
};
