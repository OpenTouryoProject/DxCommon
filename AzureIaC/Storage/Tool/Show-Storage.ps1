<#
.SYNOPSIS
    ストレージアカウント・ロール割り当て・コンテナ・ネットワークルールを表示する（読み取り専用）。

.EXAMPLE
    .\Show-Storage.ps1
#>
[CmdletBinding()]
param(
    [string]$ResourceGroupName = 'DxCmnRG',
    [string]$StorageAccountName = 'osscjpdevinfra'
)
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'Storage.Common.ps1')
$ctx = Assert-AzLogin

$sa = Get-AzStorageAccount -ResourceGroupName $ResourceGroupName -Name $StorageAccountName -ErrorAction SilentlyContinue
if (-not $sa) { throw "ストレージアカウント '$StorageAccountName'（RG: $ResourceGroupName）が見つかりません。" }

Say 'ストレージアカウント:' -Color Cyan
$sa | Format-Table StorageAccountName, Location, @{ n = 'Sku'; e = { $_.Sku.Name } }, Kind -AutoSize | Out-Host

Say 'ロール割り当て（このストレージアカウント）:' -Color Cyan
Get-AzRoleAssignment -Scope $sa.Id | Where-Object { $_.Scope -eq $sa.Id } |
    Format-Table DisplayName, SignInName, RoleDefinitionName -AutoSize | Out-Host

Say 'コンテナ:' -Color Cyan
try {
    $storageCtx = New-AzStorageContext -StorageAccountName $StorageAccountName -UseConnectedAccount
    Get-AzStorageContainer -Context $storageCtx | Format-Table Name, LastModified -AutoSize | Out-Host
}
catch { Say ("  取得できません: {0}" -f $_.Exception.Message) -Color Yellow }

Say 'ネットワークルール:' -Color Cyan
$rules = Get-AzStorageAccountNetworkRuleSet -ResourceGroupName $ResourceGroupName -Name $StorageAccountName
Say ("  DefaultAction: {0}" -f $rules.DefaultAction)
$rules.IpRules | Format-Table IPAddressOrRange, Action -AutoSize | Out-Host
