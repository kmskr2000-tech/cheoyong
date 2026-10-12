// Procedural pixel painter for the HD-2D look.
// Shapes are filled with *materials* (a hue-shifted color ramp) into a label map; render() then shades
// every pixel from a pseudo-normal (distance to the edge of its part), a fixed key light from the upper
// left, per-pixel hand adjustments (folds, creases) and ordered dithering, and finally adds a colored
// near-black outline. This gives sprites real volume instead of flat chibi fills, from code alone.

const clamp = (v, a, b) => (v < a ? a : v > b ? b : v);

// ---------------------------------------------------------------- color
export function hexRgb(h) {
  const n = parseInt(h.length === 4 ? h.slice(1).split('').map((c) => c + c).join('') : h.slice(1, 7), 16);
  return [(n >> 16) & 255, (n >> 8) & 255, n & 255];
}
const toHex = (r, g, b) => '#' + [r, g, b].map((v) => clamp(Math.round(v), 0, 255).toString(16).padStart(2, '0')).join('');
function rgbHsl(r, g, b) {
  r /= 255; g /= 255; b /= 255;
  const mx = Math.max(r, g, b), mn = Math.min(r, g, b), l = (mx + mn) / 2;
  if (mx === mn) return [0, 0, l];
  const d = mx - mn, s = l > 0.5 ? d / (2 - mx - mn) : d / (mx + mn);
  let h = mx === r ? (g - b) / d + (g < b ? 6 : 0) : mx === g ? (b - r) / d + 2 : (r - g) / d + 4;
  return [h * 60, s, l];
}
function hslRgb(h, s, l) {
  h = ((h % 360) + 360) % 360 / 360;
  if (!s) return [l * 255, l * 255, l * 255];
  const q = l < 0.5 ? l * (1 + s) : l + s - l * s, p = 2 * l - q;
  const f = (t) => { t = (t + 1) % 1; return t < 1 / 6 ? p + (q - p) * 6 * t : t < 0.5 ? q : t < 2 / 3 ? p + (q - p) * (2 / 3 - t) * 6 : p; };
  return [f(h + 1 / 3) * 255, f(h) * 255, f(h - 1 / 3) * 255];
}
function shiftHue(h, target, amt) {
  let d = ((target - h + 540) % 360) - 180;
  return h + clamp(d, -amt, amt);
}
// 5-tone ramp, darkest first. Shadows drift toward cold violet, highlights toward warm gold
// (the classic hue-shifted pixel ramp; keeps dark fantasy palettes from going muddy).
export function ramp(hex, o = {}) {
  const [h, s, l] = rgbHsl(...hexRgb(hex));
  const hs = o.hue ?? 14, spread = o.spread ?? 1;
  const tone = (dl, dh, ds, tgt) => toHex(...hslRgb(shiftHue(h, tgt, dh), clamp(s * ds, 0, 1), clamp(l * dl, 0.02, 0.97)));
  return [
    tone(1 - 0.6 * spread, hs * 1.6, 1.05, 250),
    tone(1 - 0.32 * spread, hs, 1.08, 250),
    hex,
    tone(1 + 0.26 * spread, hs * 0.8, 0.98, 50),
    tone(1 + 0.55 * spread, hs * 1.4, 0.9, 50),
  ];
}
export function mix(a, b, t) {
  const A = hexRgb(a), B = hexRgb(b);
  return toHex(A[0] + (B[0] - A[0]) * t, A[1] + (B[1] - A[1]) * t, A[2] + (B[2] - A[2]) * t);
}

const BAYER = [0, 8, 2, 10, 12, 4, 14, 6, 3, 11, 1, 9, 15, 7, 13, 5].map((v) => v / 16 - 0.47);
// key light: upper left, slightly toward the viewer
const LX = -0.55, LY = -0.75, LZ = 0.9;
const LN = Math.hypot(LX, LY, LZ);
const L = [LX / LN, LY / LN, LZ / LN];

export class Painter {
  constructor(w, h) {
    this.w = w; this.h = h;
    const n = w * h;
    this.mat = new Int16Array(n).fill(-1);
    this.grp = new Int16Array(n).fill(-1);
    this.adj = new Float32Array(n);
    this.mats = [];
    this.g = 0;
    this.ox = 0; this.oy = 0; this.flip = false;
  }
  // spec: hex string or { c: hex, r: ramp[], flat, curve, dither, outline, spec, glow }
  m(spec) {
    if (typeof spec === 'string') spec = { c: spec };
    const r = spec.r || ramp(spec.c, spec);
    this.mats.push({ r, flat: !!spec.flat, curve: spec.curve ?? 2.6, dither: spec.dither ?? 0.35, outline: spec.outline ?? true, spec: !!spec.spec, glow: !!spec.glow, ao: spec.ao ?? 1 });
    return this.mats.length - 1;
  }
  part() { this.g++; return this; }
  at(x, y) { return [Math.round(this.flip ? this.w - 1 - (x + this.ox) : x + this.ox), Math.round(y + this.oy)]; }
  set(x, y, m) {
    const [px, py] = this.at(x, y);
    if (px < 0 || py < 0 || px >= this.w || py >= this.h) return;
    const i = py * this.w + px;
    this.mat[i] = m; this.grp[i] = this.g; this.adj[i] = 0;
  }
  clear(x, y) {
    const [px, py] = this.at(x, y);
    if (px < 0 || py < 0 || px >= this.w || py >= this.h) return;
    this.mat[py * this.w + px] = -1;
  }
  sh(x, y, d) { // hand shading (+ lighter, - darker)
    const [px, py] = this.at(x, y);
    if (px < 0 || py < 0 || px >= this.w || py >= this.h) return;
    this.adj[py * this.w + px] += d;
  }
  has(x, y) {
    const [px, py] = this.at(x, y);
    return px >= 0 && py >= 0 && px < this.w && py < this.h && this.mat[py * this.w + px] >= 0;
  }
  rect(x, y, w, h, m) { for (let yy = 0; yy < h; yy++) for (let xx = 0; xx < w; xx++) this.set(x + xx, y + yy, m); return this; }
  shRect(x, y, w, h, d) { for (let yy = 0; yy < h; yy++) for (let xx = 0; xx < w; xx++) this.sh(x + xx, y + yy, d); return this; }
  ellipse(cx, cy, rx, ry, m) {
    for (let y = Math.floor(cy - ry); y <= Math.ceil(cy + ry); y++) for (let x = Math.floor(cx - rx); x <= Math.ceil(cx + rx); x++) {
      const dx = (x + 0.5 - cx) / rx, dy = (y + 0.5 - cy) / ry;
      if (dx * dx + dy * dy <= 1) this.set(x, y, m);
    }
    return this;
  }
  shEllipse(cx, cy, rx, ry, d) {
    for (let y = Math.floor(cy - ry); y <= Math.ceil(cy + ry); y++) for (let x = Math.floor(cx - rx); x <= Math.ceil(cx + rx); x++) {
      const dx = (x + 0.5 - cx) / rx, dy = (y + 0.5 - cy) / ry;
      if (dx * dx + dy * dy <= 1) this.sh(x, y, d);
    }
    return this;
  }
  // filled polygon, pixel centers inside (even-odd)
  poly(pts, m, shade) {
    let x0 = 1e9, x1 = -1e9, y0 = 1e9, y1 = -1e9;
    for (const [x, y] of pts) { x0 = Math.min(x0, x); x1 = Math.max(x1, x); y0 = Math.min(y0, y); y1 = Math.max(y1, y); }
    for (let y = Math.floor(y0); y <= Math.ceil(y1); y++) for (let x = Math.floor(x0); x <= Math.ceil(x1); x++) {
      const px = x + 0.5, py = y + 0.5;
      let inside = false;
      for (let i = 0, j = pts.length - 1; i < pts.length; j = i++) {
        const [xi, yi] = pts[i], [xj, yj] = pts[j];
        if ((yi > py) !== (yj > py) && px < ((xj - xi) * (py - yi)) / (yj - yi) + xi) inside = !inside;
      }
      if (inside) { if (shade !== undefined) this.sh(x, y, shade); else this.set(x, y, m); }
    }
    return this;
  }
  line(x0, y0, x1, y1, m, wdt = 1) {
    const n = Math.max(1, Math.ceil(Math.hypot(x1 - x0, y1 - y0) * 1.5));
    for (let i = 0; i <= n; i++) {
      const x = x0 + ((x1 - x0) * i) / n, y = y0 + ((y1 - y0) * i) / n;
      if (wdt <= 1) this.set(Math.floor(x), Math.floor(y), m);
      else this.ellipse(x, y, wdt / 2, wdt / 2, m);
    }
    return this;
  }
  shLine(x0, y0, x1, y1, d) {
    const n = Math.max(1, Math.ceil(Math.hypot(x1 - x0, y1 - y0) * 1.5));
    const seen = new Set();
    for (let i = 0; i <= n; i++) {
      const x = Math.floor(x0 + ((x1 - x0) * i) / n), y = Math.floor(y0 + ((y1 - y0) * i) / n);
      const k = x * 1000 + y;
      if (seen.has(k)) continue;
      seen.add(k); this.sh(x, y, d);
    }
    return this;
  }

  render(o = {}) {
    const { w, h, mat, grp, adj, mats } = this;
    const n = w * h;
    // 1. distance to the edge of each part (two-pass chamfer restricted to the same part)
    const d = new Float32Array(n).fill(99);
    const same = (i, j) => grp[j] === grp[i] && mat[j] >= 0;
    for (let y = 0; y < h; y++) for (let x = 0; x < w; x++) {
      const i = y * w + x;
      if (mat[i] < 0) continue;
      if (x === 0 || y === 0 || x === w - 1 || y === h - 1 || !same(i, i - 1) || !same(i, i + 1) || !same(i, i - w) || !same(i, i + w)) d[i] = 1;
    }
    for (let y = 1; y < h - 1; y++) for (let x = 1; x < w - 1; x++) {
      const i = y * w + x;
      if (mat[i] < 0 || d[i] === 1) continue;
      let v = d[i];
      if (same(i, i - 1)) v = Math.min(v, d[i - 1] + 1);
      if (same(i, i - w)) v = Math.min(v, d[i - w] + 1);
      if (same(i, i - w - 1)) v = Math.min(v, d[i - w - 1] + 1.41);
      if (same(i, i - w + 1)) v = Math.min(v, d[i - w + 1] + 1.41);
      d[i] = v;
    }
    for (let y = h - 2; y > 0; y--) for (let x = w - 2; x > 0; x--) {
      const i = y * w + x;
      if (mat[i] < 0 || d[i] === 1) continue;
      let v = d[i];
      if (same(i, i + 1)) v = Math.min(v, d[i + 1] + 1);
      if (same(i, i + w)) v = Math.min(v, d[i + w] + 1);
      if (same(i, i + w + 1)) v = Math.min(v, d[i + w + 1] + 1.41);
      if (same(i, i + w - 1)) v = Math.min(v, d[i + w - 1] + 1.41);
      d[i] = v;
    }
    // 2. pseudo height: circular profile over `curve` px from the edge
    const hgt = new Float32Array(n);
    for (let i = 0; i < n; i++) {
      if (mat[i] < 0) continue;
      const R = mats[mat[i]].curve;
      const t = Math.min(d[i] - 0.5, R) / R;
      hgt[i] = Math.sqrt(Math.max(0, 1 - (1 - t) * (1 - t))) * R;
    }
    const out = new Uint32Array(n);
    const lam0 = L[2];
    const vgrad = o.vgrad ?? 0.7;
    const top = o.top ?? 0, bot = o.bot ?? h;
    const rgbCache = new Map();
    const pack = (hex) => {
      let v = rgbCache.get(hex);
      if (v === undefined) { const [r, g, b] = hexRgb(hex); v = (255 << 24) | (b << 16) | (g << 8) | r; rgbCache.set(hex, v); }
      return v;
    };
    for (let y = 0; y < h; y++) for (let x = 0; x < w; x++) {
      const i = y * w + x;
      const mi = mat[i];
      if (mi < 0) continue;
      const M = mats[mi];
      let tone = 2 + adj[i];
      if (!M.flat) {
        const hl = x > 0 && grp[i - 1] === grp[i] ? hgt[i - 1] : 0;
        const hr = x < w - 1 && grp[i + 1] === grp[i] ? hgt[i + 1] : 0;
        const hu = y > 0 && grp[i - w] === grp[i] ? hgt[i - w] : 0;
        const hd = y < h - 1 && grp[i + w] === grp[i] ? hgt[i + w] : 0;
        const gx = (hr - hl) * 0.5, gy = (hd - hu) * 0.5;
        const nl = Math.hypot(gx, gy, 1);
        const lam = (-gx * L[0] - gy * L[1] + L[2]) / nl;
        tone += (lam - lam0) * 3.2;
        if (M.spec && lam > 0.97) tone += 1;
        // ambient occlusion toward the bottom of the figure (feet sit in the dark)
        tone -= ((y - top) / Math.max(1, bot - top) - 0.35) * vgrad * M.ao;
        // contact shadow where another part overlaps this one
        for (const j of [i - 1, i + 1, i - w, i + w]) {
          if (j < 0 || j >= n || mat[j] < 0 || grp[j] === grp[i]) continue;
          if (grp[j] > grp[i]) { tone -= 0.9; break; }
        }
      }
      if (!M.glow) tone += BAYER[(y & 3) * 4 + (x & 3)] * M.dither;
      const k = clamp(Math.round(tone), 0, 4);
      out[i] = pack(M.r[k]);
    }
    // 3. outline: near-black tinted by the neighbouring material, darker along the bottom
    const ink = o.ink || '#07060c';
    for (let y = 0; y < h; y++) for (let x = 0; x < w; x++) {
      const i = y * w + x;
      if (mat[i] >= 0) continue;
      let nb = -1, below = false;
      if (y > 0 && mat[i - w] >= 0) { nb = mat[i - w]; below = true; }
      else if (x > 0 && mat[i - 1] >= 0) nb = mat[i - 1];
      else if (x < w - 1 && mat[i + 1] >= 0) nb = mat[i + 1];
      else if (y < h - 1 && mat[i + w] >= 0) nb = mat[i + w];
      if (nb < 0 || !mats[nb].outline || o.outline === false) continue;
      out[i] = pack(mix(mats[nb].r[0], ink, below ? 0.72 : 0.55));
    }
    const c = document.createElement('canvas');
    c.width = w; c.height = h;
    const g = c.getContext('2d');
    const id = g.createImageData(w, h);
    new Uint32Array(id.data.buffer).set(out);
    g.putImageData(id, 0, 0);
    return c;
  }
}
