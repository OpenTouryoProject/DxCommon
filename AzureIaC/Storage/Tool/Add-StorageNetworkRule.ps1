<#
.SYNOPSIS
    ストレージアカウントのネットワークルールに、許可する IP アドレス（範囲）を追加する。

.DESCRIPTION
    Research の「Add as needed」（az storage account network-rule add）に相当する。
    追加後、現在のルール一覧を表示する。
    ※ 既定のアクション（DefaultAction）が Allow のままだと、IP ルールを追加しても制限にはならない。

.EXAMPLE
    .\Add-StorageNetworkRule.ps1 -IpAddress 203.0.113.10
#>
[CmdletBinding()]
param(
    [string]$ResourceGroupName = 'DxCmnRG',
    [string]$StorageAccountName = 'osscjpdevinfra',
    [Parameter(Mandatory)]
    [string]$IpAddress
)
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'Storage.Common.ps1')
$null = Assert-AzLogin

Say "  IP '$IpAddress' を '$StorageAccountName' のネットワークルールに追加します" -Color Cyan
$null = Add-AzStorageAccountNetworkRule -ResourceGroupName $ResourceGroupName -Name $StorageAccountName -IPAddressOrRange $IpAddress

$rules = Get-AzStorageAccountNetworkRuleSet -ResourceGroupName $ResourceGroupName -Name $StorageAccountName
Say ("  DefaultAction: {0}" -f $rules.DefaultAction) -Color DarkGray
$rules.IpRules | Format-Table IPAddressOrRange, Action -AutoSize | Out-Host
Say '完了。' -Color Green
