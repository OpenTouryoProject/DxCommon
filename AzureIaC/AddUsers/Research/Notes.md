# AddUsers 調査メモ（Tool 作成・実機確認で分かったこと）

実施日: 2026-11-20〜22。環境: Az.Accounts 5.5.5 / Az.Resources 10.2.3。Tool は [../Tool/README.md](../Tool/README.md)。

## MFA が必須のテナント

- 作成・削除の操作が、MFA の要求（`ClaimsChallenge`、`AADSTS50076` など）で拒否されることがある（Security Defaults が疑わしい。条件付きアクセスのポリシーは無かった）。
- 対処: `Connect-AzAccount -Tenant <テナントID>` を MFA を通して再実行する。`ClaimsChallenge` が示されれば、そのコマンドをそのまま実行する。

## ゲスト（個人の Microsoft アカウント）と、メンバー

- Gmail などの個人アカウントをゲストにすると、サインインできないことがあった:
  - 「選択されたユーザー アカウントは、テナント 'Microsoft Services' に存在しない」というエラー。
  - テナントを指定した後の MFA の登録が、「サーバーが拒否した」で失敗。
  - Authenticator の登録で、「QR コードが既に使用されている」や、プッシュ通知の確認エラー。
  - `mysecurityinfo` に「パスワード」しか表示されず、サインイン方法の追加は Authenticator しか出ない。
- 解決: **メンバーユーザーを作って**（`New-MemberUser.ps1`）、管理者が**一時アクセス パス（TAP）**を発行し、TOTP アプリ（別の認証アプリ）で MFA を登録した。
- このテナントの認証方法ポリシー: SMS / 音声 / ハードウェア OATH / FIDO2 / 証明書 は無効。Authenticator、TAP、ソフトウェア OATH、メール OTP は有効。

## Az.Resources 10.x の変更

- `PSRoleDefinition.Actions` が無くなった。カスタム ロールの操作は `Permissions[0].Actions` から読む。
- `New-AzADUser -AccountEnabled` は、値が必要（`-AccountEnabled $true`）。

## ゲストユーザーの扱い

- ユーザー プリンシパル名が `name_domain#EXT#@tenant` の形になる。`-SignInName` で探すと、プリンシパルが解決できず null になるため、`Get-AzADUser -Mail` で探して、`-ObjectId` を使う（`Grant-UserRoles.ps1` / `Show-Users.ps1`）。

## Microsoft Graph

- Az の認証で、`Get-AzAccessToken -ResourceTypeName MSGraph` から Graph のトークンを取る（SecureString で返ることがある）。`AzureAD` モジュールは廃止。
- このトークンでは、認証方法（`authentication methods`）や、Security Defaults のポリシーを読む権限が足りず、403 になる。その場合は Azure Portal（Entra 管理センター）で確認する。

## ロール割り当て

- ロール定義を作った直後は、名前での検索に反映の遅れがある。
- リソースグループへの割り当ては、RG が存在してからでないとできない（`YourRG` は `New-Sandbox` で作られる）。
- 作った 3 種のカスタム ロール: 「仮想マシンの起動と停止」「仮想マシン作成のためVMCに追加する権限」「Azure Cloud Shellの実行のために追加する権限」。`dxuser01` には「仮想マシンの起動と停止」を、サブスクリプション スコープで付けた。

## VM へのログイン用ロール（2026-11-22 / 23）

- Entra ID で VM にログインするには、**VM（またはその親）のスコープ**で、次のロールが要る。
  - `Virtual Machine Administrator Login`: 管理者としてログイン（Windows は、ローカルの Administrators に `AzureAD/<ユーザー>` が入る）。
  - `Virtual Machine User Login`: 一般ユーザーとしてログイン。
- 実機: `WorkVM2` のスコープで、`dxuser01` に付与（User → Administrator の順）。管理者ロールのほうが権限が広い（User は、残しても実質不要）。`daisukenishino` には、管理者ロールが付与済みだった。
- `Get-AzRoleAssignment -ObjectId <ユーザー> -Scope <VM の ID>` は、親のスコープから継承された割り当ても返す。VM 直下のものだけを見るなら、`$_.Scope -eq <VM の ID>` で絞る。
- `dxuser01` のカスタム ロール「仮想マシンの起動と停止」（サブスクリプション スコープ）は、配下の VM に継承される。実機: `dxuser01` で、`WorkVM1` を停止できた。
- ロールの反映には、数分かかることがある。ロールを付けた直後に入れなければ、サインアウトして入り直す。
