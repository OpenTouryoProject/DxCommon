<#
.SYNOPSIS
    Monitor（セキュリティ / 課金）の各 Tool を対話形式で実行するメニュー。

.DESCRIPTION
    次の流れで、同フォルダの各 *.ps1 を組み立てて実行する。
      1. コマンド選択   : 実行するスクリプトを選ぶ。
      2. オプション選択 : スクリプトのパラメータを入力する（Enter で既定値）。
      3. 確認           : 実行するコマンドラインを表示する。
      4. GO / NOGO      : GO と入力したときだけ実行する（読み取り専用の Show は Enter で実行）。
    実行後はコマンド選択へ戻る。途中で q を入力すると終了する（b で 1 つ前へ戻る）。
    事前に Connect-AzAccount でログインしておくこと。

.EXAMPLE
    .\Invoke-MonitorMenu.ps1
#>
[CmdletBinding()]
param()
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'Monitor.Common.ps1')

$commands = @(
    @{ Label = 'Test-Prerequisites     : 前提（モジュール / ログイン / プロバイダー）を確認（読み取り専用）'; Script = 'Test-Prerequisites.ps1'; Danger = $false
       Params = @() },
    @{ Label = 'Test-Prerequisites -Register : 未登録のリソースプロバイダーを登録'; Script = 'Test-Prerequisites.ps1'; Danger = $true
       Note = 'サブスクリプションにリソースプロバイダーを登録する（無料・取り消し可能）。Microsoft.CostManagement が未登録だと、課金が取得できないことがある。'
       Params = @(@{ Name = 'Register'; Prompt = '未登録のプロバイダーを登録する'; Kind = 'Switch'; Default = $true }) },
    @{ Label = 'Show-InboundSecurity   : インバウンド（NSG / パブリック IP / ストレージ）を表示（読み取り専用）'; Script = 'Show-InboundSecurity.ps1'; Danger = $false
       Params = @(
            @{ Name = 'ResourceGroupName'; Prompt = 'リソースグループ（空 = サブスクリプション全体）' },
            @{ Name = 'ShowAll'; Prompt = '危険でないルールも表示する'; Kind = 'Switch'; Default = $false }) },
    @{ Label = 'Show-Billing           : 課金（過去 30 日 / 先月 / 当月の予実）を表示（読み取り専用）'; Script = 'Show-Billing.ps1'; Danger = $false
       Params = @(@{ Name = 'TopServices'; Prompt = 'サービス別の上位件数（0 = 表示しない）'; Default = '5' }) }
)

Start-ToolMenu -Title 'Monitor 対話メニュー (Azure PowerShell)' -Commands $commands -ToolDir $PSScriptRoot
