# BlueLamp ダウンロード

BlueLamp のセットアップアプリ（Windows: `BlueLampSetup.exe` ／ Mac: `BlueLampSetup.dmg`）の公式ダウンロード置き場です。

## ダウンロード（常に最新版）

| OS | インストーラ | 導入手順 |
|---|---|---|
| **Windows** | https://github.com/yamatovision/bluelamp-download/releases/latest/download/BlueLampSetup.exe | [セットアップガイド（Windows 版）](https://bluelamp.mikoto.co.jp/setup-guide/windows/) |
| **Mac**（macOS 12 以降） | https://github.com/yamatovision/bluelamp-download/releases/latest/download/BlueLampSetup.dmg | 下記「Mac の導入手順」 |

- **SHA256（改ざん確認用・両方の指紋が入っています）**: https://github.com/yamatovision/bluelamp-download/releases/latest/download/SHA256SUMS.txt

### Windows の注意

> 現在の Windows ビルドはコード署名前のため、ダウンロード時や実行時に Windows の警告（SmartScreen）が表示されます。
> 表示された場合の進め方はセットアップガイドに画面つきで案内しています。

### Mac の導入手順

1. 上表の `BlueLampSetup.dmg` をダウンロードします。
2. ダウンロードした `BlueLampSetup.dmg` をダブルクリックして開きます。
3. 開いたウィンドウの中の **`BlueLampSetup`（BlueLamp セットアップ）をダブルクリック**します。
   ※ アプリケーションフォルダへのコピーは不要です。セットアップ用のアプリなので、そのまま実行してください。
4. あとは画面とターミナルの案内どおりに進めれば導入が完了します。

> Mac 版は Apple の公証（notarization）済みで、Developer ID（MIKOTO, K.K.）で署名されています。
> そのため Windows のような「開発元を確認できません」の警告は出ません。
> Intel Mac・Apple シリコン Mac のどちらにも対応しています（ユニバーサルバイナリ）。

### 指紋（SHA256）の確認方法

`SHA256SUMS.txt` には `BlueLampSetup.exe` と `BlueLampSetup.dmg` の 2 行が入っています。
ダウンロードしたファイルの指紋が、その行の値と一致することを確認してください。

- **Windows（PowerShell）**: `Get-FileHash .\BlueLampSetup.exe -Algorithm SHA256`
- **Mac（ターミナル）**: `shasum -a 256 ~/Downloads/BlueLampSetup.dmg`

## 仕組み（運用者向け）

- ビルド元: `yamatovision/bluelamp-installer`（private）の `main`
- **Windows**: `.github/workflows/build-release.yml` が windows ランナー＋Inno Setup（`build/build.ps1`）でビルドし、このリポジトリの Release（tag: `build-<sha7>`）として公開します
  - トリガー: 毎日 06:17 JST（実際の発火は 1.5〜2 時間遅れる）の自動検知で **pre-release**（`build-<sha7>`・Latest にしない）を作る／手動 `gh workflow run build-release -R yamatovision/bluelamp-download`
  - **GA（`releases/latest`）への昇格は `.github/workflows/promote-release.yml` の dispatch でだけ行う**（検証した sha を `gh workflow run promote-release -R yamatovision/bluelamp-download -f tag=build-<sha7>`）。以前の「GA を止めるための placeholder 前置」は不要（板 #936 系統⑤③）
- **Mac**: `.github/workflows/release-macos.yml`（手動 dispatch のみ）が dmg をビルドし、署名・公証・staple して `mac-<sha7>` タグの pre-release として発行します。dmg を exe と一緒に `build-<sha7>` の pre-release へ載せるのは `build-release.yml` 側で（`.github/scripts/select-mac-release.sh` が載せる dmg を選ぶ）、GA へは `promote-release.yml` で昇格させます
- 認証: installer リポの read-only deploy key（Secret `INSTALLER_DEPLOY_KEY`）のみ。ソースコードは公開されません（公開されるのはビルド済みのインストーラと SHA256 のみ）

> 配布物まわりの現在地・既知の罠は `docs/handoff-707-655s2-2026-09-10.md` にまとめてあります。
