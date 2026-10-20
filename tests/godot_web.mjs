// Load the Godot web export in headless Chromium and take a screenshot: node tests/godot_web.mjs <dir> <query> <out.png> <seconds>
import http from 'http'; import fs from 'fs'; import path from 'path';
import { createRequire } from 'module';
const require = createRequire(import.meta.url);
let pw; try { pw = require('playwright'); } catch { pw = require('/opt/node22/lib/node_modules/playwright'); }
const [dir, query = '', out = 'tests/out/godot_web.png', secs = '12', w = '1280', h = '640'] = process.argv.slice(2);
const types = { '.html': 'text/html', '.js': 'text/javascript', '.wasm': 'application/wasm', '.pck': 'application/octet-stream', '.png': 'image/png' };
const srv = http.createServer((q, r) => { const f = path.join(dir, decodeURIComponent(q.url.split('?')[0]) === '/' ? 'index.html' : decodeURIComponent(q.url.split('?')[0])); fs.readFile(f, (e, b) => { if (e) { r.writeHead(404); r.end(); return; } r.writeHead(200, { 'Content-Type': types[path.extname(f)] || 'application/octet-stream' }); r.end(b); }); });
await new Promise((r) => srv.listen(0, r));
const b = await pw.chromium.launch({ args: ['--enable-unsafe-swiftshader', '--use-angle=swiftshader', '--ignore-gpu-blocklist'] });
const page = await b.newPage({ viewport: { width: +w, height: +h } });
const logs = [];
page.on('console', (m) => logs.push(m.type() + ': ' + m.text()));
page.on('pageerror', (e) => logs.push('pageerror: ' + e));
await page.goto(`http://localhost:${srv.address().port}/index.html?${query}`);
await page.waitForTimeout(+secs * 1000);
await page.screenshot({ path: out });
console.log(logs.filter((l) => /RESULT|PROGRESS|error|Error/.test(l)).slice(-15).join('\n'));
await b.close(); srv.close();
