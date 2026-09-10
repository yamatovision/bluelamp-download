#!/bin/sh
# select-mac-release.tests.sh — .github/scripts/select-mac-release.sh の単体テスト。
#
# bats にも他のフレームワークにも依存しない（release-verdict.tests.sh と同じ流儀）。exit 0 が全緑。
# 🚨 判定器は **subprocess として起動する**（workflow が呼ぶのと同じ経路）。
# 🚨 陰性対照（落ちるべきものが落ちる）を必ず対で置く。
#
# 使い方: sh .github/scripts/tests/select-mac-release.tests.sh
set -eu

here=$(cd "$(dirname "$0")" && pwd)
target="$here/../select-mac-release.sh"
[ -f "$target" ] || { echo "判定器が無い: $target" >&2; exit 1; }

pass=0
fail=0

eq() {  # 出力が期待どおりか（合格して、かつ選んだものが正しいか）
    _label=$1; _want=$2; shift 2
    if _got=$(sh "$target" "$@" 2>/dev/null); then
        if [ "$_got" = "$_want" ]; then
            pass=$((pass + 1))
        else
            printf 'FAIL(選んだものが違う): %s\n  期待: %s\n  実際: %s\n' "$_label" "$_want" "$_got" >&2
            fail=$((fail + 1))
        fi
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

# ============================================================================
# 🚨 回帰の標本: 2026-09-10 に実配布で起きた取り違えそのもの。
#    `createdAt` が同値（どちらも 2026-08-31T12:22:55Z＝同じ commit を指すタグ）だったため
#    並べ替えが効かず、**9 日前の mac-0ae7e11 が先頭に来て GA に載った**。
#    ⇒ publishedAt から出した経過日数（0 日 / 9 日）を渡せば、必ず新しいほうが選ばれること。
#    ⛔ 「先に来たほう」に左右されないことを、**並び順を入れ替えた 2 本**で示す。
# ============================================================================
OLD='mac-0ae7e11 9'
NEW='mac-abd434b 0'

eq '🚨回帰: 古いものが先頭でも新しいほうを選ぶ' 'mac-abd434b 0 same-sha7' \
   "$OLD
$NEW" abd434b
eq '🚨回帰: 並び順を入れ替えても結果が変わらない' 'mac-abd434b 0 same-sha7' \
   "$NEW
$OLD" abd434b
# exe の sha7 が一致しない場合でも、新しいほうへ落ちる（＝並び順ではなく経過日数で決まる）
eq '🚨回帰: 同 sha7 が無くても新しいほうを選ぶ（古いものが先頭）' 'mac-abd434b 0 newest' \
   "$OLD
$NEW" deadbee
eq '🚨回帰: 同上・並び順を入れ替え' 'mac-abd434b 0 newest' \
   "$NEW
$OLD" deadbee

# --- 1. exe と同じ sha7 が在れば、新しくなくてもそれを選ぶ -------------------
# 🔑 「出所が揃う」ほうが「新しい」より優先（板 #707 の CTO 裁定）。
eq '同 sha7 は新しさより優先される' 'mac-0ae7e11 9 same-sha7' \
   "$OLD
$NEW" 0ae7e11
eq '候補が 1 件で同 sha7' 'mac-abd434b 0 same-sha7' "$NEW" abd434b

# --- 2. 同 sha7 が無ければいちばん新しいもの --------------------------------
# ⛔ ここに `2>/dev/null` を書かないこと——**失敗メッセージごと握り潰す**。
#    （実際に一度書いてしまい、「1 failed」なのに理由が出ない状態を作った）
eq '3 件から最小の経過日数' 'mac-cccccccc 2 newest' \
   'mac-aaaaaaa 30
mac-cccccccc 2
mac-bbbbbbb 7' zzzzzzz
eq '候補が 1 件（同 sha7 でない）' 'mac-0ae7e11 9 newest' "$OLD" abd434b

# --- 3. 経過日数が同値なら先に見たほうを保つ（並び順に結果を左右させない）----
eq '同値は先着を保つ' 'mac-aaaaaaa 5 newest' \
   'mac-aaaaaaa 5
mac-bbbbbbb 5' zzzzzzz

# --- 4. 測れていないものは合格に倒さない（fail-safe defaults）----------------
ng '候補が空'                     '' abd434b
ng 'exe の sha7 が空'             "$NEW" ''
ng '引数なし'
ng '候補だけ'                     "$NEW"
ng '経過日数が無い行'              'mac-abd434b' abd434b
ng '経過日数が非整数'              'mac-abd434b nine' abd434b
ng '経過日数が負'                  'mac-abd434b -1' abd434b
ng '経過日数が小数（floor し忘れ）' 'mac-abd434b 0.5' abd434b
ng 'mac- で始まらないタグが混入'    'build-abd434b 0' abd434b
ng '空白だけ'                      ' ' abd434b

printf 'select-mac-release: %d passed, %d failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
