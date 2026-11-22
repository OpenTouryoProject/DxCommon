<#
.SYNOPSIS
    Windows VM のローカル管理者アカウントでのログインを止める（Entra ID のログインだけにする）。-Enable で戻す。

.DESCRIPTION
    ローカル管理者（既定は、VM 作成時の管理者ユーザー）を、次のどちらかの方法で止める。
      DenyRdp        : 「リモート デスクトップ サービスを使ったログオンを拒否する」にローカル ユーザーを入れる（既定）。
                       アカウントは有効なまま。RDP（Bastion のパスワード接続を含む）でだけ入れなくなる。
      DisableAccount : ローカル ユーザーを無効にする（Disable-LocalUser）。あらゆるログインが無効になる。
    変更は、Run Command（Azure の VM エージェント経由）で行う。RDP とは無関係に動くので、締め出されたときの復旧にも使える
    （-Enable で戻す）。

    【締め出し防止のチェック】止める前に、次のすべてを確認し、満たさなければ中止する（-Enable のときは確認しない）。
      1. VM が Windows で、起動している。
      2. 拡張機能 AADLoginForWindows が Succeeded。
      3. 'Virtual Machine Administrator Login' が、この VM（または親のスコープ）に 1 件以上割り当てられている。
      4. VM のローカルの Administrators グループに、Entra ID のユーザー（AzureAD\...）が入っている
         （＝Entra ID の管理者が、一度ログインできている）。
    -WhatIf を付けると、チェックと、実行内容の表示だけを行う。

.PARAMETER LocalUserName
    止めるローカル ユーザー。既定は、VM の管理者ユーザー。

.PARAMETER Mode
    DenyRdp（既定）/ DisableAccount。

.PARAMETER Enable
    止めたものを戻す（拒否の解除 / アカウントの有効化）。

.EXAMPLE
    .\Disable-LocalLogin.ps1 -ResourceGroupName AzureBastionRG -VmName WorkVM2 -WhatIf
    .\Disable-LocalLogin.ps1 -ResourceGroupName AzureBastionRG -VmName WorkVM2
    .\Disable-LocalLogin.ps1 -ResourceGroupName AzureBastionRG -VmName WorkVM2 -Enable
#>
[CmdletBinding(SupportsShouldProcess)]
param(
    [string]$ResourceGroupName = 'hogeRG',
    [string]$VmName = 'hogeVM',
    [string]$LocalUserName,
    [ValidateSet('DenyRdp', 'DisableAccount')][string]$Mode = 'DenyRdp',
    [switch]$Enable,
    [switch]$Force
)
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'SingleVM.Common.ps1')
$null = Assert-AzLogin

function Invoke-VmScript([string]$Script) {
    $r = Invoke-AzVMRunCommand -ResourceGroupName $ResourceGroupName -VMName $VmName `
        -CommandId 'RunPowerShellScript' -ScriptString $Script -WhatIf:$false   # -WhatIf でも、確認用の読み取りは実行する（変更は、下の手前で止める）
    return (($r.Value | ForEach-Object { $_.Message }) -join "`n")
}

$vm = Get-AzVM -ResourceGroupName $ResourceGroupName -Name $VmName
if (Test-VmIsLinux $vm) { throw "VM '$VmName' は Linux です。この Tool は Windows VM 専用です。" }
if (-not $LocalUserName) { $LocalUserName = $vm.OSProfile.AdminUsername }
$power = ((Get-AzVM -ResourceGroupName $ResourceGroupName -Name $VmName -Status).Statuses | Where-Object { $_.Code -like 'PowerState/*' }).Code
if ($power -ne 'PowerState/running') { throw "VM '$VmName' が起動していません（$power）。Set-VMPower.ps1 で起動してください。" }

# ---- 締め出し防止のチェック（止めるときだけ）
if (-not $Enable) {
    $ext = Get-AzVMExtension -ResourceGroupName $ResourceGroupName -VMName $VmName -Name 'AADLoginForWindows' -ErrorAction SilentlyContinue
    if (-not $ext -or $ext.ProvisioningState -ne 'Succeeded') {
        throw 'AADLoginForWindows が導入されていません。先に Enable-EntraLogin.ps1 を実行してください。'
    }
    $admins = @(Get-AzRoleAssignment -Scope $vm.Id -RoleDefinitionName 'Virtual Machine Administrator Login' -ErrorAction SilentlyContinue)
    if ($admins.Count -eq 0) {
        throw "'Virtual Machine Administrator Login' が割り当てられていません。Enable-EntraLogin.ps1 -Role Administrator で、管理者ロールを付けてください。"
    }
    $members = Invoke-VmScript 'net localgroup Administrators'
    if ($members -notmatch '(?im)^\s*AzureAD\\') {
        throw 'VM の Administrators グループに、Entra ID のユーザー（AzureAD\...）がいません。Entra ID の管理者で、一度ログインできることを確認してから実行してください。'
    }
    Say '  チェック OK: 拡張 / 管理者ロール / Entra ID の管理者（Administrators）' -Color DarkGray
}

$action = if ($Enable) { '戻す' } else { '止める' }
$done = if ($Enable) { '戻しました' } else { '止めました' }
$what = if ($Mode -eq 'DenyRdp') { 'RDP ログオンを拒否' } else { 'アカウントを無効化' }
Say ("対象: VM '{0}' のローカル ユーザー '{1}'  /  内容: {2}（{3}）" -f $VmName, $LocalUserName, $what, $action) -Color Cyan
if ($WhatIfPreference) { Say '（-WhatIf: 何も変更していません）' -Color DarkGray; return }
if (-not $Enable) {
    Say '  復旧: Run Command は RDP と無関係に使えます。このスクリプトを -Enable で実行すれば、戻せます。' -Color DarkGray
}
if (-not (Confirm-Action 'よろしいですか' -Force:$Force)) { Say '中止しました。' -Color Yellow; return }

# ---- 実行
if ($Mode -eq 'DisableAccount') {
    $cmd = if ($Enable) { 'Enable-LocalUser' } else { 'Disable-LocalUser' }
    $out = Invoke-VmScript ("$cmd -Name '$LocalUserName'; (Get-LocalUser -Name '$LocalUserName').Enabled")
    Say ("  アカウントの有効状態: {0}" -f $out.Trim().Split("`n")[-1]) -Color DarkGray
}
else {
    $script = @'
$ErrorActionPreference = 'Stop'
$user = '__USER__'
$sid = (Get-LocalUser -Name $user).SID.Value
$mine = "*$sid"
# secedit の出力は、SID ではなくユーザー名（azureuser や PC名zureuser）で返ることがある。どれでも「自分」とみなす。
function Test-Mine([string]$e) { return ($e -eq $mine -or $e -ieq $user -or $e -ieq "$env:COMPUTERNAME\$user") }
$right = 'SeDenyRemoteInteractiveLogonRight'
$cfg = Join-Path $env:TEMP 'dx-ur.inf'
$cfg2 = Join-Path $env:TEMP 'dx-ur2.inf'
$db = Join-Path $env:TEMP 'dx-ur.sdb'
secedit /export /cfg $cfg /areas USER_RIGHTS | Out-Null
$line = Get-Content $cfg -Encoding Unicode | Where-Object { $_ -match "^$right\s*=" } | Select-Object -First 1
$entries = @()
if ($line) { $entries = @(($line -replace "^$right\s*=\s*", '') -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_ }) }
if ('__ACTION__' -eq 'Deny') { if (-not @($entries | Where-Object { Test-Mine $_ }).Count) { $entries += $mine } }
else { $entries = @($entries | Where-Object { -not (Test-Mine $_) }) }
$inf = "[Unicode]`r`nUnicode=yes`r`n[Version]`r`nsignature=`"`$CHICAGO`$`"`r`nRevision=1`r`n[Privilege Rights]`r`n$right = " + ($entries -join ',') + "`r`n"
Set-Content -Path $cfg2 -Value $inf -Encoding Unicode
secedit /configure /db $db /cfg $cfg2 /areas USER_RIGHTS | Out-Null
secedit /export /cfg $cfg /areas USER_RIGHTS | Out-Null
$now = Get-Content $cfg -Encoding Unicode | Where-Object { $_ -match "^$right\s*=" } | Select-Object -First 1
$nowEntries = @(($now -replace "^$right\s*=\s*", '') -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_ })
$denied = [bool](@($nowEntries | Where-Object { Test-Mine $_ }).Count)
Write-Output ("denied=" + $denied)
Remove-Item $cfg, $cfg2, $db -ErrorAction SilentlyContinue
'@.Replace('__USER__', $LocalUserName).Replace('__ACTION__', $(if ($Enable) { 'Allow' } else { 'Deny' }))
    $out = Invoke-VmScript $script
    $denied = $out -match 'denied=True'
    $expect = -not $Enable
    if ($denied -ne $expect) { throw "設定が反映されませんでした:`n$out" }
    Say ("  RDP ログオンの拒否: {0}" -f $(if ($denied) { '有効（ローカル ユーザーは RDP で入れません）' } else { '解除しました' })) -Color DarkGray
}

Say ''
Say "完了: ローカル ユーザー '$LocalUserName' を$done。" -Color Green
if (-not $Enable) { Say '  Entra ID のアカウントで、RDP に入れることを、確認してください（このウィンドウは閉じないでください）。' -Color Yellow }
