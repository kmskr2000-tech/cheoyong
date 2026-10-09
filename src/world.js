// Level: tiles, collision, entities, camera and rendering.
import { G, TS, VIEW_W, VIEW_H, SCALE, shake } from './state.js';
import { LEVELS } from './maps.js';
import { T, SOLID, getTile, PROPS, PROP_INFO, SPR, makeCanvas, C } from './gfx.js';
import { Player, Dog, Imp, Boss, NPC, Particle, Ring, TextPop, Zone, dist } from './entities.js';
import { sfx } from './audio.js';
import { paintGround, tileOverlay } from './ground.js';
import { renderLightmap, redrawTelegraphs, finish, shadow, frameDt, worldTarget } from './post.js';

const clamp = (v, a, b) => Math.max(a, Math.min(b, v));
const rand = (a, b) => a + Math.random() * (b - a);

export class Level {
  constructor(id) {
    this.id = id;
    const def = LEVELS[id]();
    this.def = def;
    this.w = def.w; this.h = def.h;
    this.tiles = def.tiles.slice();
    this.block = new Uint8Array(this.w * this.h);
    for (let i = 0; i < this.tiles.length; i++) if (SOLID.has(this.tiles[i])) this.block[i] = 1;
    // props
    this.props = def.props.map((p) => {
      const info = PROP_INFO[p.type];
      const [fw, fh] = info.foot;
      for (let y = p.ty - fh + 1; y <= p.ty; y++) for (let x = p.tx; x < p.tx + fw; x++) this.setBlock(x, y, 1);
      const img = p.type === 'chest' ? null : PROPS[p.type]();
      return { ...p, info, img, x: p.tx * TS + Math.max(fw, 1) * TS / 2, y: (p.ty + 1) * TS - (info.flat ? 8 : 0) };
    });
    this.npcs = def.npcs.map((n) => new NPC({ ...n }));
    this.items = def.items.map((it) => ({ ...it }));
    for (const it of this.items) if (it.kind === 'chest') this.setBlock(Math.floor(it.x / TS), Math.floor(it.y / TS), 1);
    this.enemies = [];
    this.spawnEnemies();
    this.zones = []; this.projectiles = []; this.fx = []; this.ghosts = [];
    this.vents = [];
    for (let y = 0; y < this.h; y++) for (let x = 0; x < this.w; x++) {
      if (this.tiles[y * this.w + x] === T.VENT) this.vents.push({ x: x * TS + 8, y: y * TS + 8, phase: ((x * 7 + y * 13) % 10) / 10 * 4.3, acc: 0 });
    }
    this.boss = null;
    this.cam = { x: 0, y: 0 };
    this.buildGround();
    if (def.bossDoor) {
      this.def.arena = { x0: 33 * TS, x1: 47 * TS - 4, y0: 4 * TS + 8, y1: 22 * TS + 8 };
    }
  }
  spawnEnemies() {
    this.enemies = this.def.enemies.map((e) => { const d = { ...e, pow: this.def.pow || 1 }; return e.type === 'dog' ? new Dog(d) : new Imp(d); });
  }
  setBlock(x, y, v) { if (x >= 0 && y >= 0 && x < this.w && y < this.h) this.block[y * this.w + x] = v; }
  tileAt(tx, ty) { return (tx < 0 || ty < 0 || tx >= this.w || ty >= this.h) ? T.VOID : this.tiles[ty * this.w + tx]; }
  blocked(tx, ty) { return (tx < 0 || ty < 0 || tx >= this.w || ty >= this.h) ? true : this.block[ty * this.w + tx] === 1; }
  solidAt(x, y) { return this.blocked(Math.floor(x / TS), Math.floor(y / TS)); }

  boxFree(x, y, w, h) {
    const x0 = Math.floor((x - w / 2) / TS), x1 = Math.floor((x + w / 2 - 0.01) / TS);
    const y0 = Math.floor((y - h) / TS), y1 = Math.floor((y - 0.01) / TS);
    for (let ty = y0; ty <= y1; ty++) for (let tx = x0; tx <= x1; tx++) if (this.blocked(tx, ty)) return false;
    return true;
  }
  moveEntity(e, dx, dy) {
    const w = e.w || 10, h = e.h || 6;
    // split large moves to avoid tunnelling
    const steps = Math.max(1, Math.ceil(Math.max(Math.abs(dx), Math.abs(dy)) / 6));
    const sx = dx / steps, sy = dy / steps;
    for (let i = 0; i < steps; i++) {
      if (sx && this.boxFree(e.x + sx, e.y, w, h) && !this.npcBlocks(e, e.x + sx, e.y)) e.x += sx;
      if (sy && this.boxFree(e.x, e.y + sy, w, h) && !this.npcBlocks(e, e.x, e.y + sy)) e.y += sy;
    }
  }
  npcBlocks(e, nx, ny) {
    if (e !== this.player) return false;
    for (const n of this.npcs) {
      if (n.hidden || n.ghost || n.spirit) continue;
      const d0 = Math.hypot(e.x - n.x, e.y - n.y), d1 = Math.hypot(nx - n.x, ny - n.y);
      if (d1 < 10 && d1 < d0) return true;
    }
    return false;
  }
  lineOfSight(a, b) {
    const d = Math.hypot(b.x - a.x, b.y - a.y);
    const n = Math.ceil(d / 8);
    for (let i = 1; i < n; i++) {
      const x = a.x + (b.x - a.x) * i / n, y = a.y - 4 + (b.y - a.y) * i / n;
      const t = this.tileAt(Math.floor(x / TS), Math.floor(y / TS));
      if (t === T.WALL || t === T.VOID) return false;
    }
    return true;
  }
  allTargets() {
    const out = this.enemies.filter((e) => !e.dead);
    if (this.boss && !this.boss.dead && this.boss.active && !this.boss.hidden) out.push(this.boss);
    if (this.boss) for (const c of this.boss.clones) if (!c.dead) out.push(c);
    return out;
  }

  placePlayer(spawnName, player) {
    const s = this.def.spawns[spawnName] || Object.values(this.def.spawns)[0];
    this.player = player || new Player(s.x, s.y);
    this.player.x = s.x; this.player.y = s.y;
    this.player.dead = false; this.player.state = 'idle'; this.player.kx = 0; this.player.ky = 0;
    this.exitArmed = false;
    this.updateCamera(true);
  }

  // ---------------------------------------------------------------- interaction
  interactables() {
    const out = [];
    for (const n of this.npcs) if (!n.hidden) out.push({ kind: 'npc', obj: n, x: n.x, y: n.y, label: n.name });
    for (const p of this.props) if (p.id === 'board' || p.id === 'shop') out.push({ kind: p.id, obj: p, x: p.x, y: p.y + 4, label: p.id === 'board' ? '의뢰 게시판' : '약방 노점' });
    for (const it of this.items) if (this.itemVisible(it)) out.push({ kind: 'item', obj: it, x: it.x, y: it.y, label: it.kind === 'chest' ? '나무 궤' : '반짝이는 것' });
    for (const ex of this.def.exits) if (ex.interact) out.push({ kind: 'exit', obj: ex, x: ex.x + ex.w / 2, y: ex.y + ex.h / 2 + 4, label: ex.label });
    return out;
  }
  nearestInteractable(p) {
    let best = null, bd = 24;
    for (const i of this.interactables()) {
      const d = Math.hypot(i.x - p.x, i.y - p.y);
      if (d < bd) { bd = d; best = i; }
    }
    return best;
  }
  tryInteract(p) {
    if (this.enemies.some((e) => !e.dead && e.aggro && dist(e, p) < 120)) return false;
    const it = this.nearestInteractable(p);
    if (!it) return false;
    G.hooks.interact(it, this);
    return true;
  }
  itemVisible(it) {
    if (it.kind === 'chest') return true;
    if (it.needFlag && !G.flags[it.needFlag]) return false;
    if (it.notFlag && G.flags[it.notFlag]) return false;
    return !it.taken;
  }

  // ---------------------------------------------------------------- update
  update(dt) {
    const p = this.player;
    if (p) p.update(dt, this);
    for (const n of this.npcs) n.update(dt);
    for (const e of this.enemies) if (!e.dead) e.update(dt, this);
    // light separation so enemies do not stack
    for (let i = 0; i < this.enemies.length; i++) {
      const a = this.enemies[i]; if (a.dead) continue;
      for (let j = i + 1; j < this.enemies.length; j++) {
        const b = this.enemies[j]; if (b.dead) continue;
        const d = Math.hypot(a.x - b.x, a.y - b.y);
        if (d < 12 && d > 0.01) { const push = (12 - d) * 0.5; const ux = (a.x - b.x) / d, uy = (a.y - b.y) / d; this.moveEntity(a, ux * push, uy * push); this.moveEntity(b, -ux * push, -uy * push); }
      }
    }
    this.enemies = this.enemies.filter((e) => !e.dead || e.keep);
    if (this.boss) this.boss.update(dt, this);
    this.zones = this.zones.filter((z) => z.update(dt, this));
    this.projectiles = this.projectiles.filter((pr) => pr.update(dt, this));
    this.fx = this.fx.filter((f) => f.update(dt));
    if (this.fx.length > 900) this.fx.splice(0, this.fx.length - 900);
    this.ghosts = this.ghosts.filter((g) => (g.t -= dt) > 0);
    this.updateVents(dt);
    this.updateEncounter(dt);
    this.updateTriggers(dt);
    this.updateCamera(false);
    // ambient miasma motes
    if (this.def.miasma && Math.random() < this.def.miasma) {
      this.fx.push(new Particle(this.cam.x + rand(0, VIEW_W), this.cam.y + rand(0, VIEW_H), rand(-4, 4), -rand(2, 8), rand(1.5, 3), 'rgba(111,191,74,0.35)', 2));
    }
  }
  updateVents(dt) {
    const p = this.player;
    for (const v of this.vents) {
      const t = (G.time + v.phase) % 4.3;
      v.state = t < 2.2 ? 'idle' : t < 3.1 ? 'bubble' : 'erupt';
      if (v.state === 'bubble' && Math.random() < 0.3) this.fx.push(new Particle(v.x + rand(-4, 4), v.y + rand(-3, 3), 0, -10, 0.4, C.plagueL, 1));
      if (v.state === 'erupt') {
        if (Math.random() < 0.9) this.fx.push(new Particle(v.x + rand(-6, 6), v.y, rand(-6, 6), -rand(30, 60), rand(0.4, 0.8), Math.random() < 0.5 ? 'rgba(111,191,74,0.8)' : 'rgba(182,255,106,0.6)', 3));
        if (p && !p.dead && Math.abs(p.x - v.x) < 11 && Math.abs(p.y - 3 - v.y) < 11) {
          v.acc -= dt;
          if (v.acc <= 0) { v.acc = 0.5; if (p.takeHit({ dmg: 6, srcX: v.x, srcY: v.y - 8, knock: 60 }, this) === 'hit') sfx('trap'); }
        }
      } else v.acc = 0;
    }
  }
  updateEncounter(dt) {
    const any = this.enemies.some((e) => !e.dead && e.aggro) || (this.boss && !this.boss.dead && this.boss.active);
    const enc = G.encounter;
    if (any) { if (!enc.active) { enc.active = true; enc.songUsed = false; } enc.calm = 0; }
    else if (enc.active) { enc.calm += dt; if (enc.calm > 5) { enc.active = false; enc.songUsed = false; } }
  }
  updateTriggers() {
    const p = this.player;
    if (!p || p.dead) return;
    // exits
    let inExit = null;
    for (const ex of this.def.exits) {
      if (ex.interact) continue;
      if (p.x > ex.x - 4 && p.x < ex.x + ex.w + 4 && p.y > ex.y && p.y < ex.y + ex.h + 6) inExit = ex;
    }
    if (!inExit) this.exitArmed = true;
    else if (this.exitArmed && !G.scriptLock && !G.dialog) { this.exitArmed = false; G.hooks.exit(inExit, this); }
    for (const tr of this.def.triggers) {
      if (tr.kind === 'bossRoom' && !tr.fired && p.x > tr.x + 8 && p.x < tr.x + tr.w && p.y > tr.y && p.y < tr.y + tr.h) {
        tr.fired = true; G.hooks.bossRoom(this);
      }
      if (tr.kind === 'miasmaDeco' && Math.random() < 0.3) this.fx.push(new Particle(tr.x + rand(-tr.r, tr.r), tr.y + rand(-tr.r, tr.r) * 0.5, rand(-4, 4), -rand(6, 14), rand(1, 2), 'rgba(111,191,74,0.5)', 3));
    }
  }
  onPlayerDeath() { G.hooks.death(this); }
  onBossDefeated(how) { G.hooks.bossDefeated(this, how); }

  updateCamera(snap) {
    const p = this.player;
    if (!p) return;
    const mw = this.w * TS, mh = this.h * TS;
    let tx = p.x - VIEW_W / 2, ty = p.y - 10 - VIEW_H / 2;
    tx = mw <= VIEW_W ? (mw - VIEW_W) / 2 : clamp(tx, 0, mw - VIEW_W);
    ty = mh <= VIEW_H ? (mh - VIEW_H) / 2 : clamp(ty, 0, mh - VIEW_H);
    if (snap) { this.cam.x = tx; this.cam.y = ty; }
    else { this.cam.x += (tx - this.cam.x) * 0.15; this.cam.y += (ty - this.cam.y) * 0.15; }
  }

  // ---------------------------------------------------------------- render
  buildGround() {
    this.ground = paintGround(this);
    // boulders and fence posts stand up out of the ground; they join the y-sorted pass
    this.overlays = [];
    for (let y = 0; y < this.h; y++) for (let x = 0; x < this.w; x++) {
      const id = this.tiles[y * this.w + x];
      const o = tileOverlay(id, x, y);
      if (o) this.overlays.push({ ...o, x: x * TS + 8, y: y * TS + 15, rock: id === T.ROCK });
    }
  }

  // The world is drawn at logical resolution (480x270) into an offscreen canvas, post-processed there,
  // then upscaled 2x with nearest-neighbour onto the screen canvas. HUD/text stay at native resolution.
  render(screen) {
    const [wc, ctx] = worldTarget();
    const sx = G.shake > 0 ? Math.round(rand(-G.shake, G.shake)) : 0;
    const sy = G.shake > 0 ? Math.round(rand(-G.shake, G.shake)) : 0;
    const cx = Math.round(this.cam.x) + sx, cy = Math.round(this.cam.y) + sy;
    ctx.setTransform(1, 0, 0, 1, 0, 0);
    ctx.imageSmoothingEnabled = false;
    ctx.fillStyle = '#05060a'; ctx.fillRect(0, 0, VIEW_W, VIEW_H);
    ctx.translate(-cx, -cy);
    ctx.drawImage(this.ground, cx, cy, VIEW_W, VIEW_H, cx, cy, VIEW_W, VIEW_H);

    const inView = (x, y, m = 80) => x > cx - m && x < cx + VIEW_W + m && y > cy - m && y < cy + VIEW_H + m * 1.5;
    // flat props
    for (const p of this.props) if (p.info.flat && inView(p.x, p.y)) ctx.drawImage(p.img, Math.round(p.x - p.info.ax), Math.round(p.y - p.info.ay));
    // soft contact shadows for standing props (drawn on the ground pass so they never cover actors)
    for (const p of this.props) if (!p.info.flat && p.info.foot[0] && inView(p.x, p.y)) shadow(ctx, p.x, p.y, Math.min(70, p.info.foot[0] * 16 + 6));
    for (const o of this.overlays) if (o.rock && inView(o.x, o.y)) shadow(ctx, o.x, o.y + 1, 20);
    // vents glow
    for (const v of this.vents) {
      if (!inView(v.x, v.y)) continue;
      if (v.state === 'bubble') { ctx.fillStyle = 'rgba(255,80,60,0.35)'; ctx.fillRect(v.x - 6, v.y - 6, 12, 12); }
      if (v.state === 'erupt') { ctx.fillStyle = 'rgba(111,191,74,0.35)'; ctx.fillRect(v.x - 9, v.y - 9, 18, 18); }
    }
    for (const z of this.zones) z.drawGround(ctx);
    if (this.boss) this.boss.drawGround(ctx);

    // y-sorted drawables
    const list = [];
    const pl = this.player;
    for (const p of this.props) {
      if (p.info.flat || !inView(p.x, p.y)) continue;
      const x0 = Math.round(p.x - p.info.ax), y0 = Math.round(p.y - p.info.ay);
      // tall props turn see-through while the hero is hidden behind them
      const hides = pl && !pl.dead && pl.y < p.y - 2 && pl.x > x0 + 4 && pl.x < x0 + p.img.width - 4 && pl.y - 20 > y0 + 4;
      p.fade = Math.max(hides ? 0.45 : 1, Math.min(1, (p.fade ?? 1) + (hides ? -0.08 : 0.08)));
      list.push({ y: p.y, d: () => { ctx.globalAlpha = p.fade; ctx.drawImage(p.img, x0, y0); ctx.globalAlpha = 1; } });
    }
    for (const o of this.overlays) if (inView(o.x, o.y)) list.push({ y: o.y, d: () => ctx.drawImage(o.img, o.x - o.ax, o.y - o.ay) });
    for (const it of this.items) if (this.itemVisible(it)) list.push({ y: it.y, d: () => this.drawItem(ctx, it) });
    for (const n of this.npcs) list.push({ y: n.y, d: () => n.draw(ctx) });
    for (const e of this.enemies) if (!e.dead) list.push({ y: e.y, d: () => e.draw(ctx) });
    if (this.boss) {
      list.push({ y: this.boss.y, d: () => this.boss.draw(ctx) });
      for (const c of this.boss.clones) if (!c.dead) list.push({ y: c.y, d: () => c.draw(ctx) });
    }
    for (const g of this.ghosts) list.push({ y: g.y, d: () => { ctx.save(); ctx.globalAlpha = Math.min(1, g.t); ctx.drawImage(g.spr, Math.round(g.x - g.spr.width / 2), Math.round(g.y - g.spr.height - (1.6 - g.t) * 14)); ctx.restore(); } });
    if (this.player) list.push({ y: this.player.y, d: () => this.player.draw(ctx) });
    for (const pr of this.projectiles) list.push({ y: pr.y + 8, d: () => pr.draw(ctx) });
    list.sort((a, b) => a.y - b.y);
    for (const it of list) it.d();

    for (const f of this.fx) if (!f.screenText) f.draw(ctx);

    renderLightmap(ctx, this, cx, cy, frameDt());
    redrawTelegraphs(ctx, this);
    ctx.setTransform(1, 0, 0, 1, 0, 0);
    finish(ctx, this, cx, cy);
    screen.setTransform(1, 0, 0, 1, 0, 0);
    screen.imageSmoothingEnabled = false;
    screen.drawImage(wc, 0, 0, VIEW_W * SCALE, VIEW_H * SCALE);
  }
  drawItem(ctx, it) {
    if (it.kind === 'chest') {
      const img = PROPS.chest(G.flags['opened_' + it.id]);
      ctx.drawImage(img, Math.round(it.x - 9), Math.round(it.y - 15));
      if (!G.flags['opened_' + it.id] && Math.sin(G.time * 4) > 0.6) { ctx.fillStyle = C.goldL; ctx.fillRect(Math.round(it.x) + 5, Math.round(it.y) - 14, 1, 1); }
      return;
    }
    if (it.id === 'doll') {
      ctx.drawImage(PROPS.doll(), Math.round(it.x - 5), Math.round(it.y - 11));
      const s = Math.sin(G.time * 5);
      ctx.fillStyle = C.goldL; ctx.globalAlpha = 0.5 + s * 0.5;
      ctx.fillRect(Math.round(it.x) - 1, Math.round(it.y) - 18, 2, 2); ctx.fillRect(Math.round(it.x) + 5, Math.round(it.y) - 12, 1, 1);
      ctx.globalAlpha = 1;
    }
  }
}
