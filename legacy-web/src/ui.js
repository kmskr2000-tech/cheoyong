// Dialogs, menus, HUD and screen-space text. Drawn at native canvas resolution
// (960x540) so Korean text stays legible.
import { G, BAL, SCALE, VIEW_W, VIEW_H } from './state.js';
import { input } from './input.js';
import { sfx } from './audio.js';
import { SPR, PORTRAIT, C, drawTalismanIcon } from './gfx.js';
import { TextPop } from './entities.js';

export const W = VIEW_W * SCALE, H = VIEW_H * SCALE;
export const FONT = "'Noto Sans KR','Noto Sans CJK KR','Apple SD Gothic Neo','Malgun Gothic','Noto Sans CJK JP',sans-serif";
export const SERIF = "'Noto Serif KR','Noto Serif CJK KR','Nanum Myeongjo','Batang','Noto Serif CJK JP',serif";

export function font(size, bold = false, serif = false) { return `${bold ? 'bold ' : ''}${size}px ${serif ? SERIF : FONT}`; }

export function wrap(ctx, text, maxW) {
  const out = [];
  for (const para of String(text).split('\n')) {
    let line = '';
    for (const ch of para) {
      if (ctx.measureText(line + ch).width > maxW && line) {
        // prefer breaking at the last space
        const sp = line.lastIndexOf(' ');
        if (sp > line.length * 0.6) { out.push(line.slice(0, sp)); line = line.slice(sp + 1) + ch; }
        else { out.push(line); line = ch; }
      } else line += ch;
    }
    out.push(line);
  }
  return out;
}

export function panel(ctx, x, y, w, h, alpha = 0.92) {
  ctx.save();
  ctx.globalAlpha = alpha;
  ctx.fillStyle = '#0d1226'; ctx.fillRect(x, y, w, h);
  ctx.globalAlpha = 1;
  ctx.strokeStyle = C.goldD; ctx.lineWidth = 2; ctx.strokeRect(x + 1, y + 1, w - 2, h - 2);
  ctx.strokeStyle = 'rgba(184,150,74,0.35)'; ctx.lineWidth = 1; ctx.strokeRect(x + 6, y + 6, w - 12, h - 12);
  // corner knots (금관 장식 느낌)
  ctx.fillStyle = C.gold;
  for (const [cx, cy] of [[x + 4, y + 4], [x + w - 8, y + 4], [x + 4, y + h - 8], [x + w - 8, y + h - 8]]) ctx.fillRect(cx, cy, 4, 4);
  ctx.restore();
}

// ------------------------------------------------------------ dialog
// say([{n, t, p}] | string[]) -> Promise
export function say(lines) {
  const ls = lines.map((l) => (typeof l === 'string' ? { t: l } : l));
  return new Promise((res) => {
    G.dialog = { lines: ls, i: 0, chars: 0, res };
  });
}
// choose(prompt, options[], {cancel}) -> Promise<index | -1>
export function choose(prompt, options, opt = {}) {
  return new Promise((res) => {
    G.menu = { prompt, options: options.map((o) => (typeof o === 'string' ? { label: o } : o)), sel: 0, res, cancel: opt.cancel !== false, title: opt.title };
    while (G.menu.options[G.menu.sel] && G.menu.options[G.menu.sel].disabled && G.menu.sel < G.menu.options.length - 1) G.menu.sel++;
  });
}

export function updateDialog(dt) {
  const d = G.dialog;
  if (!d) return false;
  const line = d.lines[d.i];
  const full = line.t.length;
  d.chars = Math.min(full, d.chars + dt * 45);
  if (input.pressed('ok')) {
    if (d.chars < full) d.chars = full;
    else {
      d.i++; d.chars = 0; sfx('blip');
      if (d.i >= d.lines.length) { G.dialog = null; input.flush(); d.res(); }
    }
  }
  return true;
}

export function updateMenu() {
  const m = G.menu;
  if (!m) return false;
  const n = m.options.length;
  const move = (dir) => {
    for (let k = 0; k < n; k++) {
      m.sel = (m.sel + dir + n) % n;
      if (!m.options[m.sel].disabled) break;
    }
    sfx('blip');
  };
  if (input.pressed('up')) move(-1);
  if (input.pressed('down')) move(1);
  if (input.pressed('ok') && !(input.pressed('cancel') && !input.pressed('ok'))) {
    const o = m.options[m.sel];
    if (o && !o.disabled) { G.menu = null; sfx('select'); input.flush(); m.res(m.sel); return true; }
    sfx('denied');
  } else if (m.cancel && (input.pressed('cancel'))) {
    G.menu = null; sfx('blip'); input.flush(); m.res(-1);
  }
  return true;
}

export function drawDialog(ctx) {
  const d = G.dialog;
  if (!d) return;
  const line = d.lines[d.i];
  const x = 40, y = H - 150, w = W - 80, h = 128;
  panel(ctx, x, y, w, h);
  let tx = x + 24;
  if (line.p && (PORTRAIT[line.p] || SPR[line.p])) {
    ctx.fillStyle = '#060814'; ctx.fillRect(x + 16, y + 16, 96, 96);
    ctx.imageSmoothingEnabled = false;
    const s = PORTRAIT[line.p] || SPR[line.p];
    const sc = PORTRAIT[line.p] ? 2 : Math.floor(80 / Math.max(s.width, s.height)) || 2;
    ctx.save(); ctx.beginPath(); ctx.rect(x + 16, y + 16, 96, 96); ctx.clip();
    const bg = ctx.createRadialGradient(x + 64, y + 50, 4, x + 64, y + 64, 70);
    bg.addColorStop(0, '#1c2236'); bg.addColorStop(1, '#05060c');
    ctx.fillStyle = bg; ctx.fillRect(x + 16, y + 16, 96, 96);
    ctx.drawImage(s, Math.round(x + 64 - s.width * sc / 2), PORTRAIT[line.p] ? y + 16 : Math.round(y + 64 - s.height * sc / 2), s.width * sc, s.height * sc);
    ctx.restore();
    ctx.strokeStyle = C.goldD; ctx.strokeRect(x + 16.5, y + 16.5, 95, 95);
    tx = x + 128;
  }
  if (line.n) {
    ctx.font = font(18, true, true);
    ctx.fillStyle = C.goldL;
    ctx.fillText(line.n, tx, y + 34);
  }
  ctx.font = font(19);
  ctx.fillStyle = '#ece6d6';
  const shown = line.t.slice(0, Math.floor(d.chars));
  const rows = wrap(ctx, shown, w - (tx - x) - 30);
  rows.slice(0, 3).forEach((r, i) => ctx.fillText(r, tx, y + (line.n ? 64 : 44) + i * 26));
  if (d.chars >= line.t.length && Math.sin(G.time * 6) > 0) {
    ctx.fillStyle = C.gold; ctx.fillText('▼', x + w - 36, y + h - 18);
  }
}

export function drawMenu(ctx) {
  const m = G.menu;
  if (!m) return;
  ctx.font = font(20);
  const optW = Math.max(320, ...m.options.map((o) => ctx.measureText(o.label + (o.right || '')).width + 120));
  const w = Math.min(W - 80, optW);
  const rowH = 34;
  const promptRows = m.prompt ? wrap(ctx, m.prompt, w - 48) : [];
  const h = 40 + promptRows.length * 26 + m.options.length * rowH + (m.options[m.sel]?.desc ? 40 : 10);
  const x = (W - w) / 2, y = Math.max(20, (H - h) / 2 - 30);
  panel(ctx, x, y, w, h, 0.96);
  // hit rects for touch (touch.js reads them, so taps match exactly what is drawn)
  m.hit = { x, y, w, h, rows: [] };
  let yy = y + 36;
  if (m.title) { ctx.font = font(20, true, true); ctx.fillStyle = C.goldL; ctx.fillText(m.title, x + 24, yy); yy += 30; }
  ctx.font = font(18);
  ctx.fillStyle = '#c8c0b0';
  promptRows.forEach((r) => { ctx.fillText(r, x + 24, yy); yy += 26; });
  yy += 6;
  m.options.forEach((o, i) => {
    const sel = i === m.sel;
    m.hit.rows.push([yy - 25, yy - 25 + rowH]);
    if (sel) { ctx.fillStyle = 'rgba(184,150,74,0.22)'; ctx.fillRect(x + 14, yy - 23, w - 28, rowH - 4); }
    ctx.font = font(20, sel);
    ctx.fillStyle = o.disabled ? '#5a5a66' : sel ? '#fff4d0' : '#d8d0c0';
    ctx.fillText((sel ? '▶ ' : '   ') + o.label, x + 24, yy);
    if (o.right) { ctx.textAlign = 'right'; ctx.fillText(o.right, x + w - 28, yy); ctx.textAlign = 'left'; }
    yy += rowH;
  });
  const desc = m.options[m.sel]?.desc;
  if (desc) { ctx.font = font(16); ctx.fillStyle = '#9fb0d0'; ctx.fillText(desc, x + 24, yy + 4); }
}

// ------------------------------------------------------------ HUD
function bar(ctx, x, y, w, h, v, max, col, bg = '#1a1010') {
  ctx.fillStyle = '#05060a'; ctx.fillRect(x - 2, y - 2, w + 4, h + 4);
  ctx.fillStyle = bg; ctx.fillRect(x, y, w, h);
  ctx.fillStyle = col; ctx.fillRect(x, y, Math.max(0, Math.round(w * Math.min(1, v / max))), h);
  ctx.fillStyle = 'rgba(255,255,255,0.15)'; ctx.fillRect(x, y, Math.max(0, Math.round(w * Math.min(1, v / max))), Math.max(1, h / 3));
}

export function questLines() {
  const f = G.flags, out = [];
  if (f.cleared) return ['제1장 완료 — 자유롭게 둘러보세요'];
  if (!f.q_main) out.push('◆ 촌주 박노인과 이야기하기');
  else if (!f.boss_result) {
    if (!f.entered_dungeon) out.push('◆ 역병의 진원: 동쪽 산길 끝 폐가로');
    else if (!f.reached_f2) out.push('◆ 폐가를 조사하라 (2층 계단 찾기)');
    else out.push('◆ 폐가 최심부로');
  }
  if (f.q_imp === 1) out.push(`◇ 퇴마: 산길의 역귀 졸개 ${f.q_imp_count || 0}/4`);
  if (f.q_imp === 2) out.push('◇ 퇴마: 게시판에 보고하기');
  if (f.q_ghost === 1) out.push(f.met_ghost ? '◇ 한풀이: 산길 봉분 근처에서 토우 찾기' : '◇ 한풀이: 폐가 1층의 우는 아이');
  if (f.q_ghost === 2) out.push('◇ 한풀이: 토우를 아이 원혼에게');
  return out;
}

export function drawHUD(ctx, lvl) {
  const p = lvl.player;
  if (!p) return;
  const s = G.stats;
  // top-left stats panel
  ctx.save();
  ctx.globalAlpha = 0.8; ctx.fillStyle = '#080b18'; ctx.fillRect(10, 10, 300, 98); ctx.globalAlpha = 1;
  ctx.strokeStyle = 'rgba(184,150,74,0.5)'; ctx.strokeRect(10.5, 10.5, 300, 98);
  ctx.font = font(15, true); ctx.fillStyle = C.goldL; ctx.fillText(`처용  Lv.${s.lv}`, 20, 30);
  ctx.font = font(13); ctx.fillStyle = '#c8c0b0'; ctx.textAlign = 'right';
  ctx.fillText(`엽전 ${s.money}냥`, 300, 30); ctx.textAlign = 'left';
  ctx.font = font(12); ctx.fillStyle = '#e8c8c0'; ctx.fillText('기력', 20, 50);
  bar(ctx, 58, 41, 200, 10, s.hp, s.maxHp, '#d84a3a');
  ctx.fillStyle = '#e8e2d0'; ctx.fillText(`${Math.ceil(s.hp)}/${s.maxHp}`, 264, 50);
  ctx.fillStyle = '#a8c8f0'; ctx.fillText('소리', 20, 68);
  bar(ctx, 58, 60, 200, 8, p.sori, 100, '#4a9ae8', '#0a1628');
  ctx.fillStyle = '#f0d890'; ctx.fillText('신명', 20, 85);
  const full = p.sin >= 100;
  bar(ctx, 58, 77, 200, 8, p.sin, 100, full ? (Math.sin(G.time * 8) > 0 ? '#ffe080' : '#e0b040') : '#b8964a', '#1a1408');
  if (full) { ctx.fillStyle = '#ffe080'; ctx.fillText('F 처용무', 264, 85); }
  ctx.fillStyle = '#8a8070'; ctx.fillText('덕망', 20, 101);
  bar(ctx, 58, 96, 200, 3, s.exp, BAL.expToNext(s.lv), '#c8b8e0', '#14101a');
  ctx.restore();

  // buffs row
  let bx = 20;
  const buff = (label, t, col) => { ctx.font = font(12, true); ctx.fillStyle = col; ctx.fillText(`${label} ${Math.ceil(t)}`, bx, 126); bx += ctx.measureText(`${label} ${Math.ceil(t)}`).width + 14; };
  if (p.songT > 0) buff('처용가', p.songT, C.goldL);
  if (p.shield > 0) buff('수호부', p.shield, '#f0e090');
  if (p.heightT > 0) buff('신명 고조', p.heightT, '#ffd0a0');
  if (p.parryBonus) buff('다음 베기 200%', 0, '#ffffff');

  // talisman bar (bottom-left)
  const kinds = ['fire', 'bind', 'guard', 'thunder', 'charm'];
  const names = { fire: '화염', bind: '결박', guard: '수호', thunder: '뇌성', charm: '현혹' };
  const cur = G.tal.unlocked[G.tal.idx % G.tal.unlocked.length];
  ctx.save();
  ctx.globalAlpha = 0.8; ctx.fillStyle = '#080b18'; ctx.fillRect(10, H - 92, 300, 82); ctx.globalAlpha = 1;
  ctx.strokeStyle = 'rgba(184,150,74,0.5)'; ctx.strokeRect(10.5, H - 91.5, 300, 82);
  kinds.forEach((k, i) => {
    const x = 22 + i * 56, y = H - 84;
    const unlocked = G.tal.unlocked.includes(k);
    if (k === cur) { ctx.fillStyle = 'rgba(255,224,128,0.25)'; ctx.fillRect(x - 6, y - 4, 40, 70); ctx.strokeStyle = C.goldL; ctx.strokeRect(x - 5.5, y - 3.5, 39, 69); }
    ctx.globalAlpha = unlocked ? 1 : 0.25;
    drawTalismanIcon(ctx, x + 4, y, k, 2);
    ctx.globalAlpha = 1;
    ctx.font = font(12, k === cur); ctx.fillStyle = unlocked ? (p.sori >= (BAL.costs[k] || 999) ? '#e8e2d0' : '#7a7a88') : '#55556a';
    ctx.textAlign = 'center';
    ctx.fillText(unlocked ? names[k] : '잠김', x + 14, y + 44);
    if (unlocked) { ctx.font = font(11); ctx.fillStyle = '#7ab0e8'; ctx.fillText(`${BAL.costs[k]}`, x + 14, y + 58); }
    ctx.textAlign = 'left';
  });
  ctx.restore();
  // items + song (bottom, right of talismans)
  ctx.save();
  ctx.globalAlpha = 0.8; ctx.fillStyle = '#080b18'; ctx.fillRect(318, H - 50, 420, 40); ctx.globalAlpha = 1;
  ctx.strokeStyle = 'rgba(184,150,74,0.5)'; ctx.strokeRect(318.5, H - 49.5, 420, 40);
  ctx.font = font(14);
  const songReady = !G.encounter.songUsed;
  ctx.fillStyle = songReady ? C.goldL : '#6a6a78';
  ctx.fillText(`V 처용가 ${songReady ? '○' : '×'}`, 330, H - 24);
  ctx.fillStyle = '#d8d0c0';
  ctx.fillText(`1 인삼정기탕×${G.items.insam}`, 440, H - 24);
  ctx.fillText(`2 구기자환×${G.items.gugija}`, 556, H - 24);
  ctx.fillText(`3 정화부×${G.items.jeonghwa}`, 660, H - 24);
  ctx.restore();

  // quest tracker (top-right)
  const ql = questLines();
  if (ql.length) {
    ctx.font = font(14);
    const qw = Math.max(...ql.map((l) => ctx.measureText(l).width)) + 28;
    ctx.save(); ctx.globalAlpha = 0.75; ctx.fillStyle = '#080b18'; ctx.fillRect(W - qw - 10, 10, qw, 14 + ql.length * 22); ctx.restore();
    ql.forEach((l, i) => { ctx.fillStyle = l.startsWith('◆') ? C.goldL : '#c8d0e0'; ctx.fillText(l, W - qw + 4, 30 + i * 22); });
  }

  // boss bar
  const b = lvl.boss;
  if (b && G.flags.boss_fight && !b.dead) {
    const bw = 520, x = (W - bw) / 2, y = H - 110;
    ctx.font = font(16, true, true); ctx.fillStyle = '#d8f0c0'; ctx.textAlign = 'center';
    ctx.fillText(`${b.name}${b.phase === 2 ? ' — 탁기 폭주' : ''}`, W / 2, y - 8); ctx.textAlign = 'left';
    bar(ctx, x, y, bw, 12, b.hp, b.maxHp, '#c03a3a');
    bar(ctx, x, y + 18, bw, 6, b.pur, b.purMax, '#e8d070', '#10203a');
    ctx.font = font(11); ctx.fillStyle = '#e8d070'; ctx.fillText(`정화 ${Math.floor(b.pur / b.purMax * 100)}%`, x + bw + 8, y + 25);
  }

  // interaction prompt
  if (!G.dialog && !G.menu && !G.scriptLock) {
    const it = lvl.nearestInteractable(p);
    if (it && !lvl.enemies.some((e) => !e.dead && e.aggro)) {
      const sx = (it.x - lvl.cam.x) * SCALE, sy = (it.y - 30 - lvl.cam.y) * SCALE;
      const label = `${G.touch ? "▶" : "Z"}  ${it.label}`;
      ctx.font = font(14, true);
      const tw = ctx.measureText(label).width + 16;
      ctx.fillStyle = 'rgba(8,11,24,0.85)'; ctx.fillRect(sx - tw / 2, sy - 18, tw, 24);
      ctx.strokeStyle = C.goldD; ctx.strokeRect(sx - tw / 2 + 0.5, sy - 17.5, tw, 24);
      ctx.fillStyle = '#fff0c0'; ctx.textAlign = 'center'; ctx.fillText(label, sx, sy); ctx.textAlign = 'left';
    }
  }
}

export function drawWorldText(ctx, lvl) {
  for (const f of lvl.fx) {
    if (!(f instanceof TextPop)) continue;
    const sx = (f.x - lvl.cam.x) * SCALE, sy = (f.y - lvl.cam.y) * SCALE;
    ctx.globalAlpha = Math.min(1, f.ttl / f.max * 2);
    ctx.font = font(f.big ? 22 : 15, true, f.big);
    ctx.textAlign = 'center';
    ctx.fillStyle = '#05060a'; ctx.fillText(f.text, sx + 2, sy + 2);
    ctx.fillStyle = f.color; ctx.fillText(f.text, sx, sy);
    ctx.textAlign = 'left';
    ctx.globalAlpha = 1;
  }
}

export function drawToasts(ctx, dt) {
  G.toasts = G.toasts.filter((t) => (t.t -= dt) > 0);
  G.toasts.forEach((t, i) => {
    ctx.globalAlpha = Math.min(1, t.t * 2);
    ctx.font = font(17, true);
    const tw = ctx.measureText(t.text).width + 30;
    const y = 150 + i * 34;
    ctx.fillStyle = 'rgba(8,11,24,0.82)'; ctx.fillRect((W - tw) / 2, y - 22, tw, 30);
    ctx.fillStyle = t.color; ctx.textAlign = 'center'; ctx.fillText(t.text, W / 2, y); ctx.textAlign = 'left';
    ctx.globalAlpha = 1;
  });
  if (G.banner) {
    G.banner.t -= dt;
    const a = Math.min(1, G.banner.t, (3 - G.banner.t) * 2);
    if (G.banner.t <= 0) G.banner = null;
    else {
      ctx.globalAlpha = Math.max(0, a);
      ctx.font = font(30, true, true); ctx.textAlign = 'center';
      ctx.fillStyle = '#05060a'; ctx.fillText(G.banner.text, W / 2 + 2, 92);
      ctx.fillStyle = '#efe4c4'; ctx.fillText(G.banner.text, W / 2, 90);
      if (G.banner.sub) { ctx.font = font(15, false, true); ctx.fillStyle = C.gold; ctx.fillText(G.banner.sub, W / 2, 116); }
      ctx.textAlign = 'left'; ctx.globalAlpha = 1;
    }
  }
}
