// 작은 ESM 번들러: src/js/main.js 에서 상대 import 를 따라가 하나의 클래식 스크립트로 묶어 dist/index.html 에 넣는다.
// 사용: node tools/build.mjs [--root <저장소>] [--out <파일>] [--check]
//  각 모듈은 `const M_x = (() => { ...; return { X, default } })();` 로 감싸고,
//  import 는 `const { X: Y } = M_x;` 로 바꾼다.
//  순환 import 는 나중에 평가되는 모듈을 가리키는 쪽만 `let Y;` + 연결 함수(__links)로 바꿔, 모든 모듈이 평가된 뒤 채운다
//  (모듈 최상위에서 순환 대상의 값을 바로 쓰면 undefined — 네이티브 ESM 의 TDZ 오류와 같은 종류의 문제).
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';

const argv = process.argv.slice(2);
const opt = (n) => { const i = argv.indexOf(n); return i >= 0 ? argv[i + 1] : null; };
const ROOT = path.resolve(opt('--root') || path.join(path.dirname(fileURLToPath(import.meta.url)), '..'));
const SRC = path.join(ROOT, 'src');
const ENTRY = path.join(SRC, 'js', 'main.js');
const OUT = path.resolve(opt('--out') || path.join(ROOT, 'dist', 'index.html'));

const idOf = (f) => 'M_' + path.relative(path.join(SRC, 'js'), f).replace(/\.js$/, '').replace(/[^\w]/g, '_');
function resolveImport(from, spec) {
  if (!spec.startsWith('.')) throw new Error(`${path.relative(ROOT, from)}: 외부 import 는 번들할 수 없음: ${spec}`);
  let f = path.resolve(path.dirname(from), spec);
  if (!path.extname(f)) f += '.js';
  if (!fs.existsSync(f)) throw new Error(`${path.relative(ROOT, from)}: import 대상 없음: ${spec}`);
  return f;
}
const IMPORT_RE = /^import\s+([\s\S]*?)\s+from\s+['"]([^'"]+)['"];?[ \t]*$/gm;
const SIDE_RE = /^import\s+['"]([^'"]+)['"];?[ \t]*$/gm;
const REEXPORT_RE = /^export\s*\{([^}]*)\}\s*from\s+['"]([^'"]+)['"];?[ \t]*$/gm;

function names(list) {   // "a, b as c" → [[a,a],[b,c]]
  return list.split(',').map((s) => s.trim()).filter(Boolean).map((s) => {
    const m = s.split(/\s+as\s+/); return [m[0].trim(), (m[1] || m[0]).trim()];
  });
}

function transform(file, isBack = null) {
  let code = fs.readFileSync(file, 'utf8');
  const deps = [];
  const dep = (spec) => { const f = resolveImport(file, spec); if (!deps.includes(f)) deps.push(f); return idOf(f); };
  const back = (spec) => !!(isBack && isBack(resolveImport(file, spec)));

  code = code.replace(REEXPORT_RE, (_, list, spec) => {
    const id = dep(spec);
    return names(list).map(([a, b]) => { reexports.push(`${JSON.stringify(b)}: ${id}[${JSON.stringify(a)}]`); return ''; }).join('');
  });
  code = code.replace(IMPORT_RE, (_, clause, spec) => {
    const id = dep(spec), late = back(spec), out = [];
    const bind = (decl, expr) => {            // decl: 'name' | '{ a: b }' 모양의 좌변
      if (!late) return out.push(`const ${decl} = ${expr};`);
      const vars = decl.startsWith('{') ? decl.slice(1, -1).split(',').map((x) => x.split(':').pop().trim()) : [decl];
      out.push(`let ${vars.join(', ')}; __links.push(() => { (${decl} = ${expr}); });`);
    };
    let c = clause.trim();
    const ns = c.match(/\*\s+as\s+(\w+)/);
    if (ns) { bind(ns[1], id); c = c.replace(/,?\s*\*\s+as\s+\w+/, '').trim(); }
    const br = c.match(/\{([\s\S]*)\}/);
    if (br) {
      const parts = names(br[1]).map(([a, b]) => (a === 'default' ? `default: ${b}` : a === b ? a : `${a}: ${b}`));
      if (parts.length) bind(`{ ${parts.join(', ')} }`, id);
      c = c.replace(/,?\s*\{[\s\S]*\}/, '').trim();
    }
    c = c.replace(/,$/, '').trim();
    if (c) bind(c, `${id}.default`);
    return out.join(' ');
  });
  code = code.replace(SIDE_RE, (_, spec) => { dep(spec); return ''; });

  const exp = [];
  code = code.replace(/^export\s+default\s+(?:async\s+)?(?:function\*?|class)\s+(\w+)/gm, (m, n) => { exp.push(`default: ${n}`); return m.replace(/^export\s+default\s+/, ''); });
  code = code.replace(/^export\s+default\s+/gm, () => { exp.push('default: __default'); return 'const __default = '; });
  code = code.replace(/^export\s+((?:const|let|var)\s+)(\w+)/gm, (_, kw, n) => { exp.push(n); return kw + n; });
  code = code.replace(/^export\s+((?:async\s+)?function\*?\s*)(\w+)/gm, (_, kw, n) => { exp.push(n); return kw + n; });
  code = code.replace(/^export\s+(class\s+)(\w+)/gm, (_, kw, n) => { exp.push(n); return kw + n; });
  code = code.replace(/^export\s*\{([^}]*)\};?[ \t]*$/gm, (_, list) => { for (const [a, b] of names(list)) exp.push(a === b ? a : `${JSON.stringify(b)}: ${a}`); return ''; });
  if (/^export\s+\*/m.test(code)) throw new Error(`${path.relative(ROOT, file)}: export * 는 지원하지 않음`);
  return { code, deps, exp: [...exp, ...reexports.splice(0)] };
}
const reexports = [];

// 위상 정렬(의존이 먼저). 순환이면 DFS 에서 만난 되돌이 간선은 무시하고 __links 로 잇는다.
const order = [], state = new Map();
function visit(f) {
  if (state.has(f)) return;
  state.set(f, 1);
  for (const d of transform(f).deps) visit(d);
  order.push(f);
}

export function bundle() {
  order.length = 0; state.clear();
  visit(ENTRY);
  const idx = new Map(order.map((f, i) => [f, i]));
  const parts = order.map((f) => {
    const m = transform(f, (dep) => idx.get(dep) >= idx.get(f));
    return `// ---- ${path.relative(SRC, f)}\nconst ${idOf(f)} = (() => {\n${m.code}\nreturn { ${m.exp.join(', ')} };\n})();`;
  });
  return `'use strict';\nconst __links = [];\n${parts.join('\n\n')}\n__links.forEach((f) => f());\n`.replace(/<\/script/gi, '<\\/script');
}

function build() {
  const html = fs.readFileSync(path.join(SRC, 'index.html'), 'utf8');
  const tag = /<script\s+type="module"\s+src="js\/main\.js"\s*><\/script>/;
  if (!tag.test(html)) throw new Error('src/index.html 에서 main.js 모듈 스크립트 태그를 찾지 못함');
  const js = bundle();
  const out = html.replace(tag, () => `<script>\n${js}</script>`);
  fs.mkdirSync(path.dirname(OUT), { recursive: true });
  fs.writeFileSync(OUT, out);
  console.log(`빌드: ${path.relative(process.cwd(), OUT)} (${(out.length / 1024).toFixed(1)} KB, 모듈 ${order.length}개)`);
}

try { build(); } catch (e) { console.error('빌드 실패: ' + e.message); process.exit(1); }

if (argv.includes('--check')) {
  const { serve, run } = await import(pathToFileURL(path.join(path.dirname(fileURLToPath(import.meta.url)), '..', 'tests', 'shot.mjs')).href);
  const srv = await serve(path.dirname(OUT));
  try {
    const r = await run({ query: 'mute', seconds: 3, base: srv.url, path: '/' + path.basename(OUT) });
    console.log('검사: scene=' + (r.info && r.info.sceneName) + ' errors=' + r.errors.length);
    if (!r.info || r.errors.length) { console.error(r.errors.join('\n') || '장면 없음'); process.exit(1); }
    console.log('번들 통과');
  } finally { await srv.close(); }
}
