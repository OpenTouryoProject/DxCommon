<#
.SYNOPSIS
    指定リージョンで使える VM サイズ、または利用できるイメージを表示する（読み取り専用）。

.DESCRIPTION
    Research の Define2（az vm list-sizes / az vm image list）に相当する。
      Sizes  : Get-AzVMSize の一覧（Core 数・メモリ）。
      Images : このツールが対応するイメージ（New-SingleVM の -OS）の一覧。
               -Publisher を指定すると Offer 一覧、-Publisher と -Offer を指定すると SKU 一覧を表示する。

.EXAMPLE
    .\Show-VMCatalog.ps1 -Kind Sizes
    .\Show-VMCatalog.ps1 -Kind Images -Publisher Canonical -Offer 0001-com-ubuntu-server-jammy
#>
[CmdletBinding()]
param(
    [string]$Location = 'japaneast',
    [ValidateSet('Sizes', 'Images')]
    [string]$Kind = 'Sizes',
    [string]$Publisher,
    [string]$Offer
)
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'SingleVM.Common.ps1')
$null = Assert-AzLogin

if ($Kind -eq 'Sizes') {
    Get-AzVMSize -Location $Location | Sort-Object NumberOfCores, MemoryInMB |
        Format-Table Name, NumberOfCores, MemoryInMB -AutoSize | Out-Host
    return
}

if ($Publisher -and $Offer) {
    Get-AzVMImageSku -Location $Location -PublisherName $Publisher -Offer $Offer | Format-Table Skus, Location -AutoSize | Out-Host
}
elseif ($Publisher) {
    Get-AzVMImageOffer -Location $Location -PublisherName $Publisher | Format-Table Offer, Location -AutoSize | Out-Host
}
else {
    Say 'New-SingleVM.ps1 の -OS で指定できるイメージ:' -Color Cyan
    foreach ($k in $VmImages.Keys) {
        $i = $VmImages[$k]
        Say ("  {0,-18} {1} / {2} / {3}" -f $k, $i.Publisher, $i.Offer, $i.Sku)
    }
}
