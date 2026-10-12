#!/usr/bin/env bash
# 세이브 견고성 검사 (헤드리스). 사용: GODOT=/path/to/godot tests/save_check.sh
# 임시 XDG_DATA_HOME을 써서 실제 user:// 세이브를 건드리지 않는다.
set -u
GODOT="${GODOT:-$HOME/workspace/tools/godot-4.4.1/Godot_v4.4.1-stable_linux.x86_64}"
HERE="$(cd "$(dirname "$0")/.." && pwd)"
TMP="$(mktemp -d)"
fail=0
# 픽스처 키가 현재(원본 v1) 저장 필드와 일치하는지: HEAD 이전 형식의 save() 키 목록과 비교
keys_code=$(python3 - "$HERE" <<'PY'
import re,sys,json
src=open(sys.argv[1]+"/src/scripts/game.gd").read()
m=re.search(r'const SAVE_DEFAULTS := \{(.*?)\n\}',src,re.S)
body=re.sub(r'\{[^{}]*\}','{}',m.group(1))
print(" ".join(sorted(re.findall(r'"([a-z_]+)":',body))))
PY
)
keys_fx=$(python3 -c "import json,sys;print(' '.join(sorted(json.load(open(sys.argv[1]+'/tests/fixtures/save_v0.json')))))" "$HERE")
if [ "$keys_code" = "$keys_fx" ]; then echo "PASS fixture keys == SAVE_DEFAULTS keys"; else echo "FAIL fixture keys differ: code=[$keys_code] fixture=[$keys_fx]"; fail=1; fi
export SAVE_FIXTURES="$HERE/tests/fixtures"
export XDG_DATA_HOME="$TMP/data"
mkdir -p "$XDG_DATA_HOME"
timeout 120 "$GODOT" --headless --path "$HERE/src" --script "$HERE/tests/save_check.gd" >"$TMP/out.log" 2>&1
rc=$?
grep -E "^(PASS|FAIL)" "$TMP/out.log"
if grep -qE "SCRIPT ERROR|Parse Error" "$TMP/out.log"; then echo "FAIL script errors:"; grep -E "SCRIPT ERROR|Parse Error" "$TMP/out.log" | head -5; fail=1; fi
[ $rc -ne 0 ] && fail=1
npass=$(grep -c "^PASS" "$TMP/out.log"); nfail=$(grep -c "^FAIL" "$TMP/out.log")
[ "$npass" -eq 0 ] && fail=1
if [ $fail -eq 0 ]; then echo "SAVE_CHECK PASS ($npass checks)"; else echo "SAVE_CHECK FAIL (rc=$rc, fail lines=$nfail)"; echo "log: $TMP/out.log"; fi
exit $fail
