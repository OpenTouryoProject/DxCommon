<#
.SYNOPSIS
    既存の VM に Public IP を付ける（NSG が無ければ作って関連付け、送信元を絞ってポートを開けることもできる）。

.DESCRIPTION
    1. Public IP（Standard / 静的）を作り、VM の 1 つ目の NIC に付ける。
    2. NIC に NSG が付いていなければ、<VmName>NSG を作って関連付ける（ルールは空。受信は、何も許可しない）。
    3. -OpenPort を指定すると、Open-VMPort.ps1 で、そのポートを開ける。**送信元の IP 制限は必須**
       （-SourceAddressPrefix か -MyIp。* / Internet / 0.0.0.0/0 は拒否する）。
    Standard の Public IP は、NSG で許可しない限り、受信できない。
    Public IP は、存在する間、課金される（小額）。不要になったら Remove-VMPublicIp.ps1 で外して削除する。
    VM は、起動していても停止していてもよい。

.PARAMETER Sku
    Public IP の SKU。Standard のみ（Basic は 2025-09-30 に廃止）。

.PARAMETER DomainNameLabel
    Public IP に付ける DNS 名のラベル（<ラベル>.<リージョン>.cloudapp.azure.com）。Entra ID の RDP ログインには FQDN が必要。
    リージョン内で一意。省略すると、DNS 名は付けない。

.PARAMETER OpenPort
    開けるポート（既定なし）。例: 3389（RDP）。

.EXAMPLE
    .\Add-VMPublicIp.ps1 -ResourceGroupName AzureBastionRG -VmName WorkVM2 -OpenPort 3389 -MyIp
#>
[CmdletBinding()]
param(
    [string]$ResourceGroupName = 'hogeRG',
    [string]$VmName = 'hogeVM',
    [string]$PublicIpName,
    [ValidateSet('Standard')][string]$Sku = 'Standard',
    [string]$DomainNameLabel,
    [int]$OpenPort,
    [string]$SourceAddressPrefix,
    [switch]$MyIp
)
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'SingleVM.Common.ps1')
$null = Assert-AzLogin
Assert-ResourceProviders $RequiredProviders

$vm = Get-AzVM -ResourceGroupName $ResourceGroupName -Name $VmName
if (-not $PublicIpName) { $PublicIpName = "${VmName}PublicIP" }

# ポートを開けるときは、先に送信元を確認する（何も作る前に止める）
$source = $null
if ($OpenPort) {
    $source = Resolve-SourcePrefix $SourceAddressPrefix -MyIp:$MyIp -Required
}

$nic = Get-VmNic $vm
if ($nic.IpConfigurations[0].PublicIpAddress.Id) {
    $r = Split-ResourceId $nic.IpConfigurations[0].PublicIpAddress.Id
    Say "  この VM には、既に Public IP '$($r.Name)' が付いています（スキップ）" -Color DarkGray
}
else {
    $pip = Get-AzPublicIpAddress -ResourceGroupName $ResourceGroupName -Name $PublicIpName -ErrorAction SilentlyContinue
    if (-not $pip) {
        Say "  Public IP '$PublicIpName' を作成します（$Sku / 静的）" -Color Cyan
        $pip = New-AzPublicIpAddress -ResourceGroupName $ResourceGroupName -Name $PublicIpName `
            -Location $vm.Location -Sku $Sku -AllocationMethod Static
    }
    $nic.IpConfigurations[0].PublicIpAddress = $pip
    Say "  NIC '$($nic.Name)' に Public IP を付けます" -Color Cyan
    $null = Set-AzNetworkInterface -NetworkInterface $nic
}

if ($DomainNameLabel) { $null = Set-VmPublicDnsLabel (Get-AzVM -ResourceGroupName $ResourceGroupName -Name $VmName) $DomainNameLabel }

# NSG
$nic = Get-VmNic $vm
if (-not $nic.NetworkSecurityGroup) {
    $nsgName = "${VmName}NSG"
    $nsg = Get-AzNetworkSecurityGroup -ResourceGroupName $ResourceGroupName -Name $nsgName -ErrorAction SilentlyContinue
    if (-not $nsg) {
        Say "  NSG '$nsgName' を作成します（ルールなし）" -Color Cyan
        $nsg = New-AzNetworkSecurityGroup -ResourceGroupName $ResourceGroupName -Name $nsgName -Location $vm.Location
    }
    $nic.NetworkSecurityGroup = $nsg
    Say "  NIC に NSG '$nsgName' を関連付けます" -Color Cyan
    $null = Set-AzNetworkInterface -NetworkInterface $nic
}
else {
    Say '  NIC には、既に NSG が付いています（スキップ）' -Color DarkGray
}

if ($OpenPort) {
    & (Join-Path $PSScriptRoot 'Open-VMPort.ps1') -ResourceGroupName $ResourceGroupName -VmName $VmName -Port $OpenPort -SourceAddressPrefix $source
}

$ip = Get-VmPublicIp (Get-AzVM -ResourceGroupName $ResourceGroupName -Name $VmName)
Say ''
Say "完了: VM '$VmName' のパブリック IP: $ip" -Color Green
if (-not $OpenPort) { Say '  受信は何も許可していません。Open-VMPort.ps1 で、送信元を絞って開けてください。' -Color DarkGray }
# Entra ID ログインを入れた Windows VM なら、接続先（コンピューター名）と、hosts に足すコマンドを表示する
$vmNow = Get-AzVM -ResourceGroupName $ResourceGroupName -Name $VmName
if (-not (Test-VmIsLinux $vmNow) -and (Get-AzVMExtension -ResourceGroupName $ResourceGroupName -VMName $VmName -Name 'AADLoginForWindows' -ErrorAction SilentlyContinue)) {
    Show-EntraHostsHint $vmNow $ip
}
