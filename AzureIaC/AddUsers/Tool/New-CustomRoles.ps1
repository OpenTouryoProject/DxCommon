<#
.SYNOPSIS
    ユーザー追加用のカスタムロール 3 種を、現在のサブスクリプションに作成する。

.DESCRIPTION
    Research の「Creating a custom role」を Azure PowerShell に置き換えたもの。
    "Virtual Machine Contributor" を元に、次のロールを作る。既に同名のロールがあればスキップする。
      - 仮想マシンの起動と停止
      - 仮想マシン作成のためVMCに追加する権限
      - Azure Cloud Shellの実行のために追加する権限
    ロール定義の作成には、サブスクリプションの所有者などの権限が必要。

.EXAMPLE
    .\New-CustomRoles.ps1
#>
[CmdletBinding()]
param()
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'AddUsers.Common.ps1')
$ctx = Assert-AzLogin
$subscriptionId = $ctx.Subscription.Id
Say "  サブスクリプション: $subscriptionId" -Color DarkGray

foreach ($def in $CustomRoles) {
    if (Get-AzRoleDefinition -Name $def.Name -ErrorAction SilentlyContinue) {
        Say "  ロール '$($def.Name)' は既に存在します（スキップ）" -Color DarkGray
        continue
    }
    Say "  ロール '$($def.Name)' を作成します" -Color Cyan
    $role = Get-AzRoleDefinition 'Virtual Machine Contributor'
    $role.Id = $null
    $role.Name = $def.Name
    $role.Description = $def.Description
    $role.Actions.Clear()
    foreach ($a in $def.Actions) { $role.Actions.Add($a) }
    $role.AssignableScopes.Clear()
    $role.AssignableScopes.Add("/subscriptions/$subscriptionId")
    $null = New-AzRoleDefinition -Role $role
}

Say '完了: カスタムロールを用意しました。' -Color Green
