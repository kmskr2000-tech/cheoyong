// Autopilot (test only, ?auto): plays the whole story through the real input layer to prove it can be finished.
'use strict';
(() => {
  if (!G.params.has('auto')) return;
  const T = G.TILE;
  const bot = { path: null, pathT: 0, goal: null, log: [], stuckT: 0, lastPos: null };
  G.bot = bot;
  const say = (s) => { if (bot.log[bot.log.length - 1] !== s) { bot.log.push(s); console.log('[auto] ' + s); } };

  // A* on the 16px collision grid
  function findPath(sx, sy, tx, ty) {
    const W = G.world, w = W.W * 2, h = W.H * 2;
    const S = Math.floor(sy / 16) * w + Math.floor(sx / 16);
    let gx = Math.floor(tx / 16), gy = Math.floor(ty / 16);
    const free = (x, y) => x >= 0 && y >= 0 && x < w && y < h && !W.solidAt(x * 16 + 8, y * 16 + 8);
    if (!free(gx, gy)) {
      // nearest free cell to the goal
      let best = null, bd = 1e9;
      for (let r = 1; r < 8 && !best; r++) for (let dy = -r; dy <= r; dy++) for (let dx = -r; dx <= r; dx++) {
        if (free(gx + dx, gy + dy) && dx * dx + dy * dy < bd) { bd = dx * dx + dy * dy; best = [gx + dx, gy + dy]; }
      }
      if (!best) return null;
      [gx, gy] = best;
    }
    const goal = gy * w + gx;
    const g = new Float32Array(w * h).fill(1e9), came = new Int32Array(w * h).fill(-1), closed = new Uint8Array(w * h);
    const open = [[0, S]]; g[S] = 0;
    const hfn = (i) => Math.hypot((i % w) - gx, ((i / w) | 0) - gy);
    let n = 0;
    while (open.length && n++ < 60000) {
      let bi = 0; for (let i = 1; i < open.length; i++) if (open[i][0] < open[bi][0]) bi = i;
      const [, cur] = open.splice(bi, 1)[0];
      if (cur === goal) break;
      if (closed[cur]) continue; closed[cur] = 1;
      const x = cur % w, y = (cur / w) | 0;
      for (const [dx, dy, c] of [[1, 0, 1], [-1, 0, 1], [0, 1, 1], [0, -1, 1], [1, 1, 1.42], [1, -1, 1.42], [-1, 1, 1.42], [-1, -1, 1.42]]) {
        const nx = x + dx, ny = y + dy;
        if (!free(nx, ny)) continue;
        if (dx && dy && (!free(x + dx, y) || !free(x, y + dy))) continue;
        const j = ny * w + nx, ng = g[cur] + c;
        if (ng < g[j]) { g[j] = ng; came[j] = cur; open.push([ng + hfn(j), j]); }
      }
    }
    if (came[goal] < 0 && goal !== S) return null;
    const pts = [];
    for (let i = goal; i !== S && i >= 0; i = came[i]) pts.push({ x: (i % w) * 16 + 8, y: ((i / w) | 0) * 16 + 8 });
    return pts.reverse();
  }

  function plan() {
    const g = G.game, f = g.flags;
    const npc = (id) => { const n = g.npc(id); return { talk: n, x: n.x, y: n.y }; };
    const hunt = (zone) => {
      const p = g.player;
      let best = null, bd = 1e9;
      for (const e of g.enemies) {
        if (e.dead || e.state === 'kneel' || (zone && e.zone !== zone && !e.summoned)) continue;
        const d = G.dist(p.x, p.y, e.x, e.y); if (d < bd) { bd = d; best = e; }
      }
      if (best) return { enemy: best, x: best.x, y: best.y };
      const sp = G.story.SPAWNS[zone].list;
      const [, tx, ty] = sp[Math.floor(g.time / 6) % sp.length];
      return { x: tx * T, y: ty * T };
    };
    if (!f.q1) return npc('yongwang');
    if (!f.q2) return (f.kills_beach || 0) < 6 ? hunt('beach') : npc('yongwang');
    if (!f.king_met) return { x: 61 * T, y: 50 * T };
    if (!f.q3) return npc('halmi');
    if (!f.q4) {
      for (const z of ['ruin', 'forest', 'pond']) {
        const b = G.story.BOSSES[z];
        if (f[b.flag]) continue;
        if ((f['kills_' + z] || 0) < 6) return hunt(z);
        return { x: b.trigger[0] * T, y: b.trigger[1] * T };
      }
      if (!f.dosa_done && (f.kills_total || 0) >= 12) return npc('dosa');
      return npc('halmi');
    }
    if (!f.yeoksin_done) return { x: 20 * T, y: 26 * T };
    return npc('wife_home');
  }

  bot.tick = (dt) => {
    const inp = G.input;
    inp.bot = { x: 0, y: 0, down: new Set() };
    if (G.state === 'title') { inp.press('confirm'); return; }
    if (G.state === 'intro' || G.state === 'ending') { if (Math.random() < 0.05) inp.press('confirm'); return; }
    if (G.state !== 'play') return;
    const g = G.game, p = g.player;
    if (G.ui.shop) { inp.press('menu'); return; }
    if (G.ui.menu) { inp.press('menu'); return; }
    if (G.ui.dialog || G.ui.banner) { bot.cf = (bot.cf || 0) + dt; if (bot.cf > 0.25) { bot.cf = 0; inp.press('confirm'); } return; }
    if (g.frozen || p.state === 'dead') return;
    // fight anything close (and the boss)
    let foe = null, fd = 260;
    for (const e of g.enemies) {
      if (e.dead || e.state === 'kneel' || e.kneeling || e.alpha === 0) continue;
      const d = G.dist(p.x, p.y, e.x, e.y);
      if (d < fd || e === g.boss) { fd = Math.min(fd, d); foe = e; if (e === g.boss) break; }
    }
    if (p.heung >= 100 && foe && (!g.boss || g.boss.ultVulnerable || g.boss.type !== 'yeoksin')) { inp.press('ult'); return; }
    if (g.boss && g.boss.ultVulnerable && p.heung >= 100) { inp.press('ult'); return; }
    let goal = plan();
    if (foe) {
      goal = { x: foe.x, y: foe.y, enemy: foe };
      const d = G.dist(p.x, p.y, foe.x, foe.y);
      if (d < 70 + foe.r) {
        p.faceTo(Math.atan2(foe.y - p.y, foe.x - p.x));
        inp.bot.down.add('attack');
        if (p.skills.skill2 && p.gi > 60) inp.press('skill2');
        return;
      }
      if (d < 200 && p.skills.skill1 && p.gi > 40) { p.faceTo(Math.atan2(foe.y - p.y, foe.x - p.x)); inp.press('skill1'); }
    }
    if (!goal) return;
    // talk when close to the NPC we want
    if (goal.talk && G.dist(p.x, p.y, goal.x, goal.y) < 82) { inp.press('interact'); return; }
    // follow an A* path, re-planned every second or when the goal moves
    bot.pathT -= dt;
    if (!bot.path || bot.pathT <= 0 || !bot.goal || G.dist(bot.goal.x, bot.goal.y, goal.x, goal.y) > 64) {
      bot.path = findPath(p.x, p.y, goal.x, goal.y); bot.pathT = 1.0; bot.goal = goal;
      if (!bot.path) say('no path to ' + Math.round(goal.x / T) + ',' + Math.round(goal.y / T));
    }
    if (bot.path && bot.path.length) {
      while (bot.path.length > 1 && G.dist(p.x, p.y, bot.path[0].x, bot.path[0].y) < 14) bot.path.shift();
      const n = bot.path[0];
      const dx = n.x - p.x, dy = n.y - p.y, m = Math.hypot(dx, dy) || 1;
      inp.bot.x = dx / m; inp.bot.y = dy / m;
    }
    // unstick
    bot.stuckT += dt;
    if (bot.stuckT > 2) {
      if (bot.lastPos && G.dist(bot.lastPos.x, bot.lastPos.y, p.x, p.y) < 10 && !foe) { bot.path = null; inp.press('roll'); }
      bot.lastPos = { x: p.x, y: p.y }; bot.stuckT = 0;
    }
  };
})();
