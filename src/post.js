// HD-2D style rendering on plain Canvas 2D (no engine, no WebGL):
//   colored lightmap (multiply) + dynamic lights, bloom (self-multiply bright pass + small Kawase-like blur),
//   tilt-shift depth of field, foreground parallax, moonlight shafts, color grade, vignette,
//   ambient particles and sprite rim light.
// Everything that can be precomputed is cached; per frame we only issue drawImage calls on small canvases.
import { G, VIEW_W, VIEW_H } from './state.js';
import { makeCanvas, PROPS } from './gfx.js';

// post passes run on the logical-resolution world canvas (480x270)
const W = VIEW_W, H = VIEW_H;
let worldC = null, worldG = null;
export function worldTarget() { if (!worldC) [worldC, worldG] = makeCanvas(VIEW_W, VIEW_H); return [worldC, worldG]; }
const TAU = Math.PI * 2;
const rand = (a, b) => a + Math.random() * (b - a);

// quality: 2 = full, 1 = no tilt-shift / lighter bloom, 0 = lightmap only
export const FX = { quality: 2, lights: [], auto: true };

// Per-level look. amb = multiply color of unlit areas (moonlit blue outdoors, deep indigo indoors).
const LOOK = {
  village: { amb: [104, 118, 178], grade: ['#2a3a7a', 0.22], rays: '170,190,255', fg: true, motes: 'firefly', tilt: 1 },
  field: { amb: [84, 100, 152], grade: ['#1e3a5a', 0.26], rays: '160,200,240', fg: true, motes: 'spore', tilt: 1 },
  dungeon1: { amb: [60, 64, 98], grade: ['#24402e', 0.24], rays: null, fg: false, motes: 'dust', tilt: 0.8 },
  dungeon2: { amb: [56, 66, 86], grade: ['#1e4a2a', 0.28], rays: null, fg: false, motes: 'dust', tilt: 0.8 },
};
const look = (lvl) => LOOK[lvl.id] || LOOK.dungeon1;

// ------------------------------------------------------------------ cached canvases
const lightSprites = new Map();
function lightSprite(color) {
  let c = lightSprites.get(color);
  if (!c) {
    let g; [c, g] = makeCanvas(64, 64);
    const gr = g.createRadialGradient(32, 32, 0, 32, 32, 32);
    gr.addColorStop(0, `rgba(${color},1)`);
    gr.addColorStop(0.35, `rgba(${color},0.55)`);
    gr.addColorStop(0.7, `rgba(${color},0.16)`);
    gr.addColorStop(1, `rgba(${color},0)`);
    g.fillStyle = gr; g.fillRect(0, 0, 64, 64);
    lightSprites.set(color, c);
  }
  return c;
}

const LW = VIEW_W / 2, LH = Math.ceil(VIEW_H / 2); // lightmap at half logical resolution, upscaled smoothly
const [lightC, lightG] = makeCanvas(LW, LH);
const [b1, b1g] = makeCanvas(240, 135);
const [b3, b3g] = makeCanvas(120, 68);
const [bt, btg] = makeCanvas(120, 68);
const [tiltC, tiltG] = makeCanvas(240, 135);
const [tt, ttg] = makeCanvas(240, 135);

let tiltMask = null, vignette = null, rays = null;
function getTiltMask() {
  if (tiltMask) return tiltMask;
  const [c, g] = makeCanvas(tiltC.width, tiltC.height);
  const gr = g.createLinearGradient(0, 0, 0, c.height);
  gr.addColorStop(0, 'rgba(0,0,0,1)');
  gr.addColorStop(0.17, 'rgba(0,0,0,0)');
  gr.addColorStop(0.86, 'rgba(0,0,0,0)');
  gr.addColorStop(1, 'rgba(0,0,0,1)');
  g.fillStyle = gr; g.fillRect(0, 0, c.width, c.height);
  return (tiltMask = c);
}
function getVignette() {
  if (vignette) return vignette;
  const [c, g] = makeCanvas(W, H);
  const gr = g.createRadialGradient(W / 2, H * 0.48, H * 0.32, W / 2, H * 0.48, W * 0.62);
  gr.addColorStop(0, 'rgba(4,4,12,0)');
  gr.addColorStop(0.55, 'rgba(4,4,12,0.22)');
  gr.addColorStop(1, 'rgba(2,2,8,0.72)');
  g.fillStyle = gr; g.fillRect(0, 0, W, H);
  return (vignette = c);
}
// moonlight shafts, white so the per-level color can be applied by tinting
function getRays() {
  if (rays) return rays;
  const [c, g] = makeCanvas(W + 200, H);
  const shafts = [[30, 35, 0.9], [125, 20, 0.6], [210, 45, 1], [350, 28, 0.7], [465, 40, 0.85], [575, 22, 0.6]];
  for (const [x, w, a] of shafts) {
    const gr = g.createLinearGradient(0, 0, 0, H);
    gr.addColorStop(0, `rgba(255,255,255,${0.55 * a})`);
    gr.addColorStop(0.6, `rgba(255,255,255,${0.18 * a})`);
    gr.addColorStop(1, 'rgba(255,255,255,0)');
    g.fillStyle = gr;
    g.beginPath(); g.moveTo(x, 0); g.lineTo(x + w, 0); g.lineTo(x + w + 110, H); g.lineTo(x + 110, H); g.closePath(); g.fill();
  }
  return (rays = c);
}
const tintStore = new Map();
function tinted(src, color) {
  let m = tintStore.get(src);
  if (!m) { m = new Map(); tintStore.set(src, m); }
  let c = m.get(color);
  if (!c) {
    let g; [c, g] = makeCanvas(src.width, src.height);
    g.drawImage(src, 0, 0);
    g.globalCompositeOperation = 'source-atop';
    g.fillStyle = color; g.fillRect(0, 0, src.width, src.height);
    m.set(color, c);
  }
  return c;
}
let shadowCache = new Map();
// soft elliptical contact shadow (replaces the old 3px rectangles)
export function shadow(g, x, y, w) {
  w = Math.max(6, Math.round(w));
  let c = shadowCache.get(w);
  if (!c) {
    const h = Math.max(4, Math.round(w * 0.4));
    let sg; [c, sg] = makeCanvas(w + 4, h + 2);
    sg.save(); sg.translate((w + 4) / 2, (h + 2) / 2); sg.scale(1, h / w);
    const gr = sg.createRadialGradient(0, 0, 0, 0, 0, w / 2 + 1);
    gr.addColorStop(0, 'rgba(0,0,0,0.55)'); gr.addColorStop(0.6, 'rgba(0,0,0,0.35)'); gr.addColorStop(1, 'rgba(0,0,0,0)');
    sg.fillStyle = gr; sg.beginPath(); sg.arc(0, 0, w / 2 + 1, 0, TAU); sg.fill(); sg.restore();
    shadowCache.set(w, c);
  }
  g.drawImage(c, Math.round(x - c.width / 2), Math.round(y - c.height / 2 - 1));
}

// ------------------------------------------------------------------ dynamic lights
const hexRgb = (h) => {
  if (!h || h[0] !== '#') return '255,255,255';
  const n = parseInt(h.length === 4 ? h.slice(1).split('').map((c) => c + c).join('') : h.slice(1, 7), 16);
  return `${(n >> 16) & 255},${(n >> 8) & 255},${n & 255}`;
};
const flick = (l) => (l.flicker ? 1 + Math.sin(G.time * 9 + l.x) * 0.05 + Math.sin(G.time * 23 + l.y) * 0.035 : 1);

function collectLights(lvl) {
  const L = [];
  // e = emissive: feeds additive glow + bloom. Non-emissive lights (player aura, auras) only lift the lightmap.
  const add = (x, y, r, color, a, e = true) => L.push({ x, y, r, color, a, e });
  for (const l of lvl.def.lights) add(l.x, l.y, l.r * 1.25 * flick(l), l.color, 0.95);
  const p = lvl.player;
  if (p && !p.dead) {
    add(p.x, p.y - 10, lvl.id === 'village' ? 64 : 82, '200,210,250', lvl.id === 'village' ? 0.4 : 0.6, false);
    if (p.songT > 0 || p.ultT > 0) add(p.x, p.y - 10, 90, '255,210,120', 0.35, false);
    if (p.shield > 0) add(p.x, p.y - 10, 40, '255,220,140', 0.3, false);
  }
  for (const z of lvl.zones) {
    const k = Math.min(1, z.ttl / 0.5) * Math.min(1, z.t / 0.2);
    if (z.kind === 'fire') add(z.x + Math.cos(z.ang) * z.r * 0.5, z.y + Math.sin(z.ang) * z.r * 0.5, 90 * (0.9 + Math.random() * 0.15), '255,140,60', 0.95 * k);
    else if (z.kind === 'bind') add(z.x, z.y, z.r + 26, '110,160,255', 0.4 * k, false);
    else if (z.kind === 'fog') add(z.x, z.y, z.r * 1.6, '120,230,90', 0.45 * k, false);
    else if (z.kind === 'tele') add(z.x, z.y, z.r * 1.5, '255,70,50', 0.7);
  }
  for (const v of lvl.vents) {
    if (v.state === 'bubble') add(v.x, v.y, 34, '255,80,60', 0.75);
    else if (v.state === 'erupt') add(v.x, v.y - 6, 48, '130,240,90', 0.8);
  }
  for (const pr of lvl.projectiles) add(pr.x, pr.y, 26, '150,240,90', 0.7);
  for (const f of lvl.fx) {
    if (f.half !== undefined && f.ttl > 0) add(f.x, f.y, f.r * 1.8, hexRgb(f.color), 0.75 * (f.ttl / f.max));
  }
  const b = lvl.boss;
  if (b && !b.dead && b.alpha > 0 && b.state !== 'human' && !(b.state === 'defeated' && b.vanishedForEnding)) {
    const tele = b.state === 'coughTele' || b.state === 'fogTele' || b.state === 'pulseTele';
    add(b.x, b.y - 20, tele ? 90 : 70, tele ? '255,80,60' : '120,230,100', 0.6 * b.alpha);
  }
  for (const m of motes) if (m.light) add(m.x, m.y, m.light, m.color, m.a * 0.6);
  return L;
}

// ------------------------------------------------------------------ ambient particles
let motes = [], motesLevel = null;
function updateMotes(lvl, dt, cx, cy) {
  if (motesLevel !== lvl) { motes = []; motesLevel = lvl; }
  const kind = look(lvl).motes;
  const cap = kind === 'firefly' ? 26 : kind === 'dust' ? 40 : 34;
  let tries = 3;
  while (motes.length < cap && tries--) {
    const x = cx + rand(-20, VIEW_W + 20), y = cy + rand(-20, VIEW_H + 20);
    if (kind === 'firefly') motes.push({ x, y, vx: 0, vy: 0, life: rand(4, 9), max: 0, ph: rand(0, TAU), color: '220,255,130', size: 1, light: 14, a: 0 });
    else if (kind === 'spore') motes.push({ x, y, vx: rand(-3, 3), vy: -rand(3, 8), life: rand(3, 7), max: 0, ph: rand(0, TAU), color: '150,230,90', size: 1, light: 0, a: 0 });
    else motes.push({ x, y, vx: rand(-2, 2), vy: rand(-1, 2), life: rand(4, 9), max: 0, ph: rand(0, TAU), color: '230,220,190', size: 1, light: 0, a: 0 });
    motes[motes.length - 1].max = motes[motes.length - 1].life;
  }
  // embers rise from warm lights
  for (const l of lvl.def.lights) {
    if (l.color !== '255,190,100' || Math.random() > dt * 2.2) continue;
    if (l.x < cx - 40 || l.x > cx + VIEW_W + 40 || l.y < cy - 40 || l.y > cy + VIEW_H + 60) continue;
    motes.push({ x: l.x + rand(-3, 3), y: l.y - 4, vx: rand(-6, 6), vy: -rand(14, 26), life: rand(0.8, 1.6), max: 1.6, ph: rand(0, TAU), color: '255,170,80', size: 1, light: 0, a: 0, ember: true });
  }
  for (const m of motes) {
    m.life -= dt; m.ph += dt;
    if (kind === 'firefly' && !m.ember) { m.vx += Math.cos(m.ph * 1.3) * 12 * dt; m.vy += Math.sin(m.ph * 0.9) * 10 * dt; m.vx *= 0.98; m.vy *= 0.98; }
    if (m.ember) m.vx += Math.sin(m.ph * 8) * 20 * dt;
    m.x += m.vx * dt; m.y += m.vy * dt;
    const fade = Math.min(1, m.life / 0.6, (m.max - m.life) / 0.6);
    const blink = kind === 'firefly' && !m.ember ? 0.5 + 0.5 * Math.sin(m.ph * 3) : 1;
    m.a = Math.max(0, fade * blink);
  }
  motes = motes.filter((m) => m.life > 0 && m.x > cx - 60 && m.x < cx + VIEW_W + 60 && m.y > cy - 80 && m.y < cy + VIEW_H + 60);
  if (motes.length > 140) motes.splice(0, motes.length - 140);
}
function drawMotes(g, cx, cy, scale, bright) {
  g.save();
  g.globalCompositeOperation = 'lighter';
  for (const m of motes) {
    if (m.a <= 0.02) continue;
    g.globalAlpha = Math.min(1, m.a * (bright ? 1 : 0.85));
    g.fillStyle = `rgb(${m.color})`;
    const s = Math.max(1, Math.round(m.size * scale));
    g.fillRect(Math.round((m.x - cx) * scale), Math.round((m.y - cy) * scale), s, s);
  }
  g.restore();
}

// ------------------------------------------------------------------ main passes
// Called from Level.render in world space (ctx is the 480x270 world canvas, translated by -cam).
export function renderLightmap(ctx, lvl, cx, cy, dt) {
  updateMotes(lvl, dt, cx, cy);
  const lk = look(lvl);
  FX.lights = collectLights(lvl);
  const g = lightG;
  g.globalCompositeOperation = 'source-over';
  g.globalAlpha = 1;
  g.fillStyle = `rgb(${lk.amb[0]},${lk.amb[1]},${lk.amb[2]})`;
  g.fillRect(0, 0, LW, LH);
  g.globalCompositeOperation = 'lighter';
  const k = LW / VIEW_W;
  for (const l of FX.lights) {
    const x = (l.x - cx) * k, y = (l.y - cy) * k, r = l.r * k;
    if (x < -r || y < -r || x > LW + r || y > LH + r || l.a <= 0.01) continue;
    g.globalAlpha = Math.min(1, l.a);
    g.drawImage(lightSprite(l.color), x - r, y - r, r * 2, r * 2);
  }
  g.globalAlpha = 1;
  g.globalCompositeOperation = 'source-over';
  // world-space motes drawn on the scene before lighting would be darkened; draw them after
  ctx.save();
  ctx.imageSmoothingEnabled = true;
  ctx.globalCompositeOperation = 'multiply';
  ctx.drawImage(lightC, cx, cy, VIEW_W, VIEW_H);
  // additive glow so lit areas get warmer/brighter than daylight, not just "less dark"
  ctx.globalCompositeOperation = 'lighter';
  for (const l of FX.lights) {
    const r = l.r * 0.8;
    if (!l.e || l.x < cx - r || l.y < cy - r || l.x > cx + VIEW_W + r || l.y > cy + VIEW_H + r || l.a <= 0.01) continue;
    ctx.globalAlpha = Math.min(1, l.a) * 0.3;
    ctx.drawImage(lightSprite(l.color), l.x - r, l.y - r, r * 2, r * 2);
  }
  ctx.restore();
  ctx.imageSmoothingEnabled = false;
}

// Re-draw ground telegraphs on top of the lightmap so warnings never get lost in the dark.
export function redrawTelegraphs(ctx, lvl) {
  ctx.save();
  ctx.globalAlpha = 0.55;
  ctx.globalCompositeOperation = 'lighter';
  for (const z of lvl.zones) if (z.kind === 'tele' || z.kind === 'bind') z.drawGround(ctx);
  if (lvl.boss) lvl.boss.drawGround(ctx);
  ctx.restore();
}

// Screen-space finishing passes. ctx transform must be identity; reads ctx.canvas.
export function finish(ctx, lvl, cx, cy) {
  const lk = look(lvl);
  const q = FX.quality;
  const canvas = ctx.canvas;
  ctx.save();
  ctx.setTransform(1, 0, 0, 1, 0, 0);
  // motes (additive) on top of lighting
  drawMotes(ctx, cx, cy, 1, true);
  // moonlight shafts drift slowly with parallax
  if (lk.rays && q >= 1) {
    const r = getRays();
    const off = -((cx * 0.35 + G.time * 3) % 200 + 200) % 200;
    ctx.globalCompositeOperation = 'lighter';
    ctx.globalAlpha = 0.07 + Math.sin(G.time * 0.6) * 0.015;
    ctx.drawImage(tinted(r, `rgb(${lk.rays})`), off, 0);
    ctx.globalAlpha = 1;
    ctx.globalCompositeOperation = 'source-over';
  }
  // foreground parallax silhouettes (bottom edge), they fall inside the tilt-shift band
  if (lk.fg) drawForeground(ctx, lvl, cx, cy);
  // color grade
  ctx.globalCompositeOperation = 'soft-light';
  ctx.globalAlpha = lk.grade[1];
  ctx.fillStyle = lk.grade[0];
  ctx.fillRect(0, 0, W, H);
  ctx.globalAlpha = 1;
  ctx.globalCompositeOperation = 'source-over';
  ctx.imageSmoothingEnabled = true;
  // one shared half-res downsample feeds both tilt-shift and bloom
  if (q >= 1) {
    b1g.imageSmoothingEnabled = true;
    b1g.globalCompositeOperation = 'copy'; b1g.drawImage(canvas, 0, 0, b1.width, b1.height); b1g.globalCompositeOperation = 'source-over';
  }
  // tilt-shift depth of field: blurred copy masked to the top/bottom bands
  if (q >= 2) {
    tiltG.globalCompositeOperation = 'source-over';
    tiltG.imageSmoothingEnabled = true;
    tiltG.clearRect(0, 0, tiltC.width, tiltC.height);
    tiltG.drawImage(b1, 0, 0, tiltC.width, tiltC.height);
    blur(tiltC, tiltG, tt, ttg, 2);
    tiltG.globalCompositeOperation = 'destination-in';
    tiltG.drawImage(getTiltMask(), 0, 0);
    tiltG.globalCompositeOperation = 'source-over';
    ctx.globalAlpha = lk.tilt * (G.flags && G.flags.boss_fight ? 0.5 : 1);
    ctx.drawImage(tiltC, 0, 0, W, H);
    ctx.globalAlpha = 1;
  }
  // bloom: downsample, bright-pass by squaring twice (multiply with itself), blur, add back
  if (q >= 1) bloom(ctx, canvas, cx, cy, q >= 2 ? 0.7 : 0.5, true);
  ctx.drawImage(getVignette(), 0, 0);
  ctx.restore();
  ctx.imageSmoothingEnabled = false;
}

function blur(c, g, tmp, tg, passes) {
  for (let i = 0; i < passes; i++) {
    const d = i + 1;
    tg.globalCompositeOperation = 'source-over';
    tg.clearRect(0, 0, tmp.width, tmp.height);
    tg.globalCompositeOperation = 'lighter';
    tg.globalAlpha = 0.25;
    tg.drawImage(c, -d, -d); tg.drawImage(c, d, -d); tg.drawImage(c, -d, d); tg.drawImage(c, d, d);
    tg.globalAlpha = 1;
    tg.globalCompositeOperation = 'source-over';
    g.globalCompositeOperation = 'copy';
    g.drawImage(tmp, 0, 0);
    g.globalCompositeOperation = 'source-over';
  }
}

function bloom(ctx, canvas, cx, cy, strength, haveDown = false) {
  const tw = canvas.width, th = canvas.height;
  b1g.imageSmoothingEnabled = true; b3g.imageSmoothingEnabled = true;
  if (!haveDown) { b1g.globalCompositeOperation = 'copy'; b1g.drawImage(canvas, 0, 0, b1.width, b1.height); b1g.globalCompositeOperation = 'source-over'; }
  b3g.globalCompositeOperation = 'copy'; b3g.drawImage(b1, 0, 0, b3.width, b3.height);
  // bright pass: x^4 (multiply the image with itself twice) — no getImageData needed
  b3g.globalCompositeOperation = 'multiply'; b3g.drawImage(b3, 0, 0); b3g.drawImage(b3, 0, 0);
  // emissive lights feed the bloom directly so lanterns and talismans always glow
  b3g.globalCompositeOperation = 'lighter';
  const k = b3.width / VIEW_W;
  for (const l of FX.lights) {
    const r = l.r * k * 0.45, x = (l.x - cx) * k, y = (l.y - cy) * k;
    if (!l.e || x < -r || y < -r || x > b3.width + r || y > b3.height + r) continue;
    b3g.globalAlpha = Math.min(1, l.a) * 0.45;
    b3g.drawImage(lightSprite(l.color), x - r, y - r, r * 2, r * 2);
  }
  b3g.globalAlpha = 1;
  b3g.globalCompositeOperation = 'source-over';
  drawMotes(b3g, cx, cy, k, false);
  blur(b3, b3g, bt, btg, 2);
  ctx.globalCompositeOperation = 'lighter';
  ctx.globalAlpha = strength;
  ctx.drawImage(b3, 0, 0, tw, th);
  ctx.globalAlpha = 1;
  ctx.globalCompositeOperation = 'source-over';
}

// Foreground silhouettes: pine tops poking in from the bottom edge, moving faster than the world.
function drawForeground(ctx, lvl, cx, cy) {
  const pine = tinted(PROPS.pine(), '#05070c');
  const par = 1.35, spacing = 150;
  const base = cx * par;
  ctx.save();
  for (let i = Math.floor(base / spacing) - 1; i <= Math.floor((base + VIEW_W) / spacing) + 1; i++) {
    const seed = Math.abs(Math.sin(i * 12.9898) * 43758.5453) % 1;
    if (seed < 0.35) continue;
    const sx = i * spacing + seed * 70 - base;
    if (sx < -100 || sx > W + 50) continue;
    const s = 2.2 + seed * 0.8;
    const sy = H - 26 * (0.5 + seed * 0.5);
    ctx.globalAlpha = 0.92;
    ctx.drawImage(pine, sx, sy, 32 * s, 48 * s);
  }
  ctx.restore();
}

// Title screen: bloom + vignette only (text is drawn afterwards, so it stays crisp).
export function finishTitle(ctx) {
  ctx.save();
  ctx.setTransform(1, 0, 0, 1, 0, 0);
  ctx.imageSmoothingEnabled = true;
  FX.lights = [];
  if (FX.quality >= 1) bloom(ctx, ctx.canvas, 0, 0, 0.55);
  ctx.drawImage(getVignette(), 0, 0, ctx.canvas.width, ctx.canvas.height);
  ctx.restore();
  ctx.imageSmoothingEnabled = false;
}

// Rim light: a 1px silhouette in the nearest light's color, offset toward that light, drawn behind the sprite.
export function rim(g, spr, dx, dy, wx, wy) {
  if (FX.quality < 1) return;
  let best = null, bs = 0;
  for (const l of FX.lights) {
    const d = Math.hypot(l.x - wx, l.y - (wy - 8));
    if (d < 3 || d > l.r) continue;
    const s = (1 - d / l.r) * l.a;
    if (s > bs) { bs = s; best = l; }
  }
  if (!best || bs < 0.12) return;
  const ang = Math.atan2(best.y - (wy - 8), best.x - wx);
  const ox = Math.round(Math.cos(ang)), oy = Math.round(Math.sin(ang));
  if (!ox && !oy) return;
  g.save();
  g.globalAlpha = Math.min(0.9, bs * 1.6);
  g.drawImage(tinted(spr, `rgb(${best.color})`), dx + ox, dy + oy);
  g.restore();
}

// Auto quality: measured on render CPU time (not rAF dt, which is 30 Hz on low-power phones anyway).
// If world rendering alone averages over 9 ms, drop to the next cheaper tier.
let perfAcc = 0, perfN = 0;
export function trackRender(ms) {
  if (!FX.auto) return;
  perfAcc += ms; perfN++;
  if (perfN >= 90) {
    if (perfAcc / perfN > 9 && FX.quality > 0) FX.quality--;
    perfAcc = 0; perfN = 0;
  }
}
let lastT = 0;
export function frameDt() { const d = Math.min(0.1, Math.max(0, G.time - lastT)); lastT = G.time; return d; }
