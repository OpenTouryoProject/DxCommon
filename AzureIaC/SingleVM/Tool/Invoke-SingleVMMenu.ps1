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
    @{ Label = 'Test-Prerequisites : 前提（モジュール / ログイン / プロバイダー）を確認（読み取り専用）'; Script = 'Test-Prerequisites.ps1'; Danger = $false
       Params = @() },
    @{ Label = 'Test-Prerequisites -Register : 未登録のリソースプロバイダーを登録'; Script = 'Test-Prerequisites.ps1'; Danger = $true
       Note = 'サブスクリプションにリソースプロバイダーを登録する（無料・取り消し可能）。'
       Params = @(@{ Name = 'Register'; Prompt = '未登録のプロバイダーを登録する'; Kind = 'Switch'; Default = $true }) },
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
            @{ Name = 'Kind'; Prompt = '表示する種類'; Kind = 'Choice'; Choices = @('Sizes', 'Images'); Default = 'Sizes' }) },
    @{ Label = 'Set-VMPower     : VM を起動 / 停止（割り当て解除）/ 再起動'; Script = 'Set-VMPower.ps1'; Danger = $true
       Note = '課金を止めるには Stop（割り当て解除）を使う。'
       Params = @($rg, $vm,
            @{ Name = 'Action'; Prompt = '操作'; Kind = 'Choice'; Choices = @('Start', 'Stop', 'Restart'); Default = 'Stop' }) },
    @{ Label = 'Remove-SingleVM : VM を付随するリソースごと削除'; Script = 'Remove-SingleVM.ps1'; Danger = $true; Destroy = $true
       Note = 'VM / NIC / Public IP / NSG / VNet / ディスク / SSH キーを対象にする。'
       Params = @($rg, $vm,
            @{ Name = 'RemoveResourceGroup'; Prompt = 'VM 単位ではなく、リソースグループごと削除する'; Kind = 'Switch'; Default = $false }) }
)

Start-ToolMenu -Title 'SingleVM 対話メニュー (Azure PowerShell)' -Commands $commands -ToolDir $PSScriptRoot
