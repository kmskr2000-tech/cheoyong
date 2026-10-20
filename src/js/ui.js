// UI: HUD, touch buttons (one glowing at a time), dialogue, verse banner, shop, pause menu, minimap.
'use strict';
G.ui = (() => {
  const U = { dialog: null, banner: null, shop: null, menu: false, glow: null, toasts: [] };
  const FONT = '"Noto Serif KR", "Nanum Myeongjo", serif';
  const SANS = '"Noto Sans KR", sans-serif';
  const isTouch = () => G.input.lastTouch || ('ontouchstart' in window && !G.input.anyKey) || G.params.has('touch');

  // ---------- dialogue ----------
  // lines: [speaker, text, onShow?] ; speaker '@' = narration, '@verse' = verse banner (text = verse number)
  U.say = (lines, onDone) => {
    U.dialog = { lines, i: -1, onDone, t: 0, shown: 0 };
    U.nextLine();
  };
  U.nextLine = () => {
    const d = U.dialog;
    d.i++;
    if (d.i >= d.lines.length) { U.dialog = null; d.onDone && d.onDone(); return; }
    const [sp, text, fn] = d.lines[d.i];
    d.t = 0; d.shown = 0;
    if (sp === '@verse') {
      const n = text;
      G.game.flags['verse' + n] = true;
      U.banner = { n, t: 0 };
      G.audio.sfx('verse');
      d.waitBanner = true;
      return;
    }
    d.waitBanner = false;
    fn && fn();
  };
  U.updateDialog = (dt) => {
    const d = U.dialog;
    if (!d) return;
    const inp = G.input;
    const conf = inp.hit('confirm') || inp.hit('interact') || inp.hit('attack') || inp.hit('tap');
    if (d.waitBanner) {
      if (U.banner && U.banner.t > 1.2 && conf) U.banner.t = Math.max(U.banner.t, 3.2);
      if (!U.banner) U.nextLine();
      return;
    }
    const text = d.lines[d.i][1];
    const before = Math.floor(d.shown);
    d.shown = Math.min(text.length, d.shown + dt * 38);
    if (Math.floor(d.shown) !== before && Math.floor(d.shown) % 3 === 0 && d.lines[d.i][0] !== '@') G.audio.sfx('talk');
    d.t += dt;
    if (conf && d.t > 0.15) {
      if (d.shown < text.length) d.shown = text.length;
      else U.nextLine();
    }
  };

  // ---------- shop ----------
  const GOODS = [
    { k: 'yakgwa', name: '약과', desc: '체력 40% 회복', price: 20 },
    { k: 'sikhye', name: '식혜', desc: '기 60 회복', price: 15 },
  ];
  U.openShop = () => { U.shop = { sel: 0, t: 0 }; };
  U.updateShop = () => {
    const s = U.shop, inp = G.input, p = G.game.player;
    s.t += 1 / 60;
    const mv = inp.move();
    if (inp.hit('menu')) { U.shop = null; return; }
    s.cool = (s.cool || 0) - 1 / 60;
    if (Math.abs(mv.y) > 0.5 && s.cool <= 0) { s.sel = (s.sel + (mv.y > 0 ? 1 : -1) + GOODS.length + 1) % (GOODS.length + 1); s.cool = 0.2; G.audio.sfx('ui'); }
    const buy = (i) => {
      if (i === GOODS.length) { U.shop = null; return; }
      const g = GOODS[i];
      if (p.coins < g.price) { U.toast('엽전이 모자라오'); return; }
      p.coins -= g.price; p.items[g.k]++; G.audio.sfx('coin'); U.toast(g.name + ' 하나 샀소');
    };
    for (const b of s.rects || []) if (inp.hit('tap') && U.hitRect(b)) { s.sel = b.i; buy(b.i); return; }
    if (s.t > 0.2 && (inp.hit('confirm') || inp.hit('interact') || inp.hit('attack'))) buy(s.sel);
  };
  U.toast = (s) => { U.toasts.push({ s, t: 0 }); };
  U.hitRect = (r) => {
    const p = G.input.tapPos;
    return p && p.x >= r.x && p.x <= r.x + r.w && p.y >= r.y && p.y <= r.y + r.h;
  };

  // ---------- buttons ----------
  function layoutButtons(vw, vh) {
    const p = G.game.player, f = G.game.flags;
    const B = [];
    // skill ring on the right, like a mobile MMORPG: big attack button, skills around it
    const bx = vw - 70, by = vh - 70;
    if (f.has_attack) {
      B.push({ action: 'attack', x: bx, y: by, r: 46, label: '', icon: 'attack', main: true });
      B.push({ action: 'roll', x: bx - 4, y: by - 112, r: 24, label: '', icon: 'roll', key: 'K' });
    }
    const sk = [['skill1', bx - 104, by + 6, 'U'], ['skill2', bx - 92, by - 62, 'I'], ['skill3', bx - 52, by - 104, 'O']];
    for (const [k, x, y, key] of sk) if (p.skills[k]) B.push({ action: k, x, y, r: 27, icon: k, key, cd: p.cd[k] / G.SKILLS[k].cd, gi: G.SKILLS[k].gi, color: { skill1: '#58d0ff', skill2: '#ff7ad0', skill3: '#3a9cff' }[k] });
    if (f.has_ult) B.push({ action: 'ult', x: bx - 170, y: by + 4, r: 31, icon: 'ult', key: 'L', fill: p.heung / 100, color: '#ffc85a' });
    if (G.game.interactTarget) B.push({ action: 'interact', x: bx - 150, y: by - 92, r: 30, label: G.game.interactTarget.label || '말걸기', icon: 'talk', key: 'E' });
    // top-right icon row
    B.push({ action: 'menu', x: vw - 28, y: 28, r: 19, icon: 'menu', small: true });
    if (p.masks.length > 1) B.push({ action: 'mask', x: vw - 72, y: 28, r: 19, icon: 'mask', small: true, key: 'M' });
    // quick slots under the health bar
    const qx = vw / 2 + 60, qy = vh - 26;
    B.push({ action: 'item1', x: qx, y: qy, r: 18, icon: 'yakgwa', count: p.items.yakgwa, slot: true, key: '1' });
    B.push({ action: 'item2', x: qx + 44, y: qy, r: 18, icon: 'sikhye', count: p.items.sikhye, slot: true, key: '2' });
    return B;
  }

  // ---------- draw helpers ----------
  const bar = (ctx, x, y, w, h, v, max, col, back = 'rgba(0,0,0,0.55)') => {
    ctx.fillStyle = back; ctx.fillRect(x - 1, y - 1, w + 2, h + 2);
    ctx.fillStyle = col; ctx.fillRect(x, y, Math.max(0, (w * v) / max), h);
    ctx.fillStyle = 'rgba(255,255,255,0.18)'; ctx.fillRect(x, y, Math.max(0, (w * v) / max), Math.ceil(h / 3));
  };
  const panel = (ctx, x, y, w, h, a = 0.82) => {
    ctx.fillStyle = `rgba(12,14,30,${a})`; ctx.fillRect(x, y, w, h);
    ctx.strokeStyle = 'rgba(214,180,110,0.85)'; ctx.lineWidth = 2; ctx.strokeRect(x + 1, y + 1, w - 2, h - 2);
    ctx.strokeStyle = 'rgba(214,180,110,0.35)'; ctx.strokeRect(x + 5, y + 5, w - 10, h - 10);
  };
  U.panel = panel;
  const wrap = (ctx, text, maxW) => {
    const out = []; let line = '';
    for (const ch of text) {
      if (ch === '\n') { out.push(line); line = ''; continue; }
      if (ctx.measureText(line + ch).width > maxW && line) { out.push(line); line = ch.trim() ? ch : ''; }
      else line += ch;
    }
    out.push(line);
    return out;
  };
  U.wrap = wrap;

  function drawIcon(ctx, icon, x, y, s) {
    ctx.save(); ctx.translate(x, y); ctx.lineWidth = 2.5; ctx.strokeStyle = '#f3e6c4'; ctx.fillStyle = '#f3e6c4';
    const k = s / 20;
    ctx.scale(k, k);
    ctx.beginPath();
    switch (icon) {
      case 'attack': ctx.moveTo(-10, 8); ctx.quadraticCurveTo(0, -16, 12, -6); ctx.moveTo(-6, 10); ctx.quadraticCurveTo(4, -8, 12, 2); ctx.stroke(); break;
      case 'roll': ctx.arc(0, 0, 9, 0.4, Math.PI * 1.8); ctx.stroke(); ctx.beginPath(); ctx.moveTo(9, -6); ctx.lineTo(9, 2); ctx.lineTo(3, -2); ctx.fill(); break;
      case 'skill1': for (let i = 0; i < 3; i++) { ctx.beginPath(); ctx.arc(-8, 0, 6 + i * 6, -0.7, 0.7); ctx.stroke(); } break;
      case 'skill2': for (let i = 0; i < 3; i++) { ctx.beginPath(); ctx.arc(0, 0, 4 + i * 4, i, i + 4.2); ctx.stroke(); } break;
      case 'skill3': ctx.moveTo(-12, 4); ctx.quadraticCurveTo(-6, -8, 0, 4); ctx.quadraticCurveTo(6, -8, 12, 4); ctx.stroke(); ctx.beginPath(); ctx.moveTo(-12, 10); ctx.quadraticCurveTo(0, 2, 12, 10); ctx.stroke(); break;
      case 'ult': ctx.arc(0, 0, 10, 0, Math.PI * 2); ctx.stroke(); ctx.beginPath(); ctx.arc(-4, -3, 1.6, 0, 7); ctx.arc(4, -3, 1.6, 0, 7); ctx.fill(); ctx.beginPath(); ctx.arc(0, 2, 5, 0.3, Math.PI - 0.3); ctx.stroke(); break;
      case 'talk': ctx.ellipse(0, -2, 11, 8, 0, 0, Math.PI * 2); ctx.stroke(); ctx.beginPath(); ctx.moveTo(-4, 5); ctx.lineTo(-8, 11); ctx.lineTo(1, 6); ctx.fill(); break;
      case 'menu': for (const yy of [-6, 0, 6]) { ctx.fillRect(-9, yy - 1.5, 18, 3); } break;
      case 'mask': ctx.ellipse(0, 0, 9, 11, 0, 0, Math.PI * 2); ctx.stroke(); ctx.beginPath(); ctx.fillStyle = '#ff6a5a'; ctx.arc(-4, 3, 2.5, 0, 7); ctx.arc(4, 3, 2.5, 0, 7); ctx.fill(); break;
      case 'yakgwa': ctx.fillStyle = '#c9822a'; for (let i = 0; i < 8; i++) { const a = (i / 8) * Math.PI * 2; ctx.moveTo(0, 0); ctx.arc(0, 0, 9, a, a + 0.5); } ctx.fill(); ctx.fillStyle = '#7a4a1a'; ctx.beginPath(); ctx.arc(0, 0, 3, 0, 7); ctx.fill(); break;
      case 'sikhye': ctx.fillStyle = '#e8dcc0'; ctx.fillRect(-8, -4, 16, 12); ctx.fillStyle = '#c9b48a'; ctx.fillRect(-8, -4, 16, 3); ctx.strokeRect(-8, -4, 16, 12); break;
    }
    ctx.restore();
  }

  function ring(ctx, x, y, r, glow) {
    // dark lacquer disc with a bronze rim
    const g = ctx.createRadialGradient(x - r * 0.3, y - r * 0.4, r * 0.1, x, y, r);
    g.addColorStop(0, 'rgba(70,64,84,0.92)'); g.addColorStop(1, 'rgba(18,16,26,0.92)');
    ctx.fillStyle = g; ctx.beginPath(); ctx.arc(x, y, r, 0, Math.PI * 2); ctx.fill();
    ctx.lineWidth = 2.5; ctx.strokeStyle = glow ? '#ffe2a0' : '#8a7652';
    ctx.beginPath(); ctx.arc(x, y, r - 1, 0, Math.PI * 2); ctx.stroke();
    ctx.lineWidth = 1; ctx.strokeStyle = 'rgba(255,240,200,0.25)';
    ctx.beginPath(); ctx.arc(x, y, r - 4, Math.PI * 1.1, Math.PI * 1.9); ctx.stroke();
  }

  function drawButtons(ctx, vw, vh) {
    const B = layoutButtons(vw, vh);
    G.input.buttons = B;
    const touch = isTouch();
    const t = G.game.time, p = G.game.player;
    for (const b of B) {
      const glow = U.glow === b.action;
      ctx.save();
      if (glow) {
        const pulse = 0.5 + 0.5 * Math.sin(t * 6);
        ctx.globalCompositeOperation = 'lighter';
        const g = ctx.createRadialGradient(b.x, b.y, b.r * 0.6, b.x, b.y, b.r * 1.9);
        g.addColorStop(0, `rgba(255,220,140,${0.5 + pulse * 0.35})`); g.addColorStop(1, 'rgba(255,200,100,0)');
        ctx.fillStyle = g; ctx.beginPath(); ctx.arc(b.x, b.y, b.r * 1.9, 0, Math.PI * 2); ctx.fill();
        ctx.globalCompositeOperation = 'source-over';
      }
      if (b.slot) {
        ctx.fillStyle = 'rgba(16,14,22,0.75)'; ctx.fillRect(b.x - b.r, b.y - b.r, b.r * 2, b.r * 2);
        ctx.strokeStyle = glow ? '#ffe2a0' : 'rgba(150,130,90,0.8)'; ctx.lineWidth = 1.5; ctx.strokeRect(b.x - b.r + 0.5, b.y - b.r + 0.5, b.r * 2 - 1, b.r * 2 - 1);
      } else ring(ctx, b.x, b.y, b.r, glow);
      // colored skill glow inside the ring
      if (b.color) {
        const g = ctx.createRadialGradient(b.x, b.y, 0, b.x, b.y, b.r * 0.9);
        g.addColorStop(0, b.color + 'cc'); g.addColorStop(1, b.color + '00');
        ctx.globalCompositeOperation = 'lighter'; ctx.fillStyle = g;
        ctx.beginPath(); ctx.arc(b.x, b.y, b.r * 0.9, 0, Math.PI * 2); ctx.fill();
        ctx.globalCompositeOperation = 'source-over';
      }
      if (b.fill != null) {
        ctx.strokeStyle = b.fill >= 1 ? '#ffd27a' : '#ff9ad0'; ctx.lineWidth = 4;
        ctx.beginPath(); ctx.arc(b.x, b.y, b.r + 3, -Math.PI / 2, -Math.PI / 2 + Math.PI * 2 * b.fill); ctx.stroke();
      }
      if (b.cd > 0) {
        ctx.fillStyle = 'rgba(0,0,0,0.6)'; ctx.beginPath(); ctx.moveTo(b.x, b.y); ctx.arc(b.x, b.y, b.r - 2, -Math.PI / 2, -Math.PI / 2 + Math.PI * 2 * b.cd); ctx.fill();
        ctx.font = `bold 13px ${SANS}`; ctx.textAlign = 'center'; ctx.fillStyle = '#fff';
        ctx.fillText((b.cd * G.SKILLS[b.action].cd).toFixed(1), b.x, b.y + 5);
      } else drawIcon(ctx, b.icon, b.x, b.y, b.r * (b.main ? 0.62 : 0.58));
      if (b.gi && p.gi < b.gi) { ctx.fillStyle = 'rgba(0,10,40,0.55)'; ctx.beginPath(); ctx.arc(b.x, b.y, b.r - 2, 0, Math.PI * 2); ctx.fill(); }
      if (b.label) {
        ctx.font = `bold 11px ${SANS}`; ctx.textAlign = 'center';
        stroked(ctx, b.label, b.x, b.y + b.r + 13, '#f3e6c4');
      }
      if (b.key && !touch) {
        ctx.font = `bold 10px ${SANS}`; ctx.textAlign = 'center';
        stroked(ctx, b.key, b.x + b.r * 0.72, b.y + b.r * 0.9, '#d8ccb0');
      }
      if (b.count != null) {
        ctx.font = `bold 12px ${SANS}`; ctx.textAlign = 'right';
        stroked(ctx, String(b.count), b.x + b.r - 2, b.y + b.r - 3, '#fff');
      }
      ctx.restore();
    }
    // floating joystick
    const st = G.input.stick;
    if (touch && st.active) {
      ctx.globalAlpha = 0.55;
      ring(ctx, st.ox, st.oy, 48, false);
      const dx = st.x - st.ox, dy = st.y - st.oy, m = Math.hypot(dx, dy), k = m > 46 ? 46 / m : 1;
      ctx.fillStyle = '#f3e6c4'; ctx.beginPath(); ctx.arc(st.ox + dx * k, st.oy + dy * k, 20, 0, Math.PI * 2); ctx.fill();
      ctx.globalAlpha = 1;
    }
  }

  function stroked(ctx, text, x, y, color, w = 3) {
    ctx.lineJoin = 'round'; ctx.lineWidth = w; ctx.strokeStyle = 'rgba(10,8,14,0.9)';
    ctx.strokeText(text, x, y); ctx.fillStyle = color; ctx.fillText(text, x, y);
  }
  U.stroked = stroked;

  // rounded translucent plate (quest list, top bar)
  function plate(ctx, x, y, w, h, a = 0.55) {
    const r = Math.min(8, h / 2);
    ctx.fillStyle = `rgba(14,12,20,${a})`;
    ctx.beginPath(); ctx.roundRect(x, y, w, h, r); ctx.fill();
  }

  function drawHud(ctx, vw, vh) {
    const g = G.game, p = g.player, f = g.flags;
    // --- top-left: zone name + round minimap ---
    drawMinimap(ctx, vw, vh);
    // --- top-center: currency strip ---
    ctx.font = `bold 13px ${SANS}`;
    const items = [['엽전', String(p.coins), '#ffd25a'], ['구절', g.verseCount() + '/8', '#bfe6ff']];
    if (p.mask) items.push(['탈', p.m.name, p.m.color]);
    let tw = 0; for (const [a, b] of items) tw += ctx.measureText(a + ' ' + b).width + 28;
    let x = vw / 2 - tw / 2;
    plate(ctx, x - 6, 8, tw + 12, 26, 0.5);
    ctx.textAlign = 'left';
    for (const [a, b, c] of items) {
      ctx.fillStyle = c; ctx.beginPath(); ctx.arc(x + 8, 21, 5, 0, Math.PI * 2); ctx.fill();
      stroked(ctx, a + ' ', x + 18, 26, '#d8ccb0', 2);
      stroked(ctx, b, x + 18 + ctx.measureText(a + ' ').width, 26, '#fff', 2);
      x += ctx.measureText(a + ' ' + b).width + 28;
    }
    // --- boss bar under the strip ---
    if (g.boss && !g.boss.dead) {
      const b = g.boss, w = Math.min(420, vw - 360), x0 = vw / 2 - w / 2, y0 = 44;
      plate(ctx, x0 - 8, y0 - 4, w + 16, 34, 0.55);
      ctx.font = `bold 13px ${SANS}`; ctx.textAlign = 'center';
      stroked(ctx, (b.ultVulnerable ? '[처용가로 굴복시키시오] ' : '') + b.def.name, vw / 2, y0 + 11, '#ff9a8a');
      bar(ctx, x0, y0 + 17, w, 7, b.hp, b.maxHp, b.ultVulnerable ? '#ffd27a' : '#d03a3a');
    }
    // --- right: quest tracker ---
    const ob = G.story.objective(f);
    if (ob) {
      const parts = ob.text.split(' — ');
      const head = parts[0], subs = parts[1] ? parts[1].split(' · ') : [];
      const w = Math.min(250, vw * 0.26), x0 = vw - w - 12, y0 = 60;
      const rows = [head, ...subs];
      plate(ctx, x0, y0, w, 14 + rows.length * 22, 0.5);
      ctx.textAlign = 'left';
      rows.forEach((r, i) => {
        const y = y0 + 22 + i * 22;
        if (i === 0) {
          ctx.fillStyle = '#ffcf5a'; ctx.beginPath(); ctx.moveTo(x0 + 10, y - 9); ctx.lineTo(x0 + 18, y - 4); ctx.lineTo(x0 + 10, y + 1); ctx.fill();
          ctx.font = `bold 13px ${SANS}`; stroked(ctx, fit(ctx, '[이야기] ' + r, w - 30), x0 + 24, y, '#ffe08a', 2);
        } else {
          ctx.font = `12px ${SANS}`; stroked(ctx, fit(ctx, r, w - 30), x0 + 24, y, '#e8e0d0', 2);
        }
      });
    }
    // --- bottom-center: level badge, health and gi bars ---
    const bw = Math.min(360, vw * 0.36), bx = vw / 2 - bw / 2, by = vh - 62;
    ctx.textAlign = 'center'; ctx.font = `bold 12px ${SANS}`;
    stroked(ctx, `Lv.${p.lvl} 처용`, bx - 34, by + 12, '#ffe2a0', 2);
    bar(ctx, bx, by, bw, 10, p.hp, p.maxHp, '#6fcf4a', 'rgba(10,10,14,0.7)');
    ctx.font = `bold 10px ${SANS}`; stroked(ctx, `${Math.ceil(p.hp)} / ${p.maxHp}`, vw / 2, by + 9, '#fff', 2);
    bar(ctx, bx, by + 14, bw, 5, p.gi, p.maxGi, '#4cb8ff', 'rgba(10,10,14,0.7)');
    if (f.has_ult) bar(ctx, bx, by + 22, bw, 3, p.heung, 100, p.heung >= 100 ? '#ffd27a' : '#ff9ad0', 'rgba(10,10,14,0.6)');
    bar(ctx, 0, vh - 3, vw, 3, p.exp, p.expNeed(), '#d8c070', 'rgba(0,0,0,0.4)');
    // zone banner
    if (g.zoneBanner && g.zoneBanner.t < 3) {
      const k = g.zoneBanner.t, a = Math.min(1, k * 2, (3 - k) * 1.5);
      ctx.globalAlpha = a; ctx.font = `bold 30px ${FONT}`; ctx.textAlign = 'center';
      stroked(ctx, g.zoneBanner.name, vw / 2, vh * 0.28, '#fff4dc', 5);
      ctx.fillStyle = 'rgba(255,220,150,0.8)'; ctx.fillRect(vw / 2 - 90, vh * 0.28 + 12, 180, 2);
      ctx.globalAlpha = 1;
    }
    // toasts
    for (let i = U.toasts.length - 1; i >= 0; i--) {
      const t = U.toasts[i]; t.t += 1 / 60;
      if (t.t > 2) { U.toasts.splice(i, 1); continue; }
      ctx.globalAlpha = Math.min(1, (2 - t.t) * 2);
      ctx.font = `bold 15px ${SANS}`; ctx.textAlign = 'center';
      stroked(ctx, t.s, vw / 2, vh * 0.62 - i * 22, '#ffe2a0');
      ctx.globalAlpha = 1;
    }
  }
  const fit = (ctx, s, w) => { if (ctx.measureText(s).width <= w) return s; while (s.length > 2 && ctx.measureText(s + '…').width > w) s = s.slice(0, -1); return s + '…'; };

  // objective arrow at the screen edge (in world layer coords)
  U.drawGuide = (ctx, cam, vw, vh) => {
    const g = G.game;
    const ob = G.story.objective(g.flags);
    if (!ob || !ob.target || g.frozen || g.boss) return;
    const tx = ob.target.x - cam.x, ty = ob.target.y - cam.y;
    const px = g.player.x - cam.x, py = g.player.y - cam.y - 40;
    const onScreen = tx > 30 && tx < vw - 30 && ty > 30 && ty < vh - 30;
    const t = g.time;
    if (onScreen) {
      const y = ty - 70 + Math.sin(t * 4) * 5;
      ctx.fillStyle = '#ffd27a';
      ctx.beginPath(); ctx.moveTo(tx, y + 12); ctx.lineTo(tx - 9, y); ctx.lineTo(tx + 9, y); ctx.fill();
      return;
    }
    const a = Math.atan2(ty - py, tx - px);
    const R = Math.min(vw, vh) * 0.32;
    const x = px + Math.cos(a) * R, y = py + Math.sin(a) * R * 0.8;
    ctx.save(); ctx.translate(x, y); ctx.rotate(a);
    ctx.globalAlpha = 0.6 + 0.3 * Math.sin(t * 5);
    ctx.fillStyle = '#ffd27a';
    ctx.beginPath(); ctx.moveTo(16, 0); ctx.lineTo(-6, -10); ctx.lineTo(-2, 0); ctx.lineTo(-6, 10); ctx.fill();
    ctx.restore(); ctx.globalAlpha = 1;
  };

  let mini = null;
  function drawMinimap(ctx, vw, vh) {
    const w = G.world;
    if (!mini) {
      mini = document.createElement('canvas'); mini.width = w.W; mini.height = w.H;
      const m = mini.getContext('2d');
      const COLS = ['#3a8ab0', '#d8c088', '#6a9a48', '#a07a50', '#b8a078', '#3a5a32', '#3a7068', '#6a6058', '#c0a070'];
      for (let y = 0; y < w.H; y++) for (let x = 0; x < w.W; x++) {
        const t = w.terrainAt(x * 32 + 16, y * 32 + 16);
        m.fillStyle = w.solidAt(x * 32 + 16, y * 32 + 16) && t !== 0 && t !== 6 ? '#2e4228' : COLS[t];
        m.fillRect(x, y, 1, 1);
      }
    }
    const R = vw < 700 ? 44 : 58, cx = 14 + R, cy = 30 + R;
    const g = G.game, p = g.player;
    // zone label
    ctx.font = `bold 12px ${SANS}`; ctx.textAlign = 'left';
    ctx.fillStyle = '#6fcf4a'; ctx.beginPath(); ctx.moveTo(14, 11); ctx.lineTo(22, 16); ctx.lineTo(14, 21); ctx.fill();
    stroked(ctx, g.zone ? g.zone.name : '', 26, 21, '#fff', 2);
    ctx.save();
    ctx.beginPath(); ctx.arc(cx, cy, R, 0, Math.PI * 2); ctx.clip();
    const s = 2.6; // minimap pixels per tile
    ctx.imageSmoothingEnabled = false;
    ctx.fillStyle = '#1a2418'; ctx.fillRect(cx - R, cy - R, R * 2, R * 2);
    ctx.drawImage(mini, cx - (p.x / 32) * s, cy - (p.y / 32) * s, w.W * s, w.H * s);
    // npcs and foes
    for (const n of g.npcs) if (!n.hidden) { ctx.fillStyle = '#ffd25a'; ctx.fillRect(cx + ((n.x - p.x) / 32) * s - 1.5, cy + ((n.y - p.y) / 32) * s - 1.5, 3, 3); }
    for (const e of g.enemies) if (!e.dead && e.state !== 'kneel') { ctx.fillStyle = e.def.boss ? '#ff3a3a' : '#ff7a7a'; ctx.fillRect(cx + ((e.x - p.x) / 32) * s - 1.5, cy + ((e.y - p.y) / 32) * s - 1.5, e.def.boss ? 5 : 3, e.def.boss ? 5 : 3); }
    const ob = G.story.objective(g.flags);
    if (ob && ob.target) {
      const ox = G.clamp(cx + ((ob.target.x - p.x) / 32) * s, cx - R + 6, cx + R - 6), oy = G.clamp(cy + ((ob.target.y - p.y) / 32) * s, cy - R + 6, cy + R - 6);
      ctx.fillStyle = '#ffcf5a'; ctx.beginPath(); ctx.arc(ox, oy, 4, 0, Math.PI * 2); ctx.fill();
    }
    ctx.restore();
    // player arrow
    ctx.save(); ctx.translate(cx, cy); ctx.rotate(p.face + Math.PI / 2);
    ctx.fillStyle = '#fff'; ctx.beginPath(); ctx.moveTo(0, -6); ctx.lineTo(4.5, 5); ctx.lineTo(-4.5, 5); ctx.fill(); ctx.restore();
    // bronze frame
    ctx.lineWidth = 4; ctx.strokeStyle = '#6a5838'; ctx.beginPath(); ctx.arc(cx, cy, R + 1, 0, Math.PI * 2); ctx.stroke();
    ctx.lineWidth = 1.5; ctx.strokeStyle = '#d8b878'; ctx.beginPath(); ctx.arc(cx, cy, R + 3, 0, Math.PI * 2); ctx.stroke();
  }

  function portrait(ctx, sprite, x, y, size) {
    const c = G.assets.chars[sprite];
    if (!c) return;
    const f = G.assets.frame(sprite, 'idle', 'south', 0);
    // crop the head and shoulders
    const cx = c.cx ?? c.w / 2, top = c.top ?? 0;
    const crop = Math.max(28, Math.round(((c.foot ?? c.h) - top) * 0.5));
    ctx.imageSmoothingEnabled = false;
    ctx.drawImage(c.img, f.sx + Math.round(cx - crop / 2), f.sy + top - 2, crop, crop, x, y, size, size);
  }
  const SPEAKER_SPRITE = { '용왕': 'yongwang', '처용': 'cheoyong', '화랑': 'hwarang', '할미': 'halmi', '상인': 'merchant', '도사': 'dosa', '아이': 'child',
    '누렁이': 'dog', '앓는 사람': 'sick', '아내': 'wife', '왕': 'king', '스님': 'monk', '산신령': 'sansin', '아낙': 'villager',
    '도깨비 대장': 'dokchief', '구미호': 'gumiho', '이무기': 'imugi', '역신': 'yeoksin' };

  function drawDialog(ctx, vw, vh) {
    const d = U.dialog;
    if (!d || d.waitBanner) return;
    const [sp, text] = d.lines[d.i];
    const w = Math.min(820, vw - 40), h = 120, x = (vw - w) / 2, y = vh - h - 16;
    panel(ctx, x, y, w, h, 0.9);
    let tx = x + 22;
    if (sp !== '@') {
      const spr = SPEAKER_SPRITE[sp];
      if (spr && G.assets.chars[spr]) {
        ctx.fillStyle = 'rgba(40,44,70,0.9)'; ctx.fillRect(x + 14, y + 14, 92, 92);
        portrait(ctx, spr, x + 16, y + 16, 88);
        ctx.strokeStyle = 'rgba(214,180,110,0.7)'; ctx.strokeRect(x + 14.5, y + 14.5, 91, 91);
        tx = x + 122;
      }
      ctx.font = `bold 17px ${FONT}`; ctx.textAlign = 'left'; ctx.fillStyle = '#ffd27a';
      ctx.fillText(sp, tx, y + 34);
    }
    ctx.font = sp === '@' ? `italic 18px ${FONT}` : `17px ${FONT}`;
    ctx.fillStyle = sp === '@' ? '#bfe6ff' : '#f3e6c4';
    ctx.textAlign = sp === '@' ? 'center' : 'left';
    const lines = wrap(ctx, text.slice(0, Math.floor(d.shown)), w - (tx - x) - 26);
    lines.forEach((l, i) => ctx.fillText(l, sp === '@' ? x + w / 2 : tx, y + (sp === '@' ? 56 : 62) + i * 24));
    if (d.shown >= text.length && Math.floor(G.game.time * 2.5) % 2 === 0) {
      ctx.fillStyle = '#ffd27a'; ctx.beginPath();
      ctx.moveTo(x + w - 26, y + h - 22); ctx.lineTo(x + w - 16, y + h - 22); ctx.lineTo(x + w - 21, y + h - 15); ctx.fill();
    }
  }

  function drawBanner(ctx, vw, vh, dt) {
    const b = U.banner;
    if (!b) return;
    b.t += dt;
    const D = 4.2;
    if (b.t > D) { U.banner = null; return; }
    const a = Math.min(1, b.t * 1.5, (D - b.t) * 1.5);
    ctx.fillStyle = `rgba(4,6,16,${0.6 * a})`; ctx.fillRect(0, 0, vw, vh);
    ctx.globalAlpha = a;
    ctx.textAlign = 'center';
    ctx.font = `bold 16px ${SANS}`; ctx.fillStyle = '#d6b46e';
    ctx.fillText('처용가 · 제' + '一二三四五六七八'[b.n - 1] + '구', vw / 2, vh / 2 - 46);
    ctx.font = `bold 40px ${FONT}`;
    const text = G.VERSES[b.n - 1];
    const shown = text.slice(0, Math.ceil(Math.min(1, b.t / 1.2) * text.length));
    ctx.fillStyle = 'rgba(160,220,255,0.35)'; ctx.fillText(shown, vw / 2, vh / 2 + 14);
    ctx.fillStyle = '#f7ecd0'; ctx.fillText(shown, vw / 2, vh / 2 + 12);
    ctx.fillStyle = 'rgba(214,180,110,0.8)'; ctx.fillRect(vw / 2 - 160 * Math.min(1, b.t), vh / 2 + 34, 320 * Math.min(1, b.t), 2);
    ctx.globalAlpha = 1;
  }

  function drawShop(ctx, vw, vh) {
    const s = U.shop, p = G.game.player;
    const w = 380, h = 74 + (GOODS.length + 1) * 52, x = vw / 2 - w / 2, y = vh / 2 - h / 2;
    panel(ctx, x, y, w, h, 0.94);
    ctx.font = `bold 20px ${FONT}`; ctx.textAlign = 'center'; ctx.fillStyle = '#ffd27a'; ctx.fillText('상인의 좌판', vw / 2, y + 34);
    ctx.font = `13px ${SANS}`; ctx.fillStyle = '#d8d0c0'; ctx.fillText('가진 엽전 ' + p.coins + '냥', vw / 2, y + 56);
    s.rects = [];
    [...GOODS, { name: '그만 보겠소', desc: '', price: null }].forEach((g, i) => {
      const ry = y + 70 + i * 52, rx = x + 20, rw = w - 40, rh = 44;
      s.rects.push({ x: rx, y: ry, w: rw, h: rh, i });
      ctx.fillStyle = s.sel === i ? 'rgba(214,180,110,0.25)' : 'rgba(255,255,255,0.05)'; ctx.fillRect(rx, ry, rw, rh);
      if (g.k) drawIcon(ctx, g.k, rx + 24, ry + 22, 14);
      ctx.textAlign = 'left'; ctx.font = `bold 16px ${SANS}`; ctx.fillStyle = '#f3e6c4'; ctx.fillText(g.name, rx + (g.k ? 46 : 16), ry + 20);
      ctx.font = `12px ${SANS}`; ctx.fillStyle = '#b8b0a0'; ctx.fillText(g.desc + (g.k ? `  (가진 것 ${p.items[g.k]})` : ''), rx + (g.k ? 46 : 16), ry + 37);
      if (g.price != null) { ctx.textAlign = 'right'; ctx.font = `bold 15px ${SANS}`; ctx.fillStyle = p.coins >= g.price ? '#ffd27a' : '#886'; ctx.fillText(g.price + '냥', rx + rw - 12, ry + 28); }
    });
  }

  // ---------- pause menu ----------
  U.menuState = { sel: 0 };
  U.updateMenu = () => {
    const inp = G.input, p = G.game.player;
    if (inp.hit('menu')) { U.menu = false; return; }
    for (const r of U.menuRects || []) if (inp.hit('tap') && U.hitRect(r)) {
      if (r.mask) { p.mask = r.mask; G.audio.sfx('ui'); }
      if (r.close) U.menu = false;
      if (r.sound) { G.audio.toggle && G.audio.toggle(); }
    }
    if (inp.hit('mask')) p.cycleMask();
  };
  function drawMenu(ctx, vw, vh) {
    const p = G.game.player, f = G.game.flags;
    ctx.fillStyle = 'rgba(4,6,16,0.7)'; ctx.fillRect(0, 0, vw, vh);
    const w = Math.min(760, vw - 40), h = Math.min(500, vh - 40), x = vw / 2 - w / 2, y = vh / 2 - h / 2;
    panel(ctx, x, y, w, h, 0.95);
    U.menuRects = [];
    ctx.textAlign = 'left'; ctx.font = `bold 22px ${FONT}`; ctx.fillStyle = '#ffd27a'; ctx.fillText('쉬어 가기', x + 24, y + 40);
    // stats
    ctx.font = `14px ${SANS}`; ctx.fillStyle = '#f3e6c4';
    const st = [`레벨 ${p.lvl}  (${Math.floor(p.exp)}/${p.expNeed()})`, `체력 ${Math.ceil(p.hp)}/${p.maxHp}`, `기 ${Math.floor(p.gi)}/${p.maxGi}`, `공격 ${Math.round(p.atk)}`, `엽전 ${p.coins}냥`, `약과 ${p.items.yakgwa} · 식혜 ${p.items.sikhye}`, `정화한 요괴 ${f.kills_total || 0}`];
    st.forEach((s, i) => ctx.fillText(s, x + 24, y + 76 + i * 24));
    // masks
    ctx.font = `bold 16px ${FONT}`; ctx.fillStyle = '#ffd27a'; ctx.fillText('탈', x + 24, y + 270);
    p.masks.forEach((m, i) => {
      const M = G.MASKS[m], rx = x + 24, ry = y + 282 + i * 46, rw = 300, rh = 40;
      U.menuRects.push({ x: rx, y: ry, w: rw, h: rh, mask: m });
      ctx.fillStyle = p.mask === m ? 'rgba(214,180,110,0.28)' : 'rgba(255,255,255,0.05)'; ctx.fillRect(rx, ry, rw, rh);
      ctx.fillStyle = M.color; ctx.font = `bold 15px ${SANS}`; ctx.fillText(M.name, rx + 12, ry + 18);
      ctx.fillStyle = '#c8c0b0'; ctx.font = `12px ${SANS}`; ctx.fillText(M.desc, rx + 12, ry + 34);
    });
    // verses
    const vx = x + w / 2 + 10;
    ctx.font = `bold 16px ${FONT}`; ctx.fillStyle = '#ffd27a'; ctx.fillText('처용가', vx, y + 76);
    G.VERSES.forEach((v, i) => {
      const got = f['verse' + (i + 1)];
      ctx.font = `16px ${FONT}`; ctx.fillStyle = got ? '#f3e6c4' : 'rgba(243,230,196,0.25)';
      ctx.fillText((i + 1) + '. ' + (got ? v : '· · · · · ·'), vx, y + 106 + i * 28);
    });
    // skills
    ctx.font = `bold 16px ${FONT}`; ctx.fillStyle = '#ffd27a'; ctx.fillText('익힌 춤', vx, y + 352);
    ctx.font = `13px ${SANS}`; ctx.fillStyle = '#d8d0c0';
    const sk = ['소매 [J]'].concat(Object.keys(p.skills).filter((k) => p.skills[k]).map((k) => G.SKILLS[k].name + ' [' + { skill1: 'U', skill2: 'I', skill3: 'O' }[k] + ']'));
    if (f.has_ult) sk.push('처용가 [L]');
    ctx.fillText(sk.join(' · '), vx, y + 376, w / 2 - 40);
    ctx.fillStyle = '#9a9080'; ctx.fillText('이동 WASD · 구르기 K · 대화 E · 탈 M · 약과 1 · 식혜 2', vx, y + 404, w / 2 - 40);
    // sound + close
    const sr = { x: x + w - 250, y: y + h - 54, w: 110, h: 38, sound: true };
    U.menuRects.push(sr);
    ctx.fillStyle = 'rgba(255,255,255,0.08)'; ctx.fillRect(sr.x, sr.y, sr.w, sr.h);
    ctx.textAlign = 'center'; ctx.fillStyle = '#d8ccb0'; ctx.font = `bold 14px ${SANS}`; ctx.fillText(G.audio.off ? '소리 켜기' : '소리 끄기', sr.x + sr.w / 2, sr.y + 24);
    const cr = { x: x + w - 130, y: y + h - 54, w: 110, h: 38, close: true };
    U.menuRects.push(cr);
    ctx.fillStyle = 'rgba(214,180,110,0.25)'; ctx.fillRect(cr.x, cr.y, cr.w, cr.h);
    ctx.textAlign = 'center'; ctx.fillStyle = '#ffd27a'; ctx.font = `bold 15px ${SANS}`; ctx.fillText('돌아가기', cr.x + cr.w / 2, cr.y + 25);
    ctx.fillStyle = '#9a9080'; ctx.font = `12px ${SANS}`; ctx.fillText('진행은 자동으로 저장되오', x + w / 2, y + h - 18);
  }

  U.draw = (ctx, vw, vh, dt) => {
    const g = G.game;
    if (!g.cinema) drawHud(ctx, vw, vh);
    if (!U.dialog && !U.shop && !U.menu && !g.cinema) drawButtons(ctx, vw, vh);
    else G.input.buttons = [];
    if (g.cinema) {
      // letterbox
      const k = Math.min(1, g.cinemaT * 2), bh = 48 * k;
      ctx.fillStyle = '#000'; ctx.fillRect(0, 0, vw, bh); ctx.fillRect(0, vh - bh, vw, bh);
    }
    drawDialog(ctx, vw, vh);
    if (U.shop) drawShop(ctx, vw, vh);
    if (U.menu) drawMenu(ctx, vw, vh);
    drawBanner(ctx, vw, vh, dt);
  };
  return U;
})();
