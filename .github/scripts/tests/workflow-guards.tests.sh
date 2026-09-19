#!/bin/sh
# workflow-guards.tests.sh — 「GA を作る経路は promote-release.yml の dispatch 1 本だけ」を workflow の文面で固定する。
# （板 #936 系統⑤③・n=1805）exit 0 が全緑。陽性対照（直した現物が通る）と陰性対照（危ない形に戻すと落ちる）を対で置く。
set -eu
here=$(cd "$(dirname "$0")" && pwd)
wf="$here/../../workflows"
pass=0; fail=0

# 判定: build-release.yml の `gh release create` は pre-release・Latest にしない。`--latest`（=true）を渡さない
check_build() {
    f=$1
    block=$(awk '/gh release create/{p=1} p{print} p&&!/\\$/{p=0}' "$f")
    [ -n "$block" ] || return 1
    printf '%s\n' "$block" | grep -q -- '--prerelease' || return 1
    printf '%s\n' "$block" | grep -q -- '--latest=false' || return 1
    ! printf '%s\n' "$block" | grep -Eq -- '--latest([[:space:]]|\\|$)' || return 1
    ! grep -Eq 'gh release edit[^#]*--latest' "$f" || return 1
    return 0
}
# 判定: promote-release.yml は workflow_dispatch だけで起動する
check_promote() {
    f=$1
    on=$(awk '/^on:/{p=1;next} p&&/^[a-z]/{p=0} p{print}' "$f")
    printf '%s\n' "$on" | grep -q 'workflow_dispatch:' || return 1
    ! printf '%s\n' "$on" | grep -Eq '^[[:space:]]+(schedule|push|pull_request|pull_request_target|workflow_run|release):' || return 1
    return 0
}
ok() { _l=$1; shift; if "$@"; then pass=$((pass+1)); else printf 'FAIL(合格するはずが落ちた): %s\n' "$_l" >&2; fail=$((fail+1)); fi; }
ng() { _l=$1; shift; if "$@"; then printf 'FAIL(落ちるはずが合格した): %s\n' "$_l" >&2; fail=$((fail+1)); else pass=$((pass+1)); fi; }

ok '陽性対照: build-release.yml は pre-release しか作らない' check_build "$wf/build-release.yml"
ok '陽性対照: promote-release.yml は dispatch だけ'          check_promote "$wf/promote-release.yml"

tmp=$(mktemp -d); trap 'rm -rf "$tmp"' EXIT
sed 's/--latest=false/--latest/' "$wf/build-release.yml" > "$tmp/b1.yml"
ng '陰性対照: --latest（自動 GA）に戻すと落ちる'            check_build "$tmp/b1.yml"
grep -v -- '--prerelease \\' "$wf/build-release.yml" > "$tmp/b2.yml"
ng '陰性対照: --prerelease を外すと落ちる'                  check_build "$tmp/b2.yml"
awk '{print} /^  workflow_dispatch:/{print "  schedule:"; print "    - cron: '"'"'0 0 * * *'"'"'"}' "$wf/promote-release.yml" > "$tmp/p1.yml"
ng '陰性対照: promote に schedule を足すと落ちる'           check_promote "$tmp/p1.yml"

printf 'workflow-guards: %s passed, %s failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
