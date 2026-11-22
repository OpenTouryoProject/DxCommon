# VM 関連の共通部品。Simplest / SingleVM の各 *.Common.ps1 からドットソースして使う。
# （Say / Get-AzContext などは、読み込み元の Common.ps1 で定義済みのものを使う）

# az の --image 別名に相当する、マーケットプレースイメージの定義。
$VmImages = [ordered]@{
    'Win2019Datacenter' = @{ Publisher = 'MicrosoftWindowsServer'; Offer = 'WindowsServer'; Sku = '2019-Datacenter'; IsLinux = $false }
    'Win2025Datacenter' = @{ Publisher = 'MicrosoftWindowsServer'; Offer = 'WindowsServer'; Sku = '2025-datacenter'; IsLinux = $false }
    'Win2022Datacenter' = @{ Publisher = 'MicrosoftWindowsServer'; Offer = 'WindowsServer'; Sku = '2022-Datacenter'; IsLinux = $false }
    'Ubuntu2604'        = @{ Publisher = 'Canonical'; Offer = 'ubuntu-26_04-lts'; Sku = 'server'; IsLinux = $true }
    'Ubuntu2404'        = @{ Publisher = 'Canonical'; Offer = 'ubuntu-24_04-lts'; Sku = 'server'; IsLinux = $true }
    'Ubuntu2204'        = @{ Publisher = 'Canonical'; Offer = '0001-com-ubuntu-server-jammy'; Sku = '22_04-lts'; IsLinux = $true }
}

function Get-VmImageSpec([string]$OS) {
    if (-not $VmImages.Contains($OS)) {
        throw ("未対応のイメージ: {0}（対応: {1}）" -f $OS, ($VmImages.Keys -join ', '))
    }
    return $VmImages[$OS]
}

function Get-CredentialIfNull([pscredential]$Credential, [string]$Message) {
    if ($Credential) { return $Credential }
    return (Get-Credential -Message $Message)
}

# VM の自動シャットダウン（az vm auto-shutdown 相当）。Time は UTC の HHmm（1500 = JST 0000）。
function Set-VmAutoShutdown([string]$ResourceGroupName, [string]$VmName, [string]$Location, [string]$Time = '1500') {
    $vm = Get-AzVM -ResourceGroupName $ResourceGroupName -Name $VmName
    $props = @{
        status               = 'Enabled'
        taskType             = 'ComputeVmShutdownTask'
        dailyRecurrence      = @{ time = $Time }
        timeZoneId           = 'UTC'
        notificationSettings = @{ status = 'Disabled'; timeInMinutes = 30 }
        targetResourceId     = $vm.Id
    }
    $null = New-AzResource -ResourceType 'Microsoft.DevTestLab/schedules' `
        -ResourceName "shutdown-computevm-$VmName" `
        -ResourceGroupName $ResourceGroupName -Location $Location `
        -Properties $props -Force
    Say "  自動シャットダウンを設定しました (UTC $Time)" -Color DarkGray
}

# Linux 用のローカル SSH 鍵を用意する（無ければ ssh-keygen で作成。パスフレーズは対話入力）。
#   戻り値: @{ Path; PublicKey }
function New-LocalSshKey([string]$VmName, [string]$SshKeyPath) {
    if (-not $SshKeyPath) { $SshKeyPath = Join-Path $HOME ".ssh\$VmName" }
    if (-not (Test-Path "$SshKeyPath.pub")) {
        Say "  SSH 鍵を作成します: $SshKeyPath（パスフレーズを聞かれます）" -Color Cyan
        $null = New-Item -ItemType Directory -Force -Path (Split-Path $SshKeyPath)
        & ssh-keygen -m PEM -t rsa -b 4096 -f $SshKeyPath
        if ($LASTEXITCODE -ne 0 -or -not (Test-Path "$SshKeyPath.pub")) { throw 'ssh-keygen に失敗しました。' }
    }
    else {
        Say "  既存の SSH 鍵を使います: $SshKeyPath" -Color DarkGray
    }
    return @{ Path = $SshKeyPath; PublicKey = (Get-Content "$SshKeyPath.pub" -Raw).Trim() }
}

# 公開鍵を、Azure の SSH キーリソース（<VmName>-sshkey）に登録する（リソースグループが必要）。
function Register-VmSshKey([string]$ResourceGroupName, [string]$VmName, [string]$PublicKey) {
    $keyName = "$VmName-sshkey"
    if (-not (Get-AzSshKey -ResourceGroupName $ResourceGroupName -Name $keyName -ErrorAction SilentlyContinue)) {
        Say "  SSH キー '$keyName' を登録します" -Color Cyan
        $null = New-AzSshKey -ResourceGroupName $ResourceGroupName -Name $keyName -PublicKey $PublicKey
    }
}

# VM 構成（OS・イメージ・NIC）を作る。Linux は、公開鍵があれば登録する（Azure が SSH のパスワード認証を無効にする）。
function New-VmConfig([string]$VmName, [string]$VmSize, $Image, [pscredential]$Credential, [string]$NicId, [string]$SshPublicKey) {
    $cfg = New-AzVMConfig -VMName $VmName -VMSize $VmSize
    if ($Image.IsLinux) {
        $cfg = Set-AzVMOperatingSystem -VM $cfg -Linux -ComputerName $VmName -Credential $Credential
        if ($SshPublicKey) {
            $cfg = Add-AzVMSshPublicKey -VM $cfg -KeyData $SshPublicKey -Path "/home/$($Credential.UserName)/.ssh/authorized_keys"
        }
    }
    else {
        $computerName = $VmName.Substring(0, [Math]::Min(15, $VmName.Length))   # Windows は 15 文字まで
        $cfg = Set-AzVMOperatingSystem -VM $cfg -Windows -ComputerName $computerName -Credential $Credential `
            -ProvisionVMAgent -EnableAutoUpdate
    }
    $cfg = Set-AzVMSourceImage -VM $cfg -PublisherName $Image.Publisher -Offer $Image.Offer -Skus $Image.Sku -Version latest
    return (Add-AzVMNetworkInterface -VM $cfg -Id $NicId)
}

# Linux VM のユーザーのパスワードを設定する（VMAccess 拡張。パスワードは保護された設定で渡す）。
# SSH 鍵つきで作った VM は、Azure が既定でパスワード認証を無効にし、パスワードもロックされる。
# ここで設定するのは、xrdp などのログイン用。sshd のパスワード認証は有効にしない（SSH は鍵のまま）。
function Set-LinuxUserPassword([string]$ResourceGroupName, [string]$VmName, [pscredential]$Credential) {
    Say "  ユーザー '$($Credential.UserName)' のパスワードを設定します（VMAccess 拡張）" -Color Cyan
    $vm = Get-AzVM -ResourceGroupName $ResourceGroupName -Name $VmName
    $prot = @{ username = $Credential.UserName; password = $Credential.GetNetworkCredential().Password }
    $null = Set-AzVMExtension -ResourceGroupName $ResourceGroupName -VMName $VmName -Location $vm.Location `
        -Name 'enablevmaccess' -Publisher 'Microsoft.OSTCExtensions' -ExtensionType 'VMAccessForLinux' `
        -TypeHandlerVersion '1.5' -ProtectedSettings $prot -ForceRerun ([guid]::NewGuid().ToString())
}

# VM の 1 つ目の NIC を返す。
function Get-VmNic($Vm) {
    $r = Split-ResourceId $Vm.NetworkProfile.NetworkInterfaces[0].Id
    return (Get-AzNetworkInterface -ResourceGroupName $r.ResourceGroupName -Name $r.Name)
}

# VM が Linux かどうか。
function Test-VmIsLinux($Vm) { return ($Vm.StorageProfile.OsDisk.OsType -eq 'Linux') }

# VM の中でスクリプトを実行する（Run Command）。戻り値: 出力の文字列。-WhatIf の影響は受けない。
function Invoke-VmCommand([string]$ResourceGroupName, [string]$VmName, [string]$CommandId, [string]$Script) {
    $r = Invoke-AzVMRunCommand -ResourceGroupName $ResourceGroupName -VMName $VmName -CommandId $CommandId -ScriptString $Script -WhatIf:$false
    return (($r.Value | ForEach-Object { $_.Message }) -join "`n")
}

# VM の中から、インターネットに出られるかを確認する。
function Test-VmOutbound([string]$ResourceGroupName, [string]$VmName, [bool]$OsIsLinux) {
    if ($osIsLinux) {
        $cmd = 'RunShellScript'
        $probe = '(timeout 8 bash -c "echo > /dev/tcp/azure.archive.ubuntu.com/80" && echo outbound-ok) 2>&1 || echo outbound-fail'
    }
    else {
        $cmd = 'RunPowerShellScript'
        $probe = 'try { $null = Invoke-WebRequest -UseBasicParsing -Uri http://www.msftconnecttest.com/connecttest.txt -TimeoutSec 8; "outbound-ok" } catch { "outbound-fail" }'
    }
    return ((Invoke-VmCommand $ResourceGroupName $VmName $cmd $probe) -match 'outbound-ok')
}

# VM がインターネットに出られないとき（プライベート サブネット。既定のアウトバウンドが無効）は、
# 一時的な Public IP を付けて、-Action を実行し、終わったら（失敗しても）外して削除する。
# 出られるときは、そのまま -Action を実行する。-Disable を付けると、一時 Public IP を付けず、出られなければ例外にする。
# Standard の Public IP は、NSG で許可しない限り、受信できない（NSG が無い NIC でも同じ）。
function Invoke-WithTempPublicIp([string]$ResourceGroupName, [string]$VmName, [scriptblock]$Action, [switch]$Disable) {
    $vm = Get-AzVM -ResourceGroupName $ResourceGroupName -Name $VmName
    $osIsLinux = Test-VmIsLinux $vm
    $tempPip = $null
    try {
        if (Test-VmOutbound $ResourceGroupName $VmName $osIsLinux) {
            Say '  インターネットに出られます。' -Color DarkGray
        }
        else {
            if ($Disable) { throw "VM '$VmName' はインターネットに出られません（一時的な Public IP を付けない指定のため、止めます）。" }
            $nic = Get-VmNic $vm
            if ($nic.IpConfigurations[0].PublicIpAddress.Id) {
                throw "VM '$VmName' は Public IP が付いていますが、インターネットに出られません。NSG などを確認してください。"
            }
            $name = "$VmName-tmp-pip"
            Say "  インターネットに出られません。一時的な Public IP '$name' を付けます（終わったら削除します）" -Color Cyan
            $tempPip = New-AzPublicIpAddress -ResourceGroupName $ResourceGroupName -Name $name -Location $vm.Location -Sku Standard -AllocationMethod Static
            $nic.IpConfigurations[0].PublicIpAddress = $tempPip
            $null = Set-AzNetworkInterface -NetworkInterface $nic
            if (-not (Test-VmOutbound $ResourceGroupName $VmName $osIsLinux)) { throw '一時的な Public IP を付けても、インターネットに出られません。' }
        }
        & $Action
    }
    finally {
        if ($tempPip) {
            Say "  一時的な Public IP '$($tempPip.Name)' を外して削除します" -Color Cyan
            $nic = Get-VmNic (Get-AzVM -ResourceGroupName $ResourceGroupName -Name $VmName)
            $nic.IpConfigurations[0].PublicIpAddress = $null
            $null = Set-AzNetworkInterface -NetworkInterface $nic
            $null = Remove-AzPublicIpAddress -ResourceGroupName $ResourceGroupName -Name $tempPip.Name -Force
        }
    }
}

# Linux VM に、デスクトップ環境（xfce4）と xrdp を入れる（Run Command で実行。数分かかる）。
# インターネットに出られない VM には、一時的な Public IP を付けて、終わったら削除する（-NoTempPublicIp で、付けずに止まる）。
# 3389 の受信は開けない。必要なら NSG などで、接続元を絞って開けること。
function Install-Xrdp([string]$ResourceGroupName, [string]$VmName, [pscredential]$Credential, [switch]$NoTempPublicIp) {
    $UserName = $Credential.UserName
    Set-LinuxUserPassword $ResourceGroupName $VmName $Credential
    $script = @'
set -e
export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get -y install xfce4 xrdp
adduser xrdp ssl-cert
echo xfce4-session > /etc/skel/.xsession
echo xfce4-session > /home/__USER__/.xsession
chown __USER__:__USER__ /home/__USER__/.xsession
systemctl enable xrdp
systemctl restart xrdp
echo xrdp-installed
'@.Replace('__USER__', $UserName).Replace("`r`n", "`n")
    Invoke-WithTempPublicIp $ResourceGroupName $VmName -Disable:$NoTempPublicIp -Action {
        Say "  VM '$VmName' に xfce4 と xrdp をインストールします（数分かかります）" -Color Cyan
        $out = Invoke-VmCommand $ResourceGroupName $VmName 'RunShellScript' $script
        if ($out -notmatch 'xrdp-installed') { throw "xrdp のインストールに失敗した可能性があります:`n$out" }
    }
    Say "  xrdp をインストールしました。ログインには、この VM の管理者ユーザーとパスワードを使います（SSH は鍵のみ）。" -Color DarkGray
}
