<#
.SYNOPSIS
    Windows VM に、Entra ID（旧 Azure AD）での RDP ログインを設定する。

.DESCRIPTION
    次を行う。
      1. システム割り当てマネージド ID を有効にする（拡張に必要）。
      2. 拡張機能 AADLoginForWindows を入れる。
      3. -UserPrincipalName のユーザーに、この VM のスコープでロールを割り当てる。
           Administrator : Virtual Machine Administrator Login（管理者としてログイン）
           User          : Virtual Machine User Login（一般ユーザーとしてログイン）
      4. -RdpFilePath を指定すると、接続用の .rdp ファイルを書き出す。
    Windows VM 専用（Linux は対象外）。VM は起動している必要がある。3389 の受信は、Open-VMPort.ps1 で、IP を絞って開けておく。
    この設定の後も、VM ローカルの管理者パスワードでのログインは使える（無効にはしない）。

    ※ 手元の PC が Entra 参加していなくても接続できるよう、.rdp には targetisaadjoined / enablerdsaadauth を入れる。
      つながらないときは、ユーザー名を AzureAD\<UPN> の形にして、パスワード入力でログインする。
      Web アカウントでのサインインは、接続先に IP アドレスを使えず、Entra ID のデバイス名（コンピューター名）と一致する名前が必要。
      そのため .rdp にはコンピューター名を書く。手元の PC の hosts に、<IP> <コンピューター名> の行を足して、名前解決させる。
    ※ MFA を求めたい場合は、条件付きアクセスで「Azure Windows VM Sign-In」アプリに MFA を要求する。

.PARAMETER UserPrincipalName
    ロールを割り当てるユーザー（UPN またはメールアドレス）。省略すると、拡張の導入だけ行う。

.PARAMETER Role
    Administrator（既定）/ User。

.PARAMETER RdpFilePath
    書き出す .rdp ファイルのパス。

.EXAMPLE
    .\Enable-EntraLogin.ps1 -ResourceGroupName hogeRG -VmName hogeVM -UserPrincipalName dxuser01@contoso.onmicrosoft.com -RdpFilePath .\hogeVM.rdp
#>
[CmdletBinding()]
param(
    [string]$ResourceGroupName = 'hogeRG',
    [string]$VmName = 'hogeVM',
    [string]$UserPrincipalName,
    [ValidateSet('Administrator', 'User')][string]$Role = 'Administrator',
    [string]$RdpFilePath
)
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'SingleVM.Common.ps1')
$null = Assert-AzLogin

$vm = Get-AzVM -ResourceGroupName $ResourceGroupName -Name $VmName -Status
$vmObj = Get-AzVM -ResourceGroupName $ResourceGroupName -Name $VmName
if (Test-VmIsLinux $vmObj) { throw "VM '$VmName' は Linux です。この Tool は Windows VM 専用です。" }
$power = ($vm.Statuses | Where-Object { $_.Code -like 'PowerState/*' }).Code
if ($power -ne 'PowerState/running') { throw "VM '$VmName' が起動していません（$power）。Set-VMPower.ps1 で起動してください。" }

# 1. マネージド ID
if ($vmObj.Identity.Type -notmatch 'SystemAssigned') {
    Say '  システム割り当てマネージド ID を有効にします' -Color Cyan
    $null = Update-AzVM -ResourceGroupName $ResourceGroupName -VM $vmObj -IdentityType SystemAssigned
}
else {
    Say '  マネージド ID は有効です（スキップ）' -Color DarkGray
}

# 2. 拡張機能
$ext = Get-AzVMExtension -ResourceGroupName $ResourceGroupName -VMName $VmName -Name 'AADLoginForWindows' -ErrorAction SilentlyContinue
if ($ext -and $ext.ProvisioningState -eq 'Succeeded') {
    Say '  拡張機能 AADLoginForWindows は導入済みです（スキップ）' -Color DarkGray
}
else {
    Say '  拡張機能 AADLoginForWindows を導入します（数分かかります）' -Color Cyan
    $null = Set-AzVMExtension -ResourceGroupName $ResourceGroupName -VMName $VmName -Location $vmObj.Location `
        -Name 'AADLoginForWindows' -Publisher 'Microsoft.Azure.ActiveDirectory' -ExtensionType 'AADLoginForWindows' -TypeHandlerVersion '2.0'
}

# 3. ロール割り当て
$upn = $null
if ($UserPrincipalName) {
    $user = Get-AzADUser -UserPrincipalName $UserPrincipalName -ErrorAction SilentlyContinue
    if (-not $user) { $user = Get-AzADUser -Mail $UserPrincipalName -ErrorAction SilentlyContinue | Select-Object -First 1 }
    if (-not $user) { throw "ユーザー '$UserPrincipalName' が見つかりません。" }
    $upn = $user.UserPrincipalName
    $roleName = if ($Role -eq 'Administrator') { 'Virtual Machine Administrator Login' } else { 'Virtual Machine User Login' }
    $exists = Get-AzRoleAssignment -ObjectId $user.Id -RoleDefinitionName $roleName -Scope $vmObj.Id -ErrorAction SilentlyContinue |
        Where-Object { $_.Scope -eq $vmObj.Id }
    if ($exists) {
        Say "  ロール '$roleName' は割り当て済みです（スキップ）" -Color DarkGray
    }
    else {
        Say "  ユーザー '$upn' に、ロール '$roleName' を割り当てます（スコープ: この VM）" -Color Cyan
        $null = New-AzRoleAssignment -ObjectId $user.Id -RoleDefinitionName $roleName -Scope $vmObj.Id
    }
}

# 4. .rdp ファイル
$ip = Get-VmPublicIp $vmObj
$hostName = $null
if ($RdpFilePath) {
    if (-not $ip) { throw 'この VM にはパブリック IP がありません。.rdp を書き出せません。' }
    # Web アカウントでのサインインは、接続先に IP アドレスを使えず、Entra ID のデバイス名（コンピューター名）と一致する名前が必要。
    # （FQDN や、Public IP の DNS 名は、デバイスが見つからず AADSTS293004 になる）。名前を IP に解決できるよう、手元の PC の hosts に足す。
    $hostName = Get-VmComputerName $vmObj
    if (-not $hostName) { throw 'コンピューター名を取得できませんでした。' }
    $lines = @("full address:s:$hostName", 'prompt for credentials:i:1', 'enablerdsaadauth:i:1', 'targetisaadjoined:i:1')
    if ($upn) { $lines += "username:s:AzureAD\$upn" }
    Set-Content -Path $RdpFilePath -Value $lines -Encoding ASCII
    Say "  .rdp ファイルを書き出しました: $RdpFilePath" -Color DarkGray
}

Say ''
Say "完了: VM '$VmName' で、Entra ID のログインを使えるようにしました。" -Color Green
Say '  - ロールの反映に数分かかることがあります。' -Color DarkGray
Say '  - 3389 は、Open-VMPort.ps1 -MyIp などで、自分の IP を絞って開けてください。' -Color DarkGray
if ($ip) { Show-EntraHostsHint $vmObj $ip }
else { Say '  - パブリック IP がありません。Add-VMPublicIp.ps1 -OpenPort 3389 -MyIp で付けると、接続先と hosts のコマンドを表示します。' -Color DarkGray }
