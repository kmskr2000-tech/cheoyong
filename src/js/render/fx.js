// 입자 · 판정 글자 · 번쩍임 · 물결. 이 모듈만 상태(입자 목록)를 가진다. 입자 총수 < 400.
import { COLORS } from './paper.js';
import { FONT } from './text.js';

const TAU = Math.PI * 2, MAX = 380;
let parts = [], texts = [], ripples = [], flashes = [];
let seed = 12345;
const rnd = () => { seed = (seed * 1664525 + 1013904223) >>> 0; return seed / 4294967296; };
const rr = (a, b) => a + (b - a) * rnd();

function add(p) { if (parts.length < MAX) parts.push(p); }
// kind: spark(먹 불꽃) soft(부드러운 빛) smoke(연기) drop(먹물 방울) blot(먹 얼룩) petal(꽃잎)
const PETALS = ['#e8697a', '#f2a6b0', '#f6dfe0', '#d9a441'];
const PEACH = ['#f2a6b0', '#f8c9d0', '#fbe3e6'];

export const fx = {
  burst(x, y, kind) {
    switch (kind) {
      case 'jeol': // 절: 먹 불꽃이 사방으로 튄다 + 금빛 알갱이
        for (let i = 0; i < 16; i++) { const a = rnd() * TAU, s = rr(140, 340); add({ k: 'spark', x, y, vx: Math.cos(a) * s, vy: Math.sin(a) * s, life: rr(0.22, 0.45), max: 0.45, s: rr(2, 3.4), c: COLORS.black, drag: 4 }); }
        for (let i = 0; i < 7; i++) { const a = rnd() * TAU, s = rr(60, 180); add({ k: 'spark', x, y, vx: Math.cos(a) * s, vy: Math.sin(a) * s, life: rr(0.3, 0.6), max: 0.6, s: rr(1.6, 2.6), c: '#f0c24a', drag: 3 }); }
        add({ k: 'soft', x, y, vx: 0, vy: 0, life: 0.28, max: 0.28, s: 26, c: '255,214,130', a: 0.5, grow: 1.6, drag: 0 });
        break;
      case 'jang': // 장: 부드러운 빛무리
        for (let i = 0; i < 9; i++) { const a = rnd() * TAU, s = rr(20, 90); add({ k: 'soft', x, y, vx: Math.cos(a) * s, vy: Math.sin(a) * s - 20, life: rr(0.4, 0.7), max: 0.7, s: rr(8, 16), c: i % 2 ? '240,178,90' : '217,164,65', a: 0.38, grow: 1.4, drag: 2 }); }
        break;
      case 'bak': // 박: 잿빛 연기
        for (let i = 0; i < 8; i++) add({ k: 'smoke', x: x + rr(-8, 8), y: y + rr(-6, 6), vx: rr(-24, 24), vy: rr(-44, -14), life: rr(0.5, 0.9), max: 0.9, s: rr(7, 12), c: '118,108,100', a: 0.42, grow: 2.1, drag: 1.5 });
        break;
      case 'miss': // 놓침: 어두운 먹물 튐
        add({ k: 'blot', x, y, vx: 0, vy: 0, life: 0.7, max: 0.7, s: 15, c: COLORS.shadow, a: 0.85, drag: 0 });
        for (let i = 0; i < 13; i++) { const a = rnd() * TAU, s = rr(60, 230); add({ k: 'drop', x, y, vx: Math.cos(a) * s, vy: Math.sin(a) * s - 40, ay: 520, life: rr(0.4, 0.8), max: 0.8, s: rr(1.8, 4.6), c: COLORS.shadow, drag: 2.2 }); }
        break;
      case 'mask': // 탈 걸림: 꽃잎이 흩날린다
        for (let i = 0; i < 20; i++) { const a = rnd() * TAU, s = rr(40, 190); add({ k: 'petal', x, y, vx: Math.cos(a) * s, vy: Math.sin(a) * s - 90, ay: 70, life: rr(1.1, 1.9), max: 1.9, s: rr(4, 7), c: PETALS[(rnd() * PETALS.length) | 0], rot: rnd() * TAU, vr: rr(-5, 5), ph: rnd() * TAU, drag: 1.6 }); }
        break;
      case 'petal': // 꽃잎 몇 장
        for (let i = 0; i < 8; i++) add({ k: 'petal', x: x + rr(-14, 14), y: y + rr(-10, 4), vx: rr(-40, 40), vy: rr(-70, -10), ay: 55, life: rr(1.2, 2), max: 2, s: rr(3.5, 6), c: PEACH[(rnd() * PEACH.length) | 0], rot: rnd() * TAU, vr: rr(-4, 4), ph: rnd() * TAU, drag: 1.2 });
        break;
    }
  },
  text(x, y, str, color) { if (texts.length < 24) texts.push({ x, y, str, color: color || COLORS.shadow, age: 0, life: 0.95 }); },
  flash(color, dur = 0.25) { if (flashes.length < 4) flashes.push({ color: color || COLORS.white, dur: Math.max(0.05, dur), age: 0 }); },
  ripple(x, y) { if (ripples.length < 12) ripples.push({ x, y, age: 0, life: 0.7 }); },
  update(dt) {
    for (let i = parts.length - 1; i >= 0; i--) {
      const p = parts[i]; p.life -= dt;
      if (p.life <= 0) { parts[i] = parts[parts.length - 1]; parts.pop(); continue; }
      const d = Math.exp(-(p.drag || 0) * dt);
      p.vx *= d; p.vy *= d; p.vy += (p.ay || 0) * dt;
      if (p.k === 'petal') { p.vx += Math.sin((p.max - p.life) * 7 + p.ph) * 60 * dt; p.rot += p.vr * dt; }
      p.x += p.vx * dt; p.y += p.vy * dt;
    }
    for (let i = texts.length - 1; i >= 0; i--) { texts[i].age += dt; if (texts[i].age >= texts[i].life) texts.splice(i, 1); }
    for (let i = ripples.length - 1; i >= 0; i--) { ripples[i].age += dt; if (ripples[i].age >= ripples[i].life) ripples.splice(i, 1); }
    for (let i = flashes.length - 1; i >= 0; i--) { flashes[i].age += dt; if (flashes[i].age >= flashes[i].dur) flashes.splice(i, 1); }
  },
  draw(ctx) {
    ctx.save();
    for (const r of ripples) { // 물결 고리 두 겹
      const k = r.age / r.life;
      for (let j = 0; j < 2; j++) {
        const kk = k - j * 0.18; if (kk <= 0) continue;
        ctx.strokeStyle = `rgba(26,20,16,${0.5 * (1 - kk)})`; ctx.lineWidth = 3.2 * (1 - kk) + 0.6;
        ctx.beginPath(); ctx.ellipse(r.x, r.y, 14 + 90 * kk, (14 + 90 * kk) * 0.45, 0, 0, TAU); ctx.stroke();
      }
    }
    for (const p of parts) {
      const k = 1 - p.life / p.max; // 0→1
      switch (p.k) {
        case 'spark': {
          ctx.strokeStyle = p.c; ctx.globalAlpha = Math.min(1, p.life / p.max * 1.6); ctx.lineWidth = p.s * (1 - k * 0.6); ctx.lineCap = 'round';
          ctx.beginPath(); ctx.moveTo(p.x, p.y); ctx.lineTo(p.x - p.vx * 0.045, p.y - p.vy * 0.045); ctx.stroke(); break;
        }
        case 'soft': case 'smoke': {
          const r = p.s * (1 + (p.grow || 1) * k);
          ctx.fillStyle = `rgba(${p.c},${p.a * (1 - k) * (1 - k * 0.3)})`; ctx.beginPath(); ctx.arc(p.x, p.y, r, 0, TAU); ctx.fill();
          if (p.k === 'soft') { ctx.fillStyle = `rgba(255,240,200,${p.a * 0.6 * (1 - k)})`; ctx.beginPath(); ctx.arc(p.x, p.y, r * 0.5, 0, TAU); ctx.fill(); }
          break;
        }
        case 'drop': ctx.globalAlpha = Math.min(1, p.life / p.max * 2); ctx.fillStyle = p.c; ctx.beginPath(); ctx.arc(p.x, p.y, p.s * (1 - k * 0.3), 0, TAU); ctx.fill(); break;
        case 'blot': { // 먹 얼룩: 불규칙한 번진 원
          ctx.globalAlpha = p.a * Math.min(1, p.life / p.max * 1.8); ctx.fillStyle = p.c; ctx.beginPath();
          for (let i = 0; i < 10; i++) { const a = (i / 10) * TAU, r = p.s * (0.8 + 0.5 * Math.sin(i * 12.9898) ) * (0.6 + 0.4 * Math.min(1, k * 5)); const px = p.x + Math.cos(a) * r, py = p.y + Math.sin(a) * r * 0.8; i ? ctx.lineTo(px, py) : ctx.moveTo(px, py); }
          ctx.closePath(); ctx.fill(); break;
        }
        case 'petal': {
          ctx.globalAlpha = Math.min(1, p.life / p.max * 2.2); ctx.fillStyle = p.c;
          ctx.save(); ctx.translate(p.x, p.y); ctx.rotate(p.rot);
          ctx.beginPath(); ctx.ellipse(0, 0, p.s, p.s * (0.45 + 0.4 * Math.abs(Math.sin(p.rot * 2))), 0, 0, TAU); ctx.fill(); ctx.restore(); break;
        }
      }
      ctx.globalAlpha = 1;
    }
    // 판정 글자
    ctx.textAlign = 'center'; ctx.textBaseline = 'middle'; ctx.lineJoin = 'round';
    for (const tx of texts) {
      const k = tx.age / tx.life, pop = 1 + 0.55 * Math.pow(Math.max(0, 1 - tx.age / 0.12), 2);
      const y = tx.y - 52 * (1 - Math.pow(1 - k, 2)), a = k > 0.65 ? 1 - (k - 0.65) / 0.35 : 1;
      ctx.save(); ctx.globalAlpha = a; ctx.translate(tx.x, y); ctx.scale(pop, pop);
      ctx.font = `34px ${FONT}`;
      ctx.lineWidth = 6; ctx.strokeStyle = 'rgba(243,233,210,0.9)'; ctx.strokeText(tx.str, 0, 0);
      ctx.fillStyle = tx.color; ctx.fillText(tx.str, 0, 0);
      ctx.restore();
    }
    // 화면 번쩍임(맨 위)
    for (const f of flashes) {
      const k = f.age / f.dur; ctx.globalAlpha = 0.5 * (1 - k) * (1 - k); ctx.fillStyle = f.color; ctx.fillRect(-300, -300, 1700, 1100);
    }
    ctx.restore();
  },
  clear() { parts = []; texts = []; ripples = []; flashes = []; },
  get count() { return parts.length; },
};
