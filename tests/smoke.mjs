// 스모크 테스트: 장면별 스크린샷(tests/out/) + 오류 0 + 자동 조종으로 엔딩 도달.
import { createRequire } from 'node:module';
import { serve, run } from './shot.mjs';

const require = createRequire(import.meta.url);
let pw;
try { pw = require('playwright'); } catch { pw = require('/opt/node22/lib/node_modules/playwright'); }

const srv = await serve();
const browser = await pw.chromium.launch();
let failed = 0;
const common = { base: srv.url, browser };

const cases = [
  { name: 'title', query: '', seconds: 2, out: 'tests/out/title.png' },
  { name: 'night1', query: 'night=1&mute', seconds: 2, out: 'tests/out/night1.png' },
  { name: 'dance-fever', query: 'dance=fever&mute', seconds: 4, out: 'tests/out/dance-fever.png',
    keys: ['KeyA@1.2', 'KeyS@1.8', 'KeyW@2.4', 'KeyD@3.0', 'hold:KeyD@3.4-3.8'] },
  { name: 'night4', query: 'night=4&mute', seconds: 2, out: 'tests/out/night4.png' },
  { name: 'ending', query: 'ending&mute', seconds: 3, out: 'tests/out/ending.png' },
  { name: 'auto', query: 'auto&mute&speed=6', seconds: 120, out: 'tests/out/auto-end.png', until: 'window.G && window.G.reachedEnding === true' },
];

try {
  for (const c of cases) {
    const t0 = Date.now();
    const r = await run({ ...common, ...c });
    const bad = r.errors.length > 0 || (c.name === 'auto' && !(r.info && r.info.reachedEnding));
    if (bad) failed++;
    console.log(`${bad ? 'FAIL' : 'ok  '} ${c.name} (${((Date.now() - t0) / 1000).toFixed(1)}s) scene=${r.info && r.info.sceneName}`);
    for (const e of r.errors) console.log('     ' + e);
  }
} finally {
  await browser.close();
  await srv.close();
}
console.log(failed ? `${failed} 실패` : '스모크 통과');
process.exit(failed ? 1 : 0);
