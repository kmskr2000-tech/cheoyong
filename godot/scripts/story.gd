# Story: quest stages, NPC dialogue, triggers, spawns and boss events. Progress lives in game.flags.
class_name Story
extends RefCounted

const T := 32
const VERSES := ["서라벌 밝은 달에", "밤 늦도록 노닐다가", "들어와 자리를 보니", "다리가 넷이로구나",
	"둘은 내 것이었고", "둘은 누구의 것인가", "본디 내 것이다마는", "빼앗긴 것을 어찌하리"]

# id, sprite, tile x, tile y, name, facing, visibility (flags -> bool) or null
var NPCS = [
	["yongwang", "yongwang", 106.5, 70.5, "용왕", "west", null],
	["hwarang", "hwarang", 66, 68.6, "화랑", "south", null],
	["halmi", "halmi", 52.5, 53, "할미", "east", null],
	["merchant", "merchant", 55, 47.6, "상인", "south", null],
	["dosa", "dosa", 74, 46.6, "도사", "west", null],
	["child", "child", 63, 57, "아이", "south", null],
	["dog", "dog", 64.5, 57.8, "누렁이", "west", null],
	["sick", "sick", 48.8, 46, "앓는 사람", "south", null],
	["wife", "wife", 58, 42, "아내", "south", func(f): return f.get("king_met", false) and not f.get("house_open", false)],
	["king", "king", 61, 43.2, "왕", "south", func(f): return f.get("king_event", false)],
	["monk", "monk", 70, 16.5, "스님", "west", null],
	["sansin", "sansin", 36.5, 54.5, "산신령", "south", null],
	["villager", "villager", 71, 55, "아낙", "west", null],
	["wife_home", "wife", 23, 24.5, "아내", "south", func(f): return f.get("yeoksin_done", false)],
]
const SPAWNS := {
	"beach": {"lvl": 1, "list": [["imp", 96, 62], ["imp", 90, 66], ["snake", 86, 74], ["imp", 100, 76], ["snake", 92, 80], ["imp", 84, 62], ["snake", 104, 64], ["imp", 88, 84]]},
	"ruin": {"lvl": 2, "list": [["imp", 92, 18], ["dokkaebi", 96, 26], ["dokkaebi", 106, 18], ["imp", 110, 26], ["dokkaebi", 90, 32], ["dokkaebi", 112, 12], ["imp", 98, 12], ["dokkaebi", 104, 32]]},
	"forest": {"lvl": 3, "list": [["imp", 30, 50], ["ghoul", 24, 56], ["ghoul", 14, 52], ["imp", 10, 64], ["ghoul", 28, 72], ["imp", 12, 80], ["ghoul", 30, 82], ["imp", 20, 60]]},
	"pond": {"lvl": 3, "list": [["snake", 46, 20], ["snake", 72, 22], ["ghoul", 50, 24], ["snake", 44, 10], ["ghoul", 76, 18], ["snake", 66, 24], ["ghoul", 54, 8], ["snake", 78, 8]]},
	"house": {"lvl": 4, "list": [["ghost", 12, 12], ["ghost", 30, 14], ["ghost", 12, 26], ["ghost", 30, 26]]},
}
const BOSSES := {
	"ruin": {"type": "dokchief", "flag": "boss_dok", "at": [101, 27], "need": "kills_ruin", "trigger": [101, 25]},
	"forest": {"type": "gumiho", "flag": "boss_fox", "at": [18, 75], "need": "kills_forest", "trigger": [18, 72]},
	"pond": {"type": "imugi", "flag": "boss_imugi", "at": [59, 19.5], "need": "kills_pond", "trigger": [59, 22]},
}

# 향가 (chapters 2-6): one per chapter, each strengthens a dance
const HYANGGA := {
	"chan": {"name": "찬기파랑가", "by": "충담사", "line": "잣나무 가지 높아 눈도 덮지 못할 화랑이여", "effect": "소리결이 세 갈래로 퍼지고 더 세진다"},
	"jemang": {"name": "제망매가", "by": "월명사", "line": "한 가지에 났건만 가는 곳을 모르는구나", "effect": "탈춤 회오리가 맞힐 때마다 체력이 돌아온다"},
	"heonhwa": {"name": "헌화가", "by": "소 끄는 노인", "line": "붉은 바위 끝에 꽃을 꺾어 바치오리다", "effect": "구르면 꽃잎 막이 피해를 절반으로 막는다"},
	"docheon": {"name": "도천수관음가", "by": "희명", "line": "천 개의 손 가운데 하나만 내어 주소서", "effect": "소매 공격이 이따금 두 번 친다"},
	"dosol": {"name": "도솔가", "by": "월명사", "line": "오늘 노래 불러 뿌린 꽃이여, 곧은 마음을 따르라", "effect": "처용가가 더 세지고 흥이 빨리 찬다"},
}
const HYANGGA_ORDER := ["chan", "jemang", "heonhwa", "docheon", "dosol"]

var g  # the Game
var chapters := {}  # map id -> Chapter

func _init(game) -> void:
	g = game
	for i in range(2, 7):
		var path := "res://scripts/chapters/ch%d.gd" % i
		if ResourceLoader.exists(path):
			var c = load(path).new(game)
			chapters[c.map] = c

func chapter():
	return chapters.get(g.map_id)

# the chapter the story is in now (null during chapter 1 and after the ending)
func main_chapter():
	if not fl("ch1_done"): return null
	for m in Maps.ORDER:
		if chapters.has(m) and not chapters[m].done(): return chapters[m]
	return null

func hyangga_count() -> int:
	var c := 0
	for k in HYANGGA_ORDER:
		if fl("hy_" + k): c += 1
	return c

# ---------- per-map data ----------
func npcs() -> Array:
	var list: Array = NPCS if g.map_id == "seorabeol" else (chapter().npcs() if chapter() else [])
	var st: Dictionary = Maps.STATION.get(g.map_id, {})
	if st:
		list = list + [["mabu", "mabu", st.mabu[0], st.mabu[1], "역참 마부", "south", func(f): return f.get("ch1_done", false)]]
	return list

func spawns() -> Dictionary:
	if g.map_id == "seorabeol": return SPAWNS
	return chapter().spawns() if chapter() else {}

func bosses() -> Dictionary:
	if g.map_id == "seorabeol": return BOSSES
	return chapter().bosses() if chapter() else {}

func on_purify(e) -> void:
	if chapter(): chapter().on_purify(e)

# where the mabu stands on this map
func mabu_pos():
	var st: Dictionary = Maps.STATION.get(g.map_id, {})
	return at(st.mabu[0], st.mabu[1]) if st else null

func travel_objective(to_map: String) -> Dictionary:
	return {"text": "역참 마부에게 — %s(으)로" % Maps.NAMES[to_map], "target": mabu_pos(), "talk": "mabu", "travel": to_map}

func open_travel() -> void:
	var opts = []
	for m in Maps.ORDER:
		if m == g.map_id: continue
		if m == "seorabeol" or fl("map_" + m):
			opts.append({"label": Maps.NAMES[m], "map": m, "fn": func(): g.travel(m)})
	if opts.is_empty():
		g.ui.say([["역참 마부", "아직 갈 만한 곳이 없소. 길이 열리면 말씀하시오."]])
		return
	opts.append({"label": "그만두겠소", "fn": func(): pass})
	g.ui.choose("어디로 모실까요?", opts)

static func at(tx: float, ty: float) -> Vector2: return Vector2(tx * T, ty * T)

func fl(k: String) -> bool: return g.flags.get(k, false)
func num(k: String) -> int: return int(g.flags.get(k, 0))

# ---------- objective shown on the HUD (with guide arrow target) ----------
func objective() -> Dictionary:
	if fl("ch1_done"):
		var c = main_chapter()
		if c == null: return {"text": "", "target": null}
		if not c.started() or c.map != g.map_id:
			return travel_objective(c.map) if g.map_id != c.map else {"text": c.title, "target": null}
		return c.objective()
	if fl("yeoksin_done") and g.map_id != "seorabeol": return travel_objective("seorabeol")
	return objective1()

func objective1() -> Dictionary:
	if not fl("q1"): return {"text": "용왕에게 말을 걸어 보시오", "target": at(106.5, 70.5)}
	if not fl("q2"):
		if num("kills_beach") < 6: return {"text": "개운포의 요괴 정화 (%d/6)" % num("kills_beach"), "target": null}
		return {"text": "용왕에게 돌아가시오", "target": at(106.5, 70.5)}
	if not fl("king_met"): return {"text": "남문을 지나 서라벌 광장으로", "target": at(61, 50)}
	if not fl("q3"): return {"text": "저잣거리의 할미를 찾으시오", "target": at(52.5, 53)}
	if not fl("q4"):
		if fl("boss_dok") and fl("boss_fox") and fl("boss_imugi"): return {"text": "할미에게 돌아가시오", "target": at(52.5, 53)}
		var parts = []
		if not fl("boss_dok"): parts.append("우물터: 우두머리" if num("kills_ruin") >= 6 else "우물터 %d/6" % num("kills_ruin"))
		if not fl("boss_fox"): parts.append("여우숲: 우두머리" if num("kills_forest") >= 6 else "여우숲 %d/6" % num("kills_forest"))
		if not fl("boss_imugi"): parts.append("연못: 우두머리" if num("kills_pond") >= 6 else "연못 %d/6" % num("kills_pond"))
		if not fl("dosa_done"): parts.append("도사에게" if num("kills_total") >= 12 else "도사 %d/12" % num("kills_total"))
		var target = null
		for z in ["ruin", "forest", "pond"]:
			var b: Dictionary = BOSSES[z]
			if not fl(b.flag) and num(b.need) >= 6: target = at(b.trigger[0], b.trigger[1]); break
		if target == null and not fl("dosa_done") and num("kills_total") >= 12: target = at(74, 46.6)
		return {"text": "흩어진 구절 — " + " · ".join(parts), "target": target}
	if not fl("q5"): return {"text": "할미에게 돌아가시오", "target": at(52.5, 53)}
	if not fl("yeoksin_done"): return {"text": "처용의 집으로", "target": at(20, 24)}
	return {"text": "아내에게 가 보시오", "target": at(23, 24.5)}

# ---------- talking ----------
func interact(npc) -> void:
	if npc.id == "mabu":
		g.ui.say([["역참 마부", "말은 늘 준비돼 있소. 어디로 가시려오?"]], func(): open_travel())
		return
	if g.map_id != "seorabeol":
		if chapter() and not chapter().talk(npc): g.ui.say([[npc.name, "……"]])
		return
	var f: Dictionary = g.flags; var p = g.player
	var say = func(lines, done = null): g.ui.say(lines, done)
	match npc.id:
		"yongwang":
			if not fl("q1"):
				say.call([
					["용왕", "깨었느냐, 아들아. 개운포에 탁한 기운이 차올랐구나."],
					["용왕", "이 탈을 받아라. 처용탈이다. 탈을 쓰면 요괴의 탁기가 보이고, 노래가 힘이 된다."],
					["@", "처용탈을 얻었다.", func(): p.masks.append("cheoyong"); p.mask = "cheoyong"; Sfx.sfx("item")],
					["용왕", "잊지 마라. 우리는 죽이지 않는다. 쓰러뜨리고, 노래로 탁기를 걷어 낸다."],
					["용왕", "첫 구절을 주마. 귀 기울이거라."],
					["@verse", 1],
					["용왕", "모래톱의 요괴 여섯을 정화하고 돌아오너라. 소매를 휘두르면 된다."],
					["처용", "다녀오겠소."],
				], func(): f.q1 = true; f.has_attack = true; g.tutorial("attack"); g.save_game())
			elif not fl("q2") and num("kills_beach") >= 6:
				say.call([
					["용왕", "잘했다. 쓰러진 것들이 편히 바다로 돌아갔구나."],
					["용왕", "소매에 소리를 실어 보내는 법을 가르쳐 주마. 소리결이다."],
					["@", "스킬 「소리결」을 익혔다. (기 12)", func(): p.skills.skill1 = true; Sfx.sfx("quest")],
					["용왕", "싸우며 흥이 차오르면 처용가를 부를 수 있다. 모은 구절이 많을수록 노래는 강해진다."],
					["@", "흥이 가득 차면 「처용가」를 부를 수 있다.", func(): f.has_ult = true],
					["용왕", "이제 서라벌로 가거라. 남문의 화랑에게 내 이름을 대면 된다."],
					["용왕", "그리고… 서두르거라. 왕이… 오신다."],
					["처용", "…왕이?"],
				], func(): f.q2 = true; f.gate_open = true; g.tutorial("skill1"); g.refresh_npcs(); g.save_game())
			elif not fl("q2"):
				say.call([["용왕", "모래톱의 요괴가 아직 남았다. (%d/6)" % num("kills_beach")]])
			else:
				say.call([["용왕", "노래가 거의 다 모였구나. 네 집으로 가거라." if fl("q5") else "서라벌의 밤이 깊다. 노래를 모으거라, 아들아."]])
		"hwarang":
			if not fl("gate_open"): say.call([["화랑", "멈추시오! 남문 밖에 요괴가 날뛰어 문을 닫았소."], ["화랑", "개운포가 잠잠해지기 전엔 열 수 없소."]])
			else: say.call([["화랑", "용왕님의 아드님이시라고요? 어서 드시오. 서라벌이 그대를 기다렸소."]])
		"halmi":
			if not fl("king_met"): say.call([["할미", "에구, 손님이시구려. 광장에 귀한 분이 오신다던데."]])
			elif not fl("q3"):
				say.call([
					["할미", "에구, 용왕님 아드님이시구려. 잘 오셨소."],
					["할미", "역신이 깨어났소. 사람 몸에 스며 병을 퍼뜨리는 귀신이지."],
					["할미", "그 놈을 굴복시킬 노래가 있었는데, 여덟 구절이 흩어져 버렸다오."],
					["할미", "우물터, 여우숲, 연못 절터… 탁기가 짙은 곳마다 구절이 붙들려 있을 게요."],
					["할미", "정자의 도사도 찾아가 보시오. 춤을 가르쳐 줄 게요."],
					["처용", "모으겠소."],
					["@", "서라벌을 둘러싼 탁기가 걷혔다.", func(): Sfx.sfx("quest")],
				], func(): f.q3 = true; f.paths_open = true; g.save_game())
			elif not fl("q4") and fl("boss_dok") and fl("boss_fox") and fl("boss_imugi"):
				say.call([
					["할미", "세 우두머리를 모두 무릎 꿇리셨구려! 장하오."],
					["할미", "여섯째 구절은 이 늙은이가 지켜 왔소."],
					["@verse", 6],
					["할미", "그런데… 역신이 처용 님 집에 들었다는 소문이오. 아씨가 위험하오!"],
					["처용", "…가겠소."],
				], func(): f.q4 = true; f.q5 = true; f.house_open = true; g.refresh_npcs(); g.save_game())
			elif fl("q5") and not fl("yeoksin_done"): say.call([["할미", "어서 집으로 가시오! 북서쪽 담장 너머요."]])
			else: say.call([["할미", "노래가 다 모였구려. 이제 서라벌의 밤도 편하겠소." if fl("yeoksin_done") else "우물터는 동북, 여우숲은 서, 연못 절터는 북쪽이오."]])
		"merchant":
			say.call([["상인", "어서 오시오! 약과 한 상자, 식혜 한 사발, 싸게 드리리다."]], func(): g.ui.open_shop())
		"dosa":
			if not fl("q3"): say.call([["도사", "허허, 바람이 탁하구먼."]])
			elif fl("dosa_done"): say.call([["도사", "돌고, 또 돌게. 춤은 몸으로 부르는 노래일세."]])
			elif num("kills_total") < 12: say.call([["도사", "요괴 열둘을 정화하고 오시게. (%d/12)" % num("kills_total")], ["도사", "그대 춤에 무엇이 모자란지 그때 보이겠지."]])
			else:
				say.call([
					["도사", "됐네. 발을 이렇게… 돌고, 또 돌게."],
					["@", "스킬 「탈춤 회오리」를 익혔다. (기 18)", func(): p.skills.skill2 = true; Sfx.sfx("quest")],
					["도사", "그리고 이건 내가 바람에서 주운 구절일세."],
					["@verse", 3],
				], func(): f.dosa_done = true; g.tutorial("skill2"); g.save_game())
		"child": say.call([["아이", "처용 아저씨 얼굴 그려서 문에 붙였어요!" if fl("yeoksin_done") else "처용 아저씨! 밤에 문 앞에 탈 그림 붙이면 귀신이 못 들어온대요!"]])
		"dog": say.call([["누렁이", "멍! 멍!"]])
		"sick": say.call([["앓는 사람", "콜록… 밤마다 꿈에 누가 내 자리 옆에 눕소…"], ["앓는 사람", "다리가… 넷이 보였소. 콜록."]])
		"wife": say.call([["아내", "밤이 깊었소. 노래를 다 모으면 집으로 오시오. 기다리겠소." if fl("q3") else "처용 님. 서라벌은 낯설지요? 천천히 둘러보시오."]])
		"king": say.call([["왕", "서라벌을 부탁하오, 처용."]])
		"monk":
			if fl("boss_imugi"): say.call([["스님", "이무기가 편히 잠들었소. 나무아미타불."]])
			else: say.call([["스님", "연못 바닥에 이무기가 잠들어 있소. 용이 되지 못한 원한이 탁기를 부르오."], ["스님", "연못가 요괴를 먼저 걷어 내시오. 그러면 놈이 올라올 게요."]])
		"sansin":
			if fl("boss_fox"): say.call([["산신령", "숲이 다시 숨을 쉬는구먼. 고맙소."]])
			else: say.call([["산신령", "여우숲의 구미호가 사람 넋을 홀리고 있소."], ["산신령", "숲의 요괴를 여섯 정화하면 놈이 숲 안쪽 제단에 나타날 게요."]])
		"villager": say.call([["아낙", "저잣거리 상인한테 약과 사 두시오. 밤길엔 그게 약이라오."]])
		"wife_home":
			if fl("ch1_done"):
				say.call([["아내", "남산이며 토함산이며… 먼 길이겠지요. 몸조심하시오." if not fl("c6_done") else "이제 정말 끝났구려. 어서 들어오시오."]])
				return
			say.call([
				["아내", "처용 님… 노랫소리가 들렸소."],
				["처용", "돌아왔소."],
				["아내", "그런데… 역신이 흩어지며 웃는 소리를 들었소. '내 뿌리는 신라 땅 곳곳에 있다'고."],
				["아내", "남산 아래 마을에서 쇠붙이가 사라지고 사람들이 앓는다는 소문도 들리오."],
				["처용", "…다녀오겠소."],
				["아내", "남문 곁 역참에 마부가 있소. 신라의 노래들이 그대를 도울 게요."],
				["@", "제1장 서라벌 — 끝. 역신의 뿌리를 찾아 신라 곳곳의 향가를 모으자."],
			], func():
				f.ch1_done = true; f.map_namsan = true; g.refresh_npcs(); g.ui.toast("이동할 수 있는 곳: 남산"); g.save_game())

# ---------- triggers (every frame) ----------
func update(dt: float) -> void:
	if g.map_id != "seorabeol":
		if chapter(): chapter().update(dt)
		return
	var p = g.player
	if g.frozen or g.boss: return
	if fl("q2") and not fl("king_event") and Vector2(p.x, p.y).distance_to(at(61, 50)) < 260: king_event()
	for zone in BOSSES:
		var b: Dictionary = BOSSES[zone]
		if fl(b.flag) or num(b.need) < 6: continue
		if Vector2(p.x, p.y).distance_to(at(b.trigger[0], b.trigger[1])) < 220: boss_intro(zone); return
	if fl("house_open") and not fl("yeoksin_done") and not fl("yeoksin_started") and p.y < 30 * T and p.x < 32 * T and p.y > 6 * T: yeoksin_intro()

func king_event() -> void:
	g.flags.king_event = true
	g.refresh_npcs()
	g.cutscene(func():
		await g.pan(at(61, 46), 1.2)
		Sfx.sfx("door")
		await g.say_async([
			["왕", "그대가 동해 용왕의 아들이오? 개운포의 탁기를 걷어 주었다 들었소."],
			["왕", "서라벌에 머물러 나를 도와주시오. 급간 벼슬을 내리고, 어진 아내도 맞게 하겠소."],
		])
		g.flags.king_met = true; g.refresh_npcs()
		await g.say_async([
			["아내", "…처용 님이시군요. 앞으로 잘 부탁드리오."],
			["처용", "고맙소."],
			["왕", "허나 요즘 밤마다 역병이 돈다오. 저잣거리 할미가 무언가 안다 하니 들어 보시오."],
		])
		await g.pan(null, 0.8)
		g.save_game())

func boss_intro(zone: String) -> void:
	var b: Dictionary = BOSSES[zone]
	var pos = at(b.at[0], b.at[1])
	var lines: Array = {
		"ruin": [["도깨비 대장", "흐하하! 누가 내 우물터를 어지럽히느냐!"], ["도깨비 대장", "내 방망이 맛 좀 봐라!"]],
		"forest": [["구미호", "곱게 생긴 사내로구나…"], ["구미호", "네 넋도 내 꼬리 하나가 되리라."]],
		"pond": [["이무기", "용이 되지 못한 나를… 용왕의 아들이 비웃으러 왔느냐!"]],
	}[zone]
	g.boss = true  # blocks re-trigger until the fight starts
	g.cutscene(func():
		var boss = g.spawn_boss(b.type, pos.x, pos.y, zone)
		boss.spawn_t = 1.2
		Sfx.sfx("roar"); g.fx.screen_shake(10)
		await g.pan(pos + Vector2(0, -40), 1.0)
		await g.wait(0.6)
		await g.say_async(lines)
		await g.pan(null, 0.6)
		g.start_boss_fight(boss, pos.x, pos.y + 40))

func boss_defeated(boss) -> void:
	if g.map_id != "seorabeol" and chapter() and chapter().boss_defeated(boss): return
	var f: Dictionary = g.flags; var p = g.player
	var done = func(): g.end_boss_fight(); g.save_game()
	match boss.type:
		"dokchief":
			f.boss_dok = true
			g.cutscene_say([
				["도깨비 대장", "끄응… 졌소, 졌어. 그 노래 참 고약하게 좋구먼."],
				["도깨비 대장", "이 구절은 돌려주리다."],
				["@verse", 2],
				["도깨비 대장", "내 탈도 가져가시오. 무섭게 생겼지만 힘은 세다오."],
				["@", "귀면탈을 얻었다. (공격 +35%, 받는 피해 +15%)", func(): p.masks.append("gwimyeon"); Sfx.sfx("item")],
			], func(): done.call(); g.tutorial("mask"))
		"gumiho":
			f.boss_fox = true
			g.cutscene_say([
				["구미호", "아아… 노랫소리가 따뜻하구나. 홀린 넋들을 놓아주마."],
				["@verse", 4],
				["구미호", "이 구슬도 가져가거라. 네 기운이 더 깊어질 게다."],
				["@", "여우구슬을 얻었다. 최대 기 +30", func(): p.max_gi += 30; p.gi = p.max_gi; Sfx.sfx("item")],
			], done)
		"imugi":
			f.boss_imugi = true
			g.cutscene_say([
				["이무기", "…그 노래, 바다 냄새가 나는구나."],
				["@verse", 5],
				["이무기", "용왕께 전해다오. 언젠가 나도 하늘에 오르겠노라고."],
				["@", "용왕탈을 얻었다. (기 회복 2배, 스킬 피해 +20%)", func(): p.masks.append("yongwang"); Sfx.sfx("item")],
				["@", "스킬 「용왕 물결」을 익혔다. (기 20)", func(): p.skills.skill3 = true],
			], func(): done.call(); g.tutorial("skill3"))

func yeoksin_intro() -> void:
	g.flags.yeoksin_started = true
	var pos = at(20, 22.5)
	g.boss = true
	g.cutscene(func():
		await g.pan(pos, 1.4)
		var boss = g.spawn_boss("yeoksin", pos.x, pos.y, "house")
		boss.spawn_t = 1.5
		Sfx.sfx("roar"); g.fx.screen_shake(8)
		await g.wait(1.0)
		await g.say_async([
			["역신", "늦었구나, 처용. 이 집의 밤은 이제 내 것이다."],
			["역신", "네 노래는 아직 반쪽이지. 반쪽 노래로 나를 어찌하겠느냐?"],
			["처용", "나가시오."],
		])
		await g.pan(null, 0.6)
		g.start_boss_fight(boss, pos.x, pos.y + 60))

# yeoksin at 30%: the song completes
func yeoksin_turn(boss) -> void:
	var p = g.player
	g.cutscene(func():
		await g.pan(Vector2(boss.x, boss.y - 30), 0.8)
		await g.say_async([
			["역신", "흐흐… 화를 내 보아라, 처용. 칼을 뽑아 보아라!"],
			["@", "들어와 자리를 보니 — 다리가 넷이로구나."],
			["처용", "…"],
			["@", "처용은 칼 대신 노래를 골랐다."],
			["@verse", 7],
			["@verse", 8],
			["@", "노래가 완성되었다. 흥이 가득 찼다.", func(): p.heung = 100.0; g.flags.song_complete = true],
		])
		await g.pan(null, 0.5)
		boss.ult_vulnerable = true
		g.tutorial("ult"))

func yeoksin_kneel(_boss) -> void:
	g.flags.yeoksin_done = true
	g.cutscene_say([
		["역신", "이럴 수가… 화내지 않고, 노래하다니."],
		["역신", "맹세하겠소. 처용의 얼굴이 그려진 문에는 다시는 들지 않으리다."],
		["역신", "…흐흐. 허나 이 몸은 그림자일 뿐. 내 뿌리는 신라 땅 곳곳에 내렸느니라."],
		["@", "역신의 그림자가 무릎 꿇고, 새벽 안개처럼 흩어졌다."],
	], func(): g.end_boss_fight(); g.refresh_npcs(); g.save_game())
