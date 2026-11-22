# Monitor - Tool

[Research](../Research/README.md) を Azure PowerShell にしたもの。
Azure の状態を見張るための、読み取り専用の Tool。
セキュリティ（インバウンドの口の一覧）と、課金（過去 30 日 / 先月 / 当月の予実）を表示する。何も変更しない。

## 前提
- PowerShell 7（または Windows PowerShell 5.1）と、`Az` モジュール（`Az.Accounts`、`Az.Resources`、`Az.Network`、`Az.Storage`）。
- `Connect-AzAccount` でサインイン済みであること。
- 課金の表示には、サブスクリプションの「Cost Management 閲覧者」（または、所有者 / 閲覧者）の権限。
- リソースプロバイダーの登録: `Microsoft.CostManagement`、`Microsoft.Network`、`Microsoft.Storage`。  
  `Test-Prerequisites.ps1` で確認でき、未登録のものは `Test-Prerequisites.ps1 -Register` で登録できる。

## 使い方
対話メニュー（推奨）:

```PowerShell
.\Invoke-MonitorMenu.ps1
```

流れ: コマンドを選ぶ → オプションを入力する（Enter で既定値）→ 確認する → Enter で実行する。
`q` で終了、`b` で 1 つ前に戻る。

| スクリプト | 内容 |
|---|---|
| `Test-Prerequisites.ps1` | モジュール、サインイン、リソースプロバイダーを確認する |
| `Show-InboundSecurity.ps1` | NSG の受信許可ルール、NSG の関連付け、パブリック IP、ストレージの公開設定を表示する |
| `Show-Billing.ps1` | 過去 30 日、先月、当月（実績と月末の予測）、予算の使用状況を表示する |

## Show-InboundSecurity
```PowerShell
.\Show-InboundSecurity.ps1                              # サブスクリプション全体
.\Show-InboundSecurity.ps1 -ResourceGroupName YourRG -ShowAll
```

| セクション | 見るもの |
|---|---|
| [1] NSG の受信許可ルール | 送信元がインターネット全体（`*` / `Internet` / `0.0.0.0/0`）のルール。<br>RDP・SSH・SMB・DB などの危険なポートに届くものは **[危険]**、それ以外の全開放は **[注意]**。`-ShowAll` で、他のルールも出す。 |
| [2] NSG の関連付け | どのサブネット / NIC に効いているか。どこにも関連付いていない NSG は、効いていない。 |
| [3] パブリック IP | IP アドレスと、割り当て先（VM / Bastion など）。未使用のものも分かる。 |
| [4] ストレージアカウント | 既定のアクション（`Allow` なら全許可）、BLOB の匿名アクセス、HTTPS のみ、最小 TLS、IP ルール。 |

危険ポート: 21 / 22 / 23 / 445 / 1433 / 3306 / 3389 / 5432 / 5985 / 5986 / 6379 / 27017。
Azure の既定ルール（65000 番台）は表示しない。

## Show-Billing
```PowerShell
.\Show-Billing.ps1                  # サービス別の上位 5 件つき
.\Show-Billing.ps1 -TopServices 0   # 合計だけ
```

| 項目 | 内容 |
|---|---|
| 過去 30 日 | 今日から 30 日前までの実績 |
| 先月 | 先月 1 日〜末日の請求額 |
| 当月 | 今日までの実績と、月末の予測（Azure の予測 API。取れないときは日割りの見込み） |
| 予実 | 当月の見込みと先月との差（金額・%） |
| 予算 | Budget が設定されていれば、予算・使用額・使用率、月末の予測での使用率 |

## 注意
- 金額は税引前。コストの反映には、数時間〜1 日ほど遅れる。新しいサブスクリプションでは、データがまだ無いことがある。
- Cost Management の API は、短時間に呼ぶと `429`（混雑）になる。スクリプトは自動で待って再試行する（最大 3 回）。
- 予算を設定していない場合は、Azure Portal の「コストの管理」→「予算」で、月額の予算とアラートを作っておくと、使い過ぎに気付ける。
- [危険] が出た場合の対処: ルールの送信元を、自分の IP / CIDR に絞る（`SingleVM\Tool\Open-VMPort.ps1 -SourceAddressPrefix`）か、Bastion 経由にする。
