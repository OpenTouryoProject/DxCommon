<#
.SYNOPSIS
    ユーザー（ゲストまたはメンバー）を、ロール割り当てごと削除する。

.DESCRIPTION
    メールアドレス または UPN でユーザーを探し、削除前に、ユーザーの種類とロール割り当てを表示して確認する
    （-Force で確認を省略）。ロール割り当てを先に外してから、ユーザーを削除する。
    現在ログインしているアカウント自身は、削除しない。
    削除したユーザーは、Entra ID の「削除済みユーザー」から 30 日以内なら復元できる。

.EXAMPLE
    .\Remove-User.ps1 -UserPrincipalName dxuser01@example.onmicrosoft.com
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$UserPrincipalName,
    [switch]$Force
)
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'AddUsers.Common.ps1')
$ctx = Assert-AzLogin

$user = Get-AzADUser -Mail $UserPrincipalName
if (-not $user) { $user = Get-AzADUser -UserPrincipalName $UserPrincipalName }
if (-not $user) { throw "ユーザー '$UserPrincipalName' が見つかりません。" }
$user = @($user)[0]

$self = Get-AzADUser -UserPrincipalName $ctx.Account.Id
if ($self -and @($self)[0].Id -eq $user.Id) { throw '現在ログインしているアカウント自身は、削除できません。' }

$kind = if ($user.UserPrincipalName -match '#EXT#') { 'ゲスト' } else { 'メンバー' }
Say '削除対象:' -Color Cyan
Say ("  ユーザー名: {0}" -f $user.UserPrincipalName)
Say ("  種類      : {0}" -f $kind)
Say ("  ID        : {0}" -f $user.Id)

$assignments = @(Get-AzRoleAssignment -ObjectId $user.Id)
Say 'ロール割り当て:' -Color DarkGray
if ($assignments.Count -eq 0) { Say '  （なし）' -Color DarkGray }
else { $assignments | Format-Table RoleDefinitionName, Scope -AutoSize | Out-Host }

if (-not (Confirm-Action "ユーザー '$($user.UserPrincipalName)' とロール割り当てを削除しますか" -Force:$Force)) {
    Say 'キャンセルしました。' -Color Yellow
    return
}

foreach ($a in $assignments) {
    Say ("  ロール '{0}' を外します: {1}" -f $a.RoleDefinitionName, $a.Scope) -Color Cyan
    $null = Remove-AzRoleAssignment -InputObject $a
}
Say "  ユーザー '$($user.UserPrincipalName)' を削除します" -Color Cyan
Remove-AzADUser -ObjectId $user.Id
Say 'ユーザーを削除しました。' -Color Green
