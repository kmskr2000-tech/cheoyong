// Story: quest stages, NPC dialogue, triggers, spawns and boss events. Progress lives in G.game.flags.
'use strict';
(() => {
  const T = G.TILE;
  const at = (tx, ty) => ({ x: tx * T, y: ty * T });
  const VERSES = ['서라벌 밝은 달에', '밤 늦도록 노닐다가', '들어와 자리를 보니', '다리가 넷이로구나',
    '둘은 내 것이었고', '둘은 누구의 것인가', '본디 내 것이다마는', '빼앗긴 것을 어찌하리'];
  G.VERSES = VERSES;

  // NPCs: id, sprite, tile pos, name, facing, visibility condition
  const NPCS = [
    ['yongwang', 'yongwang', 106.5, 70.5, '용왕', 'west'],
    ['hwarang', 'hwarang', 66, 68.6, '화랑', 'south'],
    ['halmi', 'halmi', 52.5, 53, '할미', 'east'],
    ['merchant', 'merchant', 55, 47.6, '상인', 'south'],
    ['dosa', 'dosa', 74, 46.6, '도사', 'west'],
    ['child', 'child', 63, 57, '아이', 'south'],
    ['dog', 'dog', 64.5, 57.8, '누렁이', 'west'],
    ['sick', 'sick', 48.8, 46, '앓는 사람', 'south'],
    ['wife', 'wife', 58, 42, '아내', 'south', (f) => f.king_met && !f.house_open],
    ['king', 'king', 61, 43.2, '왕', 'south', (f) => f.king_event && !f.king_left],
    ['monk', 'monk', 70, 16.5, '스님', 'west'],
    ['sansin', 'sansin', 36.5, 54.5, '산신령', 'south'],
    ['villager', 'villager', 71, 55, '아낙', 'west'],
    ['wife_home', 'wife', 23, 24.5, '아내', 'south', (f) => !!f.yeoksin_done],
  ];

  // enemy spawn points per zone: [type, tx, ty]
  const SPAWNS = {
    beach: { lvl: 1, list: [['imp', 96, 62], ['imp', 90, 66], ['snake', 86, 74], ['imp', 100, 76], ['snake', 92, 80], ['imp', 84, 62], ['snake', 104, 64], ['imp', 88, 84]] },
    ruin: { lvl: 2, list: [['imp', 92, 18], ['dokkaebi', 96, 26], ['dokkaebi', 106, 18], ['imp', 110, 26], ['dokkaebi', 90, 32], ['dokkaebi', 112, 12], ['imp', 98, 12], ['dokkaebi', 104, 32]] },
    forest: { lvl: 3, list: [['imp', 30, 50], ['ghoul', 24, 56], ['ghoul', 14, 52], ['imp', 10, 64], ['ghoul', 28, 72], ['imp', 12, 80], ['ghoul', 30, 82], ['imp', 20, 60]] },
    pond: { lvl: 3, list: [['snake', 46, 20], ['snake', 72, 22], ['ghoul', 50, 24], ['snake', 44, 10], ['ghoul', 76, 18], ['snake', 66, 24], ['ghoul', 54, 8], ['snake', 78, 8]] },
    house: { lvl: 4, list: [['ghost', 12, 12], ['ghost', 30, 14], ['ghost', 12, 26], ['ghost', 30, 26]] },
  };

  const BOSSES = {
    ruin: { type: 'dokchief', flag: 'boss_dok', at: [101, 27], need: 'kills_ruin', trigger: [101, 25] },
    forest: { type: 'gumiho', flag: 'boss_fox', at: [18, 75], need: 'kills_forest', trigger: [18, 72] },
    pond: { type: 'imugi', flag: 'boss_imugi', at: [59, 19.5], need: 'kills_pond', trigger: [59, 22] },
  };

  const S = {
    VERSES, NPCS, SPAWNS, BOSSES,
    // ---------- objectives (shown on the HUD with a guide arrow) ----------
    objective(f) {
      if (!f.q1) return { text: '용왕에게 말을 걸어 보시오', target: at(106.5, 70.5) };
      if (!f.q2) {
        if ((f.kills_beach || 0) < 6) return { text: `개운포의 요괴 정화 (${f.kills_beach || 0}/6)`, target: null };
        return { text: '용왕에게 돌아가시오', target: at(106.5, 70.5) };
      }
      if (!f.king_met) return { text: '남문을 지나 서라벌 광장으로', target: at(61, 50) };
      if (!f.q3) return { text: '저잣거리의 할미를 찾으시오', target: at(52.5, 53) };
      if (!f.q4) {
        const parts = [];
        if (!f.boss_dok) parts.push(f.kills_ruin >= 6 ? '우물터: 우두머리' : `우물터 ${f.kills_ruin || 0}/6`);
        if (!f.boss_fox) parts.push(f.kills_forest >= 6 ? '여우숲: 우두머리' : `여우숲 ${f.kills_forest || 0}/6`);
        if (!f.boss_imugi) parts.push(f.kills_pond >= 6 ? '연못: 우두머리' : `연못 ${f.kills_pond || 0}/6`);
        if (!f.dosa_done) parts.push(f.kills_total >= 12 ? '도사에게' : `도사 ${f.kills_total || 0}/12`);
        let target = null;
        if (!f.boss_dok && f.kills_ruin >= 6) target = at(...BOSSES.ruin.trigger);
        else if (!f.boss_fox && f.kills_forest >= 6) target = at(...BOSSES.forest.trigger);
        else if (!f.boss_imugi && f.kills_pond >= 6) target = at(...BOSSES.pond.trigger);
        else if (!f.dosa_done && f.kills_total >= 12) target = at(74, 46.6);
        if (f.boss_dok && f.boss_fox && f.boss_imugi) return { text: '할미에게 돌아가시오', target: at(52.5, 53) };
        return { text: '흩어진 구절 — ' + parts.join(' · '), target };
      }
      if (!f.q5) return { text: '할미에게 돌아가시오', target: at(52.5, 53) };
      if (!f.yeoksin_done) return { text: '처용의 집으로', target: at(20, 24) };
      return { text: '노래가 완성되었다', target: null };
    },

    // ---------- interaction ----------
    interact(npc) {
      const g = G.game, f = g.flags, p = g.player, say = G.ui.say;
      const id = npc.id;
      if (id === 'yongwang') {
        if (!f.q1) {
          say([
            ['용왕', '깨었느냐, 아들아. 개운포에 탁한 기운이 차올랐구나.'],
            ['용왕', '이 탈을 받아라. 처용탈이다. 탈을 쓰면 요괴의 탁기가 보이고, 노래가 힘이 된다.'],
            ['@', '처용탈을 얻었다.', () => { p.masks.push('cheoyong'); p.mask = 'cheoyong'; G.audio.sfx('item'); }],
            ['용왕', '잊지 마라. 우리는 죽이지 않는다. 쓰러뜨리고, 노래로 탁기를 걷어 낸다.'],
            ['용왕', '첫 구절을 주마. 귀 기울이거라.'],
            ['@verse', 1],
            ['용왕', '모래톱의 요괴 여섯을 정화하고 돌아오너라. 소매를 휘두르면 된다.'],
            ['처용', '다녀오겠소.'],
          ], () => { f.q1 = true; f.has_attack = true; G.game.tutorial('attack'); g.save(); });
        } else if (!f.q2 && (f.kills_beach || 0) >= 6) {
          say([
            ['용왕', '잘했다. 쓰러진 것들이 편히 바다로 돌아갔구나.'],
            ['용왕', '소매에 소리를 실어 보내는 법을 가르쳐 주마. 소리결이다.'],
            ['@', '스킬 「소리결」을 익혔다. (기 12)', () => { p.skills.skill1 = true; G.audio.sfx('quest'); }],
            ['용왕', '싸우며 흥이 차오르면 처용가를 부를 수 있다. 모은 구절이 많을수록 노래는 강해진다.'],
            ['@', '흥이 가득 차면 「처용가」를 부를 수 있다.', () => { f.has_ult = true; }],
            ['용왕', '이제 서라벌로 가거라. 남문의 화랑에게 내 이름을 대면 된다.'],
            ['용왕', '그리고… 서두르거라. 왕이… 오신다.'],
            ['처용', '…왕이?'],
          ], () => { f.q2 = true; f.gate_open = true; G.game.tutorial('skill1'); g.save(); });
        } else if (!f.q2) {
          say([['용왕', `모래톱의 요괴가 아직 남았다. (${f.kills_beach || 0}/6)`]]);
        } else {
          say([['용왕', f.q5 ? '노래가 거의 다 모였구나. 네 집으로 가거라.' : '서라벌의 밤이 깊다. 노래를 모으거라, 아들아.']]);
        }
      } else if (id === 'hwarang') {
        if (!f.gate_open) say([['화랑', '멈추시오! 남문 밖에 요괴가 날뛰어 문을 닫았소.'], ['화랑', '개운포가 잠잠해지기 전엔 열 수 없소.']]);
        else say([['화랑', '용왕님의 아드님이시라고요? 어서 드시오. 서라벌이 그대를 기다렸소.']]);
      } else if (id === 'halmi') {
        if (!f.king_met) say([['할미', '에구, 손님이시구려. 광장에 귀한 분이 오신다던데.']]);
        else if (!f.q3) {
          say([
            ['할미', '에구, 용왕님 아드님이시구려. 잘 오셨소.'],
            ['할미', '역신이 깨어났소. 사람 몸에 스며 병을 퍼뜨리는 귀신이지.'],
            ['할미', '그 놈을 굴복시킬 노래가 있었는데, 여덟 구절이 흩어져 버렸다오.'],
            ['할미', '우물터, 여우숲, 연못 절터… 탁기가 짙은 곳마다 구절이 붙들려 있을 게요.'],
            ['할미', '정자의 도사도 찾아가 보시오. 춤을 가르쳐 줄 게요.'],
            ['처용', '모으겠소.'],
            ['@', '서라벌을 둘러싼 탁기가 걷혔다.', () => { G.audio.sfx('quest'); }],
          ], () => { f.q3 = true; f.paths_open = true; g.save(); G.game.dissolveGates(); });
        } else if (!f.q4 && f.boss_dok && f.boss_fox && f.boss_imugi) {
          say([
            ['할미', '세 우두머리를 모두 무릎 꿇리셨구려! 장하오.'],
            ['할미', '여섯째 구절은 이 늙은이가 지켜 왔소.'],
            ['@verse', 6],
            ['할미', '그런데… 역신이 처용 님 집에 들었다는 소문이오. 아씨가 위험하오!'],
            ['처용', '…가겠소.'],
          ], () => { f.q4 = true; f.q5 = true; f.house_open = true; g.save(); G.game.dissolveGates(); });
        } else if (f.q5 && !f.yeoksin_done) {
          say([['할미', '어서 집으로 가시오! 북서쪽 담장 너머요.']]);
        } else {
          say([['할미', f.yeoksin_done ? '노래가 다 모였구려. 이제 서라벌의 밤도 편하겠소.' : '우물터는 동북, 여우숲은 서, 연못 절터는 북쪽이오.']]);
        }
      } else if (id === 'merchant') {
        say([['상인', '어서 오시오! 약과 한 상자, 식혜 한 사발, 싸게 드리리다.']], () => G.ui.openShop());
      } else if (id === 'dosa') {
        if (!f.q3) say([['도사', '허허, 바람이 탁하구먼.']]);
        else if (f.dosa_done) say([['도사', '돌고, 또 돌게. 춤은 몸으로 부르는 노래일세.']]);
        else if ((f.kills_total || 0) < 12) say([['도사', `요괴 열둘을 정화하고 오시게. (${f.kills_total || 0}/12)`], ['도사', '그대 춤에 무엇이 모자란지 그때 보이겠지.']]);
        else say([
          ['도사', '됐네. 발을 이렇게… 돌고, 또 돌게.'],
          ['@', '스킬 「탈춤 회오리」를 익혔다. (기 18)', () => { p.skills.skill2 = true; G.audio.sfx('quest'); }],
          ['도사', '그리고 이건 내가 바람에서 주운 구절일세.'],
          ['@verse', 3],
        ], () => { f.dosa_done = true; G.game.tutorial('skill2'); g.save(); });
      } else if (id === 'child') {
        say([['아이', f.yeoksin_done ? '처용 아저씨 얼굴 그려서 문에 붙였어요!' : '처용 아저씨! 밤에 문 앞에 탈 그림 붙이면 귀신이 못 들어온대요!']]);
      } else if (id === 'dog') {
        say([['누렁이', '멍! 멍!']]);
      } else if (id === 'sick') {
        say([['앓는 사람', '콜록… 밤마다 꿈에 누가 내 자리 옆에 눕소…'], ['앓는 사람', '다리가… 넷이 보였소. 콜록.']]);
      } else if (id === 'wife') {
        say([['아내', f.q3 ? '밤이 깊었소. 노래를 다 모으면 집으로 오시오. 기다리겠소.' : '처용 님. 서라벌은 낯설지요? 천천히 둘러보시오.']]);
      } else if (id === 'king') {
        say([['왕', '서라벌을 부탁하오, 처용.']]);
      } else if (id === 'monk') {
        if (f.boss_imugi) say([['스님', '이무기가 편히 잠들었소. 나무아미타불.']]);
        else say([['스님', '연못 바닥에 이무기가 잠들어 있소. 용이 되지 못한 원한이 탁기를 부르오.'], ['스님', '연못가 요괴를 먼저 걷어 내시오. 그러면 놈이 올라올 게요.']]);
      } else if (id === 'sansin') {
        if (f.boss_fox) say([['산신령', '숲이 다시 숨을 쉬는구먼. 고맙소.']]);
        else say([['산신령', '여우숲의 구미호가 사람 넋을 홀리고 있소.'], ['산신령', '숲의 요괴를 여섯 정화하면 놈이 숲 안쪽 제단에 나타날 게요.']]);
      } else if (id === 'villager') {
        say([['아낙', '저잣거리 상인한테 약과 사 두시오. 밤길엔 그게 약이라오.']]);
      } else if (id === 'wife_home') {
        say([['아내', '처용 님… 노랫소리가 들렸소.'], ['처용', '돌아왔소.']], () => G.game.startEnding());
      }
    },

    // ---------- zone enter / trigger checks, run every frame ----------
    update(dt) {
      const g = G.game, f = g.flags, p = g.player;
      if (g.frozen || g.boss) return;
      // King event when first entering the plaza after the gate opens
      if (f.q2 && !f.king_event && G.dist(p.x, p.y, 61 * T, 50 * T) < 260) this.kingEvent();
      // boss triggers
      for (const [zone, b] of Object.entries(BOSSES)) {
        if (f[b.flag] || (f[b.need] || 0) < 6) continue;
        if (G.dist(p.x, p.y, b.trigger[0] * T, b.trigger[1] * T) < 220) this.bossIntro(zone);
      }
      if (f.house_open && !f.yeoksin_done && !f.yeoksin_started && p.y < 30 * T && p.x < 32 * T && p.y > 6 * T) this.yeoksinIntro();
    },

    kingEvent() {
      const g = G.game, f = g.flags;
      f.king_event = true;
      const king = g.npc('king'), wife = g.npc('wife');
      g.cutscene(async (c) => {
        await c.pan(61 * T, 46 * T, 1.2);
        G.audio.sfx('door');
        await c.say([
          ['왕', '그대가 동해 용왕의 아들이오? 개운포의 탁기를 걷어 주었다 들었소.'],
          ['왕', '서라벌에 머물러 나를 도와주시오. 급간 벼슬을 내리고, 어진 아내도 맞게 하겠소.'],
        ]);
        f.king_met = true; g.refreshNpcs();
        await c.say([
          ['아내', '…처용 님이시군요. 앞으로 잘 부탁드리오.'],
          ['처용', '고맙소.'],
          ['왕', '허나 요즘 밤마다 역병이 돈다오. 저잣거리 할미가 무언가 안다 하니 들어 보시오.'],
        ]);
        await c.pan(null, null, 0.8);
      }, () => { g.save(); });
    },

    bossIntro(zone) {
      const g = G.game, f = g.flags, b = BOSSES[zone];
      const pos = at(...b.at);
      const lines = {
        ruin: [['도깨비 대장', '흐하하! 누가 내 우물터를 어지럽히느냐!'], ['도깨비 대장', '내 방망이 맛 좀 봐라!']],
        forest: [['구미호', '곱게 생긴 사내로구나…'], ['구미호', '네 넋도 내 꼬리 하나가 되리라.']],
        pond: [['이무기', '용이 되지 못한 나를… 용왕의 아들이 비웃으러 왔느냐!']],
      }[zone];
      g.cutscene(async (c) => {
        const boss = g.spawnBoss(b.type, pos.x, pos.y, zone);
        boss.spawnT = 1.2;
        G.audio.sfx('roar'); G.fx.screenShake(10);
        await c.pan(pos.x, pos.y - 40, 1.0);
        await c.wait(0.6);
        await c.say(lines);
        await c.pan(null, null, 0.6);
        g.startBossFight(boss, pos.x, pos.y + 40);
      });
    },

    bossDefeated(boss) {
      const g = G.game, f = g.flags, p = g.player;
      const zone = boss.zone;
      const done = () => { g.endBossFight(); g.save(); };
      if (boss.type === 'dokchief') {
        f.boss_dok = true;
        g.cutsceneSay([
          ['도깨비 대장', '끄응… 졌소, 졌어. 그 노래 참 고약하게 좋구먼.'],
          ['도깨비 대장', '이 구절은 돌려주리다.'],
          ['@verse', 2],
          ['도깨비 대장', '내 탈도 가져가시오. 무섭게 생겼지만 힘은 세다오.'],
          ['@', '귀면탈을 얻었다. (공격 +35%, 받는 피해 +15%)', () => { p.masks.push('gwimyeon'); G.audio.sfx('item'); }],
        ], () => { done(); G.game.tutorial('mask'); });
      } else if (boss.type === 'gumiho') {
        f.boss_fox = true;
        g.cutsceneSay([
          ['구미호', '아아… 노랫소리가 따뜻하구나. 홀린 넋들을 놓아주마.'],
          ['@verse', 4],
          ['구미호', '이 구슬도 가져가거라. 네 기운이 더 깊어질 게다.'],
          ['@', '여우구슬을 얻었다. 최대 기 +30', () => { p.maxGi += 30; p.gi = p.maxGi; G.audio.sfx('item'); }],
        ], done);
      } else if (boss.type === 'imugi') {
        f.boss_imugi = true;
        g.cutsceneSay([
          ['이무기', '…그 노래, 바다 냄새가 나는구나.'],
          ['@verse', 5],
          ['이무기', '용왕께 전해다오. 언젠가 나도 하늘에 오르겠노라고.'],
          ['@', '용왕탈을 얻었다. (기 회복 2배, 스킬 피해 +20%)', () => { p.masks.push('yongwang'); G.audio.sfx('item'); }],
          ['@', '스킬 「용왕 물결」을 익혔다. (기 20)', () => { p.skills.skill3 = true; }],
        ], () => { done(); G.game.tutorial('skill3'); });
      }
    },

    yeoksinIntro() {
      const g = G.game, f = g.flags;
      f.yeoksin_started = true;
      const pos = at(20, 22.5);
      g.cutscene(async (c) => {
        await c.pan(pos.x, pos.y, 1.4);
        const boss = g.spawnBoss('yeoksin', pos.x, pos.y, 'house');
        boss.spawnT = 1.5;
        G.audio.sfx('roar'); G.fx.screenShake(8);
        await c.wait(1.0);
        await c.say([
          ['역신', '늦었구나, 처용. 이 집의 밤은 이제 내 것이다.'],
          ['역신', '네 노래는 아직 반쪽이지. 반쪽 노래로 나를 어찌하겠느냐?'],
          ['처용', '나가시오.'],
        ]);
        await c.pan(null, null, 0.6);
        g.startBossFight(boss, pos.x, pos.y + 60);
      });
    },

    // yeoksin at 30%: the song completes
    yeoksinTurn(boss) {
      const g = G.game, f = g.flags, p = g.player;
      g.cutscene(async (c) => {
        await c.pan(boss.x, boss.y - 30, 0.8);
        await c.say([
          ['역신', '흐흐… 화를 내 보아라, 처용. 칼을 뽑아 보아라!'],
          ['@', '들어와 자리를 보니 — 다리가 넷이로구나.'],
          ['처용', '…'],
          ['@', '처용은 칼 대신 노래를 골랐다.'],
          ['@verse', 7],
          ['@verse', 8],
          ['@', '노래가 완성되었다. 흥이 가득 찼다.', () => { p.heung = 100; f.song_complete = true; }],
        ]);
        await c.pan(null, null, 0.5);
        boss.ultVulnerable = true;
        G.game.tutorial('ult');
      });
    },

    yeoksinKneel(boss) {
      const g = G.game, f = g.flags;
      f.yeoksin_done = true;
      g.cutsceneSay([
        ['역신', '이럴 수가… 화내지 않고, 노래하다니.'],
        ['역신', '맹세하겠소. 처용의 얼굴이 그려진 문에는 다시는 들지 않으리다.'],
        ['@', '역신이 무릎 꿇고, 새벽 안개처럼 흩어졌다.'],
      ], () => { g.endBossFight(); g.refreshNpcs(); g.save(); });
    },
  };
  G.story = S;
})();
