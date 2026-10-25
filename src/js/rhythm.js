// 판정 엔진(순수). node에서도 실행된다.
import { noteTimes } from './chart.js';

export const WINDOWS = { jeol: 0.045, jang: 0.090, bak: 0.135 };
const MULT = { jeol: 1.0, jang: 0.8, bak: 0.5 };       // 흉을 깎는 비율
const DEOK_COST = { bak: 2, miss: 8 };
const KNEEL_AT = 25;                                    // 흉이 이 이하면 굴복

export class Judge {
  constructor(chart, startTime = 0) {
    this.chart = chart;
    this.startTime = startTime;
    this.times = noteTimes(chart, startTime);
    this.notes = chart.notes;
    this.state = new Array(this.notes.length).fill(0);   // 0 미판정, 1 적중, 2 놓침
    this._hyung = 100;
    this._deok = 100;
    this._combo = 0;
    this.maxCombo = 0;
    this._stats = { jeol: 0, jang: 0, bak: 0, miss: 0, total: this.notes.length };
    this._events = [];
    this._now = -Infinity;
    this._unit = 100 / Math.max(1, this.notes.length);
    const song = chart.phases.find((p) => p.kind === 'song');
    this._songAt = song ? song.startBeat : Infinity;     // 노래 구간: 덕 감점 없음
    this._yeok = chart.spirit === 'yeoksin';
  }

  _loseDeok(note, n) {
    if (note.beat >= this._songAt) return;
    // 역신 본체는 끝내 무릎 꿇어야 하므로 덕이 0까지 내려가 춤이 끊기지는 않는다
    this._deok = Math.max(this._yeok ? 1 : 0, this._deok - n);
  }

  update(now) {
    this._now = now;
    for (let i = 0; i < this.notes.length; i++) {
      if (this.state[i] || now <= this.times[i] + WINDOWS.bak) continue;
      this.state[i] = 2;
      this._stats.miss++;
      this._combo = 0;
      this._loseDeok(this.notes[i], DEOK_COST.miss);
      this._events.push({ type: 'miss', grade: 'miss', note: this.notes[i], at: now, t: this.times[i] });
    }
  }

  // 그 레인에서 at에 가장 가까운 미판정 음표 하나만 본다. 창 밖이면 헛손질(감점 없음).
  hit(lane, at) {
    if (this.broken) return { grade: null, note: null };
    let best = -1, bd = Infinity;
    for (let i = 0; i < this.notes.length; i++) {
      if (this.state[i] || this.notes[i].lane !== lane) continue;
      const d = Math.abs(at - this.times[i]);
      if (d < bd) { bd = d; best = i; }
    }
    if (best < 0 || bd > WINDOWS.bak) return { grade: null, note: null };
    const grade = bd <= WINDOWS.jeol ? 'jeol' : bd <= WINDOWS.jang ? 'jang' : 'bak';
    const note = this.notes[best];
    this.state[best] = 1;
    this._stats[grade]++;
    this._hyung = Math.max(0, this._hyung - this._unit * MULT[grade]);
    if (grade === 'bak') this._loseDeok(note, DEOK_COST.bak);
    this._combo++;
    this.maxCombo = Math.max(this.maxCombo, this._combo);
    this._events.push({ type: 'hit', grade, note, at, t: this.times[best], dt: at - this.times[best] });
    return { grade, note };
  }

  drain() { const e = this._events; this._events = []; return e; }

  get hyung() { return this._hyung < 1e-9 ? 0 : this._hyung; }
  get deok() { return this._deok; }
  get combo() { return this._combo; }
  get stats() { return { ...this._stats }; }
  get done() {
    if (this.state.some((s) => !s)) return false;
    return this._now > this.times[this.times.length - 1] + WINDOWS.bak;
  }
  get broken() { return this._deok <= 0; }

  outcome() {
    if (this.broken) return 'flee';
    if (!this.done) return null;
    if (this._yeok) return 'kneel';
    return this.hyung <= KNEEL_AT ? 'kneel' : 'flee';
  }

  // 그릴 음표: 아직 판정 안 된 것 중 horizonSec 안에 도달하는 것
  upcoming(now, horizonSec) {
    const out = [];
    for (let i = 0; i < this.notes.length; i++) {
      const dt = this.times[i] - now;
      if (dt > horizonSec) break;
      if (!this.state[i]) out.push({ note: this.notes[i], t: this.times[i], dt });
    }
    return out;
  }
}
