<#
.SYNOPSIS
    VM の状態・パブリック IP・NSG ルールを表示する（読み取り専用）。

.EXAMPLE
    .\Show-VMInfo.ps1 -ResourceGroupName hogeRG -VmName hogeVM
#>
[CmdletBinding()]
param(
    [string]$ResourceGroupName = 'hogeRG',
    [string]$VmName = 'hogeVM'
)
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'SingleVM.Common.ps1')
$null = Assert-AzLogin

$vm = Get-AzVM -ResourceGroupName $ResourceGroupName -Name $VmName -Status
$vmFull = Get-AzVM -ResourceGroupName $ResourceGroupName -Name $VmName
$isLinux = [bool]$vmFull.OSProfile.LinuxConfiguration
$ip = Get-VmPublicIp $vmFull

Say 'VM:' -Color Cyan
Say ("  名前       : {0}" -f $vm.Name)
Say ("  状態       : {0}" -f $vm.PowerState)
Say ("  サイズ     : {0}" -f $vmFull.HardwareProfile.VmSize)
Say ("  OS         : {0}" -f $(if ($isLinux) { 'Linux' } else { 'Windows' }))
Say ("  ユーザー   : {0}" -f $vmFull.OSProfile.AdminUsername)
Say ("  パブリック IP: {0}" -f $(if ($ip) { $ip } else { '（なし）' }))
if ($ip) {
    if ($isLinux) { Say ("  接続例     : ssh -i <秘密鍵> {0}@{1}" -f $vmFull.OSProfile.AdminUsername, $ip) -Color DarkGray }
    else { Say "  接続例     : mstsc /v:$ip" -Color DarkGray }
}

$nic = Get-VmNic $vmFull
if ($nic.NetworkSecurityGroup) {
    $r = Split-ResourceId $nic.NetworkSecurityGroup.Id
    $nsg = Get-AzNetworkSecurityGroup -ResourceGroupName $r.ResourceGroupName -Name $r.Name
    Say ''
    Say "NSG '$($nsg.Name)' の受信ルール:" -Color Cyan
    $nsg.SecurityRules | Where-Object { $_.Direction -eq 'Inbound' } | Sort-Object Priority |
        Format-Table Name, Priority, Access, Protocol, SourceAddressPrefix, DestinationPortRange -AutoSize | Out-Host
}
