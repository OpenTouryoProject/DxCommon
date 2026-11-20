<#
.SYNOPSIS
    VM の NSG に、受信ポートを開けるルールを追加する。

.DESCRIPTION
    Research の「az vm open-port」（Linux の xrdp 用に 3389 を開ける）に相当する。
    VM の 1 つ目の NIC に付いた NSG に、Allow ルールを追加する。優先度は空いている最小値（1000 から 10 刻み）を使う。

.PARAMETER SourceAddressPrefix
    許可する送信元。既定は * （全許可）。可能なら自分の IP などに絞ること。

.EXAMPLE
    .\Open-VMPort.ps1 -ResourceGroupName hogeRG -VmName hogeVM -Port 3389 -SourceAddressPrefix 203.0.113.10
#>
[CmdletBinding()]
param(
    [string]$ResourceGroupName = 'hogeRG',
    [string]$VmName = 'hogeVM',
    [int]$Port = 3389,
    [string]$SourceAddressPrefix = '*'
)
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'SingleVM.Common.ps1')
$null = Assert-AzLogin

$vm = Get-AzVM -ResourceGroupName $ResourceGroupName -Name $VmName
$nic = Get-VmNic $vm
if (-not $nic.NetworkSecurityGroup) { throw "NIC '$($nic.Name)' に NSG が関連付けられていません。" }
$r = Split-ResourceId $nic.NetworkSecurityGroup.Id
$nsg = Get-AzNetworkSecurityGroup -ResourceGroupName $r.ResourceGroupName -Name $r.Name

$ruleName = "open-port-$Port"
if ($nsg.SecurityRules | Where-Object { $_.Name -eq $ruleName }) {
    Say "  ルール '$ruleName' は既に存在します（スキップ）" -Color DarkGray
    return
}

$used = @($nsg.SecurityRules | ForEach-Object { $_.Priority })
$priority = 1000
while ($used -contains $priority) { $priority += 10 }

Say "  NSG '$($nsg.Name)' にポート $Port（優先度 $priority / 送信元 $SourceAddressPrefix）を許可するルールを追加します" -Color Cyan
$null = Add-AzNetworkSecurityRuleConfig -NetworkSecurityGroup $nsg -Name $ruleName -Protocol Tcp -Direction Inbound `
    -Priority $priority -SourceAddressPrefix $SourceAddressPrefix -SourcePortRange '*' `
    -DestinationAddressPrefix '*' -DestinationPortRange $Port -Access Allow
$null = Set-AzNetworkSecurityGroup -NetworkSecurityGroup $nsg

Say 'WARNING: 送信元が * の場合、インターネット全体からのアクセスを許可します。' -Color Yellow
Say "完了: ポート $Port を開けました。" -Color Green
