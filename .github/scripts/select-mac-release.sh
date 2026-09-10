#!/bin/sh
# select-mac-release.sh — GA へ取り込む dmg を、どの mac-* pre-release から採るか決める。
# 板 #707（2026-09-10・実配布で取り違えが起きたので新設）。
#
# 使い方:
#   sh .github/scripts/select-mac-release.sh "<候補の一覧>" "<exe の sha7>"
#     候補の一覧 = 1 行 1 件の "<タグ名> <経過日数>"（順不同でよい）
#   選べた → exit 0 で "<タグ名> <経過日数> <選んだ理由>" を stdout へ
#   選べない・測れていない → exit 1（理由を 1 行 stdout へ）
#
# 選ぶ順序（要件は板 #707 の CTO 裁定 2026-09-10）:
#   1. **exe と同じ sha7 の mac-<sha7> が在れば、それ**（＝出所が揃う。理由 = same-sha7）
#   2. 無ければ**いちばん新しいもの**（＝経過日数が最小。理由 = newest）
#   ⛔ 同一 sha7 を**必須にはしない**——`release-macos.yml` は workflow_dispatch のみで日次と
#      歩調が合わず、必須にすると日次がほぼ常に赤になる（PM 裁定 2026-09-07）。
#      ⇒ 「在るのに選ばない」だけを潰す。無いときは新しいものへ落とし、呼び出し側が warning を出す。
#
# 🚨 なぜ新設したか（2026-09-10 に実配布で起きたこと）:
#   選別を `gh release list --json createdAt` の `sort_by(.createdAt) | reverse | .[0]` で
#   やっていたが、**GitHub の release の `createdAt` は「タグが指す commit の日時」であって
#   公開日時ではない**。⇒ 同じ commit を指す 2 つのタグは **createdAt が同値**になり、
#   並べ替えが判別子にならない。実測: `mac-abd434b`（当日公開）と `mac-0ae7e11`（9 日前公開）が
#   **どちらも 2026-08-31T12:22:55Z** で、**9 日前のほうが選ばれて GA に載った**。
#   ⇒ 呼び出し側は **`publishedAt`** から経過日数を出してこの script に渡すこと。
#   ⛔ 経過日数を `createdAt` から出すと、**1 時間前に作った dmg も「9 日前」になる**
#      （＝鮮度ガードが dmg の年齢でなく commit の年齢を測る別物になる）。
#
# I-O を書かない（コマンドを走らせず・ファイルを読まず・環境変数も見ない・時刻も自分で採らない）。
# 測る側は .github/workflows/build-release.yml。単体テストは tests/select-mac-release.tests.sh。
# shellcheck shell=sh
set -u

is_nonneg_int() {
    _v=$1
    [ -n "$_v" ] || return 1
    case "$_v" in
        *[!0-9]*) return 1 ;;
    esac
    return 0
}

list=${1-}
exe_sha7=${2-}

if [ -z "$list" ]; then
    echo 'mac-* pre-release の候補が空（0 件を合格にしない）'
    exit 1
fi
if [ -z "$exe_sha7" ]; then
    echo 'exe の sha7 が空（測れていないものを合格にしない）'
    exit 1
fi

want="mac-${exe_sha7}"
best_tag=''
best_age=''
n=0

oldifs=$IFS
IFS='
'
for line in $list; do
    line=${line%"$(printf '\r')"}
    [ -n "$line" ] || continue
    tag=${line%% *}
    age=${line##* }
    if [ "$tag" = "$line" ] || [ -z "$tag" ]; then
        IFS=$oldifs
        echo "候補の行が '<タグ名> <経過日数>' の形になっていない: '${line}'"
        exit 1
    fi
    if ! is_nonneg_int "$age"; then
        IFS=$oldifs
        echo "経過日数が非負整数でない: '${age}'（行: '${line}'）"
        exit 1
    fi
    case "$tag" in
        mac-*) ;;
        *)
            IFS=$oldifs
            echo "候補に mac- で始まらないタグが混ざっている: '${tag}'"
            exit 1
            ;;
    esac
    n=$((n + 1))
    # 1. exe と同じ sha7 が在れば即決（⛔ 以降の比較で上書きしない）
    if [ "$tag" = "$want" ]; then
        IFS=$oldifs
        echo "$tag $age same-sha7"
        exit 0
    fi
    # 2. いちばん新しいもの（経過日数が最小）を控える
    #    🚨 同値のときは先に見たほうを保つ（⛔ 「同値なら後勝ち」にすると、並び順という
    #       判別子でない値に結果が左右される。本件の事故はまさにそれだった）。
    if [ -z "$best_age" ] || [ "$age" -lt "$best_age" ]; then
        best_tag=$tag
        best_age=$age
    fi
done
IFS=$oldifs

if [ "$n" -eq 0 ] || [ -z "$best_tag" ]; then
    echo 'mac-* pre-release の候補が 1 件も無い'
    exit 1
fi

echo "$best_tag $best_age newest"
exit 0
