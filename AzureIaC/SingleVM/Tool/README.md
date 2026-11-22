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
| `New-SingleVM.ps1` | `Windows.md` / `Linux.md` | RG、ネットワーク、VM を作成する。`-InstallXrdp` で Linux に xfce4 と xrdp も入れる |
| `Open-VMPort.ps1` | `az vm open-port` | VM の NSG に、受信を許可するルールを追加する。Windows VM と 3389 は、送信元の IP 制限が必須（`-SourceAddressPrefix` か `-MyIp`） |
| `Update-VMAllowedIp.ps1` | - | 自分の IP が変わったとき、開けてあるポートの許可元の IP を付け替える（`-MyIp`） |
| `Enable-EntraLogin.ps1` | - | Windows VM に、Entra ID での RDP ログインを設定する（マネージド ID・拡張機能 `AADLoginForWindows`・ロール割り当て・`.rdp` 出力） |
| `Show-VMInfo.ps1` | - | 状態、パブリック IP、NSG ルールを表示する（読み取り専用） |
| `Set-VMPower.ps1` | - | VM を起動 / 停止（割り当て解除）/ 再起動する |
| `Remove-SingleVM.ps1` | - | VM と、NIC・Public IP・NSG・VNet・ディスク・SSH キーを削除する |

## 注意
- VM 作成まわり（イメージ表、SSH 鍵、xrdp、自動シャットダウンなど）は、Simplest と共通の `AzureIaC\Common\Vm.Common.ps1` を使う。
- 管理者のユーザー名とパスワードは、実行時に `Get-Credential` で入力する（`-Credential` で渡すこともできる）。
- Windows: NSG で RDP（3389）を許可する。Linux: `ssh-keygen` で SSH 鍵を作り（パスフレーズを聞かれる）、
  公開鍵を Azure の SSH キー `<VmName>-sshkey` に登録して、SSH（22）を許可する。
  SSH はパスワード認証が無効（鍵のみ）。xrdp 用のパスワードは、`-InstallXrdp` が VMAccess 拡張で設定する。
- 直接 RDP を開ける場合の流れ（Windows）: `New-SingleVM.ps1 -MyIp`（または `-SourceAddressPrefix`）→ 必要なら `Enable-EntraLogin.ps1` → IP が変わったら `Update-VMAllowedIp.ps1 -MyIp`。
- 送信元の IP 制限は、Windows VM と 3389 では必須で、`*` / `Internet` / `0.0.0.0/0` は拒否する。Linux の 3389 以外（22 など）は、制限なしでも開けられる（警告）。
- `-MyIp` は、自分のグローバル IP を外部サービス `api.ipify.org` に問い合わせて調べる。使いたくない場合は、`-SourceAddressPrefix` で IP を直接指定する。
- `Enable-EntraLogin.ps1` を使っても、VM ローカルの管理者パスワードでのログインは残る。MFA を求めたい場合は、条件付きアクセスで「Azure Windows VM Sign-In」に MFA を要求する。
  `.rdp` の項目（`enablerdsaadauth` / `targetisaadjoined`）は、実機での確認はこれから。つながらない場合は、ユーザー名を `AzureAD\<UPN>` にしてパスワードで入る。
- `Remove-SingleVM.ps1` は、他と共有している可能性があるため、名前が VM 名で始まる NIC・Public IP・NSG・VNet だけを削除する。
- 使えるイメージ: `Win2019Datacenter`、`Win2022Datacenter`、`Ubuntu2604`（Ubuntu 26.04 LTS）、`Ubuntu2404`、`Ubuntu2204`。
- Linux の xrdp は `-InstallXrdp` で入れられる（3389 は開かないので、`Open-VMPort.ps1` で接続元を絞って開ける）。ロケールやブラウザは、今のところ手作業。[Linux.md](../Research/Linux.md) を参照。
