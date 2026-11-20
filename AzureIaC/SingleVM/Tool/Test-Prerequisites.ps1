<#
.SYNOPSIS
    この Tool を使うための前提（Az モジュール・ログイン・リソースプロバイダー）を確認する。

.DESCRIPTION
    次を確認する。
      1. PowerShell のバージョン
      2. 必要な Az モジュールのインストール
      3. Azure へのログイン（現在のアカウントとサブスクリプション）
      4. 必要なリソースプロバイダーの登録状態
    リソースプロバイダーが未登録だと、作成系のコマンドが 'NotFound' などで失敗する。
    -Register を付けると、未登録のプロバイダーをサブスクリプションに登録する（無料・取り消し可能）。
    確認のみ（-Register なし）の場合は何も変更しない。

    ※ MFA が必須のテナントでは、作成・削除の操作が MFA 未実施のトークンで拒否されることがある。
      その場合は Connect-AzAccount -Tenant <テナントID> を、MFA を通して再実行する。

.PARAMETER Register
    未登録のリソースプロバイダーを登録する。

.EXAMPLE
    .\Test-Prerequisites.ps1
    .\Test-Prerequisites.ps1 -Register
#>
[CmdletBinding()]
param(
    [switch]$Register
)
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot (Get-ChildItem $PSScriptRoot -Filter '*.Common.ps1' | Select-Object -First 1).Name)

$ok = $true
function Report([bool]$Pass, [string]$Text) {
    if ($Pass) { Say ("  [OK] {0}" -f $Text) -Color Green }
    else { Say ("  [NG] {0}" -f $Text) -Color Red; $script:ok = $false }
}

# 1. PowerShell
Say 'PowerShell' -Color Cyan
Report ($PSVersionTable.PSVersion.Major -ge 5) ("バージョン {0}" -f $PSVersionTable.PSVersion)

# 2. モジュール
Say 'Az モジュール' -Color Cyan
foreach ($m in $RequiredModules) {
    $mod = Get-Module -ListAvailable $m | Sort-Object Version -Descending | Select-Object -First 1
    Report ([bool]$mod) $(if ($mod) { "$m $($mod.Version)" } else { "$m がありません（Install-Module Az を実行）" })
}

# 3. ログイン
Say 'ログイン' -Color Cyan
$ctx = Get-AzContext
Report ([bool]$ctx) $(if ($ctx) { "{0} / {1} ({2})" -f $ctx.Account.Id, $ctx.Subscription.Name, $ctx.Subscription.Id } else { 'ログインしていません（Connect-AzAccount を実行）' })

# 4. リソースプロバイダー
if ($ctx) {
    Say 'リソースプロバイダー' -Color Cyan
    $missing = @()
    foreach ($ns in $RequiredProviders) {
        $state = Get-ProviderState $ns
        Report ($state -eq 'Registered') ("{0} : {1}" -f $ns, $state)
        if ($state -ne 'Registered') { $missing += $ns }
    }

    if ($missing.Count -gt 0 -and $Register) {
        Say ''
        foreach ($ns in $missing) {
            Say "  '$ns' を登録します" -Color Cyan
            $null = Register-AzResourceProvider -ProviderNamespace $ns
        }
        $deadline = (Get-Date).AddMinutes(5)
        do {
            Start-Sleep -Seconds 10
            $pending = @($missing | Where-Object { (Get-ProviderState $_) -ne 'Registered' })
        } while ($pending.Count -gt 0 -and (Get-Date) -lt $deadline)
        foreach ($ns in $missing) {
            Report ((Get-ProviderState $ns) -eq 'Registered') ("{0} : {1}" -f $ns, (Get-ProviderState $ns))
        }
    }
    elseif ($missing.Count -gt 0) {
        Say ''
        Say '  未登録のプロバイダーは、-Register を付けて再実行すると登録できます。' -Color Yellow
    }
}

Say ''
if ($ok) { Say '前提はすべて満たされています。' -Color Green }
else { Say '満たされていない前提があります。上の [NG] を確認してください。' -Color Yellow }
