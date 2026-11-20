<#
.SYNOPSIS
    サンドボックス（RG / VNet / VM）を作成する。

.DESCRIPTION
    Research の 3.sandbox.sh を Azure PowerShell に置き換えたもの。
    VM はパブリック IP なしで作る。Bastion からの接続には、New-VnetPeering.ps1 で VNet をピアリングする。
    管理者のユーザー名とパスワードは、実行時に Get-Credential で入力する（-Credential でも渡せる）。

.EXAMPLE
    .\New-Sandbox.ps1
#>
[CmdletBinding()]
param(
    [string]$Location = 'japaneast',
    [string]$ResourceGroupName = 'YourRG',
    [string]$VnetName = 'YourVnet',
    [string]$SubnetName = 'YourSubnet',
    [string]$VmName = 'YourVM1',
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

Initialize-ResourceGroup $ResourceGroupName $Location

$vnet = Get-AzVirtualNetwork -ResourceGroupName $ResourceGroupName -Name $VnetName -ErrorAction SilentlyContinue
if ($vnet) {
    Say "  VNet '$VnetName' は既に存在します（スキップ）" -Color DarkGray
}
else {
    Say "  VNet '$VnetName' を作成します" -Color Cyan
    $subnet = New-AzVirtualNetworkSubnetConfig -Name $SubnetName -AddressPrefix '10.1.0.0/24'
    $null = New-AzVirtualNetwork -ResourceGroupName $ResourceGroupName -Name $VnetName `
        -Location $Location -AddressPrefix '10.1.0.0/16' -Subnet $subnet
}

New-PrivateVM -ResourceGroupName $ResourceGroupName -Location $Location -VmName $VmName -VmSize $VmSize `
    -OS $OS -Credential $cred -VnetName $VnetName -SubnetName $SubnetName

if (-not $NoAutoShutdown) {
    Set-VmAutoShutdown -ResourceGroupName $ResourceGroupName -VmName $VmName -Location $Location -Time $AutoShutdownTime
}

Say ''
Say 'Public IP 一覧:' -Color Cyan
Get-AzPublicIpAddress | Format-Table Name, ResourceGroupName, IpAddress, Sku -AutoSize | Out-Host

Say "完了: サンドボックス VM '$VmName' を作成しました。" -Color Green
