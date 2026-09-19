#!/bin/sh
# assert-promotable.tests.sh — .github/scripts/assert-promotable.sh の単体テスト（exit 0 が全緑）。
# 🚨 判定器は subprocess として起動する（workflow が呼ぶのと同じ経路）。陰性対照を必ず対で置く。
set -eu
here=$(cd "$(dirname "$0")" && pwd)
target="$here/../assert-promotable.sh"
[ -f "$target" ] || { echo "判定器が無い: $target" >&2; exit 1; }
pass=0; fail=0
ok() { _l=$1; shift; if sh "$target" "$@" >/dev/null 2>&1; then pass=$((pass+1)); else printf 'FAIL(合格するはずが落ちた): %s\n' "$_l" >&2; fail=$((fail+1)); fi; }
ng() { _l=$1; shift; if sh "$target" "$@" >/dev/null 2>&1; then printf 'FAIL(落ちるはずが合格した): %s\n' "$_l" >&2; fail=$((fail+1)); else pass=$((pass+1)); fi; }

ok '陽性対照: pre-release の build-<sha7> は昇格できる'   build-1d3c7a0 true
ng '陰性対照: 既に GA の物は昇格しない'                   build-1d3c7a0 false
ng '測れていない（空）は昇格しない'                       build-1d3c7a0 ''
ng '測れていない（想定外の値）は昇格しない'               build-1d3c7a0 null
ng 'タグが空'                                             '' true
ng 'mac- の pre-release は GA にしない'                   mac-1d3c7a0 true
ng '短い sha'                                             build-1d3c7a true
ng '大文字の sha'                                         build-1D3C7A0 true
ng '余計な接尾辞'                                         build-1d3c7a0-x true

printf 'assert-promotable: %s passed, %s failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
