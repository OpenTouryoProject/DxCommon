<#
.SYNOPSIS
    単体の Azure VM（Windows または Linux）を、専用の VNet / Public IP / NSG つきで作成する。

.DESCRIPTION
    Research の README.md / Windows.md / Linux.md を Azure PowerShell に置き換えたもの。
      Windows: RDP(3389) を許可する NSG ルールを付ける。
      Linux  : SSH 鍵（-SshKeyPath）で SSH(22) を許可する。鍵が無ければ ssh-keygen で作成し（パスフレーズは対話入力）、
               公開鍵を Azure の SSH キーリソース（<VmName>-sshkey）にも登録する。
               パスワード認証も有効のまま（xrdp でのログイン用）。
    管理者のユーザー名とパスワードは、実行時に Get-Credential で入力する（-Credential でも渡せる）。
    リソースグループは、無ければ作成する。VM の作成には数分かかり、課金される。

.PARAMETER OS
    Win2019Datacenter / Win2022Datacenter / Ubuntu2204

.PARAMETER SshKeyPath
    Linux 用の秘密鍵のパス。既定: ~/.ssh/<VmName>。公開鍵は <SshKeyPath>.pub。

.EXAMPLE
    .\New-SingleVM.ps1 -ResourceGroupName hogeRG -VmName hogeVM -OS Ubuntu2204
#>
[CmdletBinding()]
param(
    [string]$Location = 'japaneast',
    [string]$ResourceGroupName = 'hogeRG',
    [string]$VmName = 'hogeVM',
    [string]$VmSize = 'Standard_D4s_v3',
    [ValidateSet('Win2019Datacenter', 'Win2022Datacenter', 'Ubuntu2204')]
    [string]$OS = 'Win2019Datacenter',
    [pscredential]$Credential,
    [string]$SshKeyPath
)
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'SingleVM.Common.ps1')
$null = Assert-AzLogin
Assert-ResourceProviders $RequiredProviders

$img = Get-VmImageSpec $OS
$cred = Get-CredentialIfNull $Credential "VM '$VmName' の管理者ユーザー名とパスワード"

# Linux: SSH 鍵を用意する
$pubKey = $null
if ($img.IsLinux) {
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
    $pubKey = (Get-Content "$SshKeyPath.pub" -Raw).Trim()
}

Initialize-ResourceGroup $ResourceGroupName $Location

if ($img.IsLinux) {
    $keyName = "$VmName-sshkey"
    if (-not (Get-AzSshKey -ResourceGroupName $ResourceGroupName -Name $keyName -ErrorAction SilentlyContinue)) {
        Say "  SSH キー '$keyName' を登録します" -Color Cyan
        $null = New-AzSshKey -ResourceGroupName $ResourceGroupName -Name $keyName -PublicKey $pubKey
    }
}

# ネットワーク（az vm create の自動作成に相当: <VmName>VNET / <VmName>Subnet / <VmName>PublicIP / <VmName>NSG）
Say '  ネットワークを作成します' -Color Cyan
$subnet = New-AzVirtualNetworkSubnetConfig -Name "${VmName}Subnet" -AddressPrefix '10.0.0.0/24'
$vnet = New-AzVirtualNetwork -ResourceGroupName $ResourceGroupName -Name "${VmName}VNET" `
    -Location $Location -AddressPrefix '10.0.0.0/16' -Subnet $subnet
$pip = New-AzPublicIpAddress -ResourceGroupName $ResourceGroupName -Name "${VmName}PublicIP" `
    -Location $Location -Sku Standard -AllocationMethod Static

if ($img.IsLinux) { $rule = @{ Name = 'Allow-SSH'; Port = 22; Priority = 100 } }
else { $rule = @{ Name = 'Allow-RDP'; Port = 3389; Priority = 100 } }
$nsgRule = New-AzNetworkSecurityRuleConfig -Name $rule.Name -Protocol Tcp -Direction Inbound `
    -Priority $rule.Priority -SourceAddressPrefix '*' -SourcePortRange '*' `
    -DestinationAddressPrefix '*' -DestinationPortRange $rule.Port -Access Allow
$nsg = New-AzNetworkSecurityGroup -ResourceGroupName $ResourceGroupName -Name "${VmName}NSG" `
    -Location $Location -SecurityRules $nsgRule
$nic = New-AzNetworkInterface -ResourceGroupName $ResourceGroupName -Name "${VmName}VMNic" -Location $Location `
    -SubnetId $vnet.Subnets[0].Id -PublicIpAddressId $pip.Id -NetworkSecurityGroupId $nsg.Id

# VM
$cfg = New-AzVMConfig -VMName $VmName -VMSize $VmSize
if ($img.IsLinux) {
    $cfg = Set-AzVMOperatingSystem -VM $cfg -Linux -ComputerName $VmName -Credential $cred
    $cfg = Add-AzVMSshPublicKey -VM $cfg -KeyData $pubKey -Path "/home/$($cred.UserName)/.ssh/authorized_keys"
}
else {
    $computerName = $VmName.Substring(0, [Math]::Min(15, $VmName.Length))   # Windows は 15 文字まで
    $cfg = Set-AzVMOperatingSystem -VM $cfg -Windows -ComputerName $computerName -Credential $cred `
        -ProvisionVMAgent -EnableAutoUpdate
}
$cfg = Set-AzVMSourceImage -VM $cfg -PublisherName $img.Publisher -Offer $img.Offer -Skus $img.Sku -Version latest
$cfg = Add-AzVMNetworkInterface -VM $cfg -Id $nic.Id

Say "  VM '$VmName' を作成します（数分かかります）" -Color Cyan
$null = New-AzVM -ResourceGroupName $ResourceGroupName -Location $Location -VM $cfg

$ip = (Get-AzPublicIpAddress -ResourceGroupName $ResourceGroupName -Name $pip.Name).IpAddress
Say ''
Say "完了: VM '$VmName' を作成しました。パブリック IP: $ip" -Color Green
if ($img.IsLinux) { Say ("  接続: ssh -i `"{0}`" {1}@{2}" -f $SshKeyPath, $cred.UserName, $ip) -Color DarkGray }
else { Say "  接続: mstsc /v:$ip" -Color DarkGray }
