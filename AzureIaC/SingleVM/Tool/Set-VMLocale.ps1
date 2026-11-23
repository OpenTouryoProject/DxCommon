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

.PARAMETER LanguageSourceAccount
    Windows のみ。言語パックの ISO（「Languages and Optional Features」ISO）を置いた Storage アカウント名。
    指定すると、Windows Update でなく、この ISO から言語パックを入れる（速く、ビルドに左右されにくい）。
    ISO は、手動で入手し、Storage の Tool などで、コンテナーにアップロードしておく。
    実行する人に、Storage Blob Data の権限（ユーザー委任キーの取得）が必要。VM には、期限 3 時間の読み取り専用 SAS URL を渡す。

.PARAMETER LanguageSourceContainer
    ISO のコンテナー。既定 langpack。

.PARAMETER LanguageSourceBlob
    ISO の BLOB 名（例: windows-server-2025/26100.1.240331-1435.ge_release_amd64fre_SERVER_LOF_PACKAGES_OEM.iso）。

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
    [string]$LanguageSourceAccount,
    [string]$LanguageSourceContainer = 'langpack',
    [string]$LanguageSourceBlob,
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
$srcUrl = ''
if ($LanguageSourceAccount -or $LanguageSourceBlob) {
    if ($vmIsLinux) { throw '-LanguageSource* は、Windows 専用です。' }
    if (-not ($LanguageSourceAccount -and $LanguageSourceBlob)) { throw '-LanguageSourceAccount と -LanguageSourceBlob は、両方を指定してください。' }
    Say ("  言語パックの取得元: {0}/{1}/{2}（Windows Update は使わない）" -f $LanguageSourceAccount, $LanguageSourceContainer, $LanguageSourceBlob) -Color DarkGray
}
if (-not (Confirm-Action 'よろしいですか' -Force:$Force)) { Say '中止しました。' -Color Yellow; return }
if ($LanguageSourceAccount) {
    $sctx = New-AzStorageContext -StorageAccountName $LanguageSourceAccount -UseConnectedAccount
    $null = Get-AzStorageBlob -Container $LanguageSourceContainer -Blob $LanguageSourceBlob -Context $sctx -ErrorAction Stop   # 無ければ、ここで止まる
    $srcUrl = New-AzStorageBlobSASToken -Container $LanguageSourceContainer -Blob $LanguageSourceBlob -Permission r -ExpiryTime (Get-Date).AddHours(3) -Context $sctx -FullUri
}

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
$srcUrl = '__SRC__'
$phase = '__PHASE__'
$lpPattern = 'Server-LanguagePack.*' + $lang
$lpInstalled = $false
$missingCaps = @()
if ($srcUrl -and $phase -ne 'set') {
    # Already installed? Then skip the ISO (Add-WindowsPackage fails with 0x800f0952 when the language pack is already there).
    $lpInstalled = [bool](Get-WindowsPackage -Online | Where-Object { $_.PackageName -match $lpPattern -and $_.PackageState -eq 'Installed' })
    $missingCaps = @(Get-WindowsCapability -Online -Name ('Language.*' + $lang + '*') | Where-Object State -ne 'Installed')
}
if ($phase -eq 'set') { }
elseif ($srcUrl -and $lpInstalled -and $missingCaps.Count -eq 0) {
    Write-Output 'note: language pack and features are already installed (ISO skipped)'
}
elseif ($srcUrl) {
    # Install from the ISO in Storage (not Windows Update). Keep this script ASCII only (Run Command garbles non-ASCII).
    $iso = Join-Path $env:windir 'Temp\dx-lof.iso'
    $ProgressPreference = 'SilentlyContinue'
    $sw = [Diagnostics.Stopwatch]::StartNew()
    Invoke-WebRequest -Uri $srcUrl -OutFile $iso -UseBasicParsing
    Write-Output ("downloaded: {0} GB in {1} s" -f [math]::Round((Get-Item $iso).Length / 1GB, 2), [int]$sw.Elapsed.TotalSeconds)
    try {
        $vol = Mount-DiskImage -ImagePath $iso -PassThru | Get-Volume
        $src = $vol.DriveLetter + ':\LanguagesAndOptionalFeatures'
        if (-not (Test-Path $src)) { throw "LanguagesAndOptionalFeatures not found in ISO: $src" }
        $lp = Get-ChildItem $src -Filter ("Microsoft-Windows-Server-Language-Pack_x64_" + $lang.ToLower() + ".cab") | Select-Object -First 1
        if (-not $lp) { throw "language pack cab not found: $lang" }
        if (-not $lpInstalled) {
            $r = Add-WindowsPackage -Online -PackagePath $lp.FullName -NoRestart
            Write-Output ("note: Add-WindowsPackage RestartNeeded=" + $r.RestartNeeded)
        }
        Write-Output ("note: LP package state: " + ((Get-WindowsPackage -Online | Where-Object { $_.PackageName -match $lpPattern } | ForEach-Object { $_.PackageName.Split('~')[0] + '=' + $_.PackageState }) -join ';'))
        $caps = Get-WindowsCapability -Online -Name ('Language.*' + $lang + '*') -Source $src -LimitAccess | Where-Object State -ne 'Installed'
        foreach ($c in $caps) { Add-WindowsCapability -Online -Name $c.Name -Source $src -LimitAccess | Out-Null }
        # The language pack can be dropped when the capabilities are added in the same boot. Verify, and add it again if needed.
        $lpState = (Get-WindowsPackage -Online | Where-Object { $_.PackageName -match $lpPattern }).PackageState
        if ($lpState -ne 'Installed') {
            Add-WindowsPackage -Online -PackagePath $lp.FullName -NoRestart | Out-Null
            $lpState = (Get-WindowsPackage -Online | Where-Object { $_.PackageName -match $lpPattern }).PackageState
            Write-Output ("note: language pack added again: " + $lpState)
        }
        if ($lpState -ne 'Installed') { throw "language pack not installed: $lpState" }
        Write-Output ("installed from ISO: " + $lp.Name + " + " + @($caps).Count + " capabilities")
    }
    finally {
        Dismount-DiskImage -ImagePath $iso -ErrorAction SilentlyContinue | Out-Null
        Remove-Item $iso -Force -ErrorAction SilentlyContinue
    }
}
else { Install-Language -Language $lang }
if ($phase -eq 'install') { Write-Output 'locale-done'; return }
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
'@.Replace('__LANG__', $Language).Replace('__TZ__', $TimeZone).Replace('__SRC__', $srcUrl)
        Say '  言語パックをインストールし、ロケールを設定します（数分〜10 分以上かかります）' -Color Cyan
        $script:winTemplate = $script
        $phase1 = if ($srcUrl) { 'install' } else { 'all' }
        $out = Invoke-VmShell $cmdId $script.Replace('__PHASE__', $phase1)
        $out -split "`n" | Where-Object { $_ -match '^(downloaded|installed from ISO|note):' } | ForEach-Object { Say "  $_" -Color DarkGray }
        if ($out -notmatch '(?m)^locale-done\s*$') { throw "設定に失敗した可能性があります:`n$out" }
    }
}

# ---- ISO から入れたときは、再起動してから、言語を設定する（再起動前は、Set-SystemPreferredUILanguage が通らない）
if (-not $vmIsLinux -and $srcUrl) {
    Say '  言語パックを有効にするため、VM を再起動します（その後、言語を設定します）' -Color Cyan
    $null = Restart-AzVM -ResourceGroupName $ResourceGroupName -Name $VmName
    $out = $null
    for ($i = 1; $i -le 10 -and -not $out; $i++) {
        try { $out = Invoke-VmShell $cmdId $script:winTemplate.Replace('__PHASE__', 'set') }
        catch { Say "  VM エージェントの応答を待ちます（$i/10）" -Color DarkGray; Start-Sleep -Seconds 20 }
    }
    if (-not $out -or $out -notmatch '(?m)^locale-done\s*$') { throw "言語の設定に失敗した可能性があります:`n$out" }
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
