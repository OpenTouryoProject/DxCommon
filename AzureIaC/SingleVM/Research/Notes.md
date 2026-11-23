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

## VM の日本語化（Set-VMLocale.ps1、2026-11-23）

対象: `JumpboxVM1`（Windows Server 2025、プライベート サブネット）。Run Command で、VM の中を設定した（RDP / SSH は不要）。

### Windows の手順（実機で成功）
```PowerShell
Import-Module LanguagePackManagement
Install-Language -Language ja-JP          # 言語パック（Windows Update から取得）
Set-SystemPreferredUILanguage ja-JP       # システムの表示言語
Set-WinSystemLocale ja-JP
Set-Culture ja-JP
Set-WinHomeLocation -GeoId 122            # 日本
Set-TimeZone -Id 'Tokyo Standard Time'
Copy-UserInternationalSettingsToSystem -WelcomeScreen $true -NewUser $true   # ようこそ画面と新規ユーザーへ
Restart-Computer
```
- `LanguagePackManagement`（`Install-Language`）は、Windows Server 2025 に標準で入っていた。
- 結果（再起動後）: UI / ロケール / カルチャが `ja-JP`、タイムゾーンが `Tokyo Standard Time`、GeoId が `122`。`Language.Basic` / `Handwriting` / `OCR` / `Speech` / `TextToSpeech`（`ja-JP`）が `Installed`、`C:/Windows/System32/ja-JP` に 1,627 ファイル。
- **所要時間**: 初回は、言語パックの取得で、約 1 時間（01:38〜02:40 ごろ）かかった。Run Command の上限（約 90 分）に近い。導入済みの 2 回目は、約 6 分（Public IP の付け外しと再起動が大半）。
- 日本語キーボード（IME）の既定は設定していない。Bastion のブラウザ RDP での日本語入力は、未確認。

### 注意点
- **インターネットに出られる必要がある**（Windows Update）。プライベート サブネットの VM は出られないので、一時的な Public IP を付けて、終わったら削除する（[Simplest の調査メモ](../../Simplest/Research/Notes.md) の「外向き通信」）。
- Run Command は SYSTEM として動くため、**ユーザー単位の設定（既存ユーザーの表示言語や書式）は変わらない**。ようこそ画面と新規ユーザーには反映される。既存ユーザーは、ログイン後に確認する。
- Run Command は、同時に 1 つしか実行できない。実行中は、別の Run Command で、進行状況を見られない。
- Run Command の出力に日本語（UTF-8）を含めると、**文字化け**する（ラベルが `繧ｷ繧ｹ...` のようになる）。出力は ASCII にする。
- `Get-InstalledLanguage` は、Run Command（SYSTEM）の中では、空を返した。インストール済みの確認には、`Get-WindowsCapability -Online -Name "Language.*ja-JP*"` を使う。
- Linux（Ubuntu）: `language-pack-ja`、`fonts-noto-cjk`、`locale-gen ja_JP.UTF-8`、`update-locale`、`timedatectl set-timezone Asia/Tokyo`（未実機）。

## 一時 Public IP の共通化（2026-11-23）

- Run Command で VM の中を設定する処理（xrdp のインストール、日本語化）は、どちらも**インターネットに出られる必要**がある。
- 共通関数 `Invoke-WithTempPublicIp`（`Common/Vm.Common.ps1`）に切り出した: VM の中から出られるかを確認 → 出られなければ、一時 Public IP（Standard / 静的）を付ける → 処理 → **`finally` で、外して削除する**（処理が失敗しても削除する）。`-Disable` で、付けずに止まる。
- 実機で確認（Windows）: 付与 → 処理 → 削除 → 再起動 → 確認、が動いた。終了後に一時 Public IP が残らない。Linux（`Install-Xrdp` から使う形）は、実機では未確認。
- `Get-VmNic` / `Test-VmIsLinux` を `Vm.Common.ps1` に移した（Simplest からも使える）。

## PowerShell 7 の組み込み変数との衝突

- `$IsLinux` / `$IsWindows` / `$IsMacOS` は、PowerShell 7 の**読み取り専用（定数）の自動変数**。大文字小文字を区別しないので、スクリプトで `$isLinux = ...` と代入すると、`変数 IsLinux は読み取り専用または定数であるため、上書きできません。` で、**PowerShell 7 でだけ**落ちる（5.1 では動く）。
- 関数のパラメーター名（`[bool]$IsLinux`）も同様に避ける。実機で `Show-VMInfo.ps1`（既存）と `Set-VMLocale.ps1` で発生した。`$vmIsLinux` / `$osIsLinux` に変えた。
- 見つける方法: `grep -rn '\$isLinux'`（ハッシュテーブルの `.IsLinux` プロパティは問題ない）。

## VM サイズ（SKU）と OS ディスクの指定（2026-11-23）

- `Set-VMSize.ps1`: サイズの提供状況（`Restrictions`）、ファミリの vCPU クォータ、一時ディスクの あり ⇔ なし を、停止する前に確認する。起動中の VM は、停止（割り当て解除）→ `Update-AzVM` → 起動。失敗しても、元の状態で起動し直す。詳細は [Simplest の調査メモ](../../Simplest/Research/Notes.md) の「VM サイズとクォータ」。
- `New-VmConfig` / `New-SingleVM` / `New-Sandbox` / `New-JumpboxVM`: `-OsDiskSizeGb`（GB）と `-OsDiskType`（`StandardSSD_LRS` / `Premium_LRS` / `Standard_LRS`）を追加した。指定しなければ、これまでどおり（イメージと Azure の既定）。
- `Expand-WindowsOsPartition`: Windows で、OS ディスクを大きくしたときに、C ドライブをディスクいっぱいまで広げる（Run Command）。

## YourVM1 での再確認（2026-11-23）

- 手順: 起動 → `Enable-EntraLogin.ps1 -UserPrincipalName <UPN>` → `Add-VMPublicIp.ps1 -OpenPort 3389 -MyIp` → mstsc で Entra ID ログイン → `Disable-LocalLogin.ps1`。WorkVM2 と同じ手順で、そのまま成功した。
- `-UserPrincipalName` を省くと、管理者ロールは付かない。`Disable-LocalLogin.ps1` は、ロールが無いと中止する。
- **Administrators の確認の修正**: Entra ID のユーザーは、`net localgroup Administrators` に SID（`S-1-12-1-...`、`Get-LocalGroupMember` の `PrincipalSource` が `AzureAD`）で出ることがある。`AzureAD\` の名前だけを見ていたため、ログイン済みでも「いない」と中止した。名前と SID の両方を見るようにした。
- 設定変更の確認は、いったん切って、Entra ID で再ログインして行った（ローカルを拒否した後も入れた）。
- `*.rdp`（IP とユーザー名を含む）は、ルートの `.gitignore` に追加した。


## 言語パックの事前取得（方針、2026-11-23）

- 日本語化（`Set-VMLocale.ps1`）の言語パックの取得は、Windows Update 経由で、初回は約 1 時間、2 回目以降は約 6 分かかった。
- **採用する方式**: Windows Server 2025 の「Languages and Optional Features」ISO を Storage に置き、VM からそこを `-Source` にして入れる（`Add-WindowsCapability -Online -Name Language.Basic~~~ja-JP~0.1.0.0 -Source <マウントしたISO> -LimitAccess`）。
- **採用しなかった方式**: sysprep + Compute Gallery のイメージ、ディスクのスナップショット。理由: 展開数が限られ、イメージが陳腐化する（OS の更新に追従し続けるコストの方が大きい）。
- 調査結果（出典は、検索で確認したもの。未検証を含む）:
  - ISO は、Windows Server 2025 から、言語パックと Features on Demand が 1 つになった。入手先は Microsoft Evaluation Center（評価版のページ）とされる。個別の掲載・直リンクは、未確認。
  - ISO のバージョンは、VM の Windows のビルドに合わせる。
  - ISO から `.cab` を手でコピーしたフォルダーは、リポジトリとして使えない。ISO のままマウントするか、`DISM /export-source` で作る。
- 未確認: `ja-JP` が ISO に入っているか、Azure の Windows Server 2025 のビルドと ISO が合うか、Run Command（SYSTEM）での ISO のマウント（`Mount-DiskImage`）。
- 実装の予定: ISO の Storage へのアップロード（Storage の Tool）、`Set-VMLocale.ps1` の `-LanguageSource`（短期の SAS URL で VM にダウンロード → マウント → インストール）。ISO は、利用者が手動で入手する。
