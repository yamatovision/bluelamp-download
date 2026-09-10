#!/bin/sh
# assert-build-sha-matches.sh — 「タグ・title・notes が名乗る SHA」と「実際にビルドした SHA」が
# 同じ commit を指していることを判定する。板 #655 / 要件書 §3 D2-2。
#
# 使い方:
#   sh .github/scripts/assert-build-sha-matches.sh <check が出した SHA> <build の実 HEAD SHA>
#   一致 → exit 0 ／ 不一致・測れていない → exit 1（理由を 1 行 stdout へ）
#
# なぜ要るか（run 33308043796 の実測）:
#   check ジョブと build ジョブがそれぞれ独立に `ref: main` を checkout していたため、
#   check が de3d812・windows build が 0ae7e11 を掴み、**別 commit の exe が check の sha7 を
#   名乗るタグで出た**。両ジョブとも緑だったので誰も気づけない。
#   ⇒ `ref:` を固定するだけでは足りない。「固定したから一致するはず」を実測で潰すのがこの判定器。
#
# I-O を書かない（コマンドを走らせず・ファイルを読まず・環境変数も見ない）。受け取るのは
# 測った結果の文字列だけ。測る側は .github/workflows/build-release.yml。
# 単体テストは tests/assert-build-sha-matches.tests.sh（この script を subprocess として起動する）。
# shellcheck shell=sh
set -u

# 🚨 短縮 SHA を受け付けない。sha7 同士・sha7 と full を突き合わせても「同じ commit を指す」
#    ことの証明にはならず、**測れていないものを合格に倒す**ことになる。
#    full SHA（40 桁小文字 hex）以外は不合格へ倒す（fail-safe defaults）。
is_full_sha() {
    _v=$1
    [ "${#_v}" -eq 40 ] || return 1
    case "$_v" in
        *[!0-9a-f]*) return 1 ;;
    esac
    return 0
}

expected=${1-}
actual=${2-}

if [ -z "$expected" ] || [ -z "$actual" ]; then
    echo 'SHA の測定値が空（測れていないものを合格にしない）'
    exit 1
fi
if ! is_full_sha "$expected"; then
    echo "check が出した SHA が full SHA ではない: '${expected}'（40 桁小文字 hex のみ。短縮 SHA では同一 commit を証明できない）"
    exit 1
fi
if ! is_full_sha "$actual"; then
    echo "build の実 HEAD が full SHA ではない: '${actual}'（40 桁小文字 hex のみ。短縮 SHA では同一 commit を証明できない）"
    exit 1
fi
if [ "$expected" != "$actual" ]; then
    echo "出荷物と記録が食い違う: check は '${expected}' を名乗るが build が実際に checkout したのは '${actual}'"
    exit 1
fi
echo "SHA 一致: check の出力と build の実 HEAD はどちらも '${expected}'"
exit 0
