"""현황판(board 스킬)용 에셋 기록: godot/assets 의 그림마다 art/_gen/<이름>/asset.json 을 남긴다.

board.py 는 기록이 있고 그 파일이 게임에 들어 있으면 '됨'으로 센다 (소리는 기록 없이도 센다).
그림을 새로 만들면 이 스크립트를 다시 돌린다. 노멀맵·발광·물 마스크 같은 부속 파일은 세지 않는다.
"""
import json, pathlib

ROOT = pathlib.Path(__file__).parent.parent
ASSETS = ROOT / 'godot' / 'assets'
GEN = ROOT / 'art' / '_gen'
KIND = {  # 폴더 → (종류, 만든 스크립트)
    'sprites': ('스프라이트', 'art/build.py · art/enemies.py · art/monsters.py'),
    'props': ('소품', 'art/vox.py · art/props.py'),
    'levels': ('지형', 'art/ground3d.py'),
    'intro': ('인트로·타이틀 그림', 'art/intro.py'),
    'ui': ('UI', 'art/ui.py'),
    'fx': ('이펙트', 'art/fx.py'),
}
SKIP = ('_n', '_glow', '_water')


def main():
    n = 0
    for folder, (kind, made) in KIND.items():
        for p in sorted((ASSETS / folder).glob('*.png')):
            if p.stem.endswith(SKIP):
                continue
            d = GEN / p.stem
            d.mkdir(parents=True, exist_ok=True)
            rec = {'out': str(p.relative_to(ROOT)), 'kind': kind, 'made': made}
            (d / 'asset.json').write_text(json.dumps(rec, ensure_ascii=False, indent=1))
            n += 1
    print(f'board records: {n}')


if __name__ == '__main__':
    main()
