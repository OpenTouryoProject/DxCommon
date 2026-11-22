<#
.SYNOPSIS
    ストレージアカウントの最小 TLS バージョンを TLS 1.2 に上げる（BLOB の匿名アクセス無効化も選べる）。

.DESCRIPTION
    対象は、-StorageAccountName を指定したアカウント。省略すると、-ResourceGroupName 内（それも省略すると、サブスクリプション内）の
    すべてのストレージアカウント。変更前に、現在の設定を表示して確認する（-Force で確認を省略）。
    すでに TLS 1.2 以上のものは、変更しない（下げることはしない）。
    -DisableBlobPublicAccess を付けると、BLOB の匿名（公開）アクセスも無効にする。
    -WhatIf を付けると、変更せずに、対象だけを表示する。

    ※ TLS 1.0 / 1.1 でしか接続できない古いクライアントは、接続できなくなる。
    ※ 起動診断用に Azure が自動で作ったストレージアカウントも対象になる（TLS 1.2 にしても、VM の起動診断は問題ない）。

.PARAMETER MinimumTlsVersion
    TLS1_2 のみ指定できる。

.EXAMPLE
    .\Set-StorageSecurity.ps1 -WhatIf
    .\Set-StorageSecurity.ps1 -ResourceGroupName DxCmnRG -StorageAccountName osscjpdevinfra01
    .\Set-StorageSecurity.ps1 -DisableBlobPublicAccess -Force
#>
[CmdletBinding(SupportsShouldProcess)]
param(
    [string]$ResourceGroupName,
    [string]$StorageAccountName,
    [ValidateSet('TLS1_2')][string]$MinimumTlsVersion = 'TLS1_2',
    [switch]$DisableBlobPublicAccess,
    [switch]$Force
)
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'Storage.Common.ps1')
$null = Assert-AzLogin

if ($StorageAccountName -and -not $ResourceGroupName) {
    $found = @(Get-AzStorageAccount | Where-Object { $_.StorageAccountName -eq $StorageAccountName })
    if ($found.Count -eq 0) { throw "ストレージアカウント '$StorageAccountName' が見つかりません。" }
    $ResourceGroupName = $found[0].ResourceGroupName
}
$accounts = if ($StorageAccountName) {
    @(Get-AzStorageAccount -ResourceGroupName $ResourceGroupName -Name $StorageAccountName -ErrorAction SilentlyContinue)
}
elseif ($ResourceGroupName) { @(Get-AzStorageAccount -ResourceGroupName $ResourceGroupName) }
else { @(Get-AzStorageAccount) }
if ($accounts.Count -eq 0 -or -not $accounts[0]) { Say '対象のストレージアカウントがありません。' -Color Yellow; return }

# 変更が必要なものだけに絞る
$rank = @{ 'TLS1_0' = 0; 'TLS1_1' = 1; 'TLS1_2' = 2; 'TLS1_3' = 3 }
$targets = @()
foreach ($sa in $accounts) {
    $cur = if ($sa.MinimumTlsVersion) { [string]$sa.MinimumTlsVersion } else { 'TLS1_0' }
    $needTls = $rank[$cur] -lt $rank[$MinimumTlsVersion]
    $needAnon = $DisableBlobPublicAccess -and ($sa.AllowBlobPublicAccess -ne $false)
    $targets += [pscustomobject]@{
        名前 = $sa.StorageAccountName; RG = $sa.ResourceGroupName
        現在のTLS = $cur; 変更後のTLS = if ($needTls) { $MinimumTlsVersion } else { '（変更なし）' }
        匿名アクセス = $sa.AllowBlobPublicAccess; 匿名アクセス変更 = if ($needAnon) { '無効にする' } else { '（変更なし）' }
        _Account = $sa; _NeedTls = $needTls; _NeedAnon = $needAnon
    }
}

Say '対象のストレージアカウント:' -Color Cyan
$targets | Format-Table 名前, RG, 現在のTLS, 変更後のTLS, 匿名アクセス, 匿名アクセス変更 -AutoSize | Out-Host
$todo = @($targets | Where-Object { $_._NeedTls -or $_._NeedAnon })
if ($todo.Count -eq 0) { Say '変更が必要なストレージアカウントはありません。' -Color Green; return }
if ($WhatIfPreference) { Say "（-WhatIf: $($todo.Count) 件が変更対象です。何も変更していません）" -Color DarkGray; return }

Say 'TLS 1.0 / 1.1 でしか接続できない古いクライアントは、接続できなくなります。' -Color Yellow
if (-not (Confirm-Action "$($todo.Count) 件のストレージアカウントを変更しますか" -Force:$Force)) {
    Say '中止しました。' -Color Yellow
    return
}

foreach ($t in $todo) {
    $p = @{ ResourceGroupName = $t._Account.ResourceGroupName; Name = $t._Account.StorageAccountName }
    if ($t._NeedTls) { $p.MinimumTlsVersion = $MinimumTlsVersion }
    if ($t._NeedAnon) { $p.AllowBlobPublicAccess = $false }
    Say ("  '{0}' を変更します" -f $t.名前) -Color Cyan
    $null = Set-AzStorageAccount @p
}

Say ''
Say '変更後:' -Color Cyan
$after = foreach ($t in $todo) { Get-AzStorageAccount -ResourceGroupName $t._Account.ResourceGroupName -Name $t._Account.StorageAccountName }
$after | Format-Table StorageAccountName, ResourceGroupName, MinimumTlsVersion, AllowBlobPublicAccess -AutoSize | Out-Host
$bad = @($after | Where-Object { ($rank[[string]$_.MinimumTlsVersion]) -lt $rank[$MinimumTlsVersion] })
if ($bad.Count -gt 0) { throw ("最小 TLS が反映されていません: {0}" -f (($bad | ForEach-Object StorageAccountName) -join ', ')) }
Say "完了: $($todo.Count) 件を変更しました。" -Color Green
