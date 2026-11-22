# Protection - Tool

[Research](../Research/README.md) を Azure PowerShell にしたもの。
リソースグループにロック（`CanNotDelete` / `ReadOnly`）を付け外しして、誤削除・誤変更を防ぐ。

## 前提
- PowerShell 7（または Windows PowerShell 5.1）と、`Az` モジュール（`Az.Accounts`、`Az.Resources`）。
- `Connect-AzAccount` でサインイン済みであること。テナントが MFA 必須の場合は、MFA を通してサインインしないと、作成・削除が拒否される。
- ロックの付け外しには、所有者などの `Microsoft.Authorization/locks/*` の権限。

## 使い方
対話メニュー（推奨）:

```PowerShell
.\Invoke-ProtectionMenu.ps1
```

流れ: コマンドを選ぶ → オプションを入力する（Enter で既定値）→ 確認する → `GO` と入力して実行する。
`q` で終了、`b` で 1 つ前に戻る。読み取り専用のコマンドは Enter で実行する。

| スクリプト | 内容 |
|---|---|
| `Test-Prerequisites.ps1` | モジュールとサインインを確認する |
| `Show-ResourceLock.ps1` | ロックの一覧と、リソースグループごとのロックの有無を表示する（読み取り専用） |
| `Set-ResourceLock.ps1` | リソースグループに `CanNotDelete`（既定）/ `ReadOnly` のロックを付ける |
| `Remove-ResourceLock.ps1` | ロックを外す（`-LockName` で 1 つだけ。省略すると、その RG のすべて） |

```PowerShell
.\Set-ResourceLock.ps1 -ResourceGroupName AzureBastionRG                       # 削除禁止
.\Set-ResourceLock.ps1 -ResourceGroupName DxCmnRG -LockLevel ReadOnly          # 変更も禁止
.\Remove-ResourceLock.ps1 -ResourceGroupName AzureBastionRG                    # 外す
.\Set-ResourceLock.ps1 -ResourceGroupName AzureBastionRG -WhatIf               # 付けずに、内容だけ確認
```

## 注意
- ロックは、いつでも `Remove-ResourceLock.ps1` で外せる（元に戻せる）。`ReadOnly` の最中でも、外せる。
- **`ReadOnly` は、VM の起動・停止・再起動、ストレージのキーの取得、リソースの追加・変更を止める。** VM を起動・停止する運用の RG には、`CanNotDelete` にする。`Set-ResourceLock.ps1` は、RG に VM があると警告する。
- ロックを付けた RG は、**削除（`Remove-Simplest.ps1` など）や、`Set-StorageSecurity.ps1` のような変更も止まる**。片付けや変更の前に、外す。
- 同じ RG に、`CanNotDelete` と `ReadOnly` を併用できる（厳しい方が効く）。
- 実機で確認した動作（付ける / 効く / 外す / 削除）は、[Research](../Research/README.md) の「実機の確認」に記録した。
