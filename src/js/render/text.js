// 붓글씨풍 제목 · 세로쓰기 · 대사 상자. 전부 순수 그리기.
import { COLORS } from './paper.js';

export const FONT = "'Nanum Brush Script','Noto Serif KR',serif";
const TAU = Math.PI * 2;
const hash = (n) => { const s = Math.sin(n * 127.1 + 311.7) * 43758.5453; return s - Math.floor(s); };

// 폭을 재서 줄바꿈. 호출 전에 ctx.font 를 맞춰 둔다. 공백 단위 → 안 되면 글자 단위.
export function wrapText(ctx, str, maxW) {
  const out = [];
  for (const para of String(str).split('\n')) {
    let line = '';
    for (const word of para.split(/(\s+)/)) {
      if (!word) continue;
      if (ctx.measureText(line + word).width <= maxW) { line += word; continue; }
      if (line.trim()) { out.push(line.trimEnd()); line = ''; }
      if (/^\s+$/.test(word)) continue;
      if (ctx.measureText(word).width <= maxW) { line = word; continue; }
      for (const ch of word) { // 단어가 한 줄보다 길면 글자 단위
        if (ctx.measureText(line + ch).width > maxW && line) { out.push(line); line = ''; }
        line += ch;
      }
    }
    out.push(line.trimEnd());
  }
  return out;
}

// 큰 붓글씨 제목: 번짐 사본 2~3장 + 본체. jitter(0~1)는 글자별 흔들림.
export function brushTitle(ctx, str, x, y, size, color, { align = 'center', jitter = 0 } = {}) {
  ctx.save();
  ctx.font = `${size}px ${FONT}`; ctx.textBaseline = 'middle'; ctx.textAlign = 'left';
  const chars = [...String(str)], ws = chars.map((c) => ctx.measureText(c).width), gap = size * 0.04;
  const total = ws.reduce((a, b) => a + b, 0) + gap * (chars.length - 1);
  let cx = align === 'center' ? x - total / 2 : align === 'right' ? x - total : x;
  const offs = [[-0.018, 0.014, 0.16], [0.02, -0.012, 0.13], [0.006, 0.026, 0.1]];
  const pos = [];
  for (let i = 0; i < chars.length; i++) {
    const j = jitter * size;
    pos.push([cx + (hash(i * 3.1) - 0.5) * j * 0.06, y + (hash(i * 5.7) - 0.5) * j * 0.12, (hash(i * 9.3) - 0.5) * jitter * 0.1]);
    cx += ws[i] + gap;
  }
  const pass = (dx, dy, a, blur) => {
    ctx.globalAlpha = a; ctx.fillStyle = color; ctx.shadowColor = color; ctx.shadowBlur = blur;
    for (let i = 0; i < chars.length; i++) {
      ctx.save(); ctx.translate(pos[i][0] + dx * size, pos[i][1] + dy * size); ctx.rotate(pos[i][2]);
      ctx.fillText(chars[i], 0, 0); ctx.restore();
    }
  };
  for (const [dx, dy, a] of offs) pass(dx, dy, a, size * 0.05); // 먹 번짐
  pass(0, 0, 1, 0);
  // 마른 붓 느낌: 얇은 윤곽선
  ctx.shadowBlur = 0; ctx.globalAlpha = 0.5; ctx.strokeStyle = color; ctx.lineWidth = Math.max(0.6, size * 0.012);
  for (let i = 0; i < chars.length; i++) { ctx.save(); ctx.translate(pos[i][0], pos[i][1]); ctx.rotate(pos[i][2]); ctx.strokeText(chars[i], 0, 0); ctx.restore(); }
  ctx.restore();
}

// 세로쓰기: x 가 글자 열의 가운데, y 는 맨 위. '\n' 은 왼쪽 새 열.
export function verticalText(ctx, str, x, y, size, color) {
  ctx.save();
  ctx.font = `${size}px ${FONT}`; ctx.textBaseline = 'middle'; ctx.textAlign = 'center';
  ctx.fillStyle = color; ctx.shadowColor = color; ctx.shadowBlur = size * 0.04;
  const cols = String(str).split('\n').reverse(); // 오른쪽 열부터 읽으므로 뒤집어 그린다
  cols.forEach((col, ci) => {
    const cx = x - (cols.length - 1 - ci) * size * 1.5; // 첫 줄이 가장 오른쪽
    let cy = y + size * 0.55;
    for (const ch of col) {
      if (ch === ' ') { cy += size * 0.5; continue; }
      ctx.globalAlpha = 0.14; ctx.fillText(ch, cx + size * 0.015, cy + size * 0.012);
      ctx.globalAlpha = 1; ctx.fillText(ch, cx, cy);
      cy += size * 1.12;
    }
  });
  ctx.restore();
}

// 종이 결 타일(한 번만 생성)
let tile = null;
function paperTile() {
  if (tile) return tile;
  const c = typeof document !== 'undefined' ? document.createElement('canvas') : new OffscreenCanvas(96, 96);
  c.width = c.height = 96;
  const g = c.getContext('2d');
  for (let i = 0; i < 260; i++) {
    const x = hash(i * 1.7) * 96, y = hash(i * 2.9) * 96, a = hash(i * 4.1) * TAU, l = 3 + hash(i * 6.3) * 12;
    g.strokeStyle = i % 2 ? 'rgba(255,250,232,0.35)' : 'rgba(120,86,46,0.14)'; g.lineWidth = 0.6;
    g.beginPath(); g.moveTo(x, y); g.lineTo(x + Math.cos(a) * l, y + Math.sin(a) * l); g.stroke();
  }
  tile = c; return c;
}

// 아래 레터박스 대사 상자. 한지색 띠 + 먹 테두리 + 붉은 낙관식 이름표. progress 0..1 = 타자 효과.
export function dialogBox(ctx, w, h, who, text, t, { progress = 1 } = {}) {
  const bh = Math.round(h * 0.27), y0 = h - bh;
  ctx.save();
  // 위쪽 그림자
  const sh = ctx.createLinearGradient(0, y0 - 18, 0, y0);
  sh.addColorStop(0, 'rgba(26,20,16,0)'); sh.addColorStop(1, 'rgba(26,20,16,0.35)');
  ctx.fillStyle = sh; ctx.fillRect(0, y0 - 18, w, 18);
  // 종이 띠
  const pg = ctx.createLinearGradient(0, y0, 0, h);
  pg.addColorStop(0, '#efe2bf'); pg.addColorStop(1, '#e2d0a5');
  ctx.fillStyle = pg; ctx.fillRect(0, y0, w, bh);
  ctx.globalAlpha = 0.9; ctx.fillStyle = ctx.createPattern(paperTile(), 'repeat'); ctx.fillRect(0, y0, w, bh); ctx.globalAlpha = 1;
  // 먹 테두리: 굵은 윗선 + 가는 안선, 끝이 번지는 붓 느낌
  ctx.fillStyle = COLORS.shadow;
  ctx.beginPath(); ctx.moveTo(0, y0);
  for (let x = 0; x <= w; x += 12) ctx.lineTo(x, y0 - 0.5 - 1.3 * hash(x * 0.37));
  for (let x = w; x >= 0; x -= 12) ctx.lineTo(x, y0 + 4 + 1.6 * hash(x * 0.21 + 3));
  ctx.closePath(); ctx.fill();
  ctx.fillRect(0, y0 + 9, w, 1.5);
  ctx.fillRect(0, h - 4, w, 4);
  // 안쪽 따뜻한 빛
  const warm = ctx.createRadialGradient(w / 2, y0 + bh * 0.6, 20, w / 2, y0 + bh * 0.6, w * 0.6);
  warm.addColorStop(0, 'rgba(255,230,170,0.35)'); warm.addColorStop(1, 'rgba(255,230,170,0)');
  ctx.fillStyle = warm; ctx.fillRect(0, y0 + 10, w, bh - 14);

  const fs = Math.round(bh * 0.19), lh = Math.round(fs * 1.4), mx = Math.round(w * 0.045);
  // 이름표(낙관): 붉은 도장 상자 + 한지색 글씨
  let textX = mx, textY = y0 + Math.round(bh * 0.2) + fs;
  if (who) {
    const nf = Math.round(fs * 0.9);
    ctx.font = `${nf}px ${FONT}`;
    const nw = Math.max(nf * 2.6, ctx.measureText(who).width + nf * 1.3), nh = nf * 1.7, nx = mx - 6, ny = y0 - nh * 0.45;
    ctx.fillStyle = COLORS.red; ctx.beginPath();
    const J = (i) => (hash(i * 3.3 + who.length) - 0.5) * 2;
    ctx.moveTo(nx + J(1), ny + J(2)); ctx.lineTo(nx + nw + J(3), ny + J(4)); ctx.lineTo(nx + nw + J(5), ny + nh + J(6)); ctx.lineTo(nx + J(7), ny + nh + J(8)); ctx.closePath(); ctx.fill();
    ctx.strokeStyle = 'rgba(243,233,210,0.75)'; ctx.lineWidth = 1.5; ctx.strokeRect(nx + 3.5, ny + 3.5, nw - 7, nh - 7);
    ctx.fillStyle = COLORS.white; ctx.textBaseline = 'middle'; ctx.textAlign = 'center';
    ctx.fillText(who, nx + nw / 2, ny + nh / 2 + 1);
    textY = ny + nh + fs * 0.9;
  }
  // 본문(미리 줄바꿈한 뒤 글자 수만큼만 드러낸다)
  ctx.font = `${fs}px ${FONT}`; ctx.textAlign = 'left'; ctx.textBaseline = 'alphabetic';
  const lines = wrapText(ctx, text || '', w - mx * 2 - 24);
  const total = lines.reduce((a, l) => a + [...l].length, 0);
  let left = Math.floor(total * Math.max(0, Math.min(1, progress)) + (progress >= 1 ? 1 : 0));
  ctx.fillStyle = COLORS.black;
  for (let i = 0; i < lines.length && left > 0; i++) {
    const chars = [...lines[i]], shown = chars.slice(0, left).join('');
    ctx.fillText(shown, textX, textY + i * lh);
    left -= chars.length;
  }
  // 다음 표시(▼ 깜박임)
  if (progress >= 1) {
    const a = 0.45 + 0.55 * Math.abs(Math.sin(t * 3));
    ctx.fillStyle = `rgba(181,52,44,${a})`; ctx.beginPath();
    const bx = w - mx, by = h - 22 + Math.sin(t * 5) * 1.5;
    ctx.moveTo(bx - 8, by - 6); ctx.lineTo(bx + 8, by - 6); ctx.lineTo(bx, by + 6); ctx.closePath(); ctx.fill();
  }
  ctx.restore();
}
