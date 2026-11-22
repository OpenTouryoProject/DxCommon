<#
.SYNOPSIS
    単体の Azure VM（Windows または Linux）を、専用の VNet / Public IP / NSG つきで作成する。

.DESCRIPTION
    Research の README.md / Windows.md / Linux.md を Azure PowerShell に置き換えたもの。
      Windows: RDP(3389) を許可する NSG ルールを付ける。
      Linux  : SSH 鍵（-SshKeyPath）で SSH(22) を許可する。鍵が無ければ ssh-keygen で作成し（パスフレーズは対話入力）、
               公開鍵を Azure の SSH キーリソース（<VmName>-sshkey）にも登録する。
               SSH はパスワード認証が無効（鍵のみ）。xrdp 用のパスワードは -InstallXrdp が設定する。
    管理者のユーザー名とパスワードは、実行時に Get-Credential で入力する（-Credential でも渡せる）。
    リソースグループは、無ければ作成する。VM の作成には数分かかり、課金される。

.PARAMETER OS
    Win2019Datacenter / Win2022Datacenter / Ubuntu2604 / Ubuntu2404 / Ubuntu2204

.PARAMETER SshKeyPath
    Linux 用の秘密鍵のパス。既定: ~/.ssh/<VmName>。公開鍵は <SshKeyPath>.pub。

.PARAMETER InstallXrdp
    Linux（Ubuntu2204）に、xfce4 と xrdp をインストールする（Run Command。数分かかる）。
    3389 の受信は開けないので、必要なら Open-VMPort.ps1 で、接続元を絞って開ける。

.PARAMETER SourceAddressPrefix
    Windows の RDP(3389) を許可する送信元（IP / CIDR）。Windows では必須（* は拒否）。Linux の SSH(22) は、指定がなければ * 。

.PARAMETER MyIp
    自分の現在のグローバル IP を送信元にする（外部サービス api.ipify.org に問い合わせて調べる）。

.EXAMPLE
    .\New-SingleVM.ps1 -ResourceGroupName hogeRG -VmName hogeVM -OS Ubuntu2204
#>
[CmdletBinding()]
param(
    [string]$Location = 'japaneast',
    [string]$ResourceGroupName = 'hogeRG',
    [string]$VmName = 'hogeVM',
    [string]$VmSize = 'Standard_D4s_v3',
    [ValidateSet('Win2019Datacenter', 'Win2022Datacenter', 'Ubuntu2604', 'Ubuntu2404', 'Ubuntu2204')]
    [string]$OS = 'Win2019Datacenter',
    [pscredential]$Credential,
    [string]$SshKeyPath,
    [switch]$InstallXrdp,
    [string]$SourceAddressPrefix,
    [switch]$MyIp
)
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'SingleVM.Common.ps1')
$null = Assert-AzLogin
Assert-ResourceProviders $RequiredProviders

$img = Get-VmImageSpec $OS
# 送信元の IP 制限（Windows の RDP は必須）。VM やネットワークを作る前に確認する。
$srcPrefix = Resolve-SourcePrefix $SourceAddressPrefix -MyIp:$MyIp -Required:(-not $img.IsLinux)
$cred = Get-CredentialIfNull $Credential "VM '$VmName' の管理者ユーザー名とパスワード"

if ($InstallXrdp -and -not $img.IsLinux) { throw '-InstallXrdp は Linux（Ubuntu2204）でのみ使えます。' }

# Linux: SSH 鍵を用意する
$sshKey = if ($img.IsLinux) { New-LocalSshKey $VmName $SshKeyPath } else { $null }
$pubKey = if ($sshKey) { $sshKey.PublicKey } else { $null }
if ($sshKey) { $SshKeyPath = $sshKey.Path }

Initialize-ResourceGroup $ResourceGroupName $Location

if ($sshKey) { Register-VmSshKey $ResourceGroupName $VmName $pubKey }

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
    -Priority $rule.Priority -SourceAddressPrefix $srcPrefix -SourcePortRange '*' `
    -DestinationAddressPrefix '*' -DestinationPortRange $rule.Port -Access Allow
$nsg = New-AzNetworkSecurityGroup -ResourceGroupName $ResourceGroupName -Name "${VmName}NSG" `
    -Location $Location -SecurityRules $nsgRule
$nic = New-AzNetworkInterface -ResourceGroupName $ResourceGroupName -Name "${VmName}VMNic" -Location $Location `
    -SubnetId $vnet.Subnets[0].Id -PublicIpAddressId $pip.Id -NetworkSecurityGroupId $nsg.Id

# VM
$cfg = New-VmConfig $VmName $VmSize $img $cred $nic.Id $pubKey

Say "  VM '$VmName' を作成します（数分かかります）" -Color Cyan
$null = New-AzVM -ResourceGroupName $ResourceGroupName -Location $Location -VM $cfg

if ($InstallXrdp) { Install-Xrdp $ResourceGroupName $VmName $cred }

$ip = (Get-AzPublicIpAddress -ResourceGroupName $ResourceGroupName -Name $pip.Name).IpAddress
Say ''
Say "完了: VM '$VmName' を作成しました。パブリック IP: $ip" -Color Green
if ($InstallXrdp) { Say '  xrdp: 3389 は開けていません。Open-VMPort.ps1 -Port 3389 -SourceAddressPrefix <自分の IP> で開けてから、mstsc で接続してください。' -Color Yellow }
if ($img.IsLinux) { Say ("  接続: ssh -i `"{0}`" {1}@{2}" -f $SshKeyPath, $cred.UserName, $ip) -Color DarkGray }
else { Say "  接続: mstsc /v:$ip" -Color DarkGray }
