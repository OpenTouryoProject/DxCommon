# AddUsers 用の共通定義。各スクリプトからドットソースして使う。

# ==============================================================================
# 共通: 入出力ヘルパと対話メニュー本体（4 つの Tool フォルダで同じ内容）
# ==============================================================================

function Say([string]$Text = '', [string]$Color = 'Gray') {
    Write-Host $Text -ForegroundColor $Color
}

function Assert-AzLogin {
    $ctx = Get-AzContext
    if (-not $ctx) {
        throw 'Azure にログインしていません。Connect-AzAccount を実行してください。'
    }
    return $ctx
}

function Initialize-ResourceGroup([string]$Name, [string]$Location) {
    if (Get-AzResourceGroup -Name $Name -ErrorAction SilentlyContinue) {
        Say "  リソースグループ '$Name' は既に存在します（スキップ）" DarkGray
    }
    else {
        Say "  リソースグループ '$Name' を作成します ($Location)" Cyan
        $null = New-AzResourceGroup -Name $Name -Location $Location
    }
}

function Read-Input([string]$Prompt) {
    $v = Read-Host $Prompt
    if ($null -eq $v) { return '' }
    $v = $v.Trim()
    if ($v -ieq 'q') { throw [System.OperationCanceledException]::new('quit') }
    return $v
}

# 1 つ選ぶ。戻り値: 選んだ項目の位置（0 始まり）、b なら -1（戻る）。
function Select-One([string]$Title, [object[]]$Items, [int]$Default = 1) {
    while ($true) {
        Say ''
        Say $Title -Color Cyan
        for ($i = 0; $i -lt $Items.Count; $i++) {
            Say ("  {0}) {1}" -f ($i + 1), $Items[$i].Label)
        }
        Say '  (b: 戻る / q: 終了)' -Color DarkGray
        $s = Read-Input ("番号 [{0}]" -f $Default)
        if ($s -ieq 'b') { return -1 }
        if ($s -eq '') { $s = "$Default" }
        $n = 0
        if ([int]::TryParse($s, [ref]$n) -and $n -ge 1 -and $n -le $Items.Count) {
            return ($n - 1)
        }
        Say '番号が正しくありません。' -Color Yellow
    }
}

function Read-YesNo([string]$Prompt, [bool]$Default = $false) {
    $hint = if ($Default) { 'Y/n' } else { 'y/N' }
    while ($true) {
        $s = Read-Input ("{0} [{1}]" -f $Prompt, $hint)
        if ($s -eq '') { return $Default }
        if ($s -match '^(y|yes)$') { return $true }
        if ($s -match '^(n|no)$') { return $false }
        Say 'y か n で答えてください。' -Color Yellow
    }
}

# パラメータ定義（Specs）に従って値を対話入力する。戻り値: 名前付き引数のハッシュテーブル。b で戻る場合は $null。
#   Spec: @{ Name; Prompt; Kind = 'Text'|'Switch'|'Choice'; Default; Choices; Required }
function Read-ParamValues([object[]]$Specs) {
    $named = @{}
    foreach ($s in $Specs) {
        $kind = if ($s.Kind) { $s.Kind } else { 'Text' }
        switch ($kind) {
            'Switch' {
                if (Read-YesNo ("  {0} (-{1})" -f $s.Prompt, $s.Name) ([bool]$s.Default)) { $named[$s.Name] = $true }
            }
            'Choice' {
                $items = @($s.Choices | ForEach-Object { @{ Label = $_ } })
                $def = [Math]::Max(1, 1 + [array]::IndexOf(@($s.Choices), $s.Default))
                $i = Select-One ("  {0} (-{1})" -f $s.Prompt, $s.Name) $items $def
                if ($i -lt 0) { return $null }
                $named[$s.Name] = [string]$s.Choices[$i]
            }
            default {
                while ($true) {
                    $hint = if ($s.Default) { " [$($s.Default)]" }
                            elseif ($s.Required) { ' [必須]' }
                            else { ' [空 Enter = 指定しない]' }
                    $v = Read-Input ("  {0} (-{1}){2}" -f $s.Prompt, $s.Name, $hint)
                    if ($v -ieq 'b') { return $null }
                    if ($v -eq '') {
                        if ($s.Default) { $v = [string]$s.Default }
                        elseif ($s.Required) { Say '  必須項目です。' -Color Yellow; continue }
                        else { break }
                    }
                    $named[$s.Name] = $v
                    break
                }
            }
        }
    }
    return $named
}

function Format-CommandLine([string]$ScriptName, [hashtable]$Named) {
    $parts = @(".\$ScriptName")
    foreach ($k in ($Named.Keys | Sort-Object)) {
        $v = $Named[$k]
        if ($v -is [bool]) { if ($v) { $parts += "-$k" } }
        else {
            $t = "$v"
            if ($t -match '\s') { $t = "'$t'" }
            $parts += "-$k"; $parts += $t
        }
    }
    return ($parts -join ' ')
}

# よくある失敗の原因と対処を案内する（メニューの実行エラー時に呼ぶ）。
function Show-ErrorHint([string]$Message) {
    if ($Message -match 'MFA|multi-factor|multifactor|ClaimsChallenge|AADSTS50076|AADSTS50079') {
        $tenant = (Get-AzContext).Tenant.Id
        Say '  [ヒント] 作成・変更・削除に、MFA が必要なテナントのようです。MFA を通して再ログインしてください:' -Color Yellow
        Say ("    Connect-AzAccount -Tenant {0}" -f $tenant) -Color White
        Say '    （エラーに ClaimsChallenge が示されていれば、そのコマンドをそのまま実行する）' -Color DarkGray
    }
    elseif ($Message -match 'ResourceNotFound|ResourceGroupNotFound|was not found|could not be found|NotFound') {
        Say '  [ヒント] 指定した名前のリソースが見つかりません。リソースグループ名と、リソース名（VM 名など）を確認してください。' -Color Yellow
        Say '    ※ VM の「リソース名」は、Windows の「コンピューター名」と違うことがあります（復元した VM など）。Get-AzVM -ResourceGroupName <RG> で、実際の名前を確認できます。' -Color DarkGray
    }
    elseif ($Message -match 'MissingSubscriptionRegistration|not registered|NoRegisteredProviderFound') {
        Say '  [ヒント] リソースプロバイダーが未登録の可能性があります。Test-Prerequisites を実行し、-Register で登録してください。' -Color Yellow
    }
    elseif ($Message -match 'AuthorizationFailed|does not have authorization|403|Forbidden|accessDenied') {
        Say '  [ヒント] 権限が不足しています。対象のスコープで、必要なロール（所有者など）が付与されているか確認してください。' -Color Yellow
    }
    elseif ($Message -match 'AlreadyExists|already exists|StorageAccountAlreadyTaken|already taken') {
        Say '  [ヒント] 同じ名前が既に使われています。ストレージアカウント名などはグローバルで一意である必要があります。名前を変えてください。' -Color Yellow
    }
}

# 対話メニュー本体。
#   Commands: @{ Label; Script; Params = @(Spec...); Note; Danger = $true/$false }
function Start-ToolMenu([string]$Title, [object[]]$Commands, [string]$ToolDir) {
    Say "==== $Title ====" -Color Green
    Say '流れ: コマンド選択 → オプション選択 → 確認 → GO / NOGO（q で終了 / b で戻る）' -Color DarkGray
    try {
        $ctx = Assert-AzLogin
        Say ("  アカウント     : {0}" -f $ctx.Account.Id) -Color DarkGray
        Say ("  サブスクリプション: {0} ({1})" -f $ctx.Subscription.Name, $ctx.Subscription.Id) -Color DarkGray
    }
    catch { Say $_.Exception.Message -Color Red; return }

    try {
        while ($true) {
            # 1. コマンド選択
            $idx = Select-One '[1/4] コマンドを選んでください' $Commands 1
            if ($idx -lt 0) { Say '先頭のため戻れません。' -Color Yellow; continue }
            $cmd = $Commands[$idx]

            # 2. オプション選択
            Say ''
            Say '[2/4] オプションを選んでください' -Color Cyan
            $named = Read-ParamValues $cmd.Params
            if ($null -eq $named) { continue }

            # 3. 確認
            Say ''
            Say '[3/4] 確認' -Color Cyan
            Say ("  コマンド : {0}" -f $cmd.Label)
            Say ("  実行内容 : {0}" -f (Format-CommandLine $cmd.Script $named)) -Color White
            if ($cmd.Note)   { Say ("  ※ {0}" -f $cmd.Note) -Color DarkGray }
            if ($cmd.Destroy) { Say '  ※ リソースを削除します。元に戻せません。スクリプトが削除対象を表示するので、よく確認してください。' -Color Red }
            elseif ($cmd.Danger) { Say '  ※ Azure のリソースを作成・変更します（課金や権限変更を伴う場合があります）。内容をよく確認してください。' -Color Yellow }

            # 4. GO / NOGO
            Say ''
            if ($cmd.Danger) {
                Say '[4/4] 実行しますか？  GO と入力すると実行 / それ以外は NOGO（実行せずメニューへ戻る）' -Color Cyan
                $answer = Read-Input 'GO / NOGO'
                if ($answer -cne 'GO') { Say 'NOGO: 実行しませんでした。' -Color Yellow; continue }
            }
            else {
                Say '[4/4] 読み取り専用です。Enter で実行します。' -Color Cyan
                $null = Read-Input 'Enter'
            }

            Say ''
            Say '--- 実行開始 ---' -Color Green
            try {
                & (Join-Path $ToolDir $cmd.Script) @named
                Say '--- 実行終了 ---' -Color Green
            }
            catch {
                Say ("--- 実行エラー: {0}" -f $_.Exception.Message) -Color Red
                Show-ErrorHint $_.Exception.Message
            }

            Say ''
            if (-not (Read-YesNo '続けて別のコマンドを実行しますか' $true)) { break }
        }
    }
    catch [System.OperationCanceledException] {
        # q で終了
    }
    Say ''
    Say '終了します。' -Color DarkGray
}

# ==============================================================================
# AddUsers 固有: カスタムロール定義と Microsoft Graph 呼び出し
# ==============================================================================

# Research にあるカスタムロール。ベースは "Virtual Machine Contributor"。
$CustomRoles = @(
    @{
        Name        = '仮想マシンの起動と停止'
        Description = '仮想マシンの起動と停止、再起動ができます'
        Actions     = @(
            'Microsoft.DevTestLab/schedules/*',
            'Microsoft.Compute/virtualMachines/write',
            'Microsoft.Compute/VirtualMachines/start/action',
            'Microsoft.Compute/VirtualMachines/restart/action',
            'Microsoft.Compute/VirtualMachines/deallocate/action',
            'Microsoft.Storage/*/read',
            'Microsoft.Network/*/read',
            'Microsoft.Compute/*/read',
            'Microsoft.Authorization/*/read',
            'Microsoft.Resources/subscriptions/resourceGroups/read',
            'Microsoft.ResourceHealth/availabilityStatuses/read',
            'Microsoft.Insights/alertRules/*',
            'Microsoft.Support/*'
        )
    },
    @{
        Name        = '仮想マシン作成のためVMCに追加する権限'
        Description = '仮想マシンの作成のためVirtual Machine Contributor(VMC)にNSGのread/writeを追加する。'
        Actions     = @(
            'Microsoft.Network/networkSecurityGroups/read',
            'Microsoft.Network/networkSecurityGroups/write',
            'Microsoft.Compute/snapshots/read',
            'Microsoft.Compute/snapshots/write',
            'Microsoft.Compute/disks/beginGetAccess/action'
        )
    },
    @{
        Name        = 'Azure Cloud Shellの実行のために追加する権限'
        Description = 'Azure Cloud Shellの実行のためstorageAccountsのread/writeを追加する。'
        Actions     = @(
            'Microsoft.Storage/storageAccounts/read',
            'Microsoft.Storage/storageAccounts/write'
        )
    }
)

# Microsoft Graph を、Az のログイン情報（アクセストークン）で呼び出す。
# AzureAD モジュール（Connect-AzureAD）は廃止されたため、Az だけで完結させる。
function Invoke-GraphApi([string]$Method, [string]$Path, $Body = $null) {
    $t = Get-AzAccessToken -ResourceTypeName MSGraph
    $token = $t.Token
    if ($token -is [System.Security.SecureString]) {
        $bstr = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($token)
        try { $token = [System.Runtime.InteropServices.Marshal]::PtrToStringBSTR($bstr) }
        finally { [System.Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr) }
    }
    $args2 = @{
        Method  = $Method
        Uri     = "https://graph.microsoft.com/v1.0$Path"
        Headers = @{ Authorization = "Bearer $token" }
    }
    if ($null -ne $Body) {
        $args2.ContentType = 'application/json; charset=utf-8'
        $args2.Body = ($Body | ConvertTo-Json -Depth 5)
    }
    try { return (Invoke-RestMethod @args2) }
    catch {
        $detail = if ($_.ErrorDetails.Message) { $_.ErrorDetails.Message } else { $_.Exception.Message }
        throw "Microsoft Graph の呼び出しに失敗しました ($Method $Path): $detail"
    }
}

# ==============================================================================
# 共通: 前提チェック・削除確認・リソース ID ヘルパ
# ==============================================================================

# 削除などの確認。-Force のときは確認しない。
function Confirm-Action([string]$Message, [switch]$Force) {
    if ($Force) { return $true }
    return (Read-YesNo $Message $false)
}

# リソースプロバイダーの登録状態を返す（未登録なら NotRegistered）。
function Get-ProviderState([string]$Namespace) {
    # 一時的な API エラーで「未登録」と誤判定しないよう、再試行する。取得できなければ Unknown を返す。
    for ($try = 1; $try -le 3; $try++) {
        try {
            $p = Get-AzResourceProvider -ProviderNamespace $Namespace -ErrorAction Stop | Select-Object -First 1
            if ($p) { return [string]$p.RegistrationState } else { return 'NotRegistered' }
        }
        catch { if ($try -lt 3) { Start-Sleep -Seconds 2 } }
    }
    return 'Unknown'
}

# 必要なリソースプロバイダーが未登録なら、分かりやすいメッセージで止める。
function Assert-ResourceProviders([string[]]$Namespaces) {
    $missing = @($Namespaces | Where-Object { (Get-ProviderState $_) -eq 'NotRegistered' })
    if ($missing.Count -gt 0) {
        throw ("リソースプロバイダーが未登録です: {0}。.\Test-Prerequisites.ps1 -Register で登録してください。" -f ($missing -join ', '))
    }
}

# リソース ID からリソースグループ名と名前を取り出す。
function Split-ResourceId([string]$Id) {
    $p = $Id -split '/'
    return @{ ResourceGroupName = $p[4]; Name = $p[-1] }
}

$RequiredModules   = @('Az.Accounts', 'Az.Resources')
$RequiredProviders = @('Microsoft.Authorization')

# 暗号論的乱数で、各文字種を含むパスワードを生成する。
function New-RandomPassword([int]$Length = 20) {
    $sets = @('ABCDEFGHJKLMNPQRSTUVWXYZ', 'abcdefghijkmnopqrstuvwxyz', '23456789', '!#$%&*-_=+')
    $rng = [System.Security.Cryptography.RandomNumberGenerator]::Create()
    $next = {
        param([int]$Max)   # 0 以上 Max 未満の乱数（剰余の偏りを避けるため、範囲外は引き直す）
        $limit = [uint32]::MaxValue - ([uint32]::MaxValue % [uint32]$Max)
        $b = New-Object byte[] 4
        do { $rng.GetBytes($b); $v = [BitConverter]::ToUInt32($b, 0) } while ($v -ge $limit)
        return [int]($v % [uint32]$Max)
    }
    $all = -join $sets
    $chars = New-Object System.Collections.Generic.List[char]
    foreach ($s in $sets) { $chars.Add($s[(& $next $s.Length)]) }
    while ($chars.Count -lt $Length) { $chars.Add($all[(& $next $all.Length)]) }
    for ($i = $chars.Count - 1; $i -gt 0; $i--) {   # Fisher-Yates シャッフル
        $j = & $next ($i + 1)
        $tmp = $chars[$i]; $chars[$i] = $chars[$j]; $chars[$j] = $tmp
    }
    $rng.Dispose()
    return (-join $chars)
}
