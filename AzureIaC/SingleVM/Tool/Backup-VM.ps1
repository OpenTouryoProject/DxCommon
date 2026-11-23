<#
.SYNOPSIS
    VM の OS ディスク（とデータ ディスク）の、スナップショットを取る（バックアップ）。

.DESCRIPTION
    増分スナップショット（既定。Standard_LRS）を作る。スナップショットは、VM やディスクを削除しても残る。
    ディスクの内容（OS、ソフトウェア、設定、WSL のディストリビューション、ユーザー プロファイル）が、そのまま残る。
    VM が起動中だと、ディスクの内容が、書き込みの途中になることがある（クラッシュ整合）。
    **確実に取るには、VM を停止（割り当て解除）してから**取る。-StopVm で、取る前に停止し、取った後は、停止したままにする
    （-StartAfter で、取った後に、起動し直す）。
    スナップショットには、復元に使う情報（VM 名、サイズ、OS、Hyper-V 世代など）を、タグとして記録する。
    復元は Restore-VM.ps1。このスクリプトは、何も削除しない。
    ※ 課金: スナップショットは、使っているサイズに応じた、ストレージの料金がかかる（金額は、請求で確認する）。

.PARAMETER SnapshotNamePrefix
    スナップショット名の先頭。省略すると VM 名。名前は <先頭>-os-<日時>（データ ディスクは -data<LUN>-<日時>）。

.PARAMETER SnapshotResourceGroupName
    スナップショットを置く RG。省略すると、VM と同じ RG。

.EXAMPLE
    .\Backup-VM.ps1 -ResourceGroupName YourRG -VmName YourVM1 -StopVm
#>
[CmdletBinding(SupportsShouldProcess)]
param(
    [string]$ResourceGroupName = 'hogeRG',
    [string]$VmName = 'hogeVM',
    [string]$SnapshotResourceGroupName,
    [string]$SnapshotNamePrefix,
    [ValidateSet('Standard_LRS', 'Standard_ZRS', 'Premium_LRS')][string]$SkuName = 'Standard_LRS',
    [switch]$StopVm,
    [switch]$StartAfter,
    [switch]$Force
)
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'SingleVM.Common.ps1')
$null = Assert-AzLogin
Assert-ResourceProviders $RequiredProviders

$vm = Get-AzVM -ResourceGroupName $ResourceGroupName -Name $VmName
if (-not $SnapshotResourceGroupName) { $SnapshotResourceGroupName = $ResourceGroupName }
if (-not $SnapshotNamePrefix) { $SnapshotNamePrefix = $VmName }
$power = ((Get-AzVM -ResourceGroupName $ResourceGroupName -Name $VmName -Status).Statuses | Where-Object { $_.Code -like 'PowerState/*' }).Code
$stamp = Get-Date -Format 'yyyyMMdd-HHmm'

# 対象のディスク
$disks = @()
$osd = Get-AzDisk -ResourceGroupName (Split-ResourceId $vm.StorageProfile.OsDisk.ManagedDisk.Id).ResourceGroupName -DiskName $vm.StorageProfile.OsDisk.Name
$disks += [pscustomobject]@{ Disk = $osd; Role = 'os'; Lun = -1 }
foreach ($dd in $vm.StorageProfile.DataDisks) {
    $d = Get-AzDisk -ResourceGroupName (Split-ResourceId $dd.ManagedDisk.Id).ResourceGroupName -DiskName $dd.Name
    $disks += [pscustomobject]@{ Disk = $d; Role = 'data'; Lun = $dd.Lun }
}
Say ("対象: VM '{0}'（{1} / {2}）  /  状態: {3}" -f $VmName, $vm.HardwareProfile.VmSize, $(if (Test-VmIsLinux $vm) { 'Linux' } else { 'Windows' }), $power) -Color Cyan
foreach ($x in $disks) { Say ("  ディスク: {0}（{1}、{2} GB、{3}）" -f $x.Disk.Name, $x.Role, $x.Disk.DiskSizeGB, $x.Disk.Sku.Name) -Color DarkGray }
Say ("  スナップショットの置き場所: RG '{0}'  /  {1}" -f $SnapshotResourceGroupName, $SkuName) -Color DarkGray
if ($power -eq 'PowerState/running' -and -not $StopVm) {
    Say '  ※ VM が起動中です。ディスクの内容は、書き込みの途中かもしれません（クラッシュ整合）。確実に取るなら -StopVm。' -Color Yellow
}
if ($StopVm -and $power -eq 'PowerState/running') { Say '  ※ 取る前に、VM を停止（割り当て解除）します。接続は切れます。' -Color Yellow }
if ($WhatIfPreference) { Say '（-WhatIf: 何も変更していません）' -Color DarkGray; return }
if (-not (Confirm-Action 'スナップショットを取りますか' -Force:$Force)) { Say '中止しました。' -Color Yellow; return }

if ($StopVm -and $power -ne 'PowerState/deallocated') {
    Say '  VM を停止（割り当て解除）します' -Color Cyan
    $null = Stop-AzVM -ResourceGroupName $ResourceGroupName -Name $VmName -Force
}
$null = Get-AzResourceGroup -Name $SnapshotResourceGroupName -ErrorAction Stop

$tags = @{}   # 値は、すべて純粋な文字列にする（PSObject のままだと、Tag の変換で失敗する）
$tags['dx-source-vm']  = [string]$VmName
$tags['dx-source-rg']  = [string]$ResourceGroupName
$tags['dx-vm-size']    = "$($vm.HardwareProfile.VmSize)"
$tags['dx-os-type']    = "$($vm.StorageProfile.OsDisk.OsType)"
$tags['dx-hyperv-gen'] = "$($osd.HyperVGeneration)"
$tags['dx-location']   = "$($vm.Location)"
$tags['dx-taken']      = "$stamp"
$made = @()
foreach ($x in $disks) {
    $name = if ($x.Role -eq 'os') { "$SnapshotNamePrefix-os-$stamp" } else { "$SnapshotNamePrefix-data$($x.Lun)-$stamp" }
    $t = @{}; foreach ($k in $tags.Keys) { $t[$k] = $tags[$k] }
    $t['dx-disk-role'] = [string]$x.Role; $t['dx-disk-lun'] = "$($x.Lun)"
    Say "  スナップショット '$name' を作成します" -Color Cyan
    $cfg = New-AzSnapshotConfig -SourceUri $x.Disk.Id -Location $vm.Location -CreateOption Copy -Incremental -SkuName $SkuName -Tag $t
    $null = New-AzSnapshot -ResourceGroupName $SnapshotResourceGroupName -SnapshotName $name -Snapshot $cfg
    $made += $name
}
if ($StartAfter -and $StopVm) {
    Say '  VM を起動し直します' -Color Cyan
    $null = Start-AzVM -ResourceGroupName $ResourceGroupName -Name $VmName
}
Say ''
Say 'できたスナップショット:' -Color Cyan
Get-AzSnapshot -ResourceGroupName $SnapshotResourceGroupName | Where-Object { $_.Name -in $made } |
    Select-Object Name, @{n = 'GB'; e = { $_.DiskSizeGB } }, @{n = 'Sku'; e = { $_.Sku.Name } }, ProvisioningState | Format-Table -AutoSize | Out-String | Write-Host
Say "完了: スナップショットを取りました。復元: Restore-VM.ps1 -SnapshotResourceGroupName $SnapshotResourceGroupName -SnapshotName $($made[0]) -TargetResourceGroupName <新しい RG> -NewVmName <VM 名>" -Color Green
