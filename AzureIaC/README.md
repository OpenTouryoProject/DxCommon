# AzureIaC
Azure の IaC で構築する、共通基盤相当のもの。

各フォルダは 2 つの部分でできている。
- `Research` : 調査した手順（Azure CLI / Azure PowerShell のコマンド）。
- `Tool` : 同じ手順を Azure PowerShell のスクリプトにしたもの。対話メニュー（`Invoke-*Menu.ps1`）つき。

| フォルダ | Research | Tool |
|---|---|---|
| SingleVM | [Research](./SingleVM/Research/README.md) | [Tool](./SingleVM/Tool/README.md) |
| Storage | [Research](./Storage/Research/README.md) | [Tool](./Storage/Tool/README.md) |
| Simplest | [Research](./Simplest/Research/README.md) | [Tool](./Simplest/Tool/README.md) |
| AddUsers | [Research](./AddUsers/Research/README.md) | [Tool](./AddUsers/Tool/README.md) |
| Monitor | [Research](./Monitor/Research/README.md) | [Tool](./Monitor/Tool/README.md)（セキュリティ / 課金の監視。読み取り専用） |

## クイックスタート（Tool）
1. Azure PowerShell でサインインする。テナントが MFA 必須の場合は、MFA を通してサインインする。

    ```PowerShell
    Connect-AzAccount
    ```

2. 最上位のメニューを起動して、使う Tool を選ぶ。各 Tool のメニューには、モジュールとリソースプロバイダーを確認する `Test-Prerequisites` がある。

    ```PowerShell
    .\Invoke-AzureIaCMenu.ps1
    ```

作成系は課金を伴い、削除系は元に戻せない。どのメニューも、実行するコマンドラインを表示してから、`GO` の入力を求める。
