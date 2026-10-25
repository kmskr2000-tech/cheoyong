# 코드 구조 · 모듈 계약

모든 코드는 `src/js/` 아래 ES 모듈. 외부 라이브러리 없음. 각 모듈은 아래 **계약(export 서명)** 을 그대로 지킨다. 다른 모듈을 만드는 사람은 이 문서만 보고 짠다.

```
src/
  index.html             캔버스 하나 + 터치 레인 오버레이 + 폰트 링크. <script type="module" src="js/main.js">
  js/main.js             부트, 캔버스 배율, 루프, 장면 전환, URL 훅, window.G
  js/input.js            키보드·터치 → 레인/행동 이벤트(시각 기록 포함)
  js/audio.js            WebAudio 합성(장구·박·피리), 시계, 장단 스케줄러
  js/chart.js            역신별 악보 생성(순수 함수, node에서도 실행 가능)
  js/rhythm.js           판정 엔진(순수, node에서도 실행 가능)
  js/save.js             localStorage
  js/story.js            텍스트 데이터(밤 소개·대사·구절·역신 이름)
  js/autopilot.js        ?auto 자동 조종
  js/render/paper.js     한지 배경·등불 역광·달·거리 실루엣
  js/render/puppet.js    그림자 인형: 처용·역신·집·탈·등불
  js/render/fx.js        입자·판정 글자·화면 번쩍임
  js/render/text.js      붓글씨풍 제목·세로쓰기·대사 상자
  js/scenes/title.js · story.js · night.js · dance.js · result.js · ending.js
tests/smoke.mjs          Playwright 스모크(스크린샷 tests/out/)
tests/shot.mjs           한 장면 찍기 유틸(serve/run export)
tests/unit.mjs           chart/rhythm 순수 로직 node 테스트
tools/build.mjs          단일 HTML → dist/index.html
```

## 좌표·시간
- 논리 캔버스 **960×540**. `main.js`가 DPR·레터박스 변환을 걸어 둔 `ctx`를 장면에 넘긴다. 장면은 논리 좌표로만 그린다.
- 시간 단위는 **초**. 춤의 기준 시계는 `Audio.now()`. 장면 `update(dt, now)`의 `now`도 `Audio.now()`다.
- 레인 0~3 = 왼소매·발·돌기·오른소매 (`docs/game-design.md` 표).

## main.js
```js
export const G = {            // window.G 와 같은 객체(디버그·테스트용)
  scene: null, sceneName: '', params: URLSearchParams, save, night: null /* 현재 밤 상태 */,
  reachedEnding: false, auto: false, muted: false, speed: 1, seed: 1,
};
export function setScene(name, params = {});   // name: 'title'|'story'|'night'|'dance'|'result'|'ending'
export function ctxSize();                     // {w:960, h:540}
```
- 장면 모듈은 `export default { enter(params, api), exit(), update(dt, now), draw(ctx, now), onLane(lane, at), onAction(name, at), onPointer(x, y, type) }`. `api = { setScene, G, Audio, Input, fx }`. 안 쓰는 메서드는 생략 가능.
- `onAction` 이름: `'confirm'`, `'back'`, `'left'`, `'right'`(눌림), `'leftUp'`, `'rightUp'`.
- `onPointer(x, y, type)` 논리 좌표, type `'down'|'up'|'move'`.
- **포인터 라우팅(main.js)**: 장면에 `onPointer` 가 있으면 그것만 부른다. 없으면 레인 영역(춤 장면 아래 18%) 밖의 `'up'` 을 `scene.onAction('confirm', at)` 으로 바꿔 준다. Input 은 포인터로 `'confirm'` 을 직접 내지 않는다(둘 다 처리하는 장면에서 이중 발화하던 문제). 그러니 `onPointer` 를 정의한 장면은 탭 확인을 스스로 처리한다.
- 탭이 숨겨지거나(`visibilitychange`) 창이 포커스를 잃으면(`blur`) `Audio.pause()`, 돌아오면 `Audio.resume()`. 일시정지 중 프레임 `dt` 는 0.
- 부트 순서: URL 파싱 → `Save.load()` → `Input.init(canvas, Audio)` → 첫 장면(기본 `title`; `?night`·`?dance`·`?ending`이면 해당 장면) → 루프. 첫 사용자 제스처에서 `Audio.init()` — `keydown`·`pointerup`·`touchend`·`click` (모바일에서 `pointerdown` 은 사용자 활성화가 아니라 쓰지 않는다). 막히면 다음 제스처에서 다시.
- `?auto`면 `Autopilot.attach(G)`. 준비되면 `window.__ready = true`.
- `?speed=k`는 `G.muted`일 때만 적용(`Audio.setSpeed(k)`).
- 전역 에러는 `window.__errors` 배열에 모은다(테스트가 읽음).

## input.js
```js
export const Input = {
  init(canvas, Audio),                // 키·터치·포인터 리스너. 터치 레인 영역: 화면 아래 18%를 네 칸.
  BAND_Y, laneZone,                   // 레인 영역 위 경계(논리 y) / 춤 장면에서만 true(main.js 가 설정)
  onLane(cb),                         // cb(lane, at)  at = Audio.now() (이벤트 시점에 기록)
  onAction(cb),                       // cb(name, at)
  onPointer(cb),                      // cb(x, y, type, at) 논리 좌표. 포인터로 'confirm' 액션은 내지 않는다
  touchMode: false,                   // 터치 입력이 한 번이라도 있거나 ?touch 면 true
  drawTouchLanes(ctx, activeLane),    // 네 칸 안내. main.js 가 춤 장면에서 `Input.activeLane` 으로 호출(장면은 부르지 않는다). touchMode일 때만 그림.
  get activeLane()                    // 눌려 있거나 누른 뒤 120ms(실시간) 이내인 레인, 없으면 -1
};
```
레인 영역(`laneZone && y >= BAND_Y`)은 **터치만** 잡는다(`pointerType === 'touch'` 또는 `touchMode`). 마우스 클릭은 영역 안에서도 보통 포인터 이벤트다.

키 매핑: 레인 ← A / ↓ S / ↑ W / → D (화살표 포함). confirm = Space·Enter·J, back = Esc. 춤 장면이 아니어도 ←/→ 는 `'left'/'right'` 행동으로도 나간다(밤거리 걷기). 키 반복(keydown repeat)은 무시.

## audio.js
```js
export const Audio = {
  async init(),                       // 사용자 제스처 안에서 호출. 두 번 불러도 안전.
  ready: false, muted: false,
  now(),                              // 초. ctx.currentTime - 출력지연 - Audio.offset (뮤트/미초기화/일시정지 중엔 performance.now()/1000*speed 가짜 시계, 전환 때 점프 없음)
  offset, setOffset(sec),             // 사용자 보정(기본 0, ±0.5초로 제한; 양수 = 판정 기준을 소리보다 늦춤). 저장은 호출자 몫, 춤 밖에서 바꿀 것
  pause(), resume(), paused,          // ctx.suspend/resume + 가짜 시계 정지. 숨김 동안 now() 가 서므로 판정도 선다. main.js 가 visibilitychange·blur/focus 에서 호출
  cancelPending(),                    // 아직 시작 안 한 예약음(시작 시각이 미래인 노드)을 모두 끊고 stopJangdan(). 춤 장면 exit 에서 호출 — 카운트인이 다음 장면으로 새지 않게
  setMuted(b), setSpeed(k),
  play(name, at = now(), gain = 1),   // name: 'deong'|'kung'|'deok'|'roll'|'bak'|'hit'|'miss'|'kneel'|'mask'|'step'|'confirm'|'flee'
  startJangdan({ bpm, startAt, pattern, melody }), // pattern: [{beat, name}] 한 마디(4박) 단위 반복 예약. melody: 음계 인덱스 배열(0~4) 또는 null
  stopJangdan(),
  setBpm(bpm, atBeat),                // 진행 중 템포 변경(열병귀)
  beatAt(time),                       // startJangdan 기준 time → 소수 박 번호
  timeAt(beat),                       // 박 번호 → 시간
};
```
- 합성만 쓴다(오디오 파일 없음). 스케줄은 100ms 룩어헤드 타이머.
- **시계 규칙**: `now()` 는 소리가 *들리는* 시각이다. `play(name, at)`·`startJangdan` 의 `at`/`startAt` 은 `now()` 기준이고, 내부에서 ctx 원시 시간으로 바꿔 예약한다(`raw = at + 출력지연 + offset - bias`). 출력지연은 `ctx.outputLatency || ctx.baseLatency || 0` 을 init·재개·장단 시작 때만 표본한다(now() 연속 유지).
- `init()` 은 ctx 가 `running` 이 아니면 호출될 때마다 `resume()` 을 다시 부른다(대기 promise 를 캐시하지 않음). `ready` 는 state 가 running 이거나 resume 이 resolve 됐을 때만 true.
- `hit`은 판정 등급별 소리가 아니고 하나다. 판정 소리는 장면이 `deok`(절) `kung`(장) `step`(박)으로 섞어 쓴다.

## chart.js (순수)
```js
export const SPIRITS = ['fever','chill','cough','pox','yeoksin'];
export function makeChart(spirit, nightIdx /*1..5*/, seed) 
// → { spirit, bpm, bpmChanges:[{beat, bpm}], lead: 4 /*박점 도달까지 선행 박 수*/, 
//     notes:[{ beat, lane, pair:bool /*동시음 짝 여부*/ }] 시간순,
//     lengthBeats, phases:[{ startBeat, kind:'dance'|'song', verse:int|null }] }
```
- 결정적(시드 기반 `rand`). 음표 수: 1밤 24개 → 4밤 64개 근처, yeoksin 96개 + 노래 단계 16개.
- `yeoksin`의 `phases`: dance(0~) · dance(두 번째, 모든 성격 섞음) · song(여덟 구절, verse 0..7 두 박마다 하나; 이 구간 음표는 판정은 하되 덕 감점 없음).
- `export function noteTimes(chart, startTime)` → 각 음표의 절대 시간 배열(`timeAt` 없이도 쓸 수 있게 bpmChanges 반영).

## rhythm.js (순수)
```js
export const WINDOWS = { jeol: 0.045, jang: 0.090, bak: 0.135 };
export class Judge {
  constructor(chart, startTime);     // 내부에서 noteTimes 계산
  update(now);                        // 지나간 음표 → 'miss' 처리, 결과 이벤트 큐에 push
  hit(lane, at);                      // → { grade:'jeol'|'jang'|'bak'|null, note } 가장 가까운 미판정 음표만 본다. null이면 헛손질(감점 없음)
  drain();                            // 지난 update/hit 이후 이벤트 [{type:'miss'|'hit', grade, note, at}]
  get hyung();                        // 역신 흉 0..100
  get deok();                         // 처용 덕 0..100
  get combo(); get stats();           // {jeol, jang, bak, miss, total}
  get done();                         // 마지막 음표 판정 끝 && now > 마지막 음표 + bak 창
  get broken();                       // deok <= 0
  outcome();                          // 'kneel' | 'flee' | null(진행 중). yeoksin은 끝나면 항상 'kneel'
  upcoming(now, horizonSec);          // 그릴 음표 [{note, t, dt}] (dt = t - now)
}
```
- 덕 감점은 `chart.phases`에서 `song` 구간이면 0.

## save.js
```js
export const Save = { load() → {night:1, masks:{}, best:{}, cleared:false}, write(data), clear(), KEY:'cheoyongmu.save' };
```

## story.js
```js
export const STORY = {
  verses: [8개 구절],
  spirits: { fever:{name:'열병귀', one:'한 줄 소개'}, chill, cough, pox, yeoksin },
  nights: [ { n:1, title:'첫째 밤', sub:'개운포에서 온 손', houses:5, spawn:['fever'], cap:2, spread:0,
              intro:[{who:'용왕', text:'…'}, …], outro:[…] }, … 5개 ],
  ending: [{who, text}, …],
  names: { cheoyong:'처용', wife:'아내', king:'헌강왕', granny:'할미', dragon:'용왕' }
};
```
`who`가 `'처용'`이면 한 문장. 톤은 ~하오/~소/~오.

## render/*.js
전부 **순수 그리기 함수**(상태 없음, `t`는 초). 색은 오방색 상수 `COLORS = { blue:'#1f4e79', red:'#b5342c', yellow:'#d9a441', white:'#f3e9d2', black:'#15110f', paper:'#e8d9b5', shadow:'#1a1410', lantern:'#f0b25a', miasma:'#5b3a7a' }` 를 `render/paper.js`에서 export.

```js
// paper.js
export function drawPaper(ctx, w, h, t, { moon = 1, lantern = {x,y,r} | null, redMoon = false } = {});   // 한지 결·역광·달·비네트
export function drawStreet(ctx, w, h, t, { houses:[{x, w}], horizonY });                                // 지평선·담장 실루엣·먼 산. 산·안개·땅만 캐시(집 x 와 무관), 담장은 매 프레임 단색으로 → x 가 바뀌어도 캔버스를 새로 만들지 않는다
// puppet.js  (모두 발밑 기준 x,y, scale 1 = 처용 키 220px)
export const POSES = ['idle','armL','step','spin','armR','bow','sing'];
export function drawCheoyong(ctx, x, y, scale, pose, t, { phase = 0 /* 0..1 포즈 진행 */, mask = true } = {});
export function drawSpirit(ctx, x, y, scale, type, state /* 'lurk'|'throw'|'flinch'|'kneel'|'flee' */, t, { phase = 0 } = {});
export function drawHouse(ctx, x, y, w, t, { lit = true, haunted = false, masked = false, home = false, seed = null } = {});
//   seed(정수): 주면 지붕 종류(초가/기와)·볏짚 결·창 불빛 위상이 모두 seed 에서 나온다 → x 가 스크롤돼도 안 깜빡임. 없으면 Math.round(x) 해시. 스크롤 장면은 집 인덱스를 seed 로 넘길 것.
export function drawMask(ctx, x, y, size, t, { glow = 0 } = {});   // 처용탈(유일한 온색)
export function drawLantern(ctx, x, y, size, t);
export function drawNote(ctx, x, y, lane, size, t, { pair = false, alpha = 1 } = {});   // 흉 음표(레인별 오방색 글리프)
// fx.js  (유일하게 상태 있는 모듈: 입자 목록)
export const fx = { burst(x, y, kind /* 'jeol'|'jang'|'bak'|'miss'|'mask'|'petal' */), text(x, y, str, color), flash(color, dur), ripple(x, y), update(dt), draw(ctx), clear() };
// text.js
export const FONT = "'Nanum Brush Script','Noto Serif KR',serif";
export function brushTitle(ctx, str, x, y, size, color, { align = 'center', jitter = 0 } = {});   // (str,size,color,jitter,align) 별 2× 오프스크린 캐시(LRU 64). jitter 는 구울 때 고정. 호출자의 globalAlpha 가 적용된다
export function verticalText(ctx, str, x, y, size, color);
export function dialogBox(ctx, w, h, who, text, t, { progress = 1 } = {});   // 아래 letterbox 대사 상자, 타자 효과는 progress
export function wrapText(ctx, str, maxW) → string[];
```

## scenes/*.js 요약
- **title**: 큰 붓글씨 "처용무", 부제 "밤의 문", 처용 그림자가 천천히 춤, 메뉴 [새로 시작 / 이어하기(저장 있을 때)]. 확인으로 선택.
- **story**: `params.lines`, `params.next`(다음 장면 이름과 params). 확인마다 다음 줄, 끝나면 next.
- **night**: `G.night = { n, houses:[{x, w, haunted:type|null, masked, home}], spirits:[], cheoyongX, lastSpread }`. ←/→로 걷기(속도 260px/s), 집 앞(±40px)에서 확인 → `setScene('dance', {spirit, houseIdx})`. 전파 타이머. 역신 0 → `setScene('result')`. 상단에 "n째 밤 · 남은 역신 k" 표시. 터치: 집 탭 → 자동 이동 후 시작.
- **dance**: 왼쪽에 처용(x=150, 발밑 y=430), 박점 x=300, 오른쪽에 역신(x=760). 네 줄 레인 y=300..420 간격 40, 음표는 오른쪽에서 왼쪽으로 `lead`박 동안 흘러온다. 상단에 흉 게이지(오른쪽), 덕 게이지(왼쪽). 판정 시 처용 포즈 교체 + fx. `Judge.outcome()` 나오면 kneel/flee 연출(1.5초) → 밤거리로 돌아가 결과 반영(`params.houseIdx`). `?dance=` 로 바로 들어오면 결과 후 title로.
- **result**: 그 밤 요약(굴복 수, 덕 평균, 등급 상/중/하) → 저장 → story(outro) → 다음 밤 intro → night. 5밤 뒤에는 ending.
- **ending**: 모든 문에 탈이 걸린 새벽 거리를 옆으로 천천히 지나가며 처용가 여덟 구절이 세로쓰기로 뜬다. 마지막에 "처용무 — 끝". `G.reachedEnding = true; console.log('REACHED ENDING')`.

## autopilot.js
`Autopilot.attach(G)`: 매 프레임 장면을 보고 — title: confirm · story: 0.25초마다 confirm · night: 가장 가까운 역신 집으로 걷다가 confirm · dance: `Judge.upcoming` 보고 음표 시각 ±0.01에 `scene.onLane` 호출(10%는 ±0.06으로 '장') · result/ending: confirm. 장면이 노출하는 `scene.debug()`(`{ judge, night … }`)로 들여다본다.

## 테스트·빌드
- `node tests/unit.mjs`: 모든 역신·밤의 악보가 시간순·레인 범위·phases 일관, Judge 완벽 입력 시 `kneel`, 전부 놓침 시 `flee`/`broken`.
- `node tests/smoke.mjs`: 타이틀·밤거리·춤 장면 스크린샷 + 오류 0, `?auto&mute&speed=6` 으로 90초 안에 `REACHED ENDING`.
- `node tools/build.mjs`: `src/index.html`의 모듈 스크립트를 하나로 묶어 `dist/index.html`(import 문을 순서대로 인라인; 간단한 번들러를 직접 작성).
