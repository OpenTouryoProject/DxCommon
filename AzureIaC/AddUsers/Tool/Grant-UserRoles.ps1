<#
.SYNOPSIS
    ユーザーに、Research にあるロールを割り当てる。

.DESCRIPTION
    Research の「Grant them permissions by role」を Azure PowerShell に置き換えたもの。
      リソースグループ : Virtual Machine Contributor
                         仮想マシン作成のためVMCに追加する権限
      Cloud Shell 用 RG: Azure Cloud Shellの実行のために追加する権限
      サブスクリプション: 仮想マシンの起動と停止
    既に割り当て済みのものはスキップする。カスタムロールは New-CustomRoles.ps1 で先に作っておく。

.PARAMETER UserPrincipalName
    対象ユーザーのメールアドレス または UPN。

.PARAMETER SkipResourceGroupRoles
    リソースグループへの割り当てをしない。

.PARAMETER SkipSubscriptionRole
    サブスクリプションへの割り当てをしない。

.EXAMPLE
    .\Grant-UserRoles.ps1 -UserPrincipalName user@example.com -ResourceGroupName YourRG
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$UserPrincipalName,
    [string]$ResourceGroupName = 'YourRG',
    [string]$CloudShellResourceGroupName = 'cloud-shell-storage-southeastasia',
    [switch]$SkipResourceGroupRoles,
    [switch]$SkipSubscriptionRole
)
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'AddUsers.Common.ps1')
$ctx = Assert-AzLogin
$subscriptionId = $ctx.Subscription.Id

# ゲストの UPN は "<mail>#EXT#@tenant" 形式のため、-SignInName（メール）では解決できない。
# メール → UPN の順でオブジェクト ID を引いて、-ObjectId で割り当てる。
$user = Get-AzADUser -Mail $UserPrincipalName
if (-not $user) { $user = Get-AzADUser -UserPrincipalName $UserPrincipalName }
if (-not $user) { throw "ユーザー '$UserPrincipalName' が見つかりません。ゲストの場合は先に Invite-GuestUser.ps1 で招待してください。" }
$user = @($user)[0]
Say "  対象ユーザー: $($user.UserPrincipalName) ($($user.Id))" -Color DarkGray

function Grant-Role([string]$RoleName, [string]$Scope) {
    $exists = Get-AzRoleAssignment -ObjectId $user.Id -RoleDefinitionName $RoleName -Scope $Scope -ErrorAction SilentlyContinue |
        Where-Object { $_.Scope -eq $Scope }
    if ($exists) {
        Say "  '$RoleName' は割り当て済みです（スキップ）: $Scope" -Color DarkGray
        return
    }
    Say "  '$RoleName' を割り当てます: $Scope" -Color Cyan
    $null = New-AzRoleAssignment -ObjectId $user.Id -RoleDefinitionName $RoleName -Scope $Scope
}

if (-not $SkipResourceGroupRoles) {
    $rgScope = "/subscriptions/$subscriptionId/resourceGroups/$ResourceGroupName"
    $csScope = "/subscriptions/$subscriptionId/resourceGroups/$CloudShellResourceGroupName"
    Grant-Role 'Virtual Machine Contributor' $rgScope
    Grant-Role '仮想マシン作成のためVMCに追加する権限' $rgScope
    Grant-Role 'Azure Cloud Shellの実行のために追加する権限' $csScope
}
if (-not $SkipSubscriptionRole) {
    Grant-Role '仮想マシンの起動と停止' "/subscriptions/$subscriptionId"
}

Say "完了: '$UserPrincipalName' にロールを割り当てました。" -Color Green
