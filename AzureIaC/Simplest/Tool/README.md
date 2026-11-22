# Simplest - Tool

[Research](../Research/README.md) を Azure PowerShell にしたもの。
Azure Bastion、Jumpbox VM、サンドボックス VM、およびその間の VNet ピアリングを構築する。

## 前提
- PowerShell 7（または Windows PowerShell 5.1）と、`Az` モジュール（`Az.Accounts`、`Az.Resources`、`Az.Network`、`Az.Compute`）。
- `Connect-AzAccount` でサインイン済みであること。テナントが MFA 必須の場合は、MFA を通してサインインしないと、作成・削除が拒否される。
- リソースプロバイダーの登録: `Microsoft.Network`、`Microsoft.Compute`、`Microsoft.DevTestLab`。  
  `Test-Prerequisites.ps1` で確認でき、未登録のものは `Test-Prerequisites.ps1 -Register` で登録できる。

## 使い方
対話メニュー（推奨）:

```PowerShell
.\Invoke-SimplestMenu.ps1
```

流れ: コマンドを選ぶ → オプションを入力する（Enter で既定値）→ 確認する → `GO` と入力して実行する。
`q` で終了、`b` で 1 つ前に戻る。読み取り専用のコマンドは Enter で実行する。

各スクリプトは単独でも実行できる。初回は次の順に実行する。

| 順 | スクリプト | Research | 内容 |
|---|---|---|---|
| 0 | `Test-Prerequisites.ps1` | - | モジュール、サインイン、リソースプロバイダーを確認する |
| 1 | `New-Bastion.ps1` | `1.common.sh` | RG、VNet、Public IP、Bastion、Jumpbox 用サブネットを作成する。`-BastionSku Developer`（既定・無料）/ `Basic` / `Standard` で SKU を選ぶ |
| 2 | `New-JumpboxVM.ps1` | `2.jumpbox_vm.sh` | Jumpbox VM（パブリック IP なし。Windows / Linux）を作成し、自動シャットダウンを設定する。`-InstallXrdp` で Linux に xfce4 と xrdp も入れる |
| 3 | `New-Sandbox.ps1` | `3.sandbox.sh` | RG、VNet、VM（パブリック IP なし。Windows / Linux）を作成し、自動シャットダウンを設定する。`-InstallXrdp` も使える |
| 4 | `New-VnetPeering.ps1` | `4.vnet_peering.sh` | VNet を双方向にピアリングし、`PeeringState` を表示する |
| - | `Show-Simplest.ps1` | - | 状態を表示する（読み取り専用） |
| - | `Set-VMPower.ps1` | - | VM を起動 / 停止（割り当て解除）/ 再起動する |
| - | `Remove-Simplest.ps1` | - | リソースグループを中身ごと削除する |

## 注意
- Linux（`Ubuntu2204`）の VM は、SSH 鍵（`-SshKeyPath`、既定 `~/.ssh/<VM名>`）を作って登録する。SSH はパスワード認証が無効（鍵のみ）。
- `-InstallXrdp` は、Run Command で xfce4 と xrdp を入れる（数分）。3389 の受信は開けない。VNet 内の別 VM などから、管理者のユーザーとパスワード（`-InstallXrdp` が設定）で接続する。
- VM 作成まわり（イメージ表、SSH 鍵、xrdp、自動シャットダウンなど）は、SingleVM と共通の `AzureIaC\Common\Vm.Common.ps1` を使う。
- 作成系のスクリプトは、既に存在するリソースをスキップする。
- 管理者のユーザー名とパスワードは、実行時に `Get-Credential` で入力する（`-Credential` で渡すこともできる）。コマンドラインには書かない。
- 自動シャットダウンの既定は `1500`（UTC）= JST 0 時。設定しない場合は `-NoAutoShutdown` を付ける。
- Bastion の SKU: `Developer` は無料（開発・テスト向け。共有インフラを使うので専用サブネットも Public IP も不要。同時接続は 1 つで、VNet ピアリング越しの接続などに制限がある。
  Az の `New-AzBastion` が未対応のため REST で作る）。`Basic` / `Standard` は、存在する間ずっと課金される（作成に 10 分前後かかる）。不要になったら `Remove-Simplest.ps1` で削除する。
- 使えるイメージ: `Win2019Datacenter`、`Win2022Datacenter`、`Ubuntu2604`（Ubuntu 26.04 LTS）、`Ubuntu2404`、`Ubuntu2204`。
