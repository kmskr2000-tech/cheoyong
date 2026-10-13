"""임시 미리보기 패치(커밋 대상 아님 — 프로그래밍팀이 levels.gd 를 교체할 때의 참고용 사본).
prog/ch2-m2 worktree 의 levels.gd(old_village·den1·den2·den3)·level.gd(OCCLUDE)·walkability.gd(ROUTES/LIVE)를 아트 제안 좌표로 바꿔
실제 godot 걷기 검증·캡처를 돌리는 데 쓴다.  사용: python3 preview_patch.py <prog/ch2-m2 worktree 루트> <아트 worktree 루트>
"""
import sys, re, pathlib
verify, art = pathlib.Path(sys.argv[1]), pathlib.Path(sys.argv[2])
sys.path.insert(0, str(art / 'art'))
import ch2m2_markers as MK

K = 0.75
V = lambda x, y: f'Vector2({x}, {y})'


def mk(name):
    return {m[1]: (m[2], m[3]) for m in MK.MARKERS[name]}


def props(name, light):
    out = []
    for kind, x, y in MK.PROPS[name]:
        if kind == 'dok_torch':
            out.append(f'["{kind}", {x}, {y}, [-46, GHOSTFIRE, 0.8, 0.9]]')
        elif kind == 'mortar_altar':
            out.append(f'["{kind}", {x}, {y}, [-36, GHOSTFIRE, 1.0, 1.4]]')
        else:
            out.append(f'["{kind}", {x}, {y}, null]')
    return '[' + ', '.join(out) + ']'


def enemies(name, kinds):
    m = mk(name)
    return '[' + ', '.join(f'["{k}", {m[l][0]}, {m[l][1]}]' for l, k in kinds) + ']'


ov, d1, d2, d3 = mk('old_village'), mk('den1'), mk('den2'), mk('den3')
txt = f'''	# ===== 2장 M2 (아트 제안 좌표 미리보기 — production/qa/asset-import/ch2-m2/README.md)
	"old_village": {{
		"music": "dread", "amb": "wind",
		"name": "버려진 마을",
		"ground": "old_village",
		"ambient": Color(0.34, 0.36, 0.54),
		"spawns": {{"start": {V(*ov['fromPath'])}, "fromPath": {V(*ov['fromPath'])}}},
		"props": {props('old_village', 0)},
		"lights": [[300, 60, GHOSTFIRE, 0.6, 0.6], [425, 205, GHOSTFIRE, 0.6, 0.6], [695, 165, GHOSTFIRE, 0.6, 0.6], [188, 8, GHOSTFIRE, 0.5, 0.5], [300, 255, GHOSTFIRE, 0.5, 0.5]],
		"npcs": [["girl_soul", "npc_ghost", {ov['girl_soul'][0]}, {ov['girl_soul'][1]}, "빈집의 넋"]],
		"interact": [["grave", {ov['grave'][0]}, {ov['grave'][1]}, "무덤"]],
		"enemies": {enemies('old_village', [('fire1', 'dokkaebi_fire'), ('fire2', 'dokkaebi_fire'), ('fire3', 'dokkaebi_fire'), ('oneeye', 'dokkaebi_oneeye')])},
		"exits": [[Rect2(618, 350, 90, 8), "jiri_path", "fromVillage"]],
		"anchors": {{"doll": {V(*ov['doll'])}, "grave": {V(*ov['grave'])}, "exit": {V(650, 352)}}},
	}},
	"den1": {{
		"music": "dread", "amb": "wind",
		"name": "도깨비 소굴 외곽",
		"ground": "den1",
		"ambient": Color(0.34, 0.33, 0.50),
		"spawns": {{"start": {V(*d1['start'])}, "fromDen2": {V(*d1['fromDen2'])}}},
		"props": {props('den1', 0)},
		"lights": [[110, 175, GHOSTFIRE, 0.7, 0.6], [550, 250, GHOSTFIRE, 0.6, 0.6], [700, 285, GHOSTFIRE, 0.6, 0.6], [260, 185, GHOSTFIRE, 0.4, 0.5]],
		"npcs": [], "interact": [],
		"enemies": {enemies('den1', [('oneeye_A', 'dokkaebi_oneeye'), ('oneeye_B1', 'dokkaebi_oneeye'), ('fire_B1', 'dokkaebi_fire'), ('oneeye_alcove', 'dokkaebi_oneeye'), ('fire_B2', 'dokkaebi_fire'), ('sangun', 'sangun'), ('jangseung', 'jangseung_taki')])},
		"vents": [Vector2(160, 181), Vector2(430, 60), Vector2(640, 200)],
		"triggers": [[Rect2(160, 160, 60, 40), "sight"], [Rect2(715, 170, 50, 60), "deep"]],
		"exits": [[Rect2(0, 164, 6, 34), "jiri_path", "fromDen"], [Rect2(778, 180, 8, 40), "den2", "start"]],
		"anchors": {{"exit": {V(770, 200)}}},
	}},
	"den2": {{
		"music": "dread", "amb": "wind",
		"name": "도깨비 곳간",
		"ground": "den2",
		"ambient": Color(0.34, 0.33, 0.50),
		"spawns": {{"start": {V(*d2['start'])}, "fromDen3": {V(*d2['fromDen3'])}}},
		"props": {props('den2', 0)},
		"lights": [[320, 200, GHOSTFIRE, 0.7, 0.7], [210, 150, GHOSTFIRE, 0.5, 0.5], [430, 150, GHOSTFIRE, 0.5, 0.5]],
		"npcs": [], "interact": [],
		"enemies": {enemies('den2', [('jangsanbeom', 'jangsanbeom'), ('oneeye1', 'dokkaebi_oneeye'), ('oneeye2', 'dokkaebi_oneeye'), ('fire', 'dokkaebi_fire')])},
		"exits": [[Rect2(0, 176, 6, 48), "den1", "fromDen2"], [Rect2(628, 176, 8, 48), "den3", "start"]],
		"anchors": {{"door": Rect2(446, 170, 14, 60), "exit": {V(610, 200)}}},
	}},
	"den3": {{
		"music": "dread", "amb": "",
		"name": "두억시니의 방",
		"ground": "den3",
		"ambient": Color(0.34, 0.33, 0.50),
		"spawns": {{"start": {V(*d3['start'])}}},
		"props": {props('den3', 0)},
		"lights": [[320, 190, GHOSTFIRE, 0.9, 1.0], [70, 110, GHOSTFIRE, 0.5, 0.6], [570, 110, GHOSTFIRE, 0.5, 0.6]],
		"npcs": [], "interact": [],
		"enemies": [],
		"triggers": [[Rect2(70, 170, 40, 60), "gate"]],
		"exits": [[Rect2(0, 176, 6, 48), "den2", "fromDen3"]],
		"anchors": {{"door": Rect2(26, 170, 16, 60), "hall": {V(*d3['dueoksini'])}, "exit": {V(14, 200)}}},
	}},
}}
'''
p = verify / 'src/scripts/levels.gd'
s = p.read_text()
i = s.index('\t# ===== 2장 마일스톤 2')
p.write_text(s[:i] + txt)
# OCCLUDE
p = verify / 'src/scripts/level.gd'
s = p.read_text()
add = '"hut_ruin": Vector2(40, 16), "hut_ruin_b": Vector2(40, 16), "old_tools": Vector2(14, 5), "old_tools_mortar": Vector2(10, 4), "old_tools_broom": Vector2(3, 2), "old_tools_pot": Vector2(11, 4), "old_tools_sandals": Vector2(8, 3), "dok_torch": Vector2(4, 3), "mortar_altar": Vector2(30, 12), "doll": Vector2(3, 3), '
s = s.replace('"rockwall": Vector2(32, 20),', add + '"rockwall": Vector2(32, 20),', 1)
p.write_text(s)
# walkability ROUTES / LIVE
p = verify / 'tests/godot/walkability.gd'
s = p.read_text()
rep = {k: '[' + ', '.join(V(*pt) for pt in v) + ']' for k, v in MK.ROUTES.items()}
for k, v in rep.items():
    s = re.sub(r'(\t"%s": )\[[^\n]*\],\n' % k, lambda m: f'{m.group(1)}{v},\n', s, count=1)
for k in ('old_village:start', 'den1:start', 'den1:fromDen2', 'den2:start', 'den2:fromDen3', 'den3:start'):
    s = re.sub(r'(\t"%s": )\[[^\n]*\],\n' % re.escape(k), lambda m: f'{m.group(1)}[],\n', s, count=1)
p.write_text(s)
print('patched')
