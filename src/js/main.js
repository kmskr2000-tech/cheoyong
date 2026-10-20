// Main: canvas setup, resize, state machine (loading → title → intro → play → ending) and the frame loop.
'use strict';
(() => {
  const canvas = document.getElementById('game');
  const ctx = canvas.getContext('2d');
  let scale = 1, dpr = 1;
  G.viewW = 1000;
  G.state = 'loading';

  function resize() {
    dpr = Math.min(window.devicePixelRatio || 1, 3);
    const w = window.innerWidth, h = window.innerHeight;
    G.viewW = Math.round(G.clamp((w / h) * G.VIEW_H, 760, 1400));
    // fit the logical view inside the window
    scale = Math.min(w / G.viewW, h / G.VIEW_H);
    canvas.style.width = Math.round(G.viewW * scale) + 'px';
    canvas.style.height = Math.round(G.VIEW_H * scale) + 'px';
    canvas.width = Math.round(G.viewW * scale * dpr);
    canvas.height = Math.round(G.VIEW_H * scale * dpr);
    ctx.imageSmoothingEnabled = false;
    // UI layer works in roughly CSS pixels on phones (readable text, thumb-sized buttons), scaled up on big screens
    const cssH = G.VIEW_H * scale, cssW = G.viewW * scale;
    G.uiH = G.clamp(cssH, 380, 600);
    G.uiScale = cssH / G.uiH;
    G.uiW = cssW / G.uiScale;
    if (G.game.player) G.game.clampCam();
  }
  G.screenToLogical = (cx, cy) => {
    const r = canvas.getBoundingClientRect();
    return { x: ((cx - r.left) / r.width) * G.viewW, y: ((cy - r.top) / r.height) * G.VIEW_H };
  };
  G.screenToUI = (cx, cy) => {
    const r = canvas.getBoundingClientRect();
    return { x: ((cx - r.left) / r.width) * G.uiW, y: ((cy - r.top) / r.height) * G.uiH };
  };
  addEventListener('resize', resize);
  resize();
  G.input.attach(canvas);

  const FONT = '"Noto Serif KR", "Nanum Myeongjo", serif';
  const SANS = '"Noto Sans KR", sans-serif';

  // ---------- states ----------
  let st = { t: 0 };
  G.setState = (s, data = {}) => { G.state = s; st = { t: 0, ...data }; if (enter[s]) enter[s](); };
  const enter = {
    title() {
      G.audio.music('title');
      G.game.newGame();
      G.game.cam.x = 84 * 32; G.game.cam.y = 58 * 32;
      st.sel = 0;
      st.hasSave = G.game.hasSave();
    },
    intro() { G.audio.music('title'); st.shot = 0; st.st = 0; },
    play() {},
    ending() { G.audio.music('song'); st.shot = 0; },
  };

  const INTRO = [
    { cam: [61, 47], text: ['신라 헌강왕 시절,', '서라벌에는 노래와 춤이 끊이지 않았다.'] },
    { cam: [98, 64], text: ['어느 날 동해 개운포에 짙은 안개가 깔리고,', '바다에서 용왕과 일곱 아들이 나타났다.'] },
    { cam: [14, 10], text: ['그러나 밤이 되면', '역신이 집집마다 스며들어 병을 퍼뜨렸다.'] },
    { cam: [96, 66], text: ['역신을 물리칠 노래는', '여덟 구절로 흩어져 버렸다.'] },
    { cam: [96, 66], text: ['노래가 완성되면 —'], last: true },
  ];
  const ENDING = [
    { text: ['그날 이후 서라벌 사람들은', '문에 처용의 얼굴을 그려 붙였다.'] },
    { text: ['역신은 맹세를 지켜', '그 문으로는 다시 들지 않았다.'] },
    { text: ['서라벌 밝은 달에', '밤 늦도록 노닐다가 —'] },
    { text: ['신 처용가', '끝'], last: true },
  ];

  const update = {
    loading() {},
    title(dt) {
      st.t += dt;
      const g = G.game;
      g.cam.x = 84 * 32 + Math.sin(st.t * 0.05) * 200; g.cam.y = 58 * 32 + Math.cos(st.t * 0.04) * 80;
      g.clampCam(); g.time += dt; G.fx.update(dt);
      if (Math.random() < 0.3) G.fx.add({ x: g.cam.x + Math.random() * G.viewW, y: g.cam.y + G.VIEW_H, z: 0, vz: 30 + Math.random() * 30, vx: (Math.random() - 0.5) * 20, life: 6, size: 2, color: '#9fe0ff', glow: true });
      const inp = G.input;
      const opts = st.hasSave ? ['이어하기', '새로 시작'] : ['시작하기'];
      st.opts = opts;
      const mv = inp.move();
      st.cool = (st.cool || 0) - dt;
      if (Math.abs(mv.y) > 0.5 && st.cool <= 0) { st.sel = (st.sel + 1) % opts.length; st.cool = 0.25; G.audio.sfx('ui'); }
      let choose = null;
      if (inp.hit('tap') && st.rects) for (const r of st.rects) if (G.ui.hitRect(r)) choose = r.i;
      if (choose == null && st.t > 0.4 && (inp.hit('confirm') || inp.hit('interact') || inp.hit('attack'))) choose = st.sel;
      if (choose != null) {
        G.audio.unlock(); G.audio.sfx('verse');
        if (opts[choose] === '이어하기') { G.game.load(); G.setState('play'); }
        else if (G.params.has('skipintro')) { G.game.newGame(); G.setState('play'); }
        else G.setState('intro');
      }
    },
    intro(dt) {
      st.t += dt; st.st += dt;
      const shot = INTRO[st.shot];
      const g = G.game;
      g.time += dt; G.fx.update(dt);
      const [cx, cy] = shot.cam;
      g.cam.x = cx * 32 - G.viewW / 2 + st.st * 14; g.cam.y = cy * 32 - G.VIEW_H / 2;
      g.clampCam();
      const inp = G.input;
      const dur = shot.last ? 4 : 5.2;
      if (st.st > dur || (st.st > 0.6 && (inp.hit('confirm') || inp.hit('tap')))) {
        st.shot++; st.st = 0;
        if (st.shot >= INTRO.length) { G.game.newGame(); G.setState('play'); G.audio.music('sea'); }
      }
    },
    play(dt) {
      G.game.update(dt);
    },
    ending(dt) {
      st.t += dt; st.st = (st.st || 0) + dt;
      G.fx.update(dt);
      const g = G.game;
      if (Math.random() < 0.5) G.fx.add({ x: g.cam.x + Math.random() * G.viewW, y: g.cam.y + G.VIEW_H, z: 0, vz: 40 + Math.random() * 40, vx: (Math.random() - 0.5) * 30, life: 7, size: 2, color: ['#9fe0ff', '#ffe9a8'][Math.floor(Math.random() * 2)], glow: true });
      const inp = G.input;
      const shot = ENDING[st.shot];
      if (!shot.last && (st.st > 5.5 || (st.st > 0.8 && (inp.hit('confirm') || inp.hit('tap'))))) { st.shot++; st.st = 0; }
      if (shot.last && st.st > 3 && (inp.hit('confirm') || inp.hit('tap'))) { G.setState('title'); }
    },
  };

  function drawTitleText(ctx, vw, vh) {
    const a = Math.min(1, st.t * 0.8);
    ctx.globalAlpha = a;
    ctx.fillStyle = 'rgba(4,6,18,0.45)'; ctx.fillRect(0, 0, vw, vh);
    ctx.textAlign = 'center';
    ctx.font = `bold 84px ${FONT}`;
    ctx.fillStyle = 'rgba(120,200,255,0.25)'; ctx.fillText('신 처용가', vw / 2, vh * 0.36 + 4);
    ctx.fillStyle = '#f5e9cc'; ctx.fillText('신 처용가', vw / 2, vh * 0.36);
    ctx.font = `20px ${FONT}`; ctx.fillStyle = '#d6b46e'; ctx.fillText('— 탈과 노래 —', vw / 2, vh * 0.36 + 44);
    st.rects = [];
    (st.opts || []).forEach((o, i) => {
      const y = vh * 0.6 + i * 50, w = 220, x = vw / 2 - w / 2;
      st.rects.push({ x, y: y - 28, w, h: 42, i });
      ctx.fillStyle = st.sel === i ? 'rgba(214,180,110,0.28)' : 'rgba(10,12,28,0.55)';
      ctx.fillRect(x, y - 28, w, 42);
      ctx.strokeStyle = st.sel === i ? '#ffd27a' : 'rgba(214,180,110,0.5)'; ctx.lineWidth = 1.5; ctx.strokeRect(x + 0.5, y - 27.5, w - 1, 41);
      ctx.font = `bold 20px ${FONT}`; ctx.fillStyle = st.sel === i ? '#ffe2a0' : '#d8ccb0'; ctx.fillText(o, vw / 2, y);
    });
    ctx.font = `12px ${SANS}`; ctx.fillStyle = 'rgba(220,210,190,0.6)';
    ctx.fillText('가로 화면 · 왼쪽 엄지로 이동, 오른쪽 버튼으로 춤 · PC: WASD / J K U I O L E', vw / 2, vh - 24);
    ctx.globalAlpha = 1;
  }
  function drawCaption(ctx, vw, vh, lines, t, big) {
    const a = Math.min(1, t * 1.2);
    ctx.globalAlpha = a; ctx.textAlign = 'center';
    ctx.font = big ? `bold 40px ${FONT}` : `24px ${FONT}`;
    lines.forEach((l, i) => {
      const y = vh * (big ? 0.48 : 0.74) + i * (big ? 52 : 36);
      ctx.fillStyle = '#000'; ctx.fillText(l, vw / 2 + 2, y + 2);
      ctx.fillStyle = big ? '#f7ecd0' : '#e8dcc0'; ctx.fillText(l, vw / 2, y);
    });
    ctx.globalAlpha = 1;
  }

  const draw = {
    loading(ctx, vw, vh) {
      ctx.fillStyle = '#05060f'; ctx.fillRect(0, 0, vw, vh);
      ctx.fillStyle = '#d6b46e'; ctx.font = `20px ${FONT}`; ctx.textAlign = 'center';
      ctx.fillText('노래를 모으는 중…', vw / 2, vh / 2 - 20);
      ctx.fillStyle = 'rgba(214,180,110,0.3)'; ctx.fillRect(vw / 2 - 150, vh / 2, 300, 4);
      ctx.fillStyle = '#d6b46e'; ctx.fillRect(vw / 2 - 150, vh / 2, 300 * (st.p || 0), 4);
      if (st.err) { ctx.fillStyle = '#f88'; ctx.font = `14px ${SANS}`; ctx.fillText(st.err, vw / 2, vh / 2 + 40); }
    },
    title(ctx, vw, vh) {
      drawTitleText(ctx, vw, vh);
    },
    intro(ctx, vw, vh) {
      const shot = INTRO[st.shot] || INTRO[INTRO.length - 1];
      const fade = Math.min(1, st.st * 1.5, ((shot.last ? 4 : 5.2) - st.st) * 1.5);
      ctx.fillStyle = `rgba(0,0,0,${shot.last ? 0.85 : 0.35 + (1 - fade) * 0.65})`; ctx.fillRect(0, 0, vw, vh);
      ctx.fillStyle = '#000'; ctx.fillRect(0, 0, vw, 56); ctx.fillRect(0, vh - 56, vw, 56);
      drawCaption(ctx, vw, vh, shot.text, Math.max(0, st.st - 0.3), shot.last);
    },
    play(ctx, vw, vh, dt) {
      G.ui.draw(ctx, vw, vh, dt);
    },
    ending(ctx, vw, vh) {
      const g = G.game;
      g.cam.y = Math.max(0, g.cam.y - 0.15);
      ctx.fillStyle = 'rgba(0,0,0,0.6)'; ctx.fillRect(0, 0, vw, vh);
      const shot = ENDING[st.shot];
      drawCaption(ctx, vw, vh, shot.text, Math.max(0, (st.st || 0) - 0.3), shot.last);
      if (shot.last) {
        ctx.font = `13px ${SANS}`; ctx.fillStyle = 'rgba(220,210,190,0.7)'; ctx.textAlign = 'center';
        ctx.fillText('그림: PixelLab 생성 도트 · 소리: 합성 국악 · 만든 이: 신 처용가 팀', vw / 2, vh - 40);
        ctx.fillText(`처용 Lv.${g.player.lvl} · 정화한 요괴 ${g.flags.kills_total || 0}`, vw / 2, vh - 20);
      }
    },
  };

  // ---------- loop ----------
  let last = performance.now();
  const fixedFrames = +G.params.get('frames') || 0; // test hook: run N fixed frames then stop
  const speed = +G.params.get('speed') || 1; // test hook: simulate several steps per frame
  function frame(now) {
    let dt = Math.min(0.05, (now - last) / 1000);
    last = now;
    for (let i = 1; i < speed; i++) step(Math.min(dt, 1 / 30), true);
    step(dt);
    if (!fixedFrames) requestAnimationFrame(frame);
  }
  function step(dt, skipDraw) {
    if (G.bot) G.bot.tick(dt);
    update[G.state] && update[G.state](dt);
    if (skipDraw) { G.input.endFrame(); return; }
    ctx.setTransform(scale * dpr, 0, 0, scale * dpr, 0, 0);
    ctx.imageSmoothingEnabled = false;
    if (G.state !== 'loading') G.game.draw(ctx);
    const u = G.uiScale * dpr;
    ctx.setTransform(u, 0, 0, u, 0, 0);
    draw[G.state] && draw[G.state](ctx, G.uiW, G.uiH, dt);
    G.input.endFrame();
  }
  G.step = step; // used by tests to advance time deterministically

  // ---------- boot ----------
  st.p = 0;
  requestAnimationFrame(frame);
  G.assets.load((p) => { st.p = p; }).then(() => {
    G.world.init();
    G.game.newGame();
    const P = G.params;
    if (P.has('play') || P.has('quest') || P.has('at')) {
      if (P.has('continue')) G.game.load();
      G.game.applyDebug();
      G.setState('play');
      if (P.has('enemies')) {
        const p = G.game.player;
        for (const k of P.get('enemies').split(',')) G.game.spawnEnemy(k, p.x + 140 + Math.random() * 60, p.y + (Math.random() - 0.5) * 100, { level: 1 });
      }
      if (P.get('boss')) {
        const p = G.game.player;
        const b = G.game.spawnBoss(P.get('boss'), p.x + 220, p.y, null);
        G.game.startBossFight(b, p.x + 110, p.y);
      }
    } else if (P.has('ending')) G.setState('ending');
    else G.setState('title');
    window.__ready = true;
  }).catch((e) => { st.err = String(e); console.error(e); });
})();
