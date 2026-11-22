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
    @{ Label = 'Test-Prerequisites     : 前提（モジュール / ログイン / プロバイダー）を確認（読み取り専用）'; Script = 'Test-Prerequisites.ps1'; Danger = $false
       Params = @() },
    @{ Label = 'Test-Prerequisites -Register : 未登録のリソースプロバイダーを登録'; Script = 'Test-Prerequisites.ps1'; Danger = $true
       Note = 'サブスクリプションにリソースプロバイダーを登録する（無料・取り消し可能）。'
       Params = @(@{ Name = 'Register'; Prompt = '未登録のプロバイダーを登録する'; Kind = 'Switch'; Default = $true }) },
    @{ Label = 'New-StorageAccount     : RG / ストレージアカウント / ロール / コンテナを作成'; Script = 'New-StorageAccount.ps1'; Danger = $true
       Note = '操作ユーザーに "Storage Blob Data Contributor" を割り当てる。'
       Params = @(
            @{ Name = 'Location'; Prompt = 'リージョン'; Default = $DefaultLocation }, $rg, $sa,
            @{ Name = 'ContainerName'; Prompt = 'コンテナ名'; Default = 'dxcmn' }) },
    @{ Label = 'Add-StorageNetworkRule : 許可する IP アドレスを追加'; Script = 'Add-StorageNetworkRule.ps1'; Danger = $true
       Params = @($rg, $sa, @{ Name = 'IpAddress'; Prompt = '許可する IP アドレス（範囲）'; Required = $true }) },
    @{ Label = 'Set-StorageSecurity    : 最小 TLS を 1.2 に上げる（匿名アクセス無効化も選べる）'; Script = 'Set-StorageSecurity.ps1'; Danger = $true
       Note = 'TLS 1.0 / 1.1 でしか接続できない古いクライアントは、接続できなくなる。変更前に、対象と現在の設定を表示して確認する。'
       Params = @(
            @{ Name = 'ResourceGroupName'; Prompt = 'リソースグループ（空 = サブスクリプション全体）' },
            @{ Name = 'StorageAccountName'; Prompt = 'ストレージアカウント名（空 = 対象範囲のすべて）' },
            @{ Name = 'DisableBlobPublicAccess'; Prompt = 'BLOB の匿名アクセスも無効にする'; Kind = 'Switch'; Default = $false },
            @{ Name = 'WhatIf'; Prompt = '変更せず、対象だけを表示する'; Kind = 'Switch'; Default = $true }) },
    @{ Label = 'Show-Storage           : 状態を表示（読み取り専用）'; Script = 'Show-Storage.ps1'; Danger = $false
       Params = @($rg, $sa) },
    @{ Label = 'Remove-StorageAccount  : ストレージアカウントを削除'; Script = 'Remove-StorageAccount.ps1'; Danger = $true; Destroy = $true
       Params = @($rg, @{ Name = 'StorageAccountName'; Prompt = '削除するストレージアカウント名'; Required = $true },
            @{ Name = 'RemoveResourceGroup'; Prompt = 'リソースグループごと削除する'; Kind = 'Switch'; Default = $false }) }
)

Start-ToolMenu -Title 'Storage 対話メニュー (Azure PowerShell)' -Commands $commands -ToolDir $PSScriptRoot
