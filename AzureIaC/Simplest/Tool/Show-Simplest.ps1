<#
.SYNOPSIS
    Simplest 構成（Bastion / Jumpbox / Sandbox / ピアリング）の状態を表示する（読み取り専用）。

.EXAMPLE
    .\Show-Simplest.ps1
#>
[CmdletBinding()]
param(
    [string]$BastionResourceGroupName = 'AzureBastionRG',
    [string]$SandboxResourceGroupName = 'YourRG'
)
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'Simplest.Common.ps1')
$null = Assert-AzLogin

foreach ($rg in @($BastionResourceGroupName, $SandboxResourceGroupName)) {
    Say ''
    Say "==== $rg ====" -Color Cyan
    if (-not (Get-AzResourceGroup -Name $rg -ErrorAction SilentlyContinue)) {
        Say '  リソースグループがありません。' -Color Yellow
        continue
    }
    Say 'VNet / サブネット:' -Color DarkGray
    foreach ($v in (Get-AzVirtualNetwork -ResourceGroupName $rg)) {
        Say ("  {0}  {1}  サブネット: {2}" -f $v.Name, ($v.AddressSpace.AddressPrefixes -join ','), (($v.Subnets | ForEach-Object Name) -join ','))
        Get-AzVirtualNetworkPeering -VirtualNetworkName $v.Name -ResourceGroupName $rg |
            ForEach-Object { Say ("    peering {0}: {1}" -f $_.Name, $_.PeeringState) }
    }
    Say 'Bastion:' -Color DarkGray
    Get-AzBastion -ResourceGroupName $rg | Format-Table Name, ProvisioningState, Sku -AutoSize | Out-Host
    Say 'VM:' -Color DarkGray
    Get-AzVM -ResourceGroupName $rg -Status | Format-Table Name, PowerState, Location -AutoSize | Out-Host
    Say 'Public IP:' -Color DarkGray
    Get-AzPublicIpAddress -ResourceGroupName $rg | Format-Table Name, IpAddress, Sku -AutoSize | Out-Host
}
