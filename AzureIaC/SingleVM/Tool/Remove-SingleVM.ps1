<#
.SYNOPSIS
    New-SingleVM.ps1 で作った VM を、付随するリソースごと削除する。

.DESCRIPTION
    削除前に、対象を一覧表示して確認する（-Force で確認を省略）。
    対象: 自動シャットダウン設定 / VM / NIC / Public IP / NSG / VNet / ディスク / SSH キー。
    NIC・Public IP・NSG・VNet は、名前が VmName で始まるものだけを削除する（他と共有している可能性があるため）。
    -RemoveResourceGroup を付けると、VM 単位ではなくリソースグループごと削除する。元に戻せない。

.EXAMPLE
    .\Remove-SingleVM.ps1 -ResourceGroupName hogeRG -VmName hogeVM
    .\Remove-SingleVM.ps1 -ResourceGroupName hogeRG -RemoveResourceGroup
#>
[CmdletBinding()]
param(
    [string]$ResourceGroupName = 'hogeRG',
    [string]$VmName = 'hogeVM',
    [switch]$RemoveResourceGroup,
    [switch]$Force
)
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'SingleVM.Common.ps1')
$null = Assert-AzLogin

if (-not (Get-AzResourceGroup -Name $ResourceGroupName -ErrorAction SilentlyContinue)) {
    Say "リソースグループ '$ResourceGroupName' は存在しません。" -Color Yellow
    return
}

# --- リソースグループごと削除 ---
if ($RemoveResourceGroup) {
    Say "削除対象: リソースグループ '$ResourceGroupName'" -Color Cyan
    $resources = @(Get-AzResource -ResourceGroupName $ResourceGroupName)
    if ($resources.Count -eq 0) { Say '  （中身は空です）' -Color DarkGray }
    else { $resources | Format-Table Name, ResourceType -AutoSize | Out-Host }
    if (-not (Confirm-Action "リソースグループ '$ResourceGroupName' を、中身ごと削除しますか（元に戻せません）" -Force:$Force)) {
        Say 'キャンセルしました。' -Color Yellow; return
    }
    $null = Remove-AzResourceGroup -Name $ResourceGroupName -Force
    Say "完了: '$ResourceGroupName' を削除しました。" -Color Green
    return
}

# --- VM 単位で削除 ---
$vm = Get-AzVM -ResourceGroupName $ResourceGroupName -Name $VmName -ErrorAction SilentlyContinue
if (-not $vm) { throw "VM '$VmName'（RG: $ResourceGroupName）が見つかりません。" }

$targets = New-Object System.Collections.Generic.List[hashtable]
function Add-Target([string]$Type, [string]$Rg, [string]$Name, [bool]$Shared = $false) {
    $targets.Add(@{ Type = $Type; ResourceGroupName = $Rg; Name = $Name; Skip = $Shared })
}

$sched = Get-AzResource -ResourceGroupName $ResourceGroupName -ResourceType 'Microsoft.DevTestLab/schedules' -Name "shutdown-computevm-$VmName" -ErrorAction SilentlyContinue
if ($sched) { Add-Target 'Schedule' $ResourceGroupName $sched.Name }
Add-Target 'VM' $ResourceGroupName $VmName

$nic = Get-VmNic $vm
$own = { param($n) $n.StartsWith($VmName) }
Add-Target 'NIC' $nic.ResourceGroupName $nic.Name (-not (& $own $nic.Name))
$pipId = $nic.IpConfigurations[0].PublicIpAddress.Id
if ($pipId) { $r = Split-ResourceId $pipId; Add-Target 'PublicIP' $r.ResourceGroupName $r.Name (-not (& $own $r.Name)) }
if ($nic.NetworkSecurityGroup) { $r = Split-ResourceId $nic.NetworkSecurityGroup.Id; Add-Target 'NSG' $r.ResourceGroupName $r.Name (-not (& $own $r.Name)) }
$subnetParts = $nic.IpConfigurations[0].Subnet.Id -split '/'
Add-Target 'VNet' $subnetParts[4] $subnetParts[8] (-not (& $own $subnetParts[8]))
Add-Target 'Disk' $ResourceGroupName $vm.StorageProfile.OsDisk.Name
foreach ($d in $vm.StorageProfile.DataDisks) { Add-Target 'Disk' $ResourceGroupName $d.Name }
if (Get-AzSshKey -ResourceGroupName $ResourceGroupName -Name "$VmName-sshkey" -ErrorAction SilentlyContinue) {
    Add-Target 'SshKey' $ResourceGroupName "$VmName-sshkey"
}

Say "削除対象: VM '$VmName'（RG: $ResourceGroupName）と、付随するリソース" -Color Cyan
foreach ($t in $targets) {
    if ($t.Skip) { Say ("  - {0,-9} {1}/{2}  （名前が '{3}' で始まらないためスキップ）" -f $t.Type, $t.ResourceGroupName, $t.Name, $VmName) -Color DarkGray }
    else { Say ("  - {0,-9} {1}/{2}" -f $t.Type, $t.ResourceGroupName, $t.Name) }
}

if (-not (Confirm-Action "上記を削除しますか（元に戻せません）" -Force:$Force)) {
    Say 'キャンセルしました。' -Color Yellow
    return
}

foreach ($t in ($targets | Where-Object { -not $_.Skip })) {
    Say ("  {0} '{1}' を削除します" -f $t.Type, $t.Name) -Color Cyan
    try {
        switch ($t.Type) {
            'Schedule' { $null = Remove-AzResource -ResourceGroupName $t.ResourceGroupName -ResourceType 'Microsoft.DevTestLab/schedules' -Name $t.Name -Force }
            'VM'       { $null = Remove-AzVM -ResourceGroupName $t.ResourceGroupName -Name $t.Name -Force }
            'NIC'      { $null = Remove-AzNetworkInterface -ResourceGroupName $t.ResourceGroupName -Name $t.Name -Force }
            'PublicIP' { $null = Remove-AzPublicIpAddress -ResourceGroupName $t.ResourceGroupName -Name $t.Name -Force }
            'NSG'      { $null = Remove-AzNetworkSecurityGroup -ResourceGroupName $t.ResourceGroupName -Name $t.Name -Force }
            'VNet'     { $null = Remove-AzVirtualNetwork -ResourceGroupName $t.ResourceGroupName -Name $t.Name -Force }
            'Disk'     { $null = Remove-AzDisk -ResourceGroupName $t.ResourceGroupName -DiskName $t.Name -Force }
            'SshKey'   { $null = Remove-AzSshKey -ResourceGroupName $t.ResourceGroupName -Name $t.Name }
        }
    }
    catch { Say ("    失敗（続行します）: {0}" -f $_.Exception.Message) -Color Yellow }
}
Say "完了: VM '$VmName' と付随するリソースを削除しました。" -Color Green
