<#
.SYNOPSIS
    Bastion VNet とサンドボックス VNet を双方向にピアリングする。

.DESCRIPTION
    Research の 4.vnet_peering.sh を Azure PowerShell に置き換えたもの。
    既に存在するピアリングはスキップし、最後に PeeringState を表示する。

.EXAMPLE
    .\New-VnetPeering.ps1
#>
[CmdletBinding()]
param(
    [string]$BastionResourceGroupName = 'AzureBastionRG',
    [string]$BastionVnetName = 'AzureBastionVnet',
    [string]$SandboxResourceGroupName = 'YourRG',
    [string]$SandboxVnetName = 'YourVnet'
)
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'Simplest.Common.ps1')
$null = Assert-AzLogin

$vnet1 = Get-AzVirtualNetwork -ResourceGroupName $BastionResourceGroupName -Name $BastionVnetName
$vnet2 = Get-AzVirtualNetwork -ResourceGroupName $SandboxResourceGroupName -Name $SandboxVnetName
Say "  VNet1: $($vnet1.Id)" -Color DarkGray
Say "  VNet2: $($vnet2.Id)" -Color DarkGray

$pairs = @(
    @{ Name = "$BastionVnetName-$SandboxVnetName"; Vnet = $vnet1; Remote = $vnet2 },
    @{ Name = "$SandboxVnetName-$BastionVnetName"; Vnet = $vnet2; Remote = $vnet1 }
)
foreach ($p in $pairs) {
    $rg = $p.Vnet.ResourceGroupName
    if (Get-AzVirtualNetworkPeering -Name $p.Name -VirtualNetworkName $p.Vnet.Name -ResourceGroupName $rg -ErrorAction SilentlyContinue) {
        Say "  ピアリング '$($p.Name)' は既に存在します（スキップ）" -Color DarkGray
    }
    else {
        Say "  ピアリング '$($p.Name)' を作成します" -Color Cyan
        $null = Add-AzVirtualNetworkPeering -Name $p.Name -VirtualNetwork $p.Vnet -RemoteVirtualNetworkId $p.Remote.Id
    }
}

Say ''
Say 'PeeringState:' -Color Cyan
foreach ($p in $pairs) {
    Get-AzVirtualNetworkPeering -Name $p.Name -VirtualNetworkName $p.Vnet.Name -ResourceGroupName $p.Vnet.ResourceGroupName |
        Format-Table Name, PeeringState, AllowVirtualNetworkAccess -AutoSize | Out-Host
}
Say '完了: VNet ピアリングを設定しました。' -Color Green
