# Simplest 調査メモ（Tool 作成・実機確認で分かったこと）

実施日: 2026-11-22。環境: Japan East、Azure サブスクリプション（個人検証用）、Azure PowerShell（Az.Network 8.4.1 / Az.Compute 11.12.0）。
Tool は [../Tool/README.md](../Tool/README.md)。

## Bastion の SKU

| SKU | 料金 | VNet / サブネット | Public IP | 備考 |
|---|---|---|---|---|
| Developer | 無料 | 専用サブネット不要（共有インフラ） | 不要 | 開発・テスト向け。同時接続は 1 VM。**VNet ピアリング越しは不可** |
| Basic | 時間課金（存在する間ずっと） | `AzureBastionSubnet`（/26 以上） | Standard / 静的 | ブラウザ接続のみ |
| Standard / Premium | Basic より高い | 同上 | 同上 | ネイティブ クライアント、ホスト スケーリング、任意ポート・プロトコルなど |

出典: https://learn.microsoft.com/azure/bastion/bastion-sku-comparison

### 接続方法（OS 別）

ブラウザ（Azure Portal の HTML5 クライアント）:

| 接続 | Developer | Basic | Standard / Premium |
|---|---|---|---|
| Windows に RDP | ○（同時 1 VM） | ○ | ○ |
| Linux に SSH | ○（同時 1 VM） | ○ | ○ |
| Linux に RDP（xrdp） | × | × | ○ |
| Windows に SSH | × | × | ○（未確認） |

ネイティブ クライアント（手元の `mstsc` / `ssh`、Azure CLI のトンネル経由）:

| 接続 | Developer | Basic | Standard / Premium |
|---|---|---|---|
| Windows に RDP（`az network bastion rdp`） | × | × | ○ |
| Linux に SSH（`az network bastion ssh`） | × | × | ○ |
| Linux に RDP（`az network bastion rdp`） | × | × | ×（コマンドが Linux に非対応） |
| 任意ポートのトンネル（`az network bastion tunnel`） | × | × | ○（Linux の 3389 を手元に転送できる） |

- Linux への RDP は、ユーザー名とパスワードのみ。Entra ID と Kerberos は使えない。
- 実機: Developer の Portal 接続画面に、Linux VM（`WorkVM1`）の RDP は出なかった（SSH のみ）。
- 出典: https://learn.microsoft.com/azure/bastion/bastion-connect-vm-linux-rdp

## Developer SKU の作成

- `New-AzBastion`（Az.Network 8.4.1）は `-Sku` が Basic / Standard / Premium のみで、**Developer に未対応**。かつ Public IP が必須。
- REST で作る（実機で成功。Japan East で利用可）:

```
PUT /subscriptions/{sub}/resourceGroups/{rg}/providers/Microsoft.Network/bastionHosts/{name}?api-version=2024-05-01
{ "location": "japaneast", "sku": { "name": "Developer" }, "properties": { "virtualNetwork": { "id": "<VNet の ID>" } } }
```

- VNet さえあればよい（`AzureBastionSubnet` も Public IP も不要）。作成は、数十秒〜数分。
- Developer は同じ VNet の VM にしか入れないため、**作業用 VM は Bastion と同じ VNet に置く**と、Jumpbox とピアリングが不要になる。

## Basic の作成失敗（3 回）

- `New-AzBastion -Sku Basic` が、3 回とも `InternalServerError`（`An error occurred.`）で `Failed` になった（RG・VNet・Public IP は正常）。
- 失敗状態の Bastion は、同名で作り直せないため、削除してから再作成した。3 回目も同じで、原因は特定できていない（このサブスクリプション / リージョンでの Basic の問題の可能性）。
- 対処: 失敗した RG を削除して、Developer で作り直した（成功）。

## 外向き通信（既定のアウトバウンド アクセス）

- 新しい VNet のサブネットは、`DefaultOutboundAccess = False`（プライベート サブネット）。
- Public IP も NAT Gateway も無い VM は、DNS は引けるが、インターネットに出られない（`apt` が Ubuntu のミラーに TCP 80 でつなげない）。Bastion・SSH・VNet 内の通信には影響しない。
- 対処: (1) NIC に一時的な Public IP を付けて作業し、終わったら外して削除する。(2) サブネットに NAT Gateway を付ける（常時課金）。
- Standard の Public IP は、NSG で許可しない限り、受信できない（NSG が無い NIC でも同じ）。

## Linux VM のイメージ

- Japan East で確認（2026-11-22）: Ubuntu 26.04 LTS（`ubuntu-26_04-lts` / `server`）、24.04 LTS（`ubuntu-24_04-lts` / `server`）。22.04 は `0001-com-ubuntu-server-jammy` / `22_04-lts`。
- Tool の既定の選択肢: `Ubuntu2604` / `Ubuntu2404` / `Ubuntu2204`、`Win2019Datacenter` / `Win2022Datacenter`。

## そのほか

- VM を作ると、同じリージョンに標準ストレージが無い場合、起動診断用のストレージアカウント（`azureazure...`）が自動で作られる。最小 TLS は TLS 1.0 で作られるため、`Storage\Tool\Set-StorageSecurity.ps1` で上げる。
- 課金（Cost Management）上、「Virtual Network」の請求の大半は、Bastion（Basic 以上）と Public IP によるものと思われる。使わないときは削除する。

## Developer の「同時 1 VM」の単位（未確定）

- [SKU の比較](https://learn.microsoft.com/azure/bastion/bastion-sku-comparison): 「一度に 1 台の VM にしかアクセスできない」「共有リソースを使い、同時に 1 VM への接続のみ」。**User 単位か Subscription 単位かは、書かれていない**。
- 2023 年の [Tech Community の記事](https://techcommunity.microsoft.com/blog/azurenetworkingblog/secure-access-to-your-azure-virtual-machines-for-free-with/4146526): 「VNet ごとに、一度に 1 台の VM」。古い記述の可能性がある。
- 共有プールのホストを使い、専用ホストを持たないため、**VNet（Bastion のリソース）単位**が有力。ただし未確認（検索結果の要約ベースで、公式ページ本体は直接確認していない）。
- 実機で確かめる方法: 同じ VNet の `WorkVM1`（Linux）と `WorkVM2`（Windows）に、2 つのアカウント（`dxuser01` と管理者）から、別々に同時接続できるかを試す。同時にできれば User 単位、できなければ VNet / Bastion 単位。**結果が出たら、ここに追記する**。

## Windows の踏み台と RDS ライセンス（一般知識。未確認）

- Windows Server は、管理用途なら、同時 2 セッションまで RDS ライセンスなしで RDP できる。3 セッション以上や、一般ユーザーの同時利用には、RDS の役割と **RDS CAL（ユーザー / デバイス）**が要る。Azure の VM 料金には、CAL は含まれない。
- Developer の Bastion でスケールさせる場合、**ライセンスより先に、Bastion の制約（同時 1 VM、ピアリング越し不可）が効く**。スケールするなら、Basic（2 ホスト固定）か、Standard（ホスト スケーリング 2〜50）。

| 構成 | ボトルネック |
|---|---|
| Developer + Windows 踏み台 1 台 | Bastion の同時 1 VM |
| Basic / Standard + Windows 踏み台を多人数で共有 | RDS CAL |
| Basic / Standard + 人（用途）ごとの作業用 VM に直接入る | ほぼ無し（Bastion の同時セッション数の範囲） |
| Linux の踏み台（SSH） | RDS CAL は不要 |

- 設計の方針: Windows の踏み台を共有せず、人（や用途）ごとに VM を作る。多人数のデスクトップ共有なら、Azure Virtual Desktop（マルチセッション）が向く（ライセンスは Microsoft 365 などに含まれる場合がある。未確認）。
- CAL の要否は、契約形態で変わる。本番の前に、Microsoft の公式ドキュメントかライセンスの窓口で確認すること。

## 実機の作成記録（2026-11-22）

- `WorkVM1`: Ubuntu 26.04 LTS、`AzureBastionRG` / `AzureBastionVnet` / `JumpboxSubnet`、Public IP なし。`dxuser01`（サブスクリプション スコープのカスタム ロール「仮想マシンの起動と停止」）で、停止（割り当て解除）できた。
- `WorkVM2`: Windows Server 2025（`2025-datacenter`）、同じサブネット。Windows Server 2025 は、Japan East で `2025-datacenter` / `2025-datacenter-azure-edition` / `2025-datacenter-g2` が利用可。
- VM を作るたびに、起動診断用のストレージ（`azureazure...`）が自動で作られ、毎回 TLS 1.0 だった（`WorkVM2` で 2 つ目）。作成後に `Storage\Tool\Set-StorageSecurity.ps1` で TLS 1.2 に上げた。

## 実機の追記（2026-11-23）

- `WorkVM2` に、Public IP と、自分の IP 限定の 3389 を追加して、Entra ID で RDP ログインできた（手順は [SingleVM の調査メモ](../../SingleVM/Research/Notes.md)）。
- ローカル アカウントの RDP を拒否（`DenyRdp`）すると、**Bastion の RDP（パスワード接続）も入れなくなる**。Bastion（Developer）は、Linux（SSH）にだけ使う運用になる。
- Developer の Bastion の「同時 1 VM」の単位（User / VNet / Subscription）は、まだ実機で確かめていない（上の「Developer の『同時 1 VM』の単位（未確定）」）。
- Bastion を使わずに Public IP + IP 制限 + Entra ID で入る構成は、Bastion の課金（Basic 以上）も Developer の制約も受けない。

## Bastion Basic の再テスト（2026-11-23）

- `AzureBastionRG` と `DxCmnRG` を、RG ごと削除（`Remove-Simplest.ps1` / `Remove-StorageAccount.ps1 -RemoveResourceGroup`）した後、まっさらな状態から Basic を作り直したら、**成功した**（`Succeeded`、ScaleUnit 2）。以前の 3 回の失敗（`InternalServerError`）との違いは、削除直後に同じ名前の RG を作り直したか、まっさらからかだけ。原因は未特定（バックエンドの一時的な不調、または削除直後の再作成に弱い問題の可能性。仮説）。
- 失敗が続いたときの対処: RG ごと削除して、時間を置いてから、まっさらな状態で作る。
- Basic: 専用ホスト（2 ホスト固定、40 RDP / 80 SSH セッション）。存在する間、課金される（Public IP も）。
- `JumpboxVM1`（Windows Server 2025、`JumpboxSubnet`）に、**Bastion（Basic）の Portal から接続できた**（ブラウザ RDP）。
- 日本語化は [SingleVM の調査メモ](../../SingleVM/Research/Notes.md) の「VM の日本語化」。

## Windows のクライアント OS（一般知識 + Marketplace の確認）

- Japan East の Marketplace（`MicrosoftWindowsDesktop`）に、Windows 11 / 10 がある（確認）: `windows-11` の `win11-25h2-pro` / `win11-26h2-pro` / `win11-25h2-ent` / `win11-24h2-ent-ltsc` ほか。マルチセッションの `-avd` は、Azure Virtual Desktop 前提。
- **ライセンス（未確認の一般知識）**: Azure の VM 料金に、クライアント OS のライセンスは含まれない。Microsoft 365 E3 / E5 / F3 / Business Premium、Windows VDA、または Azure Dev/Test（Visual Studio サブスクリプション）などの資格が要る。通常の従量課金のサブスクリプションでは、資格の確認が先。
- 技術面（未確認）: Windows 11 は、第 2 世代 VM と Trusted Launch が必要。`Standard_D4s_v3` は第 2 世代に対応。RDP は同時 1 セッション。
- 開発用途では、Microsoft Dev Box（ライセンス込みの開発用ワークステーション）という別のサービスもある。
- Tool には、まだ追加していない（ライセンスの確認が先）。

## 起動診断用ストレージ（再掲）

- VM を作るたびに、起動診断用のストレージ（`azureazure...`）が自動で作られ、毎回 TLS 1.0 だった（3 回目: `JumpboxVM1`）。作成後に `Storage/Tool/Set-StorageSecurity.ps1` で TLS 1.2 に上げる。作成スクリプトの中で、自動で行う案は、未対応。

## 作業用 VNet とピアリング（2026-11-23、Bastion Basic）

構成: `AzureBastionRG`（`AzureBastionVnet` 10.0.0.0/16: Bastion Basic、`JumpboxVM1`）⇄ ピアリング ⇄ `YourRG`（`YourVnet` 10.1.0.0/16: `YourVM1`）。

- `New-Sandbox.ps1`（RG / VNet / VM）→ `New-VnetPeering.ps1`（双方向。`PeeringState` が `Connected`）。
- **Bastion Basic から、ピアリング越しの VM（`YourVM1`）に接続できた（ブラウザ RDP）。** Developer では不可だった構成。
- 未確認: 複数の VM に、同時に接続できるか（Basic は専用ホスト 2 台で、複数セッションに対応するはず）。

### VM サイズとクォータ

- **新しいサブスクリプションは、ファミリごとの vCPU クォータの既定が 0 のことがある。** 実機: `Standard DSv5 Family vCPUs` の上限が 0（Japan East / Japan West / East Asia / Southeast Asia / East US / West US 2 のすべて）。`Standard_D4s_v5` / `D2s_v5` は、作成できなかった。上限が 10 だったのは、`DSv3` / `DSv4` / `Dsv6` / `Dsv7` など。
- 確認方法: `Get-AzVMUsage -Location japaneast`（`Name.Value` がファミリ名）、`Get-AzComputeResourceSku`（`Family` / `Restrictions` / `Capabilities`）。引き上げは、Azure Portal の「クォータ」から申請する（所要時間は未確認）。
- 採用: 作業用 `YourVM1` は `Standard_D4s_v4`（v5 と同等の 4 vCPU / 16 GB）。
- **サイズ変更で、「一時ディスク（リソース ディスク）あり ⇔ なし」は不可**（`OperationNotAllowed: changing from resource disk to non-resource disk VM size and vice-versa is not allowed`）。
  - 一時ディスクあり: `Dsv3`（`D4s_v3` は 32 GB、`D2s_v3` は 16 GB）、`Ddsv4`。なし: `Dsv4`、`Dsv5`。
  - 実機: `JumpboxVM1` を `D4s_v3` → `D2s_v4` にしようとして失敗した。同じ種類の `D2s_v3` へは変更できた（約 3 分、停止 → 変更 → 起動）。
  - `Set-VMSize.ps1` は、停止する前に、一時ディスクの有無（`MaxResourceVolumeMB`）を確認し、失敗したときは、元のサイズで起動し直す。

### OS ディスク（C ドライブ）

- `Set-AzVMOSDisk -CreateOption FromImage -DiskSizeInGB 256 -StorageAccountType StandardSSD_LRS` で、256 GB の Standard SSD にできた（Windows イメージの既定は 127 GB、Premium_LRS）。
- ディスクを大きくしても、Windows の C ドライブ（パーティション）は、自動では広がらない想定。作成後に Run Command で、`Resize-Partition -DriveLetter C -Size (Get-PartitionSupportedSize -DriveLetter C).SizeMax` を実行する（`Expand-WindowsOsPartition`）。実機: 広げた後の C ドライブは 255.5 GB（空き 237.3 GB）。広げる前の大きさは、確認していない。
- 起動診断用のストレージ（`azureyourrgyour...`）が、また自動で作られた（TLS 1.0）。作成後に、`Set-StorageSecurity.ps1` で TLS 1.2 に上げた。

## 構成（スペック）メモ: JumpboxVM と（開発）作業用 VM（2026-11-23 時点）

実機で作って確認した構成。作り直すときの基準にする。`JumpboxVM1` は、`AzureBastionRG` ごと削除済み（取得できた値と、作成時の指定から記録）。

### JumpboxVM（`JumpboxVM1`、Bastion の VNet 内）

| 項目 | 内容 |
|---|---|
| 配置 | `AzureBastionRG` / `AzureBastionVnet`（10.0.0.0/16）/ `JumpboxSubnet`（10.0.1.0/24） |
| OS | Windows Server 2025 Datacenter（`MicrosoftWindowsServer` / `WindowsServer` / `2025-datacenter`） |
| サイズ | `Standard_D2s_v3`（2 vCPU / 8 GB / 一時ディスク 16 GB）。作成時は `D4s_v3`、`Set-VMSize.ps1` で変更 |
| OS ディスク | 127 GB / `Premium_LRS`（イメージの既定） |
| ネットワーク | Public IP なし、NSG なし。Bastion（Basic、`AzureBastionSubnet` 10.0.0.0/24）の Portal から接続 |
| 管理者 | `azureuser`（パスワードは自動生成。控えは別管理） |
| 言語 / 時刻 | `ja-JP` / `Tokyo Standard Time`（`Set-VMLocale.ps1`。言語パックの導入に約 1 時間、導入済みなら約 6 分） |
| 自動シャットダウン | 1500 UTC（JST 0 時） |
| 作成コマンド | `New-JumpboxVM.ps1 -OS Win2025Datacenter -Credential <資格情報>` → `Set-VMSize.ps1 -VmSize Standard_D2s_v3` → `Set-VMLocale.ps1` |

### 作業用 VM（`YourVM1`、別 VNet）

| 項目 | 内容 |
|---|---|
| 配置 | `YourRG` / `YourVnet`（10.1.0.0/16）/ `YourSubnet`（10.1.0.0/24）。プライベート IP 10.1.0.4 |
| OS | Windows Server 2025 Datacenter（`2025-datacenter`、HyperV 世代 V1、セキュリティ種類 Standard） |
| サイズ | `Standard_D4s_v4`（4 vCPU / 16 GB / 一時ディスクなし）。要望は `D4s_v5` だったが、Dsv5 の vCPU クォータが 0 のため `Dsv4` にした |
| OS ディスク | **256 GB / `StandardSSD_LRS` / 1 本**（データ ディスクなし）。C ドライブは 255.5 GB（空き 237.3 GB。作成後に拡張） |
| ネットワーク | 作成時は Public IP なし、NSG なし（Bastion の VNet とピアリング。Bastion 削除後は、下の「設定の追記」で Public IP + NSG を追加） |
| 管理者 | `azureuser`（パスワードは自動生成。控えは別管理）。RDP は、下記のとおり拒否済み |
| 言語 / 時刻 | **日本語（ja-JP）/ 東京**（2026-11-23、`Set-VMLocale.ps1`。Windows Update 経由、約 40 分）。`Language.*` の 5 種も入っている |
| UAC | **無効**（`EnableLUA=0`、`Set-VMUac.ps1 -Mode Full`。2026-11-23） |
| 自動シャットダウン | 1500 UTC（JST 0 時） |
| 作成コマンド | `New-Sandbox.ps1 -OS Win2025Datacenter -VmSize Standard_D4s_v4 -OsDiskSizeGb 256 -OsDiskType StandardSSD_LRS -Credential <資格情報>` |

#### 設定の追記（2026-11-23）: Entra ID ログイン / RDP / ローカル拒否
Bastion（`AzureBastionRG`）を削除した後、`YourVM1` を次の順で設定した（いずれも `SingleVM/Tool`）。
1. VM を起動（`Start-AzVM`）。
2. `Enable-EntraLogin.ps1 -UserPrincipalName <UPN> -Role Administrator`。
3. `Add-VMPublicIp.ps1 -OpenPort 3389 -MyIp`（Public IP `YourVM1PublicIP`（Standard / 静的）、NSG `YourVM1NSG`、3389 の送信元は自分の IP だけ）。
4. mstsc で Entra ID ログイン（接続先はコンピューター名 `YourVM1` + hosts に `<IP> YourVM1`、`AzureAD\<UPN>`）。
5. `Disable-LocalLogin.ps1 -Mode DenyRdp`（ローカル `azureuser` の RDP を拒否）。Entra ID で再ログインできることを確認した。
6. `Set-VMLocale.ps1`（日本語化）→ `Set-VMUac.ps1 -Mode Full`（UAC 無効、再起動）。UAC 無効の後も、Entra ID の RDP ログインができた（利用者が確認、2026-11-23）。

関連（`YourRG` に置いたもの、2026-11-23）: Storage `yourstorage1123`（コンテナー `langpack`、TLS 1.2、匿名アクセス無し）。言語パックの ISO（`windows-server-2025/…LOF_PACKAGES_OEM.iso`、6.39 GB）を置いた。`YourRG` は長期に残す RG とし、`CanNotDelete` のロック `dx-cannotdelete` を付けた（RG 削除の前に、外す）。

分かったこと:
- `-UserPrincipalName` を省くと、**ロールは付かない**（拡張と ID だけ）。`Disable-LocalLogin.ps1` は、管理者ロールが無いと中止する（締め出し防止）。
- Entra ID のユーザーは、初回ログインで、ローカルの Administrators に入る。ただし `net localgroup` は、名前でなく **SID（`S-1-12-1-...`）** で返すことがある。`Get-LocalGroupMember` では `PrincipalSource = AzureAD`。チェックは、両方を見るように直した。
- 停止（割り当て解除）から起動した直後でも、`Enable-EntraLogin` は通った。ロールの反映には、数分かかる。
- Run Command は、環境により 5 分以上かかることがある（待ち続ければ終わる）。
- 送信元 IP が変わると、RDP が通らなくなる → `Update-VMAllowedIp.ps1`。

### 共通の前提
- リージョン: Japan East。VM サイズのクォータ: `DSv3` / `DSv4` の vCPU 上限は 10（`DSv5` は 0）。
- 起動診断用のストレージ（`azure...`）が、VM ごとに自動で作られ、TLS 1.0 だった。作成後に `Set-StorageSecurity.ps1` で TLS 1.2 に上げる。
- 接続: ブラウザ RDP（Bastion Basic。ピアリング越しも可）。Basic は存在する間、課金される（Public IP も）。
- 課金を止めるには、VM を停止（割り当て解除）する。Bastion は、削除するまで課金が続く。

