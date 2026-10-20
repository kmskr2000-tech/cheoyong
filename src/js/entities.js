// Entities: player (Cheoyong), NPCs, yokai, bosses, projectiles, pickups. Combat rules live here.
'use strict';
(() => {
  const A = G.assets;
  const fx = G.fx;
  const sfx = (n) => G.audio.sfx(n);

  // ---------- data ----------
  const MASKS = {
    cheoyong: { name: '처용탈', desc: '균형 · 흥 +30%', atk: 1, taken: 1, heung: 1.3, giRegen: 1, skill: 1, color: '#ff6a5a' },
    gwimyeon: { name: '귀면탈', desc: '공격 +35% · 받는 피해 +15%', atk: 1.35, taken: 1.15, heung: 1, giRegen: 1, skill: 1, color: '#c04cff' },
    yongwang: { name: '용왕탈', desc: '기 회복 2배 · 스킬 피해 +20%', atk: 1, taken: 1, heung: 1, giRegen: 2, skill: 1.2, color: '#4cd6ff' },
  };
  const SKILLS = {
    skill1: { id: 'sorigyeol', name: '소리결', gi: 12, cd: 0.6 },
    skill2: { id: 'hoeori', name: '탈춤 회오리', gi: 18, cd: 1.2 },
    skill3: { id: 'mulgyeol', name: '용왕 물결', gi: 20, cd: 1.0 },
  };
  const ENEMIES = {
    imp: { name: '꼬마도깨비', hp: 34, atk: 6, spd: 78, r: 10, ai: 'melee', range: 36, exp: 8, coin: [1, 3], fam: 'dokkaebi' },
    snake: { name: '구렁이', hp: 48, atk: 8, spd: 55, r: 12, ai: 'lunge', range: 100, exp: 10, coin: [2, 4], fam: 'snake' },
    dokkaebi: { name: '도깨비', hp: 80, atk: 11, spd: 62, r: 13, ai: 'heavy', range: 50, exp: 16, coin: [3, 6], fam: 'dokkaebi' },
    ghoul: { name: '두억시니', hp: 100, atk: 13, spd: 48, r: 14, ai: 'slam', range: 60, exp: 18, coin: [3, 7], fam: 'ghoul' },
    ghost: { name: '원귀', hp: 56, atk: 9, spd: 66, r: 11, ai: 'ranged', range: 210, exp: 14, coin: [2, 5], fam: 'ghost', float: true },
    // bosses
    dokchief: { name: '도깨비 대장', hp: 650, atk: 16, spd: 70, r: 26, ai: 'boss', exp: 120, coin: [40, 50], boss: true, fam: 'dokkaebi' },
    gumiho: { name: '구미호', hp: 720, atk: 15, spd: 95, r: 22, ai: 'boss', exp: 140, coin: [40, 50], boss: true, fam: 'fox' },
    imugi: { name: '이무기', hp: 820, atk: 17, spd: 40, r: 30, ai: 'boss', exp: 160, coin: [45, 60], boss: true, fam: 'snake' },
    yeoksin: { name: '역신', hp: 1500, atk: 18, spd: 80, r: 22, ai: 'boss', exp: 300, coin: [0, 0], boss: true, fam: 'plague' },
  };
  G.MASKS = MASKS; G.SKILLS = SKILLS; G.ENEMIES = ENEMIES;

  // ---------- drawing ----------
  function drawShadow(ctx, cam, x, y, w) {
    ctx.fillStyle = 'rgba(0,0,10,0.38)';
    ctx.beginPath(); ctx.ellipse(Math.round(x - cam.x), Math.round(y - cam.y), w, w * 0.36, 0, 0, Math.PI * 2); ctx.fill();
  }
  // draws a character frame with its feet at (x,y)
  function drawSprite(ctx, cam, name, anim, dir, t, x, y, o = {}) {
    const f = A.frame(name, anim, dir, t, o.fps || 10, o.loop !== false);
    if (!f) return;
    const c = f.c, w = c.w, h = c.h;
    const k = (o.scale || 1) * (c.scale || 1);
    const sx = k, sy = k * (o.squash || 1);
    const px = Math.round(x - cam.x), py = Math.round(y - cam.y - (o.z || 0));
    ctx.save();
    if (k < 1) { ctx.imageSmoothingEnabled = true; ctx.imageSmoothingQuality = 'high'; }
    ctx.translate(px, py);
    if (f.mirror) ctx.scale(-1, 1);
    ctx.scale(sx, sy);
    ctx.globalAlpha = o.alpha ?? 1;
    const dx = -w / 2, dy = -c.foot;
    ctx.drawImage(c.img, f.sx, f.sy, w, h, dx, dy, w, h);
    if (o.flash > 0) { ctx.globalAlpha = Math.min(1, o.flash) * (o.alpha ?? 1); ctx.drawImage(c.white, f.sx, f.sy, w, h, dx, dy, w, h); }
    if (o.dark > 0) { ctx.globalAlpha = o.dark * (o.alpha ?? 1); ctx.drawImage(c.dark, f.sx, f.sy, w, h, dx, dy, w, h); }
    ctx.restore();
  }
  G.drawSprite = drawSprite;
  G.drawShadow = drawShadow;

  // ---------- base actor ----------
  class Actor {
    constructor(x, y) {
      this.x = x; this.y = y; this.r = 10; this.face = Math.PI / 2; this.dir = 'south';
      this.anim = 'idle'; this.animT = 0; this.flash = 0; this.kbx = 0; this.kby = 0; this.dead = false; this.z = 0;
    }
    setAnim(a) { if (this.anim !== a) { this.anim = a; this.animT = 0; } }
    faceTo(a) { this.face = a; this.dir = G.dirFromAngle(a); }
    applyKnock(dt) {
      if (Math.abs(this.kbx) + Math.abs(this.kby) < 1) return;
      G.world.moveCircle(this, this.kbx * dt, this.kby * dt);
      const d = Math.exp(-10 * dt); this.kbx *= d; this.kby *= d;
    }
  }

  // ---------- player ----------
  class Player extends Actor {
    constructor(x, y) {
      super(x, y);
      this.r = 11; this.name = 'cheoyong';
      this.lvl = 1; this.exp = 0; this.coins = 0;
      this.maxHp = 100; this.hp = 100; this.maxGi = 100; this.gi = 100; this.heung = 0;
      this.items = { yakgwa: 1, sikhye: 1 };
      this.masks = []; this.mask = null;
      this.skills = {}; // skill1..3 unlocked
      this.state = 'move'; this.stateT = 0; this.combo = 0; this.comboWindow = 0;
      this.iframe = 0; this.cd = { roll: 0, skill1: 0, skill2: 0, skill3: 0 }; this.hitSet = new Set();
      this.speed = 150;
    }
    get m() { return MASKS[this.mask] || MASKS.cheoyong; }
    get atk() { return (10 + (this.lvl - 1) * 2.5) * (this.mask ? this.m.atk : 1); }
    expNeed() { return 20 + this.lvl * 18; }
    gainExp(n) {
      this.exp += n;
      while (this.exp >= this.expNeed()) {
        this.exp -= this.expNeed(); this.lvl++;
        this.maxHp += 14; this.hp = this.maxHp; this.gi = this.maxGi;
        fx.text(this.x, this.y - 100, '레벨 ' + this.lvl + '!', '#ffe27a', 22);
        fx.ring(this.x, this.y, 10, 90, 0.8, '#ffe27a', 3);
        sfx('level');
      }
    }
    addHeung(n) { if (!G.game.flags.has_ult) return; this.heung = Math.min(100, this.heung + n * (this.mask ? this.m.heung : 1)); }
    canAct() { return this.state === 'move'; }

    update(dt) {
      const inp = G.input, game = G.game;
      this.animT += dt; this.stateT += dt;
      this.flash = Math.max(0, this.flash - dt * 5);
      this.iframe = Math.max(0, this.iframe - dt);
      for (const k in this.cd) this.cd[k] = Math.max(0, this.cd[k] - dt);
      this.comboWindow = Math.max(0, this.comboWindow - dt);
      this.gi = Math.min(this.maxGi, this.gi + dt * 4 * (this.mask ? this.m.giRegen : 1));
      this.applyKnock(dt);
      if (this.state === 'dead') return;
      if (game.frozen) { this.setAnim('idle'); return; }

      const mv = inp.move();
      const moving = Math.hypot(mv.x, mv.y) > 0.15;

      if (this.state === 'move') {
        if (moving) {
          this.faceTo(Math.atan2(mv.y, mv.x));
          const sp = this.speed * Math.min(1, Math.hypot(mv.x, mv.y) * 1.2);
          G.world.moveCircle(this, mv.x * sp * dt, mv.y * sp * dt);
          this.arenaClamp();
          this.setAnim('walk');
        } else this.setAnim('idle');
        if (game.flags.has_attack && (inp.hit('attack') || inp.down('attack'))) this.startAttack();
        else if (game.flags.has_attack && inp.hit('roll') && this.cd.roll <= 0) this.startRoll(moving ? Math.atan2(mv.y, mv.x) : this.face);
        else for (const k of ['skill1', 'skill2', 'skill3']) if (inp.hit(k)) { this.trySkill(k); break; }
        if (this.state === 'move' && inp.hit('ult')) this.tryUlt();
        if (this.state === 'move') {
          if (inp.hit('item1')) this.useItem('yakgwa');
          if (inp.hit('item2')) this.useItem('sikhye');
          if (inp.hit('mask')) this.cycleMask();
        }
      } else if (this.state === 'attack') {
        const dur = this.combo === 2 ? 0.42 : 0.3;
        // small lunge
        if (this.stateT < 0.1) G.world.moveCircle(this, Math.cos(this.face) * 140 * dt, Math.sin(this.face) * 140 * dt);
        if (this.stateT >= 0.08 && !this.swung) { this.swung = true; this.meleeHit(); }
        if (inp.hit('attack') || (inp.down('attack') && this.stateT > 0.15)) this.queued = true;
        if (inp.hit('roll') && this.cd.roll <= 0 && this.stateT > 0.12) { this.startRoll(moving ? Math.atan2(mv.y, mv.x) : this.face); return; }
        if (this.stateT >= dur) {
          this.state = 'move'; this.comboWindow = 0.35;
          if (this.queued) { if (moving) this.faceTo(Math.atan2(mv.y, mv.x)); this.startAttack(); }
        }
      } else if (this.state === 'roll') {
        const k = 1 - this.stateT / 0.32;
        G.world.moveCircle(this, Math.cos(this.rollA) * 360 * k * dt * 1.4, Math.sin(this.rollA) * 360 * k * dt * 1.4);
        this.arenaClamp();
        if (Math.random() < 0.6) fx.add({ x: this.x, y: this.y, z: 2, vx: (Math.random() - 0.5) * 30, vz: 20, life: 0.4, size: 3, color: '#c9b89a', g: 60 });
        if (this.stateT >= 0.32) this.state = 'move';
      } else if (this.state === 'skill') {
        this.updateSkill(dt);
      } else if (this.state === 'hurt') {
        if (this.stateT >= 0.25) this.state = 'move';
      } else if (this.state === 'ult') {
        this.updateUlt(dt);
      }
    }
    arenaClamp() {
      const ar = G.game.arena;
      if (!ar) return;
      const dx = this.x - ar.x, dy = (this.y - ar.y) / 0.7, d = Math.hypot(dx, dy);
      if (d > ar.r) { this.x = ar.x + (dx / d) * ar.r; this.y = ar.y + (dy / d) * ar.r * 0.7; }
    }
    autoAim(range = 140) {
      // turn toward the nearest enemy in front if one is close (helps touch play)
      let best = null, bd = range;
      for (const e of G.game.enemies) {
        if (e.dead || e.state === 'kneel') continue;
        const d = G.dist(this.x, this.y, e.x, e.y);
        const ad = Math.abs(G.angDiff(this.face, Math.atan2(e.y - this.y, e.x - this.x)));
        if (d < bd && ad < 1.6) { bd = d; best = e; }
      }
      if (best) this.faceTo(Math.atan2(best.y - this.y, best.x - this.x));
    }
    startAttack() {
      this.combo = this.comboWindow > 0 ? (this.combo + 1) % 3 : 0;
      this.state = 'attack'; this.stateT = 0; this.swung = false; this.queued = false;
      this.autoAim();
      this.setAnim('attack'); this.animT = 0;
      sfx('swing');
      // sleeve arc effect
      const a = this.face;
      for (let i = 0; i < 7; i++) {
        const aa = a - 0.9 + (i / 6) * 1.8 * (this.combo === 1 ? -1 : 1) + (this.combo === 1 ? 1.8 : 0);
        fx.add({ x: this.x + Math.cos(aa) * 40, y: this.y + Math.sin(aa) * 28, z: 30, life: 0.18 + i * 0.015, size: 3, color: this.combo === 2 ? '#ffe9a8' : '#e8f4ff', glow: true });
      }
    }
    meleeHit() {
      const R = this.combo === 2 ? 72 : 60, arc = this.combo === 2 ? 1.5 : 1.15;
      const mult = this.combo === 2 ? 1.7 : 1;
      let hits = 0;
      for (const e of G.game.enemies) {
        if (e.dead || e.state === 'kneel' || e.invuln) continue;
        const d = G.dist(this.x, this.y, e.x, e.y) - e.r;
        const ad = Math.abs(G.angDiff(this.face, Math.atan2(e.y - this.y, e.x - this.x)));
        if (d < R && (ad < arc || d < 16)) {
          e.damage(this.atk * mult, Math.cos(this.face) * (this.combo === 2 ? 320 : 160), Math.sin(this.face) * (this.combo === 2 ? 320 : 160));
          hits++;
        }
      }
      if (hits) { this.addHeung(4 * hits); G.game.hitstop = Math.max(G.game.hitstop, this.combo === 2 ? 0.08 : 0.045); }
      G.game.onPlayerAttack && G.game.onPlayerAttack(hits);
    }
    startRoll(a) {
      this.state = 'roll'; this.stateT = 0; this.rollA = a; this.faceTo(a); this.iframe = 0.3; this.cd.roll = 0.5;
      this.setAnim('walk'); sfx('roll');
      G.game.onRoll && G.game.onRoll();
    }
    trySkill(k) {
      if (!this.skills[k]) return;
      const s = SKILLS[k];
      if (this.cd[k] > 0) return;
      if (this.gi < s.gi) { fx.text(this.x, this.y - 100, '기가 모자라오', '#9fd8ff', 14); return; }
      this.gi -= s.gi; this.cd[k] = s.cd;
      this.state = 'skill'; this.stateT = 0; this.skill = k; this.skillTick = 0;
      this.autoAim(220);
      if (k === 'skill1') { this.setAnim('attack'); sfx('skill1'); this.fireSoundWave(); fx.circle(this.x, this.y, 46, '#7ff0ff', 0.6); }
      if (k === 'skill2') { this.setAnim('cast'); sfx('skill2'); fx.circle(this.x, this.y, 90, '#ff9ad0', 1.2); }
      if (k === 'skill3') { this.setAnim('walk'); sfx('skill3'); this.waveHit = new Set(); fx.circle(this.x, this.y, 50, '#5ab8ff', 0.7); }
    }
    skillMult() { return this.mask ? this.m.skill : 1; }
    fireSoundWave() {
      // a widening arc of sound that hits everything in a cone
      G.game.projectiles.push(new SoundWave(this.x, this.y, this.face, this.atk * 1.7 * this.skillMult()));
    }
    updateSkill(dt) {
      const k = this.skill;
      if (k === 'skill1' && this.stateT > 0.3) this.state = 'move';
      if (k === 'skill2') {
        this.face += dt * 14; this.dir = G.dirFromAngle(this.face); this.setAnim('walk');
        const mv = G.input.move();
        G.world.moveCircle(this, mv.x * 90 * dt, mv.y * 90 * dt);
        this.skillTick -= dt;
        if (this.skillTick <= 0) {
          this.skillTick = 0.18;
          fx.ring(this.x, this.y, 30, 86, 0.3, '#ffd2f0', 2);
          let hits = 0;
          for (const e of G.game.enemies) {
            if (e.dead || e.state === 'kneel' || e.invuln) continue;
            const d = G.dist(this.x, this.y, e.x, e.y) - e.r;
            if (d < 84) {
              const a = Math.atan2(e.y - this.y, e.x - this.x);
              e.damage(this.atk * 0.55 * this.skillMult(), Math.cos(a) * 120, Math.sin(a) * 120); hits++;
            }
          }
          if (hits) this.addHeung(2 * hits);
        }
        for (let i = 0; i < 2; i++) {
          const a = Math.random() * Math.PI * 2;
          fx.add({ x: this.x + Math.cos(a) * 60, y: this.y + Math.sin(a) * 40, z: 10 + Math.random() * 40, vx: -Math.sin(a) * 120, vy: Math.cos(a) * 80, life: 0.35, size: 3, color: ['#ff9ad0', '#ffe9a8', '#9fe0ff'][i % 3], glow: true });
        }
        if (this.stateT > 1.1) this.state = 'move';
      }
      if (k === 'skill3') {
        const t = this.stateT;
        if (t < 0.35) {
          const sp = 520 * (1 - t / 0.35) + 120;
          G.world.moveCircle(this, Math.cos(this.face) * sp * dt, Math.sin(this.face) * sp * dt);
          this.arenaClamp();
          this.iframe = Math.max(this.iframe, 0.05);
          for (let i = 0; i < 3; i++) fx.add({ x: this.x + (Math.random() - 0.5) * 40, y: this.y + (Math.random() - 0.5) * 20, z: Math.random() * 20, vz: 80 + Math.random() * 80, g: 300, life: 0.5, size: 3, color: ['#4cd6ff', '#bff2ff', '#2a7cff'][i], glow: true });
          for (const e of G.game.enemies) {
            if (e.dead || e.state === 'kneel' || e.invuln || this.waveHit.has(e)) continue;
            if (G.dist(this.x, this.y, e.x, e.y) - e.r < 56) {
              this.waveHit.add(e);
              e.damage(this.atk * 2.1 * this.skillMult(), Math.cos(this.face) * 300, Math.sin(this.face) * 300);
              this.addHeung(4);
            }
          }
        } else if (t > 0.5) this.state = 'move';
      }
    }
    tryUlt() {
      if (!G.game.flags.has_ult) return;
      if (this.heung < 100) { fx.text(this.x, this.y - 100, '흥이 덜 찼소', '#ffb3d0', 14); return; }
      this.heung = 0; this.state = 'ult'; this.stateT = 0; this.iframe = 3; this.setAnim('cast');
      G.game.ultActive = true;
      sfx('ult'); G.audio.music && G.game.pushMusic('song');
      G.game.onUlt && G.game.onUlt();
    }
    updateUlt(dt) {
      const t = this.stateT;
      if (Math.random() < 0.7) {
        const a = Math.random() * Math.PI * 2, rr = 40 + Math.random() * 300;
        fx.add({ x: this.x + Math.cos(a) * rr, y: this.y + Math.sin(a) * rr * 0.6, z: 0, vz: 40 + Math.random() * 60, life: 1.2, size: 3, color: ['#ffe9a8', '#9fe0ff', '#ff9ad0'][Math.floor(Math.random() * 3)], glow: true });
      }
      if (t > 0.6 && !this.ultRing1) { this.ultRing1 = true; fx.ring(this.x, this.y, 20, 420, 1.2, '#ffe9a8', 4); fx.circle(this.x, this.y, 160, '#ffe08a', 2.2); }
      if (t > 1.6 && !this.ultHit) {
        this.ultHit = true;
        fx.ring(this.x, this.y, 20, 600, 1.4, '#9fe0ff', 6); fx.screenFlash(0.8, '#fff6d8'); fx.screenShake(8);
        const verses = G.game.verseCount();
        for (const e of G.game.enemies) {
          if (e.dead || e.state === 'kneel') continue;
          const d = G.dist(this.x, this.y, e.x, e.y);
          if (d < 620) {
            const dmg = this.atk * (3 + verses * 1.2);
            if (e.def.boss) e.damage(e.ultVulnerable ? 99999 : Math.min(dmg, e.maxHp * 0.22), 0, 0, true);
            else e.damage(99999, 0, 0, true);
          }
        }
      }
      if (t > 2.6) {
        this.state = 'move'; this.ultRing1 = this.ultHit = false; G.game.ultActive = false; G.game.popMusic();
      }
    }
    useItem(k) {
      if (!this.items[k]) { fx.text(this.x, this.y - 100, k === 'yakgwa' ? '약과가 없소' : '식혜가 없소', '#ccc', 14); return; }
      if (k === 'yakgwa') { if (this.hp >= this.maxHp) return; this.hp = Math.min(this.maxHp, this.hp + this.maxHp * 0.4); fx.text(this.x, this.y - 100, '+체력', '#7dff9a', 16); }
      if (k === 'sikhye') { if (this.gi >= this.maxGi) return; this.gi = Math.min(this.maxGi, this.gi + 60); fx.text(this.x, this.y - 100, '+기', '#7fd0ff', 16); }
      this.items[k]--; sfx('item');
      fx.burst(this.x, this.y - 40, 10, { color: k === 'yakgwa' ? '#7dff9a' : '#7fd0ff', glow: true, g: 0, speed: 60, life: 0.6 });
    }
    cycleMask() {
      if (this.masks.length < 2) return;
      const i = this.masks.indexOf(this.mask);
      this.mask = this.masks[(i + 1) % this.masks.length];
      fx.text(this.x, this.y - 104, this.m.name, this.m.color, 16);
      fx.ring(this.x, this.y, 10, 60, 0.5, this.m.color, 3);
      sfx('ui');
    }
    hurt(dmg, fromX, fromY) {
      if (this.iframe > 0 || this.state === 'dead' || this.state === 'ult' || G.game.frozen) return false;
      if (G.params.has('god')) { this.flash = 1; this.iframe = 0.3; return true; }
      dmg = Math.round(dmg * (this.mask ? this.m.taken : 1) * (0.9 + Math.random() * 0.2));
      this.hp -= dmg; this.flash = 1; this.iframe = 0.7;
      const a = Math.atan2(this.y - fromY, this.x - fromX);
      this.kbx = Math.cos(a) * 260; this.kby = Math.sin(a) * 260;
      fx.text(this.x, this.y - 90, '-' + dmg, '#ff7a7a', 16); fx.screenShake(5); sfx('hurt');
      this.addHeung(6);
      if (this.state !== 'ult') { this.state = 'hurt'; this.stateT = 0; }
      if (this.hp <= 0) { this.hp = 0; this.state = 'dead'; this.stateT = 0; G.game.onPlayerDeath(); }
      return true;
    }
    draw(ctx, cam) {
      const blink = this.iframe > 0 && this.state !== 'roll' && this.state !== 'ult' && Math.floor(this.iframe * 20) % 2 === 0;
      drawShadow(ctx, cam, this.x, this.y, 18);
      // mask aura at the feet
      if (this.mask) {
        ctx.globalCompositeOperation = 'lighter';
        ctx.globalAlpha = 0.25 + Math.sin(G.game.time * 3) * 0.08;
        ctx.strokeStyle = this.m.color; ctx.lineWidth = 2;
        ctx.beginPath(); ctx.ellipse(this.x - cam.x, this.y - cam.y, 22, 8, 0, 0, Math.PI * 2); ctx.stroke();
        ctx.globalAlpha = 1; ctx.globalCompositeOperation = 'source-over';
      }
      let anim = this.anim, t = this.animT, fps = 10, loop = true, dir = this.dir;
      if (this.state === 'attack') { anim = 'attack'; fps = A.animLen('cheoyong', 'attack', dir) / (this.combo === 2 ? 0.42 : 0.3); loop = false; }
      if (this.state === 'roll') { anim = 'walk'; fps = 22; }
      if (this.state === 'hurt') { anim = A.has('cheoyong', 'hurt') ? 'hurt' : 'idle'; fps = 14; loop = false; }
      if (this.state === 'ult' || (this.state === 'skill' && this.skill === 'skill2' && false)) { anim = 'cast'; dir = 'south'; fps = 8; }
      if (this.state === 'dead') { anim = 'hurt'; loop = false; }
      if (anim === 'idle') { fps = 6; }
      const squash = this.state === 'roll' ? 0.82 : this.state === 'dead' ? Math.max(0.5, 1 - this.stateT) : 1;
      drawSprite(ctx, cam, 'cheoyong', anim, dir, t, this.x, this.y, { fps, loop, flash: this.flash, alpha: blink ? 0.45 : 1, squash });
    }
  }

  // ---------- projectiles ----------
  class SoundWave {
    constructor(x, y, a, dmg) { this.x = x; this.y = y; this.a = a; this.dmg = dmg; this.t = 0; this.hit = new Set(); this.owner = 'player'; }
    update(dt) {
      this.t += dt;
      const R = 40 + this.t * 520;
      for (const e of G.game.enemies) {
        if (e.dead || e.state === 'kneel' || e.invuln || this.hit.has(e)) continue;
        const d = G.dist(this.x, this.y, e.x, e.y);
        const ad = Math.abs(G.angDiff(this.a, Math.atan2(e.y - this.y, e.x - this.x)));
        if (d - e.r < R && ad < 0.62) { this.hit.add(e); e.damage(this.dmg, Math.cos(this.a) * 240, Math.sin(this.a) * 240); G.game.player.addHeung(3); }
      }
      if (this.t > 0.42) this.dead = true;
    }
    draw(ctx, cam) {
      const R = 40 + this.t * 520, k = this.t / 0.42;
      ctx.globalCompositeOperation = 'lighter';
      for (let i = 0; i < 3; i++) {
        const rr = R - i * 18; if (rr < 10) continue;
        ctx.strokeStyle = `rgba(160,225,255,${(1 - k) * (0.8 - i * 0.22)})`; ctx.lineWidth = 3 - i;
        ctx.beginPath(); ctx.ellipse(this.x - cam.x, this.y - 30 - cam.y, rr, rr * 0.65, 0, this.a - 0.6, this.a + 0.6); ctx.stroke();
      }
      ctx.globalCompositeOperation = 'source-over';
    }
  }

  class Orb {
    // enemy projectile: kind fire|plague|water|shadow
    constructor(x, y, vx, vy, dmg, kind = 'fire', o = {}) {
      Object.assign(this, { x, y, vx, vy, dmg, kind, t: 0, life: o.life || 3, r: o.r || 9, homing: o.homing || 0, z: o.z ?? 30, owner: 'enemy' });
    }
    update(dt) {
      this.t += dt;
      const p = G.game.player;
      if (this.homing && this.t < 1.4) {
        const a = Math.atan2(p.y - this.y, p.x - this.x), sp = Math.hypot(this.vx, this.vy);
        const cur = Math.atan2(this.vy, this.vx), na = cur + G.clamp(G.angDiff(cur, a), -this.homing * dt, this.homing * dt);
        this.vx = Math.cos(na) * sp; this.vy = Math.sin(na) * sp;
      }
      this.x += this.vx * dt; this.y += this.vy * dt;
      if (Math.random() < 0.5) fx.add({ x: this.x, y: this.y, z: this.z, life: 0.3, size: 3, color: COL[this.kind][1], glow: true });
      if (G.dist(this.x, this.y, p.x, p.y) < this.r + p.r) { if (p.hurt(this.dmg, this.x, this.y)) this.dead = true; }
      if (this.t > this.life || G.world.solidAt(this.x, this.y) && this.kind !== 'shadow' && this.t > 0.2) this.dead = true;
    }
    draw(ctx, cam) {
      const [c0, c1] = COL[this.kind];
      ctx.globalCompositeOperation = 'lighter';
      const g = ctx.createRadialGradient(this.x - cam.x, this.y - this.z - cam.y, 0, this.x - cam.x, this.y - this.z - cam.y, this.r * 1.8);
      g.addColorStop(0, '#ffffff'); g.addColorStop(0.35, c0); g.addColorStop(1, 'rgba(0,0,0,0)');
      ctx.fillStyle = g; ctx.beginPath(); ctx.arc(this.x - cam.x, this.y - this.z - cam.y, this.r * 1.8, 0, Math.PI * 2); ctx.fill();
      ctx.globalCompositeOperation = 'source-over';
      drawShadow(ctx, cam, this.x, this.y, 6);
    }
  }
  const COL = { fire: ['#4cb8ff', '#9fe0ff'], plague: ['#8aff6a', '#c0ff9a'], water: ['#3a9cff', '#bfe6ff'], shadow: ['#b04cff', '#e0a8ff'], red: ['#ff5a3a', '#ffb08a'] };

  // lingering ground hazard (plague cloud / telegraphed slam)
  class Hazard {
    constructor(x, y, r, o = {}) {
      Object.assign(this, { x, y, r, t: 0, warn: o.warn ?? 0.8, life: o.life ?? 0.25, dmg: o.dmg || 10, color: o.color || '#ff5050', kind: o.kind || 'slam', tick: 0, owner: 'enemy', ring: o.ring });
    }
    update(dt) {
      this.t += dt;
      const p = G.game.player;
      if (this.t >= this.warn) {
        if (!this.fired) {
          this.fired = true;
          if (this.kind === 'slam') { fx.ring(this.x, this.y, this.r * 0.3, this.r, 0.35, '#ffd0a0', 4); fx.screenShake(6); sfx('slam'); fx.burst(this.x, this.y, 14, { speed: 160, up: 120, color: '#8a7a6a', life: 0.6, size: 3 }); }
        }
        this.tick -= dt;
        const inside = Math.hypot(p.x - this.x, (p.y - this.y) / 0.62) < this.r;
        if (inside && this.tick <= 0) { if (p.hurt(this.dmg, this.x, this.y)) this.tick = 0.6; }
      }
      if (this.t > this.warn + this.life) this.dead = true;
    }
    draw(ctx, cam) {
      const k = Math.min(1, this.t / this.warn);
      const x = this.x - cam.x, y = this.y - cam.y;
      if (this.t < this.warn) {
        ctx.fillStyle = this.color; ctx.globalAlpha = 0.15 + 0.15 * Math.sin(this.t * 20);
        ctx.beginPath(); ctx.ellipse(x, y, this.r, this.r * 0.62, 0, 0, Math.PI * 2); ctx.fill();
        ctx.globalAlpha = 0.5; ctx.strokeStyle = this.color; ctx.lineWidth = 2;
        ctx.beginPath(); ctx.ellipse(x, y, this.r * k, this.r * k * 0.62, 0, 0, Math.PI * 2); ctx.stroke();
      } else if (this.kind === 'cloud') {
        const fade = Math.min(1, (this.warn + this.life - this.t) / 0.5);
        ctx.globalAlpha = 0.35 * fade; ctx.fillStyle = this.color;
        ctx.beginPath(); ctx.ellipse(x, y, this.r, this.r * 0.62, 0, 0, Math.PI * 2); ctx.fill();
        if (Math.random() < 0.3) fx.smoke(this.x + (Math.random() - 0.5) * this.r, this.y + (Math.random() - 0.5) * this.r * 0.5, 1, '#5aff3a');
      }
      ctx.globalAlpha = 1;
    }
  }

  // ---------- enemies ----------
  class Enemy extends Actor {
    constructor(type, x, y, o = {}) {
      super(x, y);
      this.type = type; this.def = ENEMIES[type];
      const lv = o.level || 1;
      this.maxHp = Math.round(this.def.hp * (1 + (lv - 1) * 0.25) * (this.def.boss ? 1.6 : 1)); this.hp = this.maxHp;
      this.atkV = this.def.atk * (1 + (lv - 1) * 0.15) * 1.2;
      this.r = this.def.r; this.lvl = lv; this.home = { x, y }; this.zone = o.zone; this.state = 'idle'; this.stateT = Math.random();
      this.wanderT = 0; this.sprite = type; this.aura = Math.random() * 6;
      this.spawnT = 0.6; this.cool = 0.5 + Math.random();
    }
    damage(d, kx, ky, ult = false) {
      if (this.dead || this.state === 'kneel' || this.invuln) return;
      d = Math.max(1, Math.round(d * (0.9 + Math.random() * 0.2)));
      this.hp -= d; this.flash = 1;
      const kbRes = this.def.boss ? 0.15 : 1;
      this.kbx += kx * kbRes; this.kby += ky * kbRes;
      fx.hit(this.x, this.y - (this.def.boss ? 60 : 20));
      fx.text(this.x + (Math.random() - 0.5) * 20, this.y - (this.def.boss ? 120 : 70), String(d), ult ? '#ffe9a8' : '#ffffff', ult ? 22 : 15);
      sfx('hit');
      if (this.state === 'idle' || this.state === 'wander') this.state = 'chase';
      if (!this.def.boss && this.state === 'windup' && d > this.maxHp * 0.25) { this.state = 'recover'; this.stateT = 0; }
      if (this.hp <= 0) { this.hp = 0; this.purifyStart(); }
      else if (this.onDamaged) this.onDamaged();
    }
    purifyStart() {
      if (this.def.boss && this.onDefeat) { this.onDefeat(); return; }
      this.state = 'kneel'; this.stateT = 0;
      sfx('purify');
      G.game.onPurify(this);
    }
    dist() { const p = G.game.player; return G.dist(this.x, this.y, p.x, p.y); }
    angTo() { const p = G.game.player; return Math.atan2(p.y - this.y, p.x - this.x); }
    update(dt) {
      this.animT += dt; this.stateT += dt; this.flash = Math.max(0, this.flash - dt * 6); this.aura += dt;
      this.spawnT = Math.max(0, this.spawnT - dt);
      this.applyKnock(dt);
      if (this.state === 'kneel') {
        if (Math.random() < 0.5 && this.stateT < 1.0) fx.smoke(this.x, this.y - 20, 1);
        if (this.stateT > 1.0 && !this.souled) { this.souled = true; fx.soul(this.x, this.y); fx.circle(this.x, this.y, 40, '#9fe0ff', 0.9); fx.ring(this.x, this.y, 5, 50, 0.6, '#9fe0ff', 2); }
        if (this.stateT > 1.6) this.dead = true;
        return;
      }
      if (G.game.frozen || this.spawnT > 0) return;
      if (this.def.ai === 'boss') { this.bossUpdate(dt); return; }
      const p = G.game.player, d = this.dist();
      const pAlive = p.state !== 'dead';
      this.cool -= dt;
      switch (this.state) {
        case 'idle': case 'wander': {
          if (pAlive && d < 240) { this.state = 'chase'; break; }
          this.wanderT -= dt;
          if (this.wanderT <= 0) { this.wanderT = 1.5 + Math.random() * 2; this.wa = Math.random() * Math.PI * 2; this.state = Math.random() < 0.5 ? 'wander' : 'idle'; }
          if (this.state === 'wander') {
            const hx = this.home.x - this.x, hy = this.home.y - this.y;
            const a = Math.hypot(hx, hy) > 90 ? Math.atan2(hy, hx) : this.wa;
            this.walk(a, this.def.spd * 0.4, dt);
          } else this.setAnim('idle');
          break;
        }
        case 'chase': {
          if (!pAlive || G.dist(this.x, this.y, this.home.x, this.home.y) > 520) { this.state = 'return'; break; }
          const a = this.angTo();
          const ai = this.def.ai;
          if (ai === 'ranged') {
            if (d < 140) this.walk(a + Math.PI, this.def.spd, dt);
            else if (d > 230) this.walk(a, this.def.spd, dt);
            else { this.walk(a + Math.PI / 2, this.def.spd * 0.5, dt); this.faceTo(a); }
            if (d < 280 && this.cool <= 0) this.windup();
          } else {
            if (d > this.def.range * 0.8) this.walk(a + this.sep(), this.def.spd, dt);
            else { this.faceTo(a); this.setAnim('idle'); }
            if (d < this.def.range && this.cool <= 0) this.windup();
          }
          break;
        }
        case 'return': {
          const a = Math.atan2(this.home.y - this.y, this.home.x - this.x);
          this.walk(a, this.def.spd, dt);
          this.hp = Math.min(this.maxHp, this.hp + dt * 20);
          if (G.dist(this.x, this.y, this.home.x, this.home.y) < 20) this.state = 'idle';
          if (pAlive && d < 160) this.state = 'chase';
          break;
        }
        case 'windup': {
          const ai = this.def.ai;
          const wt = ai === 'slam' ? 0.75 : ai === 'heavy' ? 0.55 : ai === 'lunge' ? 0.5 : 0.42;
          this.setAnim('idle');
          if (ai !== 'slam') this.faceTo(this.angTo());
          if (this.stateT >= wt) this.strike();
          break;
        }
        case 'strike': {
          const ai = this.def.ai;
          if (ai === 'lunge' || ai === 'melee') {
            const sp = ai === 'lunge' ? 420 : 200, dur = ai === 'lunge' ? 0.26 : 0.16;
            if (this.stateT < dur) {
              G.world.moveCircle(this, Math.cos(this.face) * sp * dt, Math.sin(this.face) * sp * dt);
              if (!this.didHit && d < this.r + p.r + 16) { this.didHit = true; p.hurt(this.atkV, this.x, this.y); }
            } else this.recover();
          } else if (ai === 'heavy') {
            if (!this.didHit && this.stateT > 0.06) {
              this.didHit = true;
              const ad = Math.abs(G.angDiff(this.face, this.angTo()));
              if (d < 64 + p.r && ad < 1.3) p.hurt(this.atkV * 1.3, this.x, this.y);
              fx.burst(this.x + Math.cos(this.face) * 40, this.y + Math.sin(this.face) * 26, 8, { color: '#d9c4a0', speed: 90, life: 0.4 });
            }
            if (this.stateT > 0.25) this.recover();
          } else if (ai === 'ranged') {
            if (!this.didHit) {
              this.didHit = true;
              const a = this.angTo();
              G.game.projectiles.push(new Orb(this.x, this.y, Math.cos(a) * 170, Math.sin(a) * 170, this.atkV, 'shadow', { homing: 0.8 }));
              sfx('fire');
            }
            if (this.stateT > 0.2) this.recover();
          } else if (ai === 'slam') {
            if (this.stateT > 0.75) this.recover();
          }
          break;
        }
        case 'recover': {
          this.setAnim('idle');
          if (this.stateT > (this.def.ai === 'slam' ? 0.9 : 0.6)) this.state = 'chase';
          break;
        }
      }
    }
    sep() {
      // steer slightly away from nearby allies so they surround instead of stacking
      let s = 0;
      for (const o of G.game.enemies) {
        if (o === this || o.dead) continue;
        const d = G.dist(this.x, this.y, o.x, o.y);
        if (d < 40 && d > 0) s += G.angDiff(this.angTo(), Math.atan2(this.y - o.y, this.x - o.x)) > 0 ? 0.4 : -0.4;
      }
      return G.clamp(s, -0.9, 0.9);
    }
    walk(a, sp, dt) {
      this.faceTo(a);
      const ox = this.x, oy = this.y;
      G.world.moveCircle(this, Math.cos(a) * sp * dt, Math.sin(a) * sp * dt);
      if (Math.hypot(this.x - ox, this.y - oy) < sp * dt * 0.2) {
        // stuck: try sideways
        G.world.moveCircle(this, Math.cos(a + 1.4) * sp * dt, Math.sin(a + 1.4) * sp * dt);
      }
      this.setAnim('walk');
    }
    windup() {
      this.state = 'windup'; this.stateT = 0; this.didHit = false; sfx('tell');
      if (this.def.ai === 'slam') {
        const p = G.game.player;
        G.game.hazards.push(new Hazard(this.x + Math.cos(this.angTo()) * 30, this.y + Math.sin(this.angTo()) * 20, 74, { warn: 0.75, dmg: this.atkV * 1.2 }));
      }
    }
    strike() { this.state = 'strike'; this.stateT = 0; this.setAnim('attack'); }
    recover() { this.state = 'recover'; this.stateT = 0; this.cool = 0.8 + Math.random() * 0.8; }
    draw(ctx, cam) {
      const isBoss = this.def.boss;
      const k = this.state === 'kneel' ? this.stateT : 0;
      drawShadow(ctx, cam, this.x, this.y, isBoss ? 44 : this.r * 1.6);
      // cursed aura
      if (this.state !== 'kneel' && !this.calm) {
        ctx.globalCompositeOperation = 'lighter';
        const a = 0.18 + Math.sin(this.aura * 3) * 0.06;
        const g = ctx.createRadialGradient(this.x - cam.x, this.y - cam.y - 20, 0, this.x - cam.x, this.y - cam.y - 20, isBoss ? 90 : 40);
        g.addColorStop(0, `rgba(140,60,255,${a})`); g.addColorStop(1, 'rgba(0,0,0,0)');
        ctx.fillStyle = g; ctx.fillRect(this.x - cam.x - 100, this.y - cam.y - 120, 200, 200);
        ctx.globalCompositeOperation = 'source-over';
      }
      const tell = this.state === 'windup' && Math.floor(this.stateT * 14) % 2 === 0;
      let anim = this.anim, fps = 9, loop = true;
      if (this.state === 'strike') { anim = 'attack'; fps = 14; loop = false; }
      if (this.state === 'kneel' || this.kneeling) anim = A.has(this.sprite, 'kneel') ? 'kneel' : 'idle';
      const float = this.def.float ? Math.sin(this.aura * 2.5) * 4 + 8 : 0;
      const squash = this.state === 'kneel' ? 1 - Math.min(0.28, k * 0.5) : this.spawnT > 0 ? 1 - this.spawnT : 1;
      drawSprite(ctx, cam, this.sprite, anim, this.dir, this.animT, this.x, this.y, {
        fps, loop, flash: Math.max(this.flash, tell ? 0.55 : 0), squash, z: float,
        alpha: (this.alpha ?? 1) * (this.state === 'kneel' ? Math.max(0, 1 - Math.max(0, k - 0.9) * 1.6) : this.spawnT > 0 ? 1 - Math.min(1, this.spawnT) : 1),
        dark: this.state === 'kneel' ? 0 : 0.12, scale: this.scale || 1,
      });
      if (this.state === 'kneel' && k < 1) {
        // the white glow of purification
        ctx.globalCompositeOperation = 'lighter';
        ctx.globalAlpha = Math.sin(k * Math.PI) * 0.6;
        drawSprite(ctx, cam, this.sprite, anim, this.dir, this.animT, this.x, this.y, { flash: 1, squash, alpha: Math.sin(k * Math.PI) * 0.7, scale: this.scale || 1 });
        ctx.globalCompositeOperation = 'source-over'; ctx.globalAlpha = 1;
      }
      if (!isBoss && this.hp < this.maxHp && this.state !== 'kneel') {
        const w = 30, x = Math.round(this.x - cam.x - w / 2), y = Math.round(this.y - cam.y - ((A.chars[this.sprite]?.foot || 60) - (A.chars[this.sprite]?.top || 0)) * (A.chars[this.sprite]?.scale || 1) * (this.scale || 1) - 10 - float);
        ctx.fillStyle = 'rgba(0,0,0,0.6)'; ctx.fillRect(x - 1, y - 1, w + 2, 5);
        ctx.fillStyle = '#c04cff'; ctx.fillRect(x, y, Math.round((w * this.hp) / this.maxHp), 3);
      }
    }
  }

  // ---------- NPC ----------
  class Npc extends Actor {
    constructor(id, sprite, x, y, o = {}) {
      super(x, y);
      Object.assign(this, { id, sprite, name: o.name || id, r: 12, solid: true, dirHome: o.dir || 'south' });
      this.dir = this.dirHome; this.bob = Math.random() * 4; this.visibleIf = o.visibleIf; this.hidden = false;
    }
    update(dt) {
      this.animT += dt; this.bob += dt;
      const p = G.game.player;
      const d = G.dist(this.x, this.y, p.x, p.y);
      if (d < 110) this.faceTo(Math.atan2(p.y - this.y, p.x - this.x));
      else this.dir = this.dirHome;
      if (this.walkTo) {
        const dx = this.walkTo.x - this.x, dy = this.walkTo.y - this.y, dd = Math.hypot(dx, dy);
        if (dd < 3) { this.walkTo = null; this.anim = 'idle'; }
        else { this.x += (dx / dd) * 90 * dt; this.y += (dy / dd) * 90 * dt; this.faceTo(Math.atan2(dy, dx)); this.anim = 'walk'; }
      }
    }
    draw(ctx, cam) {
      drawShadow(ctx, cam, this.x, this.y, this.sprite === 'dog' ? 12 : 16);
      const anim = this.anim === 'walk' && A.has(this.sprite, 'walk') ? 'walk' : 'idle';
      drawSprite(ctx, cam, this.sprite, anim, this.dir, this.animT, this.x, this.y, { fps: anim === 'idle_anim' ? 6 : 10, alpha: this.alpha ?? 1, scale: this.scale || 1 });
      // MMORPG-style name tag
      const c = A.chars[this.sprite];
      if (c && this.name && this.id !== 'dog') {
        const hy = Math.round(this.y - cam.y - (c.foot - c.top) * (c.scale || 1) - 8), hx = Math.round(this.x - cam.x);
        ctx.font = 'bold 11px "Noto Sans KR", sans-serif'; ctx.textAlign = 'center';
        const w = ctx.measureText(this.name).width + 12;
        ctx.fillStyle = 'rgba(40,24,70,0.72)'; ctx.beginPath(); ctx.roundRect(hx - w / 2, hy - 12, w, 16, 8); ctx.fill();
        ctx.fillStyle = '#efe4ff'; ctx.fillText(this.name, hx, hy);
      }
    }
  }

  // ---------- pickups ----------
  class Coin {
    constructor(x, y, v) {
      const a = Math.random() * Math.PI * 2, s = 40 + Math.random() * 80;
      Object.assign(this, { x, y, v, vx: Math.cos(a) * s, vy: Math.sin(a) * s * 0.6, z: 10, vz: 120 + Math.random() * 80, t: 0 });
    }
    update(dt) {
      this.t += dt;
      this.vz -= 500 * dt; this.z += this.vz * dt;
      if (this.z < 0) { this.z = 0; this.vz *= -0.4; this.vx *= 0.5; this.vy *= 0.5; }
      this.x += this.vx * dt; this.y += this.vy * dt;
      const p = G.game.player, d = G.dist(this.x, this.y, p.x, p.y);
      if (this.t > 0.5 && d < 120) { const a = Math.atan2(p.y - this.y, p.x - this.x); this.x += Math.cos(a) * 360 * dt; this.y += Math.sin(a) * 360 * dt; }
      if (this.t > 0.4 && d < 20) { this.dead = true; p.coins += this.v; sfx('coin'); }
      if (this.t > 30) this.dead = true;
    }
    draw(ctx, cam) {
      const x = Math.round(this.x - cam.x), y = Math.round(this.y - cam.y - this.z - 4);
      drawShadow(ctx, cam, this.x, this.y, 4);
      const w = Math.max(1, Math.round(Math.abs(Math.cos(this.t * 6)) * 4));
      ctx.fillStyle = '#7a5a10'; ctx.fillRect(x - w - 1, y - 5, w * 2 + 2, 10);
      ctx.fillStyle = '#ffd25a'; ctx.fillRect(x - w, y - 4, w * 2, 8);
      ctx.fillStyle = '#7a5a10'; if (w > 1) ctx.fillRect(x - 1, y - 1, 2, 2);
    }
  }

  Object.assign(G, { Player, Enemy, Npc, Coin, Orb, Hazard, SoundWave });
})();
