#!/bin/sh
# assert-release-assets.sh — GA release へ渡す 3 アセットが揃い、SHA256SUMS.txt が
# exe と dmg の 2 行になっていることを判定する。板 #655 / 要件書 §3 D2-3・D2-5。
#
# 使い方:
#   sh .github/scripts/assert-release-assets.sh "<アセット名の改行区切り一覧>" "<SHA256SUMS.txt の中身>"
#   揃っている → exit 0 ／ 欠け・余り・読めない → exit 1（理由を 1 行 stdout へ）
#
# なぜ要るか（要件書 §0-4 の実測）:
#   build-release.yml は `gh release delete --cleanup-tag` の直後に exe と SUMS の **2 つだけ**を
#   渡して release を作り直していた。⇒ 09/01 に手作業で GA へ載せた BlueLampSetup.dmg と
#   SUMS の dmg 行が、次の実走 1 回で黙って消え、releases/latest/download/BlueLampSetup.dmg が
#   404 に戻る。両ジョブは緑のままなので気づけない。
#   🚨 `delete --cleanup-tag` は不可逆。**この判定器は delete より前に呼ぶこと**（fail-safe defaults）。
#      揃っていないときの正しい振る舞いは「exe だけで作り直す」ではなく「赤で止め、GA に触らない」。
#
# I-O を書かない（コマンドを走らせず・ファイルを読まず・環境変数も見ない）。受け取るのは
# 測った結果の文字列だけ。測る側は .github/workflows/build-release.yml。
# 単体テストは tests/assert-release-assets.tests.sh（この script を subprocess として起動する）。
# shellcheck shell=sh
set -u

# GA release が持つべきアセット（この 3 点ちょうど。欠けても余っても不合格）。
WANT_EXE='BlueLampSetup.exe'
WANT_DMG='BlueLampSetup.dmg'
WANT_SUMS='SHA256SUMS.txt'

assets=${1-}
sums=${2-}

if [ -z "$assets" ]; then
    echo 'アセット名の一覧が空（0 件を合格にしない）'
    exit 1
fi
if [ -z "$sums" ]; then
    echo 'SHA256SUMS.txt の中身が空（測れていないものを合格にしない）'
    exit 1
fi

# --- 1. アセット集合が 3 点ちょうどであること -------------------------------
# 🚨 部分一致で通さない（BlueLampSetup.dmg.zip は BlueLampSetup.dmg ではない）。
seen_exe=0
seen_dmg=0
seen_sums=0
n_assets=0
extra=''
oldifs=$IFS
IFS='
'
for name in $assets; do
    name=${name%"$(printf '\r')"}   # Windows 側で作った一覧の CR を落とす
    [ -n "$name" ] || continue
    n_assets=$((n_assets + 1))
    case "$name" in
        "$WANT_EXE")  seen_exe=$((seen_exe + 1)) ;;
        "$WANT_DMG")  seen_dmg=$((seen_dmg + 1)) ;;
        "$WANT_SUMS") seen_sums=$((seen_sums + 1)) ;;
        *) extra="$extra $name" ;;
    esac
done
IFS=$oldifs

missing=''
[ "$seen_exe"  -ge 1 ] || missing="$missing $WANT_EXE"
[ "$seen_dmg"  -ge 1 ] || missing="$missing $WANT_DMG"
[ "$seen_sums" -ge 1 ] || missing="$missing $WANT_SUMS"
if [ -n "$missing" ]; then
    echo "GA release に渡すアセットが欠けている:${missing}（欠けたまま作り直すと恒久 URL が 404 に戻る。赤で止めて GA に触らない）"
    exit 1
fi
if [ -n "$extra" ]; then
    echo "GA release に想定外のアセットが混ざっている:${extra}（3 点ちょうどでないものを合格にしない）"
    exit 1
fi
if [ "$n_assets" -ne 3 ]; then
    echo "アセットが 3 点ちょうどでない（${n_assets} 件・同じ名前が重複している可能性）"
    exit 1
fi

# --- 2. SHA256SUMS.txt が exe と dmg の 2 行ちょうどであること ---------------
# 形式は `<64 桁 hex><空白 2 つ><ファイル名>`（shasum -a 256 / PowerShell 側の生成と同形）。
n_lines=0
sums_names=''
hash_exe=''
hash_dmg=''
oldifs=$IFS
IFS='
'
for line in $sums; do
    line=${line%"$(printf '\r')"}
    [ -n "$line" ] || continue
    n_lines=$((n_lines + 1))
    hash=${line%%  *}
    fname=${line#*  }
    if [ "$hash" = "$line" ] || [ -z "$fname" ]; then
        echo "SHA256SUMS.txt の行が '<hash>  <ファイル名>' の形になっていない: '${line}'"
        exit 1
    fi
    if [ "${#hash}" -ne 64 ]; then
        echo "SHA256SUMS.txt の hash が 64 桁でない: '${hash}'（行: '${line}'）"
        exit 1
    fi
    case "$hash" in
        *[!0-9a-fA-F]*)
            echo "SHA256SUMS.txt の hash が 16 進数でない: '${hash}'（行: '${line}'）"
            exit 1
            ;;
    esac
    case "$fname" in
        "$WANT_EXE") hash_exe=$hash ;;
        "$WANT_DMG") hash_dmg=$hash ;;
        *)
            echo "SHA256SUMS.txt に想定外のファイル名がある: '${fname}'（${WANT_EXE} と ${WANT_DMG} の 2 行のみ）"
            exit 1
            ;;
    esac
    sums_names="$sums_names $fname"
done
IFS=$oldifs

if [ "$n_lines" -ne 2 ]; then
    echo "SHA256SUMS.txt が 2 行でない（${n_lines} 行）: exe だけの 1 行は dmg 消失の直接の原因"
    exit 1
fi
if [ -z "$hash_exe" ]; then
    echo "SHA256SUMS.txt に ${WANT_EXE} の行が無い"
    exit 1
fi
if [ -z "$hash_dmg" ]; then
    echo "SHA256SUMS.txt に ${WANT_DMG} の行が無い"
    exit 1
fi
# 🚨 別々のファイルが同じ hash を名乗るのは、片方の hash を書き写した事故（D2-5 が禁じた
#    「prerelease 側の SUMS を写す」を含む）。同値を合格にしない。
if [ "$hash_exe" = "$hash_dmg" ]; then
    echo "${WANT_EXE} と ${WANT_DMG} が同じ hash を名乗っている: '${hash_exe}'（片方を書き写した事故。取り込んだファイルから採り直すこと）"
    exit 1
fi

echo "3 アセットが揃い、SHA256SUMS.txt は ${WANT_EXE} と ${WANT_DMG} の 2 行（アセット:${sums_names} + ${WANT_SUMS}）"
exit 0
