// Ground painter: renders a whole level's floor per pixel in world space, so textures never repeat on the
// 16px grid. Grass spills ragged tufts over road edges, flagstones get bevels, interiors get plank floors
// and two-tile-tall plaster-and-timber wall faces. Built once per level load.
import { T } from './gfx.js';
import { hexRgb, ramp } from './paint.js';

const TS = 16;

// ---------------------------------------------------------------- noise
function hash(x, y, s = 0) {
  let h = (x * 374761393 + y * 668265263 + s * 2147483647) | 0;
  h = Math.imul(h ^ (h >>> 13), 1274126177);
  return ((h ^ (h >>> 16)) >>> 0) / 4294967296;
}
function vnoise(x, y, s) {
  const xi = Math.floor(x), yi = Math.floor(y), xf = x - xi, yf = y - yi;
  const u = xf * xf * (3 - 2 * xf), v = yf * yf * (3 - 2 * yf);
  const a = hash(xi, yi, s), b = hash(xi + 1, yi, s), c = hash(xi, yi + 1, s), d = hash(xi + 1, yi + 1, s);
  return a + (b - a) * u + (c - a) * v + (a - b - c + d) * u * v;
}
function fbm(x, y, s, oct = 3) {
  let v = 0, a = 0.5, f = 1, n = 0;
  for (let i = 0; i < oct; i++) { v += vnoise(x * f, y * f, s + i * 17) * a; n += a; a *= 0.5; f *= 2.1; }
  return v / n;
}
const BAY = [0, 8, 2, 10, 12, 4, 14, 6, 3, 11, 1, 9, 15, 7, 13, 5].map((v) => v / 16 - 0.47);

// ---------------------------------------------------------------- palettes (5-tone ramps, dark → light)
const RGB = (r) => r.map(hexRgb);
const P = {
  grass: RGB(ramp('#2c4a30', { hue: 18 })),
  grassD: RGB(ramp('#203826', { hue: 18 })),
  dirt: RGB(ramp('#5a4a38', { hue: 12 })),
  stone: RGB(ramp('#58585c', { hue: 10 })),
  stoneW: RGB(ramp('#5e5a52', { hue: 10 })),
  moss: RGB(ramp('#3a5034', { hue: 16 })),
  water: RGB(ramp('#16304e', { hue: 10 })),
  wood: RGB(ramp('#4e3a2a', { hue: 12 })),
  woodD: RGB(ramp('#3a2c22', { hue: 12 })),
  mat: RGB(ramp('#6a5a3a', { hue: 12 })),
  plaster: RGB(ramp('#7a6a56', { hue: 12 })),
  timber: RGB(ramp('#3e2a1c', { hue: 12 })),
  boss: RGB(ramp('#3a3c40', { hue: 12 })),
  rock: RGB(ramp('#5e6066', { hue: 12 })),
  void: [[4, 5, 9]],
};

export function paintGround(lvl) {
  const W = lvl.w * TS, H = lvl.h * TS;
  const c = document.createElement('canvas');
  c.width = W; c.height = H;
  const g = c.getContext('2d');
  const img = g.createImageData(W, H);
  const D = img.data;
  const tileAt = (tx, ty) => lvl.tileAt(tx, ty);
  const floorish = (t) => t !== T.VOID && t !== T.WALL;
  const grassy = (t) => t === T.GRASS || t === T.GRASS2 || t === T.TREE || t === T.BLOCK || t === T.FENCE || t === T.ROCK;
  const seed = lvl.id.length * 31;

  const put = (i, pal, tone, k = 1) => {
    const t = Math.max(0, Math.min(pal.length - 1, tone | 0));
    const col = pal[t];
    D[i] = col[0] * k; D[i + 1] = col[1] * k; D[i + 2] = col[2] * k; D[i + 3] = 255;
  };

  for (let y = 0; y < H; y++) {
    const ty = (y / TS) | 0, ly = y - ty * TS;
    for (let x = 0; x < W; x++) {
      const tx = (x / TS) | 0, lx = x - tx * TS;
      const i = (y * W + x) * 4;
      let id = tileAt(tx, ty);
      const dith = BAY[(y & 3) * 4 + (x & 3)];
      const big = fbm(x / 90, y / 90, seed + 5); // large-scale light/dark patches
      // grass spills over the edge of roads and plazas
      if (id === T.PATH || id === T.PLAZA) {
        let dEdge = 99;
        if (grassy(tileAt(tx - 1, ty))) dEdge = Math.min(dEdge, lx);
        if (grassy(tileAt(tx + 1, ty))) dEdge = Math.min(dEdge, TS - 1 - lx);
        if (grassy(tileAt(tx, ty - 1))) dEdge = Math.min(dEdge, ly);
        if (grassy(tileAt(tx, ty + 1))) dEdge = Math.min(dEdge, TS - 1 - ly);
        const reach = 1.5 + vnoise(x / 3, y / 3, seed + 9) * 4;
        if (dEdge < reach) id = T.GRASS;
        else if (dEdge < reach + 2) { // shadow cast by the grass lip
          paintTile(id, x, y, lx, ly, tx, ty, i, dith, big, -1);
          continue;
        }
      }
      paintTile(id, x, y, lx, ly, tx, ty, i, dith, big, 0);
    }
  }

  function paintTile(id, x, y, lx, ly, tx, ty, i, dith, big, dark) {
    switch (id) {
      case T.GRASS: case T.GRASS2: case T.TREE: case T.BLOCK: case T.FENCE: case T.ROCK: {
        const pal = id === T.GRASS2 ? P.grassD : P.grass;
        const n = fbm(x / 7, y / 5, seed + 1);
        let tone = 1.2 + n * 2.2 + (big - 0.5) * 1.6 + dith * 0.8 + dark;
        // blades: short vertical strokes, lit tip and shaded root
        const bh = hash(x, Math.floor(y / 3), seed + 2);
        if (bh > 0.86) tone += (y % 3 === 0 ? 1.4 : 0.6);
        else if (bh < 0.07) tone -= 1;
        if (hash(x >> 1, y >> 1, seed + 3) > 0.996) { D[i] = 150; D[i + 1] = 140; D[i + 2] = 168; D[i + 3] = 255; return; } // pale wildflower
        put(i, pal, tone);
        return;
      }
      case T.PATH: {
        const n = fbm(x / 6, y / 6, seed + 4);
        let tone = 1.4 + n * 1.8 + (big - 0.5) * 1.2 + dith * 0.7 + dark;
        // pebbles: lit top, shadow under
        const ph = hash(x >> 1, y >> 1, seed + 6);
        if (ph > 0.975) tone += 1.6; else if (hash(x >> 1, (y - 1) >> 1, seed + 6) > 0.975) tone -= 1.2;
        // wheel ruts
        const rut = Math.abs(Math.sin(y * 0.11 + x * 0.013) * 0.5 + fbm(x / 30, y / 30, seed) - 0.75);
        if (rut < 0.03) tone -= 0.8;
        put(i, P.dirt, tone);
        return;
      }
      case T.PLAZA: case T.BOSSFLOOR: {
        // irregular flagstones: rows of varying height, stones of varying width, offset per row
        const pal = id === T.BOSSFLOOR ? P.boss : P.stone;
        const rowH = 9;
        const row = Math.floor(y / rowH), ry = y - row * rowH;
        const off = hash(row, 0, seed + 7) * 20;
        const sx = x + off;
        const sw = 11 + Math.floor(hash(row, Math.floor(sx / 14), seed + 8) * 6);
        const col = Math.floor(sx / sw), rx = sx - col * sw;
        const sv = hash(row, col, seed + 9);
        let tone = 1.6 + sv * 1.2 + fbm(x / 4, y / 4, seed + 10) * 0.9 + (big - 0.5) * 1.2 + dith * 0.6 + dark;
        if (ry === 0 || rx === 0) { // mortar gap, mossy outdoors
          if (id === T.PLAZA && hash(x, y, seed + 11) > 0.45) { put(i, P.moss, 0.8 + dith + (big - 0.5)); return; }
          tone = 0.2 + dith * 0.4; put(i, pal, tone); return;
        }
        if (ry === 1 || rx === 1) tone += 0.9; // bevel: lit upper-left edge
        if (ry === rowH - 1 || rx === sw - 1) tone -= 0.9; // shaded lower-right edge
        if (hash(x >> 1, y >> 1, seed + 12) > 0.985) tone -= 1.2; // chips
        if (id === T.BOSSFLOOR) {
          const stain = fbm(x / 18, y / 18, seed + 13);
          if (stain > 0.62) { const k = Math.min(1, (stain - 0.62) * 6); put(i, pal, tone - 0.6); D[i] = D[i] * (1 - 0.3 * k); D[i + 1] = D[i + 1] * (1 + 0.15 * k); D[i + 2] = D[i + 2] * (1 - 0.25 * k); return; }
        }
        put(i, pal, tone);
        return;
      }
      case T.WATER: {
        const n = fbm(x / 10, y / 4, seed + 14);
        let tone = 0.8 + n * 2 + dith * 0.6;
        if (Math.abs(Math.sin(y * 0.7 + Math.sin(x * 0.15) * 2)) > 0.97 && n > 0.45) tone += 1.6; // glints
        // dark rim where the bank meets the water
        if (!(tileAt(tx, ty - 1) === T.WATER) && ly < 3) tone -= 1.2 - ly * 0.3;
        put(i, P.water, tone);
        return;
      }
      case T.FLOOR: case T.MAT: case T.VENT: case T.STAIRS: {
        if (id === T.MAT && !(lx === 0 || ly === 0)) { // woven straw mat
          const weave = ((x >> 1) + (y >> 1)) & 1;
          let tone = 1.6 + weave * 0.8 + fbm(x / 5, y / 5, seed + 15) * 0.8 + dith * 0.5;
          if ((y % 4) === 0) tone -= 0.7;
          put(i, P.mat, tone);
          return;
        }
        // 마루 planks: 5px tall, staggered joints, stretched grain
        const ph = 5, pr = Math.floor(y / ph), py2 = y - pr * ph;
        const jo = Math.floor(hash(pr, 1, seed + 16) * 40);
        const plen = 34 + Math.floor(hash(pr, 2, seed + 16) * 20);
        const px2 = (x + jo) % plen;
        const pv = hash(pr, Math.floor((x + jo) / plen), seed + 17);
        let tone = 1.5 + pv * 1.1 + (fbm(x / 14, y / 1.3, seed + 18) - 0.5) * 1.8 + dith * 0.5 + (big - 0.5);
        if (py2 === 0) tone = 0.3 + dith * 0.3;
        else if (py2 === 1) tone += 0.7;
        else if (py2 === ph - 1) tone -= 0.6;
        if (px2 === 0) tone = 0.4;
        if (px2 === 3 && py2 === 2) tone = 0.2; // nail
        // rot and stains
        const rot = fbm(x / 16, y / 16, seed + 19);
        if (rot > 0.68) tone -= (rot - 0.68) * 8;
        put(i, P.wood, tone);
        if (id === T.VENT) paintVent(i, lx, ly, dith);
        if (id === T.STAIRS) paintStairs(i, lx, ly, dith);
        return;
      }
      case T.WALL: paintWall(i, x, y, lx, ly, tx, ty, dith); return;
      default: D[i] = 4; D[i + 1] = 5; D[i + 2] = 9; D[i + 3] = 255;
    }
  }

  function paintVent(i, lx, ly, dith) {
    const dx = lx - 7.5, dy = ly - 7.5, r = Math.hypot(dx, dy * 1.2);
    if (r > 6.5) return;
    if (r > 5.2) { put(i, P.timber, 0.6 + dith); return; }
    // dark pit with a sickly glow at the bottom and a grate
    const k = 1 - r / 5.2;
    D[i] = 20 + 40 * k; D[i + 1] = 30 + 110 * k * k; D[i + 2] = 16 + 30 * k; D[i + 3] = 255;
    if (lx % 3 === 0) { D[i] *= 0.35; D[i + 1] *= 0.35; D[i + 2] *= 0.35; }
  }
  function paintStairs(i, lx, ly, dith) {
    const step = Math.floor(ly / 4);
    const t = 1 + (3 - step) * 0.6 + (ly % 4 === 0 ? 1 : ly % 4 === 3 ? -1 : 0) + dith * 0.4;
    put(i, P.wood, t);
    if (lx === 0 || lx === 15) put(i, P.timber, 0.4);
  }
  function paintWall(i, x, y, lx, ly, tx, ty, dith) {
    const below = tileAt(tx, ty + 1), below2 = tileAt(tx, ty + 2);
    const lower = floorish(below);
    const upper = !lower && below === T.WALL && floorish(below2);
    if (!lower && !upper) {
      // wall top seen from above: dark tiled roof ridge / beams
      const capEdge = floorish(tileAt(tx, ty + 1)) || (tileAt(tx, ty + 1) === T.WALL && (floorish(tileAt(tx, ty + 2)) || floorish(tileAt(tx, ty + 3))));
      let tone = 0.4 + fbm(x / 5, y / 5, seed + 20) * 0.9 + dith * 0.4;
      if ((x + (y >> 2) * 3) % 6 === 0) tone -= 0.4;
      put(i, P.timber, tone, 0.55);
      if (capEdge && ly >= 14) put(i, P.timber, 3 - (ly - 14) * 1.5 + dith * 0.3);
      return;
    }
    // face: plaster panels between timber posts, a beam at mid-height, a sill at the floor
    const fy = upper ? ly : ly + TS; // 0..31 down the face
    const post = (x % 32) < 3;
    let tone;
    if (fy < 2) { put(i, P.timber, 3.2 - fy * 1.4 + dith * 0.3); return; } // top lintel highlight
    if (fy < 5 || (fy >= 15 && fy < 18) || fy >= 29) {
      tone = 1.5 + fbm(x / 9, y / 1.5, seed + 21) * 1 + dith * 0.5;
      if (fy === 4 || fy === 17 || fy === 31) tone -= 1; if (fy === 15 || fy === 29) tone += 0.8;
      put(i, P.timber, tone);
      return;
    }
    if (post) { tone = 1.3 + ((x % 32) === 0 ? 0.9 : (x % 32) === 2 ? -0.8 : 0) + fbm(x, y / 4, seed + 22) * 0.6 + dith * 0.4; put(i, P.timber, tone); return; }
    // plaster: crumbling patches reveal wattle, damp streaks run down from the beam
    const crack = fbm(x / 6, y / 6, seed + 23);
    tone = 1.6 + fbm(x / 3, y / 3, seed + 24) * 1 + dith * 0.6 - (fy > 24 ? (fy - 24) * 0.12 : 0);
    if (crack > 0.7) { put(i, P.timber, 1 + ((x + y) % 3 === 0 ? 0.8 : 0) + dith * 0.4); return; }
    if (crack > 0.66) tone -= 1.2;
    if (Math.abs(fbm(x / 2, 0, seed + 25) - 0.5) < 0.05) tone -= 0.6;
    put(i, P.plaster, tone, 0.85);
  }

  g.putImageData(img, 0, 0);
  // ambient occlusion: soft dark band at the foot of wall faces and rocks
  g.save();
  for (let ty = 0; ty < lvl.h; ty++) for (let tx = 0; tx < lvl.w; tx++) {
    const id = tileAt(tx, ty);
    if (floorish(id) && tileAt(tx, ty - 1) === T.WALL) {
      const gr = g.createLinearGradient(0, ty * TS, 0, ty * TS + 7);
      gr.addColorStop(0, 'rgba(0,0,0,0.55)'); gr.addColorStop(1, 'rgba(0,0,0,0)');
      g.fillStyle = gr; g.fillRect(tx * TS, ty * TS, TS, 7);
    }
    if (floorish(id) && (tileAt(tx - 1, ty) === T.WALL || tileAt(tx + 1, ty) === T.WALL)) {
      const left = tileAt(tx - 1, ty) === T.WALL;
      const gr = g.createLinearGradient(left ? tx * TS : tx * TS + TS, 0, left ? tx * TS + 5 : tx * TS + TS - 5, 0);
      gr.addColorStop(0, 'rgba(0,0,0,0.45)'); gr.addColorStop(1, 'rgba(0,0,0,0)');
      g.fillStyle = gr; g.fillRect(tx * TS, ty * TS, TS, TS);
    }
  }
  g.restore();
  return c;
}

// Boulders and fence posts rise above the ground plane; they are drawn as y-sorted overlays by world.js.
export function tileOverlay(id, seedX, seedY) {
  if (id === T.ROCK) return rockSprite((seedX * 7 + seedY * 13) % 3);
  if (id === T.FENCE) return fenceSprite();
  return null;
}
const ovCache = new Map();
function rockSprite(v) {
  const k = 'rock' + v;
  if (ovCache.has(k)) return ovCache.get(k);
  const c = document.createElement('canvas'); c.width = 22; c.height = 22;
  const g = c.getContext('2d');
  const img = g.createImageData(22, 22), D = img.data;
  const cx = 11, cy = 13, rx = 9.5 - v * 0.5, ry = 8 + v * 0.6;
  for (let y = 0; y < 22; y++) for (let x = 0; x < 22; x++) {
    const dx = (x + 0.5 - cx) / rx, dy = (y + 0.5 - cy) / ry;
    let r = dx * dx + dy * dy;
    r += (vnoise(x / 3, y / 3, 40 + v) - 0.5) * 0.35;
    if (y > 19) r = 2;
    const i = (y * 22 + x) * 4;
    if (r > 1) {
      // outline
      const near = r < 1.25;
      if (near) { D[i] = 8; D[i + 1] = 8; D[i + 2] = 12; D[i + 3] = 255; }
      continue;
    }
    const nz = Math.sqrt(1 - Math.min(1, r));
    const lam = (-dx * 0.55 - dy * 0.75 + nz * 0.9);
    let tone = 1 + lam * 2.4 + (vnoise(x / 2, y / 2, 50 + v) - 0.5) * 1.2 + BAY[(y & 3) * 4 + (x & 3)] * 0.6;
    if (vnoise(x / 4, y / 4, 60 + v) > 0.72 && dy < 0) { const m = P.moss[Math.max(0, Math.min(4, Math.round(tone)))]; D[i] = m[0]; D[i + 1] = m[1]; D[i + 2] = m[2]; D[i + 3] = 255; continue; }
    const col = P.rock[Math.max(0, Math.min(4, Math.round(tone)))];
    D[i] = col[0]; D[i + 1] = col[1]; D[i + 2] = col[2]; D[i + 3] = 255;
  }
  g.putImageData(img, 0, 0);
  const o = { img: c, ax: 11, ay: 20 };
  ovCache.set(k, o);
  return o;
}
function fenceSprite() {
  if (ovCache.has('fence')) return ovCache.get('fence');
  const c = document.createElement('canvas'); c.width = 16; c.height = 26;
  const g = c.getContext('2d');
  const wood = ramp('#5a4030', { hue: 12 });
  const post = (x) => {
    g.fillStyle = '#0a080a'; g.fillRect(x - 1, 2, 5, 24);
    g.fillStyle = wood[2]; g.fillRect(x, 3, 3, 22);
    g.fillStyle = wood[3]; g.fillRect(x, 3, 1, 22);
    g.fillStyle = wood[1]; g.fillRect(x + 2, 3, 1, 22);
    g.fillStyle = wood[4]; g.fillRect(x, 3, 3, 1);
  };
  const rail = (y) => {
    g.fillStyle = '#0a080a'; g.fillRect(0, y - 1, 16, 4);
    g.fillStyle = wood[2]; g.fillRect(0, y, 16, 2);
    g.fillStyle = wood[3]; g.fillRect(0, y, 16, 1);
  };
  rail(9); rail(16);
  post(2); post(11);
  // straw lashing
  g.fillStyle = '#8a7444'; g.fillRect(2, 10, 3, 1); g.fillRect(11, 17, 3, 1);
  const o = { img: c, ax: 8, ay: 25 };
  ovCache.set('fence', o);
  return o;
}
