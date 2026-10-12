// Keyboard input: held state plus per-frame "pressed"/"released" edges.
const BLOCK = new Set(['ArrowUp', 'ArrowDown', 'ArrowLeft', 'ArrowRight', 'Space', 'ShiftLeft', 'ShiftRight', 'Tab']);

const held = new Set();
const pressedQ = new Set();
const releasedQ = new Set();
let pressed = new Set();
let released = new Set();
const listeners = [];

export function initInput(target) {
  window.addEventListener('keydown', (e) => {
    if (BLOCK.has(e.code)) e.preventDefault();
    listeners.forEach((fn) => fn(e));
    if (e.repeat) return;
    held.add(e.code);
    pressedQ.add(e.code);
  });
  window.addEventListener('keyup', (e) => {
    if (BLOCK.has(e.code)) e.preventDefault();
    held.delete(e.code);
    releasedQ.add(e.code);
  });
  window.addEventListener('blur', () => {
    held.forEach((c) => releasedQ.add(c));
    held.clear();
  });
  if (target) target.focus();
}

export function onAnyKey(fn) { listeners.push(fn); }

// Virtual keys from the touch overlay (touch.js). Same sets as the keyboard, so
// game logic cannot tell a touch button from a key. Hold = vDown ... vUp.
export function vDown(code) {
  if (held.has(code)) return;
  held.add(code);
  pressedQ.add(code);
}
export function vUp(code) {
  if (!held.has(code)) return;
  held.delete(code);
  releasedQ.add(code);
}
// One-frame press without hold (UI confirm taps).
export function vTap(code) {
  pressedQ.add(code);
  releasedQ.add(code);
}

// Called once per fixed update step, before game logic.
export function pollInput() {
  pressed = new Set(pressedQ);
  released = new Set(releasedQ);
  pressedQ.clear();
  releasedQ.clear();
}

const MAP = {
  up: ['ArrowUp', 'KeyW'],
  down: ['ArrowDown', 'KeyS'],
  left: ['ArrowLeft', 'KeyA'],
  right: ['ArrowRight', 'KeyD'],
  attack: ['KeyZ', 'KeyJ'],
  swap: ['KeyX', 'KeyK'],
  cast: ['KeyC', 'KeyL'],
  song: ['KeyV'],
  dodge: ['ShiftLeft', 'ShiftRight', 'Space'],
  ult: ['KeyF'],
  item1: ['Digit1'],
  item2: ['Digit2'],
  item3: ['Digit3'],
  ok: ['KeyZ', 'Enter', 'Space', 'KeyJ'],
  cancel: ['KeyX', 'Escape', 'Backspace'],
  menu: ['Escape'],
  mute: ['KeyM'],
};

export const input = {
  down(action) { return MAP[action].some((c) => held.has(c)); },
  pressed(action) { return MAP[action].some((c) => pressed.has(c)); },
  released(action) { return MAP[action].some((c) => released.has(c)); },
  axis() {
    let x = 0, y = 0;
    if (this.down('left')) x -= 1;
    if (this.down('right')) x += 1;
    if (this.down('up')) y -= 1;
    if (this.down('down')) y += 1;
    return { x, y };
  },
  // Consume all edges so a key that closed a dialog does not also trigger an attack.
  flush() { pressed.clear(); released.clear(); },
};
