<#
.SYNOPSIS
    ストレージアカウントのコンテナーにある、BLOB（格納物）を一覧表示する（読み取り専用、Entra ID 認証）。

.DESCRIPTION
    コンテナーを省略すると、すべてのコンテナーの BLOB を表示する。-Prefix で、BLOB 名の先頭を絞る（例: windows-server-2025/）。
    表示するのは、BLOB 名、サイズ、更新日時、アクセス層。最後に、件数と合計サイズを出す。
    認証は、ストレージ キーでなく、Entra ID（Storage Blob Data Reader 以上のロールが必要）。
    何も変更しない。アップロードは Send-StorageFile.ps1。

.PARAMETER ContainerName
    対象のコンテナー。空にすると、すべて。

.PARAMETER Prefix
    BLOB 名の先頭で絞る。

.EXAMPLE
    .\Show-StorageFile.ps1 -ResourceGroupName YourRG -StorageAccountName yourstorage1123
#>
[CmdletBinding()]
param(
    [string]$ResourceGroupName = 'DxCmnRG',
    [string]$StorageAccountName = 'osscjpdevinfra',
    [string]$ContainerName,
    [string]$Prefix
)
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'Storage.Common.ps1')
$null = Assert-AzLogin

function Format-ByteSize([long]$Bytes) {
    if ($Bytes -ge 1GB) { return ('{0:N2} GB' -f ($Bytes / 1GB)) }
    if ($Bytes -ge 1MB) { return ('{0:N2} MB' -f ($Bytes / 1MB)) }
    if ($Bytes -ge 1KB) { return ('{0:N1} KB' -f ($Bytes / 1KB)) }
    return "$Bytes B"
}

$sa = Get-AzStorageAccount -ResourceGroupName $ResourceGroupName -Name $StorageAccountName -ErrorAction SilentlyContinue
if (-not $sa) { throw "ストレージアカウント '$StorageAccountName'（RG: $ResourceGroupName）が見つかりません。" }
$ctx = New-AzStorageContext -StorageAccountName $StorageAccountName -UseConnectedAccount

try {
    if ($ContainerName) {
        $c = Get-AzStorageContainer -Name $ContainerName -Context $ctx -ErrorAction SilentlyContinue
        if (-not $c) { throw "コンテナー '$ContainerName' がありません。" }
        $containers = @($c)
    }
    else { $containers = @(Get-AzStorageContainer -Context $ctx) }
}
catch {
    throw ("コンテナーを取得できません: {0}`n  Storage Blob Data Reader 以上のロールと、ネットワーク ルール（自分の IP）を確認してください。" -f $_.Exception.Message)
}

Say ("格納物: {0}（RG: {1}）" -f $StorageAccountName, $ResourceGroupName) -Color Cyan
if ($Prefix) { Say "  先頭: $Prefix" -Color DarkGray }
if ($containers.Count -eq 0) { Say '  コンテナーは、ありません。' -Color Yellow; return }

$total = 0L; $count = 0
foreach ($c in $containers) {
    $args2 = @{ Container = $c.Name; Context = $ctx }
    if ($Prefix) { $args2.Prefix = $Prefix }
    $blobs = @(Get-AzStorageBlob @args2)
    $size = [long](($blobs | Measure-Object Length -Sum).Sum)
    Say ''
    Say ("コンテナー '{0}'（{1} 件、{2}）" -f $c.Name, $blobs.Count, (Format-ByteSize $size)) -Color Cyan
    if ($blobs.Count -gt 0) {
        $blobs | Sort-Object Name | Select-Object Name,
            @{ n = 'Size'; e = { Format-ByteSize $_.Length } },
            @{ n = 'LastModified'; e = { $_.LastModified.ToLocalTime().ToString('yyyy-MM-dd HH:mm') } },
            @{ n = 'Tier'; e = { $_.AccessTier } } |
            Format-Table -AutoSize | Out-String -Width 250 | Write-Host
    }
    $total += $size; $count += $blobs.Count
}
Say ("合計: {0} 件 / {1}" -f $count, (Format-ByteSize $total)) -Color Green
