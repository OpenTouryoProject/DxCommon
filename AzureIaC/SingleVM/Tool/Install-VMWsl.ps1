<#
.SYNOPSIS
    Windows VM に、WSL2 の土台（機能の有効化 + WSL 本体の導入）を、外から（Run Command で）入れる。

.DESCRIPTION
    Run Command（SYSTEM）で、次を行う。RDP は要らない。
      1. 前提の確認: 入れ子の仮想化（ハイパーバイザーが見えること）。Windows のみ。
      2. 機能の有効化: Microsoft-Windows-Subsystem-Linux / VirtualMachinePlatform。
      3. VM の再起動。
      4. WSL 本体（MSI。GitHub の microsoft/WSL の最新リリース、約 350 MB）の導入（インターネットが要る。出られない VM には、一時 Public IP を付けて、終わったら削除する）。
         機能を有効にしただけでは、wsl.exe は「WSL が入っていない」状態。Run Command（SYSTEM）では wsl --install / --update が使えないため、MSI を直接入れる。
    **ディストリビューション（Ubuntu など）は、入れない。** ユーザー単位のため、使う人が、ログインして
    `wsl --install -d Ubuntu`（または `wsl --install --web-download -d Ubuntu`）で入れる。
    入れ子の仮想化に対応しない VM サイズ（例: 一部の B シリーズ）では、WSL2 は動かない。
    すでに有効なら、機能の有効化は飛ばす（再実行できる）。

.PARAMETER NoRestart
    機能を有効にしたあと、再起動しない（WSL 本体の導入は、再起動後に行うため、飛ばす）。

.EXAMPLE
    .\Install-VMWsl.ps1 -ResourceGroupName YourRG -VmName YourVM1
#>
[CmdletBinding(SupportsShouldProcess)]
param(
    [string]$ResourceGroupName = 'hogeRG',
    [string]$VmName = 'hogeVM',
    [switch]$NoRestart,
    [switch]$NoTempPublicIp,
    [switch]$Force
)
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'SingleVM.Common.ps1')
$null = Assert-AzLogin
Assert-ResourceProviders $RequiredProviders

function Invoke-VmScript([string]$Script) { return (Invoke-VmCommand $ResourceGroupName $VmName 'RunPowerShellScript' $Script) }

$vm = Get-AzVM -ResourceGroupName $ResourceGroupName -Name $VmName
if (Test-VmIsLinux $vm) { throw "VM '$VmName' は Linux です。この Tool は Windows VM 専用です。" }
$power = ((Get-AzVM -ResourceGroupName $ResourceGroupName -Name $VmName -Status).Statuses | Where-Object { $_.Code -like 'PowerState/*' }).Code
if ($power -ne 'PowerState/running') { throw "VM '$VmName' が起動していません（$power）。起動してから実行してください。" }
Say ("対象: VM '{0}'（{1}）  /  内容: WSL2 の土台（機能の有効化 → 再起動 → WSL 本体の導入）" -f $VmName, $vm.HardwareProfile.VmSize) -Color Cyan

# ---- 1. 前提（入れ子の仮想化）と現在の状態
$state = @'
"hypervisor=" + (Get-CimInstance Win32_ComputerSystem).HypervisorPresent
foreach ($n in 'Microsoft-Windows-Subsystem-Linux', 'VirtualMachinePlatform') { "feature:" + $n + "=" + (Get-WindowsOptionalFeature -Online -FeatureName $n).State }
"wsl=" + [bool](Get-Command wsl.exe -ErrorAction SilentlyContinue)
'@
$st = Invoke-VmScript $state
if ($st -notmatch 'hypervisor=True') {
    throw 'ハイパーバイザーが見えません。入れ子の仮想化に対応しないサイズ / 構成の可能性があります。WSL2 は動きません。'
}
$enabled = ($st -match 'Subsystem-Linux=Enabled') -and ($st -match 'VirtualMachinePlatform=Enabled')
Say ("  現在: {0}" -f (($st -split "`n" | Where-Object { $_ -match '=' } | ForEach-Object { $_.Trim() }) -join ' / ')) -Color DarkGray
if ($WhatIfPreference) { Say '（-WhatIf: 確認まで。何も変更していません）' -Color DarkGray; return }
if (-not (Confirm-Action 'よろしいですか（再起動を伴います）' -Force:$Force)) { Say '中止しました。' -Color Yellow; return }

# ---- 2. 機能の有効化
if (-not $enabled) {
    $out = Invoke-VmScript @'
$ErrorActionPreference = 'Stop'
$need = $false
foreach ($n in 'Microsoft-Windows-Subsystem-Linux', 'VirtualMachinePlatform') {
    $r = Enable-WindowsOptionalFeature -Online -FeatureName $n -NoRestart -All
    if ($r.RestartNeeded) { $need = $true }
}
Write-Output ("restart-needed=" + $need)
Write-Output 'features-done'
'@
    if ($out -notmatch '(?m)^features-done\s*$') { throw "機能の有効化に失敗した可能性があります:`n$out" }
    Say '  機能を有効にしました。' -Color DarkGray
}
else { Say '  機能は、すでに有効です（スキップ）。' -Color DarkGray }

# ---- 3. 再起動
if ($NoRestart) { Say '  再起動していません。WSL 本体の導入は、再起動後に、もう一度実行してください。' -Color Yellow; return }
if (-not $enabled) {
    Say '  VM を再起動します（RDP / Bastion の接続は切れます）' -Color Cyan
    $null = Restart-AzVM -ResourceGroupName $ResourceGroupName -Name $VmName
}

# ---- 4. WSL 本体（MSI）の導入（インターネットが要る）
#   機能を有効にしただけでは、wsl.exe は「WSL が入っていない」状態。Run Command（SYSTEM）では、wsl --install も
#   wsl --update も使えない（ハンドルが無効 / 管理者特権が必要）ため、GitHub の microsoft/WSL の最新リリースの MSI を、直接入れる。
Invoke-WithTempPublicIp $ResourceGroupName $VmName -Disable:$NoTempPublicIp -Action {
    Say '  WSL 本体（MSI）を導入します（約 350 MB のダウンロード）' -Color Cyan
    $out = $null
    for ($i = 1; $i -le 10 -and -not $out; $i++) {
        try {
            $out = Invoke-VmScript @'
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$rel = Invoke-RestMethod -Uri 'https://api.github.com/repos/microsoft/WSL/releases/latest' -Headers @{ 'User-Agent' = 'dx-tool' }
$asset = $rel.assets | Where-Object { $_.name -match 'x64\.msi$' } | Select-Object -First 1
if (-not $asset) { throw 'WSL msi asset not found' }
Write-Output ("release: " + $rel.tag_name + " " + $asset.name)
$msi = Join-Path $env:windir 'Temp\wsl.msi'
Invoke-WebRequest -Uri $asset.browser_download_url -OutFile $msi -UseBasicParsing
$p = Start-Process msiexec.exe -ArgumentList "/i `"$msi`" /qn /norestart" -Wait -PassThru
Remove-Item $msi -Force -ErrorAction SilentlyContinue
Write-Output ("msiexec exit: " + $p.ExitCode)
if ($p.ExitCode -notin 0, 3010) { throw ("msiexec failed: " + $p.ExitCode) }
$exe = 'C:\Program Files\WSL\wsl.exe'
if (-not (Test-Path $exe)) { throw 'wsl.exe not found after install' }
Write-Output ("wsl file version: " + (Get-Item $exe).VersionInfo.FileVersion)
Write-Output 'wsl-done'
'@
        }
        catch { Say "  VM エージェントの応答を待ちます（$i/10）" -Color DarkGray; Start-Sleep -Seconds 20 }
    }
    if ($out -notmatch '(?m)^wsl-done\s*$') { throw "WSL の導入に失敗した可能性があります:`n$out" }
    $script:wslOut = $out
}
Say ''
Say 'WSL の状態:' -Color Cyan
($script:wslOut -split "`n") | Where-Object { $_ -match '^(release|msiexec exit|wsl file version)' } | ForEach-Object { Say "  $_" -Color White }
Say "完了: VM '$VmName' に、WSL2 の土台を入れました。" -Color Green
Say '  ※ Run Command（SYSTEM）では、WSL を実行できません（WSL_E_LOCAL_SYSTEM_NOT_SUPPORTED）。ディストリビューションは、使う人が、ログインして wsl --install -d Ubuntu で入れてください。' -Color DarkGray
