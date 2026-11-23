<#
.SYNOPSIS
    VM の言語・ロケール・タイムゾーンを設定する（既定は日本語 / 東京）。Windows と Linux（Ubuntu）に対応。

.DESCRIPTION
    Run Command（Azure の VM エージェント経由）で、VM の中の設定を行う。RDP や SSH は要らない。
      Windows: 言語パック（Install-Language）、システムの表示言語、システム ロケール、国、タイムゾーン、
               ようこそ画面・新規ユーザーへの設定コピー。完了後に再起動する。
      Linux  : language-pack-<言語>、フォント、ロケール（ja_JP.UTF-8）、タイムゾーン。
    言語パックなどは、インターネット（Windows Update / Ubuntu のミラー）から取得する。
    VM がインターネットに出られない場合（プライベート サブネット。既定のアウトバウンドが無効）は、
    一時的に Public IP を付けて作業し、終わったら外して削除する（-NoTempPublicIp で、付けずに止まる）。
    この処理は、Common\Vm.Common.ps1 の Invoke-WithTempPublicIp（Install-Xrdp と共通）。
    Standard の Public IP は、NSG で許可しない限り、受信できない。

    ※ 表示言語や書式には、ユーザー単位の設定もある。Run Command は SYSTEM として動くため、既存のユーザーの設定は
      そのままでは変わらない。ようこそ画面と新規ユーザーには反映される。既存のユーザーは、ログイン後に一度、
      設定（時刻と言語）で確認すること。
    ※ 言語パックの取得は数分〜10 分以上かかる。VM は、起動している必要がある。

.PARAMETER Language
    言語（BCP 47）。既定 ja-JP。

.PARAMETER TimeZone
    Windows のタイムゾーン ID。既定 'Tokyo Standard Time'。Linux は、Asia/Tokyo。

.PARAMETER NoRestart
    Windows で、設定後に再起動しない（反映には、再起動が必要）。

.PARAMETER NoTempPublicIp
    一時的な Public IP を付けない（インターネットに出られない場合は、エラーで止まる）。

.EXAMPLE
    .\Set-VMLocale.ps1 -ResourceGroupName AzureBastionRG -VmName JumpboxVM1
#>
[CmdletBinding(SupportsShouldProcess)]
param(
    [string]$ResourceGroupName = 'hogeRG',
    [string]$VmName = 'hogeVM',
    [string]$Language = 'ja-JP',
    [string]$TimeZone = 'Tokyo Standard Time',
    [switch]$NoRestart,
    [switch]$NoTempPublicIp,
    [switch]$Force
)
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'SingleVM.Common.ps1')
$null = Assert-AzLogin
Assert-ResourceProviders $RequiredProviders

function Invoke-VmShell([string]$CommandId, [string]$Script) { return (Invoke-VmCommand $ResourceGroupName $VmName $CommandId $Script) }

$vm = Get-AzVM -ResourceGroupName $ResourceGroupName -Name $VmName
$vmIsLinux = Test-VmIsLinux $vm
$cmdId = if ($vmIsLinux) { 'RunShellScript' } else { 'RunPowerShellScript' }
$power = ((Get-AzVM -ResourceGroupName $ResourceGroupName -Name $VmName -Status).Statuses | Where-Object { $_.Code -like 'PowerState/*' }).Code
if ($power -ne 'PowerState/running') { throw "VM '$VmName' が起動していません（$power）。Set-VMPower.ps1 で起動してください。" }

Say ("対象: VM '{0}'（{1}） /  言語: {2}  /  タイムゾーン: {3}" -f $VmName, $(if ($vmIsLinux) { 'Linux' } else { 'Windows' }), $Language,
    $(if ($vmIsLinux) { 'Asia/Tokyo' } else { $TimeZone })) -Color Cyan
if (-not $vmIsLinux -and -not $NoRestart) { Say '  ※ 設定後に、VM を再起動します（RDP / Bastion の接続が、一時的に切れます）。' -Color Yellow }
if ($WhatIfPreference) { Say '（-WhatIf: 何も変更していません）' -Color DarkGray; return }
if (-not (Confirm-Action 'よろしいですか' -Force:$Force)) { Say '中止しました。' -Color Yellow; return }

# ---- 設定（インターネットに出られない VM には、一時的な Public IP を付けて、終わったら削除する）
Invoke-WithTempPublicIp $ResourceGroupName $VmName -Disable:$NoTempPublicIp -Action {
    # ---- 設定
    if ($vmIsLinux) {
        $lang = $Language.Split('-')[0]
        $locale = ($Language -replace '-', '_') + '.UTF-8'
        $script = @'
set -e
export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get -y install language-pack-__LANG__ language-pack-__LANG__-base fonts-noto-cjk locales
locale-gen __LOCALE__
update-locale LANG=__LOCALE__
timedatectl set-timezone Asia/Tokyo
echo locale-done
'@.Replace('__LANG__', $lang).Replace('__LOCALE__', $locale).Replace("`r`n", "`n")
        Say '  言語パックとロケールを設定します（数分かかります）' -Color Cyan
        $out = Invoke-VmShell $cmdId $script
        if ($out -notmatch 'locale-done') { throw "設定に失敗した可能性があります:`n$out" }
    }
    else {
        $script = @'
$ErrorActionPreference = 'Stop'
$lang = '__LANG__'
Import-Module LanguagePackManagement
Install-Language -Language $lang
Set-SystemPreferredUILanguage $lang
Set-WinSystemLocale $lang
Set-Culture $lang
Set-WinHomeLocation -GeoId 122
Set-TimeZone -Id '__TZ__'
try {
    Set-WinUserLanguageList -LanguageList $lang -Force
    Copy-UserInternationalSettingsToSystem -WelcomeScreen $true -NewUser $true
} catch { Write-Output ("note: " + $_.Exception.Message) }
Write-Output 'locale-done'
'@.Replace('__LANG__', $Language).Replace('__TZ__', $TimeZone)
        Say '  言語パックをインストールし、ロケールを設定します（数分〜10 分以上かかります）' -Color Cyan
        $out = Invoke-VmShell $cmdId $script
        if ($out -notmatch 'locale-done') { throw "設定に失敗した可能性があります:`n$out" }
    }
}

# ---- 再起動（Windows）と、結果の確認
if (-not $vmIsLinux -and -not $NoRestart) {
    Say '  VM を再起動します' -Color Cyan
    $null = Restart-AzVM -ResourceGroupName $ResourceGroupName -Name $VmName
}
Say ''
Say '現在の設定:' -Color Cyan
$check = if ($vmIsLinux) { 'locale | head -3; timedatectl | grep "Time zone"' }
         else { '"UI=" + (Get-SystemPreferredUILanguage); "Locale=" + (Get-WinSystemLocale).Name; "Culture=" + (Get-Culture).Name; "TimeZone=" + (Get-TimeZone).Id; "GeoId=" + (Get-WinHomeLocation).GeoId; "LanguageFeatures=" + ((Get-WindowsCapability -Online -Name ("Language.*" + "__LANG__" + "*") | Where-Object State -eq "Installed" | ForEach-Object { ($_.Name -split "~")[0] }) -join ",")'.Replace('__LANG__', $Language) }
$checkOut = $null
for ($i = 1; $i -le 8 -and -not $checkOut; $i++) {
    try { $checkOut = (Invoke-VmShell $cmdId $check).Trim() }
    catch { Say "  VM エージェントの応答を待ちます（$i/8）" -Color DarkGray; Start-Sleep -Seconds 20 }
}
if ($checkOut) { $checkOut -split "`n" | ForEach-Object { Say "  $_" -Color White } }
else { Say '  設定の確認ができませんでした（VM の起動後に、もう一度確認してください）。' -Color Yellow }
Say "完了: VM '$VmName' の言語設定を行いました。" -Color Green
if (-not $vmIsLinux) { Say '  表示言語は、サインアウト → サインインで反映されます（ユーザー単位の設定は、ログイン後に確認してください）。' -Color DarkGray }
