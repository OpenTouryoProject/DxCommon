<#
.SYNOPSIS
    AzureIaC の各 Tool（Simplest / SingleVM / Storage / AddUsers / Monitor）の対話メニューを選んで起動する。

.DESCRIPTION
    各フォルダの Tool\Invoke-*Menu.ps1 を、1 つ選んで実行する。メニューを終了（q）すると、ここへ戻る。
    ここで q を入力すると終了する。
    事前に Connect-AzAccount でログインしておくこと。
    前提（モジュール / リソースプロバイダー）は、各メニューの Test-Prerequisites で確認できる。

.EXAMPLE
    .\Invoke-AzureIaCMenu.ps1
#>
[CmdletBinding()]
param()
$ErrorActionPreference = 'Stop'

function Say([string]$Text = '', [string]$Color = 'Gray') { Write-Host $Text -ForegroundColor $Color }

function Read-Input([string]$Prompt) {
    $v = Read-Host $Prompt
    if ($null -eq $v) { return '' }
    $v = $v.Trim()
    if ($v -ieq 'q') { throw [System.OperationCanceledException]::new('quit') }
    return $v
}

$tools = @(
    @{ Label = 'Simplest : Bastion + Jumpbox + サンドボックス + VNet ピアリング'; Menu = 'Simplest\Tool\Invoke-SimplestMenu.ps1' },
    @{ Label = 'SingleVM : 単体 VM（Windows / Linux）';                           Menu = 'SingleVM\Tool\Invoke-SingleVMMenu.ps1' },
    @{ Label = 'Storage  : ストレージアカウント + コンテナ';                       Menu = 'Storage\Tool\Invoke-StorageMenu.ps1' },
    @{ Label = 'AddUsers : ユーザー追加（カスタムロール / ユーザー / ロール付与）'; Menu = 'AddUsers\Tool\Invoke-AddUsersMenu.ps1' },
    @{ Label = 'Monitor  : セキュリティ（インバウンド）/ 課金の監視（読み取り専用）'; Menu = 'Monitor\Tool\Invoke-MonitorMenu.ps1' }
)

Say '==== AzureIaC 対話メニュー (Azure PowerShell) ====' -Color Green
$ctx = Get-AzContext
if ($ctx) {
    Say ("  アカウント     : {0}" -f $ctx.Account.Id) -Color DarkGray
    Say ("  サブスクリプション: {0} ({1})" -f $ctx.Subscription.Name, $ctx.Subscription.Id) -Color DarkGray
}
else {
    Say '  Azure にログインしていません。Connect-AzAccount を実行してから、やり直してください。' -Color Red
    return
}

try {
    while ($true) {
        Say ''
        Say '使う Tool を選んでください' -Color Cyan
        for ($i = 0; $i -lt $tools.Count; $i++) { Say ("  {0}) {1}" -f ($i + 1), $tools[$i].Label) }
        Say '  (q: 終了)' -Color DarkGray

        $s = Read-Input '番号'
        $n = 0
        if (-not ([int]::TryParse($s, [ref]$n) -and $n -ge 1 -and $n -le $tools.Count)) {
            Say '番号が正しくありません。' -Color Yellow
            continue
        }

        $path = Join-Path $PSScriptRoot $tools[$n - 1].Menu
        if (-not (Test-Path $path)) { Say "見つかりません: $path" -Color Red; continue }
        Say ''
        & $path
    }
}
catch [System.OperationCanceledException] {
    # q で終了
}

Say ''
Say '終了します。' -Color DarkGray
