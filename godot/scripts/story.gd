extends Node
## Story beats (autoload "Story"): what happens when a level opens and when the hero talks to /
## examines something. Lines follow docs/story-bible.md (말투 ~하오, 처용은 짧게).

const CHEO := "처용"

## per-NPC lines for 경주 일상 (SC1-10 생활 대사); later chapters key off Game flags
const TALK := {
	"nanyeong": [{"name": "난영", "text": "처음 보시는 얼굴이오. 약재는 무슨 병에 쓰시오?"}],
	"apothecary": [{"name": "약방 주인", "text": "요즘 역병 때문에 약재가 동이 났소."}],
	"elder": [{"name": "촌주", "text": "서쪽 폐가에는 가지 말게. 들어간 사람이 못 나왔어."}],
	"villagerA": [{"name": "아낙", "text": "밤마다 기침 소리가 담을 넘어오오. 문을 꼭 걸어 두시오."}],
	"villagerB": [{"name": "나무꾼", "text": "산에 들면 나무가 검게 젖어 있소. 비도 안 왔는데 말이오."}],
	"villagerC": [{"name": "기침하는 사내", "text": "콜록… 괜찮소. 그냥… 감기요."}],
	"board": [{"text": "방(榜): 역병이 도니 해 진 뒤 바깥 출입을 삼가라. — 관아"}],
}


func on_enter(_level: Node) -> void:
	pass


func interact(level: Node, id: String) -> void:
	var lines: Array = TALK.get(id, [{"text": "…"}])
	await level.talk(lines)
