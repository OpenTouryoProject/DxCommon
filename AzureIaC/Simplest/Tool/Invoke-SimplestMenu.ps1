<#
.SYNOPSIS
    Simplest の各 Tool を対話形式で実行するメニュー。

.DESCRIPTION
    次の流れで、同フォルダの各 *.ps1 を組み立てて実行する。
      1. コマンド選択   : 実行するスクリプトを選ぶ。
      2. オプション選択 : スクリプトのパラメータを入力する（Enter で既定値）。
      3. 確認           : 実行するコマンドラインを表示する。
      4. GO / NOGO      : GO と入力したときだけ実行する（読み取り専用の Show は Enter で実行）。
    実行後はコマンド選択へ戻る。途中で q を入力すると終了する（b で 1 つ前へ戻る）。
    事前に Connect-AzAccount でログインしておくこと。

.EXAMPLE
    .\Invoke-SimplestMenu.ps1
#>
[CmdletBinding()]
param()
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'Simplest.Common.ps1')

$loc = @{ Name = 'Location'; Prompt = 'リージョン'; Default = $DefaultLocation }
$size = @{ Name = 'VmSize'; Prompt = 'VM サイズ'; Default = $DefaultVmSize }
$os = @{ Name = 'OS'; Prompt = 'OS イメージ'; Kind = 'Choice'; Choices = @($VmImages.Keys); Default = $DefaultOS }
$noShut = @{ Name = 'NoAutoShutdown'; Prompt = '自動シャットダウンを設定しない'; Kind = 'Switch'; Default = $false }
$disk = @(@{ Name = 'OsDiskSizeGb'; Prompt = 'OS ディスク（C ドライブ）のサイズ GB（空 = イメージの既定）' },
          @{ Name = 'OsDiskType'; Prompt = 'OS ディスクの種類（StandardSSD_LRS / Premium_LRS / Standard_LRS。空 = Azure の既定）' })
$xrdp = @{ Name = 'InstallXrdp'; Prompt = 'Linux に xfce4 と xrdp をインストールする（Ubuntu2204 のみ）'; Kind = 'Switch'; Default = $false }
$cred = '管理者のユーザー名・パスワードは、実行時に入力を求められる。'

$commands = @(
    @{ Label = 'Test-Prerequisites : 前提（モジュール / ログイン / プロバイダー）を確認（読み取り専用）'; Script = 'Test-Prerequisites.ps1'; Danger = $false
       Params = @() },
    @{ Label = 'Test-Prerequisites -Register : 未登録のリソースプロバイダーを登録'; Script = 'Test-Prerequisites.ps1'; Danger = $true
       Note = 'サブスクリプションにリソースプロバイダーを登録する（無料・取り消し可能）。'
       Params = @(@{ Name = 'Register'; Prompt = '未登録のプロバイダーを登録する'; Kind = 'Switch'; Default = $true }) },
    @{ Label = 'New-Bastion      : Bastion（RG / VNet / Public IP / Bastion / Jumpbox サブネット）を作成'; Script = 'New-Bastion.ps1'; Danger = $true
       Note = 'Developer 以外は、作成に 10 分前後かかり、課金される（Developer は無料）。'
       Params = @($loc,
            @{ Name = 'ResourceGroupName'; Prompt = 'リソースグループ'; Default = 'AzureBastionRG' },
            @{ Name = 'VnetName'; Prompt = 'VNet 名'; Default = 'AzureBastionVnet' },
            @{ Name = 'BastionSku'; Prompt = 'Bastion の SKU（Developer: 無料・開発向け / Basic: 専用 / Standard: 機能が多く高価）'; Kind = 'Choice'; Choices = @('Developer', 'Basic', 'Standard'); Default = 'Developer' }) },
    @{ Label = 'New-JumpboxVM    : Jumpbox VM を作成（パブリック IP なし）'; Script = 'New-JumpboxVM.ps1'; Danger = $true; Note = $cred
       Params = @($loc,
            @{ Name = 'ResourceGroupName'; Prompt = 'リソースグループ'; Default = 'AzureBastionRG' },
            @{ Name = 'VmName'; Prompt = 'VM 名'; Default = 'JumpboxVM1' }, $size, $os, $noShut, $xrdp, $disk[0], $disk[1]) },
    @{ Label = 'New-Sandbox      : サンドボックス（RG / VNet / VM）を作成'; Script = 'New-Sandbox.ps1'; Danger = $true; Note = $cred
       Params = @($loc,
            @{ Name = 'ResourceGroupName'; Prompt = 'リソースグループ'; Default = 'YourRG' },
            @{ Name = 'VmName'; Prompt = 'VM 名'; Default = 'YourVM1' }, $size, $os, $noShut, $xrdp, $disk[0], $disk[1]) },
    @{ Label = 'New-VnetPeering  : Bastion VNet とサンドボックス VNet をピアリング'; Script = 'New-VnetPeering.ps1'; Danger = $true
       Params = @(
            @{ Name = 'BastionResourceGroupName'; Prompt = 'Bastion 側リソースグループ'; Default = 'AzureBastionRG' },
            @{ Name = 'SandboxResourceGroupName'; Prompt = 'サンドボックス側リソースグループ'; Default = 'YourRG' }) },
    @{ Label = 'Show-Simplest    : 構成の状態を表示（読み取り専用）'; Script = 'Show-Simplest.ps1'; Danger = $false
       Params = @(
            @{ Name = 'BastionResourceGroupName'; Prompt = 'Bastion 側リソースグループ'; Default = 'AzureBastionRG' },
            @{ Name = 'SandboxResourceGroupName'; Prompt = 'サンドボックス側リソースグループ'; Default = 'YourRG' }) },
    @{ Label = 'Set-VMPower      : VM を起動 / 停止（割り当て解除）/ 再起動'; Script = 'Set-VMPower.ps1'; Danger = $true
       Note = '課金を止めるには Stop（割り当て解除）を使う。'
       Params = @(
            @{ Name = 'ResourceGroupName'; Prompt = 'リソースグループ'; Default = 'YourRG' },
            @{ Name = 'VmName'; Prompt = 'VM 名'; Default = 'YourVM1' },
            @{ Name = 'Action'; Prompt = '操作'; Kind = 'Choice'; Choices = @('Start', 'Stop', 'Restart'); Default = 'Stop' }) },
    @{ Label = 'Remove-Simplest  : リソースグループを中身ごと削除（Bastion / サンドボックス）'; Script = 'Remove-Simplest.ps1'; Danger = $true; Destroy = $true
       Note = 'Bastion や VM の課金を止めたいときの片付け。'
       Params = @(@{ Name = 'ResourceGroupName'; Prompt = '削除するリソースグループ'; Required = $true }) }
)

Start-ToolMenu -Title 'Simplest 対話メニュー (Azure PowerShell)' -Commands $commands -ToolDir $PSScriptRoot
