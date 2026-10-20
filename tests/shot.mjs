// Screenshot helper: node tests/shot.mjs "<query>" out.png [seconds] [keys...]
// keys: "KeyJ@1.2" presses J at 1.2 s, "hold:KeyD@0.5-2" holds D from 0.5 to 2 s
import { createRequire } from 'module';
import http from 'http';
import fs from 'fs';
import path from 'path';
const require = createRequire(import.meta.url);
let pw;
try { pw = require('playwright'); } catch { pw = require('/opt/node22/lib/node_modules/playwright'); }

const root = path.resolve(path.dirname(new URL(import.meta.url).pathname), '..');
export function serve(dir = root) {
  const types = { '.html': 'text/html', '.js': 'text/javascript', '.json': 'application/json', '.png': 'image/png', '.css': 'text/css' };
  const srv = http.createServer((req, res) => {
    const u = decodeURIComponent(req.url.split('?')[0]);
    const f = path.join(dir, u === '/' ? 'index.html' : u);
    fs.readFile(f, (e, b) => { if (e) { res.writeHead(404); res.end(); return; } res.writeHead(200, { 'Content-Type': types[path.extname(f)] || 'application/octet-stream' }); res.end(b); });
  });
  return new Promise((r) => srv.listen(0, () => r(srv)));
}

export async function run({ query, out, seconds = 2, keys = [], width = 1280, height = 640, page: pagePath = '/src/index.html' }) {
  const srv = await serve();
  const port = srv.address().port;
  const browser = await pw.chromium.launch({ executablePath: fs.existsSync('/opt/pw-browsers/chromium') ? undefined : undefined, args: ['--autoplay-policy=no-user-gesture-required'] });
  const page = await browser.newPage({ viewport: { width, height } });
  const errors = [];
  page.on('pageerror', (e) => errors.push(String(e)));
  page.on('console', (m) => { if (m.type() === 'error') errors.push(m.text()); });
  await page.goto(`http://localhost:${port}${pagePath}?${query}&mute`);
  await page.waitForFunction(() => window.__ready === true, null, { timeout: 30000 }).catch(() => errors.push('not ready'));
  const t0 = Date.now();
  const evs = keys.map((k) => {
    const m = k.match(/^(hold:)?(\w+)@([\d.]+)(?:-([\d.]+))?$/);
    return { hold: !!m[1], key: m[2], t: +m[3], t2: m[4] ? +m[4] : null, done: 0 };
  });
  while ((Date.now() - t0) / 1000 < seconds) {
    const t = (Date.now() - t0) / 1000;
    for (const e of evs) {
      if (e.done === 0 && t >= e.t) { e.done = 1; if (e.hold) await page.keyboard.down(e.key); else await page.keyboard.press(e.key); }
      if (e.hold && e.done === 1 && e.t2 && t >= e.t2) { e.done = 2; await page.keyboard.up(e.key); }
    }
    await page.waitForTimeout(30);
  }
  if (out) await page.screenshot({ path: out });
  const info = await page.evaluate(() => {
    const g = window.G && G.game;
    if (!g || !g.player) return { state: window.G && G.state };
    const p = g.player;
    return { state: G.state, zone: g.zone && g.zone.id, enemies: g.enemies.filter((e) => !e.dead && e.state !== 'kneel').length,
      kneeling: g.enemies.filter((e) => e.state === 'kneel').length, hp: Math.round(p.hp), lvl: p.lvl, coins: p.coins,
      pos: [Math.round(p.x / 32 * 10) / 10, Math.round(p.y / 32 * 10) / 10], flags: Object.keys(g.flags).filter((k) => g.flags[k]).join(','),
      boss: g.boss ? { type: g.boss.type, hp: g.boss.hp } : null, dialog: G.ui.dialog ? G.ui.dialog.lines[G.ui.dialog.i][1] : null };
  });
  await browser.close();
  srv.close();
  return { info, errors };
}

if (process.argv[1] && process.argv[1].endsWith('shot.mjs')) {
  const [query = 'play', out = 'tests/out/shot.png', seconds = '2', ...keys] = process.argv.slice(2);
  fs.mkdirSync(path.dirname(out), { recursive: true });
  run({ query, out, seconds: +seconds, keys }).then((r) => { console.log(JSON.stringify(r.info)); if (r.errors.length) console.log('ERRORS:\n' + r.errors.join('\n')); });
}
