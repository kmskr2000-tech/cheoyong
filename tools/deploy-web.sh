#!/usr/bin/env bash
# Godot 웹 빌드를 gh-pages 브랜치로 배포한다 (ADR-0002).
#  - 빌드 산출물은 main에 넣지 않는다. gh-pages는 매번 고아 커밋 1개로 새로 만든다(히스토리 누적 없음, force push 없이 ref 삭제 후 push).
#  - 구조: / (loader: version.json을 no-store로 읽고 ./<버전>/ 으로 이동), /<버전>/ (Godot 빌드), /legacy-web/ (옛 웹판)
#  - 사용: tools/deploy-web.sh [--dry]   (--dry: 조립만 하고 staging 경로 출력)
set -euo pipefail
GODOT="${GODOT:-$HOME/workspace/tools/godot-4.4.1/Godot_v4.4.1-stable_linux.x86_64}"
REPO="${REPO:-kmskr2000-tech/cheoyong}"
ROOT="$(git rev-parse --show-toplevel)"
V="$(date +%Y%m%d%H%M%S)"
STAGE="$(mktemp -d)"
cd "$ROOT"
rm -rf build/web && mkdir -p build/web
"$GODOT" --headless --path src --import >/dev/null 2>&1 || true
"$GODOT" --headless --path src --export-release Web ../build/web/index.html >/dev/null 2>&1
[ -s build/web/index.wasm ] && [ -s build/web/index.pck ] || { echo "빌드 실패: index.wasm/pck 없음" >&2; exit 1; }
mkdir -p "$STAGE/$V"
cp build/web/* "$STAGE/$V/"
cp -r legacy-web "$STAGE/legacy-web"
printf '{"v":"%s"}\n' "$V" > "$STAGE/version.json"
touch "$STAGE/.nojekyll"
cat > "$STAGE/index.html" <<HTML
<!doctype html>
<html lang="ko"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1, user-scalable=no">
<title>신 처용가</title>
<style>html,body{margin:0;height:100%;background:#05060c;color:#ccd;font:16px sans-serif;display:flex;align-items:center;justify-content:center}a{color:#e8c870}</style></head>
<body><p id="m">불러오는 중…</p>
<script>
// 항상 최신 버전 폴더로 보낸다 (version.json은 no-store). 실패 시 이 배포 시점 버전으로 폴백.
var FALLBACK="$V";
function go(v){location.replace("./"+v+"/"+location.search+location.hash);}
fetch("version.json?t="+Date.now(),{cache:"no-store"}).then(function(r){return r.json()}).then(function(j){go(j.v)}).catch(function(){go(FALLBACK)});
</script>
<noscript><p><a href="./$V/">게임 열기</a></p></noscript></body></html>
HTML
echo "staging: $STAGE (version $V, $(du -sh "$STAGE" | cut -f1))"
[ "${1:-}" = "--dry" ] && exit 0
cd "$STAGE"
git init -q -b gh-pages
git add -A
git -c user.name="$(git -C "$ROOT" config user.name)" -c user.email="$(git -C "$ROOT" config user.email)" commit -q -m "deploy $V"
gh api -X DELETE "repos/$REPO/git/refs/heads/gh-pages" >/dev/null 2>&1 || true
git push -q "https://github.com/$REPO.git" gh-pages
echo "pushed gh-pages ($V)"
