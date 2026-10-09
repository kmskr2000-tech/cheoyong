// Global game state shared by all modules.
export const VIEW_W = 480, VIEW_H = 270, SCALE = 2, TS = 16;

// Balance constants live here so tuning is in one place.
export const BAL = {
  playerHp: 120, hpPerLevel: 10,
  slashBase: 14, atkPerLevel: 2,
  comboMult: [1, 1.1, 1.5],
  heavyMult: 2, songMult: 1.3, parryMult: 2,
  soriRegen: 3, soriSongBonus: 30,
  sinPerHit: 2.5, sinPerParry: 15,
  ultDps: 150, ultPur: 40, ultTime: 6,
  rollTime: 0.3, rollSpeed: 210, rollInvuln: 0.4, parryWindow: 0.25,
  costs: { fire: 25, bind: 30, guard: 20 },
  expToNext: (lv) => lv * 120,
  shop: [
    { id: 'insam', name: '인삼정기탕', desc: 'HP 60 회복 (1키)', price: 30 },
    { id: 'gugija', name: '구기자환', desc: '소리 50 회복 (2키)', price: 25 },
    { id: 'jeonghwa', name: '정화부', desc: '주변 요괴 정화 +35 (3키)', price: 40 },
  ],
};

export const G = {
  scene: 'title',
  stats: null,
  items: null,
  tal: null,
  flags: {},
  checkpoint: 'village',
  level: null,
  player: null,
  dialog: null,
  menu: null,
  cutscene: null,
  toasts: [],
  timers: [],
  scriptLock: 0,
  slowT: 0,
  shake: 0,
  fade: 0, fadeTarget: 0,
  time: 0,
  debug: false,
  god: false,
  encounter: { active: false, calm: 0, songUsed: false },
  boss: null,
  banner: null,
};

export function newGameState() {
  G.stats = { lv: 1, exp: 0, maxHp: BAL.playerHp, hp: BAL.playerHp, money: 50 };
  G.items = { insam: 2, gugija: 1, jeonghwa: 0 };
  G.tal = { unlocked: ['fire', 'guard'], idx: 0 };
  G.flags = {};
  G.checkpoint = 'village';
}

export function atk() { return BAL.slashBase + (G.stats.lv - 1) * BAL.atkPerLevel; }

// Promise-based wait that advances with game time (paused while dialogs are open).
export function wait(sec) {
  return new Promise((res) => G.timers.push({ t: sec, res }));
}

export function toast(text, color = '#e8e2d0', time = 2.5) {
  G.toasts.push({ text, color, t: time, max: time });
  if (G.toasts.length > 5) G.toasts.shift();
}

export function shake(amount) { G.shake = Math.max(G.shake, amount); }

export function addExp(n) {
  const s = G.stats;
  s.exp += Math.round(n);
  let leveled = false;
  while (s.exp >= BAL.expToNext(s.lv)) {
    s.exp -= BAL.expToNext(s.lv);
    s.lv++;
    s.maxHp += BAL.hpPerLevel;
    s.hp = s.maxHp;
    leveled = true;
  }
  return leveled;
}
