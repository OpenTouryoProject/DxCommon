# AddUsers - Tool

[Research](../Research/Concept.md) を Azure PowerShell にしたもの。
カスタムロールを作り、テナントにユーザーを追加して、ロールを付与する。

## 前提
- PowerShell 7（または Windows PowerShell 5.1）と、`Az` モジュール（`Az.Accounts`、`Az.Resources`）。
- `Connect-AzAccount` でサインイン済みであること。テナントが MFA 必須の場合は、MFA を通してサインインしないと、作成・削除が拒否される。
- ロール定義とロール割り当てを作るため、サブスクリプションの所有者（または同等）の権限。
- `New-MemberUser.ps1` と `Remove-User.ps1` には、Entra ID でユーザーを作成・削除する権限。

## 使い方
対話メニュー（推奨）:

```PowerShell
.\Invoke-AddUsersMenu.ps1
```

流れ: コマンドを選ぶ → オプションを入力する（Enter で既定値）→ 確認する → `GO` と入力して実行する。
`q` で終了、`b` で 1 つ前に戻る。読み取り専用のコマンドは Enter で実行する。

| スクリプト | Research | 内容 |
|---|---|---|
| `Test-Prerequisites.ps1` | - | モジュールとサインインを確認する |
| `New-CustomRoles.ps1` | Creating a custom role | カスタムロール 3 種を作成する（既にあるものはスキップ） |
| `New-MemberUser.ps1` | - | メンバーユーザーを作成する。パスワードは自動生成して、一度だけ表示する |
| `Invite-GuestUser.ps1` | Invite users | Microsoft Graph でゲストユーザーを招待する |
| `Grant-UserRoles.ps1` | Grant them permissions by role | ユーザーにロールを割り当てる |
| `Show-Users.ps1` | - | カスタムロール、ゲストユーザー、ユーザーのロール割り当てを表示する（読み取り専用） |
| `Remove-User.ps1` | - | ユーザーを、ロール割り当てごと削除する |

## 注意
- **ゲストか、メンバーか。** 個人の Microsoft アカウント（Gmail のアドレスで作ったものなど）のゲストは、
  テナントが MFA 必須の場合、MFA の登録に失敗することがある。その場合は、`New-MemberUser.ps1` でメンバーユーザーを作る。
- 新しいメンバーユーザーは、初回サインイン時に MFA の方法を登録する必要がある。Microsoft Authenticator のプッシュ通知だけが失敗する場合は、
  Entra 管理センター（ユーザー → 対象のユーザー → 認証方法）で、管理者が「一時アクセス パス」を発行できる。
  または、「別の認証アプリを使用します」から、TOTP アプリを登録する。
- `Invite-GuestUser.ps1` と `Show-Users.ps1` は、Az のアクセストークンで Microsoft Graph を呼び出す（`AzureAD` モジュールは廃止されたため）。
  トークンに必要な権限がないと 403 になる。その場合は Azure Portal で操作する。
- リソースグループへのロール割り当ては、先にリソースグループが存在している必要がある
  （`YourRG` は `Simplest\Tool\New-Sandbox.ps1` で作られる）。作成後に、`Grant-UserRoles.ps1` をもう一度実行する。
- ゲストユーザーは、ユーザープリンシパル名が `name_domain#EXT#@tenant` の形になるため、メールアドレスで探して、オブジェクト ID を引いてから操作する。
