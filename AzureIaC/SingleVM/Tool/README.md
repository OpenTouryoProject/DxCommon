# SingleVM - Tool

[Research](../Research/README.md) を Azure PowerShell にしたもの。
単体の Azure VM（Windows または Linux）を、専用の VNet・Public IP・NSG つきで構築する。

## 前提
- PowerShell 7（または Windows PowerShell 5.1）と、`Az` モジュール（`Az.Accounts`、`Az.Resources`、`Az.Network`、`Az.Compute`）。
- `Connect-AzAccount` でサインイン済みであること。テナントが MFA 必須の場合は、MFA を通してサインインしないと、作成・削除が拒否される。
- リソースプロバイダーの登録: `Microsoft.Network`、`Microsoft.Compute`。  
  `Test-Prerequisites.ps1` で確認でき、未登録のものは `Test-Prerequisites.ps1 -Register` で登録できる。
- Linux のみ: `ssh-keygen`（OpenSSH クライアント）。

## 使い方
対話メニュー（推奨）:

```PowerShell
.\Invoke-SingleVMMenu.ps1
```

流れ: コマンドを選ぶ → オプションを入力する（Enter で既定値）→ 確認する → `GO` と入力して実行する。
`q` で終了、`b` で 1 つ前に戻る。読み取り専用のコマンドは Enter で実行する。

| スクリプト | Research | 内容 |
|---|---|---|
| `Test-Prerequisites.ps1` | - | モジュール、サインイン、リソースプロバイダーを確認する |
| `Show-VMCatalog.ps1` | Define2 | VM サイズ、または対応するイメージを一覧表示する |
| `New-SingleVM.ps1` | `Windows.md` / `Linux.md` | RG、ネットワーク、VM を作成する |
| `Open-VMPort.ps1` | `az vm open-port` | VM の NSG に、受信を許可するルールを追加する（xrdp 用の 3389 など） |
| `Show-VMInfo.ps1` | - | 状態、パブリック IP、NSG ルールを表示する（読み取り専用） |
| `Set-VMPower.ps1` | - | VM を起動 / 停止（割り当て解除）/ 再起動する |
| `Remove-SingleVM.ps1` | - | VM と、NIC・Public IP・NSG・VNet・ディスク・SSH キーを削除する |

## 注意
- 管理者のユーザー名とパスワードは、実行時に `Get-Credential` で入力する（`-Credential` で渡すこともできる）。
- Windows: NSG で RDP（3389）を許可する。Linux: `ssh-keygen` で SSH 鍵を作り（パスフレーズを聞かれる）、
  公開鍵を Azure の SSH キー `<VmName>-sshkey` に登録して、SSH（22）を許可する。
  xrdp でログインできるように、パスワード認証は有効のままにしている。
- `Open-VMPort.ps1` は、送信元の既定が `*`（全許可）。可能なら `-SourceAddressPrefix` で、自分の IP や CIDR に絞る。
- `Remove-SingleVM.ps1` は、他と共有している可能性があるため、名前が VM 名で始まる NIC・Public IP・NSG・VNet だけを削除する。
- 使えるイメージ: `Win2019Datacenter`、`Win2022Datacenter`、`Ubuntu2204`。
- Linux の構築後の設定（xrdp、ロケール、ブラウザ）は、今のところ手作業。[Linux.md](../Research/Linux.md) を参照。
