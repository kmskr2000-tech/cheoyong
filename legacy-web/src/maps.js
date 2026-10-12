// Level definitions. Maps are built in code with fixed seeds so they are identical
// on every load. Coordinates: tiles for layout, pixels (tile*16) for entities.
import { T, rng } from './gfx.js';

const TS = 16;
const px = (t) => t * TS + TS / 2;

class MapBuilder {
  constructor(w, h, fill) {
    this.w = w; this.h = h;
    this.tiles = new Array(w * h).fill(fill);
    this.props = []; this.npcs = []; this.enemies = []; this.exits = [];
    this.lights = []; this.spawns = {}; this.items = []; this.triggers = [];
  }
  get(x, y) { return (x < 0 || y < 0 || x >= this.w || y >= this.h) ? T.VOID : this.tiles[y * this.w + x]; }
  set(x, y, t) { if (x >= 0 && y >= 0 && x < this.w && y < this.h) this.tiles[y * this.w + x] = t; }
  rect(x0, y0, x1, y1, t) { for (let y = y0; y <= y1; y++) for (let x = x0; x <= x1; x++) this.set(x, y, t); }
  // thick line of tiles between two points (for paths)
  line(x0, y0, x1, y1, t, r = 1) {
    const n = Math.max(Math.abs(x1 - x0), Math.abs(y1 - y0)) || 1;
    for (let i = 0; i <= n; i++) {
      const x = Math.round(x0 + (x1 - x0) * i / n), y = Math.round(y0 + (y1 - y0) * i / n);
      this.rect(x - r + 1, y - r + 1, x + r - 1 + (r > 1 ? 0 : 0), y + r - 1, t);
    }
  }
  prop(type, tx, ty, extra = {}) { this.props.push({ type, tx, ty, ...extra }); }
  light(tx, ty, r = 60, color = '255,190,100', flicker = true) { this.lights.push({ x: px(tx), y: px(ty), r, color, flicker }); }
  room(x0, y0, x1, y1, floor = T.FLOOR) { this.rect(x0, y0, x1, y1, floor); }
  build(extra) {
    return {
      w: this.w, h: this.h, tiles: this.tiles, props: this.props, npcs: this.npcs,
      enemies: this.enemies, exits: this.exits, lights: this.lights, spawns: this.spawns,
      items: this.items, triggers: this.triggers, ...extra,
    };
  }
}

// ---------------- 마을: 경주 변두리 ----------------
function village() {
  const W = 46, H = 32;
  const m = new MapBuilder(W, H, T.GRASS);
  const r = rng(11);
  // dark grass patches
  for (let i = 0; i < 40; i++) { const x = Math.floor(r() * W), y = Math.floor(r() * H); m.rect(x, y, x + 1, y, T.GRASS2); }
  // main roads
  m.rect(15, 12, 29, 19, T.PLAZA);
  m.line(29, 15, 45, 15, T.PATH, 2);
  m.line(22, 12, 22, 6, T.PATH, 2);
  m.line(22, 6, 35, 6, T.PATH, 2);
  m.line(15, 16, 8, 16, T.PATH, 2);
  m.line(8, 16, 8, 13, T.PATH, 2);
  m.line(22, 19, 22, 25, T.PATH, 2);
  m.line(22, 25, 12, 25, T.PATH, 2);
  // pond (west-south)
  m.rect(2, 22, 6, 27, T.WATER); m.rect(3, 21, 5, 28, T.WATER);
  // border pines (leave east exit open around y 14-16)
  for (let x = 0; x < W; x++) {
    for (const y of [0, 1]) if (r() < 0.9) m.prop('pine', x, y + 1);
    if (r() < 0.85) m.prop('pine', x, H - 1);
  }
  for (let y = 2; y < H - 1; y++) {
    m.prop('pine', 0, y);
    if (y < 13 || y > 17) m.prop('pine', W - 1, y);
  }
  // scattered pines away from roads
  for (let i = 0; i < 26; i++) {
    const x = 2 + Math.floor(r() * (W - 4)), y = 3 + Math.floor(r() * (H - 6));
    if (m.get(x, y) === T.GRASS || m.get(x, y) === T.GRASS2) {
      let near = false;
      for (let dy = -2; dy <= 2; dy++) for (let dx = -2; dx <= 2; dx++) if ([T.PATH, T.PLAZA, T.WATER].includes(m.get(x + dx, y + dy))) near = true;
      if (!near && !(x > 28 && y > 20)) m.prop('pine', x, y);
    }
  }
  // houses (thatched). 처용의 집 west.
  m.prop('house', 5, 12, { id: 'home' });
  m.prop('house', 11, 8);
  m.prop('house', 26, 9);
  m.prop('house', 9, 21);
  m.prop('house', 16, 26);
  // fences around home yard
  for (let x = 3; x <= 11; x++) if (x < 7 || x > 9) m.set(x, 14, T.FENCE);
  m.rect(3, 9, 3, 13, T.FENCE);
  // plaza: board, stall, pagoda, lanterns
  m.prop('board', 17, 13, { id: 'board' });
  m.prop('stall', 25, 14, { id: 'shop' });
  m.prop('pagoda', 21, 17);
  m.prop('lantern', 16, 18); m.light(16, 17, 70);
  m.prop('lantern', 28, 18); m.light(28, 17, 70);
  m.prop('lantern', 30, 13); m.light(30, 12, 60);
  m.prop('lantern', 9, 15); m.light(9, 14, 60);
  m.prop('lantern', 40, 13); m.light(40, 12, 55);
  // 첨성대 landmark (north-east)
  m.prop('cheomseongdae', 36, 8);
  m.prop('lantern', 33, 8); m.light(33, 7, 60);
  // 봉분 (south-east)
  m.prop('tumulus', 33, 24); m.prop('tumulus', 39, 27); m.prop('tumulus', 41, 22);
  m.prop('pots', 13, 13); m.prop('pots', 28, 12);
  // sick villagers lying on mats
  m.prop('sickbed', 13, 11); m.prop('sickbed', 29, 11); m.prop('sickbed', 12, 24);
  // plague miasma hint near the east road
  m.triggers.push({ kind: 'miasmaDeco', x: px(42), y: px(15), r: 40 });

  m.npcs.push({ id: 'elder', sprite: 'elder', x: px(19) , y: px(15) + 6, name: '촌주 박노인' });
  m.npcs.push({ id: 'merchant', sprite: 'merchant', x: px(26), y: px(16) + 4, name: '약방 아낙의 남편 석구' });
  m.npcs.push({ id: 'nanyeong', sprite: 'nanyeong', x: px(7), y: px(13) + 4, name: '난영' });
  m.npcs.push({ id: 'villagerA', sprite: 'villager2', x: px(23), y: px(10), name: '마을 아낙' });
  m.npcs.push({ id: 'villagerB', sprite: 'villager', x: px(34), y: px(16) + 2, name: '나무꾼 돌쇠' });
  m.npcs.push({ id: 'villagerC', sprite: 'villagerSick', x: px(14), y: px(23), name: '기침하는 사내' });

  m.spawns.start = { x: px(8), y: px(15) + 4 };
  m.spawns.fromField = { x: px(43), y: px(15) };
  m.exits.push({ x: 45 * TS, y: 13 * TS, w: TS, h: 4 * TS, to: 'field', spawn: 'fromVillage', label: '산길' });
  return m.build({ id: 'village', name: '경주 변두리', dark: 0.42, music: 'village', safe: true, ambient: '#0b1430' });
}

// ---------------- 산길 ----------------
function field() {
  const W = 78, H = 30;
  const m = new MapBuilder(W, H, T.GRASS);
  const r = rng(23);
  for (let i = 0; i < 90; i++) { const x = Math.floor(r() * W), y = Math.floor(r() * H); m.rect(x, y, x + 2, y, T.GRASS2); }
  // winding path control points
  const pts = [[0, 15], [8, 15], [14, 10], [22, 9], [28, 14], [34, 20], [42, 21], [48, 15], [54, 10], [62, 11], [68, 15], [74, 14], [77, 14]];
  for (let i = 0; i < pts.length - 1; i++) m.line(pts[i][0], pts[i][1], pts[i + 1][0], pts[i + 1][1], T.PATH, 2);
  // clearing near tumuli (doll location)
  m.rect(30, 3, 40, 8, T.GRASS2);
  m.line(32, 9, 30, 13, T.PATH, 1);
  // trees: dense forest except near path / clearing
  const nearOpen = (x, y, d) => {
    for (let dy = -d; dy <= d; dy++) for (let dx = -d; dx <= d; dx++) {
      const t = m.get(x + dx, y + dy);
      if (t === T.PATH) return true;
    }
    return false;
  };
  for (let y = 1; y < H; y++) {
    for (let x = 0; x < W; x++) {
      if (x >= 29 && x <= 41 && y >= 2 && y <= 9) continue;
      const border = y <= 1 || y >= H - 1;
      if (border || (!nearOpen(x, y, 2) && r() < 0.38)) {
        const dead = x > 55 && r() < 0.6;
        m.prop(dead ? 'pineDead' : 'pine', x, y);
      }
    }
  }
  // rocks along the path
  for (const [x, y] of [[12, 13], [25, 12], [37, 18], [46, 18], [58, 13], [66, 13]]) m.set(x, y, T.ROCK);
  // tumuli group in the clearing
  m.prop('tumulus', 31, 5); m.prop('tumulus', 37, 7);
  m.prop('pots', 35, 4);
  m.items.push({ id: 'doll', x: px(34) + 4, y: px(7), needFlag: 'q_ghost_accepted', notFlag: 'q_ghost_doll' });
  // the ruined house gate at the east end
  m.prop('gate', 74, 15, { id: 'gate' });
  m.prop('lantern', 71, 12); m.light(71, 11, 50, '120,255,120');
  m.light(74, 13, 70, '120,255,120');
  // stone lanterns early on the path
  m.prop('lantern', 6, 13); m.light(6, 12, 55);
  // enemies
  const dogs = [[16, 9], [24, 10], [30, 16], [44, 21], [52, 12], [64, 10]];
  const imps = [[20, 7], [36, 21], [47, 17], [57, 9], [68, 17]];
  dogs.forEach(([x, y]) => m.enemies.push({ type: 'dog', x: px(x), y: px(y) }));
  imps.forEach(([x, y]) => m.enemies.push({ type: 'imp', x: px(x), y: px(y), quest: 'imp' }));

  m.spawns.fromVillage = { x: px(1), y: px(15) };
  m.spawns.fromDungeon = { x: px(72), y: px(16) };
  m.exits.push({ x: 0, y: 13 * TS, w: 8, h: 4 * TS, to: 'village', spawn: 'fromField', label: '마을' });
  m.exits.push({ x: 74 * TS - 8, y: 13 * TS, w: 24, h: 3 * TS, to: 'dungeon1', spawn: 'entrance', label: '폐가' });
  return m.build({ id: 'field', name: '폐가로 가는 산길', dark: 0.58, music: 'field', ambient: '#071026', miasma: 0.25 });
}

// helpers for dungeons: carve rooms into a void map and wrap with walls
function finishWalls(m) {
  const floorish = (t) => t !== T.VOID && t !== T.WALL;
  for (let y = 0; y < m.h; y++) for (let x = 0; x < m.w; x++) {
    if (m.get(x, y) !== T.VOID) continue;
    let adj = false;
    for (let dy = -1; dy <= 1; dy++) for (let dx = -1; dx <= 1; dx++) if (floorish(m.get(x + dx, y + dy))) adj = true;
    if (adj) m.set(x, y, T.WALL);
  }
  // make wall faces two tiles tall above floors where possible (3/4 view look)
  for (let y = m.h - 1; y >= 1; y--) for (let x = 0; x < m.w; x++) {
    if (floorish(m.get(x, y)) && m.get(x, y - 1) === T.WALL && m.get(x, y - 2) === T.VOID) m.set(x, y - 2, T.WALL);
  }
}

// ---------------- 폐가 1층 ----------------
function dungeon1() {
  const W = 42, H = 36;
  const m = new MapBuilder(W, H, T.VOID);
  // R1 entrance hall
  m.room(3, 25, 13, 32);
  // corridor north
  m.room(7, 20, 9, 24);
  // R2 trap hall (vents)
  m.room(3, 11, 14, 19);
  for (const [x, y] of [[5, 13], [8, 13], [11, 13], [6, 16], [9, 16], [12, 16], [5, 18], [11, 18]]) m.set(x, y, T.VENT);
  // corridor east
  m.room(15, 13, 19, 15);
  // R3 chest room
  m.room(20, 4, 31, 15, T.FLOOR);
  m.rect(23, 6, 28, 8, T.MAT);
  // corridor south
  m.room(25, 16, 27, 20);
  // R4 hall with stairs
  m.room(19, 21, 38, 32);
  m.set(36, 22, T.STAIRS);
  finishWalls(m);
  m.prop('rubble', 4, 31); m.prop('pots', 12, 26); m.prop('cobweb', 3, 25);
  m.prop('bones', 10, 30); m.prop('screen', 22, 5); m.prop('pots', 30, 5);
  m.prop('brazier', 4, 26); m.light(4, 25, 55); m.prop('brazier', 12, 31); m.light(12, 30, 55);
  m.prop('brazier', 3, 12); m.light(3, 11, 50); m.prop('brazier', 14, 12); m.light(14, 11, 50);
  m.prop('brazier', 21, 5); m.light(21, 4, 55); m.prop('brazier', 31, 14); m.light(31, 13, 55);
  m.prop('brazier', 20, 22); m.light(20, 21, 55); m.prop('brazier', 38, 31); m.light(38, 30, 55);
  m.light(36, 22, 50, '220,190,110');
  m.prop('bones', 30, 28); m.prop('rubble', 33, 30); m.prop('cobweb', 19, 21);
  m.items.push({ id: 'chest_bind', kind: 'chest', x: px(25) + 8, y: px(7) + 4 });
  m.npcs.push({ id: 'ghost', sprite: 'ghostChild', x: px(22), y: px(30), name: '아이 원혼 모량', ghost: true });
  // enemies
  [[8, 28, 'dog'], [5, 15, 'imp'], [12, 12, 'dog'], [24, 11, 'imp'], [29, 12, 'dog'], [27, 6, 'imp'],
    [26, 26, 'dog'], [32, 24, 'imp'], [35, 29, 'dog'], [23, 24, 'imp']]
    .forEach(([x, y, t]) => m.enemies.push({ type: t, x: px(x), y: px(y) }));
  m.spawns.entrance = { x: px(8), y: px(31) };
  m.spawns.fromUpstairs = { x: px(35), y: px(23) + 4 };
  m.exits.push({ x: 6 * TS, y: 33 * TS - 4, w: 5 * TS, h: 8, to: 'field', spawn: 'fromDungeon', label: '산길' });
  m.exits.push({ x: 36 * TS + 2, y: 22 * TS + 2, w: 12, h: 12, to: 'dungeon2', spawn: 'fromDownstairs', label: '2층으로 올라가기', interact: true });
  // floor 1 exit: bottom wall gap
  m.rect(7, 33, 9, 33, T.FLOOR);
  return m.build({ id: 'dungeon1', name: '경주 폐가 1층', dark: 0.72, music: 'dungeon', ambient: '#050812', miasma: 0.35, checkpoint: 'entrance', pow: 1.2 });
}

// ---------------- 폐가 2층 + 최심부 ----------------
function dungeon2() {
  const W = 50, H = 38;
  const m = new MapBuilder(W, H, T.VOID);
  m.room(3, 27, 12, 34);             // R1 arrival
  m.set(4, 28, T.STAIRS);
  m.room(7, 21, 9, 26);              // corridor
  m.room(3, 8, 16, 20);              // R2 vents + enemies
  for (const [x, y] of [[6, 11], [10, 11], [14, 11], [5, 15], [8, 14], [12, 15], [7, 18], [13, 18]]) m.set(x, y, T.VENT);
  m.room(17, 12, 20, 14);            // corridor
  m.room(21, 9, 28, 17);             // R3 antechamber
  m.room(29, 12, 31, 14);            // door corridor into boss room
  m.room(32, 3, 47, 22, T.BOSSFLOOR); // boss arena
  finishWalls(m);
  m.prop('rubble', 11, 33); m.prop('pots', 10, 28); m.prop('cobweb', 3, 27); m.prop('bones', 6, 32);
  m.prop('brazier', 12, 28); m.light(12, 27, 55); m.prop('brazier', 3, 33); m.light(3, 32, 50);
  m.prop('brazier', 3, 9); m.light(3, 8, 50); m.prop('brazier', 16, 19); m.light(16, 18, 50);
  m.prop('brazier', 21, 10); m.light(21, 9, 50); m.prop('brazier', 28, 16); m.light(28, 15, 50);
  m.prop('screen', 24, 10); m.prop('bones', 26, 15);
  // boss arena lights (sickly green)
  for (const [x, y] of [[33, 4], [46, 4], [33, 21], [46, 21]]) { m.prop('brazier', x, y); m.light(x, y - 1, 70, '140,255,120'); }
  m.light(40, 12, 90, '120,220,110');
  [[6, 30, 'dog'], [10, 31, 'imp'], [5, 10, 'imp'], [14, 13, 'dog'], [9, 17, 'imp'], [12, 9, 'dog'],
    [24, 12, 'imp'], [26, 15, 'dog'], [23, 15, 'imp']]
    .forEach(([x, y, t]) => m.enemies.push({ type: t, x: px(x), y: px(y) }));
  m.spawns.fromDownstairs = { x: px(5), y: px(29) + 4 };
  m.spawns.bossStart = { x: px(34), y: px(13) };
  m.exits.push({ x: 4 * TS + 2, y: 28 * TS + 2, w: 12, h: 12, to: 'dungeon1', spawn: 'fromUpstairs', label: '1층으로 내려가기', interact: true });
  m.triggers.push({ kind: 'bossRoom', x: 32 * TS, y: 3 * TS, w: 16 * TS, h: 20 * TS });
  m.npcs.push({ id: 'nanyeongSpirit', sprite: 'nanyeongSpirit', x: px(44), y: px(12), name: '난영', hidden: true, spirit: true });
  return m.build({ id: 'dungeon2', name: '경주 폐가 2층', dark: 0.74, music: 'dungeon', ambient: '#050812', miasma: 0.45, pow: 1.35, bossDoor: { x0: 29, x1: 31, y0: 12, y1: 14 } });
}

export const LEVELS = { village, field, dungeon1, dungeon2 };
