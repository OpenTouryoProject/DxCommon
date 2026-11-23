<#
.SYNOPSIS
    VM のサイズ（SKU）を変更する。

.DESCRIPTION
    実行前に、次を確認する（満たさなければ中止）。
      1. 変更後のサイズが、このリージョンで提供されていて、制限（Restrictions）が無い。
      2. サイズのファミリの vCPU クォータに、空きがある（変更後の vCPU 数 > 空きなら、クォータ不足として中止）。
    サイズの変更は、VM の停止（割り当て解除）が要る。起動中の VM は、停止 → サイズ変更 → 起動 の順に行う
    （-NoStart で、起動しない）。停止している間、RDP / Bastion / SSH の接続は切れる。
    Public IP が動的だと、再起動で変わる（このリポジトリの Tool は Standard / 静的）。
    クォータが足りないときは、Azure Portal の「クォータ」から引き上げを申請するか、別のサイズ / リージョンを選ぶ。

.PARAMETER VmSize
    変更後のサイズ（例: Standard_D2s_v5）。

.PARAMETER NoStart
    変更後に起動しない。

.EXAMPLE
    .\Set-VMSize.ps1 -ResourceGroupName AzureBastionRG -VmName JumpboxVM1 -VmSize Standard_D2s_v4
#>
[CmdletBinding(SupportsShouldProcess)]
param(
    [string]$ResourceGroupName = 'hogeRG',
    [string]$VmName = 'hogeVM',
    [Parameter(Mandatory)]
    [string]$VmSize,
    [switch]$NoStart,
    [switch]$Force
)
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'SingleVM.Common.ps1')
$null = Assert-AzLogin
Assert-ResourceProviders $RequiredProviders

$vm = Get-AzVM -ResourceGroupName $ResourceGroupName -Name $VmName
$current = $vm.HardwareProfile.VmSize
$power = ((Get-AzVM -ResourceGroupName $ResourceGroupName -Name $VmName -Status).Statuses | Where-Object { $_.Code -like 'PowerState/*' }).Code
Say ("対象: VM '{0}'  /  {1} → {2}  /  状態: {3}" -f $VmName, $current, $VmSize, $power) -Color Cyan
if ($current -eq $VmSize) { Say '  既に、そのサイズです（スキップ）' -Color DarkGray; return }

# ---- 1. サイズの提供状況と制限
$skus = @(Get-AzComputeResourceSku -Location $vm.Location | Where-Object { $_.ResourceType -eq 'virtualMachines' -and $_.Name -in @($VmSize, $current) })
$target = $skus | Where-Object Name -eq $VmSize | Select-Object -First 1
if (-not $target) { throw "サイズ '$VmSize' は、リージョン '$($vm.Location)' にありません。" }
$restricted = @($target.Restrictions | ForEach-Object { $_.ReasonCode })
if ($restricted.Count -gt 0) { throw "サイズ '$VmSize' は、このサブスクリプションでは使えません（制限: $($restricted -join ', ')）。" }

# ---- 2. クォータ（ファミリの vCPU）
$cores = [int](($target.Capabilities | Where-Object Name -eq 'vCPUs').Value)
$usage = Get-AzVMUsage -Location $vm.Location | Where-Object { $_.Name.Value -eq $target.Family } | Select-Object -First 1
$free = if ($usage) { [int]$usage.Limit - [int]$usage.CurrentValue } else { 0 }
$cur = $skus | Where-Object Name -eq $current | Select-Object -First 1
if ($cur -and $cur.Family -eq $target.Family) { $free += [int](($cur.Capabilities | Where-Object Name -eq 'vCPUs').Value) }   # 同じファミリなら、今の分は空く
Say ("  ファミリ {0}: vCPU 上限 {1} / 使用 {2} / 必要 {3}" -f $target.Family, $usage.Limit, $usage.CurrentValue, $cores) -Color DarkGray
if ($free -lt $cores) {
    throw ("vCPU のクォータが足りません（ファミリ {0}: 空き {1} / 必要 {2}）。Azure Portal の「クォータ」で引き上げを申請するか、別のサイズ / リージョンを選んでください。" -f $target.Family, $free, $cores)
}

# ---- 3. 一時ディスク（リソース ディスク）の有無（あり ⇔ なし は、変更できない）
if ($cur) {
    $curTemp = [int](($cur.Capabilities | Where-Object Name -eq 'MaxResourceVolumeMB').Value)
    $newTemp = [int](($target.Capabilities | Where-Object Name -eq 'MaxResourceVolumeMB').Value)
    if (($curTemp -gt 0) -ne ($newTemp -gt 0)) {
        throw ("{0}（一時ディスク {1} MB）から {2}（一時ディスク {3} MB）へは、変更できません（一時ディスクの あり ⇔ なし は不可）。同じ種類のサイズ（例: v3 同士）を選ぶか、新しい VM を作り直してください。" -f $current, $curTemp, $VmSize, $newTemp)
    }
}

if ($power -eq 'PowerState/running') { Say '  ※ 停止してから変更します。RDP / Bastion / SSH の接続は、一時的に切れます。' -Color Yellow }
if ($WhatIfPreference) { Say '（-WhatIf: チェックまで。何も変更していません）' -Color DarkGray; return }
if (-not (Confirm-Action 'サイズを変更しますか' -Force:$Force)) { Say '中止しました。' -Color Yellow; return }

$wasRunning = $power -eq 'PowerState/running'
if ($wasRunning) {
    Say '  VM を停止（割り当て解除）します' -Color Cyan
    $null = Stop-AzVM -ResourceGroupName $ResourceGroupName -Name $VmName -Force
}
try {
    $vm = Get-AzVM -ResourceGroupName $ResourceGroupName -Name $VmName
    $vm.HardwareProfile.VmSize = $VmSize
    Say "  サイズを $VmSize に変更します" -Color Cyan
    $null = Update-AzVM -ResourceGroupName $ResourceGroupName -VM $vm
}
catch {
    # 失敗しても、停止したままにしない（元の状態に戻す）
    if ($wasRunning -and -not $NoStart) {
        Say '  変更に失敗しました。VM を、元のサイズで起動し直します' -Color Yellow
        $null = Start-AzVM -ResourceGroupName $ResourceGroupName -Name $VmName
    }
    throw
}
if ($wasRunning -and -not $NoStart) {
    Say '  VM を起動します' -Color Cyan
    $null = Start-AzVM -ResourceGroupName $ResourceGroupName -Name $VmName
}

$after = (Get-AzVM -ResourceGroupName $ResourceGroupName -Name $VmName).HardwareProfile.VmSize
Say "完了: VM '$VmName' のサイズ: $after" -Color Green
