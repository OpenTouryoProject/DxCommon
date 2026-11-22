<#
.SYNOPSIS
    サンドボックス（RG / VNet / VM）を作成する。

.DESCRIPTION
    Research の 3.sandbox.sh を Azure PowerShell に置き換えたもの。
    VM はパブリック IP なしで作る。Bastion からの接続には、New-VnetPeering.ps1 で VNet をピアリングする。
    管理者のユーザー名とパスワードは、実行時に Get-Credential で入力する（-Credential でも渡せる）。

.EXAMPLE
    .\New-Sandbox.ps1
#>
[CmdletBinding()]
param(
    [string]$Location = 'japaneast',
    [string]$ResourceGroupName = 'YourRG',
    [string]$VnetName = 'YourVnet',
    [string]$SubnetName = 'YourSubnet',
    [string]$VmName = 'YourVM1',
    [string]$VmSize = 'Standard_D4s_v3',
    [ValidateSet('Win2019Datacenter', 'Win2022Datacenter', 'Ubuntu2604', 'Ubuntu2404', 'Ubuntu2204')]
    [string]$OS = 'Win2019Datacenter',
    [pscredential]$Credential,
    [string]$AutoShutdownTime = '1500',
    [switch]$NoAutoShutdown,
    [string]$SshKeyPath,
    [switch]$InstallXrdp
)
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'Simplest.Common.ps1')
$null = Assert-AzLogin
Assert-ResourceProviders $RequiredProviders

$img = Get-VmImageSpec $OS
if ($InstallXrdp -and -not $img.IsLinux) { throw '-InstallXrdp は Linux（Ubuntu2204）でのみ使えます。' }
$cred = Get-CredentialIfNull $Credential "VM '$VmName' の管理者ユーザー名とパスワード"
$sshKey = if ($img.IsLinux) { New-LocalSshKey $VmName $SshKeyPath } else { $null }

Initialize-ResourceGroup $ResourceGroupName $Location

$vnet = Get-AzVirtualNetwork -ResourceGroupName $ResourceGroupName -Name $VnetName -ErrorAction SilentlyContinue
if ($vnet) {
    Say "  VNet '$VnetName' は既に存在します（スキップ）" -Color DarkGray
}
else {
    Say "  VNet '$VnetName' を作成します" -Color Cyan
    $subnet = New-AzVirtualNetworkSubnetConfig -Name $SubnetName -AddressPrefix '10.1.0.0/24'
    $null = New-AzVirtualNetwork -ResourceGroupName $ResourceGroupName -Name $VnetName `
        -Location $Location -AddressPrefix '10.1.0.0/16' -Subnet $subnet
}

if ($sshKey) { Register-VmSshKey $ResourceGroupName $VmName $sshKey.PublicKey }
New-PrivateVM -ResourceGroupName $ResourceGroupName -Location $Location -VmName $VmName -VmSize $VmSize `
    -OS $OS -Credential $cred -VnetName $VnetName -SubnetName $SubnetName -SshPublicKey $sshKey.PublicKey

if ($InstallXrdp) { Install-Xrdp $ResourceGroupName $VmName $cred }

if (-not $NoAutoShutdown) {
    Set-VmAutoShutdown -ResourceGroupName $ResourceGroupName -VmName $VmName -Location $Location -Time $AutoShutdownTime
}

Say ''
Say 'Public IP 一覧:' -Color Cyan
Get-AzPublicIpAddress | Format-Table Name, ResourceGroupName, IpAddress, @{ n = 'Sku'; e = { $_.Sku.Name } } -AutoSize | Out-Host

Say "完了: サンドボックス VM '$VmName' を作成しました。" -Color Green
