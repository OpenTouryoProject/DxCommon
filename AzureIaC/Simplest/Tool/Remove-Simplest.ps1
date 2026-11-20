<#
.SYNOPSIS
    リソースグループ（Bastion 用 / サンドボックス用）を、中身ごと削除する。

.DESCRIPTION
    削除前に、中身のリソースと VNet ピアリングを表示して確認する（-Force で確認を省略）。
    他の VNet から、このリソースグループの VNet へ張られたピアリングは、先に削除する
    （残すと相手側が Disconnected のまま残るため）。
    Bastion や VM は課金されるため、使わないときの片付けに使う。元に戻せない。

.EXAMPLE
    .\Remove-Simplest.ps1 -ResourceGroupName YourRG
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$ResourceGroupName,
    [switch]$Force
)
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'Simplest.Common.ps1')
$null = Assert-AzLogin

if (-not (Get-AzResourceGroup -Name $ResourceGroupName -ErrorAction SilentlyContinue)) {
    Say "リソースグループ '$ResourceGroupName' は存在しません。" -Color Yellow
    return
}

Say "削除対象: リソースグループ '$ResourceGroupName'" -Color Cyan
$resources = @(Get-AzResource -ResourceGroupName $ResourceGroupName)
if ($resources.Count -eq 0) { Say '  （中身は空です）' -Color DarkGray }
else { $resources | Format-Table Name, ResourceType -AutoSize | Out-Host }

# この RG の VNet に張られているピアリング（相手側の削除対象も含めて洗い出す）
$remotePeerings = @()
foreach ($vnet in (Get-AzVirtualNetwork -ResourceGroupName $ResourceGroupName)) {
    foreach ($p in (Get-AzVirtualNetworkPeering -VirtualNetworkName $vnet.Name -ResourceGroupName $ResourceGroupName)) {
        Say ("  ピアリング: {0} ({1}) → {2}" -f $p.Name, $vnet.Name, $p.RemoteVirtualNetwork.Id) -Color DarkGray
        $r = Split-ResourceId $p.RemoteVirtualNetwork.Id
        if ($r.ResourceGroupName -ne $ResourceGroupName) {
            $remotePeerings += @{ Vnet = $r.Name; ResourceGroupName = $r.ResourceGroupName; LocalVnetId = $vnet.Id }
        }
    }
}

if (-not (Confirm-Action "リソースグループ '$ResourceGroupName' を、中身ごと削除しますか（元に戻せません）" -Force:$Force)) {
    Say 'キャンセルしました。' -Color Yellow
    return
}

foreach ($rp in $remotePeerings) {
    try {
        Get-AzVirtualNetworkPeering -VirtualNetworkName $rp.Vnet -ResourceGroupName $rp.ResourceGroupName |
            Where-Object { $_.RemoteVirtualNetwork.Id -eq $rp.LocalVnetId } |
            ForEach-Object {
                Say ("  相手側のピアリング '{0}'（{1}/{2}）を削除します" -f $_.Name, $rp.ResourceGroupName, $rp.Vnet) -Color Cyan
                $null = Remove-AzVirtualNetworkPeering -Name $_.Name -VirtualNetworkName $rp.Vnet -ResourceGroupName $rp.ResourceGroupName -Force
            }
    }
    catch { Say ("  相手側のピアリング削除に失敗（続行します）: {0}" -f $_.Exception.Message) -Color Yellow }
}

Say "  リソースグループ '$ResourceGroupName' を削除します（Bastion があると数分かかります）" -Color Cyan
$null = Remove-AzResourceGroup -Name $ResourceGroupName -Force
Say "完了: '$ResourceGroupName' を削除しました。" -Color Green
