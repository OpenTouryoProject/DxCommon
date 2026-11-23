<#
.SYNOPSIS
    ローカルのファイルを、ストレージアカウントのコンテナー（BLOB）にアップロードする（Entra ID 認証）。

.DESCRIPTION
    言語パックの ISO（Windows Server の「Languages and Optional Features」ISO）など、大きなファイルを置くために使う。
    置いたファイルは、SingleVM の Set-VMLocale.ps1（-LanguageSourceAccount / -LanguageSourceBlob）が、VM に取り込む。
    認証は、ストレージ キーでなく、Entra ID（Storage Blob Data Contributor などのロールが必要）。
    コンテナーが無ければ、作らずに止まる（New-StorageAccount.ps1 で作る）。同じ名前の BLOB があれば、確認してから上書きする。
    大きなファイルは、時間がかかる（6.4 GB で約 10 分）。

    ISO の入手（手動）: Microsoft Evaluation Center の Windows Server 2025 のページに、
    「Languages and Optional Features」ISO のリンクがある（ライセンス条件は、入手先で確認すること）。
    ISO のビルドは、VM の Windows に合わせる。

.PARAMETER FilePath
    アップロードするローカルのファイル。

.PARAMETER BlobName
    BLOB 名（フォルダーは / で区切る）。省略すると、windows-server-2025/<ファイル名>。

.EXAMPLE
    .\Send-StorageFile.ps1 -ResourceGroupName YourRG -StorageAccountName yourstorage1123 -FilePath C:\Users\me\Downloads\26100.1.240331-1435.ge_release_amd64fre_SERVER_LOF_PACKAGES_OEM.iso
#>
[CmdletBinding(SupportsShouldProcess)]
param(
    [string]$ResourceGroupName = 'DxCmnRG',
    [string]$StorageAccountName = 'osscjpdevinfra',
    [string]$ContainerName = 'langpack',
    [Parameter(Mandatory)]
    [string]$FilePath,
    [string]$BlobName,
    [switch]$Force
)
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'Storage.Common.ps1')
$null = Assert-AzLogin
Assert-ResourceProviders $RequiredProviders

if (-not (Test-Path -LiteralPath $FilePath -PathType Leaf)) { throw "ファイルが見つかりません: $FilePath" }
$file = Get-Item -LiteralPath $FilePath
if (-not $BlobName) { $BlobName = 'windows-server-2025/' + $file.Name }
$null = Get-AzStorageAccount -ResourceGroupName $ResourceGroupName -Name $StorageAccountName   # 無ければ、ここで止まる
$ctx = New-AzStorageContext -StorageAccountName $StorageAccountName -UseConnectedAccount
$container = Get-AzStorageContainer -Name $ContainerName -Context $ctx -ErrorAction SilentlyContinue
if (-not $container) { throw "コンテナー '$ContainerName' がありません。New-StorageAccount.ps1 -ContainerName $ContainerName で作ってください。" }
$exists = Get-AzStorageBlob -Container $ContainerName -Blob $BlobName -Context $ctx -ErrorAction SilentlyContinue

Say ("アップロード: {0}（{1} GB）" -f $file.FullName, [math]::Round($file.Length / 1GB, 2)) -Color Cyan
Say ("  先: {0}/{1}/{2}" -f $StorageAccountName, $ContainerName, $BlobName) -Color Cyan
if ($exists) { Say '  ※ 同じ名前の BLOB が、すでにあります（上書きします）。' -Color Yellow }
if ($WhatIfPreference) { Say '（-WhatIf: 何もアップロードしていません）' -Color DarkGray; return }
if (-not (Confirm-Action 'アップロードしますか' -Force:$Force)) { Say '中止しました。' -Color Yellow; return }

$sw = [Diagnostics.Stopwatch]::StartNew()
$null = Set-AzStorageBlobContent -File $file.FullName -Container $ContainerName -Blob $BlobName -Context $ctx -Force
Say ("完了: {0} GB を {1} 秒でアップロードしました。" -f [math]::Round($file.Length / 1GB, 2), [int]$sw.Elapsed.TotalSeconds) -Color Green
Say ("  Set-VMLocale.ps1 -LanguageSourceAccount {0} -LanguageSourceBlob {1}" -f $StorageAccountName, $BlobName) -Color DarkGray
