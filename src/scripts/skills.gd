class_name Skills
## 스킬 트리 (docs/growth-system.md §4): 소리 · 춤 · 가호 세 계열, 28개 수(手).
## 레벨업마다 1점. 비용은 1·2티어 1점, 3티어 2점, 비전(캡스톤) 3점 — 29점으로 다 배울 수 없다.
## 선행: 2티어는 같은 계열 1티어 2개, 3티어는 2티어 2개, 비전은 3티어 1개. 가호는 4장(용궁)에서 열린다.
## "live": false 인 수는 그 바탕(처용무·신명·부적 여럿 …)이 들어올 때까지 배울 수 없다.

const TREES := {
	"sori": {"name": "소리", "desc": "피리·노래·부적"},
	"chum": {"name": "춤", "desc": "회피·기동·처용무"},
	"gaho": {"name": "가호", "desc": "용왕의 힘 (4장)"},
}
const COST := {1: 1, 2: 1, 3: 2, 4: 3}
const NEED := {2: [1, 2], 3: [2, 2], 4: [3, 1]}   # tier: [이전 티어, 몇 개]
const TIER_NAME := {1: "1단", 2: "2단", 3: "3단", 4: "비전"}

const LIST := [
	# ① 소리
	{"id": "jangdan", "tree": "sori", "tier": 1, "name": "장단맞춤", "live": true,
		"desc": "베기가 끝나 갈 즈음 이어 치면 장단이 맞는다. 두 번 다 맞추면 셋째 찌르기 +30%."},
	{"id": "eumpa", "tree": "sori", "tier": 1, "name": "흩날리는 음파", "live": true,
		"desc": "베기마다 음파 참격이 앞으로 날아간다 (원거리 견제)."},
	{"id": "bujeok", "tree": "sori", "tier": 1, "name": "부적 다루기", "live": true,
		"desc": "부적 전환 대기 1초 → 0.5초."},
	{"id": "hwayeom2", "tree": "sori", "tier": 2, "name": "화염부·진", "live": true,
		"desc": "화염부 범위 +40%, 지속 +2초."},
	{"id": "gyeolbak2", "tree": "sori", "tier": 2, "name": "결박부·진", "live": true,
		"desc": "결박 지속 +4초, 결박된 적에게 베기 +30%."},
	{"id": "suho2", "tree": "sori", "tier": 2, "name": "수호부·진", "live": true,
		"desc": "수호막이 두 번 막고, 막아낸 공격을 음파로 되돌린다."},
	{"id": "padong", "tree": "sori", "tier": 2, "name": "파동부", "live": true,
		"desc": "넷째 부적 — 앞으로 밀쳐 내는 파동."},
	{"id": "hyeonhok", "tree": "sori", "tier": 3, "name": "현혹부", "live": false,
		"desc": "다섯째 부적 — 요괴 하나를 8초간 내 편으로."},
	{"id": "gyeopnorae", "tree": "sori", "tier": 3, "name": "겹노래", "live": true,
		"desc": "처용가가 두 겹으로 울려 정화 범위 2배."},
	{"id": "cheonji", "tree": "sori", "tier": 4, "name": "천지울림", "live": true,
		"desc": "처용무를 추면 온 화면에 음파가 터진다."},
	# ② 춤
	{"id": "nabi", "tree": "chum", "tier": 1, "name": "나비춤", "live": true,
		"desc": "구르기 거리 +30%."},
	{"id": "batanum", "tree": "chum", "tier": 1, "name": "받아넘기기", "live": true,
		"desc": "구르는 중 맞으면 시간이 느려지고 반격한다."},
	{"id": "yeonpung", "tree": "chum", "tier": 1, "name": "연풍", "live": true,
		"desc": "구르고 나서 2초간 이동 속도 +25%."},
	{"id": "geommu", "tree": "chum", "tier": 2, "name": "검무", "live": true,
		"desc": "셋째 찌르기가 둘레를 휩쓰는 범위 베기가 된다."},
	{"id": "hak", "tree": "chum", "tier": 2, "name": "학의 질주", "live": true,
		"desc": "구르기 버튼 두 번 — 먼 거리 돌진 (돌진 중 무적)."},
	{"id": "geurimja", "tree": "chum", "tier": 2, "name": "그림자춤", "live": false,
		"desc": "분신 하나가 10초간 요괴의 눈을 끈다."},
	{"id": "obang", "tree": "chum", "tier": 3, "name": "오방신장", "live": true,
		"desc": "처용무에 오방신장이 함께 쳐 춤의 피해가 두 배."},
	{"id": "muaji", "tree": "chum", "tier": 3, "name": "무아지경", "live": true,
		"desc": "체력 30% 이하에서 공격 속도 +40%, 받는 피해 -20%."},
	{"id": "sinmyeong", "tree": "chum", "tier": 4, "name": "신명폭발", "live": true,
		"desc": "신명이 가득 차는 순간 절로 터져 둘레를 친다 (처용무는 그대로 쓸 수 있다)."},
	# ③ 가호 (4장 해금)
	{"id": "bigeul", "tree": "gaho", "tier": 1, "name": "비늘 갑옷", "live": true,
		"desc": "받는 피해 -12%."},
	{"id": "yongpae", "tree": "gaho", "tier": 1, "name": "용패 감지", "live": false,
		"desc": "탁기·요괴를 두 배 멀리서 느낀다."},
	{"id": "simhae", "tree": "gaho", "tier": 1, "name": "심해의 인내", "live": true,
		"desc": "최대 체력 +40, 맞을 때마다 기력 +5."},
	{"id": "pado", "tree": "gaho", "tier": 2, "name": "파도의 가호", "live": false,
		"desc": "물 기운 피해 +30% (물가에서 +50%)."},
	{"id": "geobuk", "tree": "gaho", "tier": 2, "name": "거북의 걸음", "live": false,
		"desc": "밀려나지 않고, 묶임·느려짐이 30% 짧아진다."},
	{"id": "yeouiju", "tree": "gaho", "tier": 2, "name": "여의주 공명", "live": true,
		"desc": "정기 +20%, 재료가 떨어질 확률 +20%."},
	{"id": "yongwang", "tree": "gaho", "tier": 3, "name": "용왕의 눈", "live": false,
		"desc": "보스의 수를 0.5초 먼저 읽고, 약점이 보인다."},
	{"id": "haemu", "tree": "gaho", "tier": 3, "name": "해무", "live": false,
		"desc": "싸움마다 한 번, 3초간 안개에 숨어 요괴의 눈을 떨군다."},
	{"id": "deungyong", "tree": "gaho", "tier": 4, "name": "등용문", "live": false,
		"desc": "싸움마다 한 번, 쓰러져도 체력 절반으로 일어선다."},
]


static func get_skill(id: String) -> Dictionary:
	for s in LIST:
		if s["id"] == id:
			return s
	return {}


static func of_tree(tree: String) -> Array:
	return LIST.filter(func(s): return s["tree"] == tree)


static func tree_open(tree: String) -> bool:
	return tree != "gaho" or Game.flag("gaho")


static func learned_in(tree: String, tier: int) -> int:
	var n := 0
	for s in of_tree(tree):
		if s["tier"] == tier and s["id"] in Game.skills:
			n += 1
	return n


## "" when it can be learned now, otherwise the reason it can't
static func why_not(id: String) -> String:
	var s := get_skill(id)
	if s.is_empty():
		return "없는 수"
	if id in Game.skills:
		return "이미 익혔소"
	if not tree_open(s["tree"]):
		return "용왕의 힘이 아직 닿지 않소 (4장)"
	if not s["live"]:
		return "아직 깨닫지 못한 수요 (후일)"
	var tier: int = s["tier"]
	if NEED.has(tier):
		var nd: Array = NEED[tier]
		if learned_in(s["tree"], nd[0]) < nd[1]:
			return "%s 수를 %d개 먼저 익혀야 하오" % [TIER_NAME[nd[0]], nd[1]]
	if Game.skill_points < COST[tier]:
		return "수련 점수가 모자라오 (%d점)" % COST[tier]
	return ""


static func learn(id: String) -> bool:
	if why_not(id) != "":
		return false
	Game.skill_points -= COST[get_skill(id)["tier"]]
	Game.skills.append(id)
	Game.skills_changed.emit()
	Game.save()
	return true
