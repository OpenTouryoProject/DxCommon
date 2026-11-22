<#
.SYNOPSIS
    リソースグループのロックを外す（元に戻す）。

.DESCRIPTION
    -LockName を指定すると、その名前のロックだけを外す。省略すると、そのリソースグループに付いているロックをすべて外す。
    外す前に、対象を表示して確認する（-Force で確認を省略）。ロックが無ければ、何もしない。
    外すには、所有者などの Microsoft.Authorization/locks/* の権限が要る。

.EXAMPLE
    .\Remove-ResourceLock.ps1 -ResourceGroupName AzureBastionRG
    .\Remove-ResourceLock.ps1 -ResourceGroupName AzureBastionRG -LockName dx-readonly
#>
[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(Mandatory)]
    [string]$ResourceGroupName,
    [string]$LockName,
    [switch]$Force
)
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'Protection.Common.ps1')
$null = Assert-AzLogin

if (-not (Get-AzResourceGroup -Name $ResourceGroupName -ErrorAction SilentlyContinue)) {
    throw "リソースグループ '$ResourceGroupName' が見つかりません。"
}
$locks = @(Get-LockList $ResourceGroupName)
if ($LockName) { $locks = @($locks | Where-Object { $_.ロック名 -eq $LockName }) }
if ($locks.Count -eq 0) { Say 'この条件に合うロックはありません。' -Color Yellow; return }

Say "外すロック（リソースグループ '$ResourceGroupName'）:" -Color Cyan
$locks | Format-Table ロック名, レベル, 対象 -AutoSize | Out-Host
if ($WhatIfPreference) { Say '（-WhatIf: 何も変更していません）' -Color DarkGray; return }
if (-not (Confirm-Action "$($locks.Count) 件のロックを外しますか" -Force:$Force)) { Say '中止しました。' -Color Yellow; return }

foreach ($l in $locks) {
    Say "  ロック '$($l.ロック名)' を外します" -Color Cyan
    $null = Remove-AzResourceLock -LockId $l._LockId -Force
}
Say ''
$left = @(Get-LockList $ResourceGroupName)
Say ("完了: {0} 件のロックを外しました（残り: {1} 件）。" -f $locks.Count, $left.Count) -Color Green
