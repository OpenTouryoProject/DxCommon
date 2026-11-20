<#
.SYNOPSIS
    ゲストユーザー、カスタムロール、ユーザーのロール割り当てを表示する（読み取り専用）。

.DESCRIPTION
    ゲスト一覧は Microsoft Graph（GET /users）、ロールは Az で取得する。
    -UserPrincipalName を指定すると、そのユーザーのロール割り当てを表示する。

.EXAMPLE
    .\Show-Users.ps1
    .\Show-Users.ps1 -UserPrincipalName user@example.com
#>
[CmdletBinding()]
param(
    [string]$UserPrincipalName
)
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'AddUsers.Common.ps1')
$ctx = Assert-AzLogin

Say 'カスタムロール:' -Color Cyan
Get-AzRoleDefinition -Custom | Where-Object { $CustomRoles.Name -contains $_.Name } |
    Format-Table Name, Description -AutoSize | Out-Host

Say 'ゲストユーザー:' -Color Cyan
try {
    $filter = [uri]::EscapeDataString("userType eq 'Guest'")
    $res = Invoke-GraphApi -Method GET -Path "/users?`$filter=$filter&`$select=displayName,mail,userPrincipalName,createdDateTime"
    $res.value | Format-Table displayName, mail, createdDateTime -AutoSize | Out-Host
}
catch { Say ("  取得できません: {0}" -f $_.Exception.Message) -Color Yellow }

if ($UserPrincipalName) {
    Say "ロール割り当て: $UserPrincipalName" -Color Cyan
    Get-AzRoleAssignment -SignInName $UserPrincipalName |
        Format-Table RoleDefinitionName, Scope -AutoSize | Out-Host
}
