// Boot, main loop, scene flow, save/load and debug hooks.
import { G, BAL, VIEW_W, VIEW_H, SCALE, TS, newGameState, wait, toast } from './state.js';
import { initInput, pollInput, input, onAnyKey } from './input.js';
import { initAudio, sfx, playMusic, toggleMute } from './audio.js';
import { buildSprites, SPR, C, makeCanvas, drawBoss, PROPS, rng } from './gfx.js';
import { Level } from './world.js';
import { Player } from './entities.js';
import { say, choose, updateDialog, updateMenu, drawDialog, drawMenu, drawHUD, drawWorldText, drawToasts, font, W, H, panel } from './ui.js';
import * as story from './story.js';
import { FX, finishTitle, trackRender } from './post.js';
import { initTouch, syncTouch } from './touch.js';

const SAVE_KEY = 'cheoyong.ch1.save';
const canvas = document.getElementById('game');
const ctx = canvas.getContext('2d');
ctx.imageSmoothingEnabled = false;

// ------------------------------------------------------------ save / load
function saveGame() {
  const data = {
    v: 1, stats: G.stats, items: G.items, tal: G.tal, flags: G.flags, checkpoint: G.checkpoint,
    sori: G.player ? G.player.sori : 100, savedAt: Date.now(),
  };
  try { localStorage.setItem(SAVE_KEY, JSON.stringify(data)); } catch (e) { /* storage may be blocked */ }
}
function readSave() {
  try { const s = localStorage.getItem(SAVE_KEY); return s ? JSON.parse(s) : null; } catch (e) { return null; }
}
function applySave(d) {
  G.stats = d.stats; G.items = d.items; G.tal = d.tal; G.flags = d.flags; G.checkpoint = d.checkpoint;
  // a saved boss fight never resumes mid-fight
  G.flags.boss_fight = 0;
}

// ------------------------------------------------------------ level flow
const LEVEL_NAMES = { village: '경주 변두리', field: '폐가로 가는 산길', dungeon1: '경주 폐가 · 1층', dungeon2: '경주 폐가 · 2층' };
function loadLevel(id, spawn, keepPlayer = true) {
  const lvl = new Level(id);
  const p = keepPlayer && G.player ? G.player : new Player(0, 0);
  lvl.placePlayer(spawn, p);
  G.player = p;
  G.level = lvl;
  G.encounter = { active: false, calm: 0, songUsed: false };
  G.banner = { text: LEVEL_NAMES[id], sub: id === 'village' ? '안전 지대' : '', t: 3 };
  playMusic(lvl.def.music);
  return lvl;
}
function checkpointSpawn() {
  return G.checkpoint === 'dungeon' ? ['dungeon1', 'entrance'] : ['village', 'start'];
}

let transitioning = false;
async function transition(to, spawn) {
  if (transitioning) return;
  transitioning = true;
  G.scriptLock++;
  G.fadeTarget = 1; sfx('door');
  await wait(0.35);
  loadLevel(to, spawn);
  const f = G.flags;
  if (to === 'dungeon1' && spawn === 'entrance') {
    f.entered_dungeon = 1;
    G.checkpoint = 'dungeon';
    G.player.sori = Math.max(G.player.sori, 60);
    saveGame();
    toast('체크포인트 — 폐가 입구 (기록 저장됨)', '#9fe8a0', 3);
  }
  if (to === 'dungeon2') f.reached_f2 = 1;
  if (to === 'village') { G.checkpoint = 'village'; saveGame(); }
  G.fadeTarget = 0;
  await wait(0.3);
  G.scriptLock--;
  transitioning = false;
  if (to === 'field') story.fieldTutorial();
}

async function onDeath(lvl) {
  G.scriptLock++;
  await wait(1.0);
  G.fadeTarget = 1;
  await wait(0.8);
  G.deathMsg = 2.4;
  await wait(1.6);
  const [id, spawn] = checkpointSpawn();
  G.stats.hp = G.stats.maxHp;
  G.flags.boss_fight = 0;
  const p = G.player;
  p.dead = false; p.sori = 100; p.sin = 0; p.invuln = 1; p.songT = 0; p.ultT = 0; p.shield = 0; p.state = 'idle';
  loadLevel(id, spawn);
  G.deathMsg = 0;
  G.fadeTarget = 0;
  toast(G.checkpoint === 'dungeon' ? '폐가 입구에서 다시 일어섰다' : '집에서 다시 눈을 떴다', '#c8c0b0', 3);
  await wait(0.4);
  G.scriptLock--;
}

G.hooks = {
  interact: (it, lvl) => { if (it.kind === 'exit') transition(it.obj.to, it.obj.spawn); else runScript(() => story.talk(it, lvl)); },
  exit: (ex) => {
    if (ex.to === 'field' && G.level.id === 'village' && !G.flags.q_main) {
      runScript(async () => {
        await say([{ n: '처용', t: '(먼저 촌주 박노인에게 관아의 공문 이야기를 들어 보자. 광장에 있을 것이다.)', p: 'cheoyong' }]);
        G.player.x -= 12;
      });
      return;
    }
    transition(ex.to, ex.spawn);
  },
  bossRoom: (lvl) => { if (!G.flags.boss_result) runScript(() => story.bossIntro(lvl)); },
  bossDefeated: (lvl, how) => runScript(() => story.bossDefeated(lvl, how)),
  death: (lvl) => onDeath(lvl),
  save: saveGame,
  finish: () => {
    saveGame();
    G.scene = 'title'; G.level = null; G.player = null; G.titleSel = 0; G.fadeTarget = 0; G.fade = 1;
    G.creditsShown = true;
    playMusic('title');
  },
};

let scriptDepth = 0;
async function runScript(fn) {
  if (scriptDepth > 0) return;
  scriptDepth++;
  try { await fn(); } catch (e) { showError(e); } finally { scriptDepth--; }
}

// ------------------------------------------------------------ title
G.titleSel = 0;
async function startNew() {
  initAudio();
  newGameState();
  G.player = null;
  G.scene = 'cutscene';
  await story.intro();
  G.scene = 'play';
  loadLevel('village', 'start', false);
  G.flags.intro_done = 1;
  saveGame();
  G.fade = 1; G.fadeTarget = 0;
  await wait(0.6);
  await say([
    { n: '처용', t: '(마을 광장의 촌주 박노인이 나를 찾는다고 했다. 먼저 집 앞의 난영에게 들렀다 가자.)', p: 'cheoyong' },
    G.touch ? '이동: 왼쪽 조이스틱 · 대화·조사: 가까이 가서 [베기] 버튼 · 일시정지·조작법: 오른쪽 위 ☰' : '이동: 방향키/WASD · 대화·조사: 가까이 가서 Z · 일시정지·조작법: ESC',
  ]);
}
async function continueGame() {
  const d = readSave();
  if (!d) return;
  initAudio();
  applySave(d);
  G.player = null;
  G.scene = 'play';
  const [id, spawn] = checkpointSpawn();
  loadLevel(id, spawn, false);
  G.player.sori = d.sori ?? 100;
  G.fade = 1; G.fadeTarget = 0;
}

function updateTitle() {
  const hasSave = !!readSave();
  const opts = ['새로 시작', '이어하기'];
  if (input.pressed('up') || input.pressed('down')) { G.titleSel = 1 - G.titleSel; sfx('blip'); }
  if (!hasSave) G.titleSel = 0;
  if (input.pressed('ok')) {
    initAudio();
    sfx('select');
    input.flush();
    if (G.titleSel === 0) runScript(startNew); else runScript(continueGame);
  }
  return opts;
}
function drawTitle() {
  ctx.setTransform(SCALE, 0, 0, SCALE, 0, 0);
  const t = G.time;
  const g = ctx.createLinearGradient(0, 0, 0, VIEW_H);
  g.addColorStop(0, '#04050c'); g.addColorStop(1, '#141a2c');
  ctx.fillStyle = g; ctx.fillRect(0, 0, VIEW_W, VIEW_H);
  const r = rng(12);
  for (let i = 0; i < 80; i++) { const x = r() * VIEW_W, y = r() * 140; ctx.fillStyle = Math.sin(t * 2 + i) > 0.8 ? '#fff' : '#6a7090'; ctx.fillRect(Math.floor(x), Math.floor(y), 1, 1); }
  ctx.fillStyle = 'rgba(240,230,190,0.1)'; ctx.beginPath(); ctx.arc(370, 60, 40, 0, Math.PI * 2); ctx.fill();
  ctx.fillStyle = '#efe6c4'; ctx.beginPath(); ctx.arc(370, 60, 18, 0, Math.PI * 2); ctx.fill();
  ctx.fillStyle = '#0c1018'; ctx.beginPath(); ctx.moveTo(0, 190); ctx.lineTo(120, 150); ctx.lineTo(240, 182); ctx.lineTo(360, 140); ctx.lineTo(480, 176); ctx.lineTo(480, 270); ctx.lineTo(0, 270); ctx.fill();
  ctx.globalAlpha = 0.6; ctx.drawImage(PROPS.cheomseongdae(), 360, 150); ctx.globalAlpha = 1;
  for (let x = -10; x < VIEW_W; x += 22) ctx.drawImage(PROPS.pine(), x + (x % 3) * 3, 206 + (x % 5));
  ctx.fillStyle = '#05070c'; ctx.fillRect(0, 250, VIEW_W, 20);
  // miasma
  for (let i = 0; i < 40; i++) { const x = (r() * VIEW_W + t * 8) % VIEW_W, y = 180 + r() * 90 - (t * 5 + r() * 50) % 50; ctx.fillStyle = `rgba(111,191,74,${0.05 + r() * 0.12})`; ctx.fillRect(Math.floor(x), Math.floor(y), 5, 3); }
  // hero silhouette
  const s = SPR.player.down[0];
  ctx.drawImage(s, 100, 196, s.width * 3, s.height * 3);
  ctx.setTransform(1, 0, 0, 1, 0, 0);
  finishTitle(ctx);
  ctx.textAlign = 'center';
  ctx.font = font(20, false, true); ctx.fillStyle = C.gold; ctx.fillText('新 處容歌', W / 2, 92);
  ctx.font = font(64, true, true); ctx.fillStyle = '#05060a'; ctx.fillText('신 처용가', W / 2 + 3, 163);
  ctx.fillStyle = '#efe4c4'; ctx.fillText('신 처용가', W / 2, 160);
  ctx.font = font(18, false, true); ctx.fillStyle = '#b8b0a0'; ctx.fillText('제1장 · 처용가', W / 2, 196);
  const hasSave = !!readSave();
  ['새로 시작', '이어하기'].forEach((o, i) => {
    const dis = i === 1 && !hasSave;
    const sel = G.titleSel === i;
    ctx.font = font(22, sel); ctx.fillStyle = dis ? '#4a4a58' : sel ? '#fff0c0' : '#a8a090';
    ctx.fillText((sel ? '▶ ' : '') + o + (sel ? ' ◀' : ''), W / 2, 268 + i * 38);
  });
  ctx.font = font(13); ctx.fillStyle = '#7a8090';
  ctx.fillText(G.touch ? '메뉴를 눌러 선택 · 왼쪽 조이스틱 이동 · 오른쪽 버튼으로 베기·구르기·부적·처용가·처용무·영약 · ☰ 일시정지'
    : 'Z/Enter 선택 · 방향키 이동 · Z 베기 · Shift/Space 구르기 · X/C 부적 · V 처용가 · F 처용무 · 1/2/3 영약 · M 소리 끄기', W / 2, H - 46);
  ctx.fillStyle = '#5a6070';
  ctx.fillText('본 게임은 삼국유사의 처용 설화를 재해석한 픽션입니다.', W / 2, H - 22);
  if (G.creditsShown) { ctx.fillStyle = C.gold; ctx.fillText('제1장 완료 — 이어하기로 마을을 다시 둘러볼 수 있습니다', W / 2, 360); }
  ctx.textAlign = 'left';
}

// ------------------------------------------------------------ pause menu
async function pauseMenu() {
  const r = await choose(null, ['계속하기', '조작법', '타이틀로 (마지막 체크포인트 기록 유지)'], { title: '일시정지' });
  if (r === 1) {
    await say(G.touch ? [
      '이동: 왼쪽 아래를 누른 채 끌기 (조이스틱) · 대화·조사: [베기] 버튼 · 대화 넘기기·메뉴 선택: 화면을 누르기',
      '[베기] 연타 3단 콤보 · 길게 눌렀다 떼면 강 베기 (원형 범위, 200%)',
      '[구르기] 0.4초 무적. 공격 직전에 구르면 받아넘기기 — 1초 슬로우 + 다음 베기 200%. 3연속이면 신명 고조.',
      '[전환]/[발동] 부적 — 화염부(25), 결박부(30), 수호부(20). 소리는 자동으로 찬다.',
      '[처용가] 교전마다 1회 · [처용무] 신명 100일 때 · [인삼]/[구기자]/[정화부] 영약 · ♪ 소리 끄기 · 상점은 한 번 눌러 설명, 다시 눌러 구매',
    ] : [
      '이동: 방향키/WASD · 대화·조사: Z',
      '피리 베기: Z 연타 (3타째 넉백) · 강 베기: Z를 길게 눌렀다 떼기 (원형 범위, 200%)',
      '춤 구르기: Shift/Space (0.4초 무적). 공격 직전에 구르면 받아넘기기 — 1초 슬로우 + 다음 베기 200%. 3연속이면 신명 고조.',
      '부적: X 전환 / C 발동 — 화염부(25), 결박부(30), 수호부(20). 소리는 자동으로 찬다.',
      'V 처용가: 교전마다 1회, 10초 공격력 +30% · F 처용무: 신명 100일 때, 6초 무적 난무 · 1/2/3: 인삼정기탕/구기자환/정화부',
    ]);
  } else if (r === 2) {
    G.scene = 'title'; G.level = null; G.player = null; playMusic('title');
  }
}

// ------------------------------------------------------------ main loop
const STEP = 1 / 60;
let acc = 0, last = performance.now();

function update(dt) {
  pollInput();
  G.time += dt;
  for (const tm of G.timers.slice()) {
    tm.t -= dt;
    if (tm.t <= 0) { G.timers.splice(G.timers.indexOf(tm), 1); tm.res(); }
  }
  G.fade += (G.fadeTarget - G.fade) * Math.min(1, dt * 8);
  if (Math.abs(G.fade - G.fadeTarget) < 0.01) G.fade = G.fadeTarget;
  G.shake = Math.max(0, G.shake - dt * 12);
  if (input.pressed('mute')) { const m = toggleMute(); toast(m ? '소리 끔' : '소리 켬', '#c8c0b0', 1); }

  if (G.cutscene) { story.updateCutscene(dt); return; }
  if (G.menu) { updateMenu(); return; }
  if (G.dialog) { updateDialog(dt); return; }
  if (G.scene === 'title') { if (!scriptDepth) updateTitle(); return; }
  if (G.scene === 'play' && G.level) {
    if (input.pressed('menu') && !G.scriptLock && !scriptDepth) { input.flush(); runScript(pauseMenu); return; }
    let sdt = dt;
    if (G.slowT > 0) { G.slowT -= dt; sdt = dt * 0.3; }
    G.level.update(sdt);
  }
  if (G.deathMsg) G.deathMsg -= dt;
}

function render(dt) {
  ctx.setTransform(1, 0, 0, 1, 0, 0);
  if (G.cutscene) { story.drawCutscene(ctx); }
  else if (G.scene === 'title') drawTitle();
  else if (G.level) {
    const t0 = performance.now();
    G.level.render(ctx);
    trackRender(performance.now() - t0);
    if (G.slowT > 0) { ctx.fillStyle = 'rgba(200,220,255,0.08)'; ctx.fillRect(0, 0, W, H); }
    drawWorldText(ctx, G.level);
    drawHUD(ctx, G.level);
  } else { ctx.fillStyle = '#000'; ctx.fillRect(0, 0, W, H); }
  if (!G.cutscene) drawToasts(ctx, dt);
  drawMenu(ctx);
  drawDialog(ctx);
  if (G.fade > 0) { ctx.fillStyle = `rgba(0,0,0,${G.fade})`; ctx.fillRect(0, 0, W, H); }
  if (G.deathMsg > 0) {
    ctx.textAlign = 'center'; ctx.font = font(30, true, true); ctx.fillStyle = '#c84a3a';
    ctx.fillText('처용이 쓰러졌다…', W / 2, H / 2); ctx.font = font(16); ctx.fillStyle = '#a8a090';
    ctx.fillText('마지막 체크포인트에서 다시 일어선다', W / 2, H / 2 + 34); ctx.textAlign = 'left';
  }
}

function frame(now) {
  let dt = (now - last) / 1000; last = now;
  if (dt > 0.1) dt = 0.1;
  acc += dt;
  let steps = 0;
  try {
    while (acc >= STEP && steps < 6) { update(STEP); acc -= STEP; steps++; }
    if (steps >= 6) acc = 0;
    render(dt);
    syncTouch();
  } catch (e) { showError(e); }
  requestAnimationFrame(frame);
}

function showError(e) {
  console.error(e);
  const el = document.getElementById('err');
  if (el && G.debug) el.textContent = String(e && e.stack || e);
}

function fit() {
  const s = Math.min(window.innerWidth / W, window.innerHeight / H);
  // integer scaling when possible keeps pixels crisp
  const k = s >= 1 ? Math.floor(s * 2) / 2 : s;
  canvas.style.width = `${Math.floor(W * k)}px`;
  canvas.style.height = `${Math.floor(H * k)}px`;
}

function boot() {
  buildSprites();
  SPR.cheoyong = SPR.player.down[0];
  const mk = (human) => { const [c, g] = makeCanvas(36, 48); drawBoss(g, 18, 46, 0, { human }); return c; };
  SPR.yeoksin = mk(false); SPR.yeoksinHuman = mk(true);
  initInput(canvas);
  initTouch(canvas, () => !!readSave());
  onAnyKey(() => initAudio());
  window.addEventListener('resize', fit); fit();
  canvas.addEventListener('mousedown', () => { canvas.focus(); initAudio(); });
  const params = new URLSearchParams(location.search);
  G.debug = params.has('debug');
  // ?fx=0|1|2 forces a visual quality tier (2 = full HD-2D passes) and disables auto-downgrade
  if (params.has('fx')) { FX.quality = Math.max(0, Math.min(2, +params.get('fx') || 0)); FX.auto = false; }
  if (G.debug) installDebug();
  requestAnimationFrame((t) => { last = t; requestAnimationFrame(frame); });
}

// ------------------------------------------------------------ debug hooks (?debug=1)
function installDebug() {
  window.__dbg = {
    G, saveGame, readSave, loadLevel, transition, input, render, FX,
    state: () => ({
      scene: G.scene, level: G.level && G.level.id, x: G.player && Math.round(G.player.x), y: G.player && Math.round(G.player.y),
      hp: G.stats && G.stats.hp, lv: G.stats && G.stats.lv, money: G.stats && G.stats.money, flags: G.flags,
      dialog: !!G.dialog, menu: !!G.menu, cutscene: !!G.cutscene, lock: G.scriptLock,
      enemies: G.level ? G.level.enemies.filter((e) => !e.dead).length : 0,
      boss: G.level && G.level.boss ? { hp: Math.round(G.level.boss.hp), pur: Math.round(G.level.boss.pur), state: G.level.boss.state, phase: G.level.boss.phase, dead: G.level.boss.dead } : null,
      depth: scriptDepth, timers: G.timers.length, checkpoint: G.checkpoint, sori: G.player && Math.round(G.player.sori), sin: G.player && Math.round(G.player.sin),
    }),
    tp: (x, y) => { G.player.x = x; G.player.y = y; G.level.updateCamera(true); },
    tpTile: (tx, ty) => { G.player.x = tx * TS + 8; G.player.y = ty * TS + 12; G.level.updateCamera(true); },
    god: (v = true) => { G.god = v; },
    killAll: () => { for (const e of G.level.enemies) if (!e.dead) e.kill(G.level); },
    nearest: () => {
      const p = G.player; let best = null, bd = 1e9;
      for (const e of G.level.allTargets()) { const d = Math.hypot(e.x - p.x, e.y - p.y); if (d < bd) { bd = d; best = e; } }
      return best ? { x: best.x, y: best.y, kind: best.kind || (best.isClone ? 'clone' : '?'), d: bd } : null;
    },
    interactables: () => G.level.interactables().map((i) => ({ kind: i.kind, label: i.label, x: Math.round(i.x), y: Math.round(i.y) })),
  };
}

window.addEventListener('error', (e) => showError(e.error || e.message));
window.addEventListener('unhandledrejection', (e) => showError(e.reason));
boot();
