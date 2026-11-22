# Monitor

## 概要
Azure の状態を見張る手順の調査結果。読み取り専用で、何も変更しない。
- セキュリティ: インバウンド（外から入ってこられる口）の一覧。
- 課金: 過去 30 日 / 先月 / 当月の請求額と、当月の予実。

これを Azure PowerShell のスクリプトにしたものが [Tool](../Tool/README.md)。

### 変数

#### Define
```Bash
subscriptionID=$(az account show --query id --output tsv)
rgName=YourRG   # 絞り込むとき。省略するとサブスクリプション全体
```

#### Check
```Bash
echo $subscriptionID
echo $rgName
```

## セキュリティ（インバウンド）

### 調べる対象
外部から到達できる口は、主に次の 4 つ。

| 対象 | 見るもの | 意味 |
|---|---|---|
| NSG の受信許可ルール | `Direction=Inbound` かつ `Access=Allow` | 送信元が `*` / `Internet` / `0.0.0.0/0` で、危険なポートに届くものが問題 |
| NSG の関連付け | サブネット / NIC への適用 | どこにも関連付いていない NSG は、効いていない |
| パブリック IP | IP アドレスと割り当て先 | 割り当て先が VM なら、直接インターネットに出ている。未使用の IP も見つかる |
| ストレージアカウント | 既定のアクション、匿名アクセス、HTTPS、最小 TLS | 既定のアクションが `Allow` だと、IP ルールを足しても制限されない |

### Azure CLI
```Bash
# NSG の受信許可ルール（Azure の既定ルール 65000 番台は除く）
az network nsg list --query "[].{nsg:name, rg:resourceGroup}" --output table
az network nsg rule list --resource-group $rgName --nsg-name <NSG名> \
  --query "[?direction=='Inbound' && access=='Allow'].{name:name, priority:priority, protocol:protocol, source:sourceAddressPrefix, port:destinationPortRange}" \
  --output table

# パブリック IP と割り当て先
az network public-ip list \
  --query "[].{name:name, ip:ipAddress, sku:sku.name, attached:ipConfiguration.id}" --output table

# ストレージの公開設定
az storage account list \
  --query "[].{name:name, anon:allowBlobPublicAccess, https:enableHttpsTrafficOnly, tls:minimumTlsVersion, default:networkRuleSet.defaultAction}" \
  --output table
```

### Azure PowerShell
```PowerShell
Get-AzNetworkSecurityGroup            # .SecurityRules / .Subnets / .NetworkInterfaces
Get-AzPublicIpAddress                 # .IpAddress / .IpConfiguration.Id
Get-AzStorageAccount                  # .AllowBlobPublicAccess / .EnableHttpsTrafficOnly / .MinimumTlsVersion
Get-AzStorageAccountNetworkRuleSet -ResourceGroupName <RG> -Name <名前>   # .DefaultAction / .IpRules
```

### 判定の考え方
- 公開とみなす送信元: `*`、`Internet`、`Any`、`0.0.0.0/0`、`::/0`。
- 危険なポート: 21 (FTP)、22 (SSH)、23 (Telnet)、445 (SMB)、1433 (SQL Server)、3306 (MySQL)、3389 (RDP)、
  5432 (PostgreSQL)、5985/5986 (WinRM)、6379 (Redis)、27017 (MongoDB)。
- 宛先ポートは `80`、`1000-2000`、`*` のように書ける。範囲と `*` も含めて判定する必要がある。
- 公開 + 危険ポート = **[危険]**、公開のみ = **[注意]**。
- 対処: 送信元を自分の IP / CIDR に絞る、または Bastion 経由にする。

### 注意
- `SecurityRules` には、Azure の既定ルール（`DefaultSecurityRules`）は含まれない。既定ルールは別プロパティ。
- Az.Network 8.x の `SecurityRule` は、送信元・宛先ポートが配列（`SourceAddressPrefix` / `DestinationPortRange`）で返る。`-contains` / `-in` で比べる。
- NSG の `Subnets` / `NetworkInterfaces` は ID（リソース ID 文字列）で返る。名前は ID の末尾から取る。
- Azure Firewall、Application Gateway、Load Balancer のルール、SQL Server のファイアウォールなどは対象外（この環境では未使用）。

## 課金

### 使う API
Cost Management の REST API。サブスクリプションのスコープ:
`/subscriptions/{id}/providers/Microsoft.CostManagement/...`

| 用途 | API | 備考 |
|---|---|---|
| 期間の実績 | `POST .../query?api-version=2023-11-01` | `timeframe=Custom` で期間を指定 |
| 当月の予測 | `POST .../forecast?api-version=2023-11-01` | 実績と予測を、日別の 1 回の呼び出しで取れる |
| 予算 | `GET /subscriptions/{id}/providers/Microsoft.Consumption/budgets?api-version=2023-05-01` | 設定していなければ空 |

必要な権限: 「Cost Management 閲覧者」、または所有者 / 閲覧者。リソースプロバイダー `Microsoft.CostManagement` が登録済みであること。

### 実績の取得（query）
```Bash
az rest --method post \
  --url "https://management.azure.com/subscriptions/$subscriptionID/providers/Microsoft.CostManagement/query?api-version=2023-11-01" \
  --body '{
    "type": "ActualCost",
    "timeframe": "Custom",
    "timePeriod": { "from": "2026-10-01T00:00:00Z", "to": "2026-10-31T23:59:59Z" },
    "dataset": {
      "granularity": "None",
      "aggregation": { "totalCost": { "name": "PreTaxCost", "function": "Sum" } },
      "grouping": [ { "type": "Dimension", "name": "ServiceName" } ]
    }
  }'
```

```PowerShell
$path = "/subscriptions/$subscriptionId/providers/Microsoft.CostManagement/query?api-version=2023-11-01"
$r = Invoke-AzRestMethod -Method POST -Path $path -Payload $json
($r.Content | ConvertFrom-Json).properties.rows
```

- `grouping` を外すと合計だけ返る。`ServiceName` で、サービス別の内訳になる。
- 応答は `properties.columns`（列名）と `properties.rows`（値の配列）。列の位置は固定ではないので、列名で引く。
  合計だけなら `PreTaxCost, Currency`、サービス別なら `PreTaxCost, ServiceName, Currency` の列が返る。
- 集計は `PreTaxCost`（税引前）を使う。

### 当月の予実（forecast）
`dataset.granularity` を `Daily` にして、期間を当月の 1 日〜末日にし、`includeActualCost=true` を付ける。
```Json
{
  "type": "ActualCost",
  "timeframe": "Custom",
  "timePeriod": { "from": "2026-11-01T00:00:00Z", "to": "2026-11-30T23:59:59Z" },
  "dataset": { "granularity": "Daily", "aggregation": { "totalCost": { "name": "PreTaxCost", "function": "Sum" } } },
  "includeActualCost": true,
  "includeFreshPartialCost": false
}
```
- 応答の行に `CostStatus`（`Actual` / `Forecast`）があり、全行の合計 = 月末の予測、`Actual` の合計 = 今日までの実績。
- 利用開始直後などでデータが足りないと、予測が返らない（空、またはエラー）。その場合は日割りで代用する:
  `今日までの実績 ÷ 経過日数 × 月の日数`。
- 予実の見方: 当月の見込み と 先月 の差（金額と %）。予算があれば、予算に対する使用率と、月末の予測での使用率。

### 期間の決め方（UTC）
| 項目 | from | to |
|---|---|---|
| 過去 30 日 | 今日 - 30 日 | 今日 |
| 先月 | 先月 1 日 | 先月末日 |
| 当月 | 当月 1 日 | 今日（予測は月末日まで） |

### 注意
- 金額は税引前。コストの反映には、数時間〜1 日ほど遅れる。
- Cost Management の API は、短時間に呼ぶと `429` になる。`Retry-After` 系のヘッダー（`x-ms-ratelimit-microsoft.costmanagement-entity-retry-after`）の秒数だけ待って再試行する。
- 通貨は応答の `Currency` 列を使う（この環境では JPY。小数点は不要）。
- 課金データの種類（`ActualCost` / `AmortizedCost`）は、予約やセービングプランを使うと値が変わる。ここでは `ActualCost`。
- 課金の最大の原因になりやすいのは、Bastion（存在する間ずっと課金）、停止していない VM、使っていないパブリック IP。
  先月の「Virtual Network」の請求の大半は、Bastion とパブリック IP によるものと思われる。

## 予算（Budget）を作る（任意）
予算を設定しておくと、使い過ぎに気付ける。Azure Portal の「コストの管理」→「予算」で、月額の予算と、アラート（実績 80%、予測 100% など）を作る。
`Show-Billing.ps1` は、予算があればその使用率も表示する。

## 参考
- Cost Management Query: https://learn.microsoft.com/rest/api/cost-management/query/usage
- Cost Management Forecast: https://learn.microsoft.com/rest/api/cost-management/forecast/usage
- Budgets: https://learn.microsoft.com/rest/api/consumption/budgets
- NSG のセキュリティルール: https://learn.microsoft.com/azure/virtual-network/network-security-groups-overview
