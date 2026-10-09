// Player, enemies, boss, attack zones and visual effects.
import { G, BAL, atk, toast, shake, addExp } from './state.js';
import { input } from './input.js';
import { sfx } from './audio.js';
import { SPR, C, drawBoss } from './gfx.js';
import { shadow, rim } from './post.js';

const TAU = Math.PI * 2;
export const dist = (a, b) => Math.hypot(a.x - b.x, a.y - b.y);
export function angDiff(a, b) { let d = (a - b) % TAU; if (d > Math.PI) d -= TAU; if (d < -Math.PI) d += TAU; return Math.abs(d); }
const clamp = (v, a, b) => Math.max(a, Math.min(b, v));
const rand = (a, b) => a + Math.random() * (b - a);

// ============================================================ effects
export class Particle {
  constructor(x, y, vx, vy, life, color, size = 2, grav = 0) {
    Object.assign(this, { x, y, vx, vy, life, max: life, color, size, grav });
  }
  update(dt) { this.x += this.vx * dt; this.y += this.vy * dt; this.vy += this.grav * dt; this.life -= dt; return this.life > 0; }
  draw(g) {
    g.globalAlpha = clamp(this.life / this.max, 0, 1);
    g.fillStyle = this.color;
    const s = this.size;
    g.fillRect(Math.round(this.x - s / 2), Math.round(this.y - s / 2), s, s);
    g.globalAlpha = 1;
  }
}
export class SlashFx {
  constructor(x, y, ang, r, half, color = '#9fe8ff', ttl = 0.18, width = 4) {
    Object.assign(this, { x, y, ang, r, half, color, ttl, max: ttl, width });
  }
  update(dt) { this.ttl -= dt; return this.ttl > 0; }
  draw(g) {
    const k = this.ttl / this.max;
    g.save();
    g.globalAlpha = k;
    g.strokeStyle = this.color;
    for (let i = 0; i < 3; i++) {
      g.lineWidth = Math.max(1, this.width - i * 1.3);
      g.beginPath();
      const rr = this.r * (0.75 + i * 0.12) * (1.1 - k * 0.2);
      g.arc(this.x, this.y, rr, this.ang - this.half, this.ang + this.half);
      g.stroke();
    }
    g.restore();
  }
}
export class Ring {
  constructor(x, y, r0, r1, ttl, color, width = 2) { Object.assign(this, { x, y, r0, r1, ttl, max: ttl, color, width }); }
  update(dt) { this.ttl -= dt; return this.ttl > 0; }
  draw(g) {
    const k = 1 - this.ttl / this.max;
    g.save(); g.globalAlpha = 1 - k; g.strokeStyle = this.color; g.lineWidth = this.width;
    g.beginPath(); g.arc(this.x, this.y, this.r0 + (this.r1 - this.r0) * k, 0, TAU); g.stroke(); g.restore();
  }
}
export class TextPop {
  constructor(x, y, text, color = '#fff', ttl = 0.8, big = false) { Object.assign(this, { x, y, text, color, ttl, max: ttl, big, screenText: true }); }
  update(dt) { this.ttl -= dt; this.y -= 18 * dt; return this.ttl > 0; }
}
// 오방색 파문 for purification
export function obangRipple(lvl, x, y) {
  const cols = ['#3a6ad8', '#d83a3a', '#e8c040', '#f0f0f0', '#202020'];
  cols.forEach((c, i) => lvl.fx.push(new Ring(x, y, 4 + i * 3, 50 + i * 8, 0.8 + i * 0.12, c, 2)));
  for (let i = 0; i < 24; i++) {
    const a = Math.random() * TAU, sp = rand(20, 70);
    lvl.fx.push(new Particle(x, y, Math.cos(a) * sp, Math.sin(a) * sp - 20, rand(0.6, 1.2), cols[i % 5], 2));
  }
}

// ============================================================ zones (talismans, boss fog)
export class Zone {
  // kind: fire | bind | fog | fogTele | vent
  constructor(kind, x, y, r, ttl, opt = {}) {
    Object.assign(this, { kind, x, y, r, ttl, max: ttl, tick: 0, t: 0, ...opt });
  }
  update(dt, lvl) {
    this.ttl -= dt; this.t += dt; this.tick -= dt;
    if (this.kind === 'fire') {
      if (this.tick <= 0) {
        this.tick = 0.3;
        for (const e of lvl.allTargets()) {
          if (this.contains(e)) e.takeHit({ dmg: 5, pur: 4, talisman: 'fire', kx: 0, ky: 0, noStagger: true }, lvl);
        }
      }
      if (Math.random() < 0.8) {
        const a = this.ang + rand(-this.half, this.half), d = rand(6, this.r);
        lvl.fx.push(new Particle(this.x + Math.cos(a) * d, this.y + Math.sin(a) * d, 0, -rand(15, 40), rand(0.3, 0.6), Math.random() < 0.5 ? '#ff8a3a' : '#ffd060', 2));
      }
    } else if (this.kind === 'bind') {
      for (const e of lvl.allTargets()) if (dist(this, e) < this.r) e.slowT = 0.2;
      if (this.tick <= 0) {
        this.tick = 0.5;
        for (const e of lvl.allTargets()) if (dist(this, e) < this.r) e.takeHit({ dmg: 1, pur: 1.5, talisman: 'bind', kx: 0, ky: 0, noStagger: true, quiet: true }, lvl);
      }
    } else if (this.kind === 'fog') {
      const p = lvl.player;
      if (p && dist(this, p) < this.r && this.t > 0.3) {
        this.acc = (this.acc || 0) + dt * 5;
        if (this.acc >= 2.5) { this.acc -= 2.5; p.takeHit({ dmg: 2.5, srcX: this.x, srcY: this.y, dot: true }, lvl); }
      }
      if (Math.random() < 0.5) lvl.fx.push(new Particle(this.x + rand(-this.r, this.r) * 0.8, this.y + rand(-this.r, this.r) * 0.6, rand(-5, 5), -rand(4, 12), rand(0.6, 1.2), Math.random() < 0.5 ? 'rgba(111,191,74,0.7)' : 'rgba(182,255,106,0.5)', 3));
    }
    return this.ttl > 0;
  }
  contains(e) {
    if (this.kind === 'fire') {
      const d = Math.hypot(e.x - this.x, e.y - this.y);
      return d < this.r + (e.radius || 6) && angDiff(Math.atan2(e.y - this.y, e.x - this.x), this.ang) < this.half + 0.2;
    }
    return dist(this, e) < this.r;
  }
  drawGround(g) {
    const k = clamp(this.ttl / 0.5, 0, 1) * clamp(this.t / 0.2, 0, 1);
    g.save();
    if (this.kind === 'fire') {
      g.globalAlpha = 0.25 * k; g.fillStyle = '#ff7020';
      g.beginPath(); g.moveTo(this.x, this.y); g.arc(this.x, this.y, this.r, this.ang - this.half, this.ang + this.half); g.fill();
    } else if (this.kind === 'bind') {
      g.globalAlpha = 0.5 * k; g.strokeStyle = '#6aa8ff'; g.lineWidth = 1;
      g.beginPath(); g.arc(this.x, this.y, this.r, 0, TAU); g.stroke();
      g.globalAlpha = 0.12 * k; g.fillStyle = '#4a8ad8'; g.fill();
      g.globalAlpha = 0.6 * k; g.fillStyle = '#d8c89a';
      for (let i = 0; i < 5; i++) { const a = this.t * 0.8 + i * TAU / 5; g.fillRect(Math.round(this.x + Math.cos(a) * this.r - 2), Math.round(this.y + Math.sin(a) * this.r * 0.9 - 3), 4, 6); }
    } else if (this.kind === 'fog') {
      g.globalAlpha = 0.32 * k; g.fillStyle = '#4f9a35';
      g.beginPath(); g.ellipse(this.x, this.y, this.r, this.r * 0.8, 0, 0, TAU); g.fill();
      g.globalAlpha = 0.2 * k; g.fillStyle = '#9be05a';
      g.beginPath(); g.ellipse(this.x + Math.sin(this.t) * 4, this.y, this.r * 0.6, this.r * 0.45, 0, 0, TAU); g.fill();
    } else if (this.kind === 'tele') {
      // generic red telegraph circle that fills up
      const p = clamp(this.t / this.max, 0, 1);
      g.globalAlpha = 0.7; g.strokeStyle = '#ff4a3a'; g.lineWidth = 1;
      g.beginPath(); g.ellipse(this.x, this.y, this.r, this.r * 0.8, 0, 0, TAU); g.stroke();
      g.globalAlpha = 0.25; g.fillStyle = '#ff4a3a';
      g.beginPath(); g.ellipse(this.x, this.y, this.r * p, this.r * 0.8 * p, 0, 0, TAU); g.fill();
    }
    g.restore();
  }
}

// ============================================================ projectiles
export class Projectile {
  constructor(x, y, vx, vy, dmg, opt = {}) { Object.assign(this, { x, y, vx, vy, dmg, ttl: 2.5, r: 4, t: 0, ...opt }); }
  update(dt, lvl) {
    this.x += this.vx * dt; this.y += this.vy * dt; this.ttl -= dt; this.t += dt;
    if (lvl.solidAt(this.x, this.y)) { this.burst(lvl); return false; }
    const p = lvl.player;
    if (p && Math.hypot(p.x - this.x, p.y - 6 - this.y) < this.r + 5) {
      if (p.takeHit({ dmg: this.dmg, srcX: this.x - this.vx, srcY: this.y - this.vy }, lvl) !== 'dodged') { this.burst(lvl); return false; }
    }
    if (Math.random() < 0.5) lvl.fx.push(new Particle(this.x, this.y, 0, 0, 0.3, 'rgba(155,224,90,0.8)', 2));
    return this.ttl > 0;
  }
  burst(lvl) { for (let i = 0; i < 6; i++) lvl.fx.push(new Particle(this.x, this.y, rand(-40, 40), rand(-40, 40), 0.3, C.plagueL, 2)); }
  draw(g) {
    g.fillStyle = C.ink; g.fillRect(Math.round(this.x) - 3, Math.round(this.y) - 3, 6, 6);
    g.fillStyle = C.plague; g.fillRect(Math.round(this.x) - 2, Math.round(this.y) - 2, 4, 4);
    g.fillStyle = C.plagueL; g.fillRect(Math.round(this.x) - 1, Math.round(this.y) - 2, 2, 2);
  }
}

// ============================================================ player
const DIRS = { down: [0, 1], up: [0, -1], left: [-1, 0], right: [1, 0] };
export class Player {
  constructor(x, y) {
    this.x = x; this.y = y; this.w = 10; this.h = 6; this.radius = 6;
    this.vx = 0; this.vy = 0;
    this.dir = 'down'; this.fx = 0; this.fy = 1;
    this.state = 'idle';
    this.walkT = 0;
    this.sori = 100; this.sin = 0;
    this.combo = 0; this.comboWindow = 0; this.atkT = 0; this.atkDur = 0; this.atkHitDone = false; this.buffered = false;
    this.zHeldT = 0; this.zDown = false; this.chargeT = 0;
    this.rollT = 0; this.rollCd = 0; this.rollAge = 99; this.invuln = 0; this.hurtT = 0;
    this.parryBonus = false; this.parryChain = 0; this.parryChainT = 0;
    this.songT = 0; this.heightT = 0; this.ultT = 0; this.ultTick = 0; this.shield = 0;
    this.kx = 0; this.ky = 0;
    this.dead = false;
  }
  get hp() { return G.stats.hp; }
  set hp(v) { G.stats.hp = v; }

  ctrl() { return !G.scriptLock && !G.dialog && !G.menu; }

  update(dt, lvl) {
    if (this.dead) return;
    const T = (k) => { this[k] = Math.max(0, this[k] - dt); };
    ['comboWindow', 'rollCd', 'invuln', 'hurtT', 'songT', 'heightT', 'parryChainT'].forEach(T);
    this.rollAge += dt;
    if (this.parryChainT <= 0) this.parryChain = 0;
    this.sori = Math.min(100, this.sori + BAL.soriRegen * dt * (this.songT > 0 ? 2 : 1));
    if (this.shield > 0) this.shield -= dt;

    const ctl = this.ctrl();
    const ax = ctl ? input.axis() : { x: 0, y: 0 };
    let mx = ax.x, my = ax.y;
    if (mx && my) { mx *= Math.SQRT1_2; my *= Math.SQRT1_2; }
    const moving = mx !== 0 || my !== 0;
    const atkMul = this.heightT > 0 ? 0.77 : 1;

    // --- 처용무 (ultimate) ---
    if (this.ultT > 0) {
      this.ultT -= dt; this.ultTick -= dt;
      this.invuln = Math.max(this.invuln, 0.1);
      if (this.ultTick <= 0) {
        this.ultTick = 0.2;
        const ang = G.time * 9;
        lvl.fx.push(new SlashFx(this.x, this.y - 16, ang, 44, 1.2, '#ffd86a', 0.2, 3));
        for (const e of lvl.allTargets()) if (dist(e, this) < 70) e.takeHit({ dmg: BAL.ultDps * 0.2 * (e.isBoss ? 0.35 : 1), pur: e.isBoss ? 1 : 6, kx: 0, ky: 0, noStagger: !!e.isBoss, quiet: true }, lvl);
        sfx('slash');
      }
      this.move(lvl, mx * 60 * dt, my * 60 * dt);
      if (this.ultT <= 0) this.state = 'idle';
      return;
    }

    // facing
    if (moving && this.state !== 'attack' && this.state !== 'heavy') {
      const l = Math.hypot(mx, my); this.fx = mx / l; this.fy = my / l;
      this.dir = mx !== 0 ? (mx > 0 ? 'right' : 'left') : (my > 0 ? 'down' : 'up');
    }

    // --- input edges ---
    if (ctl) {
      if (input.pressed('attack')) {
        this.zDown = true; this.zHeldT = 0;
        if (lvl.tryInteract(this)) { this.zDown = false; }
        else if (this.state === 'idle' || this.state === 'move') this.startSlash(lvl);
        else if (this.state === 'attack') this.buffered = true;
      }
      if (this.zDown && input.down('attack')) this.zHeldT += dt;
      if (input.released('attack') || (this.zDown && !input.down('attack'))) {
        if (this.state === 'charge') {
          if (this.chargeT >= 0.45) this.startHeavy(lvl); else this.state = 'idle';
        }
        this.zDown = false;
      }
      if (input.pressed('dodge') && this.rollCd <= 0 && this.state !== 'roll') this.startRoll(lvl, mx, my);
      if (input.pressed('swap')) this.swapTalisman();
      if (input.pressed('cast') && this.state !== 'roll') this.castTalisman(lvl);
      if (input.pressed('song')) this.song(lvl);
      if (input.pressed('ult')) this.ult(lvl);
      if (input.pressed('item1')) this.useItem('insam', lvl);
      if (input.pressed('item2')) this.useItem('gugija', lvl);
      if (input.pressed('item3')) this.useItem('jeonghwa', lvl);
    } else {
      this.zDown = false;
      if (this.state === 'charge') this.state = 'idle';
    }

    // begin charging when Z is held long enough after the first slash
    if (this.zDown && this.zHeldT > 0.35 && (this.state === 'idle' || this.state === 'move')) {
      this.state = 'charge'; this.chargeT = 0;
    }

    let speed = 88 * (this.heightT > 0 ? 1.2 : 1);
    switch (this.state) {
      case 'idle': case 'move':
        this.state = moving ? 'move' : 'idle';
        this.move(lvl, mx * speed * dt, my * speed * dt);
        break;
      case 'charge':
        this.chargeT += dt;
        this.move(lvl, mx * speed * 0.4 * dt, my * speed * 0.4 * dt);
        if (this.chargeT >= 0.45 && !this.chargeReady) { this.chargeReady = true; sfx('bell'); lvl.fx.push(new Ring(this.x, this.y - 18, 4, 18, 0.3, '#ffffff')); }
        if (Math.random() < 0.5) lvl.fx.push(new Particle(this.x + rand(-10, 10), this.y + rand(-14, 2), 0, -20, 0.4, this.chargeReady ? '#ffffff' : '#9fe8ff', 1));
        break;
      case 'attack':
      case 'heavy': {
        this.atkT += dt;
        const step = this.atkT < this.atkDur * 0.4 ? 40 : 0;
        this.move(lvl, this.fx * step * dt, this.fy * step * dt);
        const hitAt = this.atkDur * 0.25;
        if (!this.atkHitDone && this.atkT >= hitAt) { this.atkHitDone = true; this.resolveSlash(lvl); }
        if (this.atkT >= this.atkDur) {
          const wasHeavy = this.state === 'heavy';
          this.state = 'idle';
          if (!wasHeavy) {
            this.comboWindow = 0.32;
            if (this.buffered && this.combo < 2) { this.combo++; this.buffered = false; this.startSlash(lvl, true); }
            else { if (this.combo >= 2) this.combo = -1; this.buffered = false; }
          }
        }
        break;
      }
      case 'roll': {
        this.rollT -= dt;
        if (moving) { const l = Math.hypot(mx, my); this.rvx = mx / l; this.rvy = my / l; }
        this.move(lvl, this.rvx * BAL.rollSpeed * dt, this.rvy * BAL.rollSpeed * dt);
        if (Math.random() < 0.7) lvl.fx.push(new Particle(this.x + rand(-4, 4), this.y, rand(-10, 10), -rand(5, 15), 0.35, '#6a7aa8', 2));
        if (this.rollT <= 0) { this.state = 'idle'; this.rollCd = 0.12; }
        break;
      }
      case 'hurt':
        if (this.hurtT <= 0.35) this.state = 'idle';
        break;
    }
    // knockback
    if (this.kx || this.ky) {
      this.move(lvl, this.kx * dt, this.ky * dt);
      this.kx *= Math.pow(0.001, dt); this.ky *= Math.pow(0.001, dt);
      if (Math.abs(this.kx) + Math.abs(this.ky) < 4) { this.kx = 0; this.ky = 0; }
    }
    if (moving && (this.state === 'move' || this.state === 'charge')) this.walkT += dt; else this.walkT = 0;
    if (this.songT > 0 && Math.random() < 0.15) lvl.fx.push(new Particle(this.x + rand(-8, 8), this.y - 34, rand(-6, 6), -18, 0.8, C.goldL, 2));
  }

  move(lvl, dx, dy) { lvl.moveEntity(this, dx, dy); }

  aimAssist(lvl) {
    let best = null, bd = 60;
    const fa = Math.atan2(this.fy, this.fx);
    for (const e of lvl.allTargets()) {
      const d = dist(e, this);
      if (d < bd && angDiff(Math.atan2(e.y - this.y, e.x - this.x), fa) < 1.0) { bd = d; best = e; }
    }
    if (best) {
      const a = Math.atan2(best.y - this.y, best.x - this.x);
      this.fx = Math.cos(a); this.fy = Math.sin(a);
      this.dir = Math.abs(this.fx) > Math.abs(this.fy) * 0.8 ? (this.fx > 0 ? 'right' : 'left') : (this.fy > 0 ? 'down' : 'up');
    }
  }

  startSlash(lvl, chained = false) {
    if (!chained) this.combo = this.comboWindow > 0 && this.combo >= 0 && this.combo < 2 ? this.combo + 1 : 0;
    if (this.combo < 0) this.combo = 0;
    this.aimAssist(lvl);
    this.state = 'attack'; this.atkT = 0; this.atkHitDone = false;
    this.atkDur = (this.combo === 2 ? 0.32 : 0.24) * (this.heightT > 0 ? 0.77 : 1);
    sfx(this.combo === 2 ? 'slash3' : 'slash');
  }
  startHeavy(lvl) {
    this.state = 'heavy'; this.atkT = 0; this.atkHitDone = false; this.atkDur = 0.36; this.chargeReady = false;
    sfx('heavy');
  }
  damageMult() {
    let m = 1;
    if (this.songT > 0) m *= BAL.songMult;
    if (this.parryBonus) m *= BAL.parryMult;
    return m;
  }
  resolveSlash(lvl) {
    const heavy = this.state === 'heavy';
    const ang = Math.atan2(this.fy, this.fx);
    const cx = this.x, cy = this.y - 7;
    const r = heavy ? 42 : this.combo === 2 ? 34 : 30;
    const half = heavy ? Math.PI : 1.15;
    const mult = (heavy ? BAL.heavyMult : BAL.comboMult[Math.max(0, this.combo)]) * this.damageMult();
    const dmg = atk() * mult;
    const knock = heavy ? 170 : this.combo === 2 ? 150 : 40;
    lvl.fx.push(new SlashFx(cx + this.fx * 4, cy - 8 + this.fy * 4, ang, r * 0.8, heavy ? Math.PI : 1.0, this.parryBonus ? '#ffffff' : heavy ? '#d8f4ff' : '#9fe8ff', heavy ? 0.3 : 0.16, heavy ? 5 : 4));
    if (heavy) lvl.fx.push(new Ring(cx, cy - 6, 8, r, 0.3, '#9fe8ff', 3));
    let hitAny = false;
    for (const e of lvl.allTargets()) {
      const d = Math.hypot(e.x - cx, (e.y - (e.hy || 6)) - cy);
      const a = Math.atan2(e.y - (e.hy || 6) - cy, e.x - cx);
      if (d < r + (e.radius || 6) && (d < 10 || angDiff(a, ang) < half)) {
        const kx = Math.cos(a) * knock, ky = Math.sin(a) * knock;
        if (e.takeHit({ dmg, pur: dmg, kx, ky, heavy: heavy || this.combo === 2, slash: true }, lvl)) hitAny = true;
      }
    }
    // slashes disperse boss fog (음파 참격으로 안개 걷어내기)
    for (const z of lvl.zones) if (z.kind === 'fog' && Math.hypot(z.x - cx, z.y - cy) < r + z.r * 0.6) { z.ttl -= heavy ? 4 : 1.5; lvl.fx.push(new Ring(z.x, z.y, 4, z.r, 0.3, 'rgba(159,232,255,0.6)')); }
    if (hitAny) {
      this.sin = Math.min(100, this.sin + BAL.sinPerHit * (heavy ? 2 : 1));
      if (this.parryBonus) { this.parryBonus = false; toast('받아넘기기 일격!', '#ffffff', 1.2); }
      sfx('hit');
      if (heavy || this.combo === 2) shake(2);
    }
  }
  startRoll(lvl, mx, my) {
    if (this.state === 'charge') this.chargeReady = false;
    this.state = 'roll'; this.rollT = BAL.rollTime; this.rollAge = 0;
    this.invuln = Math.max(this.invuln, BAL.rollInvuln);
    if (mx || my) { const l = Math.hypot(mx, my); this.rvx = mx / l; this.rvy = my / l; }
    else { this.rvx = this.fx; this.rvy = this.fy; }
    this.buffered = false; this.combo = 0;
    sfx('dodge');
  }
  swapTalisman() {
    const u = G.tal.unlocked;
    G.tal.idx = (G.tal.idx + 1) % u.length;
    sfx('blip');
  }
  castTalisman(lvl) {
    const kind = G.tal.unlocked[G.tal.idx % G.tal.unlocked.length];
    const cost = BAL.costs[kind];
    if (this.sori < cost) { sfx('denied'); toast('소리가 부족하다', '#9fb0d0', 1.2); return; }
    this.sori -= cost;
    const ang = Math.atan2(this.fy, this.fx);
    if (kind === 'fire') {
      lvl.zones.push(new Zone('fire', this.x + this.fx * 4, this.y - 6 + this.fy * 4, 58, 3, { ang, half: 0.6 }));
      sfx('fire');
    } else if (kind === 'bind') {
      // place on nearest enemy in front if any, else ahead
      let tx = this.x + this.fx * 40, ty = this.y + this.fy * 40;
      let best = null, bd = 110;
      for (const e of lvl.allTargets()) { const d = dist(e, this); if (d < bd) { bd = d; best = e; } }
      if (best) { tx = best.x; ty = best.y; }
      lvl.zones.push(new Zone('bind', tx, ty, 40, 8));
      sfx('bind');
    } else if (kind === 'guard') {
      this.shield = 10; sfx('shield');
    }
    lvl.fx.push(new Ring(this.x, this.y - 18, 4, 22, 0.35, '#d8c89a'));
  }
  song(lvl) {
    if (G.encounter.songUsed) { sfx('denied'); toast('처용가는 교전마다 한 번뿐이다', '#9fb0d0', 1.5); return; }
    G.encounter.songUsed = true;
    this.songT = 10;
    this.sori = Math.min(100, this.sori + BAL.soriSongBonus);
    sfx('song');
    toast('처용가 — 공격력 +30% (10초)', C.goldL, 2);
    for (let i = 0; i < 3; i++) lvl.fx.push(new Ring(this.x, this.y - 18, 6, 60 + i * 20, 0.8 + i * 0.2, C.goldL, 2));
  }
  ult(lvl) {
    if (this.sin < 100) { sfx('denied'); toast('신명이 차지 않았다', '#9fb0d0', 1.2); return; }
    this.sin = 0; this.ultT = BAL.ultTime; this.ultTick = 0; this.state = 'ult';
    sfx('ult'); shake(4);
    toast('처용무!', C.goldL, 2);
    for (const e of lvl.allTargets()) if (dist(e, this) < 140) e.takeHit({ dmg: 0, pur: BAL.ultPur, kx: 0, ky: 0, noStagger: true, quiet: true }, lvl);
    obangRipple(lvl, this.x, this.y - 8);
  }
  useItem(id, lvl) {
    if (!G.items[id]) { sfx('denied'); return; }
    if (id === 'insam') {
      if (G.stats.hp >= G.stats.maxHp) { toast('이미 기력이 충분하다', '#9fb0d0', 1.2); return; }
      G.stats.hp = Math.min(G.stats.maxHp, G.stats.hp + 60);
      lvl.fx.push(new TextPop(this.x, this.y - 46, '+60', '#7aff9a'));
    } else if (id === 'gugija') {
      this.sori = Math.min(100, this.sori + 50);
      lvl.fx.push(new TextPop(this.x, this.y - 46, '소리 +50', '#9fe8ff'));
    } else if (id === 'jeonghwa') {
      let n = 0;
      for (const e of lvl.allTargets()) if (dist(e, this) < 90) { e.takeHit({ dmg: 0, pur: 35, kx: 0, ky: 0, noStagger: true, quiet: true }, lvl); n++; }
      lvl.fx.push(new Ring(this.x, this.y - 18, 6, 90, 0.6, C.goldL, 2));
      if (!n) toast('주변에 요괴가 없다', '#9fb0d0', 1.2);
    }
    G.items[id]--;
    sfx('bell');
  }

  // returns 'dodged' | 'blocked' | 'hit' | false
  takeHit(h, lvl) {
    if (this.dead) return false;
    if (G.god && !h.dot) return 'blocked';
    if (this.ultT > 0) return 'blocked';
    if (this.invuln > 0) {
      if (this.state === 'roll' && this.rollAge <= BAL.parryWindow && !h.dot) this.parry(lvl);
      return 'dodged';
    }
    if (h.dot) {
      if (G.god) return false;
      G.stats.hp -= h.dmg;
      if (G.stats.hp <= 0) this.die(lvl);
      return 'hit';
    }
    if (this.shield > 0) {
      this.shield = 0; this.invuln = 0.5; sfx('shieldBreak');
      lvl.fx.push(new Ring(this.x, this.y - 18, 8, 26, 0.4, C.goldL, 3));
      return 'blocked';
    }
    G.stats.hp -= h.dmg;
    this.invuln = 0.7; this.hurtT = 0.5;
    if (this.state !== 'roll') { this.state = 'hurt'; this.combo = 0; this.buffered = false; }
    const a = Math.atan2(this.y - (h.srcY ?? this.y), this.x - (h.srcX ?? this.x));
    const k = h.knock ?? 120;
    this.kx = Math.cos(a) * k; this.ky = Math.sin(a) * k;
    sfx('phit'); shake(3);
    lvl.fx.push(new TextPop(this.x, this.y - 46, '-' + Math.round(h.dmg), '#ff6a5a'));
    if (G.stats.hp <= 0) this.die(lvl);
    return 'hit';
  }
  parry(lvl) {
    if (this.parryCooldown && G.time - this.parryCooldown < 0.3) return;
    this.parryCooldown = G.time;
    G.slowT = 1.0;
    this.parryBonus = true;
    this.sin = Math.min(100, this.sin + BAL.sinPerParry);
    this.parryChain++; this.parryChainT = 10;
    sfx('parry');
    lvl.fx.push(new Ring(this.x, this.y - 18, 6, 34, 0.5, '#ffffff', 2));
    lvl.fx.push(new TextPop(this.x, this.y - 48, '받아넘기기', '#ffffff', 1.0));
    if (this.parryChain >= 3) {
      this.parryChain = 0; this.heightT = 5;
      toast('신명 고조 — 이속·베기 속도 상승 (5초)', C.goldL, 2);
    }
  }
  // 피리 (bamboo pipe, the hero's weapon) while attacking or charging
  drawPipe(g, x, y) {
    if (!(this.state === 'attack' || this.state === 'heavy' || this.state === 'charge')) return;
    const len = 15;
    const hx = x + this.fx * 6, hy = y - 17 + this.fy * 3;
    const ex = hx + this.fx * len, ey = hy + this.fy * len - 3;
    g.lineCap = 'round';
    g.strokeStyle = '#0a080c'; g.lineWidth = 3.2; g.beginPath(); g.moveTo(hx, hy); g.lineTo(ex, ey); g.stroke();
    g.strokeStyle = '#8a6a34'; g.lineWidth = 1.6; g.beginPath(); g.moveTo(hx, hy); g.lineTo(ex, ey); g.stroke();
    g.strokeStyle = '#d8b66a'; g.lineWidth = 0.8; g.beginPath(); g.moveTo(hx, hy - 0.5); g.lineTo(ex, ey - 0.5); g.stroke();
    g.fillStyle = '#3a2410';
    for (const k of [0.33, 0.66]) g.fillRect(Math.round(hx + (ex - hx) * k), Math.round(hy + (ey - hy) * k) - 1, 1, 2);
    g.lineCap = 'butt';
  }
  die(lvl) {
    G.stats.hp = 0; this.dead = true; this.state = 'dead';
    sfx('kill');
    lvl.onPlayerDeath();
  }

  draw(g) {
    const blink = this.invuln > 0 && this.hurtT > 0 && Math.floor(G.time * 20) % 2 === 0;
    const x = Math.round(this.x), y = Math.round(this.y);
    // shadow
    shadow(g, x, y, this.state === 'roll' ? 12 : 16);
    // sprites are anchored at the feet: (13, 40) inside the 26x42 canvas
    const AX = 13, AY = 40;
    if (this.state === 'dead') {
      g.save(); g.translate(x, y - 5); g.rotate(Math.PI / 2); g.drawImage(SPR.player.down[0], -AX, -20); g.restore();
      return;
    }
    let frame = 0;
    if (this.walkT > 0) frame = 1 + (Math.floor(this.walkT * 8) % 2);
    const spr = SPR.player[this.dir][frame];
    g.save();
    if (blink) g.globalAlpha = 0.4;
    if (this.state === 'roll') {
      // 춤 구르기: spin-step afterimage
      const k = 1 - this.rollT / BAL.rollTime;
      g.globalAlpha = 0.3;
      g.drawImage(spr, x - AX - this.rvx * 8, y - AY - this.rvy * 8);
      g.globalAlpha = 1;
      const oy = -Math.sin(k * Math.PI) * 4;
      g.translate(x, y - 20 + oy); g.rotate(Math.sin(k * Math.PI * 2) * 0.35); g.drawImage(spr, -AX, -20);
      g.restore();
      return;
    }
    if (this.state === 'ult') {
      g.translate(x, y - 20); g.scale(Math.cos(G.time * 14) >= 0 ? 1 : -1, 1); g.drawImage(SPR.player.down[0], -AX, -20);
      g.restore();
      return;
    }
    const behind = this.fy < -0.3; // pipe held on the far side when facing away
    if (behind) this.drawPipe(g, x, y);
    rim(g, spr, x - AX, y - AY, this.x, this.y);
    g.drawImage(spr, x - AX, y - AY);
    if (!behind) this.drawPipe(g, x, y);
    g.restore();
    if (this.shield > 0) {
      g.save(); g.globalAlpha = 0.35 + Math.sin(G.time * 6) * 0.1; g.strokeStyle = C.goldL; g.lineWidth = 1;
      g.beginPath(); g.ellipse(x, y - 19, 15, 23, 0, 0, TAU); g.stroke(); g.restore();
    }
    if (this.heightT > 0) { g.save(); g.globalAlpha = 0.25; g.fillStyle = C.goldL; g.fillRect(x - 7, y - 19, 14, 1); g.restore(); }
  }
}

// ============================================================ enemies
export class Enemy {
  constructor(def) {
    this.x = def.x; this.y = def.y; this.homeX = def.x; this.homeY = def.y;
    this.quest = def.quest;
    this.vx = 0; this.vy = 0; this.kx = 0; this.ky = 0;
    this.state = 'idle'; this.t = 0; this.cd = rand(0.5, 1.5);
    this.aggro = false; this.flash = 0; this.stun = 0; this.slowT = 0;
    this.pur = 0; this.dead = false; this.anim = Math.random() * 10;
    this.wanderT = 0; this.wx = 0; this.wy = 0;
    this.showBars = 0;
    this.pow = def.pow || 1;
  }
  get speedMul() { return this.slowT > 0 ? 0.4 : 1; }
  takeHit(h, lvl) {
    if (this.dead) return false;
    this.hp -= h.dmg;
    const weak = h.talisman && h.talisman === this.weak;
    this.pur += h.slash ? h.pur * this.purRate : h.pur * (weak ? 2 : 1);
    if (h.dmg > 0) {
      this.flash = 0.1;
      if (!h.quiet) lvl.fx.push(new TextPop(this.x, this.y - 22, String(Math.round(h.dmg)), weak ? '#ffd060' : '#ffffff', 0.6));
    }
    if (weak && !this.weakShown) { this.weakShown = true; lvl.fx.push(new TextPop(this.x, this.y - 30, '약점!', '#ffd060', 1)); }
    this.showBars = 4;
    this.aggro = true;
    if (!h.noStagger) {
      this.kx += h.kx; this.ky += h.ky;
      if (h.heavy) { this.stun = 0.6; this.state = 'stagger'; this.t = 0; }
      else if (this.state !== 'lunge') this.stun = Math.max(this.stun, 0.15);
    }
    for (let i = 0; i < 4; i++) lvl.fx.push(new Particle(this.x, this.y - 8, rand(-50, 50), rand(-60, 10), 0.35, h.talisman === 'fire' ? '#ff9a4a' : '#9fe8ff', 2));
    if (this.pur >= this.purMax) this.purify(lvl);
    else if (this.hp <= 0) this.kill(lvl);
    return true;
  }
  reward(lvl, mult) {
    const exp = this.exp * mult;
    const money = Math.round(rand(3, 7) * mult);
    G.stats.money += money;
    if (addExp(exp)) { sfx('levelup'); toast(`신통력 상승! Lv.${G.stats.lv} (HP·공격력 증가)`, C.goldL, 3); }
    lvl.fx.push(new TextPop(this.x, this.y - 30, `덕망 +${Math.round(exp)}  엽전 +${money}`, '#d8c89a', 1.1));
    if (this.quest === 'imp' && G.flags.q_imp === 1) {
      G.flags.q_imp_count = (G.flags.q_imp_count || 0) + 1;
      if (G.flags.q_imp_count >= 4) { G.flags.q_imp = 2; toast('의뢰 달성: 산길의 역귀 졸개 — 게시판에 보고하자', C.goldL, 3.5); }
      else toast(`역귀 졸개 ${G.flags.q_imp_count}/4`, '#d8c89a', 1.5);
    }
  }
  purify(lvl) {
    this.dead = true; this.purified = true;
    sfx('purify');
    obangRipple(lvl, this.x, this.y - 8);
    lvl.fx.push(new TextPop(this.x, this.y - 40, '淨 — 한풀이', '#ff6a5a', 1.4, true));
    lvl.ghosts.push({ x: this.x, y: this.y, spr: this.pureSprite, t: 1.6 });
    this.reward(lvl, 1.5);
  }
  kill(lvl) {
    this.dead = true;
    sfx('kill');
    for (let i = 0; i < 14; i++) lvl.fx.push(new Particle(this.x, this.y - 6, rand(-60, 60), rand(-70, 10), rand(0.4, 0.8), Math.random() < 0.5 ? C.plague : '#2a2a2a', 2, 80));
    this.reward(lvl, 1);
  }
  baseUpdate(dt, lvl) {
    this.anim += dt;
    this.flash = Math.max(0, this.flash - dt);
    this.slowT = Math.max(0, this.slowT - dt);
    this.showBars = Math.max(0, this.showBars - dt);
    if (this.kx || this.ky) {
      lvl.moveEntity(this, this.kx * dt, this.ky * dt);
      this.kx *= Math.pow(0.002, dt); this.ky *= Math.pow(0.002, dt);
      if (Math.abs(this.kx) + Math.abs(this.ky) < 3) { this.kx = 0; this.ky = 0; }
    }
    const p = lvl.player;
    const d = p && !p.dead ? dist(this, p) : 9999;
    if (!this.aggro && d < this.aggroR && lvl.lineOfSight(this, p)) { this.aggro = true; }
    if (this.aggro && (d > 320 || (p && p.dead))) { this.aggro = false; this.state = 'idle'; }
    if (this.stun > 0) { this.stun -= dt; if (this.stun <= 0 && this.state === 'stagger') this.state = 'idle'; return { d, p, stunned: true }; }
    return { d, p, stunned: false };
  }
  wander(dt, lvl) {
    this.wanderT -= dt;
    if (this.wanderT <= 0) {
      this.wanderT = rand(1, 2.5);
      if (Math.random() < 0.5) { this.wx = 0; this.wy = 0; }
      else { const a = Math.random() * TAU; this.wx = Math.cos(a); this.wy = Math.sin(a); }
      if (Math.hypot(this.x - this.homeX, this.y - this.homeY) > 40) {
        const a = Math.atan2(this.homeY - this.y, this.homeX - this.x); this.wx = Math.cos(a); this.wy = Math.sin(a);
      }
    }
    lvl.moveEntity(this, this.wx * 20 * dt, this.wy * 20 * dt);
  }
  drawBars(g) {
    if (this.showBars <= 0 && !this.aggro) return;
    const x = Math.round(this.x) - 10, y = Math.round(this.y) - this.barY;
    g.fillStyle = C.ink; g.fillRect(x - 1, y - 1, 22, 6);
    g.fillStyle = '#3a1010'; g.fillRect(x, y, 20, 2);
    g.fillStyle = '#d84a3a'; g.fillRect(x, y, Math.ceil(20 * clamp(this.hp / this.maxHp, 0, 1)), 2);
    g.fillStyle = '#10203a'; g.fillRect(x, y + 3, 20, 1);
    g.fillStyle = '#e8d070'; g.fillRect(x, y + 3, Math.ceil(20 * clamp(this.pur / this.purMax, 0, 1)), 1);
  }
  drawShadow(g, w = 12) { shadow(g, this.x, this.y, w + 2); }
}

export class Dog extends Enemy {
  constructor(def) {
    super(def);
    this.kind = 'dog'; this.name = '역병 들린 들개';
    this.hp = this.maxHp = Math.round(52 * this.pow); this.purMax = Math.round(60 * this.pow); this.purRate = 0.75; this.weak = 'fire';
    this.exp = Math.round(26 * this.pow); this.radius = 7; this.w = 12; this.h = 6; this.aggroR = 100; this.barY = 26; this.hy = 5;
    this.face = 1;
    this.pureSprite = SPR.dogPure;
  }
  update(dt, lvl) {
    const { d, p, stunned } = this.baseUpdate(dt, lvl);
    if (stunned) return;
    this.t += dt; this.cd -= dt;
    if (!this.aggro) { this.state = 'idle'; this.wander(dt, lvl); if (this.wx) this.face = Math.sign(this.wx); return; }
    const a = Math.atan2(p.y - this.y, p.x - this.x);
    switch (this.state) {
      case 'idle': case 'chase':
        this.state = 'chase';
        this.face = Math.sign(p.x - this.x) || this.face;
        if (d > 34) lvl.moveEntity(this, Math.cos(a) * 58 * this.speedMul * dt, Math.sin(a) * 58 * this.speedMul * dt);
        else lvl.moveEntity(this, -Math.sin(a) * 30 * dt, Math.cos(a) * 30 * dt);
        if (d < 56 && this.cd <= 0) { this.state = 'tele'; this.t = 0; }
        break;
      case 'tele': // crouch, red flash
        if (this.t >= 0.55) {
          this.state = 'lunge'; this.t = 0; this.hitDone = false;
          this.lx = Math.cos(a); this.ly = Math.sin(a); this.face = Math.sign(this.lx) || this.face;
          sfx('enemyAtk');
        }
        break;
      case 'lunge':
        lvl.moveEntity(this, this.lx * 215 * this.speedMul * dt, this.ly * 215 * this.speedMul * dt);
        if (!this.hitDone && d < 13) {
          const r = p.takeHit({ dmg: Math.round(10 * this.pow), srcX: this.x, srcY: this.y }, lvl);
          if (r) this.hitDone = true;
        }
        if (this.t >= 0.28) { this.state = 'recover'; this.t = 0; }
        break;
      case 'recover':
        if (this.t >= 0.55) { this.state = 'chase'; this.cd = rand(0.9, 1.6); }
        break;
    }
  }
  draw(g) {
    this.drawShadow(g, 22);
    const moving = this.state === 'chase' || (this.state === 'idle' && this.wx);
    const f = moving ? Math.floor(this.anim * 8) % 2 : 0;
    const set = this.flash > 0 ? 'dogWhite' : this.state === 'tele' ? 'dogRed' : 'dog';
    let img = SPR[set][f];
    if (this.face < 0) img = this.flash > 0 || this.state === 'tele' ? flipCache(img) : SPR.dogL[f];
    const crouch = this.state === 'tele' ? 2 : 0;
    rim(g, img, Math.round(this.x) - 17, Math.round(this.y) - 20 + crouch, this.x, this.y);
    g.drawImage(img, Math.round(this.x) - 17, Math.round(this.y) - 20 + crouch);
    if (this.slowT > 0) drawBindMark(g, this);
    this.drawBars(g);
  }
}

const flipStore = new WeakMap();
function flipCache(img) {
  if (!flipStore.has(img)) {
    const c = document.createElement('canvas'); c.width = img.width; c.height = img.height;
    const x = c.getContext('2d'); x.translate(img.width, 0); x.scale(-1, 1); x.drawImage(img, 0, 0);
    flipStore.set(img, c);
  }
  return flipStore.get(img);
}
function drawBindMark(g, e) {
  g.save(); g.globalAlpha = 0.7; g.strokeStyle = '#6aa8ff'; g.lineWidth = 1;
  g.beginPath(); g.ellipse(Math.round(e.x), Math.round(e.y) - 1, 9, 3, 0, 0, TAU); g.stroke(); g.restore();
}

export class Imp extends Enemy {
  constructor(def) {
    super(def);
    this.kind = 'imp'; this.name = '역귀 졸개';
    this.hp = this.maxHp = Math.round(58 * this.pow); this.purMax = Math.round(60 * this.pow); this.purRate = 0.75; this.weak = 'bind';
    this.exp = Math.round(30 * this.pow); this.radius = 7; this.w = 10; this.h = 6; this.aggroR = 120; this.barY = 36; this.hy = 8;
    this.pureSprite = SPR.impPure;
    this.strafe = Math.random() < 0.5 ? 1 : -1;
  }
  update(dt, lvl) {
    const { d, p, stunned } = this.baseUpdate(dt, lvl);
    if (stunned) return;
    this.t += dt; this.cd -= dt;
    if (!this.aggro) { this.state = 'idle'; this.wander(dt, lvl); return; }
    const a = Math.atan2(p.y - this.y, p.x - this.x);
    const sp = 42 * this.speedMul;
    switch (this.state) {
      case 'idle': case 'move':
        this.state = 'move';
        if (d < 26 && this.cd <= 0.6) { this.state = 'claw'; this.t = 0; break; }
        if (d < 64) lvl.moveEntity(this, -Math.cos(a) * sp * dt, -Math.sin(a) * sp * dt);
        else if (d > 110) lvl.moveEntity(this, Math.cos(a) * sp * dt, Math.sin(a) * sp * dt);
        else lvl.moveEntity(this, -Math.sin(a) * sp * 0.6 * this.strafe * dt, Math.cos(a) * sp * 0.6 * this.strafe * dt);
        if (Math.random() < dt * 0.4) this.strafe *= -1;
        if (this.cd <= 0 && d < 150 && lvl.lineOfSight(this, p)) { this.state = 'tele'; this.t = 0; }
        break;
      case 'tele':
        if (this.t >= 0.65) {
          const aa = Math.atan2(p.y - 6 - (this.y - 10), p.x - this.x);
          lvl.projectiles.push(new Projectile(this.x, this.y - 10, Math.cos(aa) * 125, Math.sin(aa) * 125, Math.round(8 * this.pow)));
          sfx('spit');
          this.state = 'move'; this.cd = rand(1.6, 2.4);
        }
        break;
      case 'claw':
        if (this.t >= 0.42 && !this.hitDone) {
          this.hitDone = true;
          lvl.fx.push(new SlashFx(this.x, this.y - 8, a, 16, 0.9, '#b6ff6a', 0.15, 2));
          if (d < 26) p.takeHit({ dmg: Math.round(7 * this.pow), srcX: this.x, srcY: this.y }, lvl);
        }
        if (this.t >= 0.75) { this.state = 'move'; this.hitDone = false; this.cd = Math.max(this.cd, 1.2); }
        break;
    }
  }
  draw(g) {
    this.drawShadow(g, 14);
    const f = this.state === 'move' ? Math.floor(this.anim * 6) % 2 : 0;
    const tele = this.state === 'tele' || (this.state === 'claw' && this.t < 0.42);
    const set = this.flash > 0 ? 'impWhite' : tele ? 'impRed' : 'imp';
    const bob = Math.round(Math.sin(this.anim * 5) * 1);
    rim(g, SPR[set][f], Math.round(this.x) - 12, Math.round(this.y) - 30 + bob - (tele ? 1 : 0), this.x, this.y);
    g.drawImage(SPR[set][f], Math.round(this.x) - 12, Math.round(this.y) - 30 + bob - (tele ? 1 : 0));
    if (this.slowT > 0) drawBindMark(g, this);
    this.drawBars(g);
  }
}

// ============================================================ boss: 역신
export class Clone {
  constructor(boss, x, y, real) {
    Object.assign(this, { boss, x, y, real, w: 12, h: 6, radius: 10, hy: 18, t: 0, state: 'move', dead: false, cd: rand(0.4, 1.2), flash: 0, slowT: 0, isClone: true });
  }
  takeHit(h, lvl) {
    if (this.dead) return false;
    // clones dissolve on any hit
    this.dead = true;
    sfx('hit');
    for (let i = 0; i < 16; i++) lvl.fx.push(new Particle(this.x, this.y - 18, rand(-60, 60), rand(-60, 20), rand(0.4, 0.8), C.plague, 3));
    lvl.fx.push(new TextPop(this.x, this.y - 40, '분신', '#b6ff6a', 0.8));
    return true;
  }
  update(dt, lvl) {
    if (this.dead) return;
    this.t += dt; this.cd -= dt; this.flash = Math.max(0, this.flash - dt); this.slowT = Math.max(0, this.slowT - dt);
    const p = lvl.player;
    const d = dist(this, p);
    const a = Math.atan2(p.y - this.y, p.x - this.x);
    if (this.state === 'move') {
      const sp = (this.boss.phase === 2 ? 42 : 34) * (this.slowT > 0 ? 0.4 : 1);
      if (d > 22) lvl.moveEntity(this, Math.cos(a) * sp * dt, Math.sin(a) * sp * dt);
      if (d < 34 && this.cd <= 0) { this.state = 'tele'; this.st = 0; }
    } else if (this.state === 'tele') {
      this.st += dt;
      if (this.st >= 0.8) {
        lvl.fx.push(new SlashFx(this.x, this.y - 14, a, 22, 1.2, '#b6ff6a', 0.2, 3));
        if (d < 30) p.takeHit({ dmg: 10, srcX: this.x, srcY: this.y }, lvl);
        sfx('enemyAtk');
        this.state = 'move'; this.cd = rand(1.0, 1.8);
      }
    }
  }
  draw(g) {
    shadow(g, this.x, this.y, 28);
    drawBoss(g, this.x, this.y, G.time + (this.real ? 0 : this.x * 0.01), { tele: this.state === 'tele', flash: this.flash > 0 });
    if (this.slowT > 0) drawBindMark(g, this);
  }
}

export class Boss {
  constructor(x, y) {
    this.x = x; this.y = y; this.w = 14; this.h = 6; this.radius = 12; this.hy = 18;
    this.kind = 'boss'; this.isBoss = true; this.name = '역신(疫神)';
    this.hp = this.maxHp = 1200; this.pur = 0; this.purMax = 200; this.purRate = 0.12; this.talPur = 0.5; this.weak = 'bind';
    this.phase = 1; this.state = 'human'; this.t = 0; this.stateT = 0;
    this.patIdx = 0; this.flash = 0; this.slowT = 0; this.alpha = 1; this.dead = false;
    this.clones = []; this.kx = 0; this.ky = 0; this.contactCd = 0;
    this.hidden = false; this.closeT = 0; this.lastPat = null;
  }
  get active() { return !['human', 'intro', 'phase', 'defeated', 'vanish', 'shift'].includes(this.state); }
  takeHit(h, lvl) {
    if (this.dead || !this.active || this.hidden) return false;
    const weak = h.talisman && h.talisman === this.weak;
    // 탁기 갑옷: the miasma shroud halves damage unless 결박부 pins the body down
    const bound = this.slowT > 0;
    if (!bound && h.dmg > 0) {
      h = { ...h, dmg: h.dmg * 0.5, pur: h.slash ? h.pur * 0.5 : h.pur };
      if (!this.armorHint && h.slash) { this.armorHint = true; lvl.fx.push(new TextPop(this.x, this.y - 58, '탁기 갑옷 — 결박부로 묶어라', '#b6ff6a', 2)); }
    }
    this.hp -= h.dmg;
    this.pur += h.slash ? h.pur * this.purRate : h.pur * (weak ? 2 : 1) * this.talPur;
    if (h.dmg > 0) { this.flash = 0.08; if (!h.quiet) lvl.fx.push(new TextPop(this.x, this.y - 44, String(Math.round(h.dmg)), weak ? '#ffd060' : '#ffffff', 0.6)); }
    if (weak && !this.weakShown) { this.weakShown = true; lvl.fx.push(new TextPop(this.x, this.y - 52, '약점! 결박부', '#ffd060', 1.4)); }
    for (let i = 0; i < 3; i++) lvl.fx.push(new Particle(this.x, this.y - 20, rand(-50, 50), rand(-50, 10), 0.35, C.plagueL, 2));
    if (this.state === 'clones') {
      // hitting the real body breaks the illusion
      this.endClones(lvl);
      lvl.fx.push(new TextPop(this.x, this.y - 56, '본체!', '#ffd060', 1));
      this.state = 'recover'; this.stateT = 0;
    }
    if (this.pur >= this.purMax) { this.pur = this.purMax; this.defeat(lvl, 'purified'); return true; }
    if (this.hp <= 0) { this.hp = 0; this.defeat(lvl, 'slain'); return true; }
    if (this.phase === 1 && this.hp <= this.maxHp * 0.5) this.toPhase2(lvl);
    return true;
  }
  toPhase2(lvl) {
    this.phase = 2; this.state = 'phase'; this.stateT = 0;
    this.pur = Math.max(0, this.pur - this.purMax * 0.25);
    this.endClones(lvl);
    sfx('boss'); shake(6);
    toast('역신이 탁기를 끌어모은다 — 정화 게이지 회복', '#b6ff6a', 3);
    for (let i = 0; i < 30; i++) { const a = Math.random() * TAU; lvl.fx.push(new Particle(this.x + Math.cos(a) * 80, this.y + Math.sin(a) * 60, -Math.cos(a) * 80, -Math.sin(a) * 60, 1, C.plagueL, 3)); }
  }
  defeat(lvl, how) {
    this.dead = true; this.state = 'defeated';
    this.endClones(lvl);
    lvl.zones = lvl.zones.filter((z) => z.kind !== 'fog' && z.kind !== 'tele');
    G.flags.boss_result = how;
    lvl.onBossDefeated(how);
  }
  endClones(lvl) {
    for (const c of this.clones) if (!c.dead) { c.dead = true; for (let i = 0; i < 8; i++) lvl.fx.push(new Particle(c.x, c.y - 18, rand(-40, 40), rand(-40, 10), 0.5, C.plague, 3)); }
    this.clones = [];
    this.hidden = false; this.alpha = 1;
  }
  update(dt, lvl) {
    this.t += dt; this.stateT += dt;
    this.flash = Math.max(0, this.flash - dt);
    this.slowT = Math.max(0, this.slowT - dt);
    this.contactCd = Math.max(0, this.contactCd - dt);
    if (this.state === 'human' || this.state === 'intro' || this.state === 'defeated') return;
    const p = lvl.player;
    if (!p || p.dead) return;
    const d = dist(this, p);
    const a = Math.atan2(p.y - this.y, p.x - this.x);
    const fast = this.phase === 2 ? 1.3 : 1;
    const slow = this.slowT > 0 ? 0.4 : 1;
    if (this.kx || this.ky) { lvl.moveEntity(this, this.kx * dt, this.ky * dt); this.kx *= Math.pow(0.01, dt); this.ky *= Math.pow(0.01, dt); }
    // contact damage
    if (this.active && !this.hidden && d < 16 && this.contactCd <= 0) { if (p.takeHit({ dmg: 8, srcX: this.x, srcY: this.y }, lvl)) this.contactCd = 1; }
    switch (this.state) {
      case 'phase':
        if (this.stateT > 1.6) { this.state = 'idle'; this.stateT = 0; }
        break;
      case 'idle': {
        // drift to keep a medium distance
        const want = 70;
        const sp = 30 * fast * slow;
        if (d > want + 10) lvl.moveEntity(this, Math.cos(a) * sp * dt, Math.sin(a) * sp * dt);
        else if (d < want - 20) lvl.moveEntity(this, -Math.cos(a) * sp * dt, -Math.sin(a) * sp * dt);
        else lvl.moveEntity(this, -Math.sin(a) * sp * dt, Math.cos(a) * sp * dt);
        this.closeT = d < 30 ? this.closeT + dt : Math.max(0, this.closeT - dt);
        if (this.closeT > 1.6) { this.closeT = 0; this.state = 'pulseTele'; this.stateT = 0; sfx('enemyAtk'); break; }
        if (this.stateT > (this.phase === 2 ? 1.0 : 1.3)) this.nextPattern(lvl);
        break;
      }
      case 'pulseTele':
        if (this.stateT >= 0.8) {
          lvl.fx.push(new Ring(this.x, this.y - 10, 6, 48, 0.4, C.plagueL, 3));
          shake(3); sfx('cough');
          if (d < 46) p.takeHit({ dmg: 10, srcX: this.x, srcY: this.y, knock: 260 }, lvl);
          this.state = 'shift'; this.stateT = 0;
        }
        break;
      case 'shift': {
        // dissolve into the fog and reappear away from the player
        if (!this.shiftTo) {
          const arena = lvl.def.arena;
          let best = null;
          for (let i = 0; i < 12; i++) {
            const c = { x: rand(arena.x0 + 20, arena.x1 - 20), y: rand(arena.y0 + 20, arena.y1 - 20) };
            const dd = Math.hypot(c.x - p.x, c.y - p.y);
            if (dd > 90 && dd < 170) { best = c; break; }
            if (!best || dd > Math.hypot(best.x - p.x, best.y - p.y)) best = c;
          }
          this.shiftTo = best;
        }
        if (this.stateT < 0.4) this.alpha = 1 - this.stateT / 0.4;
        else if (!this.shifted) { this.shifted = true; this.x = this.shiftTo.x; this.y = this.shiftTo.y; lvl.fx.push(new Ring(this.x, this.y - 18, 4, 26, 0.4, C.plague, 2)); }
        else this.alpha = Math.min(1, (this.stateT - 0.4) / 0.4);
        if (this.stateT >= 0.8) { this.alpha = 1; this.shiftTo = null; this.shifted = false; this.state = 'idle'; this.stateT = 0; }
        break;
      }
      case 'fogTele':
        if (this.stateT >= 1.2) {
          for (const z of this.pendingFog) lvl.zones.push(new Zone('fog', z.x, z.y, z.r, 10));
          this.pendingFog = null;
          sfx('trap');
          this.state = 'recover'; this.stateT = 0;
        }
        break;
      case 'coughTele':
        // telegraph cone follows the player slowly during the first half
        if (this.stateT < 0.5) this.coughAng = lerpAngle(this.coughAng, a, dt * 3);
        if (this.stateT >= 1.05) { this.state = 'cough'; this.stateT = 0; this.coughHit = false; sfx('cough'); shake(3); }
        break;
      case 'cough': {
        const len = 130, half = 0.55;
        const rr = len * Math.min(1, this.stateT / 0.35);
        if (!this.coughHit && d < rr + 6 && d > rr - 30 && angDiff(a, this.coughAng) < half) {
          if (p.takeHit({ dmg: 16, srcX: this.x, srcY: this.y, knock: 200 }, lvl)) this.coughHit = true;
        }
        if (Math.random() < 0.9) { const aa = this.coughAng + rand(-half, half); lvl.fx.push(new Particle(this.x + Math.cos(aa) * rr, this.y - 14 + Math.sin(aa) * rr, Math.cos(aa) * 40, Math.sin(aa) * 40, 0.5, 'rgba(155,224,90,0.8)', 3)); }
        if (this.stateT >= 0.45) {
          if (this.phase === 2 && !this.coughTwice) { this.coughTwice = true; this.state = 'coughTele'; this.stateT = 0.45; this.coughAng = a; }
          else { this.coughTwice = false; this.state = 'recover'; this.stateT = 0; }
        }
        break;
      }
      case 'vanish':
        this.alpha = Math.max(0, 1 - this.stateT / 0.5);
        if (this.stateT >= 0.5) this.spawnClones(lvl);
        break;
      case 'clones': {
        // the real body behaves like a clone and moves toward the player
        const sp = 34 * fast * slow;
        if (d > 22) lvl.moveEntity(this, Math.cos(a) * sp * dt, Math.sin(a) * sp * dt);
        this.cloneCd -= dt;
        if (this.cloneCd <= 0 && d < 34 && !this.swipeT) this.swipeT = 0.001;
        if (this.swipeT) {
          this.swipeT += dt;
          if (this.swipeT >= 0.8) {
            lvl.fx.push(new SlashFx(this.x, this.y - 14, a, 22, 1.2, '#b6ff6a', 0.2, 3));
            if (d < 30) p.takeHit({ dmg: 10, srcX: this.x, srcY: this.y }, lvl);
            this.swipeT = 0; this.cloneCd = rand(1.0, 1.6);
          }
        }
        // 용패 감지: golden glint on the real body
        if (Math.random() < dt * 2.2) lvl.fx.push(new Particle(this.x + rand(-6, 6), this.y - 34, 0, -10, 0.6, C.goldL, 1));
        for (const c of this.clones) c.update(dt, lvl);
        const alive = this.clones.filter((c) => !c.dead).length;
        if (this.stateT > 9 || alive === 0) { this.endClones(lvl); this.state = 'recover'; this.stateT = 0; }
        break;
      }
      case 'recover':
        if (this.stateT >= (this.phase === 2 ? 0.6 : 0.9)) {
          this.state = d < 50 && this.lastPat !== 'clones' ? 'shift' : 'idle'; this.stateT = 0;
        }
        break;
    }
    // keep the boss inside the arena
    const arena = lvl.def.arena;
    if (arena) { this.x = clamp(this.x, arena.x0, arena.x1); this.y = clamp(this.y, arena.y0, arena.y1); }
  }
  nextPattern(lvl) {
    const cycle = this.phase === 2 ? ['fog', 'cough', 'clones', 'cough', 'fog', 'clones'] : ['fog', 'cough', 'clones', 'cough'];
    const pat = cycle[this.patIdx % cycle.length];
    this.patIdx++; this.lastPat = pat;
    this.stateT = 0;
    const p = lvl.player;
    if (pat === 'fog') {
      this.state = 'fogTele';
      const n = this.phase === 2 ? 4 : 3;
      this.pendingFog = [{ x: p.x, y: p.y, r: 30 }];
      for (let i = 1; i < n; i++) {
        const a = Math.random() * TAU, dd = rand(50, 100);
        const arena = lvl.def.arena;
        this.pendingFog.push({ x: clamp(p.x + Math.cos(a) * dd, arena.x0, arena.x1), y: clamp(p.y + Math.sin(a) * dd, arena.y0, arena.y1), r: 30 });
      }
      for (const z of this.pendingFog) lvl.zones.push(new Zone('tele', z.x, z.y, z.r, 1.2));
      sfx('enemyAtk');
    } else if (pat === 'cough') {
      this.state = 'coughTele'; this.coughAng = Math.atan2(p.y - this.y, p.x - this.x);
    } else {
      this.state = 'vanish'; sfx('boss');
    }
  }
  spawnClones(lvl) {
    const p = lvl.player;
    const arena = lvl.def.arena;
    const base = Math.random() * TAU;
    const spots = [];
    for (let i = 0; i < 4; i++) {
      const a = base + i * TAU / 4;
      spots.push({ x: clamp(p.x + Math.cos(a) * 85, arena.x0, arena.x1), y: clamp(p.y + Math.sin(a) * 70, arena.y0, arena.y1) });
    }
    const realIdx = Math.floor(Math.random() * 4);
    this.clones = [];
    spots.forEach((s, i) => {
      if (i === realIdx) { this.x = s.x; this.y = s.y; }
      else this.clones.push(new Clone(this, s.x, s.y, false));
    });
    this.alpha = 1; this.state = 'clones'; this.stateT = 0; this.cloneCd = 0.8; this.swipeT = 0;
    for (const s of spots) lvl.fx.push(new Ring(s.x, s.y - 18, 4, 24, 0.5, C.plague, 2));
  }
  drawGround(g) {
    if (this.state === 'pulseTele') {
      const k = this.stateT / 0.8;
      g.save(); g.globalAlpha = 0.6; g.strokeStyle = '#ff4a3a'; g.lineWidth = 1;
      g.beginPath(); g.ellipse(this.x, this.y - 4, 46, 36, 0, 0, TAU); g.stroke();
      g.globalAlpha = 0.25; g.fillStyle = '#ff4a3a'; g.beginPath(); g.ellipse(this.x, this.y - 4, 46 * k, 36 * k, 0, 0, TAU); g.fill(); g.restore();
    }
    if (this.state === 'coughTele') {
      const k = this.stateT / 1.05;
      g.save(); g.globalAlpha = 0.18 + 0.25 * k; g.fillStyle = '#ff4a3a';
      g.beginPath(); g.moveTo(this.x, this.y - 6); g.arc(this.x, this.y - 6, 130, this.coughAng - 0.55, this.coughAng + 0.55); g.closePath(); g.fill();
      g.globalAlpha = 0.8; g.strokeStyle = '#ff6a5a'; g.lineWidth = 1; g.stroke(); g.restore();
    }
  }
  draw(g) {
    if (this.state === 'defeated' && this.vanishedForEnding) return;
    if (this.alpha <= 0) return;
    shadow(g, this.x, this.y, 30 * this.alpha);
    const tele = this.state === 'coughTele' || this.state === 'fogTele' || this.state === 'pulseTele' || (this.state === 'clones' && this.swipeT > 0);
    drawBoss(g, this.x, this.y, this.t, { human: this.state === 'human', tele, flash: this.flash > 0, alpha: this.alpha * (this.state === 'defeated' ? 0.8 : 1) });
    if (this.slowT > 0) drawBindMark(g, this);
  }
  drawClones(g) { for (const c of this.clones) if (!c.dead) c.draw(g); }
}
function lerpAngle(a, b, t) { let d = ((b - a + Math.PI * 3) % TAU) - Math.PI; return a + d * clamp(t, 0, 1); }

// ============================================================ NPC
export class NPC {
  constructor(def) {
    Object.assign(this, def);
    this.radius = 7; this.w = 10; this.h = 6; this.t = Math.random() * 5;
  }
  update(dt) { this.t += dt; }
  draw(g) {
    if (this.hidden) return;
    const spr = SPR[this.sprite];
    if (!spr) return;
    const x = Math.round(this.x), y = Math.round(this.y);
    if (this.ghost || this.spirit) {
      g.save(); g.globalAlpha = 0.55 + Math.sin(this.t * 3) * 0.2;
      g.drawImage(spr, x - (spr.width >> 1), y - spr.height + 1 + Math.round(Math.sin(this.t * 2) * 2));
      g.restore();
      return;
    }
    shadow(g, x, y, 16);
    const ny = y - spr.height + 2 + (Math.sin(this.t * 2) > 0.95 ? -1 : 0);
    const nx = x - (spr.width >> 1);
    rim(g, spr, nx, ny, this.x, this.y);
    g.drawImage(spr, nx, ny);
  }
}
