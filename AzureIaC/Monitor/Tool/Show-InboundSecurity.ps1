<#
.SYNOPSIS
    インバウンド（受信）まわりのセキュリティ状況を一覧表示する（読み取り専用）。

.DESCRIPTION
    サブスクリプション内（または指定したリソースグループ内）の、外部から入ってこられる口を調べて表示する。
      1. NSG の受信許可ルール   : 送信元がインターネット（*, Internet, 0.0.0.0/0）で、
                                  RDP/SSH/DB などの危険なポートに届くものを [危険] とする。
      2. NSG の関連付け        : どのサブネット / NIC に適用されているか（未関連付けの NSG は効いていない）。
      3. パブリック IP         : 割り当て先（VM / Bastion / ロードバランサーなど）。
      4. ストレージアカウント   : 既定のアクション、BLOB の匿名アクセス、IP ルール、HTTPS / TLS。
    何も変更しない。Azure の既定ルール（65000 番台）は表示しない。

.PARAMETER ResourceGroupName
    調べる範囲をリソースグループに絞る。省略するとサブスクリプション全体。

.PARAMETER ShowAll
    危険でない受信許可ルールも表示する（既定は [危険] と [注意] のみ）。

.EXAMPLE
    .\Show-InboundSecurity.ps1
    .\Show-InboundSecurity.ps1 -ResourceGroupName YourRG -ShowAll
#>
[CmdletBinding()]
param(
    [string]$ResourceGroupName,
    [switch]$ShowAll
)
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'Monitor.Common.ps1')
$ctx = Assert-AzLogin

# 公開とみなす送信元
$AnySources = @('*', 'Internet', 'Any', '0.0.0.0/0', '::/0')
# 危険なポート（番号 = 用途）
$RiskyPorts = [ordered]@{
    21 = 'FTP'; 22 = 'SSH'; 23 = 'Telnet'; 445 = 'SMB'; 1433 = 'SQL Server'; 3306 = 'MySQL'
    3389 = 'RDP'; 5432 = 'PostgreSQL'; 5985 = 'WinRM'; 5986 = 'WinRM(S)'; 6379 = 'Redis'; 27017 = 'MongoDB'
}

# ポート指定（'80', '1000-2000', '*'）の配列に、ポートが含まれるか。
function Test-PortIn([string[]]$Ranges, [int]$Port) {
    foreach ($r in $Ranges) {
        if ($r -eq '*') { return $true }
        if ($r -match '^(\d+)-(\d+)$') { if ($Port -ge [int]$Matches[1] -and $Port -le [int]$Matches[2]) { return $true } }
        elseif ($r -match '^\d+$') { if ($Port -eq [int]$r) { return $true } }
    }
    return $false
}

function Get-ShortName([string]$Id) { if ($Id) { ($Id -split '/')[-1] } else { '' } }

$rgFilter = @{}
if ($ResourceGroupName) { $rgFilter.ResourceGroupName = $ResourceGroupName }
$scope = if ($ResourceGroupName) { "リソースグループ $ResourceGroupName" } else { 'サブスクリプション全体' }
Say ("対象: {0} / {1}" -f $ctx.Subscription.Name, $scope) -Color DarkGray

# ------------------------------------------------------------------ 1. NSG 受信許可ルール
Say ''
Say '[1] NSG の受信許可ルール' -Color Cyan
$nsgs = @(Get-AzNetworkSecurityGroup @rgFilter)
$findings = @()
foreach ($nsg in $nsgs) {
    foreach ($rule in $nsg.SecurityRules) {
        if ($rule.Direction -ne 'Inbound' -or $rule.Access -ne 'Allow') { continue }
        $open = @($rule.SourceAddressPrefix | Where-Object { $_ -in $AnySources }).Count -gt 0
        $ports = @($rule.DestinationPortRange)
        $hit = @($RiskyPorts.Keys | Where-Object { Test-PortIn $ports $_ } | ForEach-Object { "$_($($RiskyPorts[$_]))" })
        $allPorts = $ports -contains '*'
        $level = if ($open -and $hit.Count -gt 0) { '危険' } elseif ($open) { '注意' } else { '' }
        if ($level -eq '' -and -not $ShowAll) { continue }
        $findings += [pscustomobject]@{
            判定 = if ($level) { $level } else { '-' }
            NSG = $nsg.Name; RG = $nsg.ResourceGroupName; ルール = $rule.Name; 優先度 = $rule.Priority
            プロトコル = $rule.Protocol; 送信元 = ($rule.SourceAddressPrefix -join ','); 宛先ポート = ($ports -join ',')
            危険ポート = if ($allPorts) { '全ポート' } else { $hit -join ' ' }
        }
    }
}
if ($findings.Count -eq 0) {
    Say '  該当するルールはありません。' -Color Green
}
else {
    $order = @{ '危険' = 0; '注意' = 1; '-' = 2 }
    $findings = $findings | Sort-Object { $order[$_.判定] }, NSG, 優先度
    $findings | Format-Table -AutoSize | Out-Host
    $danger = @($findings | Where-Object { $_.判定 -eq '危険' }).Count
    if ($danger -gt 0) {
        Say ("  [危険] {0} 件: インターネット全体から、RDP / SSH / DB などに届くルールです。送信元を自分の IP / CIDR に絞るか、Bastion 経由にしてください。" -f $danger) -Color Red
    }
}
Say ("  （NSG {0} 件を調べました）" -f $nsgs.Count) -Color DarkGray

# ------------------------------------------------------------------ 2. NSG の関連付け
Say ''
Say '[2] NSG の関連付け（未関連付けの NSG は、どこにも効いていません）' -Color Cyan
if ($nsgs.Count -eq 0) { Say '  NSG がありません。' -Color DarkGray }
else {
    $nsgs | ForEach-Object {
        $subnets = @($_.Subnets | ForEach-Object { (($_.Id -split '/')[8] + '/' + (Get-ShortName $_.Id)) })
        $nics = @($_.NetworkInterfaces | ForEach-Object { Get-ShortName $_.Id })
        [pscustomobject]@{
            NSG = $_.Name; RG = $_.ResourceGroupName
            サブネット = ($subnets -join ', '); NIC = ($nics -join ', ')
            状態 = if ($subnets.Count + $nics.Count -eq 0) { '未関連付け' } else { '適用中' }
        }
    } | Format-Table -AutoSize | Out-Host
}

# ------------------------------------------------------------------ 3. パブリック IP
Say '[3] パブリック IP' -Color Cyan
$pips = @(Get-AzPublicIpAddress @rgFilter)
if ($pips.Count -eq 0) { Say '  パブリック IP はありません。' -Color Green }
else {
    $pips | ForEach-Object {
        $attached = if ($_.IpConfiguration.Id) {
            $p = $_.IpConfiguration.Id -split '/'
            "{0}: {1}" -f $p[7], $p[8]
        } else { '（未使用）' }
        [pscustomobject]@{
            名前 = $_.Name; RG = $_.ResourceGroupName; IP = $_.IpAddress
            SKU = $_.Sku.Name; 割り当て = $_.PublicIpAllocationMethod; 割り当て先 = $attached
        }
    } | Format-Table -AutoSize | Out-Host
}

# ------------------------------------------------------------------ 4. ストレージアカウント
Say '[4] ストレージアカウントの公開設定' -Color Cyan
$sas = @(Get-AzStorageAccount @rgFilter)
if ($sas.Count -eq 0) { Say '  ストレージアカウントはありません。' -Color DarkGray }
else {
    $sas | ForEach-Object {
        $rules = Get-AzStorageAccountNetworkRuleSet -ResourceGroupName $_.ResourceGroupName -Name $_.StorageAccountName
        $anon = $_.AllowBlobPublicAccess
        $judge = @()
        if ($rules.DefaultAction -eq 'Allow') { $judge += '全許可' }
        if ($anon) { $judge += '匿名可' }
        if (-not $_.EnableHttpsTrafficOnly) { $judge += 'HTTP可' }
        if ($_.MinimumTlsVersion -in 'TLS1_0', 'TLS1_1') { $judge += '古いTLS' }
        [pscustomobject]@{
            名前 = $_.StorageAccountName; RG = $_.ResourceGroupName
            既定アクション = $rules.DefaultAction; 公開ネットワーク = $(if ($_.PublicNetworkAccess) { $_.PublicNetworkAccess } else { '(既定)' })
            匿名アクセス = $anon; HTTPSのみ = $_.EnableHttpsTrafficOnly; 最小TLS = $_.MinimumTlsVersion
            IPルール = (@($rules.IpRules | ForEach-Object { $_.IPAddressOrRange }) -join ', ')
            判定 = if ($judge.Count) { '注意: ' + ($judge -join '/') } else { 'OK' }
        }
    } | Format-Table -AutoSize | Out-Host
    Say '  ※ 既定アクションが Allow の間は、IP ルールを追加してもアクセスは制限されません。' -Color DarkGray
}

Say ''
Say '完了。' -Color Green
