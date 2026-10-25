// 그림자 인형: 처용 · 역신 · 집 · 탈 · 등불 · 흉 음표. 전부 순수 그리기(상태 없음, t 는 초).
// 실루엣은 한 경로(path)에 모아 한 번에 채운다(방향을 통일해 겹쳐도 구멍이 안 난다).
import { COLORS } from './paper.js';

const TAU = Math.PI * 2, D2R = Math.PI / 180;
const clamp = (v, a, b) => (v < a ? a : v > b ? b : v);
const lerp = (a, b, k) => a + (b - a) * k;
const sstep = (k) => { k = clamp(k, 0, 1); return k * k * (3 - 2 * k); };
const hash = (n) => { const s = Math.sin(n * 127.1 + 311.7) * 43758.5453; return s - Math.floor(s); };

// ── 경로 도우미 ───────────────────────────────────────────────────────
function area(p) { let s = 0; for (let i = 0, n = p.length; i < n; i++) { const a = p[i], b = p[(i + 1) % n]; s += a[0] * b[1] - b[0] * a[1]; } return s; }
function poly(ctx, p) { // 항상 같은 방향(화면 시계방향)으로 추가
  if (p.rib) { // 띠는 마디마다 사각형으로: 꺾이는 곳에서 가장자리가 꼬여도 구멍이 안 난다
    const [A, B] = p.rib;
    for (let i = 0; i + 1 < A.length; i++) poly(ctx, [A[i], A[i + 1], B[i + 1], B[i]]);
    return;
  }
  const n = p.length; if (n < 3) return;
  if (area(p) >= 0) { ctx.moveTo(p[0][0], p[0][1]); for (let i = 1; i < n; i++) ctx.lineTo(p[i][0], p[i][1]); }
  else { ctx.moveTo(p[n - 1][0], p[n - 1][1]); for (let i = n - 2; i >= 0; i--) ctx.lineTo(p[i][0], p[i][1]); }
  ctx.closePath();
}
function circ(ctx, x, y, r) { ctx.moveTo(x + r, y); ctx.arc(x, y, r, 0, TAU); ctx.closePath(); }
function ell(ctx, x, y, rx, ry, rot = 0) { ctx.moveTo(x + Math.cos(rot) * rx, y + Math.sin(rot) * rx); ctx.ellipse(x, y, rx, ry, rot, 0, TAU); ctx.closePath(); }
function capsule(ctx, a, b, ra, rb) { // 두 점 사이 굵기가 변하는 막대
  const dx = b[0] - a[0], dy = b[1] - a[1], l = Math.hypot(dx, dy) || 1, nx = -dy / l, ny = dx / l, p = [];
  p.push([a[0] + nx * ra, a[1] + ny * ra], [b[0] + nx * rb, b[1] + ny * rb]);
  const ang = Math.atan2(dy, dx);
  for (let i = 1; i < 5; i++) { const q = ang + Math.PI / 2 - Math.PI * i / 5; p.push([b[0] + Math.cos(q) * rb, b[1] + Math.sin(q) * rb]); }
  p.push([b[0] - nx * rb, b[1] - ny * rb], [a[0] - nx * ra, a[1] - ny * ra]);
  for (let i = 1; i < 5; i++) { const q = ang - Math.PI / 2 - Math.PI * i / 5; p.push([a[0] + Math.cos(q) * ra, a[1] + Math.sin(q) * ra]); }
  poly(ctx, p);
}
function catmull(pts, closed = true, n = 5) { // 부드러운 폐곡선 샘플링
  const out = [], m = pts.length;
  const g = (i) => pts[closed ? (i + m) % m : clamp(i, 0, m - 1)];
  const segs = closed ? m : m - 1;
  for (let i = 0; i < segs; i++) {
    const p0 = g(i - 1), p1 = g(i), p2 = g(i + 1), p3 = g(i + 2);
    for (let j = 0; j < n; j++) {
      const s = j / n, s2 = s * s, s3 = s2 * s;
      out.push([
        0.5 * (2 * p1[0] + (-p0[0] + p2[0]) * s + (2 * p0[0] - 5 * p1[0] + 4 * p2[0] - p3[0]) * s2 + (-p0[0] + 3 * p1[0] - 3 * p2[0] + p3[0]) * s3),
        0.5 * (2 * p1[1] + (-p0[1] + p2[1]) * s + (2 * p0[1] - 5 * p1[1] + 4 * p2[1] - p3[1]) * s2 + (-p0[1] + 3 * p1[1] - 3 * p2[1] + p3[1]) * s3)]);
    }
  }
  if (!closed) out.push(pts[m - 1]);
  return out;
}
function quad(out, a, c, b, n = 6) { for (let i = 1; i <= n; i++) { const s = i / n, r = 1 - s; out.push([r * r * a[0] + 2 * r * s * c[0] + s * s * b[0], r * r * a[1] + 2 * r * s * c[1] + s * s * b[1]]); } }
function ribbon(pts, wf) { // 중심선 → 폭이 변하는 띠 다각형. wf(i,n) = 반폭
  // 급하게 꺾이는 곳에서는 반폭을 줄여(천이 접히듯) 가장자리가 꼬여 구멍이 나는 일을 막는다.
  const n = pts.length, L = [], R = [];
  for (let i = 0; i < n; i++) {
    const a = pts[Math.max(0, i - 1)], b = pts[Math.min(n - 1, i + 1)];
    const dx = b[0] - a[0], dy = b[1] - a[1], l = Math.hypot(dx, dy) || 1, nx = -dy / l, ny = dx / l;
    let w = wf(i, n);
    if (i > 0 && i < n - 1) {
      const x1 = pts[i][0] - a[0], y1 = pts[i][1] - a[1], x2 = b[0] - pts[i][0], y2 = b[1] - pts[i][1];
      const ang = Math.abs(Math.atan2(x1 * y2 - y1 * x2, x1 * x2 + y1 * y2));
      if (ang > 0.02) w = Math.min(w, 0.8 * Math.min(Math.hypot(x1, y1), Math.hypot(x2, y2)) / ang);
    }
    L.push([pts[i][0] + nx * w, pts[i][1] + ny * w]); R.push([pts[i][0] - nx * w, pts[i][1] - ny * w]);
  }
  return L.concat(R.reverse());
}
function rot(x, y, a) { const c = Math.cos(a), s = Math.sin(a); return [x * c - y * s, x * s + y * c]; }
const dirv = (a) => [Math.sin(a), Math.cos(a)]; // 아래(0)에서 +x 쪽으로 a 라디안

function soft(ctx, blur) { ctx.fillStyle = COLORS.shadow; ctx.shadowColor = COLORS.shadow; ctx.shadowBlur = blur; }
function perfFill(ctx) { ctx.fillStyle = 'rgba(255,214,140,0.62)'; } // 오려낸 구멍으로 새는 불빛

// ══════════════════════════════════════════════════════════════════
// 처용탈 — 유일한 온색. size = 얼굴 너비(px), (x,y) = 얼굴 중심
// ══════════════════════════════════════════════════════════════════
export function drawMask(ctx, x, y, size, t, { glow = 0 } = {}) {
  const u = size / 2;
  ctx.save();
  ctx.translate(x, y);
  if (glow > 0) { // 문에 걸린 탈: 살랑 흔들리고 후광이 있다
    ctx.rotate(Math.sin(t * 1.6) * 0.035 * glow);
    const g = ctx.createRadialGradient(0, 0, u * 0.4, 0, 0, u * 2.2);
    g.addColorStop(0, `rgba(255,214,130,${0.55 * glow})`); g.addColorStop(1, 'rgba(240,178,90,0)');
    ctx.fillStyle = g; ctx.fillRect(-u * 2.3, -u * 2.3, u * 4.6, u * 4.6);
  }
  const big = size >= 46, mid = size >= 26;
  const SK = '#a63f2a', SKH = '#c9593a', SKD = '#7e2a1c', INK = '#120c0a', TEETH = '#f6efdc', GOLD = '#e0a92f';
  // 귀 + 금귀고리
  for (const s of [-1, 1]) {
    ctx.fillStyle = SKD; ctx.beginPath(); ctx.ellipse(s * u * 1.02, u * 0.05, u * 0.2, u * 0.34, 0, 0, TAU); ctx.fill();
    ctx.strokeStyle = GOLD; ctx.lineWidth = Math.max(1.2, u * 0.11);
    ctx.beginPath(); ctx.arc(s * u * 1.06, u * 0.52, u * 0.15, 0, TAU); ctx.stroke();
    ctx.fillStyle = GOLD; ctx.beginPath(); ctx.arc(s * u * 1.06, u * 0.7, u * 0.09, 0, TAU); ctx.fill();
  }
  // 얼굴: 위가 좁고 볼이 넓은 네모 둥근 모양
  const face = [];
  for (let i = 0; i < 40; i++) {
    const a = (i / 40) * TAU, c = Math.cos(a), s = Math.sin(a);
    const px = Math.sign(c) * Math.pow(Math.abs(c), 0.8), py = Math.sign(s) * Math.pow(Math.abs(s), 0.85);
    const wide = 1 + 0.07 * Math.max(0, s) - 0.05 * Math.max(0, -s);
    face.push([px * u * wide, py * u * 1.06]);
  }
  const fg = ctx.createRadialGradient(-u * 0.25, -u * 0.35, u * 0.1, 0, 0, u * 1.25);
  fg.addColorStop(0, SKH); fg.addColorStop(0.65, SK); fg.addColorStop(1, SKD);
  ctx.fillStyle = fg; ctx.beginPath(); poly(ctx, face); ctx.fill();
  ctx.lineWidth = Math.max(1, u * 0.07); ctx.strokeStyle = INK; ctx.globalAlpha = 0.75; ctx.stroke(); ctx.globalAlpha = 1;
  // 둥근 볼
  for (const s of [-1, 1]) {
    const cg = ctx.createRadialGradient(s * u * 0.55, u * 0.26, 0, s * u * 0.55, u * 0.26, u * 0.38);
    cg.addColorStop(0, '#e0775a'); cg.addColorStop(1, 'rgba(224,119,90,0)');
    ctx.fillStyle = cg; ctx.beginPath(); ctx.arc(s * u * 0.55, u * 0.26, u * 0.38, 0, TAU); ctx.fill();
  }
  // 코
  ctx.fillStyle = SKD; ctx.beginPath(); ctx.ellipse(0, u * 0.12, u * 0.17, u * 0.22, 0, 0, TAU); ctx.fill();
  ctx.fillStyle = SKH; ctx.beginPath(); ctx.ellipse(-u * 0.04, u * 0.04, u * 0.07, u * 0.1, 0, 0, TAU); ctx.fill();
  if (big) { ctx.fillStyle = INK; for (const s of [-1, 1]) { ctx.beginPath(); ctx.ellipse(s * u * 0.09, u * 0.26, u * 0.045, u * 0.03, 0, 0, TAU); ctx.fill(); } }
  // 눈(작고 가늘게) + 눈빛
  for (const s of [-1, 1]) {
    ctx.fillStyle = INK; ctx.beginPath(); ctx.ellipse(s * u * 0.42, -u * 0.12, u * 0.2, u * 0.085, s * -0.12, 0, TAU); ctx.fill();
    if (mid) { ctx.fillStyle = TEETH; ctx.beginPath(); ctx.arc(s * u * 0.42 + u * 0.05, -u * 0.13, u * 0.035, 0, TAU); ctx.fill(); }
  }
  // 굵은 검은 눈썹: 안쪽이 낮고 바깥이 올라가는 호
  for (const s of [-1, 1]) {
    const pts = [[s * u * 0.12, -u * 0.22], [s * u * 0.36, -u * 0.46], [s * u * 0.66, -u * 0.5], [s * u * 0.84, -u * 0.3]];
    ctx.fillStyle = INK; ctx.beginPath(); poly(ctx, ribbon(catmull(pts, false, 5), (i, n) => u * (0.07 + 0.12 * Math.sin(Math.PI * (0.15 + 0.8 * i / (n - 1)))))); ctx.fill();
  }
  // 콧수염(큰 크기만) + 웃는 입 + 흰 이
  if (big) {
    for (const s of [-1, 1]) {
      ctx.fillStyle = INK; ctx.beginPath();
      poly(ctx, ribbon(catmull([[s * u * 0.06, u * 0.4], [s * u * 0.3, u * 0.43], [s * u * 0.55, u * 0.38], [s * u * 0.66, u * 0.46]], false, 4), (i, n) => u * 0.065 * (1 - i / n * 0.8)));
      ctx.fill();
    }
  }
  const my = u * 0.58;
  ctx.fillStyle = '#3a1210'; ctx.beginPath();
  ctx.moveTo(-u * 0.5, my - u * 0.04); ctx.quadraticCurveTo(0, my + u * 0.1, u * 0.5, my - u * 0.04);
  ctx.quadraticCurveTo(0, my + u * 0.5, -u * 0.5, my - u * 0.04); ctx.fill();
  ctx.save();
  ctx.beginPath(); ctx.moveTo(-u * 0.5, my - u * 0.04); ctx.quadraticCurveTo(0, my + u * 0.1, u * 0.5, my - u * 0.04);
  ctx.quadraticCurveTo(0, my + u * 0.5, -u * 0.5, my - u * 0.04); ctx.clip();
  ctx.fillStyle = TEETH;
  const nt = mid ? 6 : 4, tw = (u * 1.0) / nt;
  for (let i = 0; i < nt; i++) ctx.fillRect(-u * 0.5 + i * tw + tw * 0.06, my - u * 0.06, tw * 0.88, u * 0.26);
  ctx.restore();
  // 관의 꽃: 이마 위 띠 + 모란 · 복숭아꽃
  ctx.fillStyle = '#2a1812'; ctx.beginPath(); ctx.ellipse(0, -u * 0.98, u * 0.78, u * 0.17, 0, Math.PI, TAU); ctx.fill();
  if (mid) { ctx.fillStyle = GOLD; for (let i = -2; i <= 2; i++) { ctx.beginPath(); ctx.arc(i * u * 0.3, -u * 0.99 + Math.abs(i) * u * 0.02, u * 0.045, 0, TAU); ctx.fill(); } }
  flower(ctx, -u * 0.5, -u * 1.08, u * 0.3, '#f2a6b0', '#e8697a', '#f0c24a'); // 복숭아
  flower(ctx, u * 0.52, -u * 1.08, u * 0.3, '#f2a6b0', '#e8697a', '#f0c24a');
  peony(ctx, 0, -u * 1.16, u * 0.4);
  ctx.restore();
}
function flower(ctx, x, y, r, c1, c2, cc) { // 다섯 잎 꽃
  ctx.fillStyle = c1;
  for (let i = 0; i < 5; i++) { const a = (i / 5) * TAU - Math.PI / 2; ctx.beginPath(); ctx.arc(x + Math.cos(a) * r * 0.58, y + Math.sin(a) * r * 0.58, r * 0.46, 0, TAU); ctx.fill(); }
  ctx.fillStyle = c2; ctx.beginPath(); ctx.arc(x, y, r * 0.3, 0, TAU); ctx.fill();
  ctx.fillStyle = cc; ctx.beginPath(); ctx.arc(x, y, r * 0.14, 0, TAU); ctx.fill();
}
function peony(ctx, x, y, r) { // 모란: 겹꽃잎
  ctx.fillStyle = '#b8283e';
  for (let i = 0; i < 7; i++) { const a = (i / 7) * TAU; ctx.beginPath(); ctx.arc(x + Math.cos(a) * r * 0.62, y + Math.sin(a) * r * 0.62, r * 0.44, 0, TAU); ctx.fill(); }
  ctx.fillStyle = '#d9475a'; ctx.beginPath(); ctx.arc(x, y, r * 0.62, 0, TAU); ctx.fill();
  ctx.fillStyle = '#ee7f8e'; ctx.beginPath(); ctx.arc(x - r * 0.08, y - r * 0.06, r * 0.36, 0, TAU); ctx.fill();
  ctx.fillStyle = '#f0c24a'; ctx.beginPath(); ctx.arc(x, y, r * 0.15, 0, TAU); ctx.fill();
}

// ══════════════════════════════════════════════════════════════════
// 등불 — 종이 등. (x,y) = 등 몸통 중심
// ══════════════════════════════════════════════════════════════════
export function drawLantern(ctx, x, y, size, t) {
  const f = 1 + 0.07 * Math.sin(t * 13.1) + 0.05 * Math.sin(t * 7.7 + 1);
  ctx.save(); ctx.translate(x, y - size * 0.55);
  ctx.rotate(Math.sin(t * 1.1) * 0.04);
  ctx.translate(0, size * 0.55);
  const h = ctx.createRadialGradient(0, 0, size * 0.1, 0, 0, size * 2.4);
  h.addColorStop(0, `rgba(255,214,130,${0.5 * f})`); h.addColorStop(1, 'rgba(240,178,90,0)');
  ctx.fillStyle = h; ctx.fillRect(-size * 2.4, -size * 2.4, size * 4.8, size * 4.8);
  // 줄
  ctx.strokeStyle = COLORS.shadow; ctx.lineWidth = Math.max(1, size * 0.04);
  ctx.beginPath(); ctx.moveTo(0, -size * 1.6); ctx.lineTo(0, -size * 0.5); ctx.stroke();
  // 몸통(종이)
  const g = ctx.createRadialGradient(0, -size * 0.04, size * 0.04, 0, 0, size * 0.5);
  g.addColorStop(0, '#fff0c0'); g.addColorStop(0.55, '#f6c46c'); g.addColorStop(1, '#d9873a');
  ctx.fillStyle = g; ctx.beginPath(); ctx.ellipse(0, 0, size * 0.34, size * 0.45, 0, 0, TAU); ctx.fill();
  // 살대
  ctx.strokeStyle = 'rgba(40,20,10,0.7)'; ctx.lineWidth = Math.max(0.8, size * 0.03);
  for (const k of [-0.55, 0, 0.55]) { ctx.beginPath(); ctx.ellipse(0, 0, size * 0.34 * Math.abs(k) + 0.01, size * 0.45, 0, -Math.PI / 2, Math.PI / 2); ctx.stroke(); }
  for (const yy of [-0.2, 0.2]) { ctx.beginPath(); ctx.ellipse(0, size * yy, size * 0.34 * Math.sqrt(1 - (yy / 0.45) ** 2), size * 0.04, 0, 0, TAU); ctx.stroke(); }
  // 위·아래 마구리 + 술
  soft(ctx, 0); ctx.shadowBlur = 0;
  ctx.fillRect(-size * 0.16, -size * 0.5, size * 0.32, size * 0.08);
  ctx.fillRect(-size * 0.16, size * 0.43, size * 0.32, size * 0.08);
  ctx.strokeStyle = COLORS.red; ctx.lineWidth = Math.max(1, size * 0.04);
  for (const k of [-0.1, 0, 0.1]) { ctx.beginPath(); ctx.moveTo(k * size, size * 0.5); ctx.lineTo(k * size * 1.6 + Math.sin(t * 2 + k * 9) * size * 0.04, size * 0.88); ctx.stroke(); }
  ctx.restore();
}

// ══════════════════════════════════════════════════════════════════
// 흉(凶) 음표 — 레인별 오방색. 먹 바탕 위에 붓 고리 + 레인 기호
// ══════════════════════════════════════════════════════════════════
const LANE_COL = [COLORS.blue, COLORS.yellow, COLORS.white, COLORS.red];
const LANE_INK = [false, true, true, false]; // 먹 바탕(true) / 한지색 바탕(false)
function brushStroke(ctx, pts, w0, w1) { // 굵다가 가늘어지는 붓획
  ctx.beginPath(); poly(ctx, ribbon(pts, (i, n) => { const k = i / (n - 1); return lerp(w0, w1, k) * (k > 0.88 ? 1 - (k - 0.88) * 6 : 1) + 0.15; })); ctx.fill();
}
export function drawNote(ctx, x, y, lane, size, t, { pair = false, alpha = 1 } = {}) {
  const R = size / 2, col = LANE_COL[lane & 3], inkBg = LANE_INK[lane & 3];
  ctx.save(); ctx.globalAlpha = alpha; ctx.translate(x, y);
  if (pair) { // 짝 음표: 오른쪽으로 가는 얇은 끈 토막
    ctx.strokeStyle = COLORS.shadow; ctx.lineWidth = Math.max(1.3, size * 0.06); ctx.lineCap = 'round';
    ctx.beginPath(); ctx.moveTo(R * 0.8, 0); ctx.quadraticCurveTo(R * 1.5, -size * 0.12, R * 2.3, 0); ctx.stroke();
    ctx.fillStyle = col; ctx.strokeStyle = COLORS.shadow; ctx.lineWidth = Math.max(1, size * 0.04);
    ctx.beginPath(); ctx.arc(R * 2.35, 0, size * 0.075, 0, TAU); ctx.fill(); ctx.stroke();
  }
  // 바탕 원판
  ctx.shadowColor = 'rgba(26,20,16,0.55)'; ctx.shadowBlur = size * 0.12;
  ctx.fillStyle = inkBg ? COLORS.black : '#efe2c0'; ctx.beginPath(); ctx.arc(0, 0, R * 0.9, 0, TAU); ctx.fill();
  ctx.shadowBlur = 0;
  // 붓 고리: 시작이 굵고 끝이 가는 열린 원, 천천히 돈다
  const a0 = t * 1.3 + lane * 1.7, sweep = TAU * 0.93, n = 26, ring = [], ringO = [];
  const rr = R * 0.76;
  for (let i = 0; i <= n; i++) {
    const k = i / n, a = a0 + k * sweep, th = size * lerp(0.19, 0.05, k * k) * (0.9 + 0.2 * hash(i + lane * 7));
    ring.push([Math.cos(a) * (rr + th / 2), Math.sin(a) * (rr + th / 2)]);
    ringO.push([Math.cos(a) * (rr - th / 2), Math.sin(a) * (rr - th / 2)]);
  }
  const band = ring.concat(ringO.reverse());
  ctx.fillStyle = COLORS.black; ctx.globalAlpha = alpha * (inkBg ? 0 : 0.9);
  ctx.beginPath(); ctx.arc(0, 0, R * 0.98, 0, TAU); ctx.arc(0, 0, R * 0.9, 0, TAU, true); ctx.fill();
  ctx.globalAlpha = alpha; ctx.fillStyle = col; ctx.beginPath(); poly(ctx, band); ctx.fill();
  // 기호
  ctx.fillStyle = col; const q = R * 0.62;
  if (lane === 0 || lane === 3) { // 소매: 왼/오른쪽으로 휘는 획 + 끝자락
    const s = lane === 0 ? -1 : 1;
    const pts = catmull([[-s * 0.1 * q, -0.9 * q], [s * 0.32 * q, -0.45 * q], [s * 0.45 * q, 0.15 * q], [s * 0.15 * q, 0.7 * q], [-s * 0.4 * q, 0.92 * q]], false, 5);
    brushStroke(ctx, pts, q * 0.3, q * 0.06);
    brushStroke(ctx, catmull([[-s * 0.35 * q, -0.45 * q], [-s * 0.05 * q, -0.2 * q], [-s * 0.1 * q, 0.2 * q]], false, 4), q * 0.17, q * 0.04); // 소맷자락 결
  } else if (lane === 1) { // 발: 발바닥 + 발가락
    ctx.beginPath(); ell(ctx, 0.04 * q, 0.28 * q, q * 0.34, q * 0.5, -0.12); ctx.fill();
    ctx.beginPath();
    [[-0.34, -0.5, 0.13], [-0.1, -0.68, 0.12], [0.16, -0.68, 0.11], [0.38, -0.5, 0.1]].forEach(([a, b, r]) => circ(ctx, a * q, b * q, r * q));
    ctx.fill();
  } else { // 돌기: 소용돌이
    const sp = [];
    for (let i = 0; i <= 26; i++) { const k = i / 26, a = k * 2.6 * TAU - 1.2; sp.push([Math.cos(a) * (0.08 + 0.78 * k) * q, Math.sin(a) * (0.08 + 0.78 * k) * q]); }
    brushStroke(ctx, sp, q * 0.1, q * 0.2);
  }
  ctx.restore();
}

// ══════════════════════════════════════════════════════════════════
// 처용 — 관절 인형. 발밑 (x,y), scale 1 = 키 약 220px, 화면 오른쪽(역신 쪽)을 향한다.
// 팔 각도는 "세계 기준, 아래=0, 바깥=+" (L 은 화면 왼쪽으로, R 은 오른쪽으로 벌어짐)
// ══════════════════════════════════════════════════════════════════
export const POSES = ['idle', 'armL', 'step', 'spin', 'armR', 'bow', 'sing'];

const IDLE = {
  lean: 0, bob: 0, hipX: 0, head: 0, lift: 0, torsoW: 1,
  aL: 24, bL: 12, aR: 24, bR: 12,
  hL: -4, kL: 3, hR: 4, kR: 3,
  sagL: 0.9, sagR: 0.9, strL: 0, strR: 0, rpL: 0.6, rpR: 0.6,
};
const POSE = {
  idle: {},
  armL: { lean: -5, bob: 1, hipX: -3, head: -6, aL: 116, bL: -10, aR: 22, bR: 8, hL: -9, kL: 8, hR: 7, kR: 5, sagL: 0.1, strL: 0.5, rpL: 1.0 },
  armR: { lean: 5, bob: 1, hipX: 3, head: 6, aR: 116, bR: -10, aL: 22, bL: 8, hR: 9, kR: 8, hL: -7, kL: 5, sagR: 0.1, strR: 0.5, rpR: 1.0 },
  step: { lean: 3, hipX: -5, head: 3, aL: 44, bL: 22, aR: 58, bR: 16, hL: -5, kL: 7, hR: 74, kR: 96, sagL: 0.3, sagR: 0.25, strL: 0.1, strR: 0.15, rpL: 0.6, rpR: 0.6 },
  spin: { bob: -3, aL: 100, bL: -8, aR: 100, bR: -8, hL: -5, kL: 6, hR: 8, kR: 10, sagL: 0.1, sagR: 0.1, strL: 0.3, strR: 0.3, rpL: 1, rpR: 1 },
  bow: { lean: 56, bob: 2, hipX: -11, head: 12, torsoW: 0.5, aL: 6, bL: 6, aR: 4, bR: 4, hL: -2, kL: 14, hR: 22, kR: 36, sagL: 1, sagR: 1, rpL: 0.25, rpR: 0.25 },
  sing: { lean: -6, head: -11, lift: 3, aL: 124, bL: 16, aR: 124, bR: 16, hL: -11, kL: 5, hR: 11, kR: 5, sagL: 0.02, sagR: 0.02, strL: 0.45, strR: 0.45, rpL: 0.9, rpR: 0.9 },
};

function solve(pose, t, ph, hold) {
  const P = POSE[pose] || POSE.idle;
  const e = hold ? 1 : sstep(Math.sin(Math.PI * ph) * 1.35); // 0→1→0 포즈 포락선
  const J = {};
  for (const k in IDLE) J[k] = lerp(IDLE[k], P[k] !== undefined ? P[k] : IDLE[k], e);
  // 호흡(모든 포즈에 약하게)
  const br = Math.sin(t * 2.1), sw = Math.sin(t * 1.3);
  J.bob += br * 1.4 * (1 - e * 0.5); J.lean += sw * 1.3 * (1 - e * 0.6); J.head += Math.sin(t * 1.1 + 1) * 1.6 * (1 - e * 0.5);
  J.aL += Math.sin(t * 1.7) * 2.5; J.aR += Math.sin(t * 1.7 + 1.4) * 2.5;
  // 포즈 안의 움직임
  const pr = hold && pose === 'spin' ? (t * 0.9) % 1 : ph, s2 = hold ? Math.sin(t * 2.4) : Math.sin(TAU * ph);
  J.prog = pr; J.env = e;
  J.rise = hold ? 0 : (ph < 0.5 ? 1 - e : 0); J.fall = hold ? 0 : (ph >= 0.5 ? 1 - e : 0);
  if (pose === 'armL') { J.aL += 12 * s2; J.bL += 14 * s2; }
  if (pose === 'armR') { J.aR += 12 * s2; J.bR += 14 * s2; }
  if (pose === 'step') J.bob += 3.5 * Math.exp(-Math.pow(((hold ? (t * 1.1) % 1 : ph) - 0.9) / 0.05, 2));
  if (pose === 'spin') { J.bob -= 4 * Math.sin(Math.PI * pr); J.sx = Math.cos(TAU * pr); }
  if (pose === 'sing') { J.aL += 6 * Math.sin(t * 3.4); J.aR += 6 * Math.sin(t * 3.4 + 1.1); J.lift += 1.2 * Math.sin(t * 2.6); J.bL += 5 * Math.sin(t * 3.4 + 0.5); J.bR += 5 * Math.sin(t * 3.4 + 1.6); }
  if (pose === 'bow') J.bob += 1.5 * Math.sin(Math.PI * ph);
  return J;
}

// 한삼(긴 소매): 손목에서 시작하는 띠. sag=처짐(1=중력 따라 늘어짐), str=늘어남, rp=물결 세기
function sleeve(wx, wy, ang, sag, str, rp, t, seed, curl = 0) {
  const N = 16, seg = (128 * (1 + str * 0.6)) / N, pts = [[wx, wy]];
  const u0 = dirv(ang);
  let x = wx, y = wy;
  for (let i = 1; i <= N; i++) {
    const k = i / N, b = clamp(sag * sstep(k * 1.1), 0, 1);
    let dx = u0[0] * (1 - b), dy = u0[1] * (1 - b) + b;
    const l = Math.hypot(dx, dy);
    if (l < 0.3) { dx = u0[0] * 0.3 + 0.01; dy = 0.9; } else { dx /= l; dy /= l; }
    const r = rp * (0.12 + 0.95 * k) * Math.sin(t * 5.2 - i * 0.66 + seed) + curl * k;
    const c = Math.cos(r), s = Math.sin(r), ex = dx * c - dy * s, ey = dx * s + dy * c;
    x += ex * seg; y += ey * seg;
    if (y > -1.5) y = -1.5 + (y + 1.5) * 0.12; // 땅에 끌린다
    pts.push([x, y]);
  }
  return pts;
}

export function drawCheoyong(ctx, x, y, scale, pose, t, { phase, mask = true } = {}) {
  const hold = phase === undefined; // 계약과 다름: phase 생략 시 포즈를 끝까지 취한 채 유지
  const ph = hold ? 0.5 : clamp(phase, 0, 1);
  const J = solve(pose, t, ph, hold);
  const lean = J.lean * D2R, tw = J.torsoW;
  const sx = J.sx === undefined ? 1 : J.sx, proj = J.sx === undefined ? 1 : 0.3 + 0.7 * Math.abs(sx);
  const fine = scale >= 0.55;

  // ── 다리 FK ──
  const hipX = J.hipX;
  const leg = (s, hAng, kAng) => {
    const a1 = hAng * D2R, a2 = a1 - kAng * D2R, ox = s * 11;
    const d1 = dirv(a1), d2 = dirv(a2);
    return { ox, a1, a2, v: 36 * d1[1] + 32 * d2[1], k: [ox + 36 * d1[0], 36 * d1[1]], a: [ox + 36 * d1[0] + 32 * d2[0], 36 * d1[1] + 32 * d2[1]] };
  };
  const LL = leg(-1, J.hL, J.kL), LR = leg(1, J.hR, J.kR);
  const hipY = -10 - Math.max(LL.v, LR.v) + J.bob;
  const H = [hipX, hipY];
  const W = (p) => [H[0] + p[0], H[1] + p[1]]; // 다리는 몸 기울기와 무관
  const T = (px, py) => { const r = rot(px * tw, py, lean); return [H[0] + r[0], H[1] + r[1]]; }; // 몸통

  ctx.save();
  ctx.translate(x, y); ctx.scale(scale, scale);
  if (proj !== 1) { ctx.translate(hipX, 0); ctx.scale(proj, 1); ctx.translate(-hipX, 0); }
  ctx.beginPath();

  // 다리 + 신발
  const shoes = [];
  for (const [s, Lg] of [[-1, LL], [1, LR]]) {
    const kn = W(Lg.k), an = W(Lg.a);
    capsule(ctx, kn, an, 6, 4.6);
    const c = Math.cos(Lg.a2), sn = Math.sin(Lg.a2);
    const fx = [s * c, -s * sn], fy = [sn, c]; // 발 좌표축(앞=바깥)
    const fp = (a, b) => [an[0] + fx[0] * a + fy[0] * b, an[1] + fx[1] * a + fy[1] * b];
    poly(ctx, [fp(-7, -10), fp(-7, 3), fp(-3, 9), fp(13, 9), fp(22, 6), fp(27, 0), fp(29, -6), fp(24, -3), fp(16, 0), fp(8, -3), fp(4, -10)]); // 코가 들린 신
    shoes.push(an);
  }

  // 치마(넓은 관복 자락): 허리 → 무릎 → 발목 위 밑단
  const flare = 31 * (1 + (J.sx === undefined ? 0 : 0.22 * (1 - Math.abs(sx))));
  const wL = T(-26, -6), wR = T(26, -6);
  const kL = W(LL.k), kR = W(LR.k), aL2 = W(LL.a), aR2 = W(LR.a);
  const hL = [aL2[0] - flare, aL2[1] - 7 - Math.max(0, -LL.a[1] - 70) * 0.35], hR = [aR2[0] + flare, aR2[1] - 7 - Math.max(0, 72 - LR.a[1] - 0) * 0.0 - Math.max(0, 66 - LR.a[1]) * 0.35];
  const sk = [wL];
  quad(sk, wL, [kL[0] - 23, kL[1] - 8], hL, 7);
  for (let i = 1; i <= 6; i++) { const k = i / 7; sk.push([lerp(hL[0], hR[0], k), lerp(hL[1], hR[1], k) + 2.8 * Math.sin(k * Math.PI * 4) + 2]); }
  sk.push(hR);
  const up = [hR]; quad(up, hR, [kR[0] + 23, kR[1] - 8], wR, 7);
  poly(ctx, sk.concat(up.slice(1)));

  // 몸통(두루마기 상체) + 목
  const tor = catmull([T(-8, -62), T(-27, -57), T(-31, -46), T(-27, -30), T(-23, -12), T(-24, -3), T(24, -3), T(23, -12), T(27, -30), T(31, -46), T(27, -57), T(8, -62)], true, 4);
  poly(ctx, tor);
  // 허리띠 자락
  const sash = T(0, -12);
  poly(ctx, [[sash[0] - 4, sash[1]], [sash[0] + 4, sash[1]], [sash[0] + 6 + Math.sin(t * 2) * 1.5, sash[1] + 34], [sash[0] - 2, sash[1] + 38]]);

  // 팔 + 한삼
  const sleeves = [], perf = [];
  const arm = (s, aDeg, bDeg, sag, str, rp) => {
    const a = aDeg * D2R, b = bDeg * D2R;
    const sh = T(s * 26, -52);
    const d1 = [s * Math.sin(a), Math.cos(a)], d2 = [s * Math.sin(a + b), Math.cos(a + b)];
    const el = [sh[0] + d1[0] * 30, sh[1] + d1[1] * 30], wr = [el[0] + d2[0] * 28, el[1] + d2[1] * 28];
    circ(ctx, sh[0], sh[1], 8.5);
    capsule(ctx, sh, el, 7.4, 6.4); capsule(ctx, el, wr, 6.4, 9.6);
    // 한삼 방향각(아래=0, +x 쪽 +): 팔의 세계 방향
    const ang = Math.atan2(d2[0], d2[1]);
    const curl = J.sx === undefined ? 0 : s * 0.6 * (1 - Math.abs(sx));
    let sg = sag + (J.fall || 0) * 0.5 + (J.rise || 0) * 0.15;
    const pts = sleeve(wr[0], wr[1], ang, clamp(sg, 0, 1), str, rp * (1 + 0.5 * (J.fall || 0)), t, s * 1.9, curl);
    if (J.sx !== undefined) for (const p of pts) p[0] = lerp(wr[0], p[0], 0.55 + 0.45 * Math.abs(sx)); // 돌 때는 몸에 감긴다
    sleeves.push(pts); perf.push(sh, el);
  };
  arm(-1, J.aL, J.bL, J.sagL, J.strL, J.rpL);
  arm(1, J.aR, J.bR, J.sagR, J.strR, J.rpR);
  for (const sp of sleeves) {
    const pts = catmull(sp, false, 3);
    poly(ctx, ribbon(pts, (i, n) => { const k = i / (n - 1); return (lerp(5.6, 12, sstep(k * 1.5)) + 1.0 * Math.sin(i * 0.45 + t * 3.2)) * (k > 0.94 ? 1 - (k - 0.94) * 9 : 1) + 0.4; }));
  }

  // 머리는 굳은 한 덩이라 따로 구워 둔 스프라이트를 회전해 붙인다(아래). 목만 몸 경로에 넣는다.
  const hd = lean * 0.65 + J.head * D2R, N = T(0, -62 - J.lift * 0.3);
  const hr = rot(0, -J.lift * 0.5, hd), HO = [N[0] + hr[0], N[1] + hr[1]];
  const Hh = (px, py) => { const r = rot(px, py, hd); return [HO[0] + r[0], HO[1] + r[1]]; };
  capsule(ctx, T(0, -52), Hh(0, -10), 7, 6.5);

  soft(ctx, scale < 0.4 ? 1.3 : 2.4);
  ctx.fill();
  ctx.shadowBlur = 0;

  // 오려낸 문양으로 새는 불빛 (작게 그릴 때는 생략)
  if (fine) {
    perfFill(ctx); ctx.beginPath();
    for (let i = 0; i < 9; i++) { const k = (i + 0.5) / 9, p = [lerp(hL[0], hR[0], k), lerp(hL[1], hR[1], k) - 3]; circ(ctx, p[0], p[1] - 2.2, 1.5); } // 밑단 구멍
    for (let i = 0; i < perf.length; i += 2) circ(ctx, perf[i][0], perf[i][1], 2.1); // 어깨 관절 못
    for (const pts of sleeves) for (let i = 3; i < pts.length - 3; i += 3) circ(ctx, pts[i][0], pts[i][1], 1.6); // 한삼 장식
    const cl = T(0, -58), cb = T(0, -34);
    for (let i = 0; i < 7; i++) { const k = i / 6; circ(ctx, lerp(cl[0], cb[0], k) + (k < 0.5 ? -1 : 1) * 0, lerp(cl[1], cb[1], k), 1.2); } // 옷깃 선
    ctx.fill();
  }

  // 머리(사모 + 가지 + 꽃 + 탈): 구워 둔 스프라이트. 탈은 유일한 온색.
  const eff = scale * (ctx.getTransform ? ctx.getTransform().a : 1);
  const res = eff < 0.6 ? 1 : eff < 1.3 ? 2 : 4;
  const hs = headSprite(mask, res);
  ctx.save(); ctx.translate(HO[0], HO[1]); ctx.rotate(hd);
  const mw = (J.sx === undefined ? 1 : 0.55 + 0.45 * Math.abs(sx)) / proj;
  if (mw !== 1) ctx.scale(mw, 1);
  ctx.drawImage(hs, -HEAD_X, -HEAD_Y, hs.width / res, hs.height / res);
  ctx.restore();
  ctx.restore();
}

// 머리 스프라이트: 머리 좌표계(목 밑 = 원점, 위 = -y). 해상도별·탈 유무별로 한 번만 굽는다.
const HEAD_X = 58, HEAD_Y = 98, HEAD_W = 116, HEAD_H = 106;
const headCache = new Map();
function headSprite(mask, res) {
  const key = `${mask ? 1 : 0}@${res}`;
  let c = headCache.get(key);
  if (c) return c;
  c = typeof document !== 'undefined' ? document.createElement('canvas') : new OffscreenCanvas(HEAD_W * res, HEAD_H * res);
  c.width = HEAD_W * res; c.height = HEAD_H * res;
  const g = c.getContext('2d');
  g.scale(res, res); g.translate(HEAD_X, HEAD_Y);
  g.beginPath();
  poly(g, catmull([[-15, -32], [-15, -48], [-12, -61], [-6, -68], [6, -68], [12, -61], [15, -48], [15, -32]], true, 4));
  for (const s of [-1, 1]) { // 사모 날개: 양쪽으로 뻗고 끝이 살짝 올라간다
    const wing = [[s * 11, -59.5], [s * 26, -60], [s * 40, -60], [s * 52, -61.5], [s * 41, -55.5], [s * 26, -53], [s * 11, -51]];
    poly(g, catmull(wing, true, 4));
  }
  // 가지: 줄기 넷 + 모란(가운데) + 복숭아꽃 + 잎
  const stems = [[[0, -66], [-2, -73], [-1, -80]], [[-5, -66], [-13, -71], [-22, -77]], [[5, -66], [13, -70], [23, -76]], [[-8, -67], [-14, -76], [-12, -84]]];
  for (const st of stems) poly(g, ribbon(catmull(st, false, 5), (i, n) => 1.5 - i / n * 0.6));
  const flw = [];
  const peony = (px, py, r) => { for (let i = 0; i < 6; i++) { const a = (i / 6) * TAU; circ(g, px + Math.cos(a) * r * 0.62, py + Math.sin(a) * r * 0.62, r * 0.5); } circ(g, px, py, r * 0.75); flw.push([px, py, r]); };
  const peach = (px, py, r) => { for (let i = 0; i < 5; i++) { const a = (i / 5) * TAU - 1.2; circ(g, px + Math.cos(a) * r * 0.62, py + Math.sin(a) * r * 0.62, r * 0.5); } flw.push([px, py, r * 0.8]); };
  peony(-1, -84, 9); peach(-24, -79, 6); peach(25, -78, 6); peach(-12, -87, 4);
  for (const [px, py, a] of [[-11, -71, -0.6], [-18, -77, 0.2], [11, -70, 0.5], [18, -75, -0.3], [5, -77, -0.9], [-6, -78, 0.9]]) ell(g, px, py, 6.5, 2.7, a);
  if (!mask) ell(g, 0, -21, 17, 20);
  soft(g, res === 1 ? 1.5 : 2.6); g.fill(); g.shadowBlur = 0;
  // 오려낸 구멍으로 새는 불빛: 꽃술 + 모자 띠
  perfFill(g); g.beginPath();
  for (const [px, py, r] of flw) circ(g, px, py, Math.max(1, r * 0.2));
  for (let i = -3; i <= 3; i++) circ(g, i * 4.5, -37 - Math.abs(i) * 0.3, 1.1);
  g.fill();
  if (mask) drawMask(g, 0, -21, 36, 0);
  headCache.set(key, c);
  return c;
}

// ══════════════════════════════════════════════════════════════════
// 역신 — 먹빛 실루엣 + 옅은 독기 후광. 왼쪽(처용 쪽)을 향한다. 발밑 (x,y)
// ══════════════════════════════════════════════════════════════════
const EYE = { fever: '#ffab6a', chill: '#b6dcff', cough: '#efdc9a', pox: '#dcb6ff', yeoksin: '#ffd6a0' };
const HEIGHT = { fever: 200, chill: 135, cough: 125, pox: 165, yeoksin: 262 };

// 상태 → 변형 값
function stateXf(state, p, t) {
  const o = { dx: 0, sx: 1, sy: 1, rot: 0, alpha: 1, thrust: 0, glow: 0.75 + 0.25 * Math.sin(t * 2.3), kneel: 0, ghost: 0 };
  const bell = Math.sin(Math.PI * p);
  if (state === 'lurk') { o.rot = Math.sin(t * 1.6) * 0.025; o.dx = Math.sin(t * 0.9) * 3; }
  else if (state === 'throw') { // 뒤로 젖혔다가(0~.3) 앞으로 덮친다(.3~.7) 돌아온다
    const w = sstep(p / 0.3), l = sstep((p - 0.3) / 0.35), r = sstep((p - 0.7) / 0.3);
    o.dx = lerp(0, 16, w) + lerp(0, -62, l) * (1 - r) - 16 * r * w;
    o.thrust = clamp(l * (1 - r * 1.4), 0, 1); o.sx = 1 + 0.1 * o.thrust; o.rot = 0.07 * w * (1 - l) - 0.1 * o.thrust;
    o.glow = 0.9 + 0.5 * o.thrust;
  } else if (state === 'flinch') {
    const e = sstep(Math.min(1, p * 5)) * (1 - sstep((p - 0.35) / 0.65));
    o.dx = 34 * e + Math.sin(t * 70) * 2.6 * e; o.sx = 1 - 0.13 * e; o.sy = 1 - 0.08 * e; o.rot = 0.2 * e; o.glow = 0.8 + 0.9 * e;
  } else if (state === 'kneel') {
    const k = sstep(p); o.kneel = k; o.sy = 1 - 0.38 * k; o.sx = 1 + 0.1 * k; o.rot = -0.2 * k; o.dx = -8 * k; o.glow = 0.75 * (1 - k); o.dy = 0;
  } else if (state === 'flee') {
    o.dx = p * 210; o.sx = 1 + 1.4 * p; o.sy = 1 - 0.3 * p; o.rot = 0.12 * p; o.alpha = Math.pow(1 - p, 1.25); o.glow = 0.8 * (1 - p); o.ghost = p;
  }
  return o;
}

function wisp(ctx, x, y, r, a) {
  const g = ctx.createRadialGradient(x, y, 0, x, y, r);
  g.addColorStop(0, `rgba(140,96,190,${a})`); g.addColorStop(1, 'rgba(91,58,122,0)');
  ctx.fillStyle = g; ctx.fillRect(x - r, y - r, r * 2, r * 2);
}

// 길고 휘는 팔 + 손가락. 반환: 손끝 좌표
function reachArm(ctx, sh, end, bend, t, seed, w0, fingers, fl) {
  const mid = [(sh[0] + end[0]) / 2 + bend[0], (sh[1] + end[1]) / 2 + bend[1]];
  const c = catmull([sh, mid, end], false, 6);
  poly(ctx, ribbon(c, (i, n) => lerp(w0, w0 * 0.4, i / (n - 1))));
  circ(ctx, end[0], end[1], w0 * 0.75);
  const dx = end[0] - mid[0], dy = end[1] - mid[1], base = Math.atan2(dy, dx);
  for (let f = 0; f < fingers; f++) {
    const spread = (f - (fingers - 1) / 2) * 0.34, a = base + spread + Math.sin(t * 3 + f + seed) * 0.12;
    const L = fl * (0.8 + 0.25 * hash(f + seed)), p = [end];
    for (let i = 1; i <= 4; i++) { const aa = a + i * 0.1 * Math.sin(t * 2.4 + f * 1.3) + i * 0.07 * (f % 2 ? 1 : -1); p.push([p[i - 1][0] + Math.cos(aa) * L / 4, p[i - 1][1] + Math.sin(aa) * L / 4]); }
    poly(ctx, ribbon(p, (i, n) => Math.max(0.7, w0 * 0.42 * (1 - i / n))));
  }
}

const BUILD = {
  fever(ctx, t, o) {
    const H = 190, eyes = [];
    // 불꽃 한 송이: 일렁이는 중심선을 따라 끝이 뾰족해지는 띠 (cx,by 밑, w 반폭, h 높이, bend 끝 휨)
    const flame = (cx, by, w, h, bend, ph) => {
      const c = [];
      for (let i = 0; i <= 14; i++) {
        const s = i / 14;
        c.push([cx + bend * Math.pow(s, 2.1) + Math.sin(t * 3.6 + ph + s * 4.6) * w * 0.85 * s, by - s * h]);
      }
      poly(ctx, ribbon(c, (i, n) => { const s = i / (n - 1); return w * Math.pow(1 - s, 0.8) * (1 + 0.28 * Math.sin(s * 10 - t * 6.5 + ph)) + 0.5; }));
    };
    flame(0, 4, 34, H, 26 * Math.sin(t * 1.9), 0);
    flame(-27, 4, 17, H * 0.52, -20 + 9 * Math.sin(t * 2.4), 1.7);
    flame(29, 4, 16, H * 0.44, 18 + 9 * Math.sin(t * 2.9 + 1), 3.1);
    flame(-12, -H * 0.28, 12, H * 0.34, -24 + 8 * Math.sin(t * 3.3), 4.4);
    flame(13, -H * 0.46, 11, H * 0.3, 22 + 8 * Math.sin(t * 3.7 + 2), 5.9);
    // 긴 팔 · 긴 손가락 (처용 쪽 = 왼쪽)
    const th = o.thrust, sh = [-10, -H * 0.4];
    reachArm(ctx, sh, [lerp(-62 + Math.sin(t * 2) * 6, -135, th), lerp(-44 + Math.cos(t * 2.3) * 5, -H * 0.42, th)], [-4, 16 - 22 * th], t, 1, 4.4, 5, 30);
    reachArm(ctx, [10, -H * 0.4], [lerp(58 + Math.sin(t * 2.2) * 6, -90, th), lerp(-40 + Math.cos(t * 1.7) * 6, -H * 0.55, th)], [10, 18 - 30 * th], t, 5, 3.8, 5, 26);
    eyes.push([-9, -H * 0.58, 3.8, -0.35], [7, -H * 0.58, 3.8, 0.35]);
    return { eyes, hh: H };
  },
  chill(ctx, t, o) {
    const sh = Math.sin(t * 42) * 1.3, eyes = [];
    const base = [[-46, 0], [-42, -18], [-50, -40], [-38, -62], [-48, -76], [-56, -90], [-46, -102], [-30, -108], [-14, -104], [-4, -124], [24, -136], [46, -116], [60, -76], [58, -38], [46, -4], [28, 0], [4, -6], [-24, 0]];
    const c = catmull(base, true, 3), out = [];
    for (let i = 0; i < c.length; i++) { // 가시: 바깥 법선 방향으로 번갈아 튀어나온 지그재그
      const a = c[(i + c.length - 1) % c.length], b = c[(i + 1) % c.length], p = c[i];
      let nx = b[1] - a[1], ny = -(b[0] - a[0]); const l = Math.hypot(nx, ny) || 1; nx /= l; ny /= l;
      const sp = (i % 3 || p[0] < -26 || p[1] > -14) ? 0 : 9 + 6 * hash(i) + (o.thrust * 3);
      out.push([p[0] + nx * sp + Math.sin(t * 40 + i) * 0.9 + sh, p[1] + ny * sp]);
    }
    poly(ctx, out);
    const th = o.thrust;
    reachArm(ctx, [-34, -70], [lerp(-86, -140, th) + sh, lerp(-46, -88, th)], [-4, 14], t, 2, 4.2, 4, 22);
    eyes.push([-46, -97, 3.1, -0.4], [-36, -101, 3.1, 0.2]);
    return { eyes, hh: 135 };
  },
  cough(ctx, t, o) {
    const inf = 1 + 0.05 * Math.sin(t * 3) + 0.2 * o.thrust, R = 52 * inf, eyes = [];
    const pts = [];
    for (let i = 0; i < 36; i++) { const a = (i / 36) * TAU; pts.push([Math.cos(a) * (R * 1.04 + 2 * Math.sin(a * 3 + t * 2)), -62 + Math.sin(a) * R * 0.98 + 2 * Math.sin(a * 4 - t * 2.4)]); }
    poly(ctx, pts);
    ell(ctx, -22, -6, 13, 8); ell(ctx, 22, -6, 13, 8); // 발
    ell(ctx, 4, -68, R * 0.3, 8, 0.1); // 몸통 위 팔 흉내
    const mo = 0.72 + 0.28 * Math.sin(t * 4.2) + o.thrust * 0.4, mx = -22, my = -56;
    ell(ctx, -R * 0.96, -52, 16, 11, -0.3); ell(ctx, R * 0.98, -48, 14, 10, 0.3);
    eyes.push([-12, -86, 3.4, -0.3], [8, -90, 3.4, 0.3]);
    return { eyes, hh: 125, mouth: { x: mx, y: my, rx: 26, ry: 17 * mo }, R };
  },
  pox(ctx, t, o) {
    const sw = 1 + 0.18 * o.thrust, eyes = [];
    const body = [], rim = (cx, cy, rx, ry, n, r0, seed) => { for (let i = 0; i < n; i++) { const a = (i / n) * TAU, rr = (r0 + 3.5 * hash(i + seed) + 1.2 * Math.sin(t * 2.4 + i * 2)) * sw; circ(ctx, cx + Math.cos(a) * rx, cy + Math.sin(a) * ry, rr); body.push([cx + Math.cos(a) * rx, cy + Math.sin(a) * ry, rr]); } };
    ell(ctx, 0, -72, 38, 54); ell(ctx, -6, -138, 23, 22);
    rim(0, -72, 38, 54, 18, 9, 0); rim(-6, -138, 23, 22, 10, 7, 30);
    // 팔과 다리: 혹투성이 굵은 막대
    capsule(ctx, [-30, -96], [-52 - 40 * o.thrust, -60 - 30 * o.thrust], 11, 9); circ(ctx, -52 - 40 * o.thrust, -58 - 30 * o.thrust, 12);
    capsule(ctx, [30, -96], [48, -50], 11, 9); circ(ctx, 48, -48, 11);
    capsule(ctx, [-16, -30], [-20, -2], 14, 12); capsule(ctx, [18, -30], [24, -2], 14, 12);
    for (const [bx, by, br] of [[-50, -62, 6], [-44, -78, 5], [50, -60, 6], [-22, -14, 6], [24, -16, 6]]) circ(ctx, bx - 40 * o.thrust * (bx < 0 && by < -55 ? 1 : 0), by, br);
    for (let i = 0; i < 11; i++) { const a = hash(i * 3.3) * TAU, d = Math.sqrt(hash(i * 7.1)); const big = i < 4; eyes.push([Math.cos(a) * d * 26, -78 + Math.sin(a) * d * 40 - (big ? 0 : 0), big ? 3 : 2, 0, i]); }
    eyes.push([-12, -141, 3.2, 0, 20], [-1, -142, 2.6, 0, 21], [-8, -132, 2.2, 0, 22]);
    return { eyes, hh: 165, boils: body, dots: true };
  },
  yeoksin(ctx, t, o) {
    const sway = Math.sin(t * 1.1) * 4, th = o.thrust, eyes = [];
    // 도포 자락
    const rb = [[-24 + sway * 0.4, -200], [-30, -170], [-38, -120], [-52, -60], [-66 + Math.sin(t * 1.6) * 3, -6], [-40, 2], [-14, -3], [12, 2], [40, -4], [68 + Math.sin(t * 1.4) * 3, -6], [54, -60], [40, -120], [30, -170], [24 + sway * 0.4, -200]];
    poly(ctx, catmull(rb, true, 4));
    poly(ctx, catmull([[-22, -204], [-30, -196], [-34, -184], [34, -184], [30, -196], [22, -204]], true, 3)); // 어깨
    // 넓은 소매 두 개: 앞 소매는 던질 때 앞으로 치켜든다
    const sl = (sx0, ex, ey, wv) => {
      const sh = [sx0, -190], el = [(sh[0] + ex) / 2 + sway, (sh[1] + ey) / 2 + 24], pts = catmull([sh, el, [ex, ey]], false, 6);
      for (let i = 0; i < pts.length; i++) pts[i][1] += Math.sin(t * 2.8 - i * 0.5 + wv) * 3 * (i / pts.length);
      poly(ctx, ribbon(pts, (i, n) => lerp(8, 24, sstep(i / (n - 1) * 1.3)) + Math.sin(i + t * 2 + wv) * 1.5));
    };
    sl(-26, lerp(-88, -150, th), lerp(-78, -178, th), 0); sl(26, 70, -92, 2);
    // 갓: 넓은 챙 + 높은 모자통 + 끈
    ell(ctx, 0, -240, 40, 6); poly(ctx, catmull([[-15, -241], [-16, -262], [-9, -272], [9, -272], [16, -262], [15, -241]], true, 3));
    // 얼굴(가면 같은) + 수염
    ell(ctx, 0, -222, 14.5, 18.5);
    poly(ctx, ribbon(catmull([[-3, -204], [-4 + Math.sin(t * 1.4) * 2, -180], [-2, -158]], false, 4), (i, n) => 3 * (1 - i / n) + 0.4));
    poly(ctx, ribbon(catmull([[4, -204], [5 + Math.sin(t * 1.4 + 1) * 2, -184], [3, -166]], false, 4), (i, n) => 2.5 * (1 - i / n) + 0.4));
    for (const s of [-1, 1]) poly(ctx, ribbon([[s * 13, -238], [s * 16, -214], [s * 18, -190 + Math.sin(t * 2 + s) * 2]], () => 1.3)); // 갓끈
    eyes.push([-6, -224, 4.2, 0.28, 'hollow'], [6.2, -224, 4.2, -0.28, 'hollow']);
    return { eyes, hh: 262, mask: true };
  },
};

export function drawSpirit(ctx, x, y, scale, type, state, t, { phase = 0 } = {}) {
  const build = BUILD[type]; if (!build) return;
  const p = clamp(phase, 0, 1), o = stateXf(state, p, t);
  const hh = HEIGHT[type] || 160;
  const copies = state === 'flee' ? [[0, 1], [-34, 0.42], [-70, 0.22], [-106, 0.1]] : [[0, 1]];
  ctx.save();
  ctx.translate(x, y);
  // 독기 후광(몸 뒤)
  if (o.glow > 0.02) {
    const gy = -hh * 0.5 * o.sy * scale, R = hh * 0.56 * scale;
    const g = ctx.createRadialGradient(o.dx * scale, gy, R * 0.1, o.dx * scale, gy, R);
    g.addColorStop(0, `rgba(110,70,160,${0.34 * o.glow * o.alpha})`); g.addColorStop(0.55, `rgba(91,58,122,${0.16 * o.glow * o.alpha})`); g.addColorStop(1, 'rgba(91,58,122,0)');
    ctx.fillStyle = g; ctx.fillRect(o.dx * scale - R, gy - R, R * 2, R * 2);
    for (let i = 0; i < 2 && o.alpha > 0.1; i++) { // 피어오르는 독기 덩이
      const ph = (t * 0.22 + i * 0.5) % 1, wx = Math.sin(t * 0.8 + i * 2) * hh * 0.3 * scale;
      wisp(ctx, o.dx * scale + wx, -ph * hh * 0.95 * scale, hh * 0.16 * scale * (0.6 + ph * 0.6), 0.32 * Math.sin(Math.PI * ph) * o.glow * o.alpha);
    }
  }
  let info = null;
  for (const [gdx, ga] of copies) {
    ctx.save();
    ctx.translate((o.dx + gdx * o.ghost) * scale, 0);
    ctx.rotate(o.rot);
    ctx.scale(scale * o.sx * (gdx ? 1 + 0.15 * o.ghost : 1), scale * o.sy);
    ctx.globalAlpha = o.alpha * ga;
    ctx.beginPath();
    info = build(ctx, t, o);
    soft(ctx, scale < 0.5 ? 1.3 : 2.4); ctx.fill(); ctx.shadowBlur = 0;
    if (ga === 1) detail(ctx, type, info, t, o);
    ctx.restore();
  }
  ctx.restore();
}

// 눈 · 입 · 종기 등 불빛이 새는 부분
function detail(ctx, type, info, t, o) {
  const col = EYE[type];
  if (info.mouth) { // 기침귀 입: 안쪽이 환하고 이빨이 둘러 난다
    const m = info.mouth, g = ctx.createRadialGradient(m.x, m.y, 2, m.x, m.y, m.rx);
    g.addColorStop(0, 'rgba(255,214,150,0.9)'); g.addColorStop(1, 'rgba(150,100,190,0.75)');
    ctx.fillStyle = g; ctx.beginPath(); ctx.ellipse(m.x, m.y, m.rx, Math.max(2, m.ry), 0, 0, TAU); ctx.fill();
    ctx.fillStyle = COLORS.shadow; ctx.beginPath();
    for (let i = 0; i < 7; i++) {
      const a = (i / 7) * Math.PI + 0.1, px = m.x + Math.cos(a + Math.PI) * m.rx * 0.9;
      ctx.moveTo(px - 3.4, m.y - m.ry * Math.sin(a) * 0.95 - 1); ctx.lineTo(px, m.y - m.ry * Math.sin(a) * 0.95 + 8 * Math.min(1, m.ry / 12)); ctx.lineTo(px + 3.4, m.y - m.ry * Math.sin(a) * 0.95 - 1);
      ctx.moveTo(px - 3.4, m.y + m.ry * Math.sin(a) * 0.95 + 1); ctx.lineTo(px, m.y + m.ry * Math.sin(a) * 0.95 - 8 * Math.min(1, m.ry / 12)); ctx.lineTo(px + 3.4, m.y + m.ry * Math.sin(a) * 0.95 + 1);
    }
    ctx.fill();
    // 기침 연기
    for (let i = 0; i < 6; i++) {
      const age = (t * (0.7 + o.thrust * 0.8) + i / 6) % 1;
      const px = m.x - m.rx - age * (60 + o.thrust * 90), py = m.y - age * 30 + Math.sin(i * 3 + t * 3) * 6, rr = 5 + age * 16;
      ctx.fillStyle = `rgba(122,92,150,${(1 - age) * 0.5})`; ctx.beginPath(); ctx.arc(px, py, rr, 0, TAU); ctx.fill();
    }
  }
  if (info.boils) { // 종기 테두리
    ctx.strokeStyle = 'rgba(190,150,230,0.4)'; ctx.lineWidth = 1;
    for (let i = 0; i < info.boils.length; i += 2) { const b = info.boils[i]; ctx.beginPath(); ctx.arc(b[0] * 0.78, b[1] * 0.9 + (b[1] < -100 ? -2 : -7), b[2] * 0.55, 0, TAU); ctx.stroke(); }
  }
  for (const e of info.eyes) {
    const [ex, ey, er, ang, id] = e;
    if (ang === 'hollow' || e[4] === 'hollow') continue;
    if (id !== undefined) { // 홍역귀 잔 눈: 깜박인다
      const a = 0.55 + 0.45 * Math.sin(t * 2.2 + id * 1.9);
      ctx.fillStyle = col; ctx.globalAlpha *= a; ctx.beginPath(); ctx.arc(ex, ey, er, 0, TAU); ctx.fill(); ctx.globalAlpha /= a; continue;
    }
    ctx.fillStyle = col; ctx.beginPath(); ctx.ellipse(ex, ey, er * 1.4, er * 0.6, ang, 0, TAU); ctx.fill();
  }
  if (type === 'yeoksin') { // 가면 같은 얼굴: 텅 빈 눈, 얇은 입, 얼굴 테두리
    ctx.strokeStyle = 'rgba(230,200,150,0.55)'; ctx.lineWidth = 1.1;
    ctx.beginPath(); ctx.ellipse(0, -222, 14.5, 18.5, 0, 0, TAU); ctx.stroke();
    ctx.fillStyle = 'rgba(255,224,170,0.92)';
    for (const [ex, ey, a] of [[-6.2, -224, 0.28], [6.2, -224, -0.28]]) { ctx.beginPath(); ctx.ellipse(ex, ey, 4.4, 2.1, a, 0, TAU); ctx.fill(); }
    ctx.fillRect(-3.5, -211, 7, 1.2);
    ctx.fillRect(-0.7, -218, 1.4, 5);
    // 맴도는 도깨비불
    for (let i = 0; i < 3; i++) { const a = t * 0.9 + i * 2.1; ctx.fillStyle = `rgba(190,150,240,${0.5 + 0.3 * Math.sin(t * 3 + i)})`; ctx.beginPath(); ctx.arc(Math.cos(a) * 62, -150 + Math.sin(a * 1.3) * 60, 3, 0, TAU); ctx.fill(); }
  }
}

// ══════════════════════════════════════════════════════════════════
// 집 — 한옥 실루엣. (x,y) = 집 바닥 가운데, w = 너비
// ══════════════════════════════════════════════════════════════════
function tiledRoof(w, bh, ridgeH) { // 처마가 들린 기와지붕 윤곽 (오른쪽 반쪽을 만들어 거울로 합친다)
  const ey = -bh - 0.02 * w, tip = 0.07 * w, ry = -bh - ridgeH;
  const R = [[0, ey + 0.016 * w]];
  quad(R, [0, ey + 0.016 * w], [0.3 * w, ey + 0.006 * w], [0.4 * w, ey + 0.012 * w], 3); // 처마 밑선
  quad(R, [0.4 * w, ey + 0.012 * w], [0.57 * w, ey + 0.02 * w], [0.65 * w, ey - tip], 5); // 위로 들린 추녀
  quad(R, [0.65 * w, ey - tip], [0.52 * w, ey - 0.05 * w], [0.4 * w, ey - 0.07 * w], 4); // 지붕 면으로 되돌아옴
  quad(R, [0.4 * w, ey - 0.07 * w], [0.3 * w, ey - 0.13 * w], [0.265 * w, ry], 8); // 오목한 경사
  R.push([0.265 * w, ry - 0.025 * w], [0.22 * w, ry - 0.035 * w]);
  const Lh = R.map((p) => [-p[0], p[1]]).reverse();
  return R.concat(Lh);
}
function thatchRoof(w, bh, seed) { // 초가: 둥근 볏짚 지붕 + 너덜한 밑단
  const P = [], top = -bh - 0.36 * w;
  const lo = -bh + 0.02 * w;
  const half = 0.6 * w;
  for (let i = 0; i <= 14; i++) { // 왼쪽 밑 → 꼭대기 → 오른쪽 밑
    const a = Math.PI + (i / 14) * Math.PI, xx = Math.cos(a) * half, yy = lo + Math.sin(a) * (lo - top) * (1 + 0.04 * hash(i + seed));
    P.push([xx, yy]);
  }
  for (let i = 0; i <= 16; i++) { const k = i / 16; P.push([half - k * 2 * half, lo + (i % 2 ? 0.035 * w : 0.008 * w) + 0.01 * w * hash(i + seed * 3)]); }
  return P;
}

export function drawHouse(ctx, x, y, w, t, { lit = true, haunted = false, masked = false, home = false } = {}) {
  if (home) w *= 1.22;
  const thatch = !home && hash(Math.round(x) * 0.37) < 0.42;
  const bw = (thatch ? 0.7 : 0.8) * w, bh = (thatch ? 0.27 : home ? 0.36 : 0.31) * w;
  // 창 · 문 불빛 세기와 색
  let I = lit ? 0.9 : 0.12, cold = false;
  if (masked) I = 1.15;
  else if (haunted) { cold = true; const n = Math.sin(t * 21) * Math.sin(t * 13.7 + 1.3); I = 0.22 + 0.2 * (n > 0.3 ? 1 : n > -0.2 ? 0.45 : 0.1) + 0.06 * Math.sin(t * 3); }
  else if (lit) I = 0.88 + 0.07 * Math.sin(t * 9 + x) + 0.05 * Math.sin(t * 15.7 + x * 0.1);
  const winC = cold ? [150, 168, 224] : [255, 206, 120];
  const wx = bw * 0.29, wy = -bh * 0.56, ww = w * 0.075, wh = w * 0.085;

  ctx.save(); ctx.translate(x, y);
  // 창에서 새는 불빛이 종이에 번진다
  if (I > 0.1) for (const s of [-1, 1]) {
    const g = ctx.createRadialGradient(s * wx, wy, 2, s * wx, wy, w * 0.42);
    g.addColorStop(0, `rgba(${winC.join(',')},${(cold ? 0.18 : 0.3) * Math.min(1.2, I)})`); g.addColorStop(1, `rgba(${winC.join(',')},0)`);
    ctx.fillStyle = g; ctx.fillRect(s * wx - w * 0.42, wy - w * 0.42, w * 0.84, w * 0.84);
  }
  // ── 실루엣 ──
  ctx.beginPath();
  if (home) { // 담장 (집 뒤로 양옆) + 대문
    const wl = w * 1.28, wh2 = w * 0.17;
    ctx.rect(-wl, -wh2, wl * 2, wh2 + 3);
    ctx.rect(-wl - 3, -wh2 - 5, wl * 2 + 6, 6);
    for (let xx = -wl; xx < wl; xx += 9) circ(ctx, xx + 4.5, -wh2 + 1, 4);
    // 대문(왼쪽): 기둥 두 개 + 작은 기와지붕
    const gx = -w * 0.95, gw = w * 0.34;
    ctx.rect(gx - gw / 2, -wh2 - w * 0.2, 4, w * 0.2 + wh2); ctx.rect(gx + gw / 2 - 4, -wh2 - w * 0.2, 4, w * 0.2 + wh2);
    const gp = tiledRoof(gw * 1.9, 0, 0.1 * gw * 1.9).map((p) => [p[0] + gx, p[1] - wh2 - w * 0.19]);
    poly(ctx, gp);
  }
  ctx.rect(-bw / 2, -bh, bw, bh);
  ctx.rect(-bw * 0.56, -0.025 * w, bw * 1.12, 0.025 * w); // 기단
  if (thatch) poly(ctx, thatchRoof(w, bh, Math.round(x)));
  else poly(ctx, tiledRoof(w, bh, home ? 0.5 * w : 0.4 * w));
  if (!thatch) { // 용마루 끝 치미
    const ry = -bh - (home ? 0.5 : 0.4) * w;
    for (const s of [-1, 1]) poly(ctx, [[s * 0.25 * w, ry - 0.02 * w], [s * 0.3 * w, ry - 0.05 * w], [s * 0.285 * w, ry + 0.02 * w]]);
  }
  soft(ctx, 2.2); ctx.fill(); ctx.shadowBlur = 0;
  if (thatch && w >= 80) { // 볏짚 층 결
    ctx.strokeStyle = 'rgba(240,178,90,0.12)'; ctx.lineWidth = 1; ctx.beginPath();
    const lo = -bh + 0.02 * w, top = -bh - 0.36 * w, rx = 0.6 * w;
    for (let k = 1; k <= 4; k++) { const f = k / 5; ctx.moveTo(-rx * Math.sqrt(1 - f * f) * 0.96, lo + (top - lo) * 0 - 0.012 * w); ctx.ellipse(0, lo, rx * Math.sqrt(1 - f * f) * 0.96, (lo - top) * f * 0.98, 0, Math.PI, TAU); }
    ctx.stroke();
  }

  // 기와 골 · 처마 끝 기와(작은 빛 점)
  if (w >= 80 && !thatch) {
    ctx.strokeStyle = 'rgba(240,178,90,0.12)'; ctx.lineWidth = 1;
    const ey = -bh - 0.02 * w, ry = -bh - (home ? 0.5 : 0.4) * w;
    ctx.beginPath();
    for (let i = -4; i <= 4; i++) { ctx.moveTo(i * 0.062 * w, ry + 0.02 * w); ctx.lineTo(i * 0.105 * w, ey - 0.012 * w); }
    ctx.stroke();
  }
  // ── 창 (격자) ──
  for (const s of [-1, 1]) {
    const g = ctx.createLinearGradient(0, wy - wh, 0, wy + wh);
    const a = clamp(I, 0.08, 1);
    g.addColorStop(0, `rgba(${winC.join(',')},${a})`); g.addColorStop(1, `rgba(${cold ? '110,124,190' : '240,160,70'},${a * 0.9})`);
    ctx.fillStyle = g; ctx.fillRect(s * wx - ww, wy - wh, ww * 2, wh * 2);
    ctx.strokeStyle = COLORS.shadow; ctx.lineWidth = Math.max(1, w * 0.01);
    ctx.beginPath();
    ctx.rect(s * wx - ww, wy - wh, ww * 2, wh * 2);
    ctx.moveTo(s * wx, wy - wh); ctx.lineTo(s * wx, wy + wh);
    ctx.moveTo(s * wx - ww, wy); ctx.lineTo(s * wx + ww, wy);
    if (w > 110) { ctx.moveTo(s * wx - ww / 2, wy - wh); ctx.lineTo(s * wx - ww / 2, wy + wh); ctx.moveTo(s * wx + ww / 2, wy - wh); ctx.lineTo(s * wx + ww / 2, wy + wh); }
    ctx.stroke();
  }
  // ── 문(가운데) ──
  const dw = w * 0.08, dh = bh * 0.82;
  ctx.fillStyle = '#2c1f17'; ctx.fillRect(-dw, -dh, dw * 2, dh);
  const edge = haunted ? `rgba(176,130,224,${0.35 + 0.35 * I})` : `rgba(240,178,90,${masked ? 0.7 : lit ? 0.38 : 0.12})`;
  ctx.strokeStyle = edge; ctx.lineWidth = Math.max(1, w * 0.012);
  ctx.beginPath(); ctx.rect(-dw, -dh, dw * 2, dh); ctx.moveTo(0, -dh); ctx.lineTo(0, 0); ctx.stroke();
  ctx.fillStyle = edge; ctx.beginPath(); circ(ctx, -dw * 0.3, -dh * 0.5, Math.max(1, w * 0.01)); circ(ctx, dw * 0.3, -dh * 0.5, Math.max(1, w * 0.01)); ctx.fill();

  // ── 귀신 든 집: 문틈에서 새는 독기 ──
  if (haunted) {
    for (let i = 0; i < 7; i++) {
      const ph = (t * 0.3 + i / 7) % 1, side = i % 3 === 0 ? 0 : i % 2 ? 1 : -1, hh = hash(i * 5.3);
      const px = side * ph * w * (0.2 + 0.3 * hh) + Math.sin(t * 0.9 + i) * w * 0.02;
      const py = -w * 0.015 - ph * w * (side === 0 ? 0.26 : 0.07) * (0.6 + hh);
      const r = w * (0.06 + 0.11 * ph), a = Math.sin(Math.PI * ph) * 0.85;
      const g = ctx.createRadialGradient(px, py, 0, px, py, r);
      g.addColorStop(0, `rgba(138,92,190,${a})`); g.addColorStop(1, 'rgba(91,58,122,0)');
      ctx.fillStyle = g; ctx.fillRect(px - r, py - r, r * 2, r * 2);
    }
  }
  // ── 탈이 걸린 집: 문에 처용탈 ──
  if (masked) drawMask(ctx, 0, -dh * 0.56, Math.max(14, w * 0.15), t, { glow: 1 });
  ctx.restore();
}
