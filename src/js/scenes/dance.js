// 춤(리듬 전투): 흉이 오른쪽에서 박점으로 흘러오고, 맞는 춤사위로 받아낸다
import { Judge } from '../rhythm.js';
import { makeChart } from '../chart.js';
import { drawPaper, drawStreet, COLORS } from '../render/paper.js';
import { drawCheoyong, drawSpirit, drawHouse, drawMask, drawNote } from '../render/puppet.js';
import { brushTitle, FONT } from '../render/text.js';
import { STORY } from '../story.js';

const CX = 240, SX = 760, BASE_Y = 430;       // 박점 x, 역신 x, 발밑 y
const LY = [300, 340, 380, 420];              // 레인 y (0 위 … 3 아래)
const TRAVEL = SX - CX;                       // 음표 이동 거리 520
const LANE_POSE = ['armL', 'step', 'spin', 'armR'];
const LANE_GLYPH = ['左', '足', '回', '右'];
const POSE_DUR = 0.35;
const END_DUR = 1.6;
const PATTERN = [{ beat: 0, name: 'deong' }, { beat: 1, name: 'deok' }, { beat: 2, name: 'kung' }, { beat: 3, name: 'deok' }];
const MELODY = [0, 2, 3, 2];
const GRADE = {
  jeol: { txt: '절', sound: 'deok', color: COLORS.yellow },
  jang: { txt: '장', sound: 'kung', color: COLORS.blue },
  bak: { txt: '박', sound: 'step', color: COLORS.black },
};
const COUNT = ['하나…', '둘…', '셋…', '넷…'];

let api, G, N, spirit, houseIdx, chart, judge, startTime, segs, countTimes;
let state, ended, endTT, maskDone, leaving, tt, last;
let pose, poseT, lastLane, spState, spT, spDur, lastSpawn;
let songStart, songRestarted, jBase, applied, minBpm, tutorial;

const stepDt = (now) => { const d = Math.min(0.25, Math.max(0, now - last)); last = now; return d; };
const clamp = (v, a, b) => Math.max(a, Math.min(b, v));

function hexRgb(h) { const v = parseInt(h.slice(1), 16); return [(v >> 16) & 255, (v >> 8) & 255, v & 255]; }
function mix(a, b, t) {
  const A = hexRgb(a), B = hexRgb(b);
  return `rgb(${A.map((x, i) => Math.round(x + (B[i] - x) * t)).join(',')})`;
}

// 박 ↔ 시간 (bpmChanges 반영)
function buildSegs() {
  segs = [{ beat: 0, time: startTime, bpm: chart.bpm }];
  (chart.bpmChanges || []).forEach((c) => {
    const p = segs[segs.length - 1];
    segs.push({ beat: c.beat, time: p.time + ((c.beat - p.beat) * 60) / p.bpm, bpm: c.bpm });
  });
  minBpm = Math.min(...segs.map((s) => s.bpm));
}
function segAtBeat(b) { let s = segs[0]; for (const x of segs) if (x.beat <= b) s = x; return s; }
function timeOfBeat(b) { const s = segAtBeat(b); return s.time + ((b - s.beat) * 60) / s.bpm; }
function beatOfTime(t) {
  let s = segs[0];
  for (const x of segs) if (x.time <= t) s = x;
  return s.beat + ((t - s.time) * s.bpm) / 60;
}

function setPose(name, now) { pose = name; poseT = now; }
function setSpirit(name, dur) { spState = name; spT = tt; spDur = dur; }

function curPhase(now) {
  const b = beatOfTime(now);
  let ph = null;
  for (const p of chart.phases || []) if (p.startBeat <= b) ph = p;
  const inSong = !!ph && ph.kind === 'song';
  let verse = null;
  if (inSong) {
    verse = ph.verse != null ? ph.verse : Math.floor((b - songStart) / 2);
    verse = clamp(verse, 0, STORY.verses.length - 1);
  }
  return { inSong, verse };
}

// 판정 이벤트 처리
function pump(now) {
  judge.update(now);
  for (const ev of judge.drain()) {
    const lane = ev.note.lane;
    if (ev.type === 'hit') {
      const g = GRADE[ev.grade] || GRADE.bak;
      setPose(LANE_POSE[lane], now);
      api.fx.burst(CX, LY[lane], ev.grade);
      api.fx.text(CX + 30, LY[lane] - 22, g.txt, g.color);
      api.Audio.play(g.sound);
      setSpirit('flinch', 0.3);
    } else if (ev.type === 'miss') {
      api.fx.burst(CX, LY[lane], 'miss');
      api.fx.text(CX + 30, LY[lane] - 22, '놓침', COLORS.red);
      api.Audio.play('miss');
      setSpirit('throw', 0.4);
    }
  }
}

// 템포 변경과 노래 단계 장단 전환
function tempo(now) {
  const pendingSong = songStart != null && !songRestarted;
  (chart.bpmChanges || []).forEach((c, i) => {
    if (applied[i] || now < timeOfBeat(c.beat) - 0.6) return;
    if (pendingSong && c.beat > songStart) return; // 노래 단계 장단을 다시 걸 때까지 미룬다
    applied[i] = true;
    api.Audio.setBpm(c.bpm, c.beat - jBase);
  });
  if (pendingSong && now >= timeOfBeat(songStart) - 0.12) {
    songRestarted = true;
    api.Audio.stopJangdan();
    jBase = songStart;
    api.Audio.startJangdan({ bpm: segAtBeat(songStart).bpm, startAt: timeOfBeat(songStart), pattern: PATTERN, melody: null });
  }
}

function beginEnd(o) {
  ended = o; endTT = tt; maskDone = false;
  api.Audio.stopJangdan();
  if (N && N.deokLog) N.deokLog.push(judge.deok);
  api.Audio.play(o === 'kneel' ? 'kneel' : 'flee');
}

function leave(result) {
  if (leaving) return;
  leaving = true;
  if (houseIdx !== undefined) api.setScene('night', result ? { resume: true, result } : { resume: true });
  else api.setScene('title', {});
}

function drawGauges(ctx, now) {
  const deok = clamp(judge.deok, 0, 100), hy = clamp(judge.hyung, 0, 100);
  const y = 22, h = 16, w = 300;
  ctx.save();
  ctx.lineWidth = 2;
  ctx.strokeStyle = COLORS.black;
  // 덕: 왼쪽, 노랑 → 빨강
  ctx.fillStyle = 'rgba(21,17,15,0.15)'; ctx.fillRect(56, y, w, h);
  ctx.fillStyle = mix(COLORS.red, COLORS.yellow, deok / 100); ctx.fillRect(56, y, (w * deok) / 100, h);
  ctx.strokeRect(56, y, w, h);
  // 흉: 오른쪽, 독기 빛
  ctx.fillStyle = 'rgba(21,17,15,0.15)'; ctx.fillRect(604, y, w, h);
  ctx.fillStyle = COLORS.miasma; ctx.fillRect(604 + w - (w * hy) / 100, y, (w * hy) / 100, h);
  ctx.strokeRect(604, y, w, h);
  ctx.restore();
  brushTitle(ctx, '德', 30, 40, 34, COLORS.black, { align: 'center' });
  brushTitle(ctx, '凶', 930, 40, 34, COLORS.miasma, { align: 'center' });
}

export default {
  enter(params, a) {
    api = a; G = a.G;
    spirit = params.spirit || 'fever';
    houseIdx = params.houseIdx;
    N = G.night || null;
    const n = (N && N.n) || params.n || 1;
    chart = makeChart(spirit, n, G.seed != null ? G.seed : 1);
    const beatSec = 60 / chart.bpm;
    startTime = api.Audio.now() + Math.max(2.0, 4 * beatSec + 0.15); // 카운트인 4박이 들어갈 만큼
    judge = new Judge(chart, startTime);
    buildSegs();
    countTimes = [0, 1, 2, 3].map((i) => startTime - (4 - i) * beatSec);
    countTimes.forEach((t) => api.Audio.play('bak', t));

    const sp = (chart.phases || []).find((p) => p.kind === 'song');
    songStart = sp ? sp.startBeat : null;
    songRestarted = false; jBase = 0; applied = [];
    api.Audio.startJangdan({ bpm: chart.bpm, startAt: startTime, pattern: PATTERN, melody: MELODY });

    api.fx.clear();
    state = 'count'; ended = null; maskDone = false; leaving = false;
    tt = 0; last = api.Audio.now();
    pose = 'idle'; poseT = -9; lastLane = -1;
    spState = 'lurk'; spT = 0; spDur = 0; lastSpawn = -1;
    tutorial = !!(N && N.n === 1 && (N.kneels || 0) + (N.fled || 0) === 0);
  },
  exit() { try { api.Audio.stopJangdan(); } catch (e) { /* 이미 멈춤 */ } },
  update(dt, now) {
    const d = stepDt(now);
    tt += d;
    if (state === 'count' && now >= startTime - 0.2) state = 'play';
    pump(now);
    if (!ended) {
      tempo(now);
      // 새 음표가 막 던져질 때 역신이 팔을 휘두른다
      const lead = (chart.lead * 60) / segAtBeat(beatOfTime(now)).bpm;
      for (const u of judge.upcoming(now, lead + 0.05)) {
        if (u.dt > lead - 0.12 && u.note.beat !== lastSpawn) {
          lastSpawn = u.note.beat;
          if (spState === 'lurk' || tt - spT >= spDur) setSpirit('throw', 0.25);
        }
      }
      let o = judge.outcome();
      if (!o && judge.broken && spirit !== 'yeoksin') o = 'flee';
      if (o) beginEnd(o);
    } else {
      const e = tt - endTT;
      if (ended === 'kneel' && !maskDone && e >= 0.9) {
        maskDone = true;
        api.Audio.play('mask');
        api.fx.burst(SX, BASE_Y - 100, 'petal');
        api.fx.flash(COLORS.lantern, 0.4);
      }
      if (e >= END_DUR) leave({ houseIdx, outcome: ended });
    }
  },
  draw(ctx, now) {
    const W = 960, H = 540;
    const home = spirit === 'yeoksin';
    drawPaper(ctx, W, H, now, { moon: 1, lantern: null, redMoon: !!(N && N.n === 4) });
    drawStreet(ctx, W, H, now, { houses: [], horizonY: 420 });
    drawHouse(ctx, 830, BASE_Y, home ? 280 : 200, now, { lit: true, haunted: !ended || ended === 'flee', masked: ended === 'kneel' && maskDone, home });

    const { inSong, verse } = curPhase(now);
    const e = ended ? tt - endTT : 0;

    // 레인 줄·박점
    ctx.save();
    ctx.globalAlpha = inSong ? 0.18 : 0.35;
    ctx.strokeStyle = COLORS.black;
    ctx.lineWidth = 2;
    LY.forEach((y, i) => {
      ctx.beginPath(); ctx.moveTo(CX, y); ctx.lineTo(SX, y); ctx.stroke();
    });
    ctx.globalAlpha = inSong ? 0.3 : 0.7;
    ctx.lineWidth = 3;
    ctx.beginPath(); ctx.moveTo(CX, LY[0] - 22); ctx.lineTo(CX, LY[3] + 22); ctx.stroke();
    ctx.fillStyle = COLORS.red;
    LY.forEach((y) => { ctx.beginPath(); ctx.arc(CX, y, 5, 0, Math.PI * 2); ctx.fill(); });
    ctx.restore();
    ctx.save();
    ctx.font = `26px ${FONT}`;
    ctx.textAlign = 'center';
    ctx.fillStyle = COLORS.black;
    ctx.globalAlpha = inSong ? 0.3 : 0.75;
    LY.forEach((y, i) => ctx.fillText(LANE_GLYPH[i], 200, y + 9));
    ctx.restore();

    // 역신
    let st = 'lurk', ph = 0;
    if (ended === 'kneel') { st = 'kneel'; ph = clamp(e / 0.9, 0, 1); }
    else if (ended === 'flee') { st = 'flee'; ph = clamp(e / END_DUR, 0, 1); }
    else if (tt - spT < spDur) { st = spState; ph = (tt - spT) / spDur; }
    drawSpirit(ctx, SX, BASE_Y, 0.9, spirit, st, now, { phase: ph });
    if (ended === 'kneel' && e >= 0.9) {
      const g = clamp((e - 0.9) / 0.5, 0, 1);
      drawMask(ctx, SX, BASE_Y - 130, 30 + 70 * (1 - Math.pow(1 - g, 3)), now, { glow: g });
    }

    // 흉 음표
    if (!ended) {
      const horizon = (chart.lead * 60) / minBpm + 0.1;
      const ups = judge.upcoming(now, horizon);
      const byBeat = new Map();
      ctx.save();
      ctx.globalAlpha = inSong ? 0.35 : 1;
      for (const u of ups) {
        const leadSec = (chart.lead * 60) / segAtBeat(u.note.beat).bpm;
        const x = CX + (TRAVEL * u.dt) / leadSec;
        if (x > SX + 20) continue;
        const alpha = u.dt < 0 ? clamp(1 + u.dt / 0.135, 0.2, 1) : 1;
        if (u.note.pair) {
          const k = u.note.beat;
          if (byBeat.has(k)) {
            const o = byBeat.get(k);
            ctx.save();
            ctx.strokeStyle = COLORS.red; ctx.lineWidth = 3; ctx.globalAlpha = 0.5 * alpha;
            ctx.beginPath(); ctx.moveTo(o.x, LY[o.lane]); ctx.lineTo(x, LY[u.note.lane]); ctx.stroke();
            ctx.restore();
          } else byBeat.set(k, { x, lane: u.note.lane });
        }
        drawNote(ctx, x, LY[u.note.lane], u.note.lane, 30, now, { pair: !!u.note.pair, alpha });
      }
      ctx.restore();
    }

    // 처용
    const el = now - poseT;
    const p = el < POSE_DUR ? pose : (inSong ? 'sing' : 'idle');
    drawCheoyong(ctx, CX, BASE_Y, 0.9, p, now, { phase: el < POSE_DUR ? clamp(el / POSE_DUR, 0, 1) : 0 });


    // HUD
    drawGauges(ctx, now);
    if (inSong && !ended) brushTitle(ctx, STORY.verses[verse], 480, 118, 54, COLORS.red, { align: 'center' });
    if (judge.combo >= 5 && !ended) brushTitle(ctx, `${judge.combo} 이음`, CX, 478, 32, COLORS.black, { align: 'center' });
    if (state === 'count' && now < startTime) {
      let ci = -1;
      countTimes.forEach((t, i) => { if (now >= t) ci = i; });
      if (ci >= 0) brushTitle(ctx, COUNT[ci], 480, 230, 110, COLORS.red, { align: 'center' });
    }
    if (ended) {
      brushTitle(ctx, ended === 'kneel' ? '역신이 무릎을 꿇소' : '역신이 달아났소', 480, 130, 52, ended === 'kneel' ? COLORS.red : COLORS.miasma, { align: 'center' });
    }
    if (tutorial && !ended) {
      const hint = STORY.tutorial[Math.floor(tt / 3.5) % STORY.tutorial.length];
      ctx.save();
      ctx.font = `20px ${FONT}`;
      ctx.textAlign = 'center';
      ctx.fillStyle = COLORS.black;
      ctx.globalAlpha = 0.8;
      ctx.fillText(hint, 480, 268);
      ctx.restore();
    }
    if (api.Input && api.Input.drawTouchLanes) api.Input.drawTouchLanes(ctx, now - poseT < 0.15 ? lastLane : -1);
  },
  onLane(lane, at) {
    if (ended || leaving || api.Audio.now() < startTime - 0.2) return; // 카운트인 중엔 무시
    lastLane = lane;
    setPose(LANE_POSE[lane], api.Audio.now());
    judge.hit(lane, at);
    pump(api.Audio.now());
  },
  onAction(name) {
    if (name !== 'back' || ended) return;
    api.Audio.stopJangdan();
    leave(null);
  },
  onPointer() {},
  debug() { return { judge, chart, startTime }; },
};
