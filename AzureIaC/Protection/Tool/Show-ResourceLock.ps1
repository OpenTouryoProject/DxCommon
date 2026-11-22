<#
.SYNOPSIS
    サブスクリプション内のロックと、リソースグループごとのロックの有無を表示する（読み取り専用）。

.PARAMETER ResourceGroupName
    表示する範囲を、リソースグループに絞る。省略すると、サブスクリプション全体。

.EXAMPLE
    .\Show-ResourceLock.ps1
#>
[CmdletBinding()]
param(
    [string]$ResourceGroupName
)
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'Protection.Common.ps1')
$ctx = Assert-AzLogin
Say ("対象: {0}" -f $ctx.Subscription.Name) -Color DarkGray

Say ''
Say 'ロック一覧:' -Color Cyan
$locks = @(Get-LockList $ResourceGroupName)
if ($locks.Count -eq 0) { Say '  ロックはありません。' -Color DarkGray }
else { $locks | Format-Table ロック名, レベル, 対象, メモ -AutoSize | Out-Host }

if (-not $ResourceGroupName) {
    Say 'リソースグループごとのロックの有無:' -Color Cyan
    Get-AzResourceGroup | ForEach-Object {
        $rgName = $_.ResourceGroupName
        $mine = @($locks | Where-Object { $_._Scope -match "/resourceGroups/$([regex]::Escape($rgName))$" })
        $sub = @($locks | Where-Object { $_._Scope -match '^/subscriptions/[^/]+$' })
        [pscustomobject]@{
            RG       = $rgName
            ロック   = if ($mine.Count) { ($mine | ForEach-Object { "$($_.ロック名)($($_.レベル))" }) -join ', ' } else { '（なし）' }
            サブスクリプションのロック = if ($sub.Count) { 'あり' } else { '-' }
        }
    } | Format-Table -AutoSize | Out-Host
    Say '  ※ ReadOnly は、VM の起動・停止などの変更を止めます。CanNotDelete は、削除だけを止めます。' -Color DarkGray
}
Say '完了。' -Color Green
