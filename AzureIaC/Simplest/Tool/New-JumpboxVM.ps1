<#
.SYNOPSIS
    Bastion 経由で接続する Jumpbox VM（パブリック IP なし）を作成する。

.DESCRIPTION
    Research の 2.jumpbox_vm.sh を Azure PowerShell に置き換えたもの。
    事前に New-Bastion.ps1 を実行して、VNet / Jumpbox 用サブネットを作っておく。
    管理者のユーザー名とパスワードは、実行時に Get-Credential で入力する（-Credential でも渡せる）。

.PARAMETER OS
    Win2019Datacenter / Win2022Datacenter / Ubuntu2204

.PARAMETER AutoShutdownTime
    自動シャットダウン時刻（UTC の HHmm）。既定 1500 = JST 0000。-NoAutoShutdown で設定しない。

.EXAMPLE
    .\New-JumpboxVM.ps1
#>
[CmdletBinding()]
param(
    [string]$Location = 'japaneast',
    [string]$ResourceGroupName = 'AzureBastionRG',
    [string]$VnetName = 'AzureBastionVnet',
    [string]$SubnetName = 'JumpboxSubnet',
    [string]$VmName = 'JumpboxVM1',
    [string]$VmSize = 'Standard_D4s_v3',
    [ValidateSet('Win2019Datacenter', 'Win2022Datacenter', 'Ubuntu2204')]
    [string]$OS = 'Win2019Datacenter',
    [pscredential]$Credential,
    [string]$AutoShutdownTime = '1500',
    [switch]$NoAutoShutdown
)
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'Simplest.Common.ps1')
$null = Assert-AzLogin

$cred = Get-CredentialIfNull $Credential "VM '$VmName' の管理者ユーザー名とパスワード"
New-PrivateVM -ResourceGroupName $ResourceGroupName -Location $Location -VmName $VmName -VmSize $VmSize `
    -OS $OS -Credential $cred -VnetName $VnetName -SubnetName $SubnetName

if (-not $NoAutoShutdown) {
    Set-VmAutoShutdown -ResourceGroupName $ResourceGroupName -VmName $VmName -Location $Location -Time $AutoShutdownTime
}

Say ''
Say 'Public IP 一覧:' -Color Cyan
Get-AzPublicIpAddress | Format-Table Name, ResourceGroupName, IpAddress, Sku -AutoSize | Out-Host

Say "完了: VM '$VmName' を作成しました。Azure Portal から Bastion 経由で接続してください。" -Color Green
