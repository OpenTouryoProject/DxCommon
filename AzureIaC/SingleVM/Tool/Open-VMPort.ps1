<#
.SYNOPSIS
    VM の NSG に、受信ポートを開けるルールを追加する（送信元の IP 制限つき）。

.DESCRIPTION
    Research の「az vm open-port」（Linux の xrdp 用に 3389 を開ける）に相当する。
    VM の 1 つ目の NIC に付いた NSG に、Allow ルールを追加する。優先度は空いている最小値（1000 から 10 刻み）を使う。

    送信元の IP 制限は、次の場合に必須（* / Internet / 0.0.0.0/0 は拒否する）。
      - Windows VM（RDP など）
      - ポート 3389（Linux の xrdp を含む）
    Linux VM の、3389 以外のポート（22 / 80 / 443 など）は、制限なし（*）でも開けられる（警告を出す）。
    自分の IP が変わったときは、Update-VMAllowedIp.ps1 で送信元を更新する。

.PARAMETER SourceAddressPrefix
    許可する送信元（IP / CIDR）。

.PARAMETER MyIp
    自分の現在のグローバル IP を、送信元にする（外部サービス api.ipify.org に問い合わせて調べる）。

.EXAMPLE
    .\Open-VMPort.ps1 -ResourceGroupName hogeRG -VmName hogeVM -Port 3389 -MyIp
    .\Open-VMPort.ps1 -ResourceGroupName hogeRG -VmName hogeVM -Port 3389 -SourceAddressPrefix 203.0.113.10
#>
[CmdletBinding()]
param(
    [string]$ResourceGroupName = 'hogeRG',
    [string]$VmName = 'hogeVM',
    [int]$Port = 3389,
    [string]$SourceAddressPrefix,
    [switch]$MyIp
)
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'SingleVM.Common.ps1')
$null = Assert-AzLogin

$vm = Get-AzVM -ResourceGroupName $ResourceGroupName -Name $VmName
$required = (-not (Test-VmIsLinux $vm)) -or $Port -eq 3389
$source = Resolve-SourcePrefix $SourceAddressPrefix -MyIp:$MyIp -Required:$required
$nsg = Get-VmNsg $vm

$ruleName = "open-port-$Port"
if ($nsg.SecurityRules | Where-Object { $_.Name -eq $ruleName }) {
    Say "  ルール '$ruleName' は既に存在します（スキップ）。送信元を変えるときは Update-VMAllowedIp.ps1 を使ってください。" -Color DarkGray
    return
}

$used = @($nsg.SecurityRules | ForEach-Object { $_.Priority })
$priority = 1000
while ($used -contains $priority) { $priority += 10 }

Say "  NSG '$($nsg.Name)' にポート $Port（優先度 $priority / 送信元 $source）を許可するルールを追加します" -Color Cyan
$null = Add-AzNetworkSecurityRuleConfig -NetworkSecurityGroup $nsg -Name $ruleName -Protocol Tcp -Direction Inbound `
    -Priority $priority -SourceAddressPrefix $source -SourcePortRange '*' `
    -DestinationAddressPrefix '*' -DestinationPortRange $Port -Access Allow
$null = Set-AzNetworkSecurityGroup -NetworkSecurityGroup $nsg

if ($source -in '*', 'Internet', 'Any', '0.0.0.0/0', '::/0') {
    Say 'WARNING: 送信元が全許可です。インターネット全体からのアクセスを許可します。' -Color Yellow
}
Say "完了: ポート $Port を開けました（送信元: $source）。" -Color Green
