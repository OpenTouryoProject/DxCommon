<#
.SYNOPSIS
    Azure Bastion（RG / VNet / Public IP / Bastion / Jumpbox 用サブネット）を作成する。

.DESCRIPTION
    Research の 1.common.sh を Azure PowerShell に置き換えたもの。
    既に存在するリソースは作成せずスキップする。Bastion の作成には 10 分前後かかり、課金が発生する。

.EXAMPLE
    .\New-Bastion.ps1
#>
[CmdletBinding()]
param(
    [string]$Location = 'japaneast',
    [string]$ResourceGroupName = 'AzureBastionRG',
    [string]$BastionName = 'AzureBastion',
    [string]$VnetName = 'AzureBastionVnet',
    [string]$BastionSubnetName = 'AzureBastionSubnet',   # Bastion 用は、この名前固定
    [string]$JumpboxSubnetName = 'JumpboxSubnet',
    [string]$PublicIpName = 'AzureBastionPubIP'
)
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'Simplest.Common.ps1')
$null = Assert-AzLogin
Assert-ResourceProviders $RequiredProviders

Initialize-ResourceGroup $ResourceGroupName $Location

# VNet（Bastion 用サブネット）
$vnet = Get-AzVirtualNetwork -ResourceGroupName $ResourceGroupName -Name $VnetName -ErrorAction SilentlyContinue
if ($vnet) {
    Say "  VNet '$VnetName' は既に存在します（スキップ）" -Color DarkGray
}
else {
    Say "  VNet '$VnetName' を作成します" -Color Cyan
    $bastionSubnet = New-AzVirtualNetworkSubnetConfig -Name $BastionSubnetName -AddressPrefix '10.0.0.0/24'
    $vnet = New-AzVirtualNetwork -ResourceGroupName $ResourceGroupName -Name $VnetName `
        -Location $Location -AddressPrefix '10.0.0.0/16' -Subnet $bastionSubnet
}

# Public IP
$pip = Get-AzPublicIpAddress -ResourceGroupName $ResourceGroupName -Name $PublicIpName -ErrorAction SilentlyContinue
if ($pip) {
    Say "  Public IP '$PublicIpName' は既に存在します（スキップ）" -Color DarkGray
}
else {
    Say "  Public IP '$PublicIpName' を作成します" -Color Cyan
    $pip = New-AzPublicIpAddress -ResourceGroupName $ResourceGroupName -Name $PublicIpName `
        -Location $Location -Sku Standard -AllocationMethod Static
}

# Bastion
$bastion = Get-AzBastion -ResourceGroupName $ResourceGroupName -Name $BastionName -ErrorAction SilentlyContinue
if ($bastion) {
    Say "  Bastion '$BastionName' は既に存在します（スキップ）" -Color DarkGray
}
else {
    Say "  Bastion '$BastionName' を作成します（10 分前後かかります）" -Color Cyan
    $null = New-AzBastion -ResourceGroupName $ResourceGroupName -Name $BastionName `
        -PublicIpAddress $pip -VirtualNetwork $vnet
}

# Jumpbox 用サブネット
$vnet = Get-AzVirtualNetwork -ResourceGroupName $ResourceGroupName -Name $VnetName
if ($vnet.Subnets | Where-Object { $_.Name -eq $JumpboxSubnetName }) {
    Say "  サブネット '$JumpboxSubnetName' は既に存在します（スキップ）" -Color DarkGray
}
else {
    Say "  サブネット '$JumpboxSubnetName' を作成します" -Color Cyan
    $null = Add-AzVirtualNetworkSubnetConfig -VirtualNetwork $vnet -Name $JumpboxSubnetName -AddressPrefix '10.0.1.0/24'
    $null = Set-AzVirtualNetwork -VirtualNetwork $vnet
}

Say '完了: Bastion 環境を作成しました。' -Color Green
