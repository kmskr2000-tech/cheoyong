// World: terrain generation (Wang corner tiles), zones, roads, props, collision and ground rendering.
'use strict';
(() => {
  const T = G.TILE;
  const W = 120, H = 90;
  // terrain ids
  const SEA = 0, SAND = 1, GRASS = 2, PATH = 3, PLAZA = 4, FOREST = 5, POND = 6, RUIN = 7, YARD = 8;
  const NAMES = ['sea', 'sand', 'grass', 'path', 'plaza', 'forest', 'pond', 'ruin', 'yard'];
  // tileset per terrain pair: [set, lowerTerrain, upperTerrain]
  const PAIRS = {
    '0-1': ['sea_sand', SEA, SAND], '1-2': ['sand_grass', SAND, GRASS], '2-3': ['grass_path', GRASS, PATH],
    '2-4': ['grass_plaza', GRASS, PLAZA], '2-5': ['grass_forest', GRASS, FOREST], '2-6': ['grass_pond', POND, GRASS],
    '2-7': ['grass_ruin', GRASS, RUIN], '2-8': ['grass_yard', GRASS, YARD],
  };
  const pairKey = (a, b) => (a < b ? a + '-' + b : b + '-' + a);
  const HOME = { [SEA]: '0-1', [SAND]: '1-2', [GRASS]: '1-2', [PATH]: '2-3', [PLAZA]: '2-4', [FOREST]: '2-5', [POND]: '2-6', [RUIN]: '2-7', [YARD]: '2-8' };

  // ---------- zones ----------
  const ZONES = [
    { id: 'beach', name: '개운포', x0: 80, y0: 54, x1: 118, y1: 88, music: 'sea', amb: 'sea' },
    { id: 'town', name: '서라벌 저잣거리', x0: 42, y0: 34, x1: 77, y1: 66, music: 'town', amb: 'wind' },
    { id: 'ruin', name: '폐허 우물터', x0: 85, y0: 5, x1: 117, y1: 38, music: 'eerie', amb: 'wind' },
    { id: 'pond', name: '연못 절터', x0: 42, y0: 4, x1: 80, y1: 28, music: 'eerie', amb: 'wind' },
    { id: 'forest', name: '여우숲', x0: 4, y0: 42, x1: 38, y1: 86, music: 'eerie', amb: 'wind' },
    { id: 'house', name: '처용의 집', x0: 5, y0: 5, x1: 34, y1: 34, music: 'eerie', amb: 'wind' },
  ];
  // roads: polylines in tile coords, walkable corridor + dirt path
  const ROADS = [
    { pts: [[100, 70], [88, 71], [76, 70], [68, 68], [66, 64]], w: 2.2 },
    { pts: [[66, 64], [64, 56], [61, 50]], w: 1.6, plaza: true },
    { pts: [[61, 40], [61, 28], [61, 22]], w: 1.8 },
    { pts: [[72, 46], [80, 44], [86, 38], [92, 32], [100, 26]], w: 1.8 },
    { pts: [[50, 54], [40, 56], [32, 58], [22, 66], [18, 72]], w: 1.8 },
    { pts: [[48, 40], [40, 34], [30, 30], [22, 28]], w: 1.8 },
  ];
  // barriers: cells that block until a flag is set
  const GATES = [
    { id: 'south', x0: 61.5, y0: 65, x1: 70.5, y1: 68.5, flag: 'gate_open', label: '남문' },
    { id: 'ruin', x0: 81, y0: 39, x1: 86, y1: 46, flag: 'paths_open', label: '탁기' },
    { id: 'pond', x0: 58, y0: 29, x1: 64, y1: 33, flag: 'paths_open', label: '탁기' },
    { id: 'forest', x0: 37, y0: 50.5, x1: 41.5, y1: 61.5, flag: 'paths_open', label: '탁기' },
    { id: 'house', x0: 34, y0: 26, x1: 39, y1: 37.5, flag: 'house_open', label: '탁기' },
  ];

  const inRect = (x, y, r, m = 0) => x >= r.x0 - m && x <= r.x1 + m && y >= r.y0 - m && y <= r.y1 + m;
  const segDist = (px, py, ax, ay, bx, by) => {
    const dx = bx - ax, dy = by - ay; const l2 = dx * dx + dy * dy;
    let t = l2 ? ((px - ax) * dx + (py - ay) * dy) / l2 : 0; t = G.clamp(t, 0, 1);
    return Math.hypot(px - (ax + t * dx), py - (ay + t * dy));
  };
  const roadDist = (x, y, road) => {
    let d = 1e9;
    for (let i = 0; i < road.pts.length - 1; i++) d = Math.min(d, segDist(x, y, ...road.pts[i], ...road.pts[i + 1]));
    return d;
  };

  // ---------- terrain on the vertex grid ----------
  const V = new Uint8Array((W + 1) * (H + 1));
  const vi = (x, y) => y * (W + 1) + x;
  const getV = (x, y) => V[vi(G.clamp(x, 0, W), G.clamp(y, 0, H))];

  function isSea(x, y) {
    const n = G.fbm(x * 0.09, y * 0.09, 5) * 6;
    if (y >= 46 && x >= 111 - n + (y > 62 && y < 80 ? -6 : 0)) return true; // east coast with Gaeunpo bay
    if (x >= 74 && y >= 85 - n * 0.6) return true; // south coast
    return false;
  }

  function paint() {
    V.fill(GRASS);
    for (let y = 0; y <= H; y++) for (let x = 0; x <= W; x++) {
      const n = G.fbm(x * 0.15, y * 0.15, 3);
      let t = GRASS;
      if (inRect(x, y, ZONES[4], 1) && n > 0.28) t = FOREST;
      if (inRect(x, y, ZONES[2], 0) && G.fbm(x * 0.2, y * 0.2, 8) > 0.38) t = RUIN;
      if (x >= 50 && x <= 73 && y >= 40 && y <= 60) t = PLAZA;
      if (x >= 9 && x <= 31 && y >= 8 && y <= 29) t = YARD;
      // temple court around the pagoda
      if (x >= 68 && x <= 77 && y >= 6 && y <= 13) t = PLAZA;
      // pond: ellipse with noisy edge
      const pe = ((x - 59) / 10) ** 2 + ((y - 14) / 5.5) ** 2;
      if (pe < 1 - (n - 0.5) * 0.4) t = POND;
      V[vi(x, y)] = t;
    }
    for (const r of ROADS) for (let y = 0; y <= H; y++) for (let x = 0; x <= W; x++) {
      const d = roadDist(x, y, r);
      if (d < r.w * 0.55 + G.noise(x * 0.5, y * 0.5, 2) * 0.5) {
        const cur = V[vi(x, y)];
        if (cur === POND || cur === YARD || cur === PLAZA) continue;
        V[vi(x, y)] = r.plaza ? PLAZA : PATH;
      }
    }
    // coast: sea, then a sand band around it
    const sea = new Uint8Array(V.length);
    for (let y = 0; y <= H; y++) for (let x = 0; x <= W; x++) if (isSea(x, y)) sea[vi(x, y)] = 1;
    for (let y = 0; y <= H; y++) for (let x = 0; x <= W; x++) {
      if (sea[vi(x, y)]) { V[vi(x, y)] = SEA; continue; }
      let near = 99;
      for (let dy = -6; dy <= 6; dy++) for (let dx = -6; dx <= 6; dx++) {
        const xx = x + dx, yy = y + dy;
        if (xx < 0 || yy < 0 || xx > W || yy > H || !sea[vi(xx, yy)]) continue;
        near = Math.min(near, Math.hypot(dx, dy));
      }
      const band = 3.2 + G.fbm(x * 0.12, y * 0.12, 6) * 3;
      if (near <= band && x >= 74) V[vi(x, y)] = SAND;
    }
    legalize();
  }

  const legalPair = (a, b) => a === b || !!PAIRS[pairKey(a, b)];
  function legalize() {
    // repeat until every 2x2 cell holds at most two terrains that have a tileset together
    for (let pass = 0; pass < 8; pass++) {
      let changed = 0;
      for (let y = 0; y < H; y++) for (let x = 0; x < W; x++) {
        const c = [getV(x, y), getV(x + 1, y), getV(x, y + 1), getV(x + 1, y + 1)];
        const set = [...new Set(c)];
        if (set.length === 1 || (set.length === 2 && legalPair(set[0], set[1]))) continue;
        // keep the most important terrain, push others towards grass/sand
        const pts = [[x, y], [x + 1, y], [x, y + 1], [x + 1, y + 1]];
        const hasSea = set.includes(SEA);
        for (let i = 0; i < 4; i++) {
          const t = c[i];
          if (hasSea) { if (t !== SEA && t !== SAND) { V[vi(...pts[i])] = SAND; changed++; } }
          else if (set.includes(SAND)) { if (t !== SAND && t !== GRASS) { V[vi(...pts[i])] = GRASS; changed++; } }
          else if (t !== GRASS) {
            // two different non-grass terrains: the lower id wins (path > plaza ...), others become grass
            const keep = Math.min(...set.filter((s) => s !== GRASS));
            if (t !== keep) { V[vi(...pts[i])] = GRASS; changed++; }
          }
        }
      }
      if (!changed) break;
    }
  }

  // ---------- cells ----------
  const cellTile = new Array(W * H); // {set, idx, flip}
  const solid = new Uint8Array(W * 2 * H * 2); // 16px collision grid
  const SW2 = W * 2, SH2 = H * 2;
  const walkable = new Uint8Array(W * H); // zone/road mask
  const cellZone = new Array(W * H);

  function buildCells() {
    const A = G.assets.tiles;
    for (let y = 0; y < H; y++) for (let x = 0; x < W; x++) {
      const c = [getV(x, y), getV(x + 1, y), getV(x, y + 1), getV(x + 1, y + 1)]; // NW NE SW SE
      const set = [...new Set(c)];
      let key = set.length === 1 ? HOME[set[0]] : pairKey(set[0], set[1]);
      if (!PAIRS[key]) key = HOME[set[0]];
      const [name, lo, up] = PAIRS[key];
      const ts = A[name];
      let pick = null;
      if (ts) {
        const want = c.map((t) => (t === up ? 1 : 0)).join('');
        const cands = ts.byCorners[want] || ts.byCorners[set.length === 1 ? (set[0] === up ? '1111' : '0000') : '0000'];
        pick = cands ? cands[Math.floor(G.hash2(x, y, 11) * cands.length)] : null;
      }
      const full = set.length === 1;
      cellTile[y * W + x] = { set: name, idx: pick, flip: full && G.hash2(x, y, 12) < 0.5, t: c, full: full ? set[0] : -1 };
    }
  }

  function zoneAt(tx, ty) {
    for (const z of ZONES) if (inRect(tx, ty, z)) return z;
    return null;
  }

  function buildWalk() {
    for (let y = 0; y < H; y++) for (let x = 0; x < W; x++) {
      let ok = !!zoneAt(x, y);
      if (!ok) for (const r of ROADS) if (roadDist(x + 0.5, y + 0.5, r) < r.w + 0.6) { ok = true; break; }
      walkable[y * W + x] = ok ? 1 : 0;
      cellZone[y * W + x] = zoneAt(x, y);
    }
    solid.fill(0);
    for (let y = 0; y < H; y++) for (let x = 0; x < W; x++) {
      const c = cellTile[y * W + x].t;
      const water = c.filter((t) => t === SEA || t === POND).length;
      const block = !walkable[y * W + x] || water >= 3 || x < 2 || y < 2 || x >= W - 2 || y >= H - 2;
      if (block) for (let k = 0; k < 4; k++) solid[(y * 2 + (k >> 1)) * SW2 + x * 2 + (k & 1)] = 1;
      else if (water === 2) {
        // half water cells: block the water half
        const [nw, ne, sw, se] = c.map((t) => t === SEA || t === POND);
        const q = [nw, ne, sw, se];
        for (let k = 0; k < 4; k++) if (q[k]) solid[(y * 2 + (k >> 1)) * SW2 + x * 2 + (k & 1)] = 1;
      }
    }
  }

  // ---------- props ----------
  // prop kinds: footprint (collision rect relative to the anchor at the bottom centre, in px), light
  const KINDS = {
    pine: { foot: [-10, -10, 20, 12], shadow: 26 }, pine2: { foot: [-10, -10, 20, 12], shadow: 26 },
    deadtree: { foot: [-9, -10, 18, 12], shadow: 22 }, bush: { foot: [-12, -8, 24, 10], shadow: 14 },
    rock: { foot: [-18, -14, 36, 16], shadow: 18 }, reeds: { foot: null, shadow: 0 },
    giwa: { foot: [-86, -70, 172, 66], shadow: 90 }, choga: { foot: [-70, -54, 140, 50], shadow: 74 },
    stall: { foot: [-50, -36, 100, 32], shadow: 50 }, well: { foot: [-28, -26, 56, 26], shadow: 30, light: null },
    brokenwell: { foot: [-30, -26, 60, 24], shadow: 32, light: [0, -30, 90, '#8a4cff', 0.5] },
    pagoda: { foot: [-28, -28, 56, 26], shadow: 34 }, pavilion: { foot: [-66, -50, 132, 18], shadow: 70, solidEdges: true },
    lantern: { foot: [-12, -12, 24, 12], shadow: 12, light: [0, -40, 150, '#ffb35a', 0.95] },
    jangseung: { foot: [-24, -12, 48, 12], shadow: 22 }, wall: { foot: [-64, -22, 128, 20], shadow: 0 },
    ruinwall: { foot: [-52, -20, 104, 18], shadow: 0 }, gate: { foot: null, shadow: 0 },
    boat: { foot: [-48, -28, 96, 26], shadow: 40 },
    lamppost: { foot: [-6, -8, 12, 8], shadow: 8, light: [0, -70, 170, '#ff8a4a', 0.9] },
    jars: { foot: [-28, -22, 56, 20], shadow: 26 }, shrine: { foot: [-50, -50, 100, 46], shadow: 50, light: [0, -40, 120, '#7fd0ff', 0.6] },
    cheoyonghouse: { foot: [-118, -90, 236, 86], shadow: 120, light: [-60, -40, 160, '#ffb35a', 0.7] },
    palanquin: { foot: [-48, -30, 96, 28], shadow: 46 }, altar: { foot: [-26, -18, 52, 16], shadow: 20, light: [0, -20, 110, '#7fd0ff', 0.7] },
    lotus: { foot: null, shadow: 0, flat: true }, cart: { foot: [-40, -26, 80, 24], shadow: 36 },
    bones: { foot: null, shadow: 0, flat: true },
    tuft: { foot: null, shadow: 0 }, tuft2: { foot: null, shadow: 0 }, flowers: { foot: null, shadow: 0, flat: true }, pebbles: { foot: null, shadow: 0, flat: true },
  };
  const props = [];
  const addProp = (kind, tx, ty, opt = {}) => {
    const p = { kind, x: tx * T, y: ty * T, ...opt };
    props.push(p);
    return p;
  };

  function placeProps() {
    props.length = 0;
    const r = G.rng(1234);
    // --- town (서라벌) ---
    addProp('giwa', 47, 39); addProp('giwa', 76, 39); addProp('giwa', 46, 49, { flipX: true });
    addProp('choga', 46, 64); addProp('choga', 76, 63); addProp('choga', 77, 52, { flipX: true });
    addProp('stall', 55, 45); addProp('stall', 68, 45, { flipX: true }); addProp('stall', 56, 58);
    addProp('well', 61, 51); addProp('jars', 50, 44); addProp('jars', 73, 58); addProp('cart', 70, 59);
    addProp('pavilion', 74, 49 - 4); // dosa's pavilion (east of plaza)
    for (const [x, y] of [[53, 41], [69, 41], [53, 61], [69, 61], [58, 51], [64, 51], [61, 36], [57, 66], [75, 67], [44, 56]]) addProp('lamppost', x, y);
    addProp('gate', 66, 66.4, { gate: 'south' });
    for (const x of [42, 46, 50, 54, 58, 62.4, 70.2, 74, 78]) addProp('wall', x + 2, 66.8, { gateWall: true });
    // --- beach (개운포) ---
    addProp('boat', 98, 79); addProp('boat', 104, 59, { flipX: true }); addProp('rock', 94, 62); addProp('rock', 108, 84);
    addProp('reeds', 86, 58); addProp('reeds', 82, 76); addProp('jangseung', 92, 68); addProp('lantern', 96, 66);
    addProp('altar', 103.5, 74.5);
    // --- ruin (우물터) ---
    addProp('brokenwell', 101, 21);
    for (const [x, y] of [[90, 12], [110, 14], [94, 30], [112, 30], [88, 22], [106, 9]]) addProp('ruinwall', x, y, { flipX: r() < 0.5 });
    for (const [x, y] of [[96, 16], [108, 24], [92, 26], [114, 20], [99, 33], [87, 8]]) addProp('deadtree', x, y);
    for (const [x, y] of [[104, 27], [95, 20], [110, 33]]) addProp('bones', x, y);
    addProp('lantern', 100, 35);
    // --- pond temple (연못 절터) ---
    addProp('pagoda', 73, 11); addProp('lantern', 69, 12); addProp('lantern', 77, 12); addProp('altar', 73, 15);
    for (const [x, y] of [[53, 12], [57, 17], [64, 11], [61, 16], [66, 15]]) addProp('lotus', x, y);
    for (const [x, y] of [[48, 18], [70, 19], [50, 9], [67, 7]]) addProp('reeds', x, y);
    addProp('giwa', 50, 26 - 2, { flipX: true });
    // --- forest (여우숲) ---
    addProp('shrine', 34, 52); addProp('lantern', 37, 54);
    addProp('altar', 18, 70); addProp('jangseung', 26, 60);
    // --- house (처용의 집) ---
    addProp('cheoyonghouse', 20, 17);
    for (const x of [10, 14, 18, 26, 30]) addProp('wall', x, 31, { houseWall: true });
    for (const x of [10, 14, 18, 22, 26, 30]) addProp('wall', x, 7.5);
    addProp('lantern', 15, 27); addProp('lantern', 25, 27); addProp('jars', 29, 21); addProp('pine2', 9, 12);
    // town lanterns at north edge
    addProp('lantern', 59, 34); addProp('lantern', 63, 34);

    // --- trees: fill every non-walkable cell near walkable space, scatter some in zones ---
    const near = (x, y, rad) => {
      for (let dy = -rad; dy <= rad; dy++) for (let dx = -rad; dx <= rad; dx++) {
        const xx = x + dx, yy = y + dy;
        if (xx >= 0 && yy >= 0 && xx < W && yy < H && walkable[yy * W + xx]) return true;
      }
      return false;
    };
    for (let y = 0; y < H; y += 1) for (let x = 0; x < W; x += 1) {
      const wv = walkable[y * W + x];
      const h = G.hash2(x, y, 31);
      const t = cellTile[y * W + x].t;
      if (t.some((v) => v === SEA || v === POND || v === SAND)) continue;
      if (!wv) {
        if ((x + (y % 2)) % 2 === 0 && y % 2 === 0 && near(x, y, 7)) {
          const kind = cellZone[y * W + x] ? 'pine' : (h < 0.12 ? 'deadtree' : h < 0.6 ? 'pine' : 'pine2');
          addProp(zoneNearRuin(x, y) ? 'deadtree' : kind, x + 0.5 + (h - 0.5) * 0.8, y + 1 + (G.hash2(x, y, 32) - 0.5) * 0.6, { bg: true, flipX: h > 0.5 });
        }
        continue;
      }
      const z = cellZone[y * W + x];
      if (!z) continue;
      if (onRoad(x, y)) continue;
      // ground clutter like a painted MMORPG field: dry grass, green tufts, flowers, pebbles
      const hc = G.hash2(x, y, 55);
      if (z.id !== 'town' && t.every((v) => v === GRASS || v === FOREST || v === RUIN || v === YARD)) {
        const ox = G.hash2(x, y, 56), oy = G.hash2(x, y, 57);
        const dryZone = z.id === 'ruin' || z.id === 'beach' || z.id === 'house';
        if (hc < 0.07) addProp(dryZone && hc < 0.03 ? 'tuft' : 'tuft2', x + ox, y + oy + 0.4, { flipX: ox > 0.5 });
        else if (hc < 0.095 && z.id !== 'ruin') addProp('flowers', x + ox, y + oy);
      }
      if (z.id === 'forest' && h < 0.085 && !nearPoint(x, y, [[34, 52], [18, 72], [26, 60]], 5)) addProp(h < 0.06 ? 'pine' : 'pine2', x + 0.5, y + 1, { flipX: h < 0.03 });
      else if (z.id === 'forest' && h < 0.11) addProp('bush', x + 0.5, y + 1);
      else if (z.id === 'beach' && h < 0.006) addProp('rock', x + 0.5, y + 1);
      else if (z.id !== 'town' && z.id !== 'house' && h < 0.012) addProp('bush', x + 0.5, y + 1);
      else if (z.id === 'ruin' && h < 0.02) addProp('rock', x + 0.5, y + 1);
    }
    for (const p of props) {
      p.k = KINDS[p.kind] || {};
      if (p.k.light) p.light = p.k.light;
    }
  }
  const zoneNearRuin = (x, y) => x > 82 && y < 42;
  const onRoad = (x, y) => ROADS.some((r) => roadDist(x + 0.5, y + 0.5, r) < r.w + 0.4);
  const nearPoint = (x, y, pts, d) => pts.some(([px, py]) => Math.hypot(px - x, py - y) < d);

  function propSolids() {
    for (const p of props) {
      const f = p.k.foot;
      if (!f) continue;
      if (p.gateWall && Math.abs(p.x / T - 66) < 3.2) continue; // gap for the south gate
      const x0 = Math.floor((p.x + f[0]) / 16), y0 = Math.floor((p.y + f[1]) / 16);
      const x1 = Math.floor((p.x + f[0] + f[2] - 1) / 16), y1 = Math.floor((p.y + f[1] + f[3] - 1) / 16);
      for (let y = y0; y <= y1; y++) for (let x = x0; x <= x1; x++) if (x >= 0 && y >= 0 && x < SW2 && y < SH2) solid[y * SW2 + x] = 1;
    }
  }

  // ---------- public ----------
  const world = {
    W, H, ZONES, GATES, props, NAMES, pw: W * T, ph: H * T,
    init() {
      paint();
      buildCells();
      buildWalk();
      placeProps();
      propSolids();
      this.chunks = new Map();
    },
    zoneAt(px, py) { return cellZone[Math.floor(py / T) * W + Math.floor(px / T)] || null; },
    terrainAt(px, py) { const c = cellTile[G.clamp(Math.floor(py / T), 0, H - 1) * W + G.clamp(Math.floor(px / T), 0, W - 1)]; return c ? c.t[3] : GRASS; },
    gateBlocks(px, py) {
      const tx = px / T, ty = py / T;
      for (const g of GATES) if (!G.game.flags[g.flag] && tx >= g.x0 && tx <= g.x1 && ty >= g.y0 && ty <= g.y1) return g;
      return null;
    },
    solidAt(px, py) {
      const x = Math.floor(px / 16), y = Math.floor(py / 16);
      if (x < 0 || y < 0 || x >= SW2 || y >= SH2) return true;
      if (solid[y * SW2 + x]) return true;
      return !!this.gateBlocks(px, py);
    },
    // circle vs grid: test a few points on the circle
    blocked(x, y, r) {
      for (let i = 0; i < 8; i++) {
        const a = (i / 8) * Math.PI * 2;
        if (this.solidAt(x + Math.cos(a) * r, y + Math.sin(a) * r * 0.7)) return true;
      }
      return this.solidAt(x, y);
    },
    moveCircle(e, dx, dy) {
      const r = e.r || 10;
      if (dx && !this.blocked(e.x + dx, e.y, r)) e.x += dx;
      else if (dx) { // slide around corners
        for (const s of [1, -1]) if (!this.blocked(e.x + dx * 0.7, e.y + s * Math.abs(dx) * 0.7, r)) { e.x += dx * 0.7; e.y += s * Math.abs(dx) * 0.7; break; }
      }
      if (dy && !this.blocked(e.x, e.y + dy, r)) e.y += dy;
      else if (dy) {
        for (const s of [1, -1]) if (!this.blocked(e.x + s * Math.abs(dy) * 0.7, e.y + dy * 0.7, r)) { e.x += s * Math.abs(dy) * 0.7; e.y += dy * 0.7; break; }
      }
    },
    // straight line clear? (for AI)
    clearLine(x0, y0, x1, y1) {
      const d = Math.hypot(x1 - x0, y1 - y0), n = Math.ceil(d / 12);
      for (let i = 1; i < n; i++) if (this.solidAt(x0 + ((x1 - x0) * i) / n, y0 + ((y1 - y0) * i) / n)) return false;
      return true;
    },
    // ground chunk baking (512px)
    chunk(cx, cy) {
      const key = cx + ',' + cy;
      let c = this.chunks.get(key);
      if (c) return c;
      const S = 512, n = S / T;
      c = document.createElement('canvas'); c.width = S; c.height = S;
      const g = c.getContext('2d'); g.imageSmoothingEnabled = true; g.imageSmoothingQuality = 'high';
      for (let y = 0; y < n; y++) for (let x = 0; x < n; x++) {
        const tx = cx * n + x, ty = cy * n + y;
        if (tx >= W || ty >= H) continue;
        const ct = cellTile[ty * W + tx];
        const ts = G.assets.tiles[ct.set];
        if (ts && ct.idx != null) {
          const S2 = ts.size || T;
          const sx = (ct.idx % 4) * S2, sy = Math.floor(ct.idx / 4) * S2;
          if (ct.flip) { g.save(); g.translate(x * T + T, y * T); g.scale(-1, 1); g.drawImage(ts.img, sx, sy, S2, S2, 0, 0, T, T); g.restore(); }
          else g.drawImage(ts.img, sx, sy, S2, S2, x * T, y * T, T, T);
        } else {
          g.fillStyle = ['#13306a', '#d9c79a', '#2f5a2a', '#7a5b3a', '#77777a', '#2a3a22', '#244a3a', '#5a5550', '#9a7f5a'][ct.t[3]];
          g.fillRect(x * T, y * T, T, T);
        }
        // small procedural details on full grass/forest/ruin cells
        const h = G.hash2(tx, ty, 77);
        if (ct.full === GRASS && h < 0.25) {
          const col = h < 0.05 ? '#d8d0f0' : h < 0.09 ? '#e8c060' : '#4b7a3a';
          for (let k = 0; k < 3; k++) {
            const px = x * T + Math.floor(G.hash2(tx, ty, 80 + k) * 28) + 2, py = y * T + Math.floor(G.hash2(tx, ty, 90 + k) * 28) + 2;
            g.fillStyle = col; g.fillRect(px, py, 2, 2);
            if (col === '#4b7a3a') { g.fillRect(px - 1, py - 2, 1, 2); g.fillRect(px + 2, py - 2, 1, 2); }
          }
        }
      }
      this.chunks.set(key, c);
      return c;
    },
    drawGround(ctx, cam, vw, vh) {
      const S = 512;
      const x0 = Math.floor(cam.x / S), y0 = Math.floor(cam.y / S);
      const x1 = Math.floor((cam.x + vw) / S), y1 = Math.floor((cam.y + vh) / S);
      for (let cy = y0; cy <= y1; cy++) for (let cx = x0; cx <= x1; cx++) {
        if (cx < 0 || cy < 0 || cx * S >= this.pw || cy * S >= this.ph) continue;
        ctx.drawImage(this.chunk(cx, cy), Math.round(cx * S - cam.x), Math.round(cy * S - cam.y));
      }
    },
    // water shimmer drawn over the baked ground
    drawWater(ctx, cam, vw, vh, time) {
      const tx0 = Math.max(0, Math.floor(cam.x / T)), ty0 = Math.max(0, Math.floor(cam.y / T));
      const tx1 = Math.min(W - 1, Math.floor((cam.x + vw) / T)), ty1 = Math.min(H - 1, Math.floor((cam.y + vh) / T));
      ctx.fillStyle = 'rgba(190,220,255,0.35)';
      for (let ty = ty0; ty <= ty1; ty++) for (let tx = tx0; tx <= tx1; tx++) {
        const ct = cellTile[ty * W + tx];
        if (ct.full !== SEA && ct.full !== POND) continue;
        const h = G.hash2(tx, ty, 5);
        const ph = (time * 0.6 + h * 10) % 4;
        if (ph < 1.4) {
          const a = Math.sin((ph / 1.4) * Math.PI);
          ctx.globalAlpha = a * 0.6;
          const px = tx * T + Math.floor(h * 20) + 2 - cam.x, py = ty * T + Math.floor(G.hash2(tx, ty, 6) * 26) + 3 - cam.y;
          ctx.fillRect(Math.round(px), Math.round(py), 6 + Math.floor(ph * 3), 1);
        }
      }
      ctx.globalAlpha = 1;
    },
    isWaterCell(tx, ty) { const ct = cellTile[ty * W + tx]; return ct && (ct.full === SEA || ct.full === POND); },
  };
  G.world = world;
})();
