#!/bin/sh
# release-verdict.tests.sh — .github/scripts/release-verdict.sh の純粋関数の単体テスト。
#
# bats にも他のフレームワークにも依存しない（installer 側 §M16-5 と同じ流儀）。exit 0 が全緑。
# 🚨 陰性対照（落ちるべきものが落ちる）を必ず対で置く。合格側だけ書くと
#    「常に 0 を返す関数」がテストを通ってしまう。
#
# 使い方: sh .github/scripts/tests/release-verdict.tests.sh
set -eu

here=$(cd "$(dirname "$0")" && pwd)
# shellcheck source=../release-verdict.sh
. "$here/../release-verdict.sh"

pass=0
fail=0

# 合格するはず
ok() {
    _label=$1
    shift
    if "$@" >/dev/null 2>&1; then
        pass=$((pass + 1))
    else
        printf 'FAIL(合格するはずが落ちた): %s\n' "$_label" >&2
        fail=$((fail + 1))
    fi
}

# 落ちるはず
ng() {
    _label=$1
    shift
    if "$@" >/dev/null 2>&1; then
        printf 'FAIL(落ちるはずが通った): %s\n' "$_label" >&2
        fail=$((fail + 1))
    else
        pass=$((pass + 1))
    fi
}

# ---------------------------------------------------------------------------
# bl_verdict_tag_prefix — GA 側の skip 判定と衝突しないこと
# ---------------------------------------------------------------------------
ok 'mac- で始まるタグは通る'            bl_verdict_tag_prefix 'mac-0ae7e11'
ok '定数から組んだタグも通る'            bl_verdict_tag_prefix "${BL_MAC_TAG_PREFIX}abcdef0"
# 🚨 これが本丸。build-<sha7> を名乗ると build-release.yml の check が skip し、
#    windows の日次 GA を勝手に止める＝GA フラグに触れたのと同じになる。
ng 'build- で始まるタグは弾く（GA の skip 判定と衝突）' bl_verdict_tag_prefix 'build-0ae7e11'
ng 'build- 単体も弾く'                  bl_verdict_tag_prefix "$BL_GA_TAG_PREFIX"
ng '無関係な接頭辞は弾く'                bl_verdict_tag_prefix 'v1.0.0'
ng '空は弾く'                            bl_verdict_tag_prefix ''
ng '引数なしは弾く'                      bl_verdict_tag_prefix

# ---------------------------------------------------------------------------
# bl_verdict_ga_untouched — releases/latest が動いていないこと
# ---------------------------------------------------------------------------
ok '前後が同じなら通る'                  bl_verdict_ga_untouched 'build-4497091' 'build-4497091'
ok 'latest が無いリポの番兵同士も通る'   bl_verdict_ga_untouched '(none)' '(none)'
ng '前後が違えば落ちる（GA が動いた）'   bl_verdict_ga_untouched 'build-4497091' 'mac-0ae7e11'
# 🚨 空を「動いていない」と読み替えない。測れなかったものは不合格へ倒す。
ng 'before が空なら落ちる'               bl_verdict_ga_untouched '' 'build-4497091'
ng 'after が空なら落ちる'                bl_verdict_ga_untouched 'build-4497091' ''
ng '両方空なら落ちる'                    bl_verdict_ga_untouched '' ''

# ---------------------------------------------------------------------------
# bl_verdict_prerelease — pre-release かつ draft でないこと
# ---------------------------------------------------------------------------
ok 'prerelease=true / draft=false は通る' bl_verdict_prerelease 'true' 'false'
ng 'prerelease=false は落ちる（GA）'      bl_verdict_prerelease 'false' 'false'
ng 'draft=true は落ちる'                  bl_verdict_prerelease 'true' 'true'
# 🚨 読めない値を黙って合格に倒さない。
ng 'True（大文字）は落ちる'               bl_verdict_prerelease 'True' 'false'
ng '1 は落ちる'                           bl_verdict_prerelease '1' 'false'
ng '空は落ちる'                           bl_verdict_prerelease '' 'false'
ng 'null は落ちる'                        bl_verdict_prerelease 'null' 'false'

# ---------------------------------------------------------------------------
# bl_verdict_release_assets — 0 件・欠落を合格にしない
# ---------------------------------------------------------------------------
two='BlueLampSetup.dmg
SHA256SUMS.txt'
one='BlueLampSetup.dmg'
noise='BlueLampSetup.dmg.zip
SHA256SUMS.txt.bak'

ok '2 つ揃っていれば通る'                bl_verdict_release_assets "$two" BlueLampSetup.dmg SHA256SUMS.txt
ok '順序が違っても通る'                  bl_verdict_release_assets "$two" SHA256SUMS.txt BlueLampSetup.dmg
ng '片方欠けたら落ちる'                  bl_verdict_release_assets "$one" BlueLampSetup.dmg SHA256SUMS.txt
# 🚨 部分一致で通してはいけない。dmg.zip は dmg ではない。
ng '部分一致では通らない'                bl_verdict_release_assets "$noise" BlueLampSetup.dmg SHA256SUMS.txt
ng '一覧が空なら落ちる（0 件を合格にしない）' bl_verdict_release_assets '' BlueLampSetup.dmg
ng '検査対象が渡されなければ落ちる'      bl_verdict_release_assets "$two"

# ---------------------------------------------------------------------------
printf '\nrelease-verdict: %d passed, %d failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ] || exit 1
