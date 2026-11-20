<#
.SYNOPSIS
    ゲストユーザーを招待する（招待メールを送信する）。

.DESCRIPTION
    Research の「Invite users」（Connect-AzureAD / New-AzureADMSInvitation）の代替。
    AzureAD モジュールは廃止されているため、Az のアクセストークンで Microsoft Graph の
    POST /invitations を呼び出す。招待には Graph の User.Invite.All 相当の権限が必要で、
    権限不足の場合は 403 になる（その場合は Azure Portal の Entra ID から招待する）。

    ※ 個人の Microsoft アカウント（Gmail などで作ったもの）のゲストは、MFA が必須のテナントでは、
      MFA の登録に失敗することがある。その場合は New-MemberUser.ps1 でメンバーユーザーを作る。

.EXAMPLE
    .\Invite-GuestUser.ps1 -MailAddress user@example.com
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$MailAddress,
    [string]$RedirectUrl = 'https://myapps.microsoft.com',
    [switch]$NoMessage
)
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'AddUsers.Common.ps1')
$null = Assert-AzLogin

Say "  '$MailAddress' を招待します" -Color Cyan
$res = Invoke-GraphApi -Method POST -Path '/invitations' -Body @{
    invitedUserDisplayName  = $MailAddress
    invitedUserEmailAddress = $MailAddress
    inviteRedirectUrl       = $RedirectUrl
    sendInvitationMessage   = (-not $NoMessage.IsPresent)
}
Say ("  招待状態: {0} / ユーザー ID: {1}" -f $res.status, $res.invitedUser.id) -Color DarkGray
Say '完了: 招待しました。' -Color Green
Say '  ※ 個人の Microsoft アカウントは、MFA 必須のテナントで登録に失敗することがあります。その場合は New-MemberUser.ps1 を使ってください。' -Color DarkGray
