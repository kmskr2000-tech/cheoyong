// Core: shared namespace, math helpers, seeded random, input (touch + keyboard).
'use strict';
const G = (window.G = window.G || {});

G.TILE = 32;
G.VIEW_H = 600; // logical screen height in world pixels
G.params = new URLSearchParams(location.search);
G.debug = G.params.has('debug');

// ---------- math ----------
G.clamp = (v, a, b) => (v < a ? a : v > b ? b : v);
G.lerp = (a, b, t) => a + (b - a) * t;
G.dist = (ax, ay, bx, by) => Math.hypot(bx - ax, by - ay);
G.angDiff = (a, b) => {
  let d = b - a;
  while (d > Math.PI) d -= Math.PI * 2;
  while (d < -Math.PI) d += Math.PI * 2;
  return d;
};
G.easeOut = (t) => 1 - (1 - t) * (1 - t);

// 8 directions in PixelLab naming, indexed by angle (0 = east, clockwise because y grows down)
G.DIR8 = ['east', 'south-east', 'south', 'south-west', 'west', 'north-west', 'north', 'north-east'];
G.dirFromAngle = (a) => G.DIR8[((Math.round(a / (Math.PI / 4)) % 8) + 8) % 8];
G.dir4FromAngle = (a) => ['east', 'south', 'west', 'north'][((Math.round(a / (Math.PI / 2)) % 4) + 4) % 4];

// ---------- seeded random ----------
G.rng = (seed) => {
  let s = seed >>> 0 || 1;
  return () => {
    s ^= s << 13; s >>>= 0;
    s ^= s >>> 17;
    s ^= s << 5; s >>>= 0;
    return s / 4294967296;
  };
};
G.hash2 = (x, y, seed = 0) => {
  let h = (x * 374761393 + y * 668265263 + seed * 2147483647) | 0;
  h = Math.imul(h ^ (h >>> 13), 1274126177);
  return ((h ^ (h >>> 16)) >>> 0) / 4294967296;
};
// smooth value noise in [0,1]
G.noise = (x, y, seed = 0) => {
  const xi = Math.floor(x), yi = Math.floor(y);
  const xf = x - xi, yf = y - yi;
  const u = xf * xf * (3 - 2 * xf), v = yf * yf * (3 - 2 * yf);
  const a = G.hash2(xi, yi, seed), b = G.hash2(xi + 1, yi, seed);
  const c = G.hash2(xi, yi + 1, seed), d = G.hash2(xi + 1, yi + 1, seed);
  return G.lerp(G.lerp(a, b, u), G.lerp(c, d, u), v);
};
G.fbm = (x, y, seed = 0) => (G.noise(x, y, seed) * 0.6 + G.noise(x * 2.1, y * 2.1, seed + 9) * 0.3 + G.noise(x * 4.3, y * 4.3, seed + 17) * 0.1);

// ---------- input ----------
// Actions: move (vector), attack, roll, skill1-3, ult, interact, item1, item2, mask, menu, confirm
G.input = (() => {
  const keys = new Set();
  const pressed = new Set(); // edge-triggered this frame
  const touchHeld = new Set();
  const stick = { active: false, id: null, ox: 0, oy: 0, x: 0, y: 0 };
  const KEYMAP = {
    KeyJ: 'attack', KeyZ: 'attack', KeyK: 'roll', ShiftLeft: 'roll', KeyX: 'roll', KeyU: 'skill1', KeyI: 'skill2',
    KeyO: 'skill3', KeyL: 'ult', KeyE: 'interact', Space: 'interact', Enter: 'confirm', Digit1: 'item1',
    Digit2: 'item2', KeyM: 'mask', Escape: 'menu', KeyP: 'menu', KeyC: 'interact',
  };
  const api = {
    stick, buttons: [], lastTouch: false,
    down(a) {
      for (const [k, v] of Object.entries(KEYMAP)) if (v === a && keys.has(k)) return true;
      return touchHeld.has(a) || !!(api.bot && api.bot.down.has(a));
    },
    hit(a) { return pressed.has(a); },
    press(a) { pressed.add(a); },
    endFrame() { pressed.clear(); },
    move() {
      let x = 0, y = 0;
      if (keys.has('KeyA') || keys.has('ArrowLeft')) x -= 1;
      if (keys.has('KeyD') || keys.has('ArrowRight')) x += 1;
      if (keys.has('KeyW') || keys.has('ArrowUp')) y -= 1;
      if (keys.has('KeyS') || keys.has('ArrowDown')) y += 1;
      if (stick.active) {
        const dx = stick.x - stick.ox, dy = stick.y - stick.oy;
        const m = Math.hypot(dx, dy), R = 46;
        if (m > 6) { x = dx / Math.max(m, R) ; y = dy / Math.max(m, R); }
      }
      if (api.bot && (api.bot.x || api.bot.y)) { x = api.bot.x; y = api.bot.y; }
      const m = Math.hypot(x, y);
      if (m > 1) { x /= m; y /= m; }
      return { x, y };
    },
    anyKey: false,
  };
  addEventListener('keydown', (e) => {
    if (e.repeat) return;
    keys.add(e.code);
    api.lastTouch = false;
    api.anyKey = true;
    const a = KEYMAP[e.code];
    if (a) pressed.add(a);
    if (e.code === 'Enter' || e.code === 'Space' || e.code === 'KeyJ' || e.code === 'KeyE') pressed.add('confirm');
    if (a || e.code.startsWith('Arrow')) e.preventDefault();
  });
  addEventListener('keyup', (e) => keys.delete(e.code));
  addEventListener('blur', () => keys.clear());

  // Touch: buttons are registered by the UI each frame with screen-space circles.
  const toLogical = (t) => G.screenToUI(t.clientX, t.clientY);
  const btnAt = (p) => api.buttons.find((b) => b.visible !== false && Math.hypot(p.x - b.x, p.y - b.y) <= b.r * 1.15);
  const touchOwner = new Map(); // touch id -> action or 'stick'
  const onStart = (e) => {
    e.preventDefault();
    api.lastTouch = true;
    G.audio && G.audio.unlock();
    for (const t of e.changedTouches) {
      const p = toLogical(t);
      const b = btnAt(p);
      if (b) {
        touchOwner.set(t.identifier, b.action);
        touchHeld.add(b.action);
        pressed.add(b.action);
        continue;
      }
      const modal = G.state !== 'play' || (G.ui && (G.ui.dialog || G.ui.shop || G.ui.menu));
      if (!modal && p.x < G.uiW * 0.5 && !stick.active) {
        stick.active = true; stick.id = t.identifier;
        stick.ox = stick.x = p.x; stick.oy = stick.y = p.y;
        touchOwner.set(t.identifier, 'stick');
      } else {
        api.tapPos = p;
        pressed.add('confirm');
        pressed.add('tap');
      }
    }
  };
  const onMove = (e) => {
    e.preventDefault();
    for (const t of e.changedTouches) {
      if (touchOwner.get(t.identifier) === 'stick') {
        const p = toLogical(t);
        stick.x = p.x; stick.y = p.y;
        // floating: drag the origin along when pulled far
        const dx = stick.x - stick.ox, dy = stick.y - stick.oy, m = Math.hypot(dx, dy);
        if (m > 70) { stick.ox = stick.x - (dx / m) * 70; stick.oy = stick.y - (dy / m) * 70; }
      }
    }
  };
  const onEnd = (e) => {
    e.preventDefault();
    for (const t of e.changedTouches) {
      const o = touchOwner.get(t.identifier);
      if (o === 'stick') { stick.active = false; stick.id = null; }
      else if (o) touchHeld.delete(o);
      touchOwner.delete(t.identifier);
    }
  };
  api.attach = (el) => {
    el.addEventListener('touchstart', onStart, { passive: false });
    el.addEventListener('touchmove', onMove, { passive: false });
    el.addEventListener('touchend', onEnd, { passive: false });
    el.addEventListener('touchcancel', onEnd, { passive: false });
    el.addEventListener('mousedown', (e) => {
      G.audio && G.audio.unlock();
      const p = G.screenToUI(e.clientX, e.clientY);
      const b = btnAt(p);
      if (b) { pressed.add(b.action); touchHeld.add(b.action); api._mouseBtn = b.action; }
      else { api.tapPos = p; pressed.add('confirm'); pressed.add('tap'); }
    });
    addEventListener('mouseup', () => { if (api._mouseBtn) touchHeld.delete(api._mouseBtn); api._mouseBtn = null; });
  };
  return api;
})();
