<#
.SYNOPSIS
    ストレージアカウントを削除する（-RemoveResourceGroup でリソースグループごと削除）。

.DESCRIPTION
    削除前に、コンテナ・ロール割り当て・ネットワークルールを表示して確認する（-Force で確認を省略）。
    ストレージアカウントを削除すると、中のデータは元に戻せない。
    ストレージアカウントに付けたロール割り当ては、アカウントとともに無効になる。

.EXAMPLE
    .\Remove-StorageAccount.ps1 -StorageAccountName osscjpdevinfra01
    .\Remove-StorageAccount.ps1 -StorageAccountName osscjpdevinfra01 -RemoveResourceGroup
#>
[CmdletBinding()]
param(
    [string]$ResourceGroupName = 'DxCmnRG',
    [Parameter(Mandatory)]
    [string]$StorageAccountName,
    [switch]$RemoveResourceGroup,
    [switch]$Force
)
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'Storage.Common.ps1')
$null = Assert-AzLogin

if (-not (Get-AzResourceGroup -Name $ResourceGroupName -ErrorAction SilentlyContinue)) {
    Say "リソースグループ '$ResourceGroupName' は存在しません。" -Color Yellow
    return
}

if ($RemoveResourceGroup) {
    Say "削除対象: リソースグループ '$ResourceGroupName'" -Color Cyan
    $resources = @(Get-AzResource -ResourceGroupName $ResourceGroupName)
    if ($resources.Count -eq 0) { Say '  （中身は空です）' -Color DarkGray }
    else { $resources | Format-Table Name, ResourceType -AutoSize | Out-Host }
    if (-not (Confirm-Action "リソースグループ '$ResourceGroupName' を、中身ごと削除しますか（元に戻せません）" -Force:$Force)) {
        Say 'キャンセルしました。' -Color Yellow; return
    }
    $null = Remove-AzResourceGroup -Name $ResourceGroupName -Force
    Say "完了: '$ResourceGroupName' を削除しました。" -Color Green
    return
}

$sa = Get-AzStorageAccount -ResourceGroupName $ResourceGroupName -Name $StorageAccountName -ErrorAction SilentlyContinue
if (-not $sa) { throw "ストレージアカウント '$StorageAccountName'（RG: $ResourceGroupName）が見つかりません。" }

Say "削除対象: ストレージアカウント '$StorageAccountName'（RG: $ResourceGroupName）" -Color Cyan
Say 'コンテナ:' -Color DarkGray
try {
    $storageCtx = New-AzStorageContext -StorageAccountName $StorageAccountName -UseConnectedAccount
    Get-AzStorageContainer -Context $storageCtx | Format-Table Name, LastModified -AutoSize | Out-Host
}
catch { Say ("  取得できません: {0}" -f $_.Exception.Message) -Color Yellow }
Say 'ロール割り当て:' -Color DarkGray
Get-AzRoleAssignment -Scope $sa.Id | Where-Object { $_.Scope -eq $sa.Id } |
    Format-Table DisplayName, RoleDefinitionName -AutoSize | Out-Host

if (-not (Confirm-Action "ストレージアカウント '$StorageAccountName' を、データごと削除しますか（元に戻せません）" -Force:$Force)) {
    Say 'キャンセルしました。' -Color Yellow
    return
}

Say "  ストレージアカウント '$StorageAccountName' を削除します" -Color Cyan
$null = Remove-AzStorageAccount -ResourceGroupName $ResourceGroupName -Name $StorageAccountName -Force
Say "完了: '$StorageAccountName' を削除しました。リソースグループ '$ResourceGroupName' は残っています。" -Color Green
