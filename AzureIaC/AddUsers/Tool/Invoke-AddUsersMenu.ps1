<#
.SYNOPSIS
    AddUsers の各 Tool を対話形式で実行するメニュー。

.DESCRIPTION
    次の流れで、同フォルダの各 *.ps1 を組み立てて実行する。
      1. コマンド選択   : 実行するスクリプトを選ぶ。
      2. オプション選択 : スクリプトのパラメータを入力する（Enter で既定値）。
      3. 確認           : 実行するコマンドラインを表示する。
      4. GO / NOGO      : GO と入力したときだけ実行する（読み取り専用の Show は Enter で実行）。
    実行後はコマンド選択へ戻る。途中で q を入力すると終了する（b で 1 つ前へ戻る）。
    事前に Connect-AzAccount でログインしておくこと。

.EXAMPLE
    .\Invoke-AddUsersMenu.ps1
#>
[CmdletBinding()]
param()
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'AddUsers.Common.ps1')

$upn = @{ Name = 'UserPrincipalName'; Prompt = '対象ユーザーのメールアドレス / UPN'; Required = $true }

$commands = @(
    @{ Label = 'Test-Prerequisites : 前提（モジュール / ログイン）を確認（読み取り専用）'; Script = 'Test-Prerequisites.ps1'; Danger = $false
       Params = @() },
    @{ Label = 'New-MemberUser  : メンバーユーザーを作成（パスワードは自動生成）'; Script = 'New-MemberUser.ps1'; Danger = $true
       Note = '初期パスワードは画面にだけ表示される。MFA 必須のテナントでは、ゲストよりこちらが確実。'
       Params = @(
            @{ Name = 'UserName'; Prompt = 'ユーザー名（@ の前）'; Required = $true },
            @{ Name = 'DisplayName'; Prompt = '表示名' }) },
    @{ Label = 'New-CustomRoles : カスタムロール 3 種を作成'; Script = 'New-CustomRoles.ps1'; Danger = $true
       Note = '現在のサブスクリプションにロール定義を作成する（所有者などの権限が必要）。'
       Params = @() },
    @{ Label = 'Invite-GuestUser: ゲストユーザーを招待（招待メール送信）'; Script = 'Invite-GuestUser.ps1'; Danger = $true
       Note = 'Microsoft Graph を呼び出す。権限不足の場合は 403 になる。'
       Params = @(
            @{ Name = 'MailAddress'; Prompt = '招待するメールアドレス'; Required = $true },
            @{ Name = 'NoMessage'; Prompt = '招待メールを送らない'; Kind = 'Switch'; Default = $false }) },
    @{ Label = 'Grant-UserRoles : ユーザーにロールを割り当て'; Script = 'Grant-UserRoles.ps1'; Danger = $true
       Params = @($upn,
            @{ Name = 'ResourceGroupName'; Prompt = '対象リソースグループ'; Default = 'YourRG' },
            @{ Name = 'SkipResourceGroupRoles'; Prompt = 'リソースグループへの割り当てをしない'; Kind = 'Switch'; Default = $false },
            @{ Name = 'SkipSubscriptionRole'; Prompt = 'サブスクリプションへの割り当てをしない'; Kind = 'Switch'; Default = $false }) },
    @{ Label = 'Show-Users      : ゲスト / ロール / 割り当てを表示（読み取り専用）'; Script = 'Show-Users.ps1'; Danger = $false
       Params = @(@{ Name = 'UserPrincipalName'; Prompt = 'ロール割り当てを見るユーザー' }) },
    @{ Label = 'Remove-User     : ユーザーをロール割り当てごと削除'; Script = 'Remove-User.ps1'; Danger = $true; Destroy = $true
       Params = @($upn) }
)

Start-ToolMenu -Title 'AddUsers 対話メニュー (Azure PowerShell)' -Commands $commands -ToolDir $PSScriptRoot
