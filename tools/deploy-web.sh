#!/usr/bin/env bash
# Godot 웹 빌드를 gh-pages 브랜치로 배포한다 (ADR-0002).
#  - 빌드 산출물은 main에 넣지 않는다. gh-pages는 매번 고아 커밋 1개로 새로 만든다(히스토리 누적 없음, force push 없이 ref 삭제 후 push).
#  - 구조: / (loader: version.json을 no-store로 읽고 ./<버전>/ 으로 이동), /<버전>/ (Godot 빌드), /legacy-web/ (옛 웹판)
#  - PWA(서비스 워커)는 버전 폴더 범위(/<버전>/)에만 걸린다 -> 루트 로더·version.json은 캐시 영향 없음. 상세: ADR-0002 부록.
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
# PWA 매니페스트 시작 주소를 루트 로더로 돌린다. 기본값(./index.html)이면 홈 화면에 추가한 앱이 그 버전 폴더에 영원히 고정된다.
python3 - "$STAGE/$V/index.manifest.json" <<'PY'
import json, sys
p = sys.argv[1]
m = json.load(open(p))
m["start_url"] = "../"
m["scope"] = "../"
json.dump(m, open(p, "w"), ensure_ascii=False)
PY
cp -r legacy-web "$STAGE/legacy-web"
printf '{"v":"%s"}\n' "$V" > "$STAGE/version.json"
touch "$STAGE/.nojekyll"
cat > "$STAGE/index.html" <<'HTML'
<!doctype html>
<html lang="ko"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1, user-scalable=no">
<meta name="theme-color" content="#05060c">
<link rel="icon" href="data:,">
<title>신 처용가</title>
<style>html,body{margin:0;height:100%;background:#05060c;color:#ccd;font:16px sans-serif;display:flex;align-items:center;justify-content:center}a{color:#e8c870}</style></head>
<body><p id="m">불러오는 중…</p>
<script>
// 항상 최신 버전 폴더로 보낸다 (version.json은 no-store). 이 루트 페이지는 서비스 워커 범위 밖이라 캐시에 막히지 않는다.
// 오프라인/장애 시: 마지막으로 성공한 버전 -> 이 배포 시점 버전 순으로 폴백.
var FALLBACK="__V__", LS="cheoyong.lastV";
function last(){try{return localStorage.getItem(LS)}catch(e){return null}}
function go(v){try{localStorage.setItem(LS,v)}catch(e){} location.replace("./"+v+"/"+location.search+location.hash);}
// 구버전 폴더에 남은 서비스 워커 등록을 정리한다(캐시는 새 버전 SW가 활성화될 때 Godot가 지움).
function cleanup(v){
  if(!navigator.serviceWorker||!navigator.serviceWorker.getRegistrations) return Promise.resolve();
  var p=navigator.serviceWorker.getRegistrations().then(function(rs){return Promise.all(rs.filter(function(r){var b=location.pathname.replace(/[^\/]*$/,"");return r.scope.indexOf(location.origin+b)===0&&/\/\d{14}\/$/.test(r.scope)&&r.scope.indexOf("/"+v+"/")<0}).map(function(r){return r.unregister()}))}).catch(function(){});
  return Promise.race([p,new Promise(function(r){setTimeout(r,1000)})]);
}
var ctl=window.AbortController?new AbortController():null, tm=setTimeout(function(){ctl&&ctl.abort()},4000);
fetch("version.json?t="+Date.now(),{cache:"no-store",signal:ctl?ctl.signal:undefined}).then(function(r){return r.json()}).then(function(j){clearTimeout(tm);if(!/^\d{14}$/.test(j.v))throw 0;return cleanup(j.v).then(function(){go(j.v)})}).catch(function(){go(last()||FALLBACK)});
</script>
<noscript><p><a href="./__V__/">게임 열기</a></p></noscript></body></html>
HTML
sed -i "s/__V__/$V/g" "$STAGE/index.html"
# 삭제된 구버전 폴더 주소(북마크 등)로 들어오면 404 대신 루트 로더로 보낸다.
cat > "$STAGE/404.html" <<'HTML404'
<!doctype html><meta charset="utf-8"><title>신 처용가</title><script>
var m=location.pathname.match(/^(.*\/)\d{14}\//);location.replace(m?m[1]+location.search+location.hash:location.pathname.replace(/[^\/]*$/,""));
</script>
HTML404
echo "staging: $STAGE (version $V, $(du -sh "$STAGE" | cut -f1))"
[ "${1:-}" = "--dry" ] && exit 0
cd "$STAGE"
git init -q -b gh-pages
git add -A
git -c user.name="$(git -C "$ROOT" config user.name)" -c user.email="$(git -C "$ROOT" config user.email)" commit -q -m "deploy $V"
gh api -X DELETE "repos/$REPO/git/refs/heads/gh-pages" >/dev/null 2>&1 || true
git push -q "https://github.com/$REPO.git" gh-pages
echo "pushed gh-pages ($V)"
