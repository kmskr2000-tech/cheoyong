// FX: particles, floating text, ground telegraphs, screen shake and light sources.
'use strict';
G.fx = (() => {
  const parts = [];
  const texts = [];
  const rings = [];
  const circles = [];
  const F = { parts, texts, rings, shake: 0, flash: 0, flashColor: '#fff' };

  F.add = (p) => { parts.push({ life: 1, t: 0, vx: 0, vy: 0, vz: 0, z: 0, g: 0, size: 2, color: '#fff', glow: false, drag: 0, ...p }); };
  F.burst = (x, y, n, opt = {}) => {
    for (let i = 0; i < n; i++) {
      const a = Math.random() * Math.PI * 2, s = (opt.speed || 80) * (0.4 + Math.random() * 0.8);
      F.add({ x, y, vx: Math.cos(a) * s, vy: Math.sin(a) * s * 0.6, vz: (opt.up || 60) * (0.5 + Math.random()), g: opt.g ?? 220,
        life: (opt.life || 0.5) * (0.6 + Math.random() * 0.8), size: opt.size || 2, color: opt.color || '#fff', glow: opt.glow, drag: opt.drag || 1.5 });
    }
  };
  F.hit = (x, y, color = '#ffe6a0') => { F.burst(x, y - 30, 8, { speed: 140, up: 40, life: 0.25, size: 2, color, glow: true, g: 0 }); };
  F.smoke = (x, y, n = 1, color = '#7a3cff') => {
    for (let i = 0; i < n; i++) F.add({ x: x + (Math.random() - 0.5) * 30, y: y + (Math.random() - 0.5) * 10, z: Math.random() * 40, vz: 20 + Math.random() * 30,
      vx: (Math.random() - 0.5) * 20, life: 1 + Math.random(), size: 5 + Math.random() * 6, color, smoke: true, glow: true });
  };
  F.soul = (x, y) => {
    F.add({ x, y, z: 40, vz: 60, vx: (Math.random() - 0.5) * 30, life: 1.8, size: 6, color: '#9fe0ff', glow: true, soul: true });
    for (let i = 0; i < 10; i++) F.add({ x: x + (Math.random() - 0.5) * 20, y, z: 20 + Math.random() * 40, vz: 40 + Math.random() * 60, life: 1 + Math.random(), size: 2, color: '#c8f0ff', glow: true });
  };
  F.text = (x, y, s, color = '#fff', size = 16) => texts.push({ x, y, s, color, size, t: 0, life: 0.9 });
  F.ring = (x, y, r0, r1, life, color = '#9fe0ff', w = 3) => rings.push({ x, y, r0, r1, life, t: 0, color, w });
  // glowing rune circle on the ground (skills, purification)
  F.circle = (x, y, r, color = '#7ff0ff', life = 0.8) => circles.push({ x, y, r, color, life, t: 0 });
  F.drawGround = (ctx, cam) => {
    ctx.globalCompositeOperation = 'lighter';
    for (let i = circles.length - 1; i >= 0; i--) {
      const c = circles[i]; c.t += 1 / 60;
      if (c.t > c.life) { circles.splice(i, 1); continue; }
      const k = c.t / c.life, a = Math.min(1, k * 6) * (1 - k * k);
      const x = c.x - cam.x, y = c.y - cam.y, r = c.r * (0.7 + 0.3 * G.easeOut(Math.min(1, k * 3)));
      ctx.save(); ctx.translate(x, y); ctx.scale(1, 0.6);
      const g = ctx.createRadialGradient(0, 0, 0, 0, 0, r);
      g.addColorStop(0, 'rgba(255,255,255,0)'); g.addColorStop(0.7, c.color + '33'); g.addColorStop(1, c.color + '00');
      ctx.globalAlpha = a; ctx.fillStyle = g; ctx.beginPath(); ctx.arc(0, 0, r, 0, Math.PI * 2); ctx.fill();
      ctx.strokeStyle = c.color; ctx.lineWidth = 2;
      ctx.beginPath(); ctx.arc(0, 0, r, 0, Math.PI * 2); ctx.stroke();
      ctx.lineWidth = 1.2; ctx.beginPath(); ctx.arc(0, 0, r * 0.78, 0, Math.PI * 2); ctx.stroke();
      ctx.rotate(c.t * 1.6);
      for (let j = 0; j < 12; j++) { // rune ticks between the rings
        const an = (j / 12) * Math.PI * 2;
        ctx.beginPath(); ctx.moveTo(Math.cos(an) * r * 0.8, Math.sin(an) * r * 0.8); ctx.lineTo(Math.cos(an + 0.15) * r * 0.97, Math.sin(an + 0.15) * r * 0.97); ctx.stroke();
      }
      ctx.rotate(-c.t * 3.2);
      ctx.beginPath(); // inner star
      for (let j = 0; j <= 5; j++) { const an = (j * 4 * Math.PI) / 5 - Math.PI / 2; const px = Math.cos(an) * r * 0.62, py = Math.sin(an) * r * 0.62; j ? ctx.lineTo(px, py) : ctx.moveTo(px, py); }
      ctx.stroke();
      ctx.restore();
    }
    ctx.globalAlpha = 1; ctx.globalCompositeOperation = 'source-over';
  };
  F.screenShake = (v) => { F.shake = Math.max(F.shake, v); };
  F.screenFlash = (v, color = '#fff') => { F.flash = Math.max(F.flash, v); F.flashColor = color; };

  F.update = (dt) => {
    for (let i = parts.length - 1; i >= 0; i--) {
      const p = parts[i];
      p.t += dt;
      if (p.t >= p.life) { parts.splice(i, 1); continue; }
      p.x += p.vx * dt; p.y += p.vy * dt;
      p.vz -= p.g * dt; p.z += p.vz * dt;
      if (p.z < 0 && p.g) { p.z = 0; p.vz *= -0.3; p.vx *= 0.6; p.vy *= 0.6; }
      const d = Math.exp(-p.drag * dt); p.vx *= d; p.vy *= d;
      if (p.soul) p.vx += Math.sin(p.t * 6) * 40 * dt;
    }
    for (let i = texts.length - 1; i >= 0; i--) { const t = texts[i]; t.t += dt; if (t.t > t.life) texts.splice(i, 1); }
    for (let i = rings.length - 1; i >= 0; i--) { const r = rings[i]; r.t += dt; if (r.t > r.life) rings.splice(i, 1); }
    F.shake = Math.max(0, F.shake - dt * 30);
    F.flash = Math.max(0, F.flash - dt * 2.5);
  };

  F.drawWorld = (ctx, cam) => {
    for (const r of rings) {
      const k = r.t / r.life, rad = G.lerp(r.r0, r.r1, G.easeOut(k));
      ctx.globalAlpha = 1 - k; ctx.strokeStyle = r.color; ctx.lineWidth = r.w;
      ctx.beginPath(); ctx.ellipse(r.x - cam.x, r.y - cam.y, rad, rad * 0.62, 0, 0, Math.PI * 2); ctx.stroke();
    }
    ctx.globalAlpha = 1;
    for (const p of parts) {
      const k = p.t / p.life;
      ctx.globalAlpha = p.smoke ? (1 - k) * 0.35 : 1 - k * k;
      ctx.fillStyle = p.color;
      const s = p.smoke ? p.size * (1 + k) : p.size;
      if (p.glow) ctx.globalCompositeOperation = 'lighter';
      if (p.soul || p.smoke) {
        ctx.beginPath(); ctx.arc(p.x - cam.x, p.y - p.z - cam.y, s, 0, Math.PI * 2); ctx.fill();
      } else ctx.fillRect(Math.round(p.x - cam.x - s / 2), Math.round(p.y - p.z - cam.y - s / 2), s, s);
      ctx.globalCompositeOperation = 'source-over';
    }
    ctx.globalAlpha = 1;
  };
  F.drawTexts = (ctx, cam) => {
    ctx.textAlign = 'center'; ctx.lineJoin = 'round';
    for (const t of texts) {
      const k = t.t / t.life;
      // pop in, float up, fade
      const pop = k < 0.12 ? 1 + (0.12 - k) * 5 : 1;
      ctx.globalAlpha = 1 - k * k;
      const size = Math.round(t.size * 1.25 * pop);
      ctx.font = `italic 900 ${size}px "Noto Sans KR", sans-serif`;
      const y = t.y - cam.y - 26 * G.easeOut(k), x = t.x - cam.x;
      ctx.lineWidth = Math.max(3, size / 5); ctx.strokeStyle = 'rgba(20,10,10,0.9)'; ctx.strokeText(t.s, x, y);
      ctx.fillStyle = t.color; ctx.fillText(t.s, x, y);
    }
    ctx.globalAlpha = 1;
  };
  F.clear = () => { circles.length = 0; parts.length = 0; texts.length = 0; rings.length = 0; };
  return F;
})();
