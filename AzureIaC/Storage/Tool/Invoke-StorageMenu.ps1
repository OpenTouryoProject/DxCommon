<#
.SYNOPSIS
    Storage の各 Tool を対話形式で実行するメニュー。

.DESCRIPTION
    次の流れで、同フォルダの各 *.ps1 を組み立てて実行する。
      1. コマンド選択   : 実行するスクリプトを選ぶ。
      2. オプション選択 : スクリプトのパラメータを入力する（Enter で既定値）。
      3. 確認           : 実行するコマンドラインを表示する。
      4. GO / NOGO      : GO と入力したときだけ実行する（読み取り専用の Show は Enter で実行）。
    実行後はコマンド選択へ戻る。途中で q を入力すると終了する（b で 1 つ前へ戻る）。
    事前に Connect-AzAccount でログインしておくこと。

.EXAMPLE
    .\Invoke-StorageMenu.ps1
#>
[CmdletBinding()]
param()
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'Storage.Common.ps1')

$rg = @{ Name = 'ResourceGroupName'; Prompt = 'リソースグループ'; Default = 'DxCmnRG' }
$sa = @{ Name = 'StorageAccountName'; Prompt = 'ストレージアカウント名（グローバルで一意）'; Default = 'osscjpdevinfra' }

$commands = @(
    @{ Label = 'New-StorageAccount     : RG / ストレージアカウント / ロール / コンテナを作成'; Script = 'New-StorageAccount.ps1'; Danger = $true
       Note = '操作ユーザーに "Storage Blob Data Contributor" を割り当てる。'
       Params = @(
            @{ Name = 'Location'; Prompt = 'リージョン'; Default = $DefaultLocation }, $rg, $sa,
            @{ Name = 'ContainerName'; Prompt = 'コンテナ名'; Default = 'dxcmn' }) },
    @{ Label = 'Add-StorageNetworkRule : 許可する IP アドレスを追加'; Script = 'Add-StorageNetworkRule.ps1'; Danger = $true
       Params = @($rg, $sa, @{ Name = 'IpAddress'; Prompt = '許可する IP アドレス（範囲）'; Required = $true }) },
    @{ Label = 'Show-Storage           : 状態を表示（読み取り専用）'; Script = 'Show-Storage.ps1'; Danger = $false
       Params = @($rg, $sa) }
)

Start-ToolMenu -Title 'Storage 対話メニュー (Azure PowerShell)' -Commands $commands -ToolDir $PSScriptRoot
