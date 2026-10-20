// Game: world state, spawning, bosses, cutscenes, saving, and the world renderer (2.5D sort + night lighting).
'use strict';
(() => {
  const T = G.TILE;
  const fx = G.fx;
  const SAVE_KEY = 'cheoyong_save_v1';
  const CHECKPOINTS = { beach: [100, 70], town: [61, 53], ruin: [90, 36], pond: [61, 25], forest: [36, 57], house: [24, 33] };

  const game = {
    flags: {}, enemies: [], npcs: [], projectiles: [], hazards: [], pickups: [],
    time: 0, hitstop: 0, frozen: false, cinema: false, cinemaT: 0, cam: { x: 0, y: 0 }, camFocus: null,
    arena: null, boss: null, zone: null, zoneBanner: null, spawnDead: {}, musicStack: [],

    newGame() {
      this.flags = {};
      this.player = new G.Player(100 * T, 70.5 * T);
      this.player.faceTo(0);
      this.reset();
    },
    reset() {
      this.enemies = []; this.projectiles = []; this.hazards = []; this.pickups = [];
      this.arena = null; this.boss = null; this.frozen = false; this.cinema = false; this.zone = null; this.spawnDead = {};
      this.musicStack = [];
      G.ui.dialog = null; G.ui.shop = null; G.ui.menu = false; G.ui.banner = null;
      fx.clear();
      this.buildNpcs();
      this.snapCam();
    },
    hasSave() { try { return !!localStorage.getItem(SAVE_KEY); } catch (e) { return false; } },
    save() {
      const p = this.player;
      const data = { flags: this.flags, p: { x: p.x, y: p.y, lvl: p.lvl, exp: p.exp, coins: p.coins, hp: p.hp, maxHp: p.maxHp, maxGi: p.maxGi, items: p.items, masks: p.masks, mask: p.mask, skills: p.skills } };
      try { localStorage.setItem(SAVE_KEY, JSON.stringify(data)); } catch (e) { /* private mode */ }
    },
    load() {
      let data = null;
      try { data = JSON.parse(localStorage.getItem(SAVE_KEY)); } catch (e) {}
      if (!data) return this.newGame();
      this.flags = data.flags || {};
      const p = (this.player = new G.Player(data.p.x, data.p.y));
      Object.assign(p, data.p);
      p.gi = p.maxGi;
      // never resume inside a locked boss arena
      if (this.flags.yeoksin_started && !this.flags.yeoksin_done) { this.flags.yeoksin_started = false; p.x = 40 * T; p.y = 31 * T; }
      this.reset();
    },
    // URL test hooks: ?flags=a,b  ?at=x,y  ?quest=n
    applyDebug() {
      const P = G.params, p = this.player, f = this.flags;
      const q = +P.get('quest') || 0;
      const steps = [
        () => { f.q1 = true; f.has_attack = true; p.masks = ['cheoyong']; p.mask = 'cheoyong'; f.verse1 = true; },
        () => { f.kills_beach = 6; f.q2 = true; f.gate_open = true; f.has_ult = true; p.skills.skill1 = true; },
        () => { f.king_event = true; f.king_met = true; },
        () => { f.q3 = true; f.paths_open = true; },
        () => { f.kills_ruin = f.kills_forest = f.kills_pond = 6; f.kills_total = 20; f.boss_dok = f.boss_fox = f.boss_imugi = true; f.dosa_done = true;
          p.skills.skill2 = p.skills.skill3 = true; p.masks = ['cheoyong', 'gwimyeon', 'yongwang']; f.verse2 = f.verse3 = f.verse4 = f.verse5 = true; p.lvl = 8; p.maxHp = 200; p.hp = 200; p.maxGi = 130; },
        () => { f.q4 = f.q5 = true; f.house_open = true; f.verse6 = true; },
      ];
      for (let i = 0; i < Math.min(q, steps.length); i++) steps[i]();
      if (P.get('flags')) for (const k of P.get('flags').split(',')) f[k] = true;
      if (P.get('at')) { const [x, y] = P.get('at').split(',').map(Number); p.x = x * T; p.y = y * T; }
      if (P.get('lvl')) { p.lvl = +P.get('lvl'); p.maxHp = 100 + (p.lvl - 1) * 14; p.hp = p.maxHp; }
      if (P.has('heung')) p.heung = 100;
      this.buildNpcs(); this.snapCam();
    },

    // ---------- NPCs ----------
    buildNpcs() {
      this.npcs = G.story.NPCS.map(([id, spr, tx, ty, name, dir, vis]) => {
        const n = new G.Npc(id, spr, tx * T, ty * T, { name, dir, visibleIf: vis });
        if (id === 'yongwang') {
          // stand ankle-deep at the waterline east of the start point
          let x = 98 * T;
          while (x < 118 * T && !G.world.solidAt(x, n.y)) x += 8;
          n.x = x + 34;
        }
        return n;
      });
      this.refreshNpcs();
    },
    refreshNpcs() {
      for (const n of this.npcs) n.hidden = n.visibleIf ? !n.visibleIf(this.flags) : false;
      const hw = this.npc('hwarang');
      if (hw && this.flags.gate_open) { hw.x = 69.5 * T; hw.y = 68.6 * T; hw.dirHome = 'west'; }
    },
    npc(id) { return this.npcs.find((n) => n.id === id); },

    // ---------- spawning ----------
    spawnEnemy(type, x, y, o = {}) {
      const e = new G.Enemy(type, x, y, o);
      e.zone = o.zone; e.spawnKey = o.key; e.summoned = o.summoned;
      if (G.world.blocked(x, y, e.r)) { e.x = this.player.x + (Math.random() - 0.5) * 60; e.y = this.player.y + (Math.random() - 0.5) * 40; }
      this.enemies.push(e);
      fx.smoke(e.x, e.y, 6, '#6a2aff');
      return e;
    },
    spawnZone(zid) {
      const sp = G.story.SPAWNS[zid];
      if (!sp) return;
      if (zid === 'house' && (!this.flags.house_open || this.flags.yeoksin_done)) return;
      if (zid === 'beach' && !this.flags.q1) return;
      const now = this.time;
      sp.list.forEach(([type, tx, ty], i) => {
        const key = zid + i;
        if (this.enemies.some((e) => e.spawnKey === key && !e.dead)) return;
        const dead = this.spawnDead[key];
        if (dead != null && now - dead < 75) return;
        const e = this.spawnEnemy(type, tx * T, ty * T, { level: sp.lvl, zone: zid, key });
        e.spawnT = 0;
      });
    },
    despawnFar() {
      // keep the active set small: drop zone enemies far from the player who are not fighting
      const p = this.player;
      this.enemies = this.enemies.filter((e) => {
        if (e.dead || e.def.boss || e.summoned) return !e.dead;
        if (G.dist(e.x, e.y, p.x, p.y) > 1500 && e.state !== 'kneel') { return false; }
        return true;
      });
    },
    onPurify(e) {
      const f = this.flags, p = this.player;
      if (e.spawnKey) this.spawnDead[e.spawnKey] = this.time;
      if (!e.illusion) {
        f.kills_total = (f.kills_total || 0) + 1;
        if (e.zone) f['kills_' + e.zone] = (f['kills_' + e.zone] || 0) + 1;
      }
      p.gainExp(e.def.exp * (1 + ((e.lvl || 1) - 1) * 0.2));
      const [a, b] = e.def.coin;
      const n = a + Math.floor(Math.random() * (b - a + 1));
      for (let i = 0; i < Math.min(n, 8); i++) this.pickups.push(new G.Coin(e.x, e.y, Math.ceil(n / Math.min(n, 8))));
      if (Math.random() < 0.06) { p.items.yakgwa++; G.ui.toast('약과를 주웠소'); }
      p.addHeung(5);
      // quest milestones
      if (e.zone && f['kills_' + e.zone] === 6) {
        if (e.zone === 'beach') G.ui.toast('개운포의 요괴를 모두 정화했소 — 용왕에게');
        else if (G.story.BOSSES[e.zone]) G.ui.toast('탁기가 한곳으로 모인다… 우두머리가 깨어났소');
        G.audio.sfx('quest');
      }
      if (f.q3 && !f.dosa_done && f.kills_total === 12) G.ui.toast('도사에게 가 보시오');
    },
    spawnBoss(type, x, y, zone) {
      const b = new G.Enemy(type, x, y, { level: 1, zone });
      b.zone = zone; b.cool = 1.5;
      b.onDefeat = () => {
        b.kneeling = true; b.state = 'kneel'; b.stateT = 0; b.invuln = true; b.calm = true;
        for (const h of this.hazards) h.dead = true;
        for (const pr of this.projectiles) if (pr.owner === 'enemy') pr.dead = true;
        for (const e of this.enemies) if (e !== b && e.summoned && e.state !== 'kneel') { e.state = 'kneel'; e.stateT = 0; }
        G.audio.sfx('purify'); fx.screenFlash(0.6, '#e8f6ff'); fx.ring(b.x, b.y, 10, 200, 1.2, '#9fe0ff', 4);
        for (let i = 0; i < 4; i++) setTimeout(() => fx.soul(b.x + (Math.random() - 0.5) * 60, b.y), i * 250);
        this.player.gainExp(b.def.exp);
        const [lo, hi] = b.def.coin;
        for (let i = 0; i < 8; i++) this.pickups.push(new G.Coin(b.x, b.y, Math.ceil((lo + Math.random() * (hi - lo)) / 8)));
        if (b.type === 'yeoksin') G.story.yeoksinKneel(b); else G.story.bossDefeated(b);
      };
      // boss stays kneeling, never removed by the normal purify timer
      const up = b.update.bind(b);
      b.update = (dt) => { if (b.kneeling) { b.animT += dt; b.stateT = Math.min(b.stateT + dt, 0.9); b.flash = 0; return; } up(dt); };
      this.enemies.push(b);
      return b;
    },
    startBossFight(b, cx, cy) {
      this.boss = b;
      this.arena = { x: cx, y: cy, r: 360 };
      this.pushMusic('boss');
    },
    endBossFight() {
      this.arena = null;
      const b = this.boss;
      this.boss = null;
      this.popMusic();
      // the kneeling boss fades away after a while
      if (b) setTimeout(() => { b.dead = true; }, 6000);
    },

    // ---------- cutscenes ----------
    cutscene(fn, done) {
      this.frozen = true; this.cinema = true; this.cinemaT = 0;
      const c = {
        pan: (x, y, dur) => new Promise((res) => { this.camFocus = x == null ? null : { x, y }; this.camPanSpeed = 2.2 / Math.max(0.2, dur); setTimeout(res, dur * 1000); }),
        wait: (s) => new Promise((res) => setTimeout(res, s * 1000)),
        say: (lines) => new Promise((res) => G.ui.say(lines, res)),
      };
      Promise.resolve(fn(c)).then(() => {
        this.frozen = false; this.cinema = false; this.camFocus = null;
        done && done();
      });
    },
    cutsceneSay(lines, done) { this.cutscene((c) => c.say(lines), done); },
    dissolveGates() {
      for (const g of G.world.GATES) {
        if (!this.flags[g.flag]) continue;
        if (g.dissolved) continue;
        g.dissolved = true;
        const cx = ((g.x0 + g.x1) / 2) * T, cy = ((g.y0 + g.y1) / 2) * T;
        for (let i = 0; i < 30; i++) fx.smoke(cx + (Math.random() - 0.5) * 160, cy + (Math.random() - 0.5) * 120, 1, '#8a4cff');
      }
    },

    // ---------- tutorial: exactly one glowing button ----------
    tutorial(key) { this.flags['tut_' + key] = 'pending'; },
    updateTutorial() {
      const f = this.flags, p = this.player;
      let glow = null;
      if (this.interactTarget && !G.ui.dialog) glow = 'interact';
      else if (f.tut_attack === 'pending') glow = 'attack';
      else if (f.tut_roll === 'pending') glow = 'roll';
      else if (f.tut_skill1 === 'pending' && p.gi >= 12) glow = 'skill1';
      else if (f.tut_skill2 === 'pending' && p.gi >= 18) glow = 'skill2';
      else if (f.tut_skill3 === 'pending' && p.gi >= 20) glow = 'skill3';
      else if (f.has_ult && p.heung >= 100 && f.tut_ult !== 'done') glow = 'ult';
      else if (f.tut_mask === 'pending') glow = 'mask';
      G.ui.glow = glow;
      const inp = G.input;
      if (f.tut_attack === 'pending' && this.attackHits >= 1) { f.tut_attack = 'done'; f.tut_roll = 'pending'; }
      if (f.tut_roll === 'pending' && this.rolled) f.tut_roll = 'done';
      for (const k of ['skill1', 'skill2', 'skill3', 'mask', 'ult']) if (f['tut_' + k] === 'pending' && inp.hit(k)) f['tut_' + k] = 'done';
      if (inp.hit('ult') && p.heung >= 100) f.tut_ult = 'done';
    },
    onPlayerAttack(hits) { this.attackHits = (this.attackHits || 0) + (hits ? 1 : 0); },
    onRoll() { this.rolled = true; },
    onUlt() {},

    verseCount() { let n = 0; for (let i = 1; i <= 8; i++) if (this.flags['verse' + i]) n++; return n; },
    pushMusic(m) { this.musicStack.push(m); G.audio.music(m); },
    popMusic() { this.musicStack.pop(); G.audio.music(this.musicStack[this.musicStack.length - 1] || (this.zone && this.zone.music) || 'sea'); },

    onPlayerDeath() {
      G.audio.sfx('death');
      this.deathT = 0;
    },
    respawn() {
      const p = this.player;
      const z = this.zone ? this.zone.id : 'beach';
      let cp = CHECKPOINTS[z] || CHECKPOINTS.beach;
      if (z === 'town' && !this.flags.king_met) cp = [66, 62];
      if (z === 'house') cp = [40, 31];
      p.x = cp[0] * T; p.y = cp[1] * T;
      p.hp = p.maxHp; p.gi = p.maxGi; p.state = 'move'; p.iframe = 2; p.kbx = p.kby = 0;
      const lost = Math.floor(p.coins * 0.1); p.coins -= lost;
      // reset any boss fight in progress
      if (this.boss) {
        const b = this.boss;
        const flagFor = { dokchief: null, gumiho: null, imugi: null, yeoksin: 'yeoksin_started' }[b.type];
        if (flagFor) this.flags[flagFor] = false;
        this.enemies = this.enemies.filter((e) => e !== b && !e.summoned);
        this.boss = null; this.arena = null; this.musicStack = [];
      }
      this.projectiles = []; this.hazards = [];
      this.deathT = null;
      G.ui.toast(lost ? `넋을 추슬렀소 (엽전 ${lost}냥을 잃었다)` : '넋을 추슬렀소');
      this.snapCam();
      this.save();
    },
    startEnding() { G.setState('ending'); },

    // ---------- update ----------
    update(dt) {
      this.time += dt;
      if (this.cinema) this.cinemaT += dt;
      if (G.ui.menu) { G.ui.updateMenu(); return; }
      if (G.ui.shop) { G.ui.updateShop(); return; }
      if (G.ui.dialog || G.ui.banner) { G.ui.updateDialog(dt); if (G.ui.dialog || G.ui.banner) { this.updateCam(dt); fx.update(dt); return; } }
      if (G.input.hit('menu') && !this.frozen) { G.ui.menu = true; G.audio.sfx('ui'); return; }
      if (this.hitstop > 0) { this.hitstop -= dt; return; }
      const p = this.player;
      if (this.deathT != null) {
        this.deathT += dt;
        if (this.deathT > 2.2) this.respawn();
      }
      p.update(dt);
      // zone change
      const z = G.world.zoneAt(p.x, p.y);
      if (z && z !== this.zone) {
        this.zone = z;
        this.zoneBanner = { name: z.name, t: 0 };
        if (!this.boss) { this.musicStack = []; G.audio.music(z.music); }
        G.audio.ambient(z.amb);
        this.spawnZone(z.id);
        this.save();
      }
      if (this.zoneBanner) this.zoneBanner.t += dt;
      // respawn checks every few seconds
      this.spawnTick = (this.spawnTick || 0) - dt;
      if (this.spawnTick <= 0 && this.zone && !this.boss) { this.spawnTick = 5; this.spawnZone(this.zone.id); this.despawnFar(); }

      for (const n of this.npcs) if (!n.hidden) n.update(dt);
      for (const e of this.enemies) e.update(dt);
      // body push: player vs npcs/enemies
      for (const e of [...this.enemies, ...this.npcs]) {
        if (e.hidden || e.dead || e.state === 'kneel' || e.alpha === 0) continue;
        const dx = p.x - e.x, dy = p.y - e.y, d = Math.hypot(dx, dy), m = p.r + e.r * 0.8;
        if (d < m && d > 0.01) {
          const push = (m - d);
          if (e instanceof G.Npc || e.def.boss) G.world.moveCircle(p, (dx / d) * push, (dy / d) * push);
          else { G.world.moveCircle(p, (dx / d) * push * 0.5, (dy / d) * push * 0.5); G.world.moveCircle(e, (-dx / d) * push * 0.5, (-dy / d) * push * 0.5); }
        }
      }
      this.enemies = this.enemies.filter((e) => !e.dead);
      for (const pr of this.projectiles) pr.update(dt);
      this.projectiles = this.projectiles.filter((x) => !x.dead);
      for (const h of this.hazards) h.update(dt);
      this.hazards = this.hazards.filter((x) => !x.dead);
      for (const c of this.pickups) c.update(dt);
      this.pickups = this.pickups.filter((x) => !x.dead);

      // battle music when yokai chase the player
      if (!this.boss && this.zone) {
        const fighting = this.enemies.some((e) => (e.state === 'chase' || e.state === 'windup' || e.state === 'strike') && e.dist() < 400);
        const want = fighting ? 'battle' : this.zone.music;
        if (G.audio.current() !== want && !this.player.state.startsWith('ult')) {
          this.musicSwitchT = (this.musicSwitchT || 0) + dt;
          if (this.musicSwitchT > (fighting ? 0.3 : 3)) { G.audio.music(want); this.musicSwitchT = 0; }
        } else this.musicSwitchT = 0;
      }

      // interaction target
      this.interactTarget = null;
      if (!this.frozen && p.state === 'move') {
        let best = null, bd = 84;
        for (const n of this.npcs) {
          if (n.hidden) continue;
          const d = G.dist(p.x, p.y, n.x, n.y);
          if (d < bd) { bd = d; best = n; }
        }
        if (best) this.interactTarget = { npc: best, label: best.id === 'merchant' ? '사기' : '말걸기' };
      }
      if (this.interactTarget && G.input.hit('interact')) {
        G.audio.sfx('ui');
        G.story.interact(this.interactTarget.npc);
      }
      G.story.update(dt);
      this.updateTutorial();
      this.updateCam(dt);
      fx.update(dt);
      // gates that opened while the player was elsewhere
      this.dissolveGates();
    },

    snapCam() {
      const p = this.player;
      if (!p) return;
      this.cam.x = p.x - G.viewW / 2; this.cam.y = p.y - 50 - G.VIEW_H / 2;
      this.clampCam();
    },
    clampCam() {
      this.cam.x = G.clamp(this.cam.x, 0, G.world.pw - G.viewW);
      this.cam.y = G.clamp(this.cam.y, 0, G.world.ph - G.VIEW_H);
    },
    updateCam(dt) {
      const p = this.player;
      let tx, ty, k = 6;
      if (this.camFocus) { tx = this.camFocus.x; ty = this.camFocus.y; k = this.camPanSpeed || 2; }
      else if (this.boss && this.arena) { tx = (p.x * 2 + this.boss.x) / 3; ty = (p.y * 2 + this.boss.y) / 3 - 40; }
      else { tx = p.x + Math.cos(p.face) * 30; ty = p.y - 50 + Math.sin(p.face) * 20; }
      const wx = tx - G.viewW / 2, wy = ty - G.VIEW_H / 2;
      const a = 1 - Math.exp(-k * dt);
      this.cam.x += (wx - this.cam.x) * a; this.cam.y += (wy - this.cam.y) * a;
      this.clampCam();
    },

    // ---------- draw ----------
    draw(ctx) {
      const vw = G.viewW, vh = G.VIEW_H;
      const sh = fx.shake;
      const cam = { x: Math.round(this.cam.x + (Math.random() - 0.5) * sh), y: Math.round(this.cam.y + (Math.random() - 0.5) * sh) };
      this.drawCam = cam;
      ctx.fillStyle = '#0a0d1a'; ctx.fillRect(0, 0, vw, vh);
      G.world.drawGround(ctx, cam, vw, vh);
      G.world.drawWater(ctx, cam, vw, vh, this.time);
      this.drawGates(ctx, cam);
      // flat props + ground hazards
      const props = G.world.props;
      const inView = (x, y, m = 260) => x > cam.x - m && x < cam.x + vw + m && y > cam.y - 40 && y < cam.y + vh + m;
      for (const pr of props) if (pr.k.flat && inView(pr.x, pr.y)) this.drawProp(ctx, cam, pr);
      for (const h of this.hazards) h.draw(ctx, cam);
      fx.drawGround(ctx, cam);
      if (this.arena) {
        const ar = this.arena;
        ctx.strokeStyle = 'rgba(160,80,255,0.35)'; ctx.lineWidth = 3; ctx.setLineDash([10, 8]);
        ctx.beginPath(); ctx.ellipse(ar.x - cam.x, ar.y - cam.y, ar.r + 12, (ar.r + 12) * 0.7, 0, 0, Math.PI * 2); ctx.stroke(); ctx.setLineDash([]);
      }
      // sorted sprites
      const list = [];
      for (const pr of props) if (!pr.k.flat && inView(pr.x, pr.y)) list.push(pr);
      for (const n of this.npcs) if (!n.hidden && inView(n.x, n.y)) list.push(n);
      for (const e of this.enemies) if (inView(e.x, e.y)) list.push(e);
      for (const c of this.pickups) list.push(c);
      for (const pr of this.projectiles) list.push(pr);
      list.push(this.player);
      list.sort((a, b) => a.y - b.y);
      const p = this.player;
      for (const o of list) {
        if (o.kind) {
          // fade tall props that hide the player
          const A = G.assets.props[o.kind];
          let alpha = 1;
          const ks = A ? A.scale || 1 : 1;
          if (A && o.y > p.y && o.y - p.y < A.h * ks - 10 && Math.abs(o.x - p.x) < (A.bw * ks) / 2 + 10 && A.h * ks > 70) alpha = 0.55;
          this.drawProp(ctx, cam, o, alpha);
        } else o.draw(ctx, cam);
      }
      fx.drawWorld(ctx, cam);
      this.drawLights(ctx, cam, vw, vh);
      ctx.globalCompositeOperation = 'soft-light'; ctx.fillStyle = 'rgba(255,186,110,0.35)'; ctx.fillRect(0, 0, vw, vh); ctx.globalCompositeOperation = 'source-over';
      fx.drawTexts(ctx, cam);
      if (!G.ui.dialog && !this.cinema && G.state === 'play') G.ui.drawGuide(ctx, cam, vw, vh);
      // vignette
      const vg = ctx.createRadialGradient(vw / 2, vh / 2, vh * 0.35, vw / 2, vh / 2, vw * 0.7);
      vg.addColorStop(0, 'rgba(0,0,0,0)'); vg.addColorStop(1, 'rgba(20,10,20,0.32)');
      ctx.fillStyle = vg; ctx.fillRect(0, 0, vw, vh);
      if (p.hp < p.maxHp * 0.3 && p.state !== 'dead') {
        ctx.fillStyle = `rgba(160,0,20,${0.12 + Math.sin(this.time * 5) * 0.06})`; ctx.fillRect(0, 0, vw, vh);
      }
      if (fx.flash > 0) { ctx.globalAlpha = Math.min(1, fx.flash); ctx.fillStyle = fx.flashColor; ctx.fillRect(0, 0, vw, vh); ctx.globalAlpha = 1; }
      if (this.deathT != null) {
        const k = Math.min(1, this.deathT / 1.5);
        ctx.fillStyle = `rgba(0,0,0,${k * 0.9})`; ctx.fillRect(0, 0, vw, vh);
        ctx.globalAlpha = k; ctx.font = 'bold 28px "Noto Serif KR", serif'; ctx.textAlign = 'center'; ctx.fillStyle = '#c8b8e8';
        ctx.fillText('넋이 흐려진다…', vw / 2, vh / 2); ctx.globalAlpha = 1;
      }
    },
    drawProp(ctx, cam, pr, alpha = 1) {
      const A = G.assets.props[pr.kind];
      if (!A) return;
      if (pr.gate === 'south' && this.flags.gate_open) alpha *= 0.0;
      if (alpha <= 0) return;
      const x = Math.round(pr.x - cam.x), y = Math.round(pr.y - cam.y);
      if (pr.k.shadow) {
        ctx.fillStyle = 'rgba(0,0,10,0.32)';
        ctx.beginPath(); ctx.ellipse(x, y - 2, pr.k.shadow, pr.k.shadow * 0.32, 0, 0, Math.PI * 2); ctx.fill();
      }
      ctx.globalAlpha = alpha;
      const k = A.scale || 1;
      ctx.save(); ctx.translate(x, y); ctx.scale(pr.flipX ? -k : k, k);
      if (k < 1) { ctx.imageSmoothingEnabled = true; ctx.imageSmoothingQuality = 'high'; }
      ctx.drawImage(A.img, -A.ax, -A.ay);
      ctx.restore();
      ctx.globalAlpha = 1;
    },
    drawGates(ctx, cam) {
      // purple miasma walls on locked paths
      for (const g of G.world.GATES) {
        if (this.flags[g.flag] || g.id === 'south') continue;
        const x0 = g.x0 * T - cam.x, y0 = g.y0 * T - cam.y, w = (g.x1 - g.x0 + 1) * T, h = (g.y1 - g.y0 + 1) * T;
        if (x0 > G.viewW || y0 > G.VIEW_H || x0 + w < 0 || y0 + h < 0) continue;
        if (Math.random() < 0.5) fx.smoke(g.x0 * T + Math.random() * w, g.y0 * T + Math.random() * h, 1, '#7a2cff');
        ctx.globalCompositeOperation = 'lighter';
        const gr = ctx.createRadialGradient(x0 + w / 2, y0 + h / 2, 0, x0 + w / 2, y0 + h / 2, Math.max(w, h) * 0.7);
        gr.addColorStop(0, 'rgba(120,40,255,0.35)'); gr.addColorStop(1, 'rgba(60,0,120,0)');
        ctx.fillStyle = gr; ctx.fillRect(x0 - w, y0 - h, w * 3, h * 3);
        ctx.globalCompositeOperation = 'source-over';
      }
    },
    drawLights(ctx, cam, vw, vh) {
      if (!this.lightCanvas) { this.lightCanvas = document.createElement('canvas'); }
      const L = this.lightCanvas, s = 0.5;
      const lw = Math.ceil(vw * s), lh = Math.ceil(vh * s);
      if (L.width !== lw || L.height !== lh) { L.width = lw; L.height = lh; }
      const g = L.getContext('2d');
      const zid = this.zone ? this.zone.id : 'beach';
      const dark = { beach: 0.08, town: 0.12, ruin: 0.34, pond: 0.26, forest: 0.36, house: 0.3 }[zid] ?? 0.15;
      g.globalCompositeOperation = 'source-over';
      g.clearRect(0, 0, lw, lh);
      g.fillStyle = `rgba(34,20,52,${dark})`; g.fillRect(0, 0, lw, lh);
      g.globalCompositeOperation = 'destination-out';
      const lights = [];
      const p = this.player;
      lights.push([p.x, p.y - 30, 190, null, 0.85]);
      for (const pr of G.world.props) if (pr.light) {
        const [ox, oy, r, col, a] = pr.light;
        const x = pr.x + ox, y = pr.y + oy;
        if (x > cam.x - r && x < cam.x + vw + r && y > cam.y - r && y < cam.y + vh + r) lights.push([x, y, r * (1 + Math.sin(this.time * 7 + pr.x) * 0.03), col, a]);
      }
      for (const pr of this.projectiles) if (pr.kind) lights.push([pr.x, pr.y - (pr.z || 0), 70, null, 0.6]);
      for (const n of this.npcs) if (!n.hidden && (n.id === 'yongwang' || n.id === 'sansin')) lights.push([n.x, n.y - 40, 130, '#7fd0ff', 0.6]);
      if (p.state === 'ult') lights.push([p.x, p.y - 30, 200 + p.stateT * 300, '#fff0c0', 1]);
      for (const [x, y, r, , a] of lights) {
        const lx = (x - cam.x) * s, ly = (y - cam.y) * s, lr = r * s;
        const gr = g.createRadialGradient(lx, ly, 0, lx, ly, lr);
        gr.addColorStop(0, `rgba(0,0,0,${a})`); gr.addColorStop(1, 'rgba(0,0,0,0)');
        g.fillStyle = gr; g.beginPath(); g.arc(lx, ly, lr, 0, Math.PI * 2); g.fill();
      }
      ctx.imageSmoothingEnabled = true;
      ctx.drawImage(L, 0, 0, vw, vh);
      ctx.imageSmoothingEnabled = false;
      // warm/colored glow
      ctx.globalCompositeOperation = 'lighter';
      for (const [x, y, r, col, a] of lights) {
        if (!col) continue;
        const gr = ctx.createRadialGradient(x - cam.x, y - cam.y, 0, x - cam.x, y - cam.y, r * 0.8);
        const c = col.match(/\w\w/g).map((h) => parseInt(h, 16));
        gr.addColorStop(0, `rgba(${c[0]},${c[1]},${c[2]},${0.22 * a})`); gr.addColorStop(1, 'rgba(0,0,0,0)');
        ctx.fillStyle = gr; ctx.fillRect(x - cam.x - r, y - cam.y - r, r * 2, r * 2);
      }
      ctx.globalCompositeOperation = 'source-over';
    },
  };
  G.game = game;
})();
