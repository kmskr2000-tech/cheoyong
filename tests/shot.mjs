// 한 장면 찍기 + 정적 서버 유틸.
// CLI: node tests/shot.mjs "<query>" out.png <초> [KeyJ@1.0] [hold:KeyD@0.5-2]
import http from 'node:http';
import fs from 'node:fs';
import path from 'node:path';
import { createRequire } from 'node:module';
import { fileURLToPath, pathToFileURL } from 'node:url';

const require = createRequire(import.meta.url);
let pw;
try { pw = require('playwright'); } catch { pw = require('/opt/node22/lib/node_modules/playwright'); }

const HERE = path.dirname(fileURLToPath(import.meta.url));
export const REPO = path.resolve(HERE, '..');
const TYPES = {
  '.html': 'text/html; charset=utf-8', '.js': 'text/javascript; charset=utf-8', '.mjs': 'text/javascript; charset=utf-8',
  '.css': 'text/css', '.json': 'application/json', '.png': 'image/png', '.jpg': 'image/jpeg', '.svg': 'image/svg+xml',
  '.woff2': 'font/woff2', '.ttf': 'font/ttf', '.mp3': 'audio/mpeg', '.ogg': 'audio/ogg', '.wav': 'audio/wav', '.ico': 'image/x-icon',
};

// 저장소 루트(또는 root)를 정적으로 서비스. → { port, url, close() }
export function serve(root = REPO) {
  const base = path.resolve(root);
  const server = http.createServer((req, res) => {
    try {
      let p = decodeURIComponent(new URL(req.url, 'http://x').pathname);
      let f = path.join(base, p);
      if (!f.startsWith(base)) { res.writeHead(403).end(); return; }
      if (fs.existsSync(f) && fs.statSync(f).isDirectory()) f = path.join(f, 'index.html');
      if (!fs.existsSync(f)) { res.writeHead(404).end('not found'); return; }
      res.writeHead(200, { 'content-type': TYPES[path.extname(f)] || 'application/octet-stream', 'cache-control': 'no-store' });
      fs.createReadStream(f).pipe(res);
    } catch { res.writeHead(500).end(); }
  });
  return new Promise((resolve) => server.listen(0, '127.0.0.1', () => {
    const port = server.address().port;
    resolve({ port, url: `http://127.0.0.1:${port}`, close: () => new Promise((r) => server.close(() => r())) });
  }));
}

// keys: ['KeyJ@1.0', 'hold:KeyD@0.5-2'] → 시간순 이벤트
function timeline(keys = []) {
  const ev = [];
  for (const k of keys) {
    const hold = k.startsWith('hold:');
    const [code, when] = (hold ? k.slice(5) : k).split('@');
    if (hold) { const [a, b] = when.split('-').map(Number); ev.push({ t: a, type: 'down', code }, { t: b, type: 'up', code }); }
    else ev.push({ t: Number(when || 0), type: 'press', code });
  }
  return ev.sort((a, b) => a.t - b.t);
}
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

/**
 * run({ query, seconds, keys, out, touch, until, path, base, browser })
 *  - query: 'night=1&mute' 또는 '?night=1'
 *  - until: 페이지 안에서 평가할 식. 주어지면 seconds를 상한(타임아웃)으로 이 식이 참이 될 때까지 기다린다.
 *  - base/browser: 이미 띄운 서버·브라우저를 재사용
 * → { info, errors, out }
 */
export async function run({ query = '', seconds = 2, keys = [], out = null, touch = false, until = null, path: pagePath = '/src/index.html', base = null, browser = null } = {}) {
  const srv = base ? null : await serve();
  const url = (base || srv.url) + pagePath;
  const b = browser || await pw.chromium.launch();
  const context = await b.newContext(touch ? { viewport: { width: 960, height: 540 }, hasTouch: true } : { viewport: { width: 960, height: 540 } });
  const page = await context.newPage();
  const errors = [];
  page.on('pageerror', (e) => errors.push('pageerror: ' + e.message));
  await page.route(/fonts\.(googleapis|gstatic)\.com/, (r) => r.abort());
  let q = String(query).replace(/^\?/, '');
  if (touch && !/(^|&)touch(=|&|$)/.test(q)) q += (q ? '&' : '') + 'touch';
  try {
    await page.goto(`${url}${q ? '?' + q : ''}`, { waitUntil: 'domcontentloaded' });
    await page.waitForFunction('window.__ready === true', null, { timeout: 15000 }).catch((e) => errors.push('not ready: ' + e.message));
    const t0 = Date.now();
    for (const e of timeline(keys)) {
      const wait = e.t * 1000 - (Date.now() - t0);
      if (wait > 0) await sleep(wait);
      if (e.type === 'down') await page.keyboard.down(e.code);
      else if (e.type === 'up') await page.keyboard.up(e.code);
      else await page.keyboard.press(e.code);
    }
    if (until) await page.waitForFunction(until, null, { timeout: seconds * 1000, polling: 100 }).catch((e) => errors.push('timeout: ' + until));
    else { const rest = seconds * 1000 - (Date.now() - t0); if (rest > 0) await sleep(rest); }
    if (out) { fs.mkdirSync(path.dirname(path.resolve(out)), { recursive: true }); await page.screenshot({ path: out }); }
    const info = await page.evaluate(() => {
      const G = window.G; if (!G) return null;
      const i = { sceneName: G.sceneName, reachedEnding: !!G.reachedEnding, muted: G.muted, auto: G.auto, nightSpirits: G.night && G.night.spirits ? G.night.spirits.length : null, judge: null };
      try {
        const d = G.scene && G.scene.debug && G.scene.debug();
        const j = d && d.judge;
        if (j) i.judge = { stats: j.stats, hyung: j.hyung, deok: j.deok, combo: j.combo, outcome: j.outcome() };
      } catch (e) { i.judgeError = String(e); }
      return i;
    });
    const pe = await page.evaluate(() => window.__errors || []);
    return { info, errors: [...errors, ...pe], out };
  } finally {
    await context.close();
    if (!browser) await b.close();
    if (srv) await srv.close();
  }
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  const [query, out, secs, ...keys] = process.argv.slice(2);
  if (!query && query !== '') { console.log('usage: node tests/shot.mjs "<query>" out.png <seconds> [KeyJ@1.0] [hold:KeyD@0.5-2]'); process.exit(2); }
  const r = await run({ query, out: out || 'tests/out/shot.png', seconds: Number(secs) || 2, keys });
  console.log(JSON.stringify(r.info));
  if (r.errors.length) { console.log('ERRORS:\n' + r.errors.join('\n')); process.exit(1); }
}
