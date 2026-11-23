<#
.SYNOPSIS
    Windows VM の ユーザー アカウント制御（UAC）を、無効にする / 元に戻す。

.DESCRIPTION
    Run Command（Azure の VM エージェント経由）で、レジストリ
    HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System を変更する。RDP は要らない。
      Full    : EnableLUA = 0 。UAC を完全に無効にする。**再起動が必要**（既定で再起動する）。
                管理者は、昇格の確認なしで、常にフル権限で動く。Microsoft Store アプリなど、UAC を前提にした機能は動かなくなる。
      NoPrompt: ConsentPromptBehaviorAdmin = 0 。UAC は有効のまま、管理者への昇格の確認だけを出さない。再起動は不要。
    -Enable で、既定（EnableLUA = 1、ConsentPromptBehaviorAdmin = 5）に戻す（Full の場合は再起動が必要）。
    セキュリティの低下になるため、確認を求める。WhatIf で、現在の値の確認だけを行える。
    ※ 既にログインしているセッションは、再起動（または再ログイン）まで、変わらない。

.PARAMETER Mode
    Full（既定）/ NoPrompt。

.PARAMETER Enable
    無効にせず、既定に戻す。

.PARAMETER NoRestart
    Full のとき、再起動しない（設定は、再起動後に有効になる）。

.EXAMPLE
    .\Set-VMUac.ps1 -ResourceGroupName YourRG -VmName YourVM1
    .\Set-VMUac.ps1 -ResourceGroupName YourRG -VmName YourVM1 -Enable
#>
[CmdletBinding(SupportsShouldProcess)]
param(
    [string]$ResourceGroupName = 'hogeRG',
    [string]$VmName = 'hogeVM',
    [ValidateSet('Full', 'NoPrompt')][string]$Mode = 'Full',
    [switch]$Enable,
    [switch]$NoRestart,
    [switch]$Force
)
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'SingleVM.Common.ps1')
$null = Assert-AzLogin
Assert-ResourceProviders $RequiredProviders

function Invoke-VmScript([string]$Script) {
    $r = Invoke-AzVMRunCommand -ResourceGroupName $ResourceGroupName -VMName $VmName `
        -CommandId 'RunPowerShellScript' -ScriptString $Script -WhatIf:$false   # -WhatIf でも、読み取りは実行する
    return (($r.Value | ForEach-Object { $_.Message }) -join "`n")
}
$readScript = @'
$k = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System'
$p = Get-ItemProperty $k
Write-Output ("EnableLUA=" + $p.EnableLUA + " ConsentPromptBehaviorAdmin=" + $p.ConsentPromptBehaviorAdmin)
'@

$vm = Get-AzVM -ResourceGroupName $ResourceGroupName -Name $VmName
if (Test-VmIsLinux $vm) { throw "VM '$VmName' は Linux です。この Tool は Windows VM 専用です。" }
$power = ((Get-AzVM -ResourceGroupName $ResourceGroupName -Name $VmName -Status).Statuses | Where-Object { $_.Code -like 'PowerState/*' }).Code
if ($power -ne 'PowerState/running') { throw "VM '$VmName' が起動していません（$power）。起動してから実行してください。" }

$before = (Invoke-VmScript $readScript).Trim()
$what = if ($Enable) { '既定に戻す（UAC 有効）' } elseif ($Mode -eq 'Full') { 'UAC を完全に無効にする（EnableLUA=0、再起動が必要）' } else { '昇格の確認を出さない（ConsentPromptBehaviorAdmin=0）' }
Say ("対象: VM '{0}'  /  内容: {1}" -f $VmName, $what) -Color Cyan
Say ("  現在の値: {0}" -f $before) -Color DarkGray
if (-not $Enable) { Say '  ※ セキュリティの低下です。マルウェアなどが、管理者権限を確認なしで得られます。開発・検証用の VM に限ってください。' -Color Yellow }
if ($WhatIfPreference) { Say '（-WhatIf: 何も変更していません）' -Color DarkGray; return }
if (-not (Confirm-Action 'よろしいですか' -Force:$Force)) { Say '中止しました。' -Color Yellow; return }

if ($Enable) { $lua = 1; $consent = 5 }
elseif ($Mode -eq 'Full') { $lua = 0; $consent = $null }
else { $lua = $null; $consent = 0 }
$script = @'
$k = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System'
if ('__LUA__' -ne '') { Set-ItemProperty -Path $k -Name EnableLUA -Type DWord -Value __LUA__ }
if ('__CONSENT__' -ne '') { Set-ItemProperty -Path $k -Name ConsentPromptBehaviorAdmin -Type DWord -Value __CONSENT__ }
$p = Get-ItemProperty $k
Write-Output ("EnableLUA=" + $p.EnableLUA + " ConsentPromptBehaviorAdmin=" + $p.ConsentPromptBehaviorAdmin)
'@.Replace('__LUA__', "$lua").Replace('__CONSENT__', "$consent")
$after = (Invoke-VmScript $script).Trim()
Say ("  設定後の値: {0}" -f $after) -Color DarkGray
if (($null -ne $lua -and $after -notmatch "EnableLUA=$lua") -or ($null -ne $consent -and $after -notmatch "ConsentPromptBehaviorAdmin=$consent")) {
    throw "設定が反映されませんでした:`n$after"
}

if ($null -ne $lua) {
    if ($NoRestart) { Say '  再起動していません。設定は、再起動後に有効になります。' -Color Yellow }
    else {
        Say '  VM を再起動します（RDP / Bastion の接続は切れます）' -Color Cyan
        $null = Restart-AzVM -ResourceGroupName $ResourceGroupName -Name $VmName
    }
}
Say ''
Say "完了: VM '$VmName' の UAC: $what" -Color Green
