#!/bin/sh
# assert-dmg-freshness.tests.sh — .github/scripts/assert-dmg-freshness.sh の単体テスト。
#
# bats にも他のフレームワークにも依存しない（release-verdict.tests.sh と同じ流儀）。exit 0 が全緑。
# 🚨 判定器は **subprocess として起動する**（workflow が呼ぶのと同じ経路）。
# 🚨 陰性対照（落ちるべきものが落ちる）を必ず対で置く。合格側だけ書くと
#    「常に 0 を返す script」がテストを通ってしまう。
#
# 使い方: sh .github/scripts/tests/assert-dmg-freshness.tests.sh
set -eu

here=$(cd "$(dirname "$0")" && pwd)
target="$here/../assert-dmg-freshness.sh"
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

# --- 陽性対照: 上限内なら通る ---------------------------------------------
ok  '今日作られた dmg（0 日）'            0 30
ok  '10 日前（板 #707 実測の mac-0ae7e11 相当）' 10 30
ok  '上限ちょうど（境界は合格側）'          30 30
ok  '上限が 0 日で dmg も当日'             0 0

# --- 陰性対照: 上限を超えたら落ちる ---------------------------------------
ng  '上限を 1 日超えた（境界の外側）'        31 30
ng  '大きく古い'                          365 30
ng  '上限 0 日で 1 日前'                    1 0

# --- 測れていないものは合格に倒さない（fail-safe defaults）------------------
ng  '経過日数が空'                        '' 30
ng  '上限が空'                            10 ''
ng  '引数なし'
ng  '経過日数だけ'                        10
ng  '経過日数が負（date の引き算が壊れた形）'  -1 30
ng  '経過日数が小数（floor し忘れ）'         '9.5' 30
ng  '経過日数が文字列'                     'null' 30
ng  '経過日数が空白'                       ' ' 30
ng  '上限が文字列（env の設定ミス）'         10 'thirty'
ng  '上限が負'                            10 -30
ng  '経過日数に単位が付いている'             '10d' 30

# --- 🔬 「大きい方が古い」の向きを取り違えていないことの対照 ------------------
# （age と max を逆に渡す実装だと、この 2 本のどちらかが必ず落ちる）
ok  '向きの対照: 新しい dmg × 緩い上限'      1 365
ng  '向きの対照: 古い dmg × 厳しい上限'      365 1

printf 'assert-dmg-freshness: %d passed, %d failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
