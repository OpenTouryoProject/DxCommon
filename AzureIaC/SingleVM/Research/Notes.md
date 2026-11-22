# SingleVM 調査メモ（Tool 作成・実機確認で分かったこと）

実施日: 2026-11-22。環境: Japan East、Azure PowerShell（Az.Compute 11.12.0 / Az.Network 8.4.1）。
Tool は [../Tool/README.md](../Tool/README.md)。

## Linux VM と SSH 鍵・パスワード

- `Add-AzVMSshPublicKey`（SSH 鍵）つきで作った Linux VM は、**Azure が SSH のパスワード認証を無効にする**（`DisablePasswordAuthentication = True`）。
  - sshd: `PasswordAuthentication no`（`/etc/ssh/sshd_config.d/50-cloud-init.conf` ほか）。
  - ユーザーのパスワードもロックされる（`passwd -S` が `L`）。管理者パスワードを渡しても、ログインには使えない。
- xrdp など、パスワードでログインする用途では、パスワードを別に設定する必要がある:
  - VMAccess 拡張（`Microsoft.OSTCExtensions` / `VMAccessForLinux` 1.5）に、ユーザー名とパスワードを**保護された設定**で渡す。実機で成功し、`passwd -S` が `P` になった。sshd のパスワード認証は、無効のまま（SSH は鍵のみ）。
  - Run Command で `chpasswd` する方法もあるが、スクリプトにパスワードが入るため避けた。

## xrdp（Linux のデスクトップ接続）

- インストール: `xfce4` と `xrdp`。Run Command（`RunShellScript`）で、`DEBIAN_FRONTEND=noninteractive` の `apt-get -y install`。`adduser xrdp ssl-cert`、`~/.xsession` に `xfce4-session`、`systemctl enable/restart xrdp`。Ubuntu 26.04 で成功（3389 で待ち受け）。
- **VM が外向き通信できないと `apt` が失敗する**（[../../Simplest/Research/Notes.md](../../Simplest/Research/Notes.md) の「外向き通信」参照）。一時的な Public IP を付けて入れた。
- Bastion 経由で Linux に RDP をつなぐには、Standard SKU 以上が必要（Developer / Basic は SSH のみ）。実機の Developer で RDP は出なかった。

## 直接 RDP を開けるときの安全策

- 3389 に届くのは NSG の許可だけで、認証は VM ローカルのユーザーとパスワードだけ（Azure の RBAC や MFA は関係しない）。
- Tool の方針: Windows VM と 3389 は、**送信元の IP 制限を必須**にする（`*` / `Internet` / `0.0.0.0/0` を拒否）。Linux の 22 / 80 / 443 は、制限なしでも可（警告）。
- 自分の IP が変わったら、`Update-VMAllowedIp` で、指定ポートを許可しているルールの送信元を付け替える。
- 自分の IP は、`-MyIp` で外部サービス `api.ipify.org` から取得する（使いたくないときは、IP を直接指定する）。

## Entra ID ログイン

| OS | 拡張 | 対象 | 備考 |
|---|---|---|---|
| Windows | `AADLoginForWindows`（`Microsoft.Azure.ActiveDirectory`、2.0） | RDP | マネージド ID が必要。ロール `Virtual Machine Administrator Login` / `Virtual Machine User Login`。MFA は条件付きアクセスで |
| Linux | `AADSSHLoginForLinux` | **SSH のみ** | xrdp は対象外（PAM のパスワード認証）。接続は `az ssh vm` など。拡張の導入に外向き通信が必要 |

- `.rdp` の項目（`enablerdsaadauth:i:1` / `targetisaadjoined:i:1` / `username:s:AzureAD\<UPN>`）で、**実機（WorkVM2）で Entra ID の RDP ログインに成功**した（下の「実機で確認した手順」）。
- Entra ID ログインを入れても、VM ローカルの管理者パスワードのログインは残る。
- Linux への RDP（Bastion 経由）は、Entra ID と Kerberos に非対応。

## Linux のイメージ

Japan East（2026-11-22）: Ubuntu 26.04 LTS / 24.04 LTS / 22.04 LTS が利用可（詳細は [../../Simplest/Research/Notes.md](../../Simplest/Research/Notes.md)）。

## 実機で確認した手順: Windows VM に Entra ID で RDP ログイン（2026-11-22 / 23）

対象: `WorkVM2`（Windows Server 2025、`AzureBastionRG`）。手元の PC から `mstsc`（`.rdp`）で接続。

1. VM に Public IP（Standard / 静的）と NSG を付け、3389 を自分の IP だけに開ける（`Add-VMPublicIp.ps1 -OpenPort 3389 -MyIp`）。
2. `Enable-EntraLogin.ps1`: システム割り当てマネージド ID、拡張 `AADLoginForWindows`（実機は 2.2.0.0）、ロール割り当て、`.rdp` の書き出し。
   - VM は `AzureAdJoined : YES`、イベント ログに「Device is configured for RBAC authorization」。
3. 管理者ログインには `Virtual Machine Administrator Login` が必要（`Virtual Machine User Login` は一般ユーザー）。実機: `dxuser01` に付与して管理者として入れた（`net localgroup Administrators` に `AzureAD\dxuser01` が入る）。
4. ローカル管理者の RDP ログインを止める（`Disable-LocalLogin.ps1`）。実機で、Entra ID では入れ、ローカル（`azureuser`）は拒否されることを確認した。

### つまずいた点

| エラー | 原因 | 対処 |
|---|---|---|
| `0x1808`「Web アカウントでのサインインは、NetBIOS 名か FQDN が必要。IP は不可」 | `.rdp` の接続先に IP を書いた | IP 以外の名前にする |
| `AADSTS293004` 「target-device identifier（FQDN）が、テナントに見つからない」 | Entra ID は、接続先の名前を、**デバイス名（コンピューター名）**と照合する。Public IP の DNS 名（`...cloudapp.azure.com`）は、デバイス名と一致しない | `.rdp` の接続先を**コンピューター名（`WorkVM2`）**にし、手元の PC の hosts に `<IP> WorkVM2` を足す（管理者権限で 1 回） |
| イベント ログ `urn:p2p_cert` が見つからない（AADSTS50001） | デバイス間（P2P）の証明書の更新に関するもの | 無視してよい（RDP ログインには影響しなかった） |

- `.rdp` の最終形: `full address:s:WorkVM2`、`enablerdsaadauth:i:1`、`targetisaadjoined:i:1`、`username:s:AzureAD\<UPN>`、`prompt for credentials:i:1`。
- hosts: `Add-Content C:\Windows\System32\drivers\etc\hosts "<Public IP> WorkVM2"`。Public IP が変わったら、更新する。

### ローカル アカウントの RDP を止める（Disable-LocalLogin.ps1）

- 方法: ユーザー権利「リモート デスクトップ サービスを使ったログオンを拒否する」（`SeDenyRemoteInteractiveLogonRight`）に、ローカル ユーザーを入れる（`DenyRdp`）。アカウントは有効なまま。`DisableAccount`（無効化）も選べる。
- **Bastion の RDP（パスワード接続）も拒否される**（VM から見れば同じ RDP ログオン）。Bastion は WorkVM1（Linux、SSH）にだけ使う。
- 実機の確認: 適用 → 解除（`-Enable`）→ 再適用、すべて VM 上の値で確認。Run Command（RDP と無関係）で、復旧もできる。
- `secedit /export` の出力は、SID ではなく**ユーザー名**（`azureuser`）で返る。SID で比べると、確認も解除も失敗する（実機で発生。ユーザー名と SID の両方で比べるよう修正）。
- 締め出し防止のチェック: 拡張が Succeeded / 管理者ロールの割り当て / Administrators に `AzureAD\...` がいる、を満たさなければ止まる。
- `-WhatIf` を付けても、確認用の読み取りの Run Command は実行する（`-WhatIf:$false` を渡す）。渡さないと、確認が空振りする（実機で発生）。

## 既存 VM に Public IP を付けて、RDP を開ける（2026-11-22）

- 対象: `WorkVM2`（プライベート サブネット、NIC に NSG なし）。Tool: `Add-VMPublicIp.ps1` / `Remove-VMPublicIp.ps1`。
- 手順: Public IP（`Standard` / 静的）を作る → NIC に付ける → NIC に NSG が無ければ作って関連付ける（ルールなし）→ 3389 を、自分の IP だけに許可する。
- **Standard の Public IP は、NSG で許可しない限り、受信できない**（NSG が無い NIC でも同じ）。そのため、一時的に付けて外向き通信だけに使える（Linux への xrdp のインストール時に実施）。
- Public IP の SKU は Standard のみ（Basic は 2025-09-30 に廃止）。Tool は SKU の選択肢を Standard のみにしている。
- Open-VMPort は、NIC に NSG が無いと、使えない（先に NSG が要る）。Add-VMPublicIp が、NSG の作成も行う。
- 実機の確認: `Test-NetConnection <IP> -Port 3389` が `True`。Monitor の `Show-InboundSecurity` で、受信許可は 1 件（自分の IP のみ）、[危険] なし。
- 自分の IP は、`api.ipify.org` から取得（`-MyIp`）。IP が変わったら、`Update-VMAllowedIp.ps1 -MyIp` で付け替える。
- Public IP に DNS 名（`DomainNameLabel`）を付けると、`<ラベル>.japaneast.cloudapp.azure.com` で引ける。ただし、Entra ID の RDP ログインには使えない（デバイス名が必要。上の「つまずいた点」）。ローカル アカウントで入るときの FQDN としては使える。

## 未確認 / 今後確かめること

- Linux の Entra ID ログイン（`AADSSHLoginForLinux`、SSH のみ）: 未実施。
- Bastion（Developer）の Portal RDP で、Entra ID の資格情報が通るか: 未確認（通らない可能性が高い）。
- Bastion Standard の料金の目安、Windows への SSH（Bastion Standard）: 未確認。
