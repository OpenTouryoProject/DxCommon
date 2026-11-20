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
    if (Get-AzRoleDefinition -Name $def.Name -ErrorAction SilentlyContinue -WarningAction SilentlyContinue) {
        Say "  ロール '$($def.Name)' は既に存在します（スキップ）" -Color DarkGray
        continue
    }
    Say "  ロール '$($def.Name)' を作成します" -Color Cyan
    $role = Get-AzRoleDefinition 'Virtual Machine Contributor' -WarningAction SilentlyContinue
    $role.Id = $null
    $role.Name = $def.Name
    $role.Description = $def.Description
    # Az.Resources 10.x 以降は Actions などが Permissions[n] 配下に移っている（旧: $role.Actions）。
    $perm = $role.Permissions[0]
    $perm.Actions = [System.Collections.Generic.List[string]]::new([string[]]$def.Actions)
    $perm.NotActions = [System.Collections.Generic.List[string]]::new()
    $perm.DataActions = [System.Collections.Generic.List[string]]::new()
    $perm.NotDataActions = [System.Collections.Generic.List[string]]::new()
    $role.AssignableScopes.Clear()
    $role.AssignableScopes.Add("/subscriptions/$subscriptionId")
    $null = New-AzRoleDefinition -Role $role -WarningAction SilentlyContinue
}

Say '完了: カスタムロールを用意しました。' -Color Green
