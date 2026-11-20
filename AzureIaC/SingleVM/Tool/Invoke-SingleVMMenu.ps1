<#
.SYNOPSIS
    SingleVM の各 Tool を対話形式で実行するメニュー。

.DESCRIPTION
    次の流れで、同フォルダの各 *.ps1 を組み立てて実行する。
      1. コマンド選択   : 実行するスクリプトを選ぶ。
      2. オプション選択 : スクリプトのパラメータを入力する（Enter で既定値）。
      3. 確認           : 実行するコマンドラインを表示する。
      4. GO / NOGO      : GO と入力したときだけ実行する（読み取り専用の Show は Enter で実行）。
    実行後はコマンド選択へ戻る。途中で q を入力すると終了する（b で 1 つ前へ戻る）。
    事前に Connect-AzAccount でログインしておくこと。

.EXAMPLE
    .\Invoke-SingleVMMenu.ps1
#>
[CmdletBinding()]
param()
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'SingleVM.Common.ps1')

$loc = @{ Name = 'Location'; Prompt = 'リージョン'; Default = $DefaultLocation }
$rg = @{ Name = 'ResourceGroupName'; Prompt = 'リソースグループ'; Default = 'hogeRG' }
$vm = @{ Name = 'VmName'; Prompt = 'VM 名'; Default = 'hogeVM' }

$commands = @(
    @{ Label = 'New-SingleVM    : 単体 VM を作成（Windows / Linux）'; Script = 'New-SingleVM.ps1'; Danger = $true
       Note = '管理者のユーザー名・パスワードは、実行時に入力を求められる。Linux は SSH 鍵も作成する。VM は課金される。'
       Params = @($loc, $rg, $vm,
            @{ Name = 'VmSize'; Prompt = 'VM サイズ'; Default = 'Standard_D4s_v3' },
            @{ Name = 'OS'; Prompt = 'OS イメージ'; Kind = 'Choice'; Choices = @($VmImages.Keys); Default = 'Win2019Datacenter' }) },
    @{ Label = 'Open-VMPort     : VM の受信ポートを開ける（NSG ルール追加）'; Script = 'Open-VMPort.ps1'; Danger = $true
       Note = '送信元を * にすると、インターネット全体に公開される。'
       Params = @($rg, $vm,
            @{ Name = 'Port'; Prompt = '開けるポート'; Default = '3389' },
            @{ Name = 'SourceAddressPrefix'; Prompt = '許可する送信元（IP / CIDR / *）'; Default = '*' }) },
    @{ Label = 'Show-VMInfo     : VM の状態・パブリック IP・NSG を表示（読み取り専用）'; Script = 'Show-VMInfo.ps1'; Danger = $false
       Params = @($rg, $vm) },
    @{ Label = 'Show-VMCatalog  : VM サイズ / イメージの一覧を表示（読み取り専用）'; Script = 'Show-VMCatalog.ps1'; Danger = $false
       Params = @($loc,
            @{ Name = 'Kind'; Prompt = '表示する種類'; Kind = 'Choice'; Choices = @('Sizes', 'Images'); Default = 'Sizes' }) }
)

Start-ToolMenu -Title 'SingleVM 対話メニュー (Azure PowerShell)' -Commands $commands -ToolDir $PSScriptRoot
