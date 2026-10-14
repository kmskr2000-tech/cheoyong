// Character art for the HD-2D pass: ~4.3-head realistic proportions, shaded with the Painter.
// Every sprite is anchored at the feet: bottom-centre of the canvas is where the character stands.
import { Painter, ramp, mix } from './paint.js';

export const HW = 26, HH = 42; // human sprite canvas
const CX = 13, F = 40; // centre line, feet row

const SKIN = '#c49a80', SKIN_PALE = '#c9b8a0', SKIN_SICK = '#a9b08a';

// ---------------------------------------------------------------- humans
// o: { skin, hair, robe, trim, belt, inner, pants, shoes, outfit, head, beard, female, child, staff, sick, ghost }
export function human(o, dir = 'down', frame = 0) {
  const P = new Painter(HW, HH);
  const M = {
    skin: P.m({ c: o.skin || SKIN, curve: 2.2, dither: 0.15, hue: 4, spread: 0.85 }),
    hair: P.m({ c: o.hair || '#1c1a22', curve: 2, dither: 0.4, spread: 1.15 }),
    robe: P.m({ c: o.robe || '#3b3f52', curve: 3, dither: 0.2 }),
    trim: P.m({ c: o.trim || '#8a6a3a', curve: 1.2, dither: 0.3 }),
    belt: P.m({ c: o.belt || '#b08a3e', curve: 1, spec: true, dither: 0 }),
    inner: P.m({ c: o.inner || '#cfc6b0', curve: 1.2, dither: 0.3 }),
    pants: P.m({ c: o.pants || mix(o.robe || '#3b3f52', '#000000', 0.25), curve: 2, dither: 0.5 }),
    shoes: P.m({ c: o.shoes || '#2a2420', curve: 1, dither: 0 }),
    hat: P.m({ c: o.hatC || '#1b1a22', curve: 2.4, dither: 0.3, spec: true, spread: 1.2 }),
    gold: P.m({ c: '#c9a24a', curve: 1, spec: true, dither: 0 }),
    eye: P.m({ c: '#100c10', flat: true, outline: false, dither: 0 }),
    eyeW: P.m({ c: o.eyeC || '#d8d0c0', flat: true, outline: false, dither: 0 }),
    staff: P.m({ c: '#5a3e26', curve: 1, dither: 0 }),
  };
  const side = dir === 'right';
  const back = dir === 'up';
  const short = o.child ? 9 : o.female ? 2 : 0; // body shortening (head stays the same size)
  const yS = 13 + short; // shoulder row
  const yB = 21 + Math.round(short * 0.6); // belt row
  const headY = 8 + short; // head centre
  const step = frame === 1 ? 1 : frame === 2 ? -1 : 0;
  const stoop = o.stoop ? 1 : 0;

  // --- back layer: long hair hanging behind the body
  if (o.female || o.head === 'long') {
    P.part();
    const hw = side ? 3 : 4;
    const hx = side ? CX - 2 : CX;
    P.poly([[hx - hw, headY], [hx + hw, headY], [hx + hw + 0.5, yS + 9], [hx - hw - 0.5, yS + 9]], M.hair);
    if (!back) P.shRect(hx - hw, headY + 4, hw * 2, 10, -0.4);
  }

  // --- feet / legs
  P.part();
  if (o.outfit === 'jeogori' || o.outfit === 'rags') {
    // baji trousers with leg wraps
    const legTop = yB + 1;
    if (side) {
      P.poly([[CX - 3, legTop], [CX + 2, legTop], [CX + 2 + step, F - 2], [CX - 2 + step, F - 2]], M.pants);
      P.poly([[CX - 3, legTop], [CX + 1, legTop], [CX - step, F - 2], [CX - 3 - step, F - 2]], M.pants);
      P.rect(CX - 1 + step, F - 1, 4, 2, M.shoes); P.rect(CX - 3 - step, F - 1, 3, 2, M.shoes);
    } else {
      const l = frame === 1 ? -1 : 0, r = frame === 2 ? -1 : 0;
      P.poly([[CX - 5, legTop], [CX, legTop], [CX - 0.5, F - 2 + l], [CX - 4.5, F - 2 + l]], M.pants);
      P.poly([[CX, legTop], [CX + 5, legTop], [CX + 4.5, F - 2 + r], [CX + 0.5, F - 2 + r]], M.pants);
      P.shLine(CX, legTop + 1, CX, F - 3, -1);
      P.rect(CX - 4, F - 1 + l, 4, 2, M.shoes); P.rect(CX, F - 1 + r, 4, 2, M.shoes);
      P.shRect(CX - 4, F - 6 + l, 4, 1, -0.6); P.shRect(CX, F - 6 + r, 4, 1, -0.6);
    }
  } else {
    // shoes peeking out under a long hem
    if (side) { P.rect(CX - 2 + step * 2, F - 1, 5, 2, M.shoes); P.rect(CX - 3 - step * 2, F - 1, 4, 2, M.shoes); }
    else {
      P.rect(CX - 4, F - 1 - (frame === 1 ? 1 : 0), 3, 2, M.shoes);
      P.rect(CX + 1, F - 1 - (frame === 2 ? 1 : 0), 3, 2, M.shoes);
    }
  }

  // --- body garment
  P.part();
  const sw = side ? 4 : 5.5; // half shoulder width
  if (o.outfit === 'skirt') {
    // jeogori + full chima from a high waist
    const yW = yS + 4;
    const hem = side ? 6 : 8;
    P.poly([[CX - sw + 1, yW], [CX + sw - 1, yW], [CX + hem + (side ? 1 : 0) + step * 0.5, F - 1], [CX - hem + step * 0.5, F - 1]], M.robe);
    for (const fx of side ? [-2, 1, 4] : [-5, -2, 1, 4]) P.shLine(CX + fx * 0.6, yW + 3, CX + fx + step * 0.5, F - 2, -0.8);
    P.shRect(CX - hem, F - 3, hem * 2 + 1, 2, -0.5);
    P.part();
    P.poly([[CX - sw, yS], [CX + sw, yS], [CX + sw + 0.5, yW + 1], [CX - sw - 0.5, yW + 1]], M.inner);
    if (!back) { P.part(); P.rect(side ? CX + 1 : CX - 1, yW - 1, 2, 1, M.trim); P.line(side ? CX + 2 : CX, yW, side ? CX + 2 : CX + 1, yW + 5, M.trim); }
  } else if (o.outfit === 'jeogori' || o.outfit === 'rags') {
    const hemY = yB + 3;
    P.poly([[CX - sw, yS], [CX + sw, yS], [CX + sw + 1, hemY], [CX - sw - 1, hemY]], M.robe);
    if (!back && !side) { P.shLine(CX - 1, yS + 1, CX + 2, yB - 1, -1.2); }
    if (o.outfit === 'rags') { for (let x = -sw; x <= sw; x += 2) P.clear(CX + x, hemY - ((x * 7) & 1)); P.shRect(CX - sw, yS + 3, 2, 3, -0.8); }
    P.part();
    P.rect(CX - sw - 1, yB, sw * 2 + 2, 1, M.trim);
  } else {
    // long round-collar robe (단령/도포): flares toward the hem, sways with the step
    const hem = side ? 6 : 7.5;
    const hemY = F - 1 - (o.outfit === 'longrobe' ? 0 : 1);
    const st = step * 0.7;
    if (side) {
      P.poly([[CX - 3, yS - 0.5], [CX + 3, yS - 0.5], [CX + 4, yS + 3], [CX + 3.5, yB + 2], [CX + 6 + st, hemY], [CX + 2 + st, hemY + 0.6], [CX - 5 + st, hemY], [CX - 4, yB + 2], [CX - 4.5, yS + 3]], M.robe);
    } else {
      // sloped shoulders, cinched at the belt, flaring hem that dips toward the viewer
      P.poly([[CX - 2.5, yS - 1], [CX + 2.5, yS - 1], [CX + sw - 0.5, yS + 1], [CX + sw - 1, yB], [CX + hem + st, hemY - 0.5], [CX + st, hemY + 0.7], [CX - hem + st, hemY - 0.5], [CX - sw + 1, yB], [CX - sw + 0.5, yS + 1]], M.robe);
    }
    // folds
    if (side) { P.shLine(CX - 1, yB + 2, CX - 3 + step, hemY - 1, -1); P.shLine(CX + 2, yB + 2, CX + 4 + step, hemY - 1, -0.8); }
    else {
      P.shLine(CX - 2, yB + 2, CX - 4 + step * 0.5, hemY - 1, -1);
      P.shLine(CX + 2, yB + 2, CX + 4 + step * 0.5, hemY - 1, -0.9);
      P.shLine(CX, yB + 3, CX + step * 0.5, hemY - 1, -0.6);
      if (!back) { P.shLine(CX, yS + 2, CX, yB - 1, -0.7); }
    }
    P.shRect(CX - hem, hemY - 1, hem * 2 + 2, 1, -0.5);
    if (o.trim && o.outfit !== 'plain') { P.part(); P.rect(CX - hem + 1 + Math.round(step * 0.7), hemY, hem * 2 - 1, 1, M.trim); }
    // belt (요대) with a buckle
    P.part();
    if (side) P.rect(CX - 4, yB, 8, 2, M.belt); else P.rect(CX - 5, yB, 10, 2, M.belt);
    if (!back) { P.part(); P.rect(side ? CX + 1 : CX - 1, yB, 2, 2, M.gold); }
  }

  // --- collar
  if (!back && o.outfit !== 'skirt') {
    P.part();
    if (side) P.rect(CX + 1, yS, 2, 3, M.inner);
    else if (o.outfit === 'jeogori' || o.outfit === 'rags') { P.line(CX - 2, yS, CX + 1, yS + 4, M.inner); P.line(CX + 2, yS, CX, yS + 2, M.inner); }
    else { P.ellipse(CX, yS + 0.5, 2.6, 2, M.inner); P.part(); P.ellipse(CX, yS - 0.2, 1.6, 1.3, M.skin); }
  }

  // --- arms in wide sleeves
  // bell sleeve: narrow at the shoulder, hanging wide at the cuff; s = -1 left, +1 right (front/back views)
  const yH = yB + 4 + (o.child ? -2 : 0);
  const sleeve = (s, swing) => {
    P.part();
    const xs = CX + s * (sw - 1); // shoulder joint
    const sy = swing; // vertical swing of the cuff
    P.poly([[xs, yS], [xs + s * 2.2, yS + 1], [xs + s * 3.2, yB - 1 + sy], [xs + s * 3.6, yH + sy], [xs + s * 0.2, yH + 1 + sy], [xs - s * 0.6, yB - 2]], M.robe);
    P.shLine(xs + s * 0.6, yS + 3, xs + s * 1.2, yH - 1 + sy, -0.9);
    if (o.cuff !== false) { P.part(); P.line(xs + s * 3.6, yH + sy, xs + s * 0.2, yH + 1 + sy, M.trim); }
    P.part(); P.rect(Math.round(xs + s * 1.4 - 1), yH + 1 + sy, 2, 2, M.skin);
  };
  if (side) {
    P.part();
    const sx = CX + 0.5, sg = -step * 1.6;
    P.poly([[sx - 1.5, yS], [sx + 1.8, yS], [sx + 2.5 + sg, yB], [sx + 3 + sg, yH], [sx - 2.5 + sg, yH + 1], [sx - 2.4, yB - 1]], M.robe);
    P.shLine(sx - 1, yS + 3, sx - 1.5 + sg, yH, -1);
    P.part(); P.line(sx - 2.5 + sg, yH + 1, sx + 3 + sg, yH, M.trim);
    P.part(); P.rect(Math.round(sx + sg), yH + 1, 2, 2, M.skin);
    if (o.staff) { P.part(); P.line(CX + 4, yS + 4, CX + 5, F, M.staff, 1); }
  } else {
    sleeve(-1, frame === 1 ? -1 : 0);
    sleeve(1, frame === 2 ? -1 : 0);
    if (o.staff && !back) { P.part(); P.line(CX + sw + 3, yS + 5, CX + sw + 3.5, F, M.staff, 1); }
  }

  // --- head
  P.part();
  const hx = side ? CX + 1 + stoop : CX;
  const hy = headY + stoop;
  P.ellipse(hx, hy, 3.6, 4.3, M.skin);
  P.rect(hx - 1, hy + 3, 2, 2, M.skin); // neck
  if (side) { P.set(hx + 3, hy + 0, M.skin); P.set(hx + 3, hy + 1, M.skin); } // nose
  // jaw shading + eye sockets: the face reads stern, not cute
  if (!back) {
    if (side) {
      P.shRect(hx - 1, hy - 1, 3, 1, -1.1); // brow shadow
      P.set(hx + 1, hy, M.eye);
      P.sh(hx + 2, hy + 2, -1); P.sh(hx + 1, hy + 3, -0.8); // mouth
      P.shRect(hx - 2, hy + 1, 2, 3, -0.7); // cheek/jaw
      P.set(hx - 2, hy, M.skin); P.sh(hx - 2, hy, -1); // ear
    } else {
      P.shRect(hx - 3, hy - 1, 7, 1, -1.0); // brows
      P.set(hx - 2, hy, M.eye); P.set(hx + 1, hy, M.eye);
      if (o.eyeGlow) { P.set(hx - 2, hy, M.eyeW); P.set(hx + 1, hy, M.eyeW); }
      P.sh(hx, hy + 1, -0.6); P.sh(hx, hy + 2, -0.9); // nose shadow
      P.shRect(hx - 1, hy + 3, 2, 1, -1.1); // mouth line
      P.shRect(hx - 3, hy + 1, 1, 2, -0.5); P.shRect(hx + 2, hy + 1, 1, 2, -0.8);
      if (o.sick || o.ghost) { P.shRect(hx - 2, hy + 1, 1, 1, -0.8); P.shRect(hx + 1, hy + 1, 1, 1, -0.8); }
    }
  }
  // beard
  if (o.beard && !back) {
    P.part();
    const bm = o.beard === 'white' ? P.m({ c: '#c8c4bc', curve: 1.6, dither: 0.3 }) : M.hair;
    if (side) P.poly([[hx - 1, hy + 2], [hx + 3, hy + 2], [hx + 2, hy + (o.beard === 'long' || o.beard === 'white' ? 8 : 5)], [hx, hy + 4]], bm);
    else {
      P.poly([[hx - 3, hy + 2], [hx + 3, hy + 2], [hx + 1, hy + (o.beard === 'long' || o.beard === 'white' ? 9 : 5)], [hx - 1, hy + (o.beard === 'long' || o.beard === 'white' ? 9 : 5)]], bm);
      P.clear(hx - 1, hy + 3); P.clear(hx, hy + 3);
      P.set(hx - 1, hy + 3, M.skin); P.set(hx, hy + 3, M.skin); P.sh(hx - 1, hy + 3, -1.2); P.sh(hx, hy + 3, -1.2);
      P.part(); P.rect(hx - 3, hy + 2, 2, 1, bm); P.rect(hx + 1, hy + 2, 2, 1, bm); // moustache
    }
  }

  // --- hair & headwear
  P.part();
  const head = o.head || 'topknot';
  const hairCap = (low = 0) => {
    if (back) P.ellipse(hx, hy - 0.5, 3.8, 4.2 - low, M.hair);
    else if (side) { P.poly([[hx - 4, hy - 4], [hx + 3, hy - 4.5], [hx + 3.5, hy - 2], [hx, hy - 1.5], [hx - 1, hy + 1], [hx - 3, hy + 3], [hx - 4.2, hy + 1]], M.hair); }
    else { P.ellipse(hx, hy - 2.5, 3.9, 2.6, M.hair); P.rect(hx - 4, hy - 2, 1, 4 - low, M.hair); P.rect(hx + 3, hy - 2, 1, 4 - low, M.hair); }
  };
  if (head === 'boktu') {
    // 복두: rigid black silk cap with a raised rear crown and two long stiff wings (각)
    P.ellipse(hx, hy - 3, 4, 2.6, M.hat);
    P.ellipse(hx - (side ? 1.5 : 0), hy - 5.2, 2.6, 2, M.hat);
    P.rect(hx - 4, hy - 3, 8, 2, M.hat);
    P.part();
    if (!side) {
      P.rect(hx - 11, hy - 3, 7, 1, M.hat); P.rect(hx + 4, hy - 3, 7, 1, M.hat);
      P.set(hx - 11, hy - 4, M.hat); P.set(hx + 10, hy - 4, M.hat);
    } else { P.rect(hx - 6, hy - 3, 2, 1, M.hat); }
    P.part(); P.rect(hx - 4, hy - 1, 8, 1, M.hat); // band
    if (!back) P.sh(hx - 3, hy - 4, 1);
  } else if (head === 'topknot' || head === 'child') {
    hairCap();
    if (head === 'topknot') { P.part(); P.ellipse(hx - (side ? 1 : 0), hy - 6, 1.6, 1.6, M.hair); P.part(); P.rect(hx - 4, hy - 2, 8, 1, M.trim); } // 상투 + 망건
  } else if (head === 'bun') {
    hairCap(1);
    P.part();
    if (side) P.ellipse(hx - 4, hy - 1, 2.2, 2.4, M.hair); else if (back) P.ellipse(hx, hy + 2, 2.5, 2.2, M.hair);
    else P.ellipse(hx, hy - 5.5, 2.4, 1.6, M.hair);
    if (o.pin) { P.part(); if (side) P.rect(hx - 6, hy - 2, 4, 1, M.gold); else P.rect(hx + 1, hy - 6, 4, 1, M.gold); }
  } else if (head === 'scarf') {
    P.ellipse(hx, hy - 1.8, 4.2, 3.6, M.trim);
    if (!side && !back) P.clear(hx, hy + 1);
    P.part(); if (side) P.poly([[hx - 4, hy - 1], [hx - 2, hy], [hx - 4, hy + 6], [hx - 6, hy + 5]], M.trim);
  } else if (head === 'crown') {
    hairCap();
    P.part();
    // 신라 금관: band + 出-shaped uprights + antler-like side branches
    P.rect(hx - 4, hy - 4, 8, 2, M.gold);
    for (const ux of side ? [-1, 2] : [-3, 0, 2]) { P.rect(hx + ux, hy - 10, 1, 6, M.gold); P.rect(hx + ux - 1, hy - 8, 3, 1, M.gold); P.rect(hx + ux - 1, hy - 6, 3, 1, M.gold); }
    if (!side) { P.line(hx - 4, hy - 4, hx - 6, hy - 9, M.gold); P.line(hx + 3, hy - 4, hx + 5, hy - 9, M.gold); }
    P.part(); const jade = P.m({ c: '#4a9a7a', curve: 1, spec: true, dither: 0 });
    if (!side) { P.set(hx - 4, hy - 1, jade); P.set(hx + 3, hy - 1, jade); P.set(hx - 4, hy + 1, jade); P.set(hx + 3, hy + 1, jade); }
  } else if (head === 'dragon') {
    hairCap();
    P.part();
    const horn = P.m({ c: '#cfc2a0', curve: 1.2, dither: 0.2 });
    if (side) P.poly([[hx - 2, hy - 3], [hx, hy - 4], [hx - 4, hy - 10], [hx - 5, hy - 9]], horn);
    else { P.poly([[hx - 3, hy - 3], [hx - 1, hy - 4], [hx - 5, hy - 10], [hx - 6, hy - 9]], horn); P.poly([[hx + 3, hy - 3], [hx + 1, hy - 4], [hx + 5, hy - 10], [hx + 6, hy - 9]], horn); }
    P.part(); P.rect(hx - 3, hy - 5, 6, 2, M.gold); if (!side) P.rect(hx - 1, hy - 7, 2, 2, M.gold);
  } else if (head === 'long') {
    // loose long hair (역신 human disguise)
    hairCap(0);
    P.part(); if (!side && !back) { P.rect(hx - 5, hy - 2, 2, 9, M.hair); P.rect(hx + 3, hy - 2, 2, 9, M.hair); }
  } else if (head === 'bald') {
    P.sh(hx - 2, hy - 3, 1);
    P.part(); P.rect(hx - 4, hy - 2, 8, 1, M.trim);
  }
  if (head === 'child') { /* bangs */ if (!back && !side) { P.part(); P.rect(hx - 3, hy - 2, 6, 1, M.hair); P.clear(hx - 1, hy - 2); } }

  return P.render({ top: 2, bot: F, vgrad: 0.9 });
}

export function humanSet(o) {
  const set = { down: [], up: [], right: [], left: [] };
  for (let f = 0; f < 3; f++) {
    set.down.push(human(o, 'down', f));
    set.up.push(human(o, 'up', f));
    const r = human(o, 'right', f);
    set.right.push(r);
    set.left.push(flip(r));
  }
  return set;
}

export function flip(src) {
  const c = document.createElement('canvas');
  c.width = src.width; c.height = src.height;
  const g = c.getContext('2d');
  g.translate(src.width, 0); g.scale(-1, 1); g.drawImage(src, 0, 0);
  return c;
}

// ---------------------------------------------------------------- 처용
export const CHEOYONG = {
  head: 'boktu', robe: '#26305a', trim: '#7a6a44', belt: '#b8923e', inner: '#d2c8b2', shoes: '#1e1a1a',
  skin: '#c09478', outfit: 'longrobe', hatC: '#16151c',
};

// ---------------------------------------------------------------- 역병 들개 (gaunt plague hound, side view)
export function plagueDog(frame) {
  const P = new Painter(34, 22);
  const fur = P.m({ c: '#4a4440', curve: 2.4, dither: 0.7, spread: 1.1 });
  const furD = P.m({ c: '#2e2a2c', curve: 2, dither: 0.6 });
  const rot = P.m({ c: '#5f7a3a', curve: 1.6, dither: 0.6 });
  const eye = P.m({ c: '#c8ff70', flat: true, glow: true, outline: false });
  const teeth = P.m({ c: '#d8d0b0', flat: true, dither: 0 });
  const legPhase = frame === 1;
  // far legs (darker)
  P.part();
  const leg = (x, y, dx, m) => { P.line(x, y, x + dx, y + 5, m, 2); P.line(x + dx, y + 5, x + dx - 0.5, y + 9, m, 1.4); };
  leg(9, 10, legPhase ? 2 : -1, furD); leg(23, 10, legPhase ? -2 : 1, furD);
  // body: hunched spine, sunken belly
  P.part();
  P.poly([[6, 9], [10, 5], [17, 4], [23, 5], [27, 8], [26, 12], [20, 13], [13, 12], [8, 13]], fur);
  for (const rx of [15, 17, 19]) P.shLine(rx, 7, rx - 1, 12, -1.2); // ribs
  P.shRect(9, 11, 14, 1, -0.7);
  P.part(); P.ellipse(12, 7, 2.5, 1.6, rot); // open sore
  // tail: ragged
  P.part(); P.line(6, 9, 2, 6, fur, 1.6); P.line(2, 6, 1, 8, fur, 1);
  // near legs
  P.part();
  leg(11, 11, legPhase ? -1 : 2, fur); leg(25, 10, legPhase ? 1 : -2, fur);
  // neck + head low and forward
  P.part();
  P.poly([[23, 5], [27, 4], [30, 7], [28, 10], [25, 10]], fur);
  P.part();
  P.poly([[26, 6], [30, 5], [33, 8], [33, 10], [29, 11], [26, 10]], fur);
  P.poly([[27, 4], [28, 1], [29.5, 4.5]], furD); // ear
  P.set(30, 7, eye);
  P.part(); P.rect(30, 10, 3, 1, teeth); P.sh(32, 9, -1);
  return P.render({ top: 1, bot: 21, vgrad: 0.6 });
}

// ---------------------------------------------------------------- 역귀 졸개 (hunched ghoul)
export function ghoul(frame) {
  const P = new Painter(24, 32);
  const skin = P.m({ c: '#7d8a6e', curve: 2.2, dither: 0.6, spread: 1.15 });
  const skinD = P.m({ c: '#5a6650', curve: 2, dither: 0.5 });
  const cloth = P.m({ c: '#3a3436', curve: 2, dither: 0.6 });
  const rope = P.m({ c: '#8a7444', curve: 1, dither: 0.2 });
  const eye = P.m({ c: '#d6ff7a', flat: true, glow: true, outline: false });
  const horn = P.m({ c: '#bcae8c', curve: 1, dither: 0.2 });
  const claw = P.m({ c: '#d8d2bc', curve: 1, dither: 0 });
  const s = frame === 1 ? 1 : 0;
  // far arm hanging long
  P.part(); P.line(16, 13, 19, 21 + s, skinD, 2); P.line(19, 21 + s, 19, 25 + s, skinD, 1.4);
  P.part(); P.set(18, 26 + s, claw); P.set(20, 26 + s, claw);
  // legs: bent, digitigrade
  P.part();
  P.line(10, 21, 8 - s, 25, skin, 2.2); P.line(8 - s, 25, 9 - s, 29, skin, 1.6);
  P.line(14, 21, 16 + s, 25, skinD, 2.2); P.line(16 + s, 25, 15 + s, 29, skinD, 1.6);
  P.rect(7 - s, 29, 3, 1, skin); P.rect(15 + s, 29, 3, 1, skinD);
  // torso: hunched forward, spine bulge
  P.part();
  P.poly([[7, 12], [12, 8], [17, 10], [17, 16], [15, 22], [9, 22], [7, 17]], skin);
  for (const ry of [13, 15, 17]) P.shLine(10, ry, 15, ry - 1, -1.1);
  P.shLine(8, 13, 8, 20, -0.8);
  // loincloth with straw rope
  P.part(); P.poly([[8, 19], [16, 19], [17, 25], [14, 23], [12, 26], [10, 23], [7, 25]], cloth);
  P.part(); P.rect(8, 19, 9, 1, rope);
  // near arm: long, claws forward
  P.part();
  P.line(9, 12, 5, 19 + s, skin, 2.2); P.line(5, 19 + s, 4, 24 + s, skin, 1.6);
  P.part(); P.set(3, 25 + s, claw); P.set(5, 25 + s, claw); P.set(4, 26 + s, claw);
  // head sunk between the shoulders
  P.part();
  P.ellipse(12, 8, 3.6, 3.8, skin);
  P.rect(10, 10, 5, 2, skin);
  P.shRect(9, 7, 7, 1, -1.4);
  P.set(10, 8, eye); P.set(13, 8, eye);
  P.shRect(10, 11, 5, 1, -1.5); // mouth slit
  P.part(); P.poly([[9, 5], [10, 4], [8, 1]], horn); P.poly([[14, 4], [15, 5], [16, 1]], horn);
  return P.render({ top: 1, bot: 30, vgrad: 0.7 });
}

// ---------------------------------------------------------------- 역신 boss (pre-rendered sway frames)
// variant: 'idle' | 'tele' | 'human'
export function plagueGod(variant, phase) {
  const human = variant === 'human';
  const P = new Painter(46, 64);
  const cx = 23, F2 = 62;
  const sway = Math.sin(phase * Math.PI * 2) * 1.5;
  const robe = P.m({ c: human ? '#b8b0a0' : '#5a6250', curve: 4, dither: 0.7, spread: 1.15 });
  const robeD = P.m({ c: human ? '#8a8070' : '#3a4234', curve: 3, dither: 0.6 });
  const rot = P.m({ c: '#6a8a3a', curve: 2, dither: 0.6 });
  const skin = P.m({ c: human ? '#d8c4a8' : '#cfd6c0', curve: 2.4, dither: 0.3, hue: 6 });
  const hair = P.m({ c: '#121018', curve: 2, dither: 0.4, spread: 1.2 });
  const eye = P.m({ c: variant === 'tele' ? '#ff5a4a' : '#c8ff70', flat: true, glow: true, outline: false });
  const cap = P.m({ c: '#17161c', curve: 2.4, spec: true, dither: 0.2 });
  const claw = P.m({ c: '#e0dac4', curve: 1, dither: 0 });
  const H = human ? 50 : 58;
  const top = F2 - H;
  const lift = variant === 'tele' ? -7 : 0;
  // back hair cascade
  if (!human) {
    P.part();
    P.poly([[cx - 7 + sway, top + 4], [cx + 7 + sway, top + 4], [cx + 9 + sway * 0.6, top + 30], [cx - 9 + sway * 0.6, top + 30]], hair);
  }
  // robe: tall bell, ragged hem
  P.part();
  const shoulder = human ? 7 : 8, hem = human ? 11 : 15;
  P.poly([[cx - shoulder + sway, top + 12], [cx + shoulder + sway, top + 12], [cx + hem, F2 - 1], [cx - hem, F2 - 1]], robe);
  if (!human) {
    for (let x = -hem; x <= hem; x += 2) { const k = ((x * 13 + Math.round(phase * 8)) % 4 + 4) % 4; for (let y = 0; y < k; y++) P.clear(cx + x, F2 - 1 - y); }
    P.part(); P.ellipse(cx - 6, F2 - 12, 2.5, 3.5, rot); P.ellipse(cx + 5, top + 26, 2, 2.6, rot);
  }
  for (const fx of [-6, -2, 3, 7]) P.shLine(cx + fx * 0.5 + sway, top + 20, cx + fx * 1.3, F2 - 3, -1.1);
  P.part(); P.rect(cx - shoulder + Math.round(sway), top + 22, shoulder * 2, 2, robeD); // sash
  // arms: long sleeves, claws
  const arm = (side) => {
    P.part();
    const x = cx + side * (shoulder + 1) + sway;
    P.poly([[x - 2, top + 13 + lift * 0.3], [x + 2, top + 13 + lift * 0.3], [x + side * 3 + 3, top + 32 + lift], [x + side * 3 - 3, top + 32 + lift]], robeD);
    P.part();
    if (human) P.rect(Math.round(x + side * 3 - 1), top + 33 + lift, 3, 2, skin);
    else for (let i = -1; i <= 1; i++) P.line(x + side * 3 + i * 1.5, top + 32 + lift, x + side * 3 + i * 2, top + 37 + lift, claw);
  };
  arm(-1); arm(1);
  // head: long face, mask-like
  P.part();
  const hx = cx + sway * 1.2, hy = top + 6;
  P.ellipse(hx, hy, 4.2, 5.4, skin);
  P.rect(Math.round(hx - 1), hy + 4, 3, 3, skin);
  if (human) {
    P.shRect(hx - 3, hy - 1, 7, 1, -1);
    P.set(hx - 2, hy, P.m({ c: '#100c10', flat: true, outline: false })); P.set(hx + 1, hy, P.m({ c: '#100c10', flat: true, outline: false }));
    P.shRect(hx - 1, hy + 3, 3, 1, -1.2); P.sh(hx + 2, hy + 3, -1); // thin crooked smile
    P.part(); P.ellipse(hx, hy - 4, 4.4, 2.6, cap); P.ellipse(hx, hy - 6, 2.6, 2, cap);
    P.part(); P.rect(hx - 12, hy - 4, 8, 1, cap); P.rect(hx + 4, hy - 4, 8, 1, cap);
  } else {
    P.shRect(hx - 3, hy - 1, 7, 2, -1.8); // deep sockets
    P.rect(Math.round(hx - 3), hy, 2, 1, eye); P.rect(Math.round(hx + 1), hy, 2, 1, eye);
    P.shRect(hx - 2, hy + 3, 4, 2, -2.2); // gaping mouth
    if (variant === 'tele') P.shRect(hx - 1, hy + 3, 2, 3, -3);
    P.part(); // hair over the face, parted
    P.poly([[hx - 5, hy - 5], [hx + 5, hy - 5], [hx + 5, hy + 8], [hx + 3, hy + 2], [hx + 2, hy - 3], [hx - 2, hy - 3], [hx - 3, hy + 2], [hx - 5, hy + 9]], hair);
  }
  return P.render({ top, bot: F2, vgrad: 0.8 });
}

// ---------------------------------------------------------------- dialogue portraits (48x48 busts)
// o: same spec as human() plus { mood }
export function portrait(o) {
  const S = 48;
  const P = new Painter(S, S);
  const skinC = o.skin || SKIN;
  const M = {
    skin: P.m({ c: skinC, curve: 6, dither: 0.2, hue: 3, spread: 0.8 }),
    hair: P.m({ c: o.hair || '#1c1a22', curve: 4, dither: 0.5, spread: 1.15 }),
    robe: P.m({ c: o.robe || '#3b3f52', curve: 8, dither: 0.3 }),
    trim: P.m({ c: o.trim || '#8a6a3a', curve: 2, dither: 0.4 }),
    inner: P.m({ c: o.inner || '#cfc6b0', curve: 3, dither: 0.4 }),
    hat: P.m({ c: o.hatC || '#1b1a22', curve: 5, spec: true, dither: 0.4, spread: 1.2 }),
    gold: P.m({ c: '#c9a24a', curve: 2, spec: true, dither: 0.2 }),
    eyeW: P.m({ c: o.ghost ? '#c8d8e8' : '#d8d0c0', flat: true, outline: false, dither: 0 }),
    iris: P.m({ c: o.eyeC || '#2a1c18', flat: true, outline: false, dither: 0 }),
    lash: P.m({ c: '#140e10', flat: true, outline: false, dither: 0 }),
    lip: P.m({ c: mix(skinC, '#8a3a3a', o.female ? 0.45 : 0.25), flat: true, outline: false, dither: 0 }),
    beard: P.m({ c: o.beard === 'white' ? '#cac6be' : o.hair || '#1c1a22', curve: 3, dither: 0.5 }),
  };
  const cx = 24, fy = 22 + (o.child ? 3 : 0); // face centre
  const fw = o.female || o.child ? 8.5 : 9.5, fh = o.child ? 10.5 : 12;
  // shoulders + garment
  P.part();
  P.poly([[cx - 20, S], [cx - 16, 38], [cx - 6, 34], [cx + 6, 34], [cx + 16, 38], [cx + 20, S]], M.robe);
  P.shLine(cx - 10, 40, cx - 12, S - 1, -1); P.shLine(cx + 10, 40, cx + 12, S - 1, -1.2);
  P.part();
  if (o.outfit === 'skirt' || o.outfit === 'jeogori' || o.outfit === 'rags') { P.poly([[cx - 6, 34], [cx - 2, 34], [cx + 4, 44], [cx + 2, 46]], M.inner); }
  else { P.poly([[cx - 7, 34], [cx + 7, 34], [cx + 5, 39], [cx, 41], [cx - 5, 39]], M.inner); P.part(); P.poly([[cx - 4, 34], [cx + 4, 34], [cx + 2, 37], [cx - 2, 37]], M.skin); }
  if (o.trim) { P.part(); P.line(cx - 16, 39, cx - 7, 35, M.trim, 1.5); P.line(cx + 16, 39, cx + 7, 35, M.trim, 1.5); }
  // long hair behind
  if (o.female || o.head === 'long') { P.part(); P.poly([[cx - fw - 2, fy - 6], [cx + fw + 2, fy - 6], [cx + fw + 4, 40], [cx - fw - 4, 40]], M.hair); }
  // neck
  P.part(); P.rect(cx - 4, fy + fh - 4, 8, 10, M.skin); P.shRect(cx - 4, fy + fh - 3, 8, 3, -1.3);
  // face: slightly tapered jaw
  P.part();
  P.ellipse(cx, fy, fw, fh, M.skin);
  P.poly([[cx - fw + 0.5, fy + 1], [cx + fw - 0.5, fy + 1], [cx + fw * 0.45, fy + fh - 0.5], [cx - fw * 0.45, fy + fh - 0.5]], M.skin);
  // ears
  P.part(); P.ellipse(cx - fw - 0.5, fy + 1, 1.8, 3, M.skin); P.ellipse(cx + fw + 0.5, fy + 1, 1.8, 3, M.skin);
  // features (in the face part's coordinate space; drawn as shading + flat pixels)
  const ey = fy - 0;
  const stern = o.mood !== 'soft';
  // brows: heavy, inner ends low when stern
  const browM = M.hair;
  P.part();
  P.line(cx - 7, ey - 4 + (stern ? -1 : 0), cx - 2, ey - 3 + (stern ? 1 : 0), browM, 1);
  P.line(cx + 7, ey - 4 + (stern ? -1 : 0), cx + 2, ey - 3 + (stern ? 1 : 0), browM, 1);
  if (!o.female && !o.child) { P.line(cx - 6, ey - 3 + (stern ? -1 : 0), cx - 3, ey - 3 + (stern ? 1 : 0), browM, 1); P.line(cx + 6, ey - 3 + (stern ? -1 : 0), cx + 3, ey - 3 + (stern ? 1 : 0), browM, 1); }
  // eye sockets
  P.shRect(cx - 7, ey - 2, 5, 3, -0.6); P.shRect(cx + 2, ey - 2, 5, 3, -0.9);
  // eyes: narrow almond, upper lid line, iris
  for (const s of [-1, 1]) {
    const ex = cx + s * 4.5;
    P.rect(Math.round(ex - 2), ey, 4, 1, M.eyeW);
    P.rect(Math.round(ex - 2), ey - 1, 4, 1, M.lash);
    P.set(Math.round(ex - 3 * (s > 0 ? 0 : 1) + (s > 0 ? 2 : 0)), ey, M.lash);
    P.rect(Math.round(ex - 1), ey, 2, 1, o.eyeGlow ? M.eyeW : M.iris);
    if (o.eyeGlow) P.rect(Math.round(ex - 1), ey, 2, 1, P.m({ c: o.eyeGlow, flat: true, glow: true, outline: false }));
    P.shRect(ex - 2, ey + 1, 4, 1, -0.5);
  }
  // nose: shadow on the right of the bridge and under the tip
  P.shLine(cx + 1, ey + 0, cx + 1, ey + 5, -0.9);
  P.shRect(cx - 1, ey + 6, 3, 1, -1.3); P.sh(cx - 2, ey + 5, -0.6); P.sh(cx + 2, ey + 5, -0.8);
  P.sh(cx - 1, ey + 2, 0.6); P.sh(cx - 1, ey + 3, 0.6);
  // mouth: thin, closed, shadow under lower lip
  P.part();
  P.rect(cx - 3, ey + 9, 6, 1, M.lip); P.shRect(cx - 3, ey + 9, 6, 1, -1.4);
  if (o.mood === 'sinister') { P.sh(cx + 3, ey + 8, -1.5); P.sh(cx + 4, ey + 8, -1); }
  P.shRect(cx - 2, ey + 10, 4, 1, 0.5); P.shRect(cx - 2, ey + 11, 4, 1, -0.6);
  // cheekbones / jaw shadow (right side, away from the light)
  P.shLine(cx + fw - 2, ey + 1, cx + 4, fy + fh - 1, -1.0);
  P.shLine(cx - fw + 2, ey + 3, cx - 5, fy + fh - 2, -0.4);
  if (o.sick || o.ghost) { P.shRect(cx - 7, ey + 2, 4, 1, -0.9); P.shRect(cx + 3, ey + 2, 4, 1, -1.1); }
  // beard
  if (o.beard) {
    P.part();
    const long = o.beard === 'long' || o.beard === 'white';
    P.poly([[cx - 6, ey + 8], [cx + 6, ey + 8], [cx + 4, fy + fh + (long ? 9 : 2)], [cx, fy + fh + (long ? 12 : 3)], [cx - 4, fy + fh + (long ? 9 : 2)]], M.beard);
    P.part(); P.poly([[cx - 6, ey + 8], [cx - 1, ey + 7], [cx - 1, ey + 8], [cx - 5, ey + 10]], M.beard); P.poly([[cx + 6, ey + 8], [cx + 1, ey + 7], [cx + 1, ey + 8], [cx + 5, ey + 10]], M.beard);
    P.part(); P.rect(cx - 3, ey + 9, 6, 1, M.lip); P.shRect(cx - 3, ey + 9, 6, 1, -1.6);
  }
  // hair & headwear
  P.part();
  const head = o.head || 'topknot';
  const hairTop = () => {
    P.poly([[cx - fw - 1, fy + 2], [cx - fw - 1, fy - 6], [cx - fw + 2, fy - fh + 1], [cx, fy - fh - 1.5], [cx + fw - 2, fy - fh + 1], [cx + fw + 1, fy - 6], [cx + fw + 1, fy + 2], [cx + fw - 1, fy - 3], [cx + 3, fy - 7], [cx - 3, fy - 7], [cx - fw + 1, fy - 3]], M.hair);
    P.shLine(cx - 3, fy - 10, cx - 6, fy - 4, 0.8); P.shLine(cx + 3, fy - 10, cx + 7, fy - 3, -0.8);
  };
  if (head === 'boktu') {
    hairTop();
    P.part();
    P.poly([[cx - fw - 1.5, fy - 5], [cx - fw, fy - fh - 1], [cx - 4, fy - fh - 4], [cx + 4, fy - fh - 4], [cx + fw, fy - fh - 1], [cx + fw + 1.5, fy - 5]], M.hat);
    P.part(); P.ellipse(cx, fy - fh - 5, 5.5, 4, M.hat);
    P.part(); P.rect(cx - 23, fy - 7, 13, 2, M.hat); P.rect(cx + 10, fy - 7, 14, 2, M.hat);
    P.part(); P.rect(cx - fw - 1, fy - 6, fw * 2 + 3, 2, M.hat);
  } else if (head === 'topknot' || head === 'child') {
    hairTop();
    if (head === 'topknot') { P.part(); P.ellipse(cx, fy - fh - 3, 3, 3, M.hair); P.part(); P.rect(cx - fw, fy - 7, fw * 2 + 1, 2, M.trim); }
    else { P.part(); P.poly([[cx - fw, fy - 8], [cx + fw, fy - 8], [cx + fw - 1, fy - 3], [cx + 3, fy - 5], [cx, fy - 3], [cx - 4, fy - 5], [cx - fw + 1, fy - 3]], M.hair); }
  } else if (head === 'bun') {
    hairTop();
    P.part(); P.ellipse(cx, fy - fh - 2, 5.5, 3.2, M.hair);
    if (o.pin) { P.part(); P.rect(cx + 2, fy - fh - 3, 12, 1, M.gold); P.ellipse(cx + 14, fy - fh - 3, 1.5, 1.5, M.gold); }
  } else if (head === 'scarf') {
    P.poly([[cx - fw - 3, fy + 8], [cx - fw - 2, fy - 6], [cx - 3, fy - fh - 3], [cx + 3, fy - fh - 3], [cx + fw + 2, fy - 6], [cx + fw + 3, fy + 8], [cx + fw, fy + 6], [cx + fw - 1, fy - 5], [cx, fy - 8], [cx - fw + 1, fy - 5], [cx - fw, fy + 6]], M.trim);
  } else if (head === 'crown') {
    hairTop();
    P.part(); P.rect(cx - fw - 1, fy - 9, fw * 2 + 3, 3, M.gold);
    for (const ux of [-6, 0, 6]) { P.rect(cx + ux - 1, fy - 20, 2, 11, M.gold); P.rect(cx + ux - 3, fy - 17, 6, 1, M.gold); P.rect(cx + ux - 3, fy - 13, 6, 1, M.gold); }
  } else if (head === 'dragon') {
    hairTop();
    P.part();
    const horn = P.m({ c: '#cfc2a0', curve: 2, dither: 0.3 });
    P.poly([[cx - 7, fy - 9], [cx - 4, fy - 10], [cx - 12, fy - 22], [cx - 14, fy - 20]], horn);
    P.poly([[cx + 7, fy - 9], [cx + 4, fy - 10], [cx + 12, fy - 22], [cx + 14, fy - 20]], horn);
    P.part(); P.rect(cx - 6, fy - 12, 12, 3, M.gold); P.rect(cx - 2, fy - 15, 4, 3, M.gold);
  } else if (head === 'long') {
    hairTop();
    P.part(); P.poly([[cx - fw - 1, fy - 4], [cx - fw + 3, fy - 4], [cx - fw + 2, fy + 14], [cx - fw - 2, fy + 16]], M.hair); P.poly([[cx + fw + 1, fy - 4], [cx + fw - 3, fy - 4], [cx + fw - 2, fy + 14], [cx + fw + 2, fy + 16]], M.hair);
  } else if (head === 'bald') {
    P.part(); P.rect(cx - fw, fy - 7, fw * 2 + 1, 2, M.trim);
  }
  return P.render({ top: 0, bot: S, vgrad: 0.5 });
}

// The plague god's portrait: a pale mask-like face behind a curtain of hair.
export function plagueGodPortrait() {
  const S = 48, P = new Painter(S, S);
  const skin = P.m({ c: '#cdd4bc', curve: 7, dither: 0.5 });
  const hair = P.m({ c: '#121018', curve: 4, dither: 0.5, spread: 1.2 });
  const robe = P.m({ c: '#4a5242', curve: 8, dither: 0.6 });
  const eye = P.m({ c: '#c8ff70', flat: true, glow: true, outline: false });
  const cx = 24, fy = 22;
  P.part(); P.poly([[cx - 22, S], [cx - 16, 36], [cx + 16, 36], [cx + 22, S]], robe);
  P.part(); P.poly([[cx - 13, fy - 10], [cx + 13, fy - 10], [cx + 15, S], [cx - 15, S]], hair);
  P.part(); P.ellipse(cx, fy + 1, 9, 13, skin);
  P.shRect(cx - 7, fy - 3, 14, 4, -1.9);
  P.rect(cx - 6, fy - 1, 3, 1, eye); P.rect(cx + 3, fy - 1, 3, 1, eye);
  P.shLine(cx + 1, fy, cx + 1, fy + 5, -0.8);
  P.shEllipse(cx, fy + 9, 3, 2.5, -2.6);
  P.shLine(cx + 6, fy + 2, cx + 4, fy + 12, -1.2);
  P.part(); P.poly([[cx - 11, fy - 12], [cx + 11, fy - 12], [cx + 10, fy + 4], [cx + 6, fy - 6], [cx + 1, fy - 8], [cx - 2, fy - 6], [cx - 6, fy - 6], [cx - 10, fy + 6]], hair);
  return P.render({ top: 0, bot: S, vgrad: 0.6 });
}

export { ramp };
