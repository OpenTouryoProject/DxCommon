<#
.SYNOPSIS
    Azure Storage（RG / ストレージアカウント / ロール割り当て / コンテナ）を作成する。

.DESCRIPTION
    Research の Storage/README.md を Azure PowerShell に置き換えたもの。
    既に存在するリソースはスキップする。ストレージアカウント名はグローバルで一意である必要がある。
    操作ユーザーに "Storage Blob Data Contributor" を割り当て、Azure AD 認証でコンテナを作成する。
    ロールの反映待ちでコンテナ作成に失敗した場合は、数回リトライする。

.PARAMETER UserPrincipalName
    ロールを割り当てるユーザー。省略時は現在ログイン中のアカウント。

.EXAMPLE
    .\New-StorageAccount.ps1 -StorageAccountName osscjpdevinfra
#>
[CmdletBinding()]
param(
    [string]$Location = 'japaneast',
    [string]$ResourceGroupName = 'DxCmnRG',
    [string]$StorageAccountName = 'osscjpdevinfra',
    [string]$ContainerName = 'dxcmn',
    [string]$SkuName = 'Standard_LRS',
    [string]$UserPrincipalName
)
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'Storage.Common.ps1')
$ctx = Assert-AzLogin
Assert-ResourceProviders $RequiredProviders
if (-not $UserPrincipalName) { $UserPrincipalName = $ctx.Account.Id }
$subscriptionId = $ctx.Subscription.Id

Say "  サブスクリプション: $subscriptionId" -Color DarkGray
Say "  ユーザー          : $UserPrincipalName" -Color DarkGray

Initialize-ResourceGroup $ResourceGroupName $Location

# ストレージアカウント
$sa = Get-AzStorageAccount -ResourceGroupName $ResourceGroupName -Name $StorageAccountName -ErrorAction SilentlyContinue
if ($sa) {
    Say "  ストレージアカウント '$StorageAccountName' は既に存在します（スキップ）" -Color DarkGray
}
else {
    Say "  ストレージアカウント '$StorageAccountName' を作成します" -Color Cyan
    $sa = New-AzStorageAccount -ResourceGroupName $ResourceGroupName -Name $StorageAccountName `
        -Location $Location -SkuName $SkuName
}

# ロール割り当て
$role = 'Storage Blob Data Contributor'
$assigned = Get-AzRoleAssignment -SignInName $UserPrincipalName -RoleDefinitionName $role -Scope $sa.Id -ErrorAction SilentlyContinue
if ($assigned) {
    Say "  ロール '$role' は割り当て済みです（スキップ）" -Color DarkGray
}
else {
    Say "  ロール '$role' を割り当てます" -Color Cyan
    $null = New-AzRoleAssignment -SignInName $UserPrincipalName -RoleDefinitionName $role -Scope $sa.Id
}

# コンテナ（Azure AD 認証）
$storageCtx = New-AzStorageContext -StorageAccountName $StorageAccountName -UseConnectedAccount
$done = $false
for ($try = 1; $try -le 6 -and -not $done; $try++) {
    try {
        if (Get-AzStorageContainer -Name $ContainerName -Context $storageCtx -ErrorAction SilentlyContinue) {
            Say "  コンテナ '$ContainerName' は既に存在します（スキップ）" -Color DarkGray
        }
        else {
            Say "  コンテナ '$ContainerName' を作成します" -Color Cyan
            $null = New-AzStorageContainer -Name $ContainerName -Context $storageCtx -ErrorAction Stop
        }
        $done = $true
    }
    catch {
        if ($try -ge 6) { throw }
        Say ("  ロールの反映待ち... 20 秒後に再試行します ({0}/6): {1}" -f $try, $_.Exception.Message) -Color Yellow
        Start-Sleep -Seconds 20
    }
}

Say "完了: ストレージ '$StorageAccountName' / コンテナ '$ContainerName' を用意しました。" -Color Green
