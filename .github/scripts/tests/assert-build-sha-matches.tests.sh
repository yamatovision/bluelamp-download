#!/bin/sh
# assert-build-sha-matches.tests.sh — .github/scripts/assert-build-sha-matches.sh の単体テスト。
#
# bats にも他のフレームワークにも依存しない（release-verdict.tests.sh と同じ流儀）。exit 0 が全緑。
# 🚨 判定器は **subprocess として起動する**（workflow が呼ぶのと同じ経路）。source して関数を
#    呼ぶ形にすると「script として起動したときの引数の受け取り」を 1 度も測らないまま緑になる。
# 🚨 陰性対照（落ちるべきものが落ちる）を必ず対で置く。合格側だけ書くと
#    「常に 0 を返す script」がテストを通ってしまう。
#
# 使い方: sh .github/scripts/tests/assert-build-sha-matches.tests.sh
set -eu

here=$(cd "$(dirname "$0")" && pwd)
target="$here/../assert-build-sha-matches.sh"
[ -f "$target" ] || { echo "判定器が無い: $target" >&2; exit 1; }

pass=0
fail=0

ok() {  # 合格するはず
    _label=$1
    shift
    if sh "$target" "$@" >/dev/null 2>&1; then
        pass=$((pass + 1))
    else
        printf 'FAIL(合格するはずが落ちた): %s\n' "$_label" >&2
        fail=$((fail + 1))
    fi
}

ng() {  # 落ちるはず
    _label=$1
    shift
    if sh "$target" "$@" >/dev/null 2>&1; then
        printf 'FAIL(落ちるはずが通った): %s\n' "$_label" >&2
        fail=$((fail + 1))
    else
        pass=$((pass + 1))
    fi
}

A='0123456789abcdef0123456789abcdef01234567'
B='fedcba9876543210fedcba9876543210fedcba98'

# --- 陽性対照: 同じ full SHA なら通る -------------------------------------
ok '同一の full SHA は通る'            "$A" "$A"
ok '別の値でも同一同士なら通る'        "$B" "$B"

# --- 本丸: run 33308043796 の再現（check と build が別 commit）------------
ng '別 commit なら落ちる（出荷物と記録の食い違い）' "$A" "$B"

# --- 短縮 SHA は「測れていない」に倒す ------------------------------------
# 🚨 sha7 同士が一致しても同一 commit の証明にはならない。合格に倒さない。
ng 'sha7 同士は落ちる'                 '0123456' '0123456'
ng 'check 側だけ sha7 なら落ちる'      '0123456' "$A"
ng 'build 側だけ sha7 なら落ちる'      "$A" '0123456'
ng '41 桁は落ちる'                     "${A}0" "${A}0"
ng '39 桁は落ちる'                     "${A%?}" "${A%?}"

# --- 読めない値を黙って合格に倒さない --------------------------------------
ng '大文字 hex は落ちる（git は小文字を出す）' \
   '0123456789ABCDEF0123456789ABCDEF01234567' '0123456789ABCDEF0123456789ABCDEF01234567'
ng 'hex でない 40 文字は落ちる'        'zzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz' 'zzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz'
ng '空同士は落ちる（空 == 空 を合格にしない）' '' ''
ng '第 1 引数が空なら落ちる'           '' "$A"
ng '第 2 引数が空なら落ちる'           "$A" ''
ng '引数なしは落ちる'
ng '引数 1 つは落ちる'                 "$A"
ng '前後の空白付きは落ちる'            " $A" "$A "

printf '\nassert-build-sha-matches: %d passed, %d failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ] || exit 1
