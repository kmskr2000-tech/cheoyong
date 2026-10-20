// Build a single self-contained HTML file: dist/index.html (scripts and PNG assets inlined).
import fs from 'fs';
import path from 'path';
const root = path.resolve(path.dirname(new URL(import.meta.url).pathname), '..');
const src = path.join(root, 'src');
let html = fs.readFileSync(path.join(src, 'index.html'), 'utf8');
const man = JSON.parse(fs.readFileSync(path.join(src, 'assets', 'manifest.json'), 'utf8'));
const data = {};
const files = [];
for (const c of Object.values(man.chars)) files.push(c.file);
for (const t of Object.values(man.tiles)) files.push(t.file);
for (const p of Object.values(man.props)) files.push(p.file);
for (const f of Object.values(man.images || {})) files.push(f);
for (const f of files) data[f] = 'data:image/png;base64,' + fs.readFileSync(path.join(src, 'assets', f)).toString('base64');
const assets = `<script>window.ASSET_MANIFEST=${JSON.stringify(man)};window.ASSET_DATA=${JSON.stringify(data)};</script>`;
html = html.replace('<!--ASSETS-->', assets);
html = html.replace(/<script src="(js\/[^"]+)"><\/script>/g, (_, f) => `<script>\n${fs.readFileSync(path.join(src, f), 'utf8').replace(/<\/script>/g, '<\\/script>')}\n</script>`);
fs.mkdirSync(path.join(root, 'dist'), { recursive: true });
fs.writeFileSync(path.join(root, 'dist', 'index.html'), html);
console.log('dist/index.html', (html.length / 1024 / 1024).toFixed(2), 'MB');

// --artifact <path>: same page without the document wrapper (the artifact host adds its own)
const ai = process.argv.indexOf('--artifact');
if (ai > 0) {
  let body = html
    .replace(/<!doctype html>\s*/i, '')
    .replace(/<html[^>]*>|<\/html>|<head>|<\/head>|<body>|<\/body>/gi, '')
    .replace(/<meta charset="utf-8">\s*/i, '')
    .replace(/<meta name="viewport"[^>]*>\s*/i, '');
  body = body.replace('<title>신 처용가 — 탈과 노래</title>', '<title>신 처용가</title>');
  body = body.replace('html, body { margin: 0; height: 100%;', ':root { color-scheme: dark; background: #05060f; } html, body { margin: 0; height: 100%;');
  const t = body.match(/<title>.*?<\/title>/)[0];
  body = t + '\n' + body.replace(t, '');
  fs.writeFileSync(process.argv[ai + 1], body);
  console.log(process.argv[ai + 1], (body.length / 1024 / 1024).toFixed(2), 'MB');
}
