// chart/rhythm 순수 로직 테스트. 실행: node tests/unit.mjs
import { SPIRITS, makeChart, noteTimes, timeOfBeat } from '../src/js/chart.js';
import { Judge, WINDOWS } from '../src/js/rhythm.js';

let fails = 0, checks = 0;
const ok = (c, msg) => { checks++; if (!c) { fails++; console.log('FAIL', msg); } };

for (const sp of SPIRITS) {
  const nights = sp === 'yeoksin' ? [5] : [1, 2, 3, 4, 5];
  for (const n of nights) for (const seed of [1, 7, 12345]) {
    const tag = `${sp} night${n} seed${seed}`;
    const c = makeChart(sp, n, seed);
    const c2 = makeChart(sp, n, seed);
    ok(JSON.stringify(c) === JSON.stringify(c2), `${tag} 결정적`);
    ok(c.notes.length > 0 && c.notes.length === c.total, `${tag} 음표 수`);
    // 정렬·레인
    for (let i = 0; i < c.notes.length; i++) {
      const x = c.notes[i];
      ok(x.lane >= 0 && x.lane <= 3 && Number.isInteger(x.lane), `${tag} 레인 ${i}`);
      if (i) ok(x.beat >= c.notes[i - 1].beat, `${tag} 시간순 ${i}`);
      if (i) ok(!(x.beat === c.notes[i - 1].beat && x.lane === c.notes[i - 1].lane), `${tag} 같은 박 같은 레인 ${i}`);
      ok(x.beat >= c.lead, `${tag} 첫 음표는 lead 이후`);
    }
    ok(c.lengthBeats > c.notes[c.notes.length - 1].beat, `${tag} lengthBeats`);
    // 같은 레인 3연속 금지
    for (let i = 2; i < c.notes.length; i++)
      ok(!(c.notes[i].lane === c.notes[i - 1].lane && c.notes[i].lane === c.notes[i - 2].lane), `${tag} 3연속 ${i}`);
    // 간격(초)
    const ts = noteTimes(c, 0);
    const lim = sp === 'cough' ? 0.14 : 0.16;
    for (let i = 1; i < ts.length; i++) {
      const g = ts[i] - ts[i - 1];
      if (c.notes[i].beat === c.notes[i - 1].beat) continue;     // 겹음표
      ok(g >= lim - 1e-9, `${tag} 간격 ${i}: ${g.toFixed(3)}s`);
    }
    // 겹음표는 pox/yeoksin만, 짝은 정확히 둘
    const pairs = c.notes.filter((x) => x.pair);
    if (sp === 'pox' || sp === 'yeoksin') ok(pairs.length > 0, `${tag} 겹음표 있음`); else ok(pairs.length === 0, `${tag} 겹음표 없음`);
    for (const p of pairs) ok(c.notes.filter((x) => x.beat === p.beat).length === 2, `${tag} 짝은 둘`);
    for (const x of c.notes) if (!x.pair) ok(c.notes.filter((y) => y.beat === x.beat).length === 1, `${tag} 홑음표`);
    // phases
    ok(c.phases[0].startBeat === 0 && c.phases[0].kind === 'dance', `${tag} 첫 phase`);
    for (let i = 1; i < c.phases.length; i++) ok(c.phases[i].startBeat > c.phases[i - 1].startBeat, `${tag} phase 순서`);
    if (sp === 'yeoksin') {
      const songs = c.phases.filter((p) => p.kind === 'song');
      ok(songs.length === 8 && songs.every((p, i) => p.verse === i), `${tag} 노래 8구절`);
      ok(songs.every((p, i) => i === 0 || p.startBeat - songs[i - 1].startBeat === 2), `${tag} 두 박마다`);
      const inSong = c.notes.filter((x) => x.beat >= songs[0].startBeat);
      ok(inSong.length === 16, `${tag} 노래 음표 16 (${inSong.length})`);
      ok(c.notes.length - inSong.length === 96, `${tag} 춤 음표 96 (${c.notes.length - inSong.length})`);
      ok(c.phases.filter((p) => p.kind === 'dance').length === 2, `${tag} 춤 단계 둘`);
    } else ok(c.phases.length === 1, `${tag} phase 하나`);
    // 개수 범위
    if (sp !== 'yeoksin') ok(c.notes.length === [24, 36, 48, 64, 64][n - 1], `${tag} 개수 ${c.notes.length}`);
    // bpm
    if (sp === 'fever') {
      ok(c.bpm === 96 && c.bpmChanges.length === 2 && c.bpmChanges[0].bpm === 106 && c.bpmChanges[1].bpm === 116, `${tag} fever bpm`);
      ok(Math.abs(c.bpmChanges[0].beat - c.lengthBeats / 3) <= 1 && Math.abs(c.bpmChanges[1].beat - c.lengthBeats * 2 / 3) <= 1, `${tag} fever 변속 위치`);
    } else ok(c.bpmChanges.length === 0, `${tag} 변속 없음`);
    ok(c.bpm === { fever: 96, chill: 104, cough: 112, pox: 108, yeoksin: 112 }[sp], `${tag} bpm`);
    // 성격 특징
    if (sp === 'chill') ok(c.notes.filter((x) => x.beat % 1 === 0.5).length > c.notes.length * 0.35, `${tag} 엇박 많음`);
    if (sp === 'cough') {
      const trip = c.notes.filter((x) => Math.abs((x.beat % 1) - 1 / 3) < 1e-6 || Math.abs((x.beat % 1) - 2 / 3) < 1e-6).length;
      ok(trip >= c.notes.length * 0.6, `${tag} 셋잇단 ${trip}`);
    }
    if (sp === 'pox') { const r = pairs.length / c.notes.length; ok(r > 0.15 && r < 0.6, `${tag} 겹음표 비율 ${r.toFixed(2)}`); }
    // 다른 시드는 다른 악보
    if (seed === 1 && sp !== 'fever') ok(JSON.stringify(c.notes) !== JSON.stringify(makeChart(sp, n, 2).notes), `${tag} 시드 차이`);
  }
}

// noteTimes가 bpmChanges를 반영
{
  const c = makeChart('fever', 3, 1);
  const ts = noteTimes(c, 10);
  const c0 = c.bpmChanges[0];
  const flat = c.notes.map((n) => 10 + n.beat * 60 / c.bpm);
  const k = c.notes.findIndex((n) => n.beat > c0.beat);
  ok(Math.abs(ts[0] - flat[0]) < 1e-9, '변속 전 시간 일치');
  ok(ts[k] < flat[k], '변속 후 시간은 더 이르다');
  const manual = 10 + c0.beat * 60 / 96 + (c.notes[k].beat - c0.beat) * 60 / 106;
  const c1 = c.bpmChanges[1];
  if (c.notes[k].beat <= c1.beat) ok(Math.abs(ts[k] - manual) < 1e-9, '변속 구간 시간 수식');
  ok(Math.abs(timeOfBeat(c, 10, c1.beat) - (10 + c0.beat * 60 / 96 + (c1.beat - c0.beat) * 60 / 106)) < 1e-9, 'timeOfBeat');
  ok(ts.every((t, i) => i === 0 || t >= ts[i - 1]), '시간 단조 증가');
}

// Judge: 완벽 입력 → kneel, 전부 놓침 → flee/broken(역신 본체 제외)
function play(chart, mode) {
  const start = 100, j = new Judge(chart, start);
  const order = chart.notes.map((n, i) => ({ n, t: j.times[i] })).sort((a, b) => a.t - b.t);
  for (const { n, t } of order) {
    if (mode === 'perfect') { j.update(t - 0.02); const r = j.hit(n.lane, t); ok(r.grade === 'jeol', `${chart.spirit} 완벽 jeol`); }
    else if (mode === 'jang') { j.update(t - 0.1); j.hit(n.lane, t + 0.07); }
    else if (mode === 'bak') { j.update(t - 0.1); j.hit(n.lane, t + 0.12); }
    else j.update(t + 0.2);
  }
  j.update(j.times[j.times.length - 1] + 1);
  return j;
}
for (const sp of SPIRITS) {
  const n = sp === 'yeoksin' ? 5 : 3;
  const c = makeChart(sp, n, 3);
  const p = play(c, 'perfect');
  ok(p.done && p.outcome() === 'kneel' && p.hyung === 0 && p.deok === 100 && !p.broken, `${sp} 완벽 → kneel`);
  ok(p.stats.jeol === c.notes.length && p.stats.miss === 0 && p.combo === c.notes.length, `${sp} 완벽 통계`);
  const m = play(c, 'none');
  if (sp === 'yeoksin') ok(m.outcome() === 'kneel' && m.deok >= 1, `${sp} 전부 놓쳐도 kneel`);
  else ok(m.broken && m.outcome() === 'flee' && m.hyung === 100 && m.stats.miss > 0, `${sp} 전부 놓침 → flee/broken`);
  const jg = play(c, 'jang');
  ok(jg.outcome() === 'kneel' && Math.abs(jg.hyung - 100 * 0.2) < 1e-6, `${sp} 장만 → 흉 20 (${jg.hyung.toFixed(2)})`);
  const bk = play(c, 'bak');
  ok(bk.outcome() === (sp === 'yeoksin' ? 'kneel' : 'flee'), `${sp} 박만 → ${bk.outcome()}`);
}

// Judge 세부
{
  const c = makeChart('fever', 1, 1);
  const j = new Judge(c, 0);
  const t0 = j.times[0], l0 = c.notes[0].lane;
  ok(j.hit((l0 + 1) % 4, t0).grade === null, '다른 레인은 헛손질');
  ok(j.hit(l0, t0 + 0.2).grade === null && j.stats.miss === 0 && j.deok === 100, '창 밖은 헛손질·무감점');
  ok(j.outcome() === null, '진행 중 outcome null');
  ok(j.hit(l0, t0 - WINDOWS.jang + 0.001).grade === 'jang', '장 판정');
  ok(j.drain().length === 1 && j.drain().length === 0, 'drain 비움');
  const j2 = new Judge(c, 0);
  j2.hit(l0, t0 + WINDOWS.bak - 0.001);
  ok(j2.deok === 98, '박 → 덕 -2');
  j2.update(j2.times[1] + 0.2);
  ok(j2.deok === 90 && j2.stats.miss === 1 && j2.combo === 0, '놓침 → 덕 -8, 콤보 끊김');
  const up = j2.upcoming(0, 100);
  ok(up.length === c.notes.length - 2 && up[0].dt === up[0].t, 'upcoming');
  // 노래 구간 덕 감점 없음
  const y = makeChart('yeoksin', 5, 1), jy = new Judge(y, 0);
  const songAt = y.phases.find((p) => p.kind === 'song').startBeat;
  const dance = y.notes.filter((n) => n.beat < songAt).length;
  jy.update(jy.times[dance - 1] + 1);
  const deokAfterDance = jy.deok;
  jy.update(jy.times[jy.times.length - 1] + 1);
  ok(deokAfterDance < 100 && jy.deok === deokAfterDance, '노래 구간 덕 감점 없음');
}

console.log(`${checks} checks, ${fails} failed`);
process.exit(fails ? 1 : 0);
