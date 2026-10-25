// 키보드·터치·마우스 → 레인/행동/포인터 이벤트. 이벤트 시점의 Audio.now()를 같이 넘긴다.
const W = 960, H = 540;
const BAND_Y = H * 0.82;                       // 아래 18% = 터치 레인 영역
const LANE_KEYS = {
  ArrowLeft: 0, KeyA: 0, ArrowDown: 1, KeyS: 1, ArrowUp: 2, KeyW: 2, ArrowRight: 3, KeyD: 3,
};
const CONFIRM_KEYS = new Set(['Space', 'Enter', 'NumpadEnter', 'KeyJ']);
const LANE_COLORS = ['#1f4e79', '#d9a441', '#f3e9d2', '#b5342c']; // 레인 오방색(청·황·백·적)
const LANE_LABELS = ['왼소매', '발', '돌기', '오른소매'];

const cbLane = [], cbAction = [], cbPointer = [];
let A = null;                                  // Audio
let canvasEl = null;
const held = new Map();                        // 입력원(키 코드·포인터 id) → 레인
const down = new Set();                        // 눌려 있는 키
const ptrLane = new Map();                     // 포인터 id → 레인(레인 영역에서 시작한 것)
let lastLane = -1, lastLaneAt = -1e9;

const nowT = () => (A ? A.now() : performance.now() / 1000);
const emitLane = (lane, at) => { lastLane = lane; lastLaneAt = at; for (const f of cbLane) f(lane, at); };
const emitAction = (name, at) => { for (const f of cbAction) f(name, at); };
const emitPointer = (x, y, type) => { for (const f of cbPointer) f(x, y, type); };

function toLogical(e) {
  const r = canvasEl.getBoundingClientRect();
  return { x: (e.clientX - r.left) / r.width * W, y: (e.clientY - r.top) / r.height * H };
}

function keyDown(e) {
  if (e.repeat || e.ctrlKey || e.metaKey || e.altKey) return;
  const at = nowT(), c = e.code;
  let used = false;
  if (c in LANE_KEYS) {
    used = true; down.add(c);
    const lane = LANE_KEYS[c];
    held.set(c, lane);
    emitLane(lane, at);
    if (lane === 0) emitAction('left', at);
    if (lane === 3) emitAction('right', at);
  } else if (CONFIRM_KEYS.has(c)) { used = true; emitAction('confirm', at); }
  else if (c === 'Escape') { used = true; emitAction('back', at); }
  if (used) e.preventDefault();
}
function keyUp(e) {
  const c = e.code;
  if (!(c in LANE_KEYS)) return;
  down.delete(c); held.delete(c);
  const lane = LANE_KEYS[c], at = nowT();
  // 같은 방향의 다른 키가 아직 눌려 있으면 뗌 이벤트를 내지 않는다
  const still = Object.keys(LANE_KEYS).some((k) => down.has(k) && LANE_KEYS[k] === lane);
  if (still) return;
  if (lane === 0) emitAction('leftUp', at);
  if (lane === 3) emitAction('rightUp', at);
}
function blur() {
  const at = nowT();
  const l = Object.keys(LANE_KEYS).some((k) => down.has(k) && LANE_KEYS[k] === 0);
  const r = Object.keys(LANE_KEYS).some((k) => down.has(k) && LANE_KEYS[k] === 3);
  down.clear(); held.clear(); ptrLane.clear();
  if (l) emitAction('leftUp', at);
  if (r) emitAction('rightUp', at);
}

function ptrDown(e) {
  if (e.pointerType === 'touch') Input.touchMode = true;
  const { x, y } = toLogical(e), at = nowT();
  try { canvasEl.setPointerCapture(e.pointerId); } catch (err) { /* 무시 */ }
  if (Input.laneZone && y >= BAND_Y) {
    const lane = Math.min(3, Math.max(0, Math.floor(x / (W / 4))));
    ptrLane.set(e.pointerId, lane); held.set('p' + e.pointerId, lane);
    emitLane(lane, at);
  } else emitPointer(x, y, 'down');
  e.preventDefault();
}
function ptrUp(e) {
  const { x, y } = toLogical(e), at = nowT();
  if (ptrLane.has(e.pointerId)) { ptrLane.delete(e.pointerId); held.delete('p' + e.pointerId); return; }
  if (e.type === 'pointercancel') return;
  emitPointer(x, y, 'up');
  emitAction('confirm', at);
}
function ptrMove(e) {
  if (ptrLane.has(e.pointerId)) return;
  const { x, y } = toLogical(e);
  emitPointer(x, y, 'move');
}

export const Input = {
  touchMode: false,
  laneZone: false,                             // main.js가 춤 장면에서만 true (터치 레인 영역 활성)

  init(canvas, Audio) {
    A = Audio; canvasEl = canvas;
    try { if (new URLSearchParams(location.search).has('touch')) Input.touchMode = true; } catch (e) { /* 무시 */ }
    window.addEventListener('keydown', keyDown);
    window.addEventListener('keyup', keyUp);
    window.addEventListener('blur', blur);
    canvas.addEventListener('pointerdown', ptrDown);
    canvas.addEventListener('pointerup', ptrUp);
    canvas.addEventListener('pointercancel', ptrUp);
    canvas.addEventListener('pointermove', ptrMove);
    canvas.addEventListener('contextmenu', (e) => e.preventDefault());
  },
  onLane(cb) { cbLane.push(cb); },
  onAction(cb) { cbAction.push(cb); },
  onPointer(cb) { cbPointer.push(cb); },

  // 지금 눌려 있거나 막 눌린 레인(없으면 -1). drawTouchLanes에 넘긴다.
  get activeLane() {
    for (const l of held.values()) return l;
    return nowT() - lastLaneAt < 0.12 ? lastLane : -1;
  },

  // 화면 아래 네 칸 안내. touchMode일 때만 그린다.
  drawTouchLanes(ctx, activeLane = -1) {
    if (!Input.touchMode) return;
    const cw = W / 4, h = H - BAND_Y;
    ctx.save();
    ctx.textAlign = 'center'; ctx.textBaseline = 'middle';
    ctx.font = "22px 'Nanum Brush Script','Noto Serif KR',serif";
    for (let i = 0; i < 4; i++) {
      const x = i * cw, on = i === activeLane;
      ctx.globalAlpha = on ? 0.5 : 0.16; ctx.fillStyle = LANE_COLORS[i];
      ctx.fillRect(x, BAND_Y, cw, h);
      ctx.globalAlpha = 0.5; ctx.strokeStyle = '#f3e9d2'; ctx.lineWidth = 2;
      ctx.strokeRect(x + 3, BAND_Y + 3, cw - 6, h - 6);
      ctx.globalAlpha = on ? 1 : 0.75; ctx.fillStyle = i === 2 ? '#15110f' : '#f3e9d2';
      ctx.fillText(LANE_LABELS[i], x + cw / 2, BAND_Y + h / 2);
    }
    ctx.restore();
  },
};
