#!/bin/sh
# is-docs-only.tests.sh — .github/scripts/is-docs-only.sh の単体テスト。
#
# bats にも他のフレームワークにも依存しない（release-verdict.tests.sh と同じ流儀）。exit 0 が全緑。
# 🚨 判定器は **subprocess として起動する**（workflow が呼ぶのと同じ経路）。
# 🚨 陰性対照（落ちるべきものが落ちる）を必ず対で置く。合格側だけ書くと
#    「常に 0 を返す script」がテストを通ってしまう。
#
# 使い方: sh .github/scripts/tests/is-docs-only.tests.sh
set -eu

here=$(cd "$(dirname "$0")" && pwd)
target="$here/../is-docs-only.sh"
[ -f "$target" ] || { echo "判定器が無い: $target" >&2; exit 1; }

pass=0
fail=0
nl='
'

ok() {  # 文書だけ（skip する）はず
    _label=$1
    shift
    if sh "$target" "$@" >/dev/null 2>&1; then
        pass=$((pass + 1))
    else
        printf 'FAIL(文書だけのはずがビルド側に倒れた): %s\n' "$_label" >&2
        fail=$((fail + 1))
    fi
}

ng() {  # ビルドするはず
    _label=$1
    shift
    if sh "$target" "$@" >/dev/null 2>&1; then
        printf 'FAIL(ビルドすべきものが skip 側に倒れた): %s\n' "$_label" >&2
        fail=$((fail + 1))
    else
        pass=$((pass + 1))
    fi
}

# --- 陽性対照: 文書だけなら skip ---------------------------------------------
ok  'docs 1 件'                                  'docs/requirements.md'
ok  'docs 深い階層・.md 以外（証跡の png）'         'docs/verify-result/mac-installer-2026-09-16/run-A/shot.png'
ok  'リポ直下の README.md'                         'README.md'
ok  'docs と README の混在（2026-09-16 の証跡 commit 型）' "docs/verify-result/x/README.md${nl}README.md${nl}docs/a.json"
ok  '末尾に改行が付いている（git diff の出力そのまま）' "docs/a.md${nl}"
ok  '日本語ファイル名（quotepath=false で渡る形）'     'docs/主君手番-macユーザー作成.md'

# --- 陰性対照: 出荷物に触れうる変更を 1 件でも含めばビルド ---------------------
ng  'インストーラー本体'                            'installer/BlueLampSetup.iss'
ng  '🚨 Windows の AI 台本（.md でも出荷物）'          'installer/playbook/setup.md'
ng  '🚨 mac の AI 台本（.md でも出荷物）'              'installer/mac/playbook/setup-mac.md'
ng  '🚨 台本の展開元テンプレート'                     'installer/playbook-src/repair.md.tmpl'
ng  'ビルド script'                                'build/build.ps1'
ng  'workflow（CI の変更）'                         '.github/workflows/ci-build.yml'
ng  'tests'                                        'tests/foo.tests.ps1'
ng  '文書に 1 件だけ本体が混ざる（最後の行）'          "docs/a.md${nl}README.md${nl}build/build-mac.sh"
ng  '文書に 1 件だけ本体が混ざる（最初の行）'          "installer/mac/scripts/bootstrap.sh${nl}docs/a.md"
ng  'リポ直下の .md 以外（.gitignore）'               '.gitignore'
ng  'docs に似た名前（docs 直下ではない）'             'docsx/a.md'
ng  'docs に似た名前（別階層の docs）'                'installer/docs/a.md'
ng  'md に似た拡張子（.mdx）'                        'README.mdx'

# --- 測れていないものは skip に倒さない（fail-safe defaults）------------------
ng  '空文字'                                        ''
ng  '引数なし'
ng  '改行だけ'                                      "${nl}${nl}"
ng  '空白だけ'                                      '   '

printf 'is-docs-only: %d passed, %d failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
