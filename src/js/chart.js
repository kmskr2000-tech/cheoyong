// 역신별 악보 생성(순수·결정적). node에서도 실행된다.
export const SPIRITS = ['fever', 'chill', 'cough', 'pox', 'yeoksin'];
export const LEAD = 4;                         // 박점 도달까지 선행 박 수 = 첫 음표 박
const COUNTS = [24, 36, 48, 64, 64];           // 밤(1~5)별 음표 수
const BPM = { fever: 96, chill: 104, cough: 112, pox: 108, yeoksin: 112 };
const PAIRS = [[0, 3], [0, 3], [1, 2], [1, 2], [0, 1], [2, 3], [0, 2], [1, 3]];

function mulberry32(a) {
  return function () {
    a |= 0; a = (a + 0x6D2B79F5) | 0;
    let t = Math.imul(a ^ (a >>> 15), 1 | a);
    t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t;
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
}
const pick = (rng, arr) => arr[Math.floor(rng() * arr.length)];
function shuffle(rng, arr) {
  const a = arr.slice();
  for (let i = a.length - 1; i > 0; i--) { const j = Math.floor(rng() * (i + 1)); [a[i], a[j]] = [a[j], a[i]]; }
  return a;
}

// ---- 성격별 조각: 상대 박(0부터)의 이벤트 [{beat, lanes?}] 를 n개 음표만큼 만든다. lanes 두 개면 겹음표.
function segFever(n, rng, lvl) {            // 4분박 일정, 가끔 쉼. 3밤부터 8분 한 쌍
  const ev = []; let b = 0, c = 0, k = 0;
  while (c < n) {
    ev.push({ beat: b }); c++; k++;
    if (lvl >= 3 && c < n && rng() < 0.12) { ev.push({ beat: b + 0.5 }); c++; b += 1; }
    else b += k % 8 === 0 ? 2 : 1;
  }
  return ev;
}
function segChill(n, rng, lvl) {            // 엇박: 뒷박(.5) 위주, 떨림(.25/.75)
  const ev = []; let b = 0, last = -9;
  while (ev.length < n) {
    const r = rng();
    let p = r < 0.6 ? 0.5 : r < 0.7 ? 0 : r < 0.84 ? 0.25 : 0.75;
    if (lvl <= 2 && p % 0.5) p = 0.5;
    const t = b + p;
    if (rng() >= 0.12 && t - last >= 0.5 - 1e-9) { ev.push({ beat: t }); last = t; }
    b++;
  }
  return ev;
}
function segCough(n, rng, lvl) {            // 셋잇단 몰아치기(+0, +1/3, +2/3) 뒤 쉼
  const ev = []; let b = 0, c = 0;
  while (c < n) {
    const m = Math.min(3, n - c), dir = rng() < 0.5 ? 1 : -1;
    const s = dir > 0 ? Math.floor(rng() * 2) : 2 + Math.floor(rng() * 2);
    for (let i = 0; i < m; i++) ev.push({ beat: b + i / 3, lanes: [s + dir * i] });
    c += m; b += 1 + (lvl >= 4 && rng() < 0.3 ? 1 : 2);
  }
  return ev;
}
function segPox(n, rng) {                   // 두 레인 동시(겹음표) ~25%
  const kinds = []; let c = 0;
  while (c < n) {
    const pair = c >= 3 && c + 2 <= n && kinds[kinds.length - 1] !== 'p' && rng() < 0.25;
    kinds.push(pair ? 'p' : 's'); c += pair ? 2 : 1;
  }
  const ev = []; let b = 0;
  kinds.forEach((k, i) => {
    ev.push(k === 'p' ? { beat: b, lanes: pick(rng, PAIRS).slice() } : { beat: b });
    b += k === 's' && kinds[i + 1] === 's' && rng() < 0.15 ? 0.5 : 1;
  });
  return ev;
}
const SEG = { fever: segFever, chill: segChill, cough: segCough, pox: segPox };

// 이벤트 → 음표(레인 배정). 같은 레인이 세 번 연속되지 않게 다듬는다.
function toNotes(events, rng, offset) {
  const notes = [];
  let prev = -1;
  for (const e of events) {
    const beat = offset + e.beat;
    if (e.lanes && e.lanes.length === 2) {
      const [a, b] = e.lanes.slice().sort((x, y) => x - y);
      notes.push({ beat, lane: a, pair: true }, { beat, lane: b, pair: true });
      prev = b;
    } else {
      let lane = e.lanes ? e.lanes[0] : (rng() < 0.75 ? (prev + 1 + Math.floor(rng() * 3)) % 4 : Math.floor(rng() * 4));
      if (prev < 0 && !e.lanes) lane = Math.floor(rng() * 4);
      notes.push({ beat, lane, pair: false });
      prev = lane;
    }
  }
  fixRuns(notes, rng);
  return notes;
}
function fixRuns(notes, rng) {
  for (let i = 2; i < notes.length; i++) {
    if (notes[i].lane !== notes[i - 1].lane || notes[i].lane !== notes[i - 2].lane) continue;
    const bad = notes[i].lane;
    const mate = notes.find((x, j) => j !== i && x.beat === notes[i].beat);
    const cand = shuffle(rng, [0, 1, 2, 3]).filter((l) => l !== bad && !(mate && mate.lane === l) &&
      !(notes[i + 1] && notes[i + 2] && notes[i + 1].lane === l && notes[i + 2].lane === l));
    notes[i].lane = cand[0];
  }
  // 겹음표 안에서 레인 순서(작은 것 먼저)를 유지
  notes.sort((x, y) => x.beat - y.beat || x.lane - y.lane);
}

export function makeChart(spirit, nightIdx = 1, seed = 1) {
  const si = Math.max(0, SPIRITS.indexOf(spirit));
  const n = Math.min(5, Math.max(1, nightIdx | 0 || 1));
  const rng = mulberry32((Math.imul(seed | 0, 2654435761) ^ Math.imul(n, 97) ^ Math.imul(si + 1, 7919)) >>> 0);
  const bpm = BPM[SPIRITS[si]];
  let notes = [], phases = [], bpmChanges = [];

  if (SPIRITS[si] !== 'yeoksin') {
    const ev = SEG[spirit](COUNTS[n - 1], rng, n);
    notes = toNotes(ev, rng, LEAD);
    phases = [{ startBeat: 0, kind: 'dance', verse: null }];
  } else {
    // 1단계: 열·오한·기침 16개씩 / 2단계: 넷을 섞어 12개씩 / 3단계: 노래 16개(두 박마다 한 구절)
    const plan1 = ['fever', 'chill', 'cough'].map((k) => [k, 16]);
    const plan2 = shuffle(rng, ['fever', 'chill', 'cough', 'pox']).map((k) => [k, 12]);
    const ev = []; let cur = LEAD, phase2At = 0;
    const run = (plan, isSecond) => plan.forEach(([k, cnt], i) => {
      if (isSecond && i === 0) phase2At = cur;
      for (const e of SEG[k](cnt, rng, 5)) ev.push({ ...e, beat: cur + e.beat });
      cur = Math.ceil(ev[ev.length - 1].beat) + 3;       // 조각 사이 쉼
    });
    run(plan1, false);
    cur += 2;                                 // 단계 사이 쉼
    run(plan2, true);
    notes = toNotes(ev, rng, 0);
    const songAt = Math.ceil(notes[notes.length - 1].beat) + 4;
    let lane = Math.floor(rng() * 4), dir = rng() < 0.5 ? 1 : -1;
    for (let i = 0; i < 16; i++) {
      notes.push({ beat: songAt + i, lane, pair: false });
      if (lane + dir < 0 || lane + dir > 3) dir = -dir;
      lane += dir;
    }
    phases = [{ startBeat: 0, kind: 'dance', verse: null }, { startBeat: phase2At, kind: 'dance', verse: null }];
    for (let v = 0; v < 8; v++) phases.push({ startBeat: songAt + v * 2, kind: 'song', verse: v });
  }

  const last = notes[notes.length - 1].beat;
  const lengthBeats = Math.ceil(last) + 4;
  if (spirit === 'fever') {
    bpmChanges = [
      { beat: Math.round(lengthBeats / 3), bpm: bpm + 10 },
      { beat: Math.round(lengthBeats * 2 / 3), bpm: bpm + 20 },
    ];
  }
  return { spirit: SPIRITS[si], night: n, bpm, bpmChanges, lead: LEAD, notes, lengthBeats, phases, total: notes.length };
}

// 박 → 시간(startTime이 박 0). bpmChanges 반영.
export function timeOfBeat(chart, startTime, beat) {
  let t = startTime, b = 0, bpm = chart.bpm;
  for (const c of chart.bpmChanges) {
    if (beat <= c.beat) break;
    t += (c.beat - b) * 60 / bpm; b = c.beat; bpm = c.bpm;
  }
  return t + (beat - b) * 60 / bpm;
}
export function noteTimes(chart, startTime = 0) {
  return chart.notes.map((n) => timeOfBeat(chart, startTime, n.beat));
}
