<#
.SYNOPSIS
    VM の NIC から Public IP を外して、削除する。

.DESCRIPTION
    VM の 1 つ目の NIC に付いた Public IP を外し、Public IP リソースを削除する（-KeepPublicIp で、外すだけ）。
    NSG とルールは、そのまま残す（受信の許可ルールが残っていても、Public IP が無ければ届かない）。
    削除前に、対象を表示して確認する（-Force で確認を省略）。

.EXAMPLE
    .\Remove-VMPublicIp.ps1 -ResourceGroupName AzureBastionRG -VmName WorkVM2
#>
[CmdletBinding()]
param(
    [string]$ResourceGroupName = 'hogeRG',
    [string]$VmName = 'hogeVM',
    [switch]$KeepPublicIp,
    [switch]$Force
)
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'SingleVM.Common.ps1')
$null = Assert-AzLogin

$vm = Get-AzVM -ResourceGroupName $ResourceGroupName -Name $VmName
$nic = Get-VmNic $vm
$pipId = $nic.IpConfigurations[0].PublicIpAddress.Id
if (-not $pipId) { Say "VM '$VmName' には Public IP が付いていません。" -Color Yellow; return }
$r = Split-ResourceId $pipId
$pip = Get-AzPublicIpAddress -ResourceGroupName $r.ResourceGroupName -Name $r.Name

Say ("対象: Public IP '{0}'（{1}）を、VM '{2}' から外します{3}" -f $pip.Name, $pip.IpAddress, $VmName, $(if ($KeepPublicIp) { '' } else { '。外したあと、削除します' })) -Color Cyan
if (-not (Confirm-Action 'よろしいですか' -Force:$Force)) { Say '中止しました。' -Color Yellow; return }

$nic.IpConfigurations[0].PublicIpAddress = $null
$null = Set-AzNetworkInterface -NetworkInterface $nic
Say '  NIC から Public IP を外しました' -Color DarkGray
if (-not $KeepPublicIp) {
    $null = Remove-AzPublicIpAddress -ResourceGroupName $r.ResourceGroupName -Name $r.Name -Force
    Say "  Public IP '$($r.Name)' を削除しました" -Color DarkGray
}
Say '完了。' -Color Green
