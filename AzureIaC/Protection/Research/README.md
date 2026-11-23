# Protection

## 概要
リソースグループ内のリソースの、誤削除・誤変更を防ぐ手段の調査結果。
これを Azure PowerShell のスクリプトにしたものが [Tool](../Tool/README.md)。

## 手段の比較

| 手段 | 防げるもの | 向くもの | 備考 |
|---|---|---|---|
| リソース ロック `CanNotDelete` | 削除 | 誤削除の防止 | 変更はできる。影響が小さい |
| リソース ロック `ReadOnly` | 変更と削除 | 落ち着いた RG の固定 | 副作用が大きい（下記） |
| Azure Policy（`Deny`） | 特定の設定（例: 最小 TLS、3389 の全許可、Public IP の作成） | 設定の逸脱の防止 | 条件つき。既存リソースは非準拠として表示されるだけ。評価に時間がかかる |
| RBAC | 変更できる人 | 権限の最小化 | 抑止ではなく制限。所有者は変更できる |
| デプロイ スタックの `denySettings` | スタックの外からの変更・削除 | Bicep / ARM でのデプロイ | この環境の Azure PowerShell の流れとは別 |

## リソース ロック

- リソース グループに付けると、配下のすべてのリソースに**継承される**。サブスクリプション、リソース単位にも付けられる。
- 付け外しの権限: `Microsoft.Authorization/locks/*`（所有者、ユーザー アクセス管理者）。
- **ロックは、いつでも外せる（元に戻せる）**。`ReadOnly` の最中でも、ロックを外す操作は止まらない（ロックは `Microsoft.Authorization/locks` という別のリソース）。実機で確認した。
- 同じ RG に、複数のロックを付けられる（`CanNotDelete` と `ReadOnly` の併用）。厳しい方が効く。

### ReadOnly の副作用
`GET` 以外の操作が止まる。例:
- VM の起動・停止・再起動・割り当て解除（POST の操作）。自動シャットダウンの変更も。
- ストレージ アカウントのキーの取得（`listKeys`）。
- 配下のリソースの変更、新しいリソースの作成。

VM を起動・停止する運用の RG には、`CanNotDelete` を使う。

### Azure PowerShell
```PowerShell
New-AzResourceLock -LockName dx-cannotdelete -LockLevel CanNotDelete -ResourceGroupName <RG> -LockNotes '<メモ>' -Force
Get-AzResourceLock                                   # サブスクリプション内のすべて
Get-AzResourceLock -ResourceGroupName <RG> -AtScope  # その RG に付けたものだけ
Remove-AzResourceLock -LockId <LockId> -Force
```
- `Get-AzResourceLock` の `LockId` は、`<スコープ>/providers/Microsoft.Authorization/locks/<名前>`。スコープは、LockId の末尾を除いたもの。
- レベルは `$lock.Properties.level`。

### Azure CLI
```Bash
az lock create --name dx-cannotdelete --lock-type CanNotDelete --resource-group $rg
az lock list --resource-group $rg
az lock delete --name dx-cannotdelete --resource-group $rg
```

## 実機の確認（2026-11-23、使い捨ての RG `dx-locktest-rg` で実施）

| 操作 | 結果 |
|---|---|
| `CanNotDelete` を付けて、RG を削除 | 拒否（`cannot perform delete operation because following scope(s) are locked`） |
| `CanNotDelete` の状態で、タグを変更 | 通る |
| `ReadOnly` を追加して、タグを変更 | 拒否（`cannot perform write operation ...`） |
| `ReadOnly` を外す | 外せた。外した後は、タグの変更が通る |
| `CanNotDelete` を外して、RG を削除 | 削除できた |

## 注意
- `ReadOnly` を付けた RG に、新しい VM を作る、Public IP を付ける、`Set-StorageSecurity` を実行する、などは、すべて拒否される。先に外す。
- ロックは、**RG を削除する、`Remove-Simplest.ps1` などの片付けも止める**。片付けの前に外す。
- Azure Policy は、今回は調べただけで、Tool には含めていない。

## 実機の運用例（2026-11-23）

- `AzureOpneAI_RG`（Azure OpenAI アカウントと AIServices アカウント）に、`ReadOnly` を付けた。
  - 付ける前に、アクティビティ ログ（過去 89 日）を確認: イベントは 0 件（書き込み・削除・`listKeys` なし）。
  - **推論（API 呼び出し）は、データ プレーンなので、ロックの影響を受けない**。止まるのは、デプロイの作成・変更・削除、アカウント設定の変更、API キーの取得（`listKeys`）と再生成、Foundry のプロジェクトや接続の追加など、ARM を通る操作。
  - アクティビティ ログは、データ プレーンの呼び出しを記録しない。また、保持は 90 日まで。アプリの実際の稼働は、利用者側で確認する。
  - 戻し方: `Remove-ResourceLock.ps1 -ResourceGroupName AzureOpneAI_RG -LockName dx-readonly`。
- 運用の考え方: VM を起動・停止する RG は `CanNotDelete`、設定が落ち着いている RG（変更が数か月無いもの）は `ReadOnly`。RG ごと削除して片付けるときは、先にロックを外す。
- `YourRG`（長期に残す作業用の RG。VM、VNet、Storage）に、`CanNotDelete` を付けた（`dx-cannotdelete`）。VM の起動・停止や設定変更は、そのまま通る。RG ごとの削除（`Remove-Simplest.ps1` など）は、先にロックを外す。一時 Public IP などの削除も、ロックの対象になる点に注意する。

