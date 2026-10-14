// Touch controls: virtual joystick (left), action buttons (right), pause/mute,
// and canvas taps for title/dialog/menu/cutscene. Everything is turned into the
// same key codes the keyboard sends (input.js vDown/vUp/vTap), so game logic is unchanged.
// Shown only on touch devices: primary pointer is coarse, or a finger touched the screen.
// ?touch=1 forces it on, ?touch=0 forces it off.
import { G, BAL } from './state.js';
import { vDown, vUp, vTap } from './input.js';
import { initAudio, sfx } from './audio.js';
import { W, H } from './ui.js';

const CSS = `
#touch { position: fixed; inset: 0; pointer-events: none; z-index: 10; display: none;
  --u: min(1vw, 1vh); font-family: 'Noto Sans KR','Apple SD Gothic Neo','Malgun Gothic',sans-serif;
  -webkit-user-select: none; user-select: none; -webkit-touch-callout: none; touch-action: none; }
#touch.on { display: block; }
#touch .grp { display: none; }
#touch.play .grp.play, #touch.cut .grp.cut { display: block; }
#touch .b { position: absolute; pointer-events: auto; touch-action: none; box-sizing: border-box;
  width: calc(var(--s) * var(--u)); height: calc(var(--s) * var(--u));
  right: calc(var(--r) * var(--u)); bottom: calc(var(--y) * var(--u));
  border-radius: 50%; border: 2px solid rgba(232,208,128,0.55); background: rgba(13,18,38,0.45);
  color: #f0e6c8; display: flex; flex-direction: column; align-items: center; justify-content: center;
  font-size: calc(var(--s) * var(--u) * 0.24); line-height: 1.1; text-shadow: 0 1px 2px #000; }
#touch .b small { font-size: 0.62em; opacity: 0.7; }
#touch .b.on { background: rgba(232,200,96,0.45); border-color: #ffe9a0; }
#touch .b.dim { opacity: 0.4; }
#touch .b.ready { border-color: #ffe080; box-shadow: 0 0 calc(2 * var(--u)) rgba(255,224,128,0.8); }
#touch .b.big { font-size: calc(var(--s) * var(--u) * 0.2); }
#touch .top { position: absolute; top: calc(2 * var(--u)); pointer-events: auto; touch-action: none;
  min-width: calc(9 * var(--u)); height: calc(9 * var(--u)); padding: 0 calc(1.5 * var(--u)); box-sizing: border-box;
  border-radius: calc(2 * var(--u)); border: 2px solid rgba(232,208,128,0.5); background: rgba(13,18,38,0.6);
  color: #f0e6c8; display: flex; align-items: center; justify-content: center; font-size: calc(4 * var(--u)); }
#touch #t-zone { position: absolute; left: 0; bottom: 0; width: 45vw; height: 80vh; pointer-events: auto; touch-action: none; }
#touch .stick { position: absolute; width: calc(26 * var(--u)); height: calc(26 * var(--u)); margin: calc(-13 * var(--u)) 0 0 calc(-13 * var(--u));
  border-radius: 50%; border: 2px solid rgba(232,208,128,0.4); background: rgba(13,18,38,0.3); pointer-events: none; }
#touch .knob { position: absolute; left: 50%; top: 50%; width: calc(11 * var(--u)); height: calc(11 * var(--u));
  margin: calc(-5.5 * var(--u)) 0 0 calc(-5.5 * var(--u)); border-radius: 50%; background: rgba(232,208,128,0.55); }
`;

// [id, code, label, key hint, size, right, bottom]
const BTNS = [
  ['attack', 'KeyZ', '베기', '조사', 21, 3, 4],
  ['dodge', 'ShiftLeft', '구르기', '', 15, 26, 3],
  ['cast', 'KeyC', '발동', '부적', 15, 5, 27],
  ['swap', 'KeyX', '전환', '부적', 12, 22, 21],
  ['song', 'KeyV', '처용가', '', 11, 36, 19],
  ['ult', 'KeyF', '처용무', '', 12, 22, 36],
  ['item3', 'Digit3', '정화부', '', 9, 3, 47],
  ['item2', 'Digit2', '구기자', '', 9, 13, 47],
  ['item1', 'Digit1', '인삼', '', 9, 23, 47],
];
const ITEM_OF = { item1: 'insam', item2: 'gugija', item3: 'jeonghwa' };

let root, zone, stick, knob, btnEls = {};
let mode = '';
const STICK_R = 13; // in --u units (base radius)

export const TOUCH = { on: false };
const FORCE = new URLSearchParams(location.search).get('touch');

function unit() { return Math.min(window.innerWidth, window.innerHeight) / 100; }

function enable() {
  if (TOUCH.on) return;
  TOUCH.on = true; G.touch = true;
  root.classList.add('on');
}

// ------------------------------------------------------------ buttons (hold semantics)
function bindButton(el, code) {
  let pid = null;
  const release = () => { if (pid === null) return; pid = null; el.classList.remove('on'); vUp(code); };
  el.addEventListener('pointerdown', (e) => {
    e.preventDefault();
    if (pid !== null) return;
    pid = e.pointerId;
    try { el.setPointerCapture(pid); } catch (_) { /* synthetic pointers */ }
    el.classList.add('on');
    vDown(code);
  });
  el.addEventListener('pointerup', (e) => { if (e.pointerId === pid) release(); });
  el.addEventListener('pointercancel', (e) => { if (e.pointerId === pid) release(); });
  el.addEventListener('lostpointercapture', (e) => { if (e.pointerId === pid) release(); });
  return release;
}

// ------------------------------------------------------------ joystick (digital 8-way)
const DIRS = [ // sector i covers angle i*45° (0 = right, clockwise in screen coords)
  ['ArrowRight'], ['ArrowRight', 'ArrowDown'], ['ArrowDown'], ['ArrowDown', 'ArrowLeft'],
  ['ArrowLeft'], ['ArrowLeft', 'ArrowUp'], ['ArrowUp'], ['ArrowUp', 'ArrowRight'],
];
const ARROWS = ['ArrowRight', 'ArrowDown', 'ArrowLeft', 'ArrowUp'];
const joy = { pid: null, ox: 0, oy: 0, sector: -1 };

function setSector(s) {
  if (s === joy.sector) return;
  joy.sector = s;
  const want = s < 0 ? [] : DIRS[s];
  for (const k of ARROWS) if (!want.includes(k)) vUp(k);
  for (const k of want) vDown(k);
}
function joyMove(x, y) {
  const r = STICK_R * unit();
  let dx = x - joy.ox, dy = y - joy.oy;
  const d = Math.hypot(dx, dy);
  const m = d / r;
  if (d > r) { dx *= r / d; dy *= r / d; }
  knob.style.transform = `translate(${dx}px, ${dy}px)`;
  // dead zone with hysteresis: engage above 0.3, release below 0.2
  if (m < (joy.sector < 0 ? 0.3 : 0.2)) { setSector(-1); return; }
  const ang = (Math.atan2(dy, dx) * 180 / Math.PI + 360) % 360;
  if (joy.sector >= 0) {
    // keep the current direction until the finger is clearly in another sector
    let diff = Math.abs(ang - joy.sector * 45); if (diff > 180) diff = 360 - diff;
    if (diff <= 22.5 + 8) return;
  }
  setSector(Math.round(ang / 45) % 8);
}
function placeStick(x, y) { stick.style.left = `${x}px`; stick.style.top = `${y}px`; }
function stickHome() {
  const u = unit();
  joy.ox = 19 * u; joy.oy = window.innerHeight - 19 * u;
  placeStick(joy.ox, joy.oy);
  knob.style.transform = '';
}
function joyRelease() {
  if (joy.pid === null && joy.sector < 0) return;
  joy.pid = null;
  setSector(-1);
  stickHome();
}

function releaseAll() {
  joyRelease();
  Object.values(btnEls).forEach((b) => b.release());
}

// ------------------------------------------------------------ canvas taps (UI)
function canvasPoint(canvas, e) {
  const r = canvas.getBoundingClientRect();
  return { x: (e.clientX - r.left) / r.width * W, y: (e.clientY - r.top) / r.height * H };
}

function tapUI(x, y, hasSave) {
  const m = G.menu;
  if (m) {
    const h = m.hit;
    if (!h) return;
    if (x >= h.x && x <= h.x + h.w && y >= h.y && y <= h.y + h.h) {
      const i = h.rows.findIndex(([y0, y1]) => y >= y0 && y < y1);
      if (i < 0) return;
      const o = m.options[i];
      if (o.disabled) { sfx('denied'); return; }
      // menus with descriptions (shop): first tap selects and shows the description, second tap buys
      // (armed per menu instance, so the default highlighted row also needs a confirming tap)
      if (m.armed !== i && m.options.some((q) => q.desc)) { m.sel = i; m.armed = i; sfx('blip'); return; }
      m.sel = i;
      vTap('Enter');
    } else if (m.cancel) vTap('Escape');
    return;
  }
  if (G.dialog || G.cutscene) { vTap('Enter'); return; }
  if (G.scene === 'title') {
    ['새로 시작', '이어하기'].forEach((_, i) => {
      const cy = 268 + i * 38;
      if (Math.abs(x - W / 2) < 170 && y > cy - 28 && y < cy + 10) {
        if (i === 1 && !hasSave()) { sfx('denied'); return; }
        G.titleSel = i;
        vTap('Enter');
      }
    });
  }
}

// ------------------------------------------------------------ per-frame sync
export function syncTouch() {
  if (!TOUCH.on) return;
  const play = G.scene === 'play' && G.level && G.player && !G.dialog && !G.menu && !G.cutscene;
  const m = play ? 'play' : (G.cutscene && G.cutscene.skippable ? 'cut' : '');
  if (m !== mode) {
    root.classList.toggle('play', m === 'play');
    root.classList.toggle('cut', m === 'cut');
    if (m !== 'play') releaseAll();
    mode = m;
  }
  if (m !== 'play') return;
  const p = G.player;
  for (const id in ITEM_OF) btnEls[id].setSub(`×${G.items[ITEM_OF[id]]}`);
  btnEls.ult.el.classList.toggle('ready', p.sin >= 100);
  btnEls.ult.el.classList.toggle('dim', p.sin < 100);
  btnEls.song.el.classList.toggle('dim', !!(G.encounter && G.encounter.songUsed));
  const cur = G.tal.unlocked[G.tal.idx % G.tal.unlocked.length];
  btnEls.cast.setSub({ fire: '화염부', bind: '결박부', guard: '수호부' }[cur] || '부적');
  btnEls.cast.el.classList.toggle('dim', p.sori < (BAL.costs[cur] || 0));
}

export function initTouch(canvas, hasSave) {
  const st = document.createElement('style'); st.textContent = CSS; document.head.appendChild(st);
  root = document.createElement('div'); root.id = 'touch';
  root.innerHTML = `
    <div class="grp play">
      <div id="t-zone"></div>
      <div class="stick"><div class="knob"></div></div>
    </div>
    <div class="grp play"></div>
    <div class="grp cut"><div class="top" id="t-skip" style="right:calc(2*var(--u))">건너뛰기 ▶▶</div></div>`;
  document.body.appendChild(root);
  zone = root.querySelector('#t-zone');
  stick = root.querySelector('.stick');
  knob = root.querySelector('.knob');
  const pad = root.querySelectorAll('.grp.play')[1];

  for (const [id, code, label, hint, s, r, y] of BTNS) {
    const el = document.createElement('div');
    el.className = 'b' + (s >= 20 ? ' big' : '');
    el.dataset.id = id;
    el.style.setProperty('--s', s); el.style.setProperty('--r', r); el.style.setProperty('--y', y);
    el.innerHTML = `<span>${label}</span><small>${hint}</small>`;
    pad.appendChild(el);
    const sub = el.querySelector('small');
    let last = hint;
    btnEls[id] = { el, release: bindButton(el, code), setSub: (t) => { if (t !== last) { sub.textContent = t; last = t; } } };
  }
  const topBtn = (id, text, right, code) => {
    const el = document.createElement('div');
    el.className = 'top'; el.id = id; el.textContent = text; el.style.right = `calc(${right} * var(--u))`;
    el.addEventListener('pointerdown', (e) => { e.preventDefault(); vTap(code); });
    pad.appendChild(el);
  };
  // top-right sits over the quest tracker only at its very edge; the canvas is letterboxed on most phones
  topBtn('t-pause', '☰', 2, 'Escape');
  topBtn('t-mute', '♪', 13, 'KeyM');
  root.querySelector('#t-skip').addEventListener('pointerdown', (e) => { e.preventDefault(); vTap('Escape'); });

  zone.addEventListener('pointerdown', (e) => {
    e.preventDefault();
    if (joy.pid !== null) return;
    joy.pid = e.pointerId;
    try { zone.setPointerCapture(joy.pid); } catch (_) { /* synthetic pointers */ }
    joy.ox = e.clientX; joy.oy = e.clientY; // floating stick: centre where the thumb lands
    placeStick(joy.ox, joy.oy);
    knob.style.transform = '';
  });
  zone.addEventListener('pointermove', (e) => { if (e.pointerId === joy.pid) joyMove(e.clientX, e.clientY); });
  const end = (e) => { if (e.pointerId === joy.pid) joyRelease(); };
  zone.addEventListener('pointerup', end);
  zone.addEventListener('pointercancel', end);
  zone.addEventListener('lostpointercapture', end);

  canvas.addEventListener('pointerdown', (e) => {
    if (e.pointerType === 'mouse') return; // desktop keeps keyboard-only UI
    e.preventDefault();
    const pt = canvasPoint(canvas, e);
    tapUI(pt.x, pt.y, hasSave);
  });

  window.addEventListener('pointerdown', (e) => {
    initAudio(); // iOS unlocks audio only inside a user gesture
    if (e.pointerType === 'touch' && FORCE !== '0') enable();
  }, true);
  root.addEventListener('contextmenu', (e) => e.preventDefault());
  window.addEventListener('blur', releaseAll);
  document.addEventListener('visibilitychange', () => { if (document.hidden) releaseAll(); });
  window.addEventListener('resize', () => { if (joy.pid === null) stickHome(); });

  const coarse = window.matchMedia && window.matchMedia('(pointer: coarse)').matches;
  if (FORCE !== '0' && (FORCE === '1' || coarse)) enable();
  stickHome();
}
