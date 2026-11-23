# Storage 調査メモ（Tool 作成・実機確認で分かったこと）

実施日: 2026-11-22。環境: Japan East、Az.Storage 9.8.0。Tool は [../Tool/README.md](../Tool/README.md)。

## リソースプロバイダー

- サブスクリプションで `Microsoft.Storage` が未登録だと、`New-AzStorageAccount` が `NotFound` で失敗する。登録（`Register-AzResourceProvider`）は無料・取り消し可能。

## コンテナ作成とロール

- `New-AzStorageContext -UseConnectedAccount`（Azure AD 認証）でコンテナを作るには、操作ユーザーに `Storage Blob Data Contributor` が必要。ロール割り当ての反映に時間がかかるため、コンテナ作成は再試行する。

## 最小 TLS と匿名アクセス

- 既定で、ストレージアカウントは `MinimumTlsVersion = TLS1_0` で作られることがある（実機: 手動作成・VM の起動診断用の自動作成のどちらも TLS1_0）。
- 上げる: `Set-AzStorageAccount -MinimumTlsVersion TLS1_2`（Az.Storage 9.8.0）。BLOB の匿名アクセスは `-AllowBlobPublicAccess $false`。
- 影響: TLS 1.0 / 1.1 でしか接続できない古いクライアントは、接続できなくなる。Azure AD 認証でのコンテナ一覧は、TLS 1.2 にした後も問題なし（実機）。
- Tool: `Set-StorageSecurity.ps1`（`-WhatIf` で対象だけ確認、すでに TLS 1.2 以上は変更しない）。`New-StorageAccount.ps1` は、今後 TLS 1.2 と匿名アクセス無効で作る。

## ネットワーク ルール

- `DefaultAction` が `Allow` のままだと、IP ルールを追加してもアクセスは制限されない。絞るなら、IP ルールを足したうえで `Deny` にする（自分の IP が外れるとアクセスできなくなるので注意）。

## 起動診断用のストレージ

- VM を作ると、同じリージョンに標準ストレージが無い場合、起動診断用に `azureazure...` が自動で作られる（実機: `azureazurebwork112220460`）。Monitor の `Show-InboundSecurity` に出てくる。TLS 1.2 にしても、VM の起動診断は問題なし。

## 言語パックの ISO を置く（yourstorage1123、2026-11-23）

- `YourRG` に、`yourstorage1123` を作った（`yourstorage` は、世界中で一意でなければならず、すでに使われていたため、数字を足した。名前は、小文字と数字のみ）。コンテナーは `langpack`。TLS 1.2、匿名アクセス無し、HTTPS のみ。
- 認証は Entra ID（`Storage Blob Data Contributor`）。`New-StorageAccount.ps1` が、実行者に付ける。ロールの反映には、数分かかる。
- 6.39 GB の ISO を、約 10 分でアップロードできた（`Send-StorageFile.ps1`）。保管料金は、小さい（金額は、請求で確認する）。
- VM には、期限 3 時間の読み取り専用 SAS（ユーザー委任）を渡す。ダウンロードは、約 60〜70 秒。
- Monitor（`Show-InboundSecurity.ps1`）は、ネットワーク規則の既定が `Allow` のため、「注意: 全許可」と表示する。匿名アクセスは無効、認証は必須。ネットワークを絞るかは、別に決める。

