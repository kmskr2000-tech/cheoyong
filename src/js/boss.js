// Boss patterns. Each boss telegraphs its attacks (ground marks, flashes) and kneels instead of dying.
'use strict';
(() => {
  const fx = G.fx;
  const sfx = (n) => G.audio.sfx(n);
  const E = G.Enemy.prototype;

  E.bossUpdate = function (dt) {
    const p = G.game.player;
    this.cool -= dt;
    if (this.state === 'kneel' || this.kneeling) { this.setAnim('idle'); return; }
    if (this.state === 'idle' || this.state === 'wander' || this.state === 'chase') this.state = 'move';
    const fn = BOSS[this.type];
    if (fn) fn.call(this, dt, p);
  };

  // helpers
  function chaseTo(b, dt, minD, speedMul = 1) {
    const d = b.dist(), a = b.angTo();
    if (d > minD) b.walk(a, b.def.spd * speedMul, dt);
    else { b.faceTo(a); b.setAnim('idle'); }
  }
  function pick(b, list) {
    // weighted random pick of the next attack, avoiding a repeat
    const opts = list.filter((x) => x[0] !== b.lastMove || list.length === 1);
    let s = opts.reduce((a, x) => a + x[1], 0) * Math.random();
    for (const x of opts) { s -= x[1]; if (s <= 0) { b.lastMove = x[0]; return x[0]; } }
    return opts[0][0];
  }
  function begin(b, move) { b.state = move; b.stateT = 0; b.step = 0; sfx('tell'); }
  const phase2 = (b) => b.hp < b.maxHp * 0.5;

  const BOSS = {
    // 도깨비 대장: club swing, ground slam rings, charge, summons imps at half health
    dokchief(dt, p) {
      const d = this.dist();
      switch (this.state) {
        case 'move':
          chaseTo(this, dt, 70);
          if (phase2(this) && !this.summoned) { this.summoned = true; begin(this, 'summon'); break; }
          if (this.cool <= 0) begin(this, d < 110 ? pick(this, [['swing', 3], ['slam', 2]]) : pick(this, [['charge', 3], ['slam', 2], ['swing', 1]]));
          break;
        case 'swing':
          this.setAnim('idle'); if (this.stateT < 0.5) this.faceTo(this.angTo());
          if (this.stateT > 0.55 && !this.step) {
            this.step = 1; this.setAnim('attack'); this.animT = 0; sfx('slam');
            const ad = Math.abs(G.angDiff(this.face, this.angTo()));
            if (d < 130 && ad < 1.4) p.hurt(this.atkV * 1.3, this.x, this.y);
            fx.screenShake(5);
            fx.burst(this.x + Math.cos(this.face) * 80, this.y + Math.sin(this.face) * 50, 16, { color: '#d9c4a0', speed: 160, life: 0.5 });
          }
          if (this.stateT > 1.1) { this.state = 'move'; this.cool = phase2(this) ? 0.6 : 1.1; }
          break;
        case 'slam': {
          this.setAnim('idle');
          const n = phase2(this) ? 3 : 2;
          if (this.step < n && this.stateT > 0.2 + this.step * 0.5) {
            const r = 90 + this.step * 70;
            G.game.hazards.push(new G.Hazard(this.x, this.y, r, { warn: 0.8, dmg: this.atkV, color: '#ff8040' }));
            this.step++;
          }
          if (this.stateT > 0.2 + n * 0.5 + 0.9) { this.state = 'move'; this.cool = 1.2; }
          break;
        }
        case 'charge':
          if (this.stateT < 0.7) { this.faceTo(this.angTo()); this.setAnim('idle'); if (Math.random() < 0.4) fx.add({ x: this.x, y: this.y, z: 4, vz: 30, vx: (Math.random() - 0.5) * 60, life: 0.4, size: 4, color: '#a08a6a', g: 100 }); }
          else if (this.stateT < 1.4) {
            this.walk(this.face, 380, dt);
            if (!this.step && d < this.r + p.r + 20) { this.step = 1; p.hurt(this.atkV * 1.2, this.x, this.y); }
          } else { this.state = 'move'; this.cool = 1.0; }
          break;
        case 'summon':
          this.setAnim('attack');
          if (this.stateT > 0.5 && !this.step) {
            this.step = 1; G.audio.sfx('roar'); fx.screenShake(8);
            for (let i = 0; i < 3; i++) {
              const a = (i / 3) * Math.PI * 2;
              G.game.spawnEnemy('imp', this.x + Math.cos(a) * 110, this.y + Math.sin(a) * 70, { level: 2, zone: null, summoned: true });
            }
          }
          if (this.stateT > 1.2) { this.state = 'move'; this.cool = 1; }
          break;
      }
    },

    // 구미호: fox-fire volleys, dash slashes, illusion copies at half health
    gumiho(dt, p) {
      const d = this.dist();
      switch (this.state) {
        case 'move': {
          // keep a middle distance, circling
          const a = this.angTo();
          if (d < 150) this.walk(a + Math.PI * 0.75, this.def.spd, dt);
          else if (d > 280) this.walk(a, this.def.spd, dt);
          else this.walk(a + Math.PI / 2, this.def.spd * 0.6, dt);
          if (phase2(this) && !this.cloned) { this.cloned = true; begin(this, 'clone'); break; }
          if (this.cool <= 0) begin(this, pick(this, [['volley', 3], ['dash', 2], ['ring', phase2(this) ? 2 : 1]]));
          break;
        }
        case 'volley': {
          this.faceTo(this.angTo()); this.setAnim('attack');
          const n = phase2(this) ? 3 : 2;
          if (this.step < n && this.stateT > 0.45 + this.step * 0.45) {
            this.step++; sfx('fire');
            const base = this.angTo(), k = phase2(this) ? 7 : 5;
            for (let i = 0; i < k; i++) {
              const a = base + (i - (k - 1) / 2) * 0.2;
              G.game.projectiles.push(new G.Orb(this.x, this.y - 10, Math.cos(a) * 190, Math.sin(a) * 190, this.atkV * 0.8, 'fire', { homing: 0.6, life: 3 }));
            }
          }
          if (this.stateT > 0.45 + n * 0.45 + 0.4) { this.state = 'move'; this.cool = 1.2; }
          break;
        }
        case 'dash':
          if (this.stateT < 0.55) { this.faceTo(this.angTo()); this.setAnim('idle'); this.dashA = this.face; }
          else if (this.stateT < 0.95) {
            this.walk(this.dashA, 520, dt); this.setAnim('attack');
            if (!this.step && d < this.r + p.r + 24) { this.step = 1; p.hurt(this.atkV * 1.1, this.x, this.y); }
            fx.add({ x: this.x, y: this.y, z: 20, life: 0.3, size: 4, color: '#9fe0ff', glow: true });
          } else { this.state = 'move'; this.cool = 0.9; }
          break;
        case 'ring':
          this.setAnim('attack');
          if (this.stateT > 0.6 && !this.step) {
            this.step = 1; sfx('fire');
            for (let i = 0; i < 14; i++) {
              const a = (i / 14) * Math.PI * 2;
              G.game.projectiles.push(new G.Orb(this.x, this.y - 10, Math.cos(a) * 150, Math.sin(a) * 150, this.atkV * 0.8, 'fire', { life: 3.5 }));
            }
          }
          if (this.stateT > 1.3) { this.state = 'move'; this.cool = 1.3; }
          break;
        case 'clone':
          this.setAnim('attack'); this.invuln = true;
          if (this.stateT > 0.6 && !this.step) {
            this.step = 1; sfx('roar'); fx.screenFlash(0.4, '#9fe0ff');
            for (let i = 0; i < 2; i++) {
              const a = Math.random() * Math.PI * 2;
              const c = G.game.spawnEnemy('gumiho', this.x + Math.cos(a) * 160, this.y + Math.sin(a) * 100, { level: 1, zone: null, summoned: true });
              c.maxHp = c.hp = 60; c.illusion = true; c.def = { ...c.def, boss: false, name: '여우 환영', exp: 5, coin: [1, 2], ai: 'ranged' };
              c.atkV = this.atkV * 0.6; c.r = 18; c.alpha = 0.6;
            }
          }
          if (this.stateT > 1.0) { this.invuln = false; this.state = 'move'; this.cool = 0.8; }
          break;
      }
    },

    // 이무기: water spit lines, tail sweep around itself, submerge and rise elsewhere, snakes at half health
    imugi(dt, p) {
      const d = this.dist();
      switch (this.state) {
        case 'move':
          chaseTo(this, dt, 140, 1);
          if (phase2(this) && !this.summoned) { this.summoned = true; begin(this, 'summon'); break; }
          if (this.cool <= 0) begin(this, d < 140 ? pick(this, [['sweep', 3], ['dive', 1]]) : pick(this, [['spit', 3], ['dive', 2], ['rain', phase2(this) ? 2 : 1]]));
          break;
        case 'spit': {
          this.faceTo(this.angTo()); this.setAnim('attack');
          const n = phase2(this) ? 5 : 4;
          if (this.step < n && this.stateT > 0.5 + this.step * 0.22) {
            this.step++; sfx('fire');
            const a = this.angTo() + (Math.random() - 0.5) * 0.25;
            G.game.projectiles.push(new G.Orb(this.x, this.y - 20, Math.cos(a) * 260, Math.sin(a) * 260, this.atkV * 0.8, 'water', { r: 11, life: 2.5 }));
          }
          if (this.stateT > 0.5 + n * 0.22 + 0.5) { this.state = 'move'; this.cool = 1.2; }
          break;
        }
        case 'sweep':
          this.setAnim('idle');
          if (!this.step) { this.step = 1; G.game.hazards.push(new G.Hazard(this.x, this.y, 150, { warn: 0.9, dmg: this.atkV * 1.2, color: '#40a0ff' })); }
          if (this.stateT > 0.9 && this.step === 1) { this.step = 2; this.setAnim('attack'); this.animT = 0; }
          if (this.stateT > 1.6) { this.state = 'move'; this.cool = 1.0; }
          break;
        case 'dive':
          if (this.stateT < 0.6) { this.alpha = 1 - this.stateT / 0.6; if (Math.random() < 0.6) fx.burst(this.x, this.y, 2, { color: '#7fc8ff', speed: 80, up: 120, life: 0.6 }); }
          else if (this.stateT < 1.4) {
            this.alpha = 0; this.invuln = true;
            if (!this.step) {
              this.step = 1;
              const a = Math.random() * Math.PI * 2;
              this.tx = p.x + Math.cos(a) * 60; this.ty = p.y + Math.sin(a) * 40;
              if (G.world.blocked(this.tx, this.ty, this.r)) { this.tx = p.x; this.ty = p.y; }
              G.game.hazards.push(new G.Hazard(this.tx, this.ty, 110, { warn: 0.8, dmg: this.atkV * 1.3, color: '#40a0ff' }));
            }
          } else if (this.step === 1) {
            this.step = 2; this.x = this.tx; this.y = this.ty; this.alpha = 1; this.invuln = false;
            fx.burst(this.x, this.y, 30, { color: '#9fd8ff', speed: 200, up: 260, life: 0.8, size: 3 }); fx.screenShake(8); sfx('roar');
          } else if (this.stateT > 2.0) { this.state = 'move'; this.cool = 1.0; }
          break;
        case 'rain':
          this.setAnim('attack');
          if (this.step < 6 && this.stateT > 0.4 + this.step * 0.25) {
            this.step++;
            G.game.hazards.push(new G.Hazard(p.x + (Math.random() - 0.5) * 120, p.y + (Math.random() - 0.5) * 80, 54, { warn: 0.8, dmg: this.atkV * 0.8, color: '#40a0ff' }));
          }
          if (this.stateT > 2.4) { this.state = 'move'; this.cool = 1.2; }
          break;
        case 'summon':
          this.setAnim('attack');
          if (this.stateT > 0.5 && !this.step) {
            this.step = 1; sfx('roar');
            for (let i = 0; i < 3; i++) {
              const a = (i / 3) * Math.PI * 2 + 0.5;
              G.game.spawnEnemy('snake', this.x + Math.cos(a) * 140, this.y + Math.sin(a) * 90 + 40, { level: 3, zone: null, summoned: true });
            }
          }
          if (this.stateT > 1.2) { this.state = 'move'; this.cool = 1; }
          break;
      }
    },

    // 역신: plague clouds, shadow bolts, ghost summons, blinks; at 30% the song completes (story)
    yeoksin(dt, p) {
      const d = this.dist();
      if (!this.turned && this.hp <= this.maxHp * 0.3) {
        this.turned = true; this.hp = Math.ceil(this.maxHp * 0.3); this.invuln = true; this.state = 'hold'; this.stateT = 0;
        for (const h of G.game.hazards) h.dead = true;
        for (const pr of G.game.projectiles) if (pr.owner === 'enemy') pr.dead = true;
        G.story.yeoksinTurn(this);
        return;
      }
      if (this.ultVulnerable && this.invuln) this.invuln = false;
      if (this.ultVulnerable) {
        // after the song is complete it only staggers; only 처용가 can finish it
        this.hp = Math.max(this.hp, Math.ceil(this.maxHp * 0.05));
      }
      switch (this.state) {
        case 'hold': this.setAnim('idle'); if (this.ultVulnerable) { this.state = 'move'; this.cool = 1.5; } break;
        case 'move': {
          const a = this.angTo();
          if (d < 160) this.walk(a + Math.PI * 0.8, this.def.spd, dt);
          else if (d > 300) this.walk(a, this.def.spd, dt);
          else this.walk(a - Math.PI / 2, this.def.spd * 0.5, dt);
          if (this.cool <= 0) begin(this, pick(this, [['bolts', 3], ['cloud', 3], ['blink', 2], ['summon', this.ghosts() < 2 ? 2 : 0.01]]));
          break;
        }
        case 'bolts': {
          this.faceTo(this.angTo()); this.setAnim('attack');
          const n = this.ultVulnerable ? 2 : 4;
          if (this.step < n && this.stateT > 0.5 + this.step * 0.3) {
            this.step++; sfx('fire');
            for (const off of [-0.35, 0, 0.35]) {
              const a = this.angTo() + off;
              G.game.projectiles.push(new G.Orb(this.x, this.y - 30, Math.cos(a) * 200, Math.sin(a) * 200, this.atkV * 0.75, 'shadow', { homing: 0.4 }));
            }
          }
          if (this.stateT > 0.5 + n * 0.3 + 0.4) { this.state = 'move'; this.cool = 1.1; }
          break;
        }
        case 'cloud':
          this.setAnim('attack');
          if (this.step < 3 && this.stateT > 0.4 + this.step * 0.35) {
            this.step++;
            G.game.hazards.push(new G.Hazard(p.x + (Math.random() - 0.5) * 140, p.y + (Math.random() - 0.5) * 90, 70, { warn: 0.9, life: 3.2, dmg: this.atkV * 0.5, color: '#5aff3a', kind: 'cloud' }));
          }
          if (this.stateT > 1.8) { this.state = 'move'; this.cool = 1.2; }
          break;
        case 'blink':
          if (this.stateT < 0.4) { this.alpha = 1 - this.stateT / 0.4; fx.smoke(this.x, this.y - 30, 1, '#5a2a8a'); }
          else if (!this.step) {
            this.step = 1;
            const ar = G.game.arena;
            const a = Math.random() * Math.PI * 2, rr = 120 + Math.random() * 120;
            let nx = ar.x + Math.cos(a) * rr, ny = ar.y + Math.sin(a) * rr * 0.6;
            if (G.world.blocked(nx, ny, this.r)) { nx = ar.x; ny = ar.y; }
            this.x = nx; this.y = ny;
          } else if (this.stateT < 0.8) this.alpha = (this.stateT - 0.4) / 0.4;
          else { this.alpha = 1; this.state = 'move'; this.cool = 0.4; }
          break;
        case 'summon':
          this.setAnim('attack');
          if (this.stateT > 0.6 && !this.step) {
            this.step = 1; sfx('roar');
            for (let i = 0; i < 2; i++) {
              const a = Math.random() * Math.PI * 2;
              G.game.spawnEnemy('ghost', this.x + Math.cos(a) * 120, this.y + Math.sin(a) * 80, { level: 4, zone: null, summoned: true });
            }
          }
          if (this.stateT > 1.2) { this.state = 'move'; this.cool = 1.2; }
          break;
      }
    },
  };
  E.ghosts = function () { return G.game.enemies.filter((e) => e.type === 'ghost' && !e.dead && e.state !== 'kneel').length; };
})();
