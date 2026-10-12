// All art is drawn in code: characters come from the shading painter (chars.js / paint.js),
// tiles and large props are drawn procedurally here. No external image assets.
import { human, humanSet, CHEOYONG, plagueDog, ghoul, plagueGod, portrait, plagueGodPortrait } from './chars.js';

export const C = {
  ink: '#0b0c14', ink2: '#1a1b26', ink3: '#272836',
  navy: '#1b2547', navy2: '#111833', navyL: '#2c3d70',
  gold: '#b8964a', goldD: '#7a6128', goldL: '#e0c070',
  plague: '#6fbf4a', plagueL: '#b6ff6a', plagueD: '#2f5a22',
  skin: '#e0b48a', skinD: '#b5835e',
  white: '#e8e2d0', red: '#c0392b', redL: '#ff6a5a', blood: '#7a1a1a',
  grass: '#1f3326', grass2: '#26402d', grass3: '#182a1f',
  path: '#4a4033', path2: '#3d342a',
  stone: '#4b4d55', stone2: '#5d5f68', stone3: '#35363d',
  wood: '#5a3a22', wood2: '#3e2816',
  thatch: '#7a6a3e', thatch2: '#5e512d', thatch3: '#93814b',
  water: '#142a44', water2: '#1d3a5c',
};

// ---------- deterministic RNG ----------
export function rng(seed) {
  let s = seed >>> 0 || 1;
  return () => {
    s ^= s << 13; s >>>= 0; s ^= s >>> 17; s ^= s << 5; s >>>= 0;
    return s / 4294967296;
  };
}

export function makeCanvas(w, h) {
  const c = document.createElement('canvas');
  c.width = w; c.height = h;
  const ctx = c.getContext('2d');
  ctx.imageSmoothingEnabled = false;
  return [c, ctx];
}

// Build a sprite from rows of characters. Rows shorter than the widest are padded.
export function fromRows(rows, pal) {
  const w = Math.max(...rows.map((r) => r.length));
  const [c, ctx] = makeCanvas(w, rows.length);
  rows.forEach((row, y) => {
    for (let x = 0; x < row.length; x++) {
      const col = pal[row[x]];
      if (col) { ctx.fillStyle = col; ctx.fillRect(x, y, 1, 1); }
    }
  });
  return c;
}

export function flipH(src) {
  const [c, ctx] = makeCanvas(src.width, src.height);
  ctx.translate(src.width, 0); ctx.scale(-1, 1); ctx.drawImage(src, 0, 0);
  return c;
}

// Solid-color silhouette (used for hit flash and telegraph tint).
export function tint(src, color, alpha = 1) {
  const [c, ctx] = makeCanvas(src.width, src.height);
  ctx.drawImage(src, 0, 0);
  ctx.globalCompositeOperation = 'source-atop';
  ctx.globalAlpha = alpha;
  ctx.fillStyle = color;
  ctx.fillRect(0, 0, src.width, src.height);
  return c;
}

// ---------- characters (HD-2D painter: see chars.js) ----------
const NPC_SPECS = {
  elder: { head: 'boktu', robe: '#4a4a52', trim: '#6a5a3a', belt: '#5a4a32', beard: 'white', hair: '#8a8680', staff: true, outfit: 'longrobe', skin: '#b89880' },
  nanyeong: { head: 'bun', female: true, outfit: 'skirt', robe: '#5a2638', inner: '#d6c8aa', trim: '#b8923e', pin: true, skin: '#cfac98' },
  villager: { head: 'topknot', outfit: 'jeogori', robe: '#5e5444', pants: '#7a7262', trim: '#3a3226', skin: '#b48e74' },
  villager2: { head: 'scarf', female: true, outfit: 'skirt', robe: '#44465a', inner: '#7e705c', trim: '#6e6050', skin: '#c09c86' },
  villagerSick: { head: 'topknot', outfit: 'rags', robe: '#4e5444', pants: '#626454', trim: '#3a3a30', skin: '#a2a88a', sick: true },
  merchant: { head: 'bald', outfit: 'jeogori', robe: '#5e4430', pants: '#706048', trim: '#4a3a26', beard: 'short', skin: '#b08870' },
  king: { head: 'crown', robe: '#5e1a26', trim: '#c9a24a', belt: '#c9a24a', beard: 'long', outfit: 'longrobe' },
  dragonKing: { head: 'dragon', robe: '#1a4252', trim: '#c9a24a', belt: '#c9a24a', beard: 'white', hair: '#bcc4c0', skin: '#b4bca6', outfit: 'longrobe' },
  official: { head: 'boktu', robe: '#2a4430', trim: '#8a7a4a', belt: '#b8923e' },
  ghostChild: { head: 'child', child: true, outfit: 'jeogori', robe: '#c8c8d0', pants: '#a0a0b0', trim: '#8a8a9a', skin: '#d8dce8', ghost: true, mood: 'soft' },
};

// ---------- sprite registry ----------
export const SPR = {};
// dialogue portraits keyed like SPR (line.p)
export const PORTRAIT = {};

export function buildSprites() {
  SPR.player = humanSet(CHEOYONG);
  SPR.playerFlash = tint(SPR.player.down[0], '#ffffff');

  SPR.dog = [plagueDog(0), plagueDog(1)];
  SPR.dogL = SPR.dog.map(flipH);
  SPR.imp = [ghoul(0), ghoul(1)];
  for (const k of ['dog', 'dogL', 'imp']) {
    SPR[k + 'White'] = SPR[k].map((s) => tint(s, '#ffffff'));
    SPR[k + 'Red'] = SPR[k].map((s) => tint(s, '#ff4030', 0.55));
  }
  // purified forms (원래 모습): a calm brown dog and a little straw doll
  SPR.dogPure = tint(SPR.dog[0], '#c8b090', 0.6);
  SPR.impPure = tint(SPR.imp[0], '#e8d8a0', 0.7);

  for (const [k, o] of Object.entries(NPC_SPECS)) SPR[k] = human(o, 'down', 0);
  SPR.nanyeongSpirit = tint(SPR.nanyeong, '#a0e0ff', 0.45);
  SPR.ghostChild = tint(SPR.ghostChild, '#9fd8ff', 0.35);

  for (const [k, o] of Object.entries(NPC_SPECS)) PORTRAIT[k] = portrait(o);
  PORTRAIT.cheoyong = portrait({ ...CHEOYONG, trim: CHEOYONG.trim });
  PORTRAIT.nanyeongSpirit = tint(PORTRAIT.nanyeong, '#a0e0ff', 0.4);
  PORTRAIT.ghostChild = tint(PORTRAIT.ghostChild, '#9fd8ff', 0.3);
  PORTRAIT.yeoksin = plagueGodPortrait();
  PORTRAIT.yeoksinHuman = portrait({ head: 'long', hair: '#121018', robe: '#9a9080', inner: '#cfc8b8', skin: '#cdbca4', mood: 'sinister' });
}

// ---------- 역신 (boss): pre-rendered sway frames ----------
// opt: { tele, human, flash, alpha }
const BOSS_FRAMES = 8;
const bossCache = new Map();
function bossFrame(variant, i) {
  const k = variant + i;
  let c = bossCache.get(k);
  if (!c) { c = plagueGod(variant, i / BOSS_FRAMES); bossCache.set(k, c); }
  return c;
}
const bossFlash = new Map();
export function drawBoss(ctx, x, y, t, opt = {}) {
  const human = opt.human;
  const variant = human ? 'human' : opt.tele ? 'tele' : 'idle';
  const i = ((Math.floor((t * 2 / (Math.PI * 2)) * BOSS_FRAMES) % BOSS_FRAMES) + BOSS_FRAMES) % BOSS_FRAMES;
  let img = bossFrame(variant, i);
  if (opt.flash) { let f = bossFlash.get(img); if (!f) { f = tint(img, '#ffffff', 0.8); bossFlash.set(img, f); } img = f; }
  ctx.save();
  ctx.globalAlpha = opt.alpha ?? 1;
  const bx = Math.round(x - img.width / 2), by = Math.round(y - img.height + 2);
  // miasma motes orbiting the body
  if (!human) {
    for (let j = 0; j < 7; j++) {
      const a = t * 1.3 + j * 0.9;
      ctx.fillStyle = j % 2 ? 'rgba(111,191,74,0.22)' : 'rgba(182,255,106,0.16)';
      ctx.fillRect(Math.round(x + Math.cos(a) * 17 - 2), Math.round(y - 30 + Math.sin(a * 1.4) * 14 - 2), 4, 4);
    }
  }
  ctx.drawImage(img, bx, by);
  ctx.restore();
}

// ---------- tiles ----------
export const T = {
  GRASS: 0, GRASS2: 1, PATH: 2, WATER: 3, FLOOR: 4, WALL: 5, VOID: 6, VENT: 7,
  FENCE: 8, ROCK: 9, PLAZA: 10, BOSSFLOOR: 11, STAIRS: 12, TREE: 13, BLOCK: 14, MAT: 15,
};
export const SOLID = new Set([T.WATER, T.WALL, T.VOID, T.FENCE, T.ROCK, T.TREE, T.BLOCK]);

const tileCache = new Map();
function tileVariant(id, v, wallFace) {
  const key = id * 100 + v * 2 + (wallFace ? 1 : 0);
  if (tileCache.has(key)) return tileCache.get(key);
  const [c, ctx] = makeCanvas(16, 16);
  const r = rng(id * 977 + v * 131 + 7);
  const speck = (cols, n) => {
    for (let i = 0; i < n; i++) { ctx.fillStyle = cols[Math.floor(r() * cols.length)]; ctx.fillRect(Math.floor(r() * 16), Math.floor(r() * 16), 1, 1); }
  };
  switch (id) {
    case T.GRASS: case T.TREE: case T.BLOCK:
      ctx.fillStyle = C.grass; ctx.fillRect(0, 0, 16, 16);
      speck([C.grass2, C.grass3], 14);
      if (v === 1) { ctx.fillStyle = '#2e4a33'; ctx.fillRect(4, 9, 1, 3); ctx.fillRect(6, 8, 1, 4); ctx.fillRect(8, 10, 1, 2); }
      if (v === 2) { ctx.fillStyle = '#6a6a3a'; ctx.fillRect(10, 5, 1, 1); ctx.fillStyle = '#8a7ab0'; ctx.fillRect(3, 11, 1, 1); }
      break;
    case T.GRASS2:
      ctx.fillStyle = C.grass3; ctx.fillRect(0, 0, 16, 16);
      speck([C.grass, '#14231a'], 18);
      break;
    case T.PATH:
      ctx.fillStyle = C.path; ctx.fillRect(0, 0, 16, 16);
      speck([C.path2, '#57493a', '#3a3128'], 22);
      if (v === 1) { ctx.fillStyle = '#5e5446'; ctx.fillRect(5, 6, 3, 2); }
      break;
    case T.PLAZA:
      ctx.fillStyle = '#45433f'; ctx.fillRect(0, 0, 16, 16);
      ctx.fillStyle = '#383632';
      ctx.fillRect(0, 7, 16, 1); ctx.fillRect(v ? 4 : 10, 0, 1, 7); ctx.fillRect(v ? 12 : 6, 8, 1, 8);
      speck(['#4e4c47', '#3c3a36'], 8);
      break;
    case T.WATER:
      ctx.fillStyle = C.water; ctx.fillRect(0, 0, 16, 16);
      ctx.fillStyle = C.water2; ctx.fillRect(2 + v * 3, 4, 5, 1); ctx.fillRect(8 - v * 2, 11, 6, 1);
      break;
    case T.FLOOR: case T.MAT:
      ctx.fillStyle = id === T.MAT ? '#4a3a2a' : '#3a2e24'; ctx.fillRect(0, 0, 16, 16);
      ctx.fillStyle = '#2a2018';
      ctx.fillRect(0, 0, 16, 1); ctx.fillRect(0, 8, 16, 1);
      ctx.fillRect(v ? 5 : 11, 1, 1, 7); ctx.fillRect(v ? 13 : 3, 9, 1, 7);
      speck(['#44372b', '#2f251c'], 10);
      if (v === 2) { ctx.fillStyle = 'rgba(111,191,74,0.25)'; ctx.fillRect(3, 3, 6, 4); }
      break;
    case T.BOSSFLOOR:
      ctx.fillStyle = '#2a2c30'; ctx.fillRect(0, 0, 16, 16);
      ctx.fillStyle = '#1e1f23'; ctx.fillRect(0, 15, 16, 1); ctx.fillRect(15, 0, 1, 16);
      speck(['#33363b', '#24262a'], 10);
      if (v === 1) { ctx.fillStyle = 'rgba(111,191,74,0.18)'; ctx.fillRect(2, 2, 12, 12); }
      break;
    case T.WALL:
      if (wallFace) {
        ctx.fillStyle = '#4a3a2c'; ctx.fillRect(0, 0, 16, 16);
        ctx.fillStyle = '#5a4836'; for (let x = 0; x < 16; x += 4) ctx.fillRect(x, 2, 2, 12);
        ctx.fillStyle = '#2a2018'; ctx.fillRect(0, 0, 16, 2); ctx.fillRect(0, 14, 16, 2);
        if (v === 1) { ctx.fillStyle = '#1a140e'; ctx.fillRect(6, 5, 4, 6); }
      } else {
        ctx.fillStyle = '#15120f'; ctx.fillRect(0, 0, 16, 16);
        speck(['#1d1915', '#100d0a'], 10);
      }
      break;
    case T.VOID:
      ctx.fillStyle = '#05060a'; ctx.fillRect(0, 0, 16, 16);
      break;
    case T.VENT:
      ctx.fillStyle = '#3a2e24'; ctx.fillRect(0, 0, 16, 16);
      ctx.fillStyle = '#1a1612'; ctx.fillRect(3, 3, 10, 10);
      ctx.fillStyle = '#2f5a22'; ctx.fillRect(5, 5, 6, 6);
      ctx.fillStyle = '#0d0b08'; for (let i = 4; i < 13; i += 3) ctx.fillRect(i, 3, 1, 10);
      break;
    case T.FENCE:
      ctx.fillStyle = C.grass; ctx.fillRect(0, 0, 16, 16); speck([C.grass2], 8);
      ctx.fillStyle = C.wood2; ctx.fillRect(0, 5, 16, 2); ctx.fillRect(0, 10, 16, 2);
      ctx.fillStyle = C.wood; ctx.fillRect(2, 2, 3, 13); ctx.fillRect(11, 2, 3, 13);
      ctx.fillStyle = C.ink; ctx.fillRect(2, 15, 3, 1); ctx.fillRect(11, 15, 3, 1);
      break;
    case T.ROCK:
      ctx.fillStyle = C.grass; ctx.fillRect(0, 0, 16, 16);
      ctx.fillStyle = C.ink; ctx.fillRect(1, 4, 14, 11);
      ctx.fillStyle = C.stone; ctx.fillRect(2, 4, 12, 10);
      ctx.fillStyle = C.stone2; ctx.fillRect(3, 5, 7, 4);
      ctx.fillStyle = C.stone3; ctx.fillRect(2, 12, 12, 2);
      break;
    case T.STAIRS:
      ctx.fillStyle = '#1a140e'; ctx.fillRect(0, 0, 16, 16);
      for (let i = 0; i < 4; i++) { ctx.fillStyle = i % 2 ? '#5a4836' : '#4a3a2c'; ctx.fillRect(1, 1 + i * 4, 14, 3); }
      ctx.fillStyle = C.gold; ctx.fillRect(7, 0, 2, 1);
      break;
  }
  tileCache.set(key, c);
  return c;
}
export function getTile(id, x, y, wallFace) {
  const h = ((x * 73856093) ^ (y * 19349663)) >>> 0;
  let v = 0;
  if (id === T.GRASS || id === T.TREE || id === T.BLOCK) v = h % 11 === 0 ? 1 : h % 17 === 0 ? 2 : 0;
  else if (id === T.FLOOR) v = h % 13 === 0 ? 2 : h % 2;
  else if (id === T.WALL) v = h % 9 === 0 ? 1 : 0;
  else v = h % 2;
  return tileVariant(id, v, wallFace);
}

// ---------- props (large objects) ----------
const propCache = new Map();
function cached(key, w, h, draw) {
  if (propCache.has(key)) return propCache.get(key);
  const [c, ctx] = makeCanvas(w, h);
  draw(ctx, w, h);
  propCache.set(key, c);
  return c;
}

// Each prop: canvas + anchor (ax, ay) = feet point within the canvas, plus footprint
// in tiles for collision (handled in world.js).
export const PROPS = {
  pine: () => cached('pine', 32, 48, (g) => {
    g.fillStyle = C.ink; g.fillRect(13, 30, 6, 16);
    g.fillStyle = '#4a3020'; g.fillRect(14, 30, 4, 16);
    g.fillStyle = '#3a2418'; g.fillRect(15, 34, 1, 10);
    const layers = [[16, 4, 6], [16, 10, 10], [16, 17, 13], [16, 24, 15]];
    for (const [cx, cy, hw] of layers) {
      g.fillStyle = C.ink; g.beginPath(); g.moveTo(cx, cy - 6); g.lineTo(cx + hw + 1, cy + 7); g.lineTo(cx - hw - 1, cy + 7); g.fill();
      g.fillStyle = '#1f3d2a'; g.beginPath(); g.moveTo(cx, cy - 5); g.lineTo(cx + hw, cy + 6); g.lineTo(cx - hw, cy + 6); g.fill();
      g.fillStyle = '#2b5236'; g.fillRect(cx - 3, cy, 4, 2); g.fillRect(cx + 2, cy + 3, 5, 1);
    }
  }),
  pineDead: () => cached('pineDead', 32, 48, (g) => {
    g.fillStyle = C.ink; g.fillRect(13, 14, 6, 32);
    g.fillStyle = '#3a2a20'; g.fillRect(14, 14, 4, 32);
    g.fillRect(6, 20, 8, 2); g.fillRect(18, 26, 9, 2); g.fillRect(8, 32, 6, 2); g.fillRect(17, 16, 6, 2);
    g.fillStyle = '#2f5a22'; g.fillRect(5, 19, 2, 2); g.fillRect(25, 25, 2, 2);
  }),
  house: () => cached('house', 64, 56, (g) => { // 초가 (thatched commoner house)
    // earthen walls
    g.fillStyle = C.ink; g.fillRect(5, 26, 54, 28);
    g.fillStyle = '#7a6650'; g.fillRect(6, 27, 52, 26);
    g.fillStyle = '#6a5642'; for (let x = 8; x < 58; x += 12) g.fillRect(x, 27, 2, 26);
    g.fillStyle = C.wood2; g.fillRect(6, 50, 52, 3);
    // door + window (paper)
    g.fillStyle = C.ink; g.fillRect(26, 34, 12, 19);
    g.fillStyle = C.wood; g.fillRect(27, 35, 10, 18);
    g.fillStyle = '#d8c89a'; g.fillRect(29, 37, 6, 7);
    g.fillStyle = '#c8a860'; g.fillRect(11, 34, 8, 7); g.fillRect(45, 34, 8, 7);
    g.fillStyle = C.wood2; g.fillRect(15, 34, 1, 7); g.fillRect(49, 34, 1, 7);
    // thatched roof: rounded mound
    g.fillStyle = C.ink;
    g.beginPath(); g.ellipse(32, 24, 33, 18, 0, Math.PI, 0); g.lineTo(65, 30); g.lineTo(-1, 30); g.fill();
    g.fillStyle = C.thatch2;
    g.beginPath(); g.ellipse(32, 24, 31, 16, 0, Math.PI, 0); g.lineTo(63, 29); g.lineTo(1, 29); g.fill();
    g.fillStyle = C.thatch;
    g.beginPath(); g.ellipse(32, 22, 27, 12, 0, Math.PI, 0); g.fill();
    g.fillStyle = C.thatch3;
    for (let i = 0; i < 14; i++) g.fillRect(6 + i * 4, 18 + (i % 3), 1, 8);
    g.fillStyle = '#4a3f22'; g.fillRect(1, 28, 62, 2);
    // straw rope lines
    g.fillStyle = '#4e4428'; g.fillRect(14, 10, 1, 18); g.fillRect(32, 7, 1, 21); g.fillRect(50, 10, 1, 18);
  }),
  stall: () => cached('stall', 48, 44, (g) => { // 약방 노점
    g.fillStyle = C.ink; g.fillRect(3, 12, 3, 32); g.fillRect(42, 12, 3, 32);
    g.fillStyle = C.wood; g.fillRect(4, 12, 1, 32); g.fillRect(43, 12, 1, 32);
    // cloth awning (faded indigo)
    g.fillStyle = C.ink; g.fillRect(0, 6, 48, 10);
    g.fillStyle = '#2c3d70'; g.fillRect(1, 7, 46, 8);
    g.fillStyle = '#3a4d88'; for (let x = 1; x < 47; x += 6) g.fillRect(x, 7, 3, 8);
    g.fillStyle = '#2c3d70'; for (let x = 1; x < 47; x += 6) g.fillRect(x + 1, 15, 3, 2);
    // counter with jars and herb bundles
    g.fillStyle = C.ink; g.fillRect(2, 30, 44, 12);
    g.fillStyle = C.wood; g.fillRect(3, 31, 42, 10);
    g.fillStyle = C.wood2; g.fillRect(3, 36, 42, 1);
    const jar = (x) => { g.fillStyle = C.ink; g.fillRect(x, 23, 7, 8); g.fillStyle = '#6a6a72'; g.fillRect(x + 1, 24, 5, 6); g.fillStyle = '#8a8a92'; g.fillRect(x + 2, 25, 1, 3); };
    jar(6); jar(30);
    g.fillStyle = '#5a7a3a'; g.fillRect(16, 25, 4, 6); g.fillStyle = '#c9a64a'; g.fillRect(22, 24, 5, 7);
    g.fillStyle = C.red; g.fillRect(23, 26, 3, 3);
  }),
  board: () => cached('board', 36, 34, (g) => { // 의뢰 게시판
    g.fillStyle = C.ink; g.fillRect(4, 8, 4, 26); g.fillRect(28, 8, 4, 26);
    g.fillStyle = C.wood; g.fillRect(5, 8, 2, 26); g.fillRect(29, 8, 2, 26);
    g.fillStyle = C.ink; g.fillRect(1, 2, 34, 22);
    g.fillStyle = '#6a4a2c'; g.fillRect(2, 3, 32, 20);
    g.fillStyle = '#4a3420'; g.fillRect(2, 3, 32, 2);
    const note = (x, y, w, h, seal) => {
      g.fillStyle = '#d8ccaa'; g.fillRect(x, y, w, h);
      g.fillStyle = '#5a5040'; for (let yy = y + 2; yy < y + h - 1; yy += 2) g.fillRect(x + 1, yy, w - 2, 1);
      if (seal) { g.fillStyle = C.red; g.fillRect(x + w - 3, y + h - 3, 2, 2); }
    };
    note(5, 6, 8, 11, true); note(15, 7, 7, 9, false); note(24, 6, 8, 12, true);
  }),
  cheomseongdae: () => cached('cheom', 44, 84, (g) => { // 첨성대
    // base platform
    g.fillStyle = C.ink; g.fillRect(2, 72, 40, 12);
    g.fillStyle = '#6a6458'; g.fillRect(3, 73, 38, 5); g.fillStyle = '#56504a'; g.fillRect(3, 78, 38, 5);
    // bottle body: profile widens toward bottom
    for (let y = 14; y < 72; y++) {
      const t = (y - 14) / 58;
      const hw = Math.round(9 + 9 * Math.pow(t, 1.6));
      g.fillStyle = C.ink; g.fillRect(22 - hw - 1, y, hw * 2 + 2, 1);
      g.fillStyle = (Math.floor(y / 3) % 2) ? '#8a8272' : '#7a7262';
      g.fillRect(22 - hw, y, hw * 2, 1);
      if (y % 3 === 0) { g.fillStyle = '#5a5448'; g.fillRect(22 - hw, y, hw * 2, 1); }
    }
    // stone block seams
    g.fillStyle = '#625c50';
    for (let y = 15; y < 72; y += 6) for (let x = 6 + (y % 12 ? 3 : 0); x < 38; x += 6) g.fillRect(x, y, 1, 3);
    // south window
    g.fillStyle = C.ink; g.fillRect(17, 38, 10, 10);
    g.fillStyle = '#0a0a10'; g.fillRect(18, 39, 8, 8);
    // 정자석 top frame (井)
    g.fillStyle = C.ink; g.fillRect(9, 5, 26, 10);
    g.fillStyle = '#8a8272'; g.fillRect(10, 6, 24, 3); g.fillRect(10, 11, 24, 3);
    g.fillStyle = '#6a6458'; g.fillRect(12, 9, 3, 2); g.fillRect(29, 9, 3, 2);
  }),
  pagoda: () => cached('pagoda', 40, 60, (g) => { // 모전석탑풍 3층 석탑
    const tier = (y, w, h) => {
      g.fillStyle = C.ink; g.fillRect(20 - w / 2 - 1, y - 1, w + 2, h + 2);
      g.fillStyle = '#5e5a54'; g.fillRect(20 - w / 2, y, w, h);
      g.fillStyle = '#4e4a44'; for (let yy = y + 2; yy < y + h; yy += 3) g.fillRect(20 - w / 2, yy, w, 1);
      g.fillStyle = '#6e6a62'; for (let yy = y + 1; yy < y + h; yy += 6) for (let x = 20 - w / 2 + 2; x < 20 + w / 2; x += 5) g.fillRect(x, yy, 1, 2);
    };
    const roof = (y, w) => {
      g.fillStyle = C.ink; g.fillRect(20 - w / 2 - 1, y - 1, w + 2, 5);
      g.fillStyle = '#4a4640'; g.fillRect(20 - w / 2, y, w, 2);
      g.fillStyle = '#3a3630'; g.fillRect(20 - w / 2 + 1, y + 2, w - 2, 2);
    };
    tier(44, 34, 14); roof(40, 38);
    tier(30, 26, 10); roof(26, 30);
    tier(18, 20, 8); roof(14, 24);
    g.fillStyle = C.ink; g.fillRect(17, 4, 6, 10);
    g.fillStyle = '#5e5a54'; g.fillRect(18, 5, 4, 9);
    g.fillStyle = C.goldD; g.fillRect(19, 1, 2, 4);
    // door niche on the bottom tier
    g.fillStyle = '#1a1a1e'; g.fillRect(17, 48, 6, 8);
  }),
  tumulus: () => cached('tumulus', 72, 36, (g) => { // 봉분 (목곽고분)
    g.fillStyle = C.ink; g.beginPath(); g.ellipse(36, 34, 36, 30, 0, Math.PI, 0); g.fill();
    g.fillStyle = '#28432f'; g.beginPath(); g.ellipse(36, 34, 35, 29, 0, Math.PI, 0); g.fill();
    g.fillStyle = '#30503a'; g.beginPath(); g.ellipse(32, 30, 26, 20, 0, Math.PI, 0); g.fill();
    g.fillStyle = '#3a5e44'; g.beginPath(); g.ellipse(28, 24, 14, 10, 0, Math.PI, 0); g.fill();
    g.fillStyle = '#1f3326'; for (let i = 0; i < 18; i++) g.fillRect(6 + i * 3.4, 30 - Math.abs(9 - i) * 1.1, 1, 2);
  }),
  lantern: () => cached('lantern', 14, 30, (g) => { // 석등
    g.fillStyle = C.ink; g.fillRect(3, 24, 8, 6); g.fillRect(5, 14, 4, 11); g.fillRect(1, 6, 12, 9); g.fillRect(2, 2, 10, 5);
    g.fillStyle = '#6a665e'; g.fillRect(4, 25, 6, 4); g.fillRect(6, 15, 2, 10); g.fillRect(2, 13, 10, 2);
    g.fillStyle = '#7a766c'; g.fillRect(3, 3, 8, 3); g.fillRect(6, 0, 2, 3);
    g.fillStyle = '#ffcf6a'; g.fillRect(3, 7, 8, 6);
    g.fillStyle = '#fff0b0'; g.fillRect(5, 8, 4, 4);
    g.fillStyle = '#6a665e'; g.fillRect(6, 7, 2, 6);
  }),
  pots: () => cached('pots', 24, 18, (g) => { // 신라 토기 (굽다리접시·항아리)
    g.fillStyle = C.ink; g.fillRect(1, 4, 10, 13); g.fillRect(13, 8, 10, 4); g.fillRect(16, 11, 4, 6);
    g.fillStyle = '#5a5c62'; g.fillRect(2, 5, 8, 11); g.fillStyle = '#6e7078'; g.fillRect(3, 6, 2, 6);
    g.fillStyle = '#44464c'; g.fillRect(2, 9, 8, 1); g.fillRect(2, 12, 8, 1);
    g.fillStyle = '#5a5c62'; g.fillRect(14, 9, 8, 2); g.fillRect(17, 11, 2, 5); g.fillRect(15, 15, 6, 2);
    g.fillStyle = C.ink; g.fillRect(4, 3, 4, 2);
  }),
  rubble: () => cached('rubble', 20, 12, (g) => {
    g.fillStyle = C.ink; g.fillRect(1, 5, 8, 6); g.fillRect(10, 3, 9, 8);
    g.fillStyle = '#4a3a2c'; g.fillRect(2, 6, 6, 4); g.fillStyle = '#5a4836'; g.fillRect(11, 4, 7, 6);
    g.fillStyle = C.wood2; g.fillRect(0, 9, 20, 2);
  }),
  brazier: () => cached('brazier', 12, 18, (g) => { // 등잔 받침
    g.fillStyle = C.ink; g.fillRect(4, 8, 4, 10); g.fillRect(1, 5, 10, 4);
    g.fillStyle = '#6a5a3a'; g.fillRect(5, 9, 2, 9); g.fillRect(2, 6, 8, 2);
    g.fillStyle = '#ffb040'; g.fillRect(4, 1, 4, 5); g.fillStyle = '#fff0b0'; g.fillRect(5, 2, 2, 3);
  }),
  chest: (open) => cached('chest' + (open ? 1 : 0), 18, 16, (g) => { // 나무 궤
    g.fillStyle = C.ink; g.fillRect(1, 4, 16, 12);
    g.fillStyle = C.wood; g.fillRect(2, 5, 14, 10);
    g.fillStyle = C.gold; g.fillRect(2, 9, 14, 1); g.fillRect(8, 8, 2, 3);
    if (open) { g.fillStyle = '#1a140e'; g.fillRect(2, 1, 14, 4); g.fillStyle = C.ink; g.fillRect(1, 0, 16, 1); }
    else { g.fillStyle = C.wood2; g.fillRect(2, 5, 14, 3); }
  }),
  gate: () => cached('gate', 64, 64, (g) => { // 폐가 대문 (무너진 나무 문)
    g.fillStyle = C.ink; g.fillRect(4, 14, 8, 50); g.fillRect(52, 14, 8, 50); g.fillRect(0, 8, 64, 10);
    g.fillStyle = '#4a3420'; g.fillRect(5, 14, 6, 50); g.fillRect(53, 14, 6, 50);
    g.fillStyle = '#3a2818'; g.fillRect(1, 9, 62, 8);
    g.fillStyle = '#2a1e12'; g.fillRect(1, 15, 62, 2);
    // broken door leaf hanging
    g.fillStyle = C.ink; g.fillRect(14, 20, 16, 40);
    g.fillStyle = '#3e2c1c'; g.fillRect(15, 21, 14, 38);
    g.fillStyle = '#2a1e12'; for (let y = 24; y < 58; y += 6) g.fillRect(15, y, 14, 1);
    // dark doorway
    g.fillStyle = '#05060a'; g.fillRect(31, 22, 20, 42);
    // talisman paper torn
    g.fillStyle = '#c9a64a'; g.fillRect(20, 30, 4, 9);
    g.fillStyle = C.red; g.fillRect(21, 32, 2, 4);
    // miasma drip
    g.fillStyle = 'rgba(111,191,74,0.5)'; g.fillRect(36, 30, 3, 20); g.fillRect(44, 40, 2, 16);
  }),
  sickbed: () => cached('sickbed', 28, 14, (g) => { // 거적 위 병자
    g.fillStyle = C.ink; g.fillRect(0, 4, 28, 10);
    g.fillStyle = '#6a5a3a'; g.fillRect(1, 5, 26, 8);
    g.fillStyle = '#5a5f4c'; g.fillRect(6, 6, 18, 6);
    g.fillStyle = '#b8c49a'; g.fillRect(2, 6, 5, 5);
    g.fillStyle = 'rgba(111,191,74,0.45)'; g.fillRect(2, 1, 6, 4);
  }),
  doll: () => cached('doll', 10, 12, (g) => { // 토우 (흙 인형)
    g.fillStyle = C.ink; g.fillRect(2, 0, 6, 12);
    g.fillStyle = '#a07a54'; g.fillRect(3, 1, 4, 4); g.fillRect(3, 5, 4, 6);
    g.fillStyle = C.ink; g.fillRect(4, 2, 1, 1); g.fillRect(6, 2, 1, 1);
    g.fillStyle = '#8a6444'; g.fillRect(1, 6, 2, 2); g.fillRect(7, 6, 2, 2);
  }),
  cobweb: () => cached('cobweb', 16, 16, (g) => {
    g.strokeStyle = 'rgba(200,200,210,0.35)'; g.lineWidth = 1;
    g.beginPath(); g.moveTo(0, 0); g.lineTo(15, 15); g.moveTo(0, 0); g.lineTo(15, 4); g.moveTo(0, 0); g.lineTo(4, 15);
    g.moveTo(8, 2); g.quadraticCurveTo(6, 6, 2, 8); g.moveTo(13, 4); g.quadraticCurveTo(10, 10, 4, 13); g.stroke();
  }),
  bones: () => cached('bones', 16, 10, (g) => {
    g.fillStyle = '#c8c0a8'; g.fillRect(1, 5, 9, 2); g.fillRect(0, 4, 2, 4); g.fillRect(9, 4, 2, 4);
    g.fillRect(11, 2, 4, 4); g.fillStyle = C.ink; g.fillRect(12, 3, 1, 1); g.fillRect(14, 3, 1, 1);
  }),
  screen: () => cached('screen', 40, 30, (g) => { // 낡은 병풍
    for (let i = 0; i < 4; i++) {
      g.fillStyle = C.ink; g.fillRect(i * 10, 2, 10, 28);
      g.fillStyle = '#8a7a5a'; g.fillRect(i * 10 + 1, 3, 8, 26);
      g.fillStyle = '#5a4a3a'; g.fillRect(i * 10 + 2, 6 + i * 3, 5, 2); g.fillRect(i * 10 + 3, 16, 3, 7);
    }
    g.fillStyle = 'rgba(111,191,74,0.3)'; g.fillRect(12, 18, 16, 8);
  }),
};

export const PROP_INFO = {
  pine: { ax: 16, ay: 46, foot: [1, 1] },
  pineDead: { ax: 16, ay: 46, foot: [1, 1] },
  house: { ax: 32, ay: 54, foot: [4, 2] },
  stall: { ax: 24, ay: 42, foot: [3, 1] },
  board: { ax: 18, ay: 32, foot: [2, 1] },
  cheomseongdae: { ax: 22, ay: 82, foot: [3, 1] },
  pagoda: { ax: 20, ay: 58, foot: [2, 1] },
  tumulus: { ax: 36, ay: 34, foot: [4, 1] },
  lantern: { ax: 7, ay: 29, foot: [1, 1] },
  pots: { ax: 12, ay: 17, foot: [1, 1] },
  rubble: { ax: 10, ay: 11, foot: [1, 1] },
  brazier: { ax: 6, ay: 17, foot: [1, 1] },
  chest: { ax: 9, ay: 15, foot: [1, 1] },
  gate: { ax: 32, ay: 63, foot: [0, 0] },
  sickbed: { ax: 14, ay: 13, foot: [2, 1] },
  doll: { ax: 5, ay: 11, foot: [0, 0] },
  cobweb: { ax: 0, ay: 0, foot: [0, 0], flat: true },
  bones: { ax: 8, ay: 9, foot: [0, 0], flat: true },
  screen: { ax: 20, ay: 29, foot: [2, 1] },
};

// Small HUD icons for talismans.
export function drawTalismanIcon(ctx, x, y, kind, s = 2) {
  const col = { fire: '#e05a2a', bind: '#4a8ad8', guard: '#d8c050', thunder: '#a080e0', charm: '#e080b0' }[kind];
  ctx.fillStyle = C.ink; ctx.fillRect(x, y, 10 * s, 14 * s);
  ctx.fillStyle = '#d8c89a'; ctx.fillRect(x + s, y + s, 8 * s, 12 * s);
  ctx.fillStyle = col;
  ctx.fillRect(x + 4 * s, y + 2 * s, 2 * s, 8 * s);
  ctx.fillRect(x + 2 * s, y + 4 * s, 6 * s, s);
  ctx.fillRect(x + 2 * s, y + 8 * s, 6 * s, s);
  ctx.fillRect(x + 3 * s, y + 11 * s, 4 * s, s);
}
