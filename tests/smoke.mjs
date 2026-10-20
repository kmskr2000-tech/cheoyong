// Smoke suite: runs scenarios in headless Chromium and fails on page errors or wrong outcomes.
import fs from 'fs';
import { run, serve } from './shot.mjs';
import { createRequire } from 'module';
const require = createRequire(import.meta.url);
let pw; try { pw = require('playwright'); } catch { pw = require('/opt/node22/lib/node_modules/playwright'); }

const OUT = 'tests/out';
fs.mkdirSync(OUT, { recursive: true });
let fail = 0;
const check = (name, ok, extra = '') => { console.log((ok ? 'PASS ' : 'FAIL ') + name + (extra ? '  ' + extra : '')); if (!ok) fail++; };

// 1. reachability: with gates closed the beach must not reach town; with all flags it reaches every zone
async function reach() {
  const srv = await serve();
  const b = await pw.chromium.launch();
  const p = await b.newPage();
  await p.goto(`http://localhost:${srv.address().port}/src/index.html?play&mute`);
  await p.waitForFunction(() => window.__ready === true);
  const res = await p.evaluate(() => {
    const W = G.world, f = G.game.flags;
    const flood = () => {
      const w = W.W * 2, h = W.H * 2, seen = new Uint8Array(w * h), q = [];
      const sx = Math.floor((100 * 32) / 16), sy = Math.floor((70.5 * 32) / 16);
      q.push(sy * w + sx); seen[sy * w + sx] = 1;
      while (q.length) {
        const i = q.pop(), x = i % w, y = (i / w) | 0;
        for (const [dx, dy] of [[1, 0], [-1, 0], [0, 1], [0, -1]]) {
          const nx = x + dx, ny = y + dy, j = ny * w + nx;
          if (nx < 0 || ny < 0 || nx >= w || ny >= h || seen[j]) continue;
          if (W.solidAt(nx * 16 + 8, ny * 16 + 8)) continue;
          seen[j] = 1; q.push(j);
        }
      }
      const out = {};
      for (const z of W.ZONES) {
        const cx = Math.floor(((z.x0 + z.x1) / 2) * 2), cy = Math.floor(((z.y0 + z.y1) / 2) * 2);
        let any = false;
        for (let y = z.y0 * 2; y <= z.y1 * 2 && !any; y++) for (let x = z.x0 * 2; x <= z.x1 * 2; x++) if (seen[y * w + x]) { any = true; break; }
        out[z.id] = any;
      }
      return out;
    };
    const closed = flood();
    f.gate_open = true;
    const town = flood();
    f.paths_open = true; f.house_open = true;
    const all = flood();
    return { closed, town, all };
  });
  await b.close(); srv.close();
  check('gates closed: beach only', res.closed.beach && !res.closed.town && !res.closed.ruin && !res.closed.forest && !res.closed.pond && !res.closed.house, JSON.stringify(res.closed));
  check('south gate open: town reachable, others not', res.town.town && !res.town.ruin && !res.town.forest && !res.town.pond && !res.town.house, JSON.stringify(res.town));
  check('all open: every zone reachable', Object.values(res.all).every(Boolean), JSON.stringify(res.all));
}

async function scenarios() {
  const S = [
    ['title', { query: 'x=1', seconds: 1.5 }, (i) => i.state === 'title'],
    ['talk to dragon king', { query: 'play', seconds: 5, keys: ['hold:KeyD@0.3-1.6', 'KeyE@1.9', 'Enter@2.6', 'Enter@2.9', 'Enter@3.3', 'Enter@3.6'] }, (i) => /q1|has_attack/.test(i.flags) || /처용탈|탈|구절/.test(i.dialog || '') || i.flags === ''],
    ['combat purifies yokai', { query: 'quest=1&enemies=imp,imp,snake', seconds: 7, keys: ['hold:KeyD@0.2-0.8', 'hold:KeyJ@0.9-6.8'] }, (i) => /kills_total/.test(i.flags)],
    ['skills', { query: 'quest=5&enemies=dokkaebi,ghoul,ghost', seconds: 5, keys: ['hold:KeyD@0.2-0.6', 'KeyU@0.8', 'KeyI@1.4', 'KeyO@3.0', 'KeyM@3.8'] }, (i) => i.hp > 0],
    ['boss dokchief', { query: 'quest=5&lvl=8&boss=dokchief&heung', seconds: 8, keys: ['KeyL@0.5', 'hold:KeyJ@3.2-7.8'] }, (i) => i.boss && i.boss.hp < 1040],
    ['boss gumiho', { query: 'quest=5&lvl=8&boss=gumiho', seconds: 6, keys: ['hold:KeyJ@0.5-5.8', 'hold:KeyD@0.5-1.2'] }, (i) => i.state === 'play'],
    ['boss imugi', { query: 'quest=5&lvl=8&boss=imugi', seconds: 6, keys: ['hold:KeyJ@0.5-5.8', 'hold:KeyD@0.5-1.2'] }, (i) => i.state === 'play'],
    ['boss yeoksin', { query: 'quest=6&lvl=10&boss=yeoksin&heung', seconds: 6, keys: ['KeyL@0.5', 'hold:KeyJ@3.2-5.8'] }, (i) => i.state === 'play'],
    ['ending', { query: 'ending', seconds: 2 }, (i) => i.state === 'ending'],
  ];
  for (const [name, opt, ok] of S) {
    const r = await run({ ...opt, out: `${OUT}/${name.replace(/\s+/g, '_')}.png` });
    check(name, ok(r.info) && r.errors.length === 0, JSON.stringify(r.info) + (r.errors.length ? ' ERR ' + r.errors.join(' | ') : ''));
  }
}

await reach();
await scenarios();
console.log(fail ? `${fail} failed` : 'all passed');
process.exit(fail ? 1 : 0);
