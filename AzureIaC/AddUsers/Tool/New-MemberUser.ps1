<#
.SYNOPSIS
    テナント内にメンバーユーザー（組織のアカウント）を作成する。

.DESCRIPTION
    ゲスト招待（Invite-GuestUser.ps1）の代わりに使う。個人の Microsoft アカウントのゲストは、
    MFA が必須のテナントでは、MFA の登録に失敗することがある。メンバーユーザーなら、
    初回サインイン時に通常どおり MFA（認証アプリ）を登録できる。
    -InitialPassword を省略すると、パスワードを自動生成して、画面にだけ表示する（保存しない）。
    既定では、初回サインイン時にパスワードの変更を求める。
    作成後は Grant-UserRoles.ps1 でロールを付与する。

.PARAMETER UserName
    @ の前の部分（例: dxuser01）。

.PARAMETER DomainName
    @ の後ろ。省略時はテナントの既定ドメイン（取得できなければ、ログイン中のアカウントのドメイン）。

.EXAMPLE
    .\New-MemberUser.ps1 -UserName dxuser01
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [ValidatePattern('^[A-Za-z0-9._-]+$')]
    [string]$UserName,
    [string]$DomainName,
    [string]$DisplayName,
    [securestring]$InitialPassword,
    [switch]$NoForcePasswordChange
)
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'AddUsers.Common.ps1')
$ctx = Assert-AzLogin

if (-not $DomainName) {
    try {
        $d = (Invoke-GraphApi -Method GET -Path '/domains').value | Where-Object { $_.isDefault } | Select-Object -First 1
        if ($d) { $DomainName = $d.id }
    }
    catch { }
}
if (-not $DomainName) { $DomainName = ($ctx.Account.Id -split '@')[-1] }
if (-not $DisplayName) { $DisplayName = $UserName }
$upn = "$UserName@$DomainName"

if (Get-AzADUser -UserPrincipalName $upn) {
    Say "  ユーザー '$upn' は既に存在します（スキップ）" -Color DarkGray
    return
}

$generated = $null
if (-not $InitialPassword) {
    $generated = New-RandomPassword 20
    $InitialPassword = ConvertTo-SecureString $generated -AsPlainText -Force
}

Say "  ユーザー '$upn' を作成します" -Color Cyan
$params = @{
    DisplayName       = $DisplayName
    UserPrincipalName = $upn
    MailNickname      = $UserName
    Password          = $InitialPassword
    AccountEnabled    = $true
}
if (-not $NoForcePasswordChange) { $params.ForceChangePasswordNextLogin = $true }
$u = New-AzADUser @params

Say ''
Say "完了: ユーザーを作成しました。" -Color Green
Say ("  ユーザー名: {0}" -f $u.UserPrincipalName)
Say ("  オブジェクト ID: {0}" -f $u.Id)
if ($generated) {
    Say ("  初期パスワード: {0}" -f $generated) -Color Yellow
    Say '  ※ このパスワードは再表示できません。控えてください。' -Color DarkGray
}
Say '  次の手順: Grant-UserRoles.ps1 でロールを付与し、InPrivate ウィンドウで初回サインイン（MFA 登録）を行う。' -Color DarkGray
