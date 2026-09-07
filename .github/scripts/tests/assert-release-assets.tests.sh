#!/bin/sh
# assert-release-assets.tests.sh — .github/scripts/assert-release-assets.sh の単体テスト。
#
# bats にも他のフレームワークにも依存しない（release-verdict.tests.sh と同じ流儀）。exit 0 が全緑。
# 🚨 判定器は **subprocess として起動する**（workflow が呼ぶのと同じ経路）。
# 🚨 陰性対照（落ちるべきものが落ちる）を必ず対で置く。
#
# 使い方: sh .github/scripts/tests/assert-release-assets.tests.sh
set -eu

here=$(cd "$(dirname "$0")" && pwd)
target="$here/../assert-release-assets.sh"
[ -f "$target" ] || { echo "判定器が無い: $target" >&2; exit 1; }

pass=0
fail=0

ok() {
    _label=$1
    shift
    if sh "$target" "$@" >/dev/null 2>&1; then
        pass=$((pass + 1))
    else
        printf 'FAIL(合格するはずが落ちた): %s\n' "$_label" >&2
        fail=$((fail + 1))
    fi
}

ng() {
    _label=$1
    shift
    if sh "$target" "$@" >/dev/null 2>&1; then
        printf 'FAIL(落ちるはずが通った): %s\n' "$_label" >&2
        fail=$((fail + 1))
    else
        pass=$((pass + 1))
    fi
}

H_EXE='1111111111111111111111111111111111111111111111111111111111111111'
H_DMG='2222222222222222222222222222222222222222222222222222222222222222'

three='BlueLampSetup.exe
BlueLampSetup.dmg
SHA256SUMS.txt'
# 🚨 これが現状（要件書 §0-4）。exe と SUMS だけで作り直すと dmg が消える。
two_no_dmg='BlueLampSetup.exe
SHA256SUMS.txt'

sums2="$H_EXE  BlueLampSetup.exe
$H_DMG  BlueLampSetup.dmg"
# 🚨 これが現状の SUMS。exe 1 行だけ。
sums1="$H_EXE  BlueLampSetup.exe"

# --- 陽性対照: 3 アセット + SUMS 2 行 なら通る ------------------------------
ok '3 アセット・SUMS 2 行 は通る'      "$three" "$sums2"
ok 'アセットの順序が違っても通る' \
   'SHA256SUMS.txt
BlueLampSetup.dmg
BlueLampSetup.exe' "$sums2"
ok 'SUMS の行順が違っても通る'         "$three" "$H_DMG  BlueLampSetup.dmg
$H_EXE  BlueLampSetup.exe"
ok '大文字 hash（PowerShell の Get-FileHash 形式）も通る' "$three" \
   "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA  BlueLampSetup.exe
BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB  BlueLampSetup.dmg"
ok 'CRLF（Windows 側で作った一覧）でも通る' \
   "$(printf 'BlueLampSetup.exe\r\nBlueLampSetup.dmg\r\nSHA256SUMS.txt')" \
   "$(printf '%s  BlueLampSetup.exe\r\n%s  BlueLampSetup.dmg' "$H_EXE" "$H_DMG")"

# --- 本丸: 現状（dmg 消失）を落とす ----------------------------------------
ng 'dmg が無いアセット集合は落ちる'    "$two_no_dmg" "$sums2"
ng 'SUMS が exe 1 行だけなら落ちる'    "$three" "$sums1"
ng '現状そのもの（dmg 無し・SUMS 1 行）は落ちる' "$two_no_dmg" "$sums1"

# --- 欠け・余り・重複 -------------------------------------------------------
ng 'exe が無ければ落ちる'              'BlueLampSetup.dmg
SHA256SUMS.txt' "$sums2"
ng 'SHA256SUMS.txt 自体が無ければ落ちる' 'BlueLampSetup.exe
BlueLampSetup.dmg' "$sums2"
ng '想定外のアセットが混ざれば落ちる'  "$three
BlueLampSetup.dmg.zip" "$sums2"
# 🚨 部分一致で通してはいけない。dmg.zip は dmg ではない。
ng '部分一致では通らない'              'BlueLampSetup.exe
BlueLampSetup.dmg.zip
SHA256SUMS.txt' "$sums2"
ng '同じ名前の重複は落ちる（3 点ちょうどでない）' 'BlueLampSetup.exe
BlueLampSetup.exe
BlueLampSetup.dmg
SHA256SUMS.txt' "$sums2"

# --- SUMS の形 --------------------------------------------------------------
ng 'SUMS が 3 行なら落ちる'            "$three" "$sums2
3333333333333333333333333333333333333333333333333333333333333333  SHA256SUMS.txt"
ng 'SUMS に想定外のファイル名があれば落ちる' "$three" \
   "$H_EXE  BlueLampSetup.exe
$H_DMG  BlueLampSetup.msi"
ng 'hash が 64 桁でなければ落ちる'     "$three" "abc  BlueLampSetup.exe
$H_DMG  BlueLampSetup.dmg"
ng 'hash が 16 進数でなければ落ちる'   "$three" \
   "zzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz  BlueLampSetup.exe
$H_DMG  BlueLampSetup.dmg"
ng '区切りが空白 1 つなら落ちる'       "$three" "$H_EXE BlueLampSetup.exe
$H_DMG BlueLampSetup.dmg"
# 🚨 別ファイルが同じ hash を名乗るのは片方を書き写した事故（D2-5）。
ng 'exe と dmg が同じ hash なら落ちる' "$three" "$H_EXE  BlueLampSetup.exe
$H_EXE  BlueLampSetup.dmg"

# --- 空・引数不足を合格に倒さない ------------------------------------------
ng 'アセット一覧が空なら落ちる'        '' "$sums2"
ng 'SUMS が空なら落ちる'               "$three" ''
ng '両方空なら落ちる'                  '' ''
ng '引数なしは落ちる'
ng '引数 1 つは落ちる'                 "$three"

printf '\nassert-release-assets: %d passed, %d failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ] || exit 1
