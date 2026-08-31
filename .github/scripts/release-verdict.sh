# release-verdict.sh — 配布リポ側の「pre-release として正しく出せたか」を決める純粋関数だけを置く。
#
# ここには I-O を書かない。コマンドも走らせず、ファイルも読まず、環境変数も見ない。
# 受け取るのは「測った結果の文字列」だけで、返すのは 0（合格）/ 1（不合格）と 1 行の理由。
# 測る側（gh api / gh release を実際に叩く側）は .github/workflows/release-macos.yml。
#
# 手本: bluelamp-installer の build/mac/lib/signature-verdict.sh（同じ 2 段構造・
#       **空出力は必ず不合格に倒す** fail-safe をそのまま踏襲する）。
#
# 🚨 署名・公証そのものの判定はここに置かない。それは installer 側 build/mac/lib/signature-verdict.sh が
#    単一の実装として持っており、配布リポへ移植するのは便 B-2b の担当である。
#    ここが受け持つのは「GA に触れていないこと」「pre-release であること」だけ。
#
# このファイルは source して使う。単体テストは tests/release-verdict.tests.sh。
# shellcheck shell=sh

# 本便が出すタグの接頭辞（板 #529 便B-2a）。
BL_MAC_TAG_PREFIX='mac-'

# 🚨 build-release.yml の check ジョブが日次ビルドの skip 判定に使う接頭辞。
#    `gh api repos/.../releases/tags/build-$SHA7` の **存在** で skip するので、
#    こちらが build-<sha7> を名乗ると **windows の日次 GA を勝手に止める**
#    ＝ GA フラグに触れたのと同じになる（CTO 条件 1 違反）。構造的に弾く。
BL_GA_TAG_PREFIX='build-'

# ---------------------------------------------------------------------------
# 1 段目: タグ名 — GA 側の skip 判定と衝突しないこと
# ---------------------------------------------------------------------------

bl_verdict_tag_prefix() {
    _tag="${1-}"
    if [ -z "$_tag" ]; then
        echo 'タグ名が空（測れていないものを合格にしない）'
        return 1
    fi
    case "$_tag" in
        "$BL_GA_TAG_PREFIX"*)
            echo "タグ '${_tag}' は GA 側の接頭辞 '${BL_GA_TAG_PREFIX}' で始まる（build-release.yml の check が skip 判定に使うので windows の日次 GA を止めてしまう）"
            return 1
            ;;
    esac
    case "$_tag" in
        "$BL_MAC_TAG_PREFIX"*)
            echo "タグ '${_tag}' は本便の接頭辞 '${BL_MAC_TAG_PREFIX}' で始まる（GA 側と衝突しない）"
            return 0
            ;;
    esac
    echo "タグ '${_tag}' が本便の接頭辞 '${BL_MAC_TAG_PREFIX}' で始まっていない"
    return 1
}

# ---------------------------------------------------------------------------
# 2 段目: GA 不変 — releases/latest が 1 文字も動いていないこと
# ---------------------------------------------------------------------------

# 引数は publish の前後に `gh api repos/.../releases/latest --jq .tag_name` で測った文字列。
# 🚨 どちらかが空なら不合格。「測れなかった」を「動いていない」と読み替えない。
#    latest が 1 つも無いリポでは呼び出し側が '(none)' 等の番兵を入れる約束にする。
bl_verdict_ga_untouched() {
    _before="${1-}"
    _after="${2-}"
    if [ -z "$_before" ] || [ -z "$_after" ]; then
        echo 'releases/latest の測定値が空（測れていないものを合格にしない）'
        return 1
    fi
    if [ "$_before" != "$_after" ]; then
        echo "GA が動いた: releases/latest が '${_before}' → '${_after}' に変わっている"
        return 1
    fi
    echo "GA 不変: releases/latest は '${_before}' のまま動いていない"
    return 0
}

# ---------------------------------------------------------------------------
# 3 段目: 作った release が pre-release であること
# ---------------------------------------------------------------------------

# 引数は `gh release view --json isPrerelease,isDraft` の値（"true" / "false"）。
# 🚨 解釈できない値を黙って合格に倒さない。読めない＝測れていない＝不合格。
bl_verdict_prerelease() {
    _pre="${1-}"
    _draft="${2-}"
    for _v in "$_pre" "$_draft"; do
        case "$_v" in
            true | false) : ;;
            *)
                echo "真偽値として読めない: '${_v}'（true / false のみ）"
                return 1
                ;;
        esac
    done
    if [ "$_pre" != true ]; then
        echo 'release が pre-release になっていない（GA として作られている）'
        return 1
    fi
    if [ "$_draft" != false ]; then
        echo 'release が draft のまま（公開されていない）'
        return 1
    fi
    echo 'release は pre-release かつ draft でない'
    return 0
}

# ---------------------------------------------------------------------------
# 4 段目: アセットが揃っていること（0 件・欠落を合格にしない）
# ---------------------------------------------------------------------------

# 第 1 引数は改行区切りのアセット名一覧、第 2 引数以降が「在るべき名前」。
bl_verdict_release_assets() {
    _text="${1-}"
    shift 2>/dev/null || true
    if [ -z "$_text" ]; then
        echo 'アセット名の一覧が空（0 件を合格にしない）'
        return 1
    fi
    if [ "$#" -eq 0 ]; then
        echo '在るべきアセット名が 1 つも渡されていない（何も検査していない）'
        return 1
    fi
    _missing=''
    for _want in "$@"; do
        _found=0
        _oldifs=$IFS
        IFS='
'
        for _name in $_text; do
            [ "$_name" = "$_want" ] && _found=1
        done
        IFS=$_oldifs
        [ "$_found" -eq 1 ] || _missing="$_missing $_want"
    done
    if [ -n "$_missing" ]; then
        echo "release に無いアセット:${_missing}"
        return 1
    fi
    echo "release に必要なアセットが揃っている（$*）"
    return 0
}
