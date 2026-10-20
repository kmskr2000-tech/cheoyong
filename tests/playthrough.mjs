// Full playthrough: the autopilot (?auto) plays from the title to the ending through real input.
// node tests/playthrough.mjs [maxMinutes] [extra query]
import { serve } from './shot.mjs';
import { createRequire } from 'module';
const require = createRequire(import.meta.url);
let pw; try { pw = require('playwright'); } catch { pw = require('/opt/node22/lib/node_modules/playwright'); }
const maxMin = +(process.argv[2] || 20);
const extra = process.argv[3] || 'god';
const srv = await serve();
const b = await pw.chromium.launch();
const page = await b.newPage({ viewport: { width: 1280, height: 640 } });
const errors = [];
page.on('pageerror', (e) => errors.push(String(e)));
page.on('console', (m) => { const t = m.text(); if (m.type() === 'error') errors.push(t); else if (t.startsWith('[auto]')) console.log(t); });
await page.goto(`http://localhost:${srv.address().port}/src/index.html?auto&mute&skipintro&speed=6&${extra}`);
await page.waitForFunction(() => window.__ready === true);
const t0 = Date.now();
let last = '';
let shot = 0;
while ((Date.now() - t0) / 60000 < maxMin) {
  await page.waitForTimeout(4000);
  const s = await page.evaluate(() => {
    const g = G.game, f = g.flags, p = g.player;
    const keys = ['q1', 'q2', 'king_met', 'q3', 'boss_dok', 'boss_fox', 'boss_imugi', 'dosa_done', 'q4', 'yeoksin_done'].filter((k) => f[k]);
    return { state: G.state, t: Math.round(g.time), stage: keys.join(','), zone: g.zone && g.zone.id, lvl: p.lvl, hp: Math.round(p.hp), kills: f.kills_total || 0,
      boss: g.boss ? g.boss.type + ':' + Math.round(g.boss.hp) : '', verses: g.verseCount(), pos: [Math.round(p.x / 32), Math.round(p.y / 32)] };
  });
  const line = JSON.stringify(s);
  if (line !== last) { console.log(line); last = line; }
  if (shot++ % 8 === 0) await page.screenshot({ path: `tests/out/play_${String(shot).padStart(3, '0')}.png` });
  if (s.state === 'ending') { console.log('REACHED ENDING in game time', s.t, 's'); break; }
}
await page.screenshot({ path: 'tests/out/play_final.png' });
if (errors.length) console.log('ERRORS:\n' + [...new Set(errors)].join('\n'));
await b.close(); srv.close();
