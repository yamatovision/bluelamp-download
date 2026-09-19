#!/bin/sh
# assert-promotable.sh — 「この release を GA に昇格してよいか」を決める純粋関数（板 #936 系統⑤③・n=1805）。
#
# I-O を書かない。受け取るのは測った結果の文字列だけで、返すのは 0（昇格してよい）/ 1（だめ）と 1 行の理由。
# 測る側は .github/workflows/promote-release.yml。
#
# 使い方: sh assert-promotable.sh <tag> <isPrerelease: true|false>
#   - tag は build-<sha7>（7 桁の小文字 16 進）だけを受け付ける。mac- 等は GA にしない
#   - 昇格できるのは pre-release だけ。既に GA の物・測れなかった物は不合格
set -u
tag="${1-}"
pre="${2-}"
case "$tag" in
    '') echo 'タグが空（測れていないものを昇格しない）'; exit 1 ;;
esac
if ! printf '%s' "$tag" | grep -Eq '^build-[0-9a-f]{7}$'; then
    echo "タグ '${tag}' は build-<sha7>（7 桁の小文字 16 進）の形ではない"
    exit 1
fi
case "$pre" in
    true)  echo "昇格してよい: '${tag}' は pre-release"; exit 0 ;;
    false) echo "'${tag}' は既に GA（pre-release ではない）＝昇格する物が無い"; exit 1 ;;
    *)     echo "'${tag}' が pre-release か測れていない（値='${pre}'）"; exit 1 ;;
esac
