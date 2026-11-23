<#
.SYNOPSIS
    スナップショットから、新しい VM を作る（復元）。元の VM には、触らない。

.DESCRIPTION
    Backup-VM.ps1 で取った OS ディスクのスナップショットから、ディスクを作り、新しい VM（ディスクをそのまま使う形）を作る。
    コンピューター名、ローカル ユーザー、設定、ソフトウェアは、ディスクのとおり。
    復元先は、別の RG（無ければ作る）。VNet / サブネットも、復元先に作る（既存があれば使う）。
    既定では、Public IP は付けない（-PublicIp で付ける）。自動シャットダウン（UTC 1500）を設定する。
    VM サイズは、スナップショットのタグから既定値を読む（-VmSize で変更）。

    ※ **復元した VM は、別の VM（新しい ID）。** Entra ID のログインは、Enable-EntraLogin.ps1 を、やり直す
      （システム割り当て ID と、VM 単位のロールは、引き継がれない）。ローカル ユーザーの設定（RDP 拒否など）は、ディスクに残る。
    ※ 元の VM と、同じコンピューター名・SID になる。同じネットワークに、同時に置かない（別の VNet に作る）。
    ※ データ ディスクは、復元しない（OS ディスクのみ）。

.PARAMETER SnapshotName
    OS ディスクのスナップショット名。

.EXAMPLE
    .\Restore-VM.ps1 -SnapshotResourceGroupName YourRG -SnapshotName YourVM1-os-20261123-1200 -TargetResourceGroupName RestoredRG -NewVmName RestoredVM1
#>
[CmdletBinding(SupportsShouldProcess)]
param(
    [string]$SnapshotResourceGroupName = 'hogeRG',
    [Parameter(Mandatory)]
    [string]$SnapshotName,
    [string]$TargetResourceGroupName = 'RestoredRG',
    [string]$NewVmName = 'RestoredVM1',
    [string]$VmSize,
    [string]$Location,
    [string]$VnetName,
    [string]$VnetAddressPrefix = '10.2.0.0/16',
    [string]$SubnetAddressPrefix = '10.2.0.0/24',
    [ValidateSet('StandardSSD_LRS', 'Premium_LRS', 'Standard_LRS')][string]$DiskType = 'StandardSSD_LRS',
    [switch]$PublicIp,
    [string]$AutoShutdownTime = '1500',
    [switch]$NoAutoShutdown,
    [switch]$Force
)
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'SingleVM.Common.ps1')
$null = Assert-AzLogin
Assert-ResourceProviders $RequiredProviders

$snap = Get-AzSnapshot -ResourceGroupName $SnapshotResourceGroupName -SnapshotName $SnapshotName
$t = $snap.Tags
if (-not $t -or -not $t['dx-os-type']) { throw "スナップショット '$SnapshotName' に、Backup-VM.ps1 のタグがありません。" }
if ($t['dx-disk-role'] -ne 'os') { throw "スナップショット '$SnapshotName' は、OS ディスクのものではありません（role=$($t['dx-disk-role'])）。" }
if (-not $VmSize) { $VmSize = $t['dx-vm-size'] }
if (-not $Location) { $Location = $snap.Location }
if (-not $VnetName) { $VnetName = "$NewVmName-vnet" }
$osType = $t['dx-os-type']
$diskName = "${NewVmName}_OsDisk_1"

Say ("復元: スナップショット '{0}'（元 VM: {1}、{2}、{3} GB、取得 {4}）" -f $SnapshotName, $t['dx-source-vm'], $osType, $snap.DiskSizeGB, $t['dx-taken']) -Color Cyan
Say ("  新しい VM: '{0}'（{1}）  RG: '{2}'（{3}）  ディスク: {4}" -f $NewVmName, $VmSize, $TargetResourceGroupName, $Location, $DiskType) -Color Cyan
Say ("  ネットワーク: VNet '{0}'（{1}）/ サブネット {2}  /  Public IP: {3}" -f $VnetName, $VnetAddressPrefix, $SubnetAddressPrefix, $(if ($PublicIp) { 'あり' } else { 'なし' })) -Color DarkGray

# ---- フールプルーフ
if (Get-AzVM -ResourceGroupName $TargetResourceGroupName -Name $NewVmName -ErrorAction SilentlyContinue) { throw "VM '$NewVmName' は、RG '$TargetResourceGroupName' に、すでにあります。" }
if (Get-AzDisk -ResourceGroupName $TargetResourceGroupName -DiskName $diskName -ErrorAction SilentlyContinue) { throw "ディスク '$diskName' は、RG '$TargetResourceGroupName' に、すでにあります。" }
$sku = @(Get-AzComputeResourceSku -Location $Location | Where-Object { $_.ResourceType -eq 'virtualMachines' -and $_.Name -eq $VmSize })
if ($sku.Count -eq 0) { throw "サイズ '$VmSize' は、リージョン '$Location' にありません。" }
$restricted = @($sku[0].Restrictions | ForEach-Object { $_.ReasonCode })
if ($restricted.Count -gt 0) { throw "サイズ '$VmSize' は、このサブスクリプションでは使えません（制限: $($restricted -join ', ')）。" }
$cores = [int](($sku[0].Capabilities | Where-Object Name -eq 'vCPUs').Value)
$usage = Get-AzVMUsage -Location $Location | Where-Object { $_.Name.Value -eq $sku[0].Family } | Select-Object -First 1
$free = if ($usage) { [int]$usage.Limit - [int]$usage.CurrentValue } else { 0 }
if ($free -lt $cores) { throw ("vCPU のクォータが足りません（ファミリ {0}: 空き {1} / 必要 {2}）。" -f $sku[0].Family, $free, $cores) }
Say "  事前チェック OK（サイズ / クォータ空き $free / 必要 $cores）" -Color DarkGray
if ($WhatIfPreference) { Say '（-WhatIf: チェックまで。何も作成していません）' -Color DarkGray; return }
if (-not (Confirm-Action '復元して、新しい VM を作成しますか（課金が発生します）' -Force:$Force)) { Say '中止しました。' -Color Yellow; return }

# ---- 作成
if (-not (Get-AzResourceGroup -Name $TargetResourceGroupName -ErrorAction SilentlyContinue)) {
    Say "  リソースグループ '$TargetResourceGroupName' を作成します ($Location)" -Color Cyan
    $null = New-AzResourceGroup -Name $TargetResourceGroupName -Location $Location
}
$vnet = Get-AzVirtualNetwork -ResourceGroupName $TargetResourceGroupName -Name $VnetName -ErrorAction SilentlyContinue
if (-not $vnet) {
    Say "  VNet '$VnetName' を作成します" -Color Cyan
    $sn = New-AzVirtualNetworkSubnetConfig -Name 'default' -AddressPrefix $SubnetAddressPrefix
    $vnet = New-AzVirtualNetwork -ResourceGroupName $TargetResourceGroupName -Name $VnetName -Location $Location -AddressPrefix $VnetAddressPrefix -Subnet $sn
}
$subnet = $vnet.Subnets[0]

Say "  スナップショットから、ディスク '$diskName' を作成します" -Color Cyan
$dcfg = New-AzDiskConfig -Location $Location -CreateOption Copy -SourceResourceId $snap.Id -SkuName $DiskType -OsType $osType
if ($t['dx-hyperv-gen']) { $dcfg.HyperVGeneration = $t['dx-hyperv-gen'] }
$disk = New-AzDisk -ResourceGroupName $TargetResourceGroupName -DiskName $diskName -Disk $dcfg

Say '  NIC を作成します' -Color Cyan
$ipId = $null
if ($PublicIp) {
    $pip = New-AzPublicIpAddress -ResourceGroupName $TargetResourceGroupName -Name "$NewVmName-pip" -Location $Location -Sku Standard -AllocationMethod Static
    $ipId = $pip.Id
}
$nicParams = @{ ResourceGroupName = $TargetResourceGroupName; Name = "$NewVmName-nic"; Location = $Location; SubnetId = $subnet.Id }
if ($ipId) { $nicParams.PublicIpAddressId = $ipId }
$nic = New-AzNetworkInterface @nicParams

Say "  VM '$NewVmName' を作成します（数分かかります）" -Color Cyan
$cfg = New-AzVMConfig -VMName $NewVmName -VMSize $VmSize
$cfg = Add-AzVMNetworkInterface -VM $cfg -Id $nic.Id
if ($osType -eq 'Windows') { $cfg = Set-AzVMOSDisk -VM $cfg -ManagedDiskId $disk.Id -CreateOption Attach -Windows }
else { $cfg = Set-AzVMOSDisk -VM $cfg -ManagedDiskId $disk.Id -CreateOption Attach -Linux }
$cfg = Set-AzVMBootDiagnostic -VM $cfg -Disable
$null = New-AzVM -ResourceGroupName $TargetResourceGroupName -Location $Location -VM $cfg
if (-not $NoAutoShutdown) { Set-VmAutoShutdown $TargetResourceGroupName $NewVmName $Location $AutoShutdownTime }

Say ''
Say "完了: VM '$NewVmName' を、スナップショット '$SnapshotName' から作成しました。" -Color Green
Say '  Entra ID のログインは、Enable-EntraLogin.ps1 を、やり直してください（ID とロールは、引き継がれません）。' -Color Yellow
if ($PublicIp) { Say ("  Public IP: {0}（RDP を開けるには Open-VMPort.ps1 -MyIp）" -f (Get-AzPublicIpAddress -ResourceGroupName $TargetResourceGroupName -Name "$NewVmName-pip").IpAddress) -Color DarkGray }
