// ?auto 자동 조종: 타이틀부터 엔딩까지 스스로 진행한다
import { Audio } from './audio.js';

export const Autopilot = {
  attach(G) {
    let lastName = '';
    let lastTick = 0;
    let lastConfirm = -9;
    let held = null;            // 밤거리에서 누르고 있는 방향 'left' | 'right' | null
    const hitSet = new Set();   // 이미 자동으로 친 음표

    const release = (scene, at) => {
      if (held) scene.onAction(held + 'Up', at);
      held = null;
    };
    const confirmEvery = (scene, now, gap) => {
      if (now - lastConfirm < gap) return;
      lastConfirm = now;
      scene.onAction('confirm', now);
    };

    const tick = () => {
      const scene = G.scene;
      const name = G.sceneName;
      if (!scene) return;
      const now = Audio.now();
      const frame = Math.min(0.3, Math.max(0, now - lastTick)); // 틱 사이의 게임 시간
      lastTick = now;
      if (name !== lastName) { lastName = name; held = null; hitSet.clear(); lastConfirm = now - 0.3; }

      if (name === 'title') confirmEvery(scene, now, 0.5);
      else if (name === 'story') confirmEvery(scene, now, 0.25);
      else if (name === 'result') confirmEvery(scene, now, 0.5);
      else if (name === 'ending') { if (!G.reachedEnding) confirmEvery(scene, now, 0.5); }
      else if (name === 'night') {
        const N = G.night;
        if (!N) return;
        let best = null, bd = Infinity;
        for (const h of N.houses) {
          const d = Math.abs(h.x - N.cheoyongX);
          if (h.haunted && d < bd) { best = h; bd = d; }
        }
        if (!best) { release(scene, now); return; }
        if (bd < 30) {
          release(scene, now);
          confirmEvery(scene, now, 0.3);
        } else {
          const dir = best.x > N.cheoyongX ? 'right' : 'left';
          if (held !== dir) { release(scene, now); held = dir; scene.onAction(dir, now); }
        }
      } else if (name === 'dance') {
        if (!scene.debug) return;
        const d = scene.debug();
        if (!d || !d.judge) return;
        const horizon = Math.max(0.5, frame * 2);
        for (const u of d.judge.upcoming(now, horizon)) {
          if (hitSet.has(u.note)) continue;
          if (u.t - now <= Math.max(0.012, frame)) {
            hitSet.add(u.note);
            scene.onLane(u.note.lane, u.t + (Math.random() < 0.1 ? 0.06 : 0)); // 10%는 '장'
          }
        }
      }
    };

    setInterval(() => {
      try { tick(); } catch (e) { (window.__errors = window.__errors || []).push('autopilot: ' + (e && e.message)); }
    }, 8);
  },
};
