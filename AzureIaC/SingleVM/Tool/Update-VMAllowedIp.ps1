<#
.SYNOPSIS
    VM の NSG で、指定ポートを許可している受信ルールの送信元 IP を更新する。

.DESCRIPTION
    自分のグローバル IP が変わったときに、開けてあるポート（既定 3389）の許可元を、新しい IP に付け替える。
    VM の 1 つ目の NIC に付いた NSG の、Inbound / Allow で、指定ポートを含むルール（open-port-<ポート> や Allow-RDP など）が対象。
    送信元は、必ず IP / CIDR に絞る（* / Internet / 0.0.0.0/0 は拒否する）。
    ルールが 1 つも無いときは何もしない（先に Open-VMPort.ps1 で開ける）。

.PARAMETER SourceAddressPrefix
    新しい送信元（IP / CIDR）。

.PARAMETER MyIp
    自分の現在のグローバル IP を、新しい送信元にする（外部サービス api.ipify.org に問い合わせて調べる）。

.EXAMPLE
    .\Update-VMAllowedIp.ps1 -ResourceGroupName hogeRG -VmName hogeVM -MyIp
    .\Update-VMAllowedIp.ps1 -ResourceGroupName hogeRG -VmName hogeVM -Port 22 -SourceAddressPrefix 203.0.113.0/24
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

$source = Resolve-SourcePrefix $SourceAddressPrefix -MyIp:$MyIp -Required
$vm = Get-AzVM -ResourceGroupName $ResourceGroupName -Name $VmName
$nsg = Get-VmNsg $vm

# 指定ポートを含む、受信許可ルール（'80', '1000-2000', '*' の指定を解釈する）
function Test-PortIn([string[]]$Ranges, [int]$P) {
    foreach ($r in $Ranges) {
        if ($r -eq '*') { return $true }
        if ($r -match '^(\d+)-(\d+)$') { if ($P -ge [int]$Matches[1] -and $P -le [int]$Matches[2]) { return $true } }
        elseif ($r -match '^\d+$') { if ($P -eq [int]$r) { return $true } }
    }
    return $false
}
$targets = @($nsg.SecurityRules | Where-Object {
        $_.Direction -eq 'Inbound' -and $_.Access -eq 'Allow' -and (Test-PortIn @($_.DestinationPortRange) $Port)
    })
if ($targets.Count -eq 0) {
    Say "  ポート $Port を許可する受信ルールが NSG '$($nsg.Name)' にありません。先に Open-VMPort.ps1 で開けてください。" -Color Yellow
    return
}

$changed = 0
foreach ($rule in $targets) {
    $old = $rule.SourceAddressPrefix -join ','
    if ($old -eq $source) {
        Say ("  ルール '{0}': 既に {1} です（変更なし）" -f $rule.Name, $source) -Color DarkGray
        continue
    }
    Say ("  ルール '{0}': {1} → {2}" -f $rule.Name, $old, $source) -Color Cyan
    $null = Set-AzNetworkSecurityRuleConfig -NetworkSecurityGroup $nsg -Name $rule.Name -Protocol $rule.Protocol `
        -Direction $rule.Direction -Priority $rule.Priority -SourceAddressPrefix $source `
        -SourcePortRange $rule.SourcePortRange -DestinationAddressPrefix $rule.DestinationAddressPrefix `
        -DestinationPortRange $rule.DestinationPortRange -Access $rule.Access
    $changed++
}
if ($changed -gt 0) { $null = Set-AzNetworkSecurityGroup -NetworkSecurityGroup $nsg }
Say "完了: $changed 件のルールを更新しました。" -Color Green
