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
