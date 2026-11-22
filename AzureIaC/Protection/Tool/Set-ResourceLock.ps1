<#
.SYNOPSIS
    リソースグループに、ロック（CanNotDelete / ReadOnly）を付ける。

.DESCRIPTION
    リソースグループにロックを付けると、配下のすべてのリソースに継承される。
      CanNotDelete : 削除だけを防ぐ（変更はできる）。誤削除の防止に向く。影響は小さい。
      ReadOnly     : 変更も削除も防ぐ。副作用が大きい（下記）。
    ロックは、いつでも Remove-ResourceLock.ps1 で外せる（元に戻せる）。外すには、所有者などの
    Microsoft.Authorization/locks/* の権限が要る。ロックを付けても、ロックの付け外し自体は止まらない。

    【ReadOnly の副作用】GET 以外の操作が止まる。例:
      - VM の起動・停止・再起動・割り当て解除（POST の操作）。自動シャットダウンの変更も。
      - ストレージ アカウントのキーの取得（listKeys）。Azure AD 認証でのデータ操作は影響を受けにくい。
      - 配下の VM のディスクや NIC の変更、新しいリソースの作成。
    VM を起動・停止する運用の RG には、CanNotDelete を使うこと。
    実行前に、現在のロックと、対象のリソースを表示して確認する（-Force で確認を省略）。

.PARAMETER LockLevel
    CanNotDelete（既定）/ ReadOnly。

.PARAMETER LockName
    ロック名。省略すると、dx-<レベル>。同名のロックが既にあれば、何もしない（スキップ）。

.EXAMPLE
    .\Set-ResourceLock.ps1 -ResourceGroupName AzureBastionRG
    .\Set-ResourceLock.ps1 -ResourceGroupName DxCmnRG -LockLevel ReadOnly
#>
[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(Mandatory)]
    [string]$ResourceGroupName,
    [ValidateSet('CanNotDelete', 'ReadOnly')][string]$LockLevel = 'CanNotDelete',
    [string]$LockName,
    [string]$Notes,
    [switch]$Force
)
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'Protection.Common.ps1')
$null = Assert-AzLogin

$rg = Get-AzResourceGroup -Name $ResourceGroupName -ErrorAction SilentlyContinue
if (-not $rg) { throw "リソースグループ '$ResourceGroupName' が見つかりません。" }
if (-not $LockName) { $LockName = "dx-$($LockLevel.ToLower())" }

Say "対象: リソースグループ '$ResourceGroupName'  /  ロック: $LockName（$LockLevel）" -Color Cyan
$existing = @(Get-LockList $ResourceGroupName)
if ($existing.Count -gt 0) {
    Say '  このリソースグループの、現在のロック:' -Color DarkGray
    $existing | Format-Table ロック名, レベル, 対象 -AutoSize | Out-Host
    if ($existing | Where-Object { $_.ロック名 -eq $LockName }) {
        Say "  ロック '$LockName' は既に存在します（スキップ）" -Color DarkGray
        return
    }
}
$resources = @(Get-AzResource -ResourceGroupName $ResourceGroupName)
Say ("  配下のリソース: {0} 件" -f $resources.Count) -Color DarkGray
$resources | Select-Object -First 15 | Format-Table Name, ResourceType -AutoSize | Out-Host

if ($LockLevel -eq 'ReadOnly') {
    Say 'WARNING: ReadOnly は、変更を止めます。VM の起動・停止・再起動、ストレージのキー取得、リソースの追加・変更ができなくなります。' -Color Yellow
    $hasVm = @($resources | Where-Object { $_.ResourceType -eq 'Microsoft.Compute/virtualMachines' }).Count
    if ($hasVm -gt 0) { Say "  ※ この RG には VM が $hasVm 台あります。VM を起動・停止する運用なら、CanNotDelete にしてください。" -Color Yellow }
}
Say "  戻し方: .\Remove-ResourceLock.ps1 -ResourceGroupName $ResourceGroupName -LockName $LockName" -Color DarkGray

if ($WhatIfPreference) { Say '（-WhatIf: 何も変更していません）' -Color DarkGray; return }
if (-not (Confirm-Action 'ロックを付けますか' -Force:$Force)) { Say '中止しました。' -Color Yellow; return }

$p = @{ LockName = $LockName; LockLevel = $LockLevel; ResourceGroupName = $ResourceGroupName; Force = $true }
if ($Notes) { $p.LockNotes = $Notes } else { $p.LockNotes = 'AzureIaC\Protection\Tool\Set-ResourceLock.ps1' }
$null = New-AzResourceLock @p

Say ''
Say 'ロックを付けました:' -Color Cyan
Get-LockList $ResourceGroupName | Format-Table ロック名, レベル, 対象 -AutoSize | Out-Host
Say "完了: '$ResourceGroupName' に $LockLevel のロックを付けました。" -Color Green
