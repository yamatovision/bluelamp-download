#!/bin/sh
# assert-dmg-freshness.sh — 取り込もうとしている BlueLampSetup.dmg が、GA に載せてよいだけ
# 新しいかを判定する。板 #655 S2 / 板 #707 のレビューで CTO 裁定（2026-09-10・案 A3）。
#
# 使い方:
#   sh .github/scripts/assert-dmg-freshness.sh <経過日数> <上限日数>
#   新しい → exit 0 ／ 古い・測れていない → exit 1（理由を 1 行 stdout へ）
#
# なぜ要るか（板 #707 の実測）:
#   dmg を出す release-macos.yml は workflow_dispatch のみで、日次の build-release とは
#   歩調が合わない。⇒ 「最新の mac-* から取り込む」だけだと、**誰も dispatch しない限り
#   同じ dmg が永遠に『最新』として GA に載り続ける**（実測: 2026-09-10 時点で現存する
#   mac-* は mac-0ae7e11＝08-31 の 1 本だけ。10 日前の dmg が毎日出ることになる）。
#   🚨 これは板 #707 の症状そのもの——**人が手で載せた 1 本が正解であり続けた状態**——を
#      自動化で再生産する形である。⛔ 古くなる方向にだけは歯止めを置く。
#
#   ⚠️ 上限を超えたときの振る舞いは **赤ではなく no-op**（PM 裁定 2026-09-07 と同じ）。
#      呼び出し側は BL_ASSETS_READY=0 へ倒し、既存 GA に 1 バイトも触れずに warning で終える。
#      ⇒ この判定器の「不合格」は「GA を作り直さない」の意味であって「ジョブを赤にする」ではない。
#
# 上限日数は呼び出し側が渡す（⛔ ここに 30 を書かない——裁定で変わる値を判定器に埋めない）。
# 正本は .github/workflows/build-release.yml の env: BL_MAC_DMG_MAX_AGE_DAYS。
#
# I-O を書かない（コマンドを走らせず・ファイルを読まず・環境変数も見ない・時刻も自分で採らない）。
# 受け取るのは測った結果の文字列だけ。測る側は build-release.yml（gh の jq で経過日数を出す）。
# 単体テストは tests/assert-dmg-freshness.tests.sh。
# shellcheck shell=sh
set -u

# 非負の 10 進整数だけを受け付ける。⛔ 空・負・小数・文字列は「測れていない」＝不合格へ倒す
# （fail-safe defaults。測れていないものを「新しい」の側へ倒すと、古い dmg が黙って GA に載る）。
is_nonneg_int() {
    _v=$1
    [ -n "$_v" ] || return 1
    case "$_v" in
        *[!0-9]*) return 1 ;;
    esac
    return 0
}

age=${1-}
max=${2-}

if ! is_nonneg_int "$age"; then
    echo "dmg の経過日数が非負整数でない: '${age}'（測れていないものを合格にしない）"
    exit 1
fi
if ! is_nonneg_int "$max"; then
    echo "上限日数が非負整数でない: '${max}'（BL_MAC_DMG_MAX_AGE_DAYS の設定を見直すこと）"
    exit 1
fi

if [ "$age" -gt "$max" ]; then
    echo "取り込もうとした dmg が古すぎる: ${age} 日前（上限 ${max} 日）。GA を作り直さない——release-macos.yml を dispatch して新しい mac-<sha7> を作ること"
    exit 1
fi

echo "dmg の鮮度は許容内: ${age} 日前（上限 ${max} 日）"
exit 0
