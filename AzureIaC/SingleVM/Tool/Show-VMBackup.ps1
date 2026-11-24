<#
.SYNOPSIS
    Backup-VM.ps1 で取ったスナップショット（バックアップ）を一覧表示する（読み取り専用）。

.DESCRIPTION
    スナップショットのタグ（dx-source-vm など）を読み、元の VM、役割（OS / データ）、取得日時、サイズを表示する。
    RG を省略すると、サブスクリプション全体から探す。-VmName で、元の VM を絞る。
    既定では、Backup-VM.ps1 のタグが付いたものだけを表示する（-All で、付いていないものも表示する）。
    何も変更しない。復元は Restore-VM.ps1、削除は、RG ごと（またはポータル）。
    ※ DiskSizeGB は、ディスクの容量（プロビジョニング）。増分スナップショットの課金は、実際に使っている分だけ。

.PARAMETER ResourceGroupName
    スナップショットのある RG。空にすると、サブスクリプション全体。

.PARAMETER VmName
    元の VM 名で絞る（タグ dx-source-vm）。

.EXAMPLE
    .\Show-VMBackup.ps1 -ResourceGroupName YourRG -VmName YourVM1
#>
[CmdletBinding()]
param(
    [string]$ResourceGroupName = 'hogeRG',
    [string]$VmName,
    [switch]$All
)
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'SingleVM.Common.ps1')
$null = Assert-AzLogin

if ($ResourceGroupName) {
    $null = Get-AzResourceGroup -Name $ResourceGroupName -ErrorAction Stop   # 無ければ、ここで止まる
    $snaps = @(Get-AzSnapshot -ResourceGroupName $ResourceGroupName)
}
else { $snaps = @(Get-AzSnapshot) }

function Get-SnapTag($s, [string]$Key) { if ($s.Tags -and $s.Tags.ContainsKey($Key)) { return [string]$s.Tags[$Key] } else { return '' } }

$tagged = @($snaps | Where-Object { Get-SnapTag $_ 'dx-os-type' })
$target = if ($All) { $snaps } else { $tagged }
if ($VmName) { $target = @($target | Where-Object { (Get-SnapTag $_ 'dx-source-vm') -eq $VmName }) }
$scope = if ($ResourceGroupName) { "RG '$ResourceGroupName'" } else { 'サブスクリプション全体' }
Say ("バックアップ（スナップショット）: {0}" -f $scope) -Color Cyan
if ($VmName) { Say "  元の VM: $VmName" -Color DarkGray }

if (@($target).Count -eq 0) {
    Say '  該当するスナップショットは、ありません。' -Color Yellow
    $skipped = $snaps.Count - $tagged.Count
    if (-not $All -and $skipped -gt 0) { Say "  （Backup-VM.ps1 のタグが無いスナップショットが $skipped 件あります。-All で表示）" -Color DarkGray }
    return
}

$rows = $target | Sort-Object @{ e = { Get-SnapTag $_ 'dx-source-vm' } }, @{ e = { $_.TimeCreated }; Descending = $true } | ForEach-Object {
    $role = Get-SnapTag $_ 'dx-disk-role'
    if ($role -eq 'data') { $role = 'data' + (Get-SnapTag $_ 'dx-disk-lun') }
    [pscustomobject]@{
        Name        = $_.Name
        RG          = $_.ResourceGroupName
        SourceVm    = Get-SnapTag $_ 'dx-source-vm'
        Role        = $role
        VmSize      = Get-SnapTag $_ 'dx-vm-size'
        GB          = $_.DiskSizeGB
        Sku         = $_.Sku.Name
        Created     = $_.TimeCreated.ToLocalTime().ToString('yyyy-MM-dd HH:mm')
        State       = $_.ProvisioningState
    }
}
$rows | Format-Table -AutoSize | Out-String -Width 250 | Write-Host

$gb = ($target | Measure-Object DiskSizeGB -Sum).Sum
Say ("  {0} 件（ディスク容量の合計 {1} GB。増分は、使っている分だけが課金）" -f @($target).Count, $gb) -Color DarkGray
if (-not $All) {
    $skipped = $snaps.Count - $tagged.Count
    if ($skipped -gt 0) { Say "  （Backup-VM.ps1 のタグが無いスナップショット $skipped 件は、表示していません。-All で表示）" -Color DarkGray }
}
$latest = $target | Where-Object { (Get-SnapTag $_ 'dx-disk-role') -eq 'os' } | Sort-Object TimeCreated -Descending | Select-Object -First 1
if ($latest) {
    Say ("  復元: Restore-VM.ps1 -SnapshotResourceGroupName {0} -SnapshotName {1} -TargetResourceGroupName <新しい RG> -NewVmName <VM 名>" -f $latest.ResourceGroupName, $latest.Name) -Color DarkGray
}
