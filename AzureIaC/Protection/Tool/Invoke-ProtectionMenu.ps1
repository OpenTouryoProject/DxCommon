<#
.SYNOPSIS
    Protection（リソースグループのロック）の各 Tool を対話形式で実行するメニュー。

.DESCRIPTION
    次の流れで、同フォルダの各 *.ps1 を組み立てて実行する。
      1. コマンド選択   : 実行するスクリプトを選ぶ。
      2. オプション選択 : スクリプトのパラメータを入力する（Enter で既定値）。
      3. 確認           : 実行するコマンドラインを表示する。
      4. GO / NOGO      : GO と入力したときだけ実行する（読み取り専用の Show は Enter で実行）。
    実行後はコマンド選択へ戻る。途中で q を入力すると終了する（b で 1 つ前へ戻る）。
    事前に Connect-AzAccount でログインしておくこと。

.EXAMPLE
    .\Invoke-ProtectionMenu.ps1
#>
[CmdletBinding()]
param()
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'Protection.Common.ps1')

$rg = @{ Name = 'ResourceGroupName'; Prompt = 'リソースグループ'; Required = $true }

$commands = @(
    @{ Label = 'Test-Prerequisites : 前提（モジュール / ログイン）を確認（読み取り専用）'; Script = 'Test-Prerequisites.ps1'; Danger = $false
       Params = @() },
    @{ Label = 'Show-ResourceLock  : ロックの一覧を表示（読み取り専用）'; Script = 'Show-ResourceLock.ps1'; Danger = $false
       Params = @(@{ Name = 'ResourceGroupName'; Prompt = 'リソースグループ（空 = サブスクリプション全体）' }) },
    @{ Label = 'Set-ResourceLock   : RG にロックを付ける（CanNotDelete / ReadOnly）'; Script = 'Set-ResourceLock.ps1'; Danger = $true
       Note = 'CanNotDelete: 削除だけを防ぐ。ReadOnly: 変更も防ぐ（VM の起動・停止なども止まる）。いつでも Remove-ResourceLock で外せる。'
       Params = @($rg,
            @{ Name = 'LockLevel'; Prompt = 'ロックの種類'; Kind = 'Choice'; Choices = @('CanNotDelete', 'ReadOnly'); Default = 'CanNotDelete' }) },
    @{ Label = 'Remove-ResourceLock: RG のロックを外す（元に戻す）'; Script = 'Remove-ResourceLock.ps1'; Danger = $true
       Note = '外すと、削除・変更が、またできるようになる。'
       Params = @($rg, @{ Name = 'LockName'; Prompt = '外すロック名（空 = その RG のすべて）' }) }
)

Start-ToolMenu -Title 'Protection 対話メニュー (Azure PowerShell)' -Commands $commands -ToolDir $PSScriptRoot
