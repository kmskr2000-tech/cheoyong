// Story: cutscenes, NPC dialogue, quests, shop, boss sequence and ending.
// All names come from 삼국유사 설화 or are original (보리, 석구, 박노인, 난영).
import { G, BAL, VIEW_W, VIEW_H, SCALE, TS, wait, toast, addExp } from './state.js';
import { say, choose, font, wrap, W, H, panel } from './ui.js';
import { input } from './input.js';
import { sfx, playMusic } from './audio.js';
import { SPR, PROPS, C, drawBoss, rng, T } from './gfx.js';
import { Boss, obangRipple, Ring, TextPop } from './entities.js';

// ------------------------------------------------------------ cutscene player
export function playCutscene(panels, opt = {}) {
  return new Promise((res) => {
    G.cutscene = { panels, i: 0, line: 0, chars: 0, t: 0, res, skippable: !!opt.skippable };
  });
}
export function updateCutscene(dt) {
  const cs = G.cutscene;
  if (!cs) return;
  cs.t += dt;
  const pnl = cs.panels[cs.i];
  const line = pnl.lines[cs.line] || '';
  cs.chars = Math.min(line.length, cs.chars + dt * 30);
  const end = () => { G.cutscene = null; input.flush(); cs.res(); };
  if (cs.skippable && input.pressed('menu')) { end(); return; }
  if (input.pressed('ok') && cs.t > 0.3) {
    if (cs.chars < line.length) cs.chars = line.length;
    else {
      sfx('blip');
      cs.line++; cs.chars = 0;
      if (cs.line >= pnl.lines.length) {
        cs.i++; cs.line = 0; cs.t = 0;
        if (cs.i >= cs.panels.length) end();
      }
    }
  }
}
export function drawCutscene(ctx) {
  const cs = G.cutscene;
  if (!cs) return;
  const pnl = cs.panels[cs.i];
  ctx.setTransform(SCALE, 0, 0, SCALE, 0, 0);
  ctx.imageSmoothingEnabled = false;
  ctx.fillStyle = '#000'; ctx.fillRect(0, 0, VIEW_W, VIEW_H);
  pnl.draw(ctx, G.time, cs.t);
  ctx.setTransform(1, 0, 0, 1, 0, 0);
  // fade in
  if (cs.t < 0.6) { ctx.fillStyle = `rgba(0,0,0,${1 - cs.t / 0.6})`; ctx.fillRect(0, 0, W, H); }
  // letterbox caption
  ctx.fillStyle = 'rgba(0,0,0,0.78)'; ctx.fillRect(0, H - 120, W, 120);
  ctx.fillStyle = C.goldD; ctx.fillRect(0, H - 120, W, 2);
  const line = pnl.lines[cs.line] || '';
  ctx.font = font(21, false, true);
  ctx.fillStyle = '#efe6cf';
  const rows = wrap(ctx, line.slice(0, Math.floor(cs.chars)), W - 160);
  rows.forEach((r, i) => ctx.fillText(r, 80, H - 76 + i * 30));
  if (pnl.title) {
    ctx.font = font(15, true, true); ctx.fillStyle = C.gold; ctx.fillText(pnl.title, 80, H - 98);
  }
  ctx.font = font(13); ctx.fillStyle = '#8a8070';
  ctx.textAlign = 'right';
  ctx.fillText(cs.skippable ? 'Z 다음   ESC 건너뛰기' : 'Z 다음', W - 30, H - 14);
  ctx.textAlign = 'left';
}

// ------------------------------------------------------------ panel art helpers
function sky(ctx, top, bot) {
  const g = ctx.createLinearGradient(0, 0, 0, VIEW_H);
  g.addColorStop(0, top); g.addColorStop(1, bot);
  ctx.fillStyle = g; ctx.fillRect(0, 0, VIEW_W, VIEW_H);
}
function stars(ctx, seed, n, t) {
  const r = rng(seed);
  for (let i = 0; i < n; i++) {
    const x = Math.floor(r() * VIEW_W), y = Math.floor(r() * 120), tw = Math.sin(t * 2 + i) > 0.7;
    ctx.fillStyle = tw ? '#ffffff' : '#8a90b0'; ctx.fillRect(x, y, 1, 1);
  }
}
function moon(ctx, x, y, r) {
  ctx.fillStyle = 'rgba(240,230,190,0.12)'; ctx.beginPath(); ctx.arc(x, y, r * 2.2, 0, Math.PI * 2); ctx.fill();
  ctx.fillStyle = '#efe6c4'; ctx.beginPath(); ctx.arc(x, y, r, 0, Math.PI * 2); ctx.fill();
  ctx.fillStyle = '#d8ceaa'; ctx.fillRect(x - 3, y - 2, 3, 2); ctx.fillRect(x + 2, y + 3, 2, 2);
}
function big(ctx, spr, x, y, s) { ctx.drawImage(spr, Math.round(x - spr.width * s / 2), Math.round(y - spr.height * s), spr.width * s, spr.height * s); }
function pineRow(ctx, y, seed, col = '#0a120e') {
  const r = rng(seed);
  ctx.fillStyle = col;
  for (let x = -10; x < VIEW_W + 10; x += 8 + Math.floor(r() * 10)) {
    const h = 20 + r() * 26;
    ctx.beginPath(); ctx.moveTo(x, y - h); ctx.lineTo(x + 10, y); ctx.lineTo(x - 10, y); ctx.fill();
  }
  ctx.fillRect(0, y, VIEW_W, VIEW_H - y);
}
function miasma(ctx, t, amount = 30, yMin = 150) {
  const r = rng(99);
  for (let i = 0; i < amount; i++) {
    const x = (r() * VIEW_W + t * (5 + r() * 10)) % VIEW_W, y = yMin + r() * (VIEW_H - yMin) - (t * 6 + r() * 40) % 60;
    ctx.fillStyle = `rgba(111,191,74,${0.08 + r() * 0.12})`; ctx.fillRect(Math.round(x), Math.round(y), 4 + Math.floor(r() * 6), 3);
  }
}

const P = {
  palaceSea(ctx, t) {
    sky(ctx, '#03142a', '#0a2f4a');
    // light rays
    for (let i = 0; i < 6; i++) {
      ctx.fillStyle = `rgba(150,220,255,${0.04 + 0.02 * Math.sin(t + i)})`;
      ctx.beginPath(); ctx.moveTo(60 + i * 70, 0); ctx.lineTo(90 + i * 70, 0); ctx.lineTo(40 + i * 70 + Math.sin(t * 0.5) * 10, 270); ctx.lineTo(i * 70, 270); ctx.fill();
    }
    // underwater palace silhouette (기둥 + 넓은 지붕)
    ctx.fillStyle = '#06203a';
    ctx.fillRect(130, 120, 220, 70);
    ctx.beginPath(); ctx.moveTo(110, 124); ctx.quadraticCurveTo(240, 92, 370, 124); ctx.lineTo(370, 130); ctx.lineTo(110, 130); ctx.fill();
    ctx.beginPath(); ctx.moveTo(170, 96); ctx.quadraticCurveTo(240, 74, 310, 96); ctx.lineTo(310, 100); ctx.lineTo(170, 100); ctx.fill();
    ctx.fillRect(190, 100, 100, 22);
    ctx.fillStyle = '#0c3050'; for (let x = 140; x < 350; x += 24) ctx.fillRect(x, 132, 6, 58);
    ctx.fillStyle = 'rgba(224,192,112,0.6)'; ctx.fillRect(236, 104, 8, 8);
    // seabed
    ctx.fillStyle = '#04101e'; ctx.fillRect(0, 190, VIEW_W, 80);
    ctx.fillStyle = '#0a2236'; for (let x = 0; x < VIEW_W; x += 30) { ctx.beginPath(); ctx.ellipse(x + 10, 194, 22, 8, 0, Math.PI, 0); ctx.fill(); }
    // seaweed
    ctx.fillStyle = '#0f3a2a';
    for (let i = 0; i < 12; i++) { const x = 20 + i * 40; for (let y = 0; y < 30; y += 3) ctx.fillRect(x + Math.round(Math.sin(t * 1.5 + y * 0.2 + i) * 3), 190 - y, 2, 3); }
    // bubbles
    const r = rng(5);
    for (let i = 0; i < 20; i++) { const x = r() * VIEW_W, y = (VIEW_H - ((t * 20 + r() * 300) % 300)); ctx.fillStyle = 'rgba(180,230,255,0.4)'; ctx.fillRect(Math.round(x), Math.round(y), 2, 2); }
    big(ctx, SPR.dragonKing, 210, 206, 3);
    big(ctx, SPR.player.up[0], 280, 212, 3);
  },
  dragonKing(ctx, t) {
    sky(ctx, '#041a30', '#082a44');
    ctx.fillStyle = 'rgba(224,192,112,0.08)'; ctx.beginPath(); ctx.arc(240, 120, 110 + Math.sin(t * 2) * 4, 0, Math.PI * 2); ctx.fill();
    big(ctx, SPR.dragonKing, 240, 230, 9);
    // 용패 (dragon scale token)
    const y = 60 + Math.sin(t * 2) * 3;
    ctx.fillStyle = 'rgba(255,230,140,0.25)'; ctx.beginPath(); ctx.arc(380, y + 12, 22, 0, Math.PI * 2); ctx.fill();
    ctx.fillStyle = C.ink; ctx.beginPath(); ctx.moveTo(380, y - 4); ctx.lineTo(394, y + 12); ctx.lineTo(380, y + 30); ctx.lineTo(366, y + 12); ctx.fill();
    ctx.fillStyle = '#5ac8b8'; ctx.beginPath(); ctx.moveTo(380, y - 1); ctx.lineTo(391, y + 12); ctx.lineTo(380, y + 27); ctx.lineTo(369, y + 12); ctx.fill();
    ctx.fillStyle = C.goldL; ctx.fillRect(379, y + 4, 2, 16); ctx.fillRect(374, y + 11, 12, 2);
  },
  crossing(ctx, t) {
    sky(ctx, '#050a1c', '#14203a');
    stars(ctx, 3, 70, t);
    moon(ctx, 380, 50, 16);
    // coast with pines (left) and the rock off 개운포
    ctx.fillStyle = '#0a120e';
    ctx.beginPath(); ctx.moveTo(0, 140); ctx.lineTo(120, 150); ctx.lineTo(160, 175); ctx.lineTo(0, 190); ctx.fill();
    pineRow(ctx, 150, 7);
    ctx.fillStyle = '#0d1424'; ctx.beginPath(); ctx.moveTo(300, 175); ctx.lineTo(318, 150); ctx.lineTo(340, 158); ctx.lineTo(352, 175); ctx.fill();
    // sea
    ctx.fillStyle = '#0b1a32'; ctx.fillRect(0, 170, VIEW_W, 100);
    for (let y = 172; y < 270; y += 6) for (let x = (y * 7) % 30; x < VIEW_W; x += 30) { ctx.fillStyle = 'rgba(160,190,230,0.25)'; ctx.fillRect(x + Math.round(Math.sin(t + y) * 4), y, 8, 1); }
    // moon path
    for (let y = 175; y < 270; y += 4) { ctx.fillStyle = 'rgba(240,230,190,0.3)'; ctx.fillRect(372 + Math.round(Math.sin(t * 2 + y) * 6), y, 16 - (y - 175) / 10, 1); }
    // 처용 rising from the waves
    const rise = Math.min(1, t / 3);
    ctx.save(); ctx.beginPath(); ctx.rect(0, 0, VIEW_W, 196); ctx.clip();
    big(ctx, SPR.player.down[0], 250, 200 - rise * 14, 3);
    ctx.restore();
    ctx.fillStyle = 'rgba(200,230,255,0.5)'; ctx.fillRect(228, 194, 44, 2);
  },
  seorabeol(ctx, t) {
    sky(ctx, '#060814', '#1a1830');
    stars(ctx, 9, 50, t);
    moon(ctx, 80, 44, 13);
    // mountains
    ctx.fillStyle = '#0e1222'; ctx.beginPath(); ctx.moveTo(0, 150); ctx.lineTo(90, 100); ctx.lineTo(170, 140); ctx.lineTo(260, 92); ctx.lineTo(380, 136); ctx.lineTo(480, 104); ctx.lineTo(480, 270); ctx.lineTo(0, 270); ctx.fill();
    // tumuli
    ctx.fillStyle = '#121a1a';
    for (const [x, r] of [[60, 40], [140, 30], [400, 46]]) { ctx.beginPath(); ctx.ellipse(x, 200, r, r * 0.7, 0, Math.PI, 0); ctx.fill(); }
    // 첨성대 + 석탑 silhouettes
    ctx.drawImage(PROPS.cheomseongdae(), 250, 118);
    ctx.drawImage(PROPS.pagoda(), 320, 142);
    ctx.fillStyle = 'rgba(6,8,20,0.45)'; ctx.fillRect(240, 110, 130, 100);
    ctx.fillStyle = '#0a0e14'; ctx.fillRect(0, 200, VIEW_W, 70);
    // village roofs (초가)
    ctx.fillStyle = '#141a18';
    for (let x = 10; x < VIEW_W; x += 70) { ctx.beginPath(); ctx.ellipse(x + 20, 206, 26, 12, 0, Math.PI, 0); ctx.fill(); }
    // lit windows
    ctx.fillStyle = 'rgba(255,200,110,0.7)'; ctx.fillRect(40, 212, 3, 3); ctx.fillRect(180, 214, 3, 3);
    miasma(ctx, t, 50, 150);
  },
  titleCard(text, sub) {
    return (ctx, t) => {
      sky(ctx, '#05060c', '#0b0f20');
      miasma(ctx, t, 30, 160);
      ctx.setTransform(1, 0, 0, 1, 0, 0);
      ctx.textAlign = 'center';
      ctx.font = font(18, false, true); ctx.fillStyle = C.gold; ctx.fillText(sub, W / 2, H / 2 - 70);
      ctx.font = font(52, true, true); ctx.fillStyle = '#efe4c4'; ctx.fillText(text, W / 2, H / 2 - 10);
      ctx.fillStyle = C.goldD; ctx.fillRect(W / 2 - 120, H / 2 + 10, 240, 2);
      ctx.textAlign = 'left';
      ctx.setTransform(SCALE, 0, 0, SCALE, 0, 0);
    };
  },
  palace(ctx, t) {
    sky(ctx, '#0a0608', '#1a0e10');
    // pillars and dais (신라 궁궐: 붉은 기둥 + 단청 대신 소박한 금빛)
    ctx.fillStyle = '#2a0e10'; ctx.fillRect(0, 180, VIEW_W, 90);
    ctx.fillStyle = '#3a1418'; for (let x = 0; x < VIEW_W; x += 40) ctx.fillRect(x, 180, 39, 1);
    for (const x of [40, 120, 352, 432]) {
      ctx.fillStyle = '#0a0406'; ctx.fillRect(x - 1, 20, 18, 160);
      ctx.fillStyle = '#6a1a1e'; ctx.fillRect(x, 20, 16, 160);
      ctx.fillStyle = '#8a2a2a'; ctx.fillRect(x + 3, 20, 3, 160);
      ctx.fillStyle = C.goldD; ctx.fillRect(x, 30, 16, 3);
    }
    ctx.fillStyle = '#1a0a0c'; ctx.fillRect(0, 0, VIEW_W, 22);
    ctx.fillStyle = C.goldD; ctx.fillRect(0, 22, VIEW_W, 2);
    // dais + screen with 금관 문양
    ctx.fillStyle = '#2a1a10'; ctx.fillRect(170, 150, 140, 30); ctx.fillStyle = '#3a2614'; ctx.fillRect(160, 172, 160, 10);
    ctx.fillStyle = '#1a1210'; ctx.fillRect(180, 60, 120, 92);
    ctx.fillStyle = C.goldD; for (let i = 0; i < 5; i++) { ctx.fillRect(196 + i * 22, 70, 3, 30); ctx.fillRect(190 + i * 22, 80, 15, 2); }
    // lamps
    for (const x of [150, 330]) { ctx.fillStyle = 'rgba(255,190,100,0.25)'; ctx.beginPath(); ctx.arc(x, 120, 26, 0, Math.PI * 2); ctx.fill(); ctx.fillStyle = '#ffcf6a'; ctx.fillRect(x - 3, 116, 6, 8); }
    big(ctx, SPR.king, 240, 152, 4);
    big(ctx, SPR.official, 120, 250, 3);
    big(ctx, SPR.player.up[0], 240, 262, 4);
  },
  mask(ctx, t) {
    sky(ctx, '#05060c', '#121624');
    moon(ctx, 400, 40, 12);
    // a gate with 처용 face painted
    ctx.fillStyle = '#1a120c'; ctx.fillRect(120, 40, 240, 230);
    ctx.fillStyle = '#4a3420'; ctx.fillRect(130, 50, 220, 220);
    ctx.fillStyle = '#3a2818'; ctx.fillRect(238, 50, 4, 220);
    // painted face on paper
    const x = 190, y = 90;
    ctx.fillStyle = '#d8ccaa'; ctx.fillRect(x, y, 100, 120);
    ctx.fillStyle = '#b83a2a'; ctx.beginPath(); ctx.ellipse(x + 50, y + 62, 34, 42, 0, 0, Math.PI * 2); ctx.fill();
    ctx.fillStyle = C.ink; ctx.fillRect(x + 22, y + 14, 56, 12); ctx.fillRect(x + 6, y + 22, 88, 6);
    ctx.fillStyle = '#f0e0c0'; ctx.fillRect(x + 30, y + 50, 14, 6); ctx.fillRect(x + 56, y + 50, 14, 6);
    ctx.fillStyle = C.ink; ctx.fillRect(x + 34, y + 51, 5, 4); ctx.fillRect(x + 60, y + 51, 5, 4);
    ctx.fillStyle = '#e8c860'; ctx.fillRect(x + 40, y + 82, 20, 4);
    ctx.fillStyle = '#2a6a3a'; ctx.fillRect(x + 14, y + 96, 8, 10); ctx.fillRect(x + 78, y + 96, 8, 10);
    // lantern glow
    ctx.fillStyle = 'rgba(255,200,110,0.12)'; ctx.beginPath(); ctx.arc(240, 150, 120, 0, Math.PI * 2); ctx.fill();
  },
  teaser(ctx, t) {
    sky(ctx, '#020408', '#0a1018');
    // 지리산 ridges
    ctx.fillStyle = '#0a0f14'; ctx.beginPath(); ctx.moveTo(0, 120); ctx.lineTo(70, 70); ctx.lineTo(150, 110); ctx.lineTo(230, 50); ctx.lineTo(320, 100); ctx.lineTo(400, 60); ctx.lineTo(480, 96); ctx.lineTo(480, 270); ctx.lineTo(0, 270); ctx.fill();
    ctx.fillStyle = '#060a0e'; ctx.beginPath(); ctx.moveTo(0, 170); ctx.lineTo(120, 140); ctx.lineTo(260, 170); ctx.lineTo(380, 136); ctx.lineTo(480, 160); ctx.lineTo(480, 270); ctx.lineTo(0, 270); ctx.fill();
    pineRow(ctx, 210, 31, '#04070a');
    // 도깨비불
    for (let i = 0; i < 9; i++) {
      const x = 40 + i * 50 + Math.sin(t * 1.3 + i) * 12, y = 150 + Math.sin(t * 2 + i * 2) * 18 + (i % 3) * 14;
      ctx.fillStyle = 'rgba(90,160,255,0.18)'; ctx.beginPath(); ctx.arc(x, y, 9, 0, Math.PI * 2); ctx.fill();
      ctx.fillStyle = '#9ad0ff'; ctx.fillRect(Math.round(x) - 2, Math.round(y) - 3, 4, 5);
    }
    // silhouette of a big horned figure with a club
    ctx.fillStyle = '#000';
    ctx.beginPath(); ctx.ellipse(380, 210, 28, 36, 0, 0, Math.PI * 2); ctx.fill();
    ctx.fillRect(366, 162, 6, 14); ctx.fillRect(388, 162, 6, 14);
    ctx.fillRect(404, 180, 30, 8); ctx.fillRect(428, 168, 12, 30);
    ctx.fillStyle = '#ffd040'; ctx.fillRect(370, 196, 4, 3); ctx.fillRect(386, 196, 4, 3);
  },
  end(ctx, t) {
    sky(ctx, '#05060c', '#0b0f20');
    stars(ctx, 77, 80, t);
    moon(ctx, 240, 70, 20);
    pineRow(ctx, 230, 41);
  },
};

// ------------------------------------------------------------ intro
export async function intro() {
  playMusic('title');
  await playCutscene([
    { draw: P.palaceSea, title: '동해 용궁', lines: [
      '신라의 동쪽 끝, 깊은 바다 밑에 용궁이 있었다.',
      '용왕에게는 아들이 일곱. 그 가운데 셋째는 유독 물 밖 인간 세상을 오래 바라보는 아이였다.',
      '그 아이의 이름은 처용(處容).',
    ] },
    { draw: P.dragonKing, title: '용왕의 유언', lines: [
      '용왕: "처용아. 요즘 들어 바다 위에서 올라오는 기운이 탁하다."',
      '용왕: "역병과 한(恨)이 뭉쳐 탁기(濁氣)가 되고, 탁기가 뭉쳐 요괴가 된다. 용궁과 저승과 인간 세상의 경계가 얇아지고 있다."',
      '용왕: "인간 세상의 액(厄)을 막는 것이 용의 오랜 사명이다. 이 용패를 가져가거라. 탁기를 읽을 것이다."',
      '용왕: "그리고 화염부와 수호부를 주마. 피리 소리에 실어 쓰거라."',
    ] },
    { draw: P.crossing, title: '개운포', lines: [
      '처용은 달 밝은 밤, 개운포 바위 곁으로 물을 가르고 올라왔다.',
      '헌강왕 시절의 일이라 전한다. 왕은 바다에서 온 이 젊은이에게 급간(級干) 벼슬을 내려 서라벌에 머물게 했다.',
      '처용은 서라벌의 여인 난영과 혼인하여, 낮에는 이름 없는 말단 관리로 살았다.',
    ] },
    { draw: P.seorabeol, title: '서라벌', lines: [
      '그러나 그해 가을, 서라벌 변두리에 역병이 돌기 시작했다.',
      '밤마다 녹빛 안개가 고분 사이를 기어 다니고, 사람들은 기침을 하다 쓰러졌다.',
      '처용은 피리를 쥐었다. 노래로, 춤으로 탁기를 걷어내는 것 — 그것이 용의 아들이 아는 유일한 싸움이었다.',
    ] },
    { draw: P.titleCard('처용가', '신 처용가 · 제1장'), lines: ['경주 변두리, 역병의 밤.'] },
  ], { skippable: true });
}

// ------------------------------------------------------------ NPC talk
const N = (n, t, p) => ({ n, t, p });

export async function talk(it, lvl) {
  const f = G.flags;
  if (it.kind === 'board') return board();
  if (it.kind === 'shop') return shop();
  if (it.kind === 'item') return item(it.obj, lvl);
  const npc = it.obj;
  switch (npc.id) {
    case 'elder': return elder();
    case 'merchant': return shop(true);
    case 'nanyeong': return nanyeong();
    case 'ghost': return ghost(npc, lvl);
    case 'villagerA':
      return say([N('마을 아낙', f.boss_result ? '안개가 걷혔어요! 아이들이 다시 마당에서 놀아요. 어사 나리… 아니, 급간 나리 덕분이지요.' : '밤마다 동쪽 산길에서 개 짖는 소리가 이상하게 들려요. 짖는 게 아니라… 기침하는 것 같기도 하고.', 'villager2')]);
    case 'villagerB':
      return say([N('나무꾼 돌쇠', f.boss_result ? '산길이 조용해졌습니다. 내일부턴 다시 나무를 하러 갈 수 있겠어요.' : '산길 끝 폐가는 역병으로 한 집안이 몰살한 곳입니다. 그 뒤로 귀신 아이 우는 소리가 난다고들 해요.', 'villager'),
        ...(f.boss_result ? [] : [N('나무꾼 돌쇠', '산길의 들개들은 불을 무서워합니다. 녹색 눈을 한 놈들은 특히요.', 'villager')])]);
    case 'villagerC':
      return say([N('기침하는 사내', f.boss_result ? '…숨이 쉬어집니다. 가슴을 짓누르던 것이 사라졌어요.' : '콜록… 콜록… 폐가 쪽에서 녹색 안개가 내려온 뒤로… 이렇게…', 'villagerSick')]);
  }
}

async function elder() {
  const f = G.flags;
  if (!f.q_main) {
    await say([
      N('촌주 박노인', '급간 나리, 오셨군요. 관아에서 공문이 내려왔습니다.', 'elder'),
      N('촌주 박노인', '"역병의 진원을 찾아 아뢰라." 하지만 관아 군사들은 모두 겁을 먹고 동쪽 산길에 들어가려 하지 않습니다.', 'elder'),
      N('처용', '진원이라 짐작되는 곳이 있습니까.', 'cheoyong'),
      N('촌주 박노인', '산길 끝의 폐가입니다. 지난봄 역병으로 한 집안이 몰살한 뒤로, 그곳에서 녹빛 안개가 흘러나옵니다.', 'elder'),
      N('촌주 박노인', '광장 게시판에 마을 사람들의 부탁도 붙어 있습니다. 약방 노점의 석구에게서 영약도 구하실 수 있고요.', 'elder'),
      N('촌주 박노인', '…나리. 부디 몸조심하십시오. 난영 아씨도 요즘 안색이 좋지 않던데.', 'elder'),
    ]);
    f.q_main = 1;
    toast('메인 의뢰: 역병의 진원 — 동쪽 산길 끝 폐가', C.goldL, 3.5);
    G.hooks.save();
    return;
  }
  if (f.boss_result) {
    return say([N('촌주 박노인', '안개가 걷혔습니다. 관아에서는 아무도 믿지 않겠지만… 이 마을 사람들은 압니다. 나리께서 무엇을 하셨는지.', 'elder')]);
  }
  return say([N('촌주 박노인', '폐가는 동쪽 산길 끝입니다. 역귀 졸개는 결박부에 약하고, 들개는 불을 싫어한다고 들었습니다.', 'elder'),
    N('촌주 박노인', '마을로 돌아오시면 집에서 쉬어 가십시오. 쉬면 기력이 돌아옵니다.', 'elder')]);
}

async function nanyeong() {
  const f = G.flags;
  if (f.boss_result) {
    await say([
      N('난영', '꿈을 꿨어요. 어두운 방에서… 누군가 노래를 불러 주는 꿈.', 'nanyeong'),
      N('난영', '그 노래가 들리자 무섭던 것이 다 물러갔어요. …당신 목소리였지요?', 'nanyeong'),
    ]);
  } else if (f.entered_dungeon) {
    await say([
      N('난영', '…(열에 들떠 얕은 숨을 쉬고 있다. 이마가 뜨겁다.)', 'nanyeong'),
      N('처용', '(넋이 반쯤 빠져나간 기색이다. 폐가 쪽에서 탁기가 그녀를 끌어당기고 있다.)', 'cheoyong'),
    ]);
  } else if (!f.talked_nanyeong) {
    f.talked_nanyeong = 1;
    await say([
      N('난영', '오늘도 늦으시네요. 마을 어귀까지 안개가 내려왔다고들 해요.', 'nanyeong'),
      N('난영', '요즘 밤마다 이상한 꿈을 꿔요. 누가 제 이름을 부르면서 동쪽으로 오라고… 콜록.', 'nanyeong'),
      N('처용', '(용패가 희미하게 녹빛으로 떨린다. 그녀의 기침 속에 탁기가 섞여 있다.)', 'cheoyong'),
      N('난영', '지치면 언제든 집에 와서 쉬세요. 따뜻한 차를 끓여 둘게요.', 'nanyeong'),
    ]);
  }
  const r = await choose('집에서 쉬어 갈까? (기력·소리 회복, 기록 저장)', ['쉬어 간다', '그냥 둔다']);
  if (r === 0) await rest();
}

export async function rest() {
  G.fadeTarget = 1; await wait(0.5);
  G.stats.hp = G.stats.maxHp;
  if (G.player) { G.player.sori = 100; }
  G.checkpoint = 'village';
  G.hooks.save();
  await wait(0.4);
  G.fadeTarget = 0;
  sfx('bell');
  toast('기력을 회복했다 · 기록 저장됨', '#9fe8a0', 2.5);
}

async function board() {
  const f = G.flags;
  for (;;) {
    const opts = [
      { label: '[관아 공문] 역병의 진원을 찾으라', right: f.boss_result ? '완료' : f.q_main ? '수행 중' : '' },
      { label: '[퇴마] 산길의 역귀 졸개', right: ['', '수행 중', '보고 가능', '완료'][f.q_imp || 0] },
      { label: '[한풀이] 우는 아이의 넋', right: ['', '수행 중', '수행 중', '완료'][f.q_ghost || 0] },
      { label: '닫기' },
    ];
    const r = await choose(null, opts, { title: '의뢰 게시판' });
    if (r === 0) {
      await say(['관아 공문: "경주 변두리에 번지는 역병의 진원을 찾아 아뢰라. 동쪽 산길 끝 폐가가 의심된다." — 붉은 관인이 찍혀 있다.']);
    } else if (r === 1) {
      if (!f.q_imp) {
        await say(['"산길에 역귀 졸개들이 들끓어 나무하러 갈 수가 없습니다. 네 놈만 쫓아 주시면 사례하겠습니다. — 나무꾼들"',
          '(역귀 졸개는 녹색 침을 뱉는 작은 요괴다. 결박부에 약하다.)']);
        const a = await choose('의뢰를 받을까?', ['받는다', '나중에']);
        if (a === 0) { f.q_imp = 1; f.q_imp_count = 0; toast('퇴마 의뢰 수락: 역귀 졸개 0/4', C.goldL, 3); }
      } else if (f.q_imp === 1) {
        await say([`(역귀 졸개를 ${f.q_imp_count || 0}/4 마리 물리쳤다. 산길에 아직 남아 있다.)`]);
      } else if (f.q_imp === 2) {
        f.q_imp = 3;
        G.stats.money += 120; G.items.jeonghwa += 1;
        const lv = addExp(100);
        sfx('coin');
        await say(['나무꾼들이 엽전 꾸러미를 맡겨 두었다. "고맙습니다, 나리!"', '보상: 엽전 120냥 · 정화부 1장 · 덕망 100']);
        if (lv) { sfx('levelup'); toast(`신통력 상승! Lv.${G.stats.lv}`, C.goldL, 3); }
      } else await say(['(이미 끝낸 의뢰다.)']);
    } else if (r === 2) {
      if (!f.q_ghost) {
        await say(['서툰 글씨: "폐가에서 밤마다 아이 울음소리가 납니다. 지난봄 역병으로 죽은 보리라는 아이입니다. 부디 달래 주세요. — 보리의 이웃"',
          '(원혼은 베는 것이 아니라 한을 풀어 주어야 한다.)']);
        const a = await choose('의뢰를 받을까?', ['받는다', '나중에']);
        if (a === 0) { f.q_ghost = 1; f.q_ghost_accepted = 1; toast('한풀이 의뢰 수락: 폐가 1층의 우는 아이', C.goldL, 3); }
      } else if (f.q_ghost < 3) {
        await say([f.q_ghost === 2 ? '(토우를 찾았다. 폐가 1층의 아이에게 돌려주자.)' : f.met_ghost ? '(보리가 잃어버린 토우를 산길 봉분 근처에서 찾아야 한다.)' : '(폐가 1층에서 우는 아이를 찾아야 한다.)']);
      } else await say(['(보리의 넋은 편히 떠났다.)']);
    } else return;
  }
}

async function shop(fromNpc) {
  if (fromNpc) await say([N('석구', '어서 오십시오, 나리. 역병 통에 약재가 귀하지만, 나리께는 제값만 받습니다.', 'merchant')]);
  for (;;) {
    const opts = BAL.shop.map((s) => ({ label: `${s.name}  (보유 ${G.items[s.id]})`, right: `${s.price}냥`, desc: s.desc, disabled: G.stats.money < s.price }));
    opts.push({ label: '그만 둔다' });
    const r = await choose(`소지금 ${G.stats.money}냥`, opts, { title: '약방 노점' });
    if (r < 0 || r >= BAL.shop.length) return;
    const s = BAL.shop[r];
    if (G.stats.money >= s.price) {
      G.stats.money -= s.price; G.items[s.id]++;
      sfx('coin');
      toast(`${s.name}을(를) 샀다`, '#d8c89a', 1.5);
    }
  }
}

async function item(it, lvl) {
  const f = G.flags;
  if (it.kind === 'chest') {
    if (f['opened_' + it.id]) return say(['(빈 궤다.)']);
    f['opened_' + it.id] = 1;
    sfx('door');
    if (!G.tal.unlocked.includes('bind')) G.tal.unlocked.splice(1, 0, 'bind');
    G.tal.idx = 1;
    lvl.fx.push(new Ring(it.x, it.y - 8, 4, 40, 0.6, '#6aa8ff', 2));
    await say([
      '낡은 나무 궤 안에, 퇴마사가 남긴 듯한 부적 묶음이 있다.',
      '「결박부」를 얻었다! — 땅에 결계를 쳐서 안의 요괴를 느리게 하고 서서히 정화한다. (소리 30)',
      'X로 부적을 바꾸고 C로 발동한다. 역귀 졸개, 그리고 역신 같은 역병의 요괴는 결박에 약하다.',
    ]);
    G.hooks.save();
    return;
  }
  if (it.id === 'doll') {
    it.taken = true;
    f.q_ghost_doll = 1; f.q_ghost = 2;
    sfx('bell');
    await say(['봉분 아래 풀숲에 작은 흙 인형이 떨어져 있다. 신라의 토우 — 두 팔을 벌린 아이 모양이다.', '「보리의 토우」를 얻었다.']);
  }
}

async function ghost(npc, lvl) {
  const f = G.flags;
  if (!f.q_ghost) {
    return say([N('아이 원혼', '흑… 흑… (아이가 등을 돌린 채 울고 있다. 다가가자 차가운 바람이 분다.)', 'ghostChild'),
      N('처용', '(이 아이의 사연을 아는 사람이 마을에 있을지도 모른다. 게시판을 살펴보자.)', 'cheoyong')]);
  }
  if (f.q_ghost === 1) {
    f.met_ghost = 1;
    return say([
      N('보리', '…아저씨, 내 인형 못 봤어? 엄마가 구워 준 흙 인형.', 'ghostChild'),
      N('보리', '아프기 전에 산길 무덤가에서 놀다가 잃어버렸어. 그거 없으면 무서워서… 못 가.', 'ghostChild'),
      N('처용', '(산길 중간, 고분이 모인 빈터를 찾아보자.)', 'cheoyong'),
    ]);
  }
  if (f.q_ghost === 2) {
    await say([N('보리', '…! 그거, 내 인형!', 'ghostChild')]);
    const r = await choose('토우를 돌려주고 해원(解冤)의 가락을 불어 줄까?', ['토우를 돌려주고 피리를 분다', '조금 뒤에']);
    if (r !== 0) return;
    sfx('song');
    await wait(0.6);
    await say([
      N('보리', '따뜻해… 엄마 냄새가 나.', 'ghostChild'),
      N('처용', '이제 무섭지 않을 게다. 가거라. 기다리는 사람들이 있는 곳으로.', 'cheoyong'),
      N('보리', '고마워, 피리 아저씨. 저 위층에… 무서운 아저씨가 있어. 사람 얼굴을 하고 있는데, 사람이 아니야. 조심해.', 'ghostChild'),
    ]);
    obangRipple(lvl, npc.x, npc.y - 10);
    sfx('purify');
    npc.hidden = true;
    f.q_ghost = 3;
    G.stats.money += 60; G.items.insam += 2;
    const lv = addExp(150);
    await say(['보리의 넋이 오방색 빛 속으로 흩어졌다. 그 자리에 엽전 꾸러미와 약첩이 남아 있다.', '보상: 엽전 60냥 · 인삼정기탕 2개 · 덕망 150']);
    if (lv) { sfx('levelup'); toast(`신통력 상승! Lv.${G.stats.lv}`, C.goldL, 3); }
    G.hooks.save();
  }
}

// ------------------------------------------------------------ first field tutorial
export async function fieldTutorial() {
  if (G.flags.tut_field) return;
  G.flags.tut_field = 1;
  await say([
    N('처용', '(탁기가 짙다. 용패가 녹빛으로 떤다.)', 'cheoyong'),
    '조작 — 이동: 방향키/WASD · 피리 베기: Z (연타 3단 콤보, 길게 눌렀다 떼면 강 베기)',
    '춤 구르기: Shift/Space (잠깐 무적) — 적의 공격 직전에 구르면 「받아넘기기」: 시간이 느려지고 다음 베기 200%.',
    '부적: X 전환 / C 발동 (소리 소모) · V 처용가: 교전마다 1회, 10초간 공격력 +30% · F 처용무: 신명이 가득 차면.',
    '요괴는 HP와 별도로 「정화」 게이지(노란 줄)가 있다. 정화를 먼저 채우면 한풀이 — 덕망 1.5배. 약점 부적이 정화를 두 배로 채운다.',
  ]);
}

// ------------------------------------------------------------ boss sequence
export async function bossIntro(lvl) {
  const f = G.flags;
  G.scriptLock++;
  const p = lvl.player;
  const spirit = lvl.npcs.find((n) => n.id === 'nanyeongSpirit');
  spirit.hidden = false;
  const boss = new Boss(41 * TS, 12 * TS + 8);
  lvl.boss = boss;
  boss.state = 'human';
  playMusic(null);
  await wait(0.6);
  await say([
    N('처용', '(넓은 방 한가운데, 희미하게 빛나는 난영의 넋이 잠들어 있다. 그 곁에 한 사내가 앉아 그녀의 머리칼을 쓰다듬고 있다.)', 'cheoyong'),
    N('낯선 사내', '…왔구나, 용의 아들. 이 여인의 꿈길은 참 따뜻하더구나. 열에 들뜬 꿈일수록 들어가기 쉽지.', 'yeoksinHuman'),
    N('낯선 사내', '화가 나느냐? 칼을 뽑아라. 분노도 한도 내게는 다 먹이가 된다.', 'yeoksinHuman'),
    N('처용', '(용패가 뜨겁게 떤다. 분노가 치밀지만 — 처용은 피리를 입에 대었다.)', 'cheoyong'),
  ]);
  sfx('song');
  await playCutscene([{ draw: (ctx, t) => {
    ctx.fillStyle = '#05060c'; ctx.fillRect(0, 0, VIEW_W, VIEW_H);
    moon(ctx, 240, 70, 22);
    ctx.fillStyle = 'rgba(224,192,112,0.08)'; ctx.beginPath(); ctx.arc(240, 150, 80 + Math.sin(t * 2) * 6, 0, Math.PI * 2); ctx.fill();
    big(ctx, SPR.player.up[0], 240, 220, 4);
    const r = rng(4);
    for (let i = 0; i < 14; i++) { const x = (r() * VIEW_W + t * 20) % VIEW_W, y = 180 - ((t * 25 + r() * 160) % 160); ctx.fillStyle = C.goldL; ctx.fillRect(Math.round(x), Math.round(y), 2, 2); }
  }, title: '처용가', lines: [
    '서라벌 밝은 달 아래 / 밤 깊도록 노닐다가',
    '들어와 자리를 보니 / 다리가 넷이로구나',
    '둘은 내 것이었고 / 둘은 누구의 것인고',
    '본디 내 사람이건만 / 빼앗긴 것을 어찌하리오',
    '— 그러나 처용은 노여워하지 않았다. 노래는 칼보다 멀리 닿는다.',
  ] }]);
  await say([
    N('낯선 사내', '…노래? 노래라고? 크, 크하하하!', 'yeoksinHuman'),
    N('낯선 사내', '좋다. 그 노래가 얼마나 버티는지 보자. 이 땅의 역병이 모두 내 몸이다!', 'yeoksinHuman'),
  ]);
  // transformation
  boss.state = 'intro';
  sfx('boss');
  G.shake = 6;
  obangRipple(lvl, boss.x, boss.y - 20);
  spirit.hidden = true;
  await wait(1.0);
  // close the door behind the player
  const bd = lvl.def.bossDoor;
  for (let y = bd.y0; y <= bd.y1; y++) for (let x = bd.x0; x <= bd.x1; x++) { lvl.tiles[y * lvl.w + x] = T.WALL; lvl.setBlock(x, y, 1); }
  lvl.buildGround();
  if (p.x < 32 * TS + 8) p.x = 33 * TS;
  sfx('door');
  G.banner = { text: '역신(疫神)', sub: '역병의 화신', t: 3 };
  await wait(1.2);
  boss.state = 'idle'; boss.stateT = 0;
  f.boss_fight = 1;
  G.encounter.active = true; G.encounter.songUsed = false; G.encounter.calm = 0;
  playMusic('boss');
  G.scriptLock--;
  toast('결박부로 발을 묶고, 피리 베기로 안개를 걷어내라', '#c8e8b0', 4);
}

export async function bossDefeated(lvl, how) {
  const f = G.flags;
  G.scriptLock++;
  f.boss_fight = 0;
  playMusic(null);
  const boss = lvl.boss;
  G.slowT = 1.5;
  sfx(how === 'purified' ? 'purify' : 'kill');
  obangRipple(lvl, boss.x, boss.y - 20);
  await wait(1.6);
  if (how === 'purified') {
    await say([
      N('역신', '…이 소리. 이토록 맑은 소리는… 처음이구나.', 'yeoksin'),
      N('역신', '나는 역병으로 죽어 간 이들의 신음이 뭉친 것. 아무도 그 한을 들어 주지 않았기에… 나는 더 많은 신음을 원했다.', 'yeoksin'),
      N('처용', '들었다. 이제 가거라.', 'cheoyong'),
      N('역신', '(역신이 무릎을 꿇는다.) …맹세하마, 용의 아들. 네 얼굴을 그려 붙인 문 안으로는, 다시는 발을 들이지 않겠다.', 'yeoksin'),
    ]);
  } else {
    await say([
      N('역신', '크… 베어낸다고… 역병이 사라질 것 같으냐…', 'yeoksin'),
      N('처용', '사라지지 않겠지. 그래서 나는 몇 번이고 올 것이다.', 'cheoyong'),
      N('역신', '…좋다. 네 얼굴이 그려진 문에는 들지 않으마. 허나 기억해라. 우리의 왕께서 깨어나시는 날… 경계는 무너진다…', 'yeoksin'),
    ]);
  }
  boss.vanishedForEnding = true;
  for (let i = 0; i < 30; i++) lvl.fx.push(new Ring(boss.x, boss.y - 20, 2, 30 + i * 2, 0.5 + i * 0.03, 'rgba(182,255,106,0.4)', 1));
  await wait(0.8);
  const spirit = lvl.npcs.find((n) => n.id === 'nanyeongSpirit');
  spirit.hidden = false;
  sfx('bell');
  await say([
    N('난영', '…여보? 노랫소리가… 들렸어요.', 'nanyeongSpirit'),
    N('처용', '집으로 가자. 당신의 몸이 기다린다.', 'cheoyong'),
  ]);
  spirit.hidden = true;
  obangRipple(lvl, spirit.x, spirit.y - 10);
  await wait(1);
  addExp(how === 'purified' ? 450 : 300);
  f.cleared = 1;
  G.fadeTarget = 1;
  await wait(1.2);
  await ending(how);
  G.scriptLock--;
}

async function ending(how) {
  playMusic('title');
  G.fade = 0; G.fadeTarget = 0;
  await playCutscene([
    { draw: P.seorabeol, title: '그날 밤 이후', lines: [
      '그날 밤, 서라벌 변두리의 녹빛 안개가 걷혔다.',
      '난영은 아침에 눈을 떴고, 기침하던 사람들은 다시 숨을 쉬었다.',
      how === 'purified' ? '역신은 처단되지 않고 정화되었다. 사람들은 그것을 몰랐지만, 고분 사이를 맴돌던 신음 소리는 다시 들리지 않았다.'
        : '역신은 베어졌다. 그러나 처용은 알았다. 베어낸 것은 역신의 몸일 뿐, 그를 낳은 한은 아직 이 땅 어딘가에 남아 있다는 것을.',
    ] },
    { draw: P.palace, title: '월성, 한밤', lines: [
      '며칠 뒤 한밤중, 처용은 비밀리에 궁으로 불려 갔다.',
      '왕: "폐가의 일은 들었다. 관아의 군사도 들어가지 못한 곳에, 피리 하나 들고 들어갔다지."',
      '왕: "역병과 요괴가 서라벌만의 일이 아니다. 낮에는 급간으로, 밤에는 짐의 눈과 귀가 되어 다오."',
      '왕: "오늘부터 그대를 퇴마어사(退魔御史)로 삼는다. 이 일은 짐과 그대만이 안다."',
    ] },
    { draw: P.titleCard('퇴마어사 임명', '처용, 밤의 어사가 되다'), lines: ['처용은 낮에는 이름 없는 관리로, 밤에는 탈을 쓴 어사로 신라 땅을 걷게 된다.'] },
    { draw: P.mask, title: '처용의 얼굴', lines: [
      '서라벌 사람들은 그 뒤로, 대문에 처용의 얼굴을 그려 붙였다.',
      '역신이 맹세한 대로 — 그 얼굴이 걸린 집에는 역병이 들지 않았다고 한다.',
    ] },
    { draw: P.teaser, title: '다음 이야기', lines: [
      '지리산 자락의 마을에서 도깨비들이 곳간을 털어 간다는 소문이 들려온다.',
      '그러나 용패가 읽어 낸 기운은 장난이 아니었다. 도깨비들의 방망이에도, 녹빛 탁기가 스며 있었다.',
    ] },
    { draw: P.titleCard('도깨비골', '신 처용가 · 제2장 예고'), lines: ['제1장 「처용가」 — 완(完). 플레이해 주셔서 고맙습니다.'] },
  ]);
  G.hooks.finish();
}
