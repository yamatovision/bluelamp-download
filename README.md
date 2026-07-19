# BlueLamp ダウンロード（Windows）

BlueLamp の Windows セットアップ（`BlueLampSetup.exe`）の公式ダウンロード置き場です。

## ダウンロード（常に最新版）

- **インストーラ本体**: https://github.com/yamatovision/bluelamp-download/releases/latest/download/BlueLampSetup.exe
- **SHA256（改ざん確認用）**: https://github.com/yamatovision/bluelamp-download/releases/latest/download/SHA256SUMS.txt

導入手順はセットアップガイドをご覧ください: https://bluelamp.mikoto.co.jp/setup-guide/windows/

> 現在のビルドはコード署名前のため、ダウンロード時や実行時に Windows の警告（SmartScreen）が表示されます。
> 表示された場合の進め方はセットアップガイドに画面つきで案内しています。

## 仕組み（運用者向け）

- ビルド元: `yamatovision/bluelamp-installer`（private）の `main`
- `.github/workflows/build-release.yml` が windows ランナー＋Inno Setup（`build/build.ps1`）でビルドし、このリポジトリの Release（tag: `build-<sha7>`）として公開します
- トリガー: 毎日 06:17 JST の自動検知（main が更新されていれば自動リリース）／手動 `gh workflow run build-release -R yamatovision/bluelamp-download`
- 認証: installer リポの read-only deploy key（Secret `INSTALLER_DEPLOY_KEY`）のみ。ソースコードは公開されません（公開されるのはビルド済み exe と SHA256 のみ）
