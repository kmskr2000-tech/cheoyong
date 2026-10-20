// Assets: loads the packed PixelLab sprites (manifest from art/pack.py) and makes tinted copies.
'use strict';
G.assets = (() => {
  const A = { chars: {}, tiles: {}, props: {}, images: {}, ready: false };
  const base = (window.ASSET_BASE || 'assets/');
  const loadImg = (src) => new Promise((res, rej) => {
    const im = new Image();
    im.onload = () => res(im);
    im.onerror = () => rej(new Error('image ' + src));
    im.src = (window.ASSET_DATA && window.ASSET_DATA[src]) || base + src;
  });
  const tinted = (img, color) => {
    const c = document.createElement('canvas'); c.width = img.width; c.height = img.height;
    const g = c.getContext('2d'); g.drawImage(img, 0, 0);
    g.globalCompositeOperation = 'source-in'; g.fillStyle = color; g.fillRect(0, 0, c.width, c.height);
    return c;
  };
  A.load = async (onProgress) => {
    const man = window.ASSET_MANIFEST || (await (await fetch(base + 'manifest.json')).json());
    A.manifest = man;
    const jobs = [];
    let done = 0, total = 0;
    const add = (p) => { total++; jobs.push(p.then((v) => { done++; onProgress && onProgress(done / total); return v; })); };
    for (const [n, c] of Object.entries(man.chars || {})) add(loadImg(c.file).then((img) => {
      A.chars[n] = { ...c, img, white: tinted(img, '#ffffff'), dark: tinted(img, '#1a0830') };
    }));
    for (const [n, t] of Object.entries(man.tiles || {})) add(loadImg(t.file).then((img) => {
      const byCorners = {};
      t.tiles.forEach((c, i) => { (byCorners[c] = byCorners[c] || []).push(i); });
      A.tiles[n] = { img, byCorners };
    }));
    for (const [n, p] of Object.entries(man.props || {})) add(loadImg(p.file).then((img) => { A.props[n] = { ...p, img }; }));
    for (const [n, f] of Object.entries(man.images || {})) add(loadImg(f).then((img) => { A.images[n] = img; }));
    await Promise.all(jobs);
    A.ready = true;
  };

  // pick a frame: anim -> direction (nearest available) -> frame index by time
  const DIR_ANG = { east: 0, 'south-east': 1, south: 2, 'south-west': 3, west: 4, 'north-west': 5, north: 6, 'north-east': 7 };
  A.frame = (name, anim, dir, t, fps = 10, loop = true) => {
    const c = A.chars[name];
    if (!c) return null;
    let a = c.anims[anim] || c.anims.idle;
    let fr = a[dir];
    let mirror = false;
    if (!fr) {
      const MIRROR = { east: 'west', west: 'east', 'south-east': 'south-west', 'south-west': 'south-east', 'north-east': 'north-west', 'north-west': 'north-east' };
      if (a[MIRROR[dir]]) { fr = a[MIRROR[dir]]; mirror = true; }
      else {
        // nearest direction by angle
        const want = DIR_ANG[dir] ?? 2;
        let best = null, bd = 9;
        for (const d of Object.keys(a)) {
          const k = DIR_ANG[d]; const dd = Math.min(Math.abs(k - want), 8 - Math.abs(k - want));
          if (dd < bd) { bd = dd; best = d; }
        }
        fr = a[best];
        if (!fr || bd > 2) { a = c.anims.idle; fr = a[dir] || a.south || Object.values(a)[0]; }
      }
    }
    let i = Math.floor(t * fps);
    i = loop ? i % fr.length : Math.min(i, fr.length - 1);
    return { c, sx: fr[i][0], sy: fr[i][1], mirror, n: fr.length, i };
  };
  A.animLen = (name, anim, dir) => {
    const c = A.chars[name]; if (!c || !c.anims[anim]) return 0;
    const a = c.anims[anim]; const fr = a[dir] || Object.values(a)[0];
    return fr ? fr.length : 0;
  };
  A.has = (name, anim) => !!(A.chars[name] && A.chars[name].anims[anim]);
  return A;
})();
