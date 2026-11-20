<#
.SYNOPSIS
    VM を起動・停止（割り当て解除）・再起動する。

.DESCRIPTION
    Stop は「割り当て解除」（deallocate）で止める。OS を止めるだけの停止（stopped）では
    コンピューティング料金が止まらないため、課金を止めたいときは Stop を使う。
    Stop / Restart は確認を求める。-Force で確認を省略する。

.PARAMETER Action
    Start / Stop / Restart

.EXAMPLE
    .\Set-VMPower.ps1 -ResourceGroupName hogeRG -VmName hogeVM -Action Stop
#>
[CmdletBinding()]
param(
    [string]$ResourceGroupName = 'hogeRG',
    [string]$VmName = 'hogeVM',
    [ValidateSet('Start', 'Stop', 'Restart')]
    [string]$Action = 'Stop',
    [switch]$Force
)
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'SingleVM.Common.ps1')
$null = Assert-AzLogin

$vm = Get-AzVM -ResourceGroupName $ResourceGroupName -Name $VmName -Status -ErrorAction SilentlyContinue
if (-not $vm) { throw "VM '$VmName'（RG: $ResourceGroupName）が見つかりません。" }
Say ("  現在の状態: {0}" -f $vm.PowerState) -Color DarkGray

switch ($Action) {
    'Start' {
        Say "  VM '$VmName' を起動します" -Color Cyan
        $null = Start-AzVM -ResourceGroupName $ResourceGroupName -Name $VmName
    }
    'Stop' {
        if (-not (Confirm-Action "VM '$VmName' を停止（割り当て解除）しますか" -Force:$Force)) { Say 'キャンセルしました。' -Color Yellow; return }
        Say "  VM '$VmName' を停止します（割り当て解除）" -Color Cyan
        $null = Stop-AzVM -ResourceGroupName $ResourceGroupName -Name $VmName -Force
    }
    'Restart' {
        if (-not (Confirm-Action "VM '$VmName' を再起動しますか" -Force:$Force)) { Say 'キャンセルしました。' -Color Yellow; return }
        Say "  VM '$VmName' を再起動します" -Color Cyan
        $null = Restart-AzVM -ResourceGroupName $ResourceGroupName -Name $VmName
    }
}

$after = Get-AzVM -ResourceGroupName $ResourceGroupName -Name $VmName -Status
Say ("完了: 現在の状態は {0} です。" -f $after.PowerState) -Color Green
