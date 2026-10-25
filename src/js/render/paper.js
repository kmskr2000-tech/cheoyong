// 한지 배경 · 등불 역광 · 달 · 거리 실루엣. 전부 순수 그리기(상태 없음).
// 무거운 부분(결·얼룩·비네트)은 오프스크린에 한 번만 구워 두고 매 프레임 drawImage 로 쓴다.

export const COLORS = {
  blue: '#1f4e79', red: '#b5342c', yellow: '#d9a441', white: '#f3e9d2', black: '#15110f',
  paper: '#e8d9b5', shadow: '#1a1410', lantern: '#f0b25a', miasma: '#5b3a7a',
};

const clamp = (v, a, b) => (v < a ? a : v > b ? b : v);

function mkCanvas(w, h) {
  if (typeof document !== 'undefined') { const c = document.createElement('canvas'); c.width = w; c.height = h; return c; }
  return new OffscreenCanvas(w, h);
}
function rng(seed) { // mulberry32
  return () => {
    seed |= 0; seed = (seed + 0x6D2B79F5) | 0;
    let t = Math.imul(seed ^ (seed >>> 15), 1 | seed);
    t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t;
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
}

// ── 캐시: 해상도(w,h,배율)·달 상태별로 한 번만 굽는다 ────────────────────
// base = 한지 + 역광 + 달 + 비네트(불투명, 한 번 blit), spot = 천천히 떠다니는 빛무리
const cache = new Map();
function layers(w, h, k, moonQ, red) {
  const key = `${w}x${h}@${k}|${moonQ}${red ? 'r' : ''}`;
  let L = cache.get(key);
  if (!L) { L = bake(w, h, k, moonQ, red); cache.set(key, L); }
  return L;
}

function bake(w, h, k, moonQ, red) {
  const W = Math.round(w * k), H = Math.round(h * k);
  const R = rng(20261020);
  const base = mkCanvas(W, H), b = base.getContext('2d');
  // 바탕색
  b.fillStyle = '#d6c398'; b.fillRect(0, 0, W, H);
  // 큰 얼룩(닥종이 두께 차이)
  for (let i = 0; i < 70; i++) {
    const x = R() * W, y = R() * H, r = (40 + R() * 160) * k;
    const g = b.createRadialGradient(x, y, 0, x, y, r);
    const warm = R() < 0.5;
    g.addColorStop(0, warm ? 'rgba(170,125,60,0.07)' : 'rgba(255,248,225,0.09)');
    g.addColorStop(1, 'rgba(0,0,0,0)');
    b.fillStyle = g; b.fillRect(x - r, y - r, r * 2, r * 2);
  }
  // 고운 알갱이 노이즈
  const id = b.getImageData(0, 0, W, H), d = id.data;
  for (let i = 0; i < d.length; i += 4) {
    const n = (R() - 0.5) * 22;
    d[i] += n; d[i + 1] += n * 0.95; d[i + 2] += n * 0.85;
  }
  b.putImageData(id, 0, 0);
  // 닥 섬유: 짧고 가는 곡선 다수 + 드물게 긴 가닥
  b.lineCap = 'round';
  const fibres = Math.round(2800 * (W * H) / (960 * 540));
  for (let i = 0; i < fibres; i++) {
    const long = R() < 0.03;
    const len = (long ? 60 + R() * 90 : 6 + R() * 30) * k;
    const x = R() * W, y = R() * H, a = R() * Math.PI * 2, bend = (R() - 0.5) * len * 0.6;
    const light = R() < 0.55;
    b.strokeStyle = light ? `rgba(255,250,232,${0.12 + R() * 0.18})` : `rgba(110,78,40,${0.06 + R() * 0.11})`;
    b.lineWidth = (long ? 0.7 + R() * 0.7 : 0.4 + R() * 0.6) * k;
    const ex = x + Math.cos(a) * len, ey = y + Math.sin(a) * len;
    b.beginPath(); b.moveTo(x, y);
    b.quadraticCurveTo((x + ex) / 2 - Math.sin(a) * bend, (y + ey) / 2 + Math.cos(a) * bend, ex, ey);
    b.stroke();
  }
  // 역광(중심이 밝고 가장자리로 갈수록 투명)
  const cx = W / 2, cy = H * 0.47, gr = Math.max(W, H) * 0.62;
  const gg = b.createRadialGradient(cx, cy, 0, cx, cy, gr);
  gg.addColorStop(0, 'rgba(255,240,196,0.97)'); gg.addColorStop(0.35, 'rgba(250,224,156,0.66)');
  gg.addColorStop(0.72, 'rgba(238,196,120,0.19)'); gg.addColorStop(1, 'rgba(230,180,100,0)');
  b.fillStyle = gg; b.fillRect(0, 0, W, H);
  if (red) { b.fillStyle = 'rgba(150,40,28,0.17)'; b.fillRect(0, 0, W, H); }
  // 달: 지평선 위, 오른쪽
  if (moonQ > 0) drawMoon(b, W * 0.8, H * 0.17, Math.min(W, H) * 0.058, moonQ / 4, red);
  // 비네트(가장자리 그을음)
  const rad = Math.hypot(W, H) * 0.56;
  const v = b.createRadialGradient(cx, cy, rad * 0.22, cx, cy, rad);
  v.addColorStop(0, 'rgba(40,22,8,0)'); v.addColorStop(0.55, 'rgba(46,26,10,0.10)');
  v.addColorStop(0.85, 'rgba(40,20,8,0.42)'); v.addColorStop(1, 'rgba(30,14,4,0.66)');
  b.fillStyle = v; b.fillRect(0, 0, W, H);
  const tb = b.createLinearGradient(0, 0, 0, H);
  tb.addColorStop(0, 'rgba(30,14,4,0.22)'); tb.addColorStop(0.1, 'rgba(30,14,4,0)');
  tb.addColorStop(0.9, 'rgba(30,14,4,0)'); tb.addColorStop(1, 'rgba(30,14,4,0.28)');
  b.fillStyle = tb; b.fillRect(0, 0, W, H);

  // 떠다니는 빛무리(작은 영역만 blit)
  const sw = Math.round(W * 0.42), sh = Math.round(H * 0.5);
  const spot = mkCanvas(sw, sh), g = spot.getContext('2d');
  const sg = g.createRadialGradient(sw / 2, sh / 2, 0, sw / 2, sh / 2, sw / 2);
  sg.addColorStop(0, 'rgba(255,238,190,0.30)'); sg.addColorStop(1, 'rgba(255,238,190,0)');
  g.fillStyle = sg; g.fillRect(0, 0, sw, sh);
  return { base, spot, sw, sh, lan: new Map() };
}

function lanternSprite(L, r) { // 등불 위치에 얹는 작은 광원 스프라이트
  const rr = Math.max(8, Math.round(r / 8) * 8);
  let s = L.lan.get(rr);
  if (!s) {
    s = mkCanvas(rr * 2, rr * 2);
    const g = s.getContext('2d'), gr = g.createRadialGradient(rr, rr, 0, rr, rr, rr);
    gr.addColorStop(0, 'rgba(255,226,150,0.85)'); gr.addColorStop(0.4, 'rgba(250,200,120,0.38)');
    gr.addColorStop(1, 'rgba(240,178,90,0)');
    g.fillStyle = gr; g.fillRect(0, 0, rr * 2, rr * 2);
    L.lan.set(rr, s);
  }
  return { s, rr };
}

// 역광 깜박임: 약 0.4초 주기 ±3% + 느린 표류
function flicker(t) {
  return 1 + 0.018 * Math.sin(t * 15.7) + 0.009 * Math.sin(t * 9.3 + 1.3)
    + 0.012 * Math.sin(t * 2.1) + 0.008 * Math.sin(t * 0.6 + 2);
}

export function drawPaper(ctx, w, h, t, { moon = 1, lantern = null, redMoon = false } = {}) {
  const m = ctx.getTransform ? ctx.getTransform().a : 1;
  const k = clamp(Math.round(m), 1, 2);
  const L = layers(w, h, k, Math.round(clamp(moon, 0, 1) * 4), redMoon);
  const f = flicker(t);
  ctx.save();
  ctx.globalAlpha = 1;
  ctx.drawImage(L.base, 0, 0, w, h);
  // 빛무리가 천천히 떠다닌다(정수 좌표로 옮겨 빠른 blit 경로 유지)
  const sw = L.sw / k, sh = L.sh / k;
  ctx.globalAlpha = clamp(0.85 + 0.15 * Math.sin(t * 0.7), 0, 1);
  ctx.drawImage(L.spot, Math.round(w * 0.5 - sw / 2 + Math.sin(t * 0.37) * w * 0.12), Math.round(h * 0.47 - sh / 2 + Math.cos(t * 0.29) * h * 0.06), sw, sh);
  if (lantern) {
    const { s, rr } = lanternSprite(L, lantern.r);
    ctx.globalAlpha = clamp(f * f, 0, 1);
    ctx.drawImage(s, lantern.x - lantern.r, lantern.y - lantern.r, lantern.r * 2, lantern.r * 2);
  }
  // 깜박임: ±3% 밝기(어두운 막의 농도를 흔든다)
  ctx.globalAlpha = 1;
  ctx.fillStyle = `rgba(36,18,4,${clamp(0.032 - (f - 1) * 1.0, 0, 0.08).toFixed(3)})`;
  ctx.fillRect(0, 0, w, h);
  ctx.restore();
}

function drawMoon(ctx, x, y, r, a, red) {
  ctx.save();
  const halo = ctx.createRadialGradient(x, y, r * 0.8, x, y, r * 4);
  halo.addColorStop(0, red ? 'rgba(190,60,40,0.30)' : 'rgba(255,252,232,0.42)');
  halo.addColorStop(1, 'rgba(255,250,230,0)');
  ctx.globalAlpha = a; ctx.fillStyle = halo;
  ctx.fillRect(x - r * 4.2, y - r * 4.2, r * 8.4, r * 8.4);
  ctx.beginPath(); ctx.arc(x, y, r, 0, Math.PI * 2);
  ctx.fillStyle = red ? 'rgba(186,58,44,0.86)' : 'rgba(255,252,238,0.80)'; ctx.fill();
  // 달 무늬(옅은 얼룩)
  ctx.fillStyle = red ? 'rgba(110,26,20,0.28)' : 'rgba(200,176,130,0.30)';
  for (const [dx, dy, rr] of [[-0.3, -0.2, 0.28], [0.28, 0.18, 0.22], [-0.05, 0.4, 0.15]]) {
    ctx.beginPath(); ctx.arc(x + dx * r, y + dy * r, rr * r, 0, Math.PI * 2); ctx.fill();
  }
  ctx.lineWidth = 1.2; ctx.strokeStyle = red ? 'rgba(90,20,14,0.45)' : 'rgba(150,120,70,0.35)';
  ctx.beginPath(); ctx.arc(x, y, r, 0, Math.PI * 2); ctx.stroke();
  ctx.restore();
}

// ── 거리: 먼 산 · 안개 · 땅 · 담장 ───────────────────────────────────
// 집의 발밑 y = horizonY. 집 자체는 puppet.drawHouse 로 그린다.
function ridge(ctx, w, base, amp, f1, p1, color, step = 8) {
  ctx.beginPath(); ctx.moveTo(0, base + 4);
  for (let x = 0; x <= w + step; x += step) {
    const u = x * f1;
    const y = base - amp * (0.52 * Math.pow(Math.abs(Math.sin(u + p1)), 0.8)
      + 0.30 * Math.sin(u * 2.3 + p1 * 2.1) * 0.5 + 0.30 + 0.18 * Math.sin(u * 5.1 + p1));
    ctx.lineTo(x, y);
  }
  ctx.lineTo(w + step, base + 4); ctx.closePath();
  ctx.fillStyle = color; ctx.fill();
}

// 구운 부분(산·안개·땅)은 집 위치와 무관해 한 번만 굽는다. 집 옆 담장 토막은 매 프레임 단색으로 직접 그린다
// (집 x 가 매 프레임 바뀌는 스크롤 장면에서도 캔버스를 새로 만들지 않는다).
export function drawStreet(ctx, w, h, t, { houses = [], horizonY = h * 0.72 } = {}) {
  const m = ctx.getTransform ? ctx.getTransform().a : 1, k = clamp(Math.round(m), 1, 2);
  const key = `${w}x${h}@${k}|${horizonY}`;
  let S = streetCache.get(key);
  if (!S) { if (streetCache.size > 8) streetCache.clear(); S = bakeStreet(w, h, k, horizonY); streetCache.set(key, S); }
  ctx.drawImage(S.back, 0, S.y0, w, S.y1 - S.y0);
  if (houses.length) drawWalls(ctx, w, horizonY, houses);
  ctx.drawImage(S.front, 0, S.y2, w, h - S.y2);
  // 흐르는 안개 띠(움직이는 것만 실시간)
  ctx.save(); ctx.fillStyle = 'rgba(255,244,214,0.09)';
  for (let i = 0; i < 3; i++) {
    const mx = ((t * (4 + i * 2) + i * 330) % (w + 400)) - 200;
    ctx.beginPath(); ctx.ellipse(mx, horizonY - 38 - i * 13, 190, 6 + i * 2, 0, 0, Math.PI * 2); ctx.fill();
  }
  ctx.restore();
}
const streetCache = new Map();

// 담장(집 사이 · 양끝). 블러 없는 단색 채우기만.
const WALL_H = 30, WALL_REACH = 240;
function wallSeg(ctx, horizonY, a, b) {
  if (b - a < 6) return;
  ctx.beginPath();
  ctx.rect(a, horizonY - WALL_H, b - a, WALL_H + 6);
  ctx.rect(a - 3, horizonY - WALL_H - 6, b - a + 6, 7);
  for (let x = a; x < b; x += 9) { ctx.moveTo(x + 4.5, horizonY - WALL_H + 1); ctx.arc(x + 4.5, horizonY - WALL_H + 1, 4.2, 0, Math.PI * 2); }
  ctx.fill();
}
function wallMarks(ctx, horizonY, a, b) {
  if (b - a < 6) return;
  for (let x = a + 12; x < b - 6; x += 22) {
    ctx.fillRect(x, horizonY - WALL_H * 0.55, 8, 2); ctx.fillRect(x + 8, horizonY - WALL_H * 0.22, 8, 2);
  }
}
// 집 사이는 메우고, 너무 먼 빈 터는 집 쪽 토막만 세운다. fn(a, b)로 토막마다 호출.
function eachWall(houses, w, fn) {
  let sorted = true;
  for (let i = 1; i < houses.length; i++) if (houses[i].x < houses[i - 1].x) { sorted = false; break; }
  const hs = sorted ? houses : [...houses].sort((a, b) => a.x - b.x);
  const gap = (a, b, edgeL, edgeR) => {
    if (b - a <= WALL_REACH * 2.1 && !edgeL && !edgeR) fn(a, b);
    else { if (!edgeL) fn(a, Math.min(b, a + WALL_REACH)); if (!edgeR) fn(Math.max(a, b - WALL_REACH), b); }
  };
  let cur = -10;
  for (let i = 0; i < hs.length; i++) { gap(cur, hs[i].x - hs[i].w * 0.5, i === 0, false); cur = hs[i].x + hs[i].w * 0.5; }
  gap(cur, w + 10, false, true);
}
function drawWalls(ctx, w, horizonY, houses) {
  ctx.save();
  ctx.fillStyle = COLORS.shadow; ctx.globalAlpha = 0.93;
  eachWall(houses, w, (a, b) => wallSeg(ctx, horizonY, a, b));
  ctx.globalAlpha = 1; ctx.fillStyle = 'rgba(240,178,90,0.10)'; // 담장 흙벽 무늬
  eachWall(houses, w, (a, b) => wallMarks(ctx, horizonY, a, b));
  ctx.restore();
}

// 뒤층(산·안개)과 앞층(땅·길)을 따로 구워 그 사이에 담장을 낀다.
function bakeStreet(w, h, k, horizonY) {
  const y0 = Math.max(0, Math.floor(horizonY - h * 0.34));
  const y1 = Math.min(h, Math.ceil(horizonY + 8));
  const y2 = Math.max(0, Math.floor(horizonY - 4));
  const back = mkCanvas(Math.round(w * k), Math.round((y1 - y0) * k)), bc = back.getContext('2d');
  bc.scale(k, k); bc.translate(0, -y0);
  // 먼 산 두 겹 + 안개
  ridge(bc, w, horizonY - 6, h * 0.20, 0.0062, 0.7, 'rgba(70,48,30,0.10)');
  ridge(bc, w, horizonY - 2, h * 0.12, 0.0095, 2.4, 'rgba(60,40,26,0.17)');
  const mist = bc.createLinearGradient(0, horizonY - h * 0.12, 0, horizonY + 4);
  mist.addColorStop(0, 'rgba(250,236,200,0)'); mist.addColorStop(1, 'rgba(250,236,200,0.34)');
  bc.fillStyle = mist; bc.fillRect(0, horizonY - h * 0.12, w, h * 0.12 + 4);
  // 땅: 지평선 아래를 먹빛으로
  const front = mkCanvas(Math.round(w * k), Math.round((h - y2) * k)), ctx = front.getContext('2d');
  ctx.scale(k, k); ctx.translate(0, -y2);
  const gnd = ctx.createLinearGradient(0, horizonY, 0, h);
  gnd.addColorStop(0, 'rgba(26,20,16,0.62)'); gnd.addColorStop(0.35, 'rgba(26,20,16,0.80)'); gnd.addColorStop(1, 'rgba(22,16,12,0.94)');
  ctx.fillStyle = gnd;
  ctx.beginPath(); ctx.moveTo(0, h);
  for (let x = 0; x <= w + 12; x += 12) ctx.lineTo(x, horizonY + 1.6 * Math.sin(x * 0.045) + 0.9 * Math.sin(x * 0.13 + 1));
  ctx.lineTo(w + 12, h); ctx.closePath(); ctx.fill();
  const road = ctx.createLinearGradient(0, horizonY, 0, h); // 길 위의 옅은 등불빛
  road.addColorStop(0, 'rgba(240,178,90,0.0)'); road.addColorStop(0.3, 'rgba(240,178,90,0.10)'); road.addColorStop(1, 'rgba(240,178,90,0.0)');
  ctx.fillStyle = road; ctx.fillRect(0, horizonY, w, h - horizonY);
  return { back, front, y0, y1, y2 };
}
