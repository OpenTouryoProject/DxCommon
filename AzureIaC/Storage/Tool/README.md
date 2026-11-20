# Storage - Tool

[Research](../Research/README.md) を Azure PowerShell にしたもの。
Azure Storage（ストレージアカウントと BLOB コンテナ）を構築し、自分のアカウントが Azure AD 認証で使えるようにする。

## 前提
- PowerShell 7（または Windows PowerShell 5.1）と、`Az` モジュール（`Az.Accounts`、`Az.Resources`、`Az.Storage`）。
- `Connect-AzAccount` でサインイン済みであること。テナントが MFA 必須の場合は、MFA を通してサインインしないと、作成・削除が拒否される。
- リソースプロバイダーの登録: `Microsoft.Storage`。  
  未登録だと、ストレージアカウントの作成が `NotFound` で失敗する。
  `Test-Prerequisites.ps1` で確認でき、`Test-Prerequisites.ps1 -Register` で登録できる。

## 使い方
対話メニュー（推奨）:

```PowerShell
.\Invoke-StorageMenu.ps1
```

流れ: コマンドを選ぶ → オプションを入力する（Enter で既定値）→ 確認する → `GO` と入力して実行する。
`q` で終了、`b` で 1 つ前に戻る。読み取り専用のコマンドは Enter で実行する。

| スクリプト | Research | 内容 |
|---|---|---|
| `Test-Prerequisites.ps1` | - | モジュール、サインイン、リソースプロバイダーを確認する |
| `New-StorageAccount.ps1` | Creating | RG、ストレージアカウント、自分への `Storage Blob Data Contributor` ロール、コンテナを作成する |
| `Add-StorageNetworkRule.ps1` | Add as needed | ネットワークルールに、許可する IP アドレスを追加する |
| `Show-Storage.ps1` | - | アカウント、ロール割り当て、コンテナ、ネットワークルールを表示する（読み取り専用） |
| `Remove-StorageAccount.ps1` | - | ストレージアカウント（または、リソースグループごと）を削除する |

## 注意
- ストレージアカウント名は、グローバルで一意である必要がある（小文字の英字と数字で 3〜24 文字）。既定の `osscjpdevinfra` は、既に使われている可能性がある。
- コンテナは Azure AD 認証で作る。ロール割り当ての反映に時間がかかることがあるため、スクリプトは再試行する。
- 既定のアクション（`DefaultAction`）が `Allow` のままだと、IP ルールを追加しても、アクセスは制限されない。
- ストレージアカウントを削除すると、データも消え、元に戻せない。
