# コード署名（BlueLampSetup.exe）

`BlueLampSetup.exe` は GlobalSign OV コードサイニング証明書で Authenticode 署名される。
これにより Windows の UAC ダイアログの発行元が「不明」から「**株式会社命**」になり、
SmartScreen の評価が**発行元単位で蓄積される**（未署名だとビルドごとに評価がリセットされ、永久に貯まらない）。

## 構成

| 物 | 実体 |
|---|---|
| 証明書 | GlobalSign OV コードサイニング証明書（HSM 格納タイプ）／CN=`MIKOTO, K.K.`／オーダーID `OS20260721456257` |
| 有効期間 | 2026-08-03 〜 2027-08-04 |
| 発行 CA | `GlobalSign GCC R45 CodeSigning CA 2020` |
| 秘密鍵 | **GCP Cloud KMS の HSM 内**（FIPS 140-2 Level 3）。`projects/yamatovision-blue-lamp/locations/asia-northeast1/keyRings/bluelamp-codesign/cryptoKeys/ov-codesign-2026/cryptoKeyVersions/1`（RSA 4096 / PKCS#1 v1.5 / SHA-256） |
| 署名ツール | [jsign](https://ebourg.github.io/jsign/) 7.5（`--storetype GOOGLECLOUD`。signtool は Cloud KMS 用の CNG プロバイダが無いため使えない） |
| タイムスタンプ | `http://timestamp.globalsign.com/tsa/r6advanced1`（RFC 3161） |

**秘密鍵は HSM の外に出ない。** CI は Workload Identity 連携で一時トークンを得て、KMS に「この digest に署名して」と依頼するだけ。
リポジトリにも GitHub Secret にも秘密鍵は存在しない。

## `full-chain.pem`

エンドエンティティ証明書 + 中間 CA 2 枚（`GlobalSign GCC R45 CodeSigning CA 2020` → `GlobalSign Code Signing Root R45`）。
**証明書は公開情報**（署名済みバイナリに必ず埋め込まれる）なので、Secret ではなくリポジトリで管理する。

更新（証明書の年次更新時）はこのファイルを差し替えるだけでよい。

## 必要な GitHub Secret

| 名前 | 中身 |
|---|---|
| `GCP_WORKLOAD_IDENTITY_PROVIDER` | `projects/<番号>/locations/global/workloadIdentityPools/<pool>/providers/<provider>` |
| `GCP_SIGNING_SERVICE_ACCOUNT` | 署名専用 SA のメールアドレス |

署名専用 SA には **`roles/cloudkms.signerVerifier` を鍵 `ov-codesign-2026` 単体にのみ**付与する（プロジェクト全体には付けない）。

## 検証

ワークフローは署名後に `Get-AuthenticodeSignature` で以下を検証し、満たさなければビルドを落とす。

- `Status` が `Valid`
- 署名者 Subject に `MIKOTO` を含む
- タイムスタンプが付いている

ローカルで検証する場合（mac/Linux）:

```bash
osslsigncode verify -CAfile /etc/ssl/cert.pem -TSA-CAfile /etc/ssl/cert.pem BlueLampSetup.exe
```

## ⚠️ 順序の注意

**署名は `SHA256SUMS.txt` の生成より前**に行うこと。署名するとファイルのハッシュが変わるため、
逆順にすると公開ハッシュと実物が食い違う。
