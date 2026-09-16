#!/bin/sh
# is-docs-only.sh — 前回 GA から installer main までの変更が「出荷物に入らない文書だけ」かを判定する。
# 板 #936 系統⑤(b)（大掃除便・2026-09-17）。
#
# 使い方:
#   sh .github/scripts/is-docs-only.sh "<変更パス（改行区切り）>"
#   文書だけ → exit 0 ／ 出荷物に触れうる変更を含む・測れていない → exit 1（理由を 1 行 stdout へ）
#
# なぜ要るか（2026-09-16 の実測）:
#   日次 cron（06:17 JST）は installer main の sha7 に `build-<sha7>` の release が無ければ GA を作り直す。
#   ⇒ **docs だけの commit でも exe が再署名され・GA が一度消え・指紋が変わる**。これを止めるために
#      人が `build-<sha7>` の placeholder release を前置していた（2026-09-16 に 3 回）。人の手に依存する経路。
#
# 🚨 「文書」の定義は **`docs/` 配下** と **リポ直下の `*.md`（README.md 等）** の 2 つだけ。
#    ⛔ 「任意の階層の `*.md`」にしないこと——**AI 台本は .md のまま出荷物に同梱される**
#       （`installer/playbook/*.md` は .iss の `Source: ...\playbook\*.md`、`installer/mac/playbook/*-mac.md` は
#        build-mac.sh が .app に入れる。`installer/playbook-src/*.md.tmpl` は展開元）。
#       拡張子で文書と決めると、台本の修正が GA に届かない＝**黙って古い台本を配り続ける**。
#    📌 `docs/e2e-specs/rig/*.sh` は ci-build-mac.yml（CI）だけが使い、出荷物には入らない。
#
# fail-safe defaults: 空・判定できないものは「文書だけ」に倒さない（倒すと出荷すべき変更が GA に届かない）。
# ⚠️ 不合格＝「skip しない＝これまでどおりビルドする」の意味であって、赤にするのではない。
#
# I-O を書かない（コマンドを走らせず・ファイルを読まず・環境変数も見ない）。
# 受け取るのは測った結果の文字列だけ。測る側は build-release.yml の check job（git diff --name-only --no-renames）。
# 単体テストは tests/is-docs-only.tests.sh。
# shellcheck shell=sh
set -u
set -f   # パスを glob 展開させない（`docs/*` のような名前が別のファイル群に化けないように）

paths=${1-}

n=0
first_hit=''
old_ifs=$IFS
IFS='
'
for p in $paths; do
    [ -n "$p" ] || continue
    n=$((n + 1))
    case "$p" in
        docs/*) continue ;;
        */*) ;;               # 階層の中の .md は出荷物でありうる（台本）→ 文書に数えない
        *.md) continue ;;     # リポ直下の .md
    esac
    [ -n "$first_hit" ] || first_hit=$p
done
IFS=$old_ifs

if [ "$n" -eq 0 ]; then
    echo "変更パスが空（差分を測れていない）→ 文書だけとは言わない"
    exit 1
fi

if [ -n "$first_hit" ]; then
    echo "出荷物に触れうる変更を含む（例: ${first_hit}）→ ビルドする"
    exit 1
fi
echo "変更 ${n} 件はすべて文書（docs/ 配下かリポ直下の .md）→ GA を作り直さない"
exit 0
