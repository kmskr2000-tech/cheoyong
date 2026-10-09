class_name Bestiary
## 요괴 도감 (docs/growth-system.md §5): every purifiable kind with its family (퇴치향 계열), tier and one line
## from the folklore it comes from. Rewards for purifying it follow its tier.

const TIERS := {
	# 정기 [min, max], 덕망 [min, max], 엽전 [min, max], 재료 확률
	"normal": {"jeonggi": [5, 15], "deok": [18, 26], "money": [1, 4], "mat": 0.35},
	"elite": {"jeonggi": [30, 50], "deok": [80, 90], "money": [10, 16], "mat": 1.0},
	"boss": {"jeonggi": [200, 200], "deok": [360, 360], "money": [50, 50], "mat": 1.0},
}

## family → the material its purified 탁기 leaves behind (퇴치향·부적 재료)
const MATERIALS := {
	"역병": "탁한 종기",
	"귀신": "원혼의 머리카락",
	"물": "물비린 해초",
	"도깨비": "도깨비 털",
	"산": "산짐승의 송곳니",
	"여우": "여우 털",
	"용": "비늘 조각",
	"저승": "저승의 재",
}

const ENTRIES := {
	"dog": {"name": "역병 들개", "family": "역병", "tier": "normal",
		"lore": "역병이 돌면 개가 먼저 미쳐 날뛴다는 옛사람들의 두려움에서 나왔다."},
	"ghoul": {"name": "역귀", "family": "역병", "tier": "normal",
		"lore": "『삼국유사』 처용랑 설화의 역신(疫神)을 따라다니는 잡귀."},
	"sea": {"name": "갯귀", "family": "물", "tier": "normal",
		"lore": "바다에 빠져 죽은 이의 넋이 해초와 따개비에 엉겨 갯가를 떠돈다."},
	"mama": {"name": "마마귀신", "family": "역병", "tier": "elite",
		"lore": "천연두를 '손님'이라 높여 부르며 손님굿으로 달래 보낸 호구별성."},
	"egg_ghost": {"name": "달걀귀신", "family": "귀신", "tier": "normal",
		"lore": "눈도 코도 입도 없는 달걀 같은 얼굴 — 민담에 널리 전하는 얼굴 없는 귀신."},
	"maiden_ghost": {"name": "처녀귀신", "family": "귀신", "tier": "normal",
		"lore": "혼인하지 못하고 죽은 처녀의 원혼(손말명). 가장 한이 깊다고 여겼다."},
	"mulgwi": {"name": "물귀신", "family": "물", "tier": "normal",
		"lore": "물에 빠져 죽은 혼이 산 사람을 끌어들여 제 대신으로 삼는다는 믿음."},
	"dokkaebi_oneeye": {"name": "외눈박이 도깨비", "family": "도깨비", "tier": "normal",
		"lore": "쓰면 모습이 사라진다는 도깨비감투 이야기의 주인."},
	"dokkaebi_fire": {"name": "불도깨비", "family": "도깨비", "tier": "normal",
		"lore": "밤 들판에 떠도는 푸른 도깨비불이 몸을 얻은 것."},
	"jangsanbeom": {"name": "장산범", "family": "산", "tier": "elite",
		"lore": "장산에 산다는 흰 털의 괴수. 사람 목소리를 흉내 내어 홀린다."},
	"sangun": {"name": "산군", "family": "산", "tier": "normal",
		"lore": "호랑이를 산의 임금이라 높여 부른 이름. 산신의 사자."},
	"fox_minion": {"name": "여우 졸개", "family": "여우", "tier": "normal",
		"lore": "천 년 묵은 여우가 사람으로 둔갑한다는 구미호 설화의 권속."},
	"songaksi": {"name": "손각시", "family": "귀신", "tier": "elite",
		"lore": "시집 못 가고 죽은 처녀 귀신의 다른 이름. 신부의 모습으로 나타난다."},
	"jangseung_taki": {"name": "오염된 장승", "family": "역병", "tier": "normal",
		"lore": "마을 어귀에서 잡귀를 막던 천하대장군·지하여장군이 탁기에 물들었다."},
	"haetae": {"name": "해태", "family": "용", "tier": "elite",
		"lore": "시비선악을 가리고 불을 먹어 화재를 막는다는 신수."},
	"eodukssini": {"name": "어둑시니", "family": "귀신", "tier": "normal",
		"lore": "어둠 속에 나타나 바라볼수록 커지고, 내려다보면 작아진다는 요괴."},
	"pado": {"name": "파도 요괴", "family": "용", "tier": "normal",
		"lore": "탁해진 바다의 노여움이 물마루에 얼굴을 얻었다."},
	"mangja": {"name": "망자", "family": "저승", "tier": "normal",
		"lore": "저승길을 건너지 못하고 무리 지어 떠도는 원혼."},
	"bulgae": {"name": "불개", "family": "저승", "tier": "elite",
		"lore": "까막나라 임금의 명으로 해와 달을 물어뜯어 일식·월식을 일으킨다는 불개."},
	"jeoseung_guard": {"name": "저승 파수꾼", "family": "저승", "tier": "normal",
		"lore": "산 자와 죽은 자의 경계, 저승 문을 지키는 장수."},
	"plague_god": {"name": "역신", "family": "역병", "tier": "boss",
		"lore": "처용의 아내를 범하려다 처용가에 감복해 물러갔다 — 『삼국유사』 처용랑 망해사조."},
}


static func entry(kind: String) -> Dictionary:
	return ENTRIES.get(kind, {"name": kind, "family": "역병", "tier": "normal", "lore": ""})
