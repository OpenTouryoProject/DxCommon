<#
.SYNOPSIS
    Azure Bastion（RG / VNet / Public IP / Bastion / Jumpbox 用サブネット）を作成する。

.DESCRIPTION
    Research の 1.common.sh を Azure PowerShell に置き換えたもの。
    -BastionSku で SKU を選べる（Developer: 無料。開発・テスト向けで、共有インフラを使うため専用サブネットも Public IP も不要。
    同時接続は 1 つ、VNet ピアリング越しの接続や一部機能に制限がある。作成は数分。Az の New-AzBastion が未対応のため REST で作る。
    Basic: 最小構成 / Standard: ホスト スケーリング、ファイル転送、IP ベース接続など。料金は Standard の方が高い）。
    既に存在するリソースは作成せずスキップする。Bastion の作成には 10 分前後かかり、課金が発生する。

.EXAMPLE
    .\New-Bastion.ps1
#>
[CmdletBinding()]
param(
    [string]$Location = 'japaneast',
    [string]$ResourceGroupName = 'AzureBastionRG',
    [string]$BastionName = 'AzureBastion',
    [string]$VnetName = 'AzureBastionVnet',
    [string]$BastionSubnetName = 'AzureBastionSubnet',   # Bastion 用は、この名前固定
    [string]$JumpboxSubnetName = 'JumpboxSubnet',
    [string]$PublicIpName = 'AzureBastionPubIP',
    [ValidateSet('Developer', 'Basic', 'Standard')][string]$BastionSku = 'Developer'
)
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'Simplest.Common.ps1')
$null = Assert-AzLogin
Assert-ResourceProviders $RequiredProviders

Initialize-ResourceGroup $ResourceGroupName $Location

# VNet（Bastion 用サブネット）
$vnet = Get-AzVirtualNetwork -ResourceGroupName $ResourceGroupName -Name $VnetName -ErrorAction SilentlyContinue
if ($vnet) {
    Say "  VNet '$VnetName' は既に存在します（スキップ）" -Color DarkGray
}
else {
    Say "  VNet '$VnetName' を作成します" -Color Cyan
    $bastionSubnet = New-AzVirtualNetworkSubnetConfig -Name $BastionSubnetName -AddressPrefix '10.0.0.0/24'
    $vnet = New-AzVirtualNetwork -ResourceGroupName $ResourceGroupName -Name $VnetName `
        -Location $Location -AddressPrefix '10.0.0.0/16' -Subnet $bastionSubnet
}

# Public IP（Developer は不要）
$pip = Get-AzPublicIpAddress -ResourceGroupName $ResourceGroupName -Name $PublicIpName -ErrorAction SilentlyContinue
if ($BastionSku -eq 'Developer') {
    Say '  Developer SKU は Public IP が不要です（スキップ）' -Color DarkGray
}
elseif ($pip) {
    Say "  Public IP '$PublicIpName' は既に存在します（スキップ）" -Color DarkGray
}
else {
    Say "  Public IP '$PublicIpName' を作成します" -Color Cyan
    $pip = New-AzPublicIpAddress -ResourceGroupName $ResourceGroupName -Name $PublicIpName `
        -Location $Location -Sku Standard -AllocationMethod Static
}

# Bastion
$bastion = Get-AzBastion -ResourceGroupName $ResourceGroupName -Name $BastionName -ErrorAction SilentlyContinue
if ($bastion) {
    Say "  Bastion '$BastionName' は既に存在します（スキップ）" -Color DarkGray
}
else {
    if ($BastionSku -eq 'Developer') {
        Say "  Bastion '$BastionName' を作成します（SKU: Developer、無料。REST で作成）" -Color Cyan
        $body = @{
            location   = $Location
            sku        = @{ name = 'Developer' }
            properties = @{ virtualNetwork = @{ id = $vnet.Id } }
        } | ConvertTo-Json -Depth 5 -Compress
        $path = "/subscriptions/{0}/resourceGroups/{1}/providers/Microsoft.Network/bastionHosts/{2}?api-version=2024-05-01" -f (Get-AzContext).Subscription.Id, $ResourceGroupName, $BastionName
        $r = Invoke-AzRestMethod -Method PUT -Path $path -Payload $body
        if ($r.StatusCode -ge 300) {
            $msg = try { ($r.Content | ConvertFrom-Json).error.message } catch { $r.Content }
            throw ("Developer SKU の Bastion を作成できません（HTTP {0}）: {1}" -f $r.StatusCode, $msg)
        }
        $deadline = (Get-Date).AddMinutes(15)
        do {
            Start-Sleep -Seconds 15
            $bastion = Get-AzBastion -ResourceGroupName $ResourceGroupName -Name $BastionName -ErrorAction SilentlyContinue
            Say ("    状態: {0}" -f $bastion.ProvisioningState) -Color DarkGray
        } while ($bastion.ProvisioningState -notin 'Succeeded', 'Failed' -and (Get-Date) -lt $deadline)
        if ($bastion.ProvisioningState -ne 'Succeeded') { throw "Bastion の作成が完了しませんでした（状態: $($bastion.ProvisioningState)）。" }
    }
    else {
        Say "  Bastion '$BastionName' を作成します（SKU: $BastionSku、10 分前後かかります）" -Color Cyan
        $null = New-AzBastion -ResourceGroupName $ResourceGroupName -Name $BastionName `
            -PublicIpAddress $pip -VirtualNetwork $vnet -Sku $BastionSku
    }
}

# Jumpbox 用サブネット
$vnet = Get-AzVirtualNetwork -ResourceGroupName $ResourceGroupName -Name $VnetName
if ($vnet.Subnets | Where-Object { $_.Name -eq $JumpboxSubnetName }) {
    Say "  サブネット '$JumpboxSubnetName' は既に存在します（スキップ）" -Color DarkGray
}
else {
    Say "  サブネット '$JumpboxSubnetName' を作成します" -Color Cyan
    $null = Add-AzVirtualNetworkSubnetConfig -VirtualNetwork $vnet -Name $JumpboxSubnetName -AddressPrefix '10.0.1.0/24'
    $null = Set-AzVirtualNetwork -VirtualNetwork $vnet
}

Say '完了: Bastion 環境を作成しました。' -Color Green
