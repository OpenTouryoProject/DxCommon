# Simplest 用の共通定義。各スクリプトからドットソースして使う。
$DefaultLocation = 'japaneast'
$DefaultVmSize   = 'Standard_D4s_v3'
$DefaultOS       = 'Win2019Datacenter'

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
            if ($cmd.Danger) { Say '  ※ Azure のリソースを作成・変更します（課金や権限変更を伴う場合があります）。内容をよく確認してください。' -Color Yellow }

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
# 共通: VM 関連ヘルパ
# ==============================================================================

# az の --image 別名に相当する、マーケットプレースイメージの定義。
$VmImages = [ordered]@{
    'Win2019Datacenter' = @{ Publisher = 'MicrosoftWindowsServer'; Offer = 'WindowsServer'; Sku = '2019-Datacenter'; IsLinux = $false }
    'Win2022Datacenter' = @{ Publisher = 'MicrosoftWindowsServer'; Offer = 'WindowsServer'; Sku = '2022-Datacenter'; IsLinux = $false }
    'Ubuntu2204'        = @{ Publisher = 'Canonical'; Offer = '0001-com-ubuntu-server-jammy'; Sku = '22_04-lts'; IsLinux = $true }
}

function Get-VmImageSpec([string]$OS) {
    if (-not $VmImages.Contains($OS)) {
        throw ("未対応のイメージ: {0}（対応: {1}）" -f $OS, ($VmImages.Keys -join ', '))
    }
    return $VmImages[$OS]
}

# VM の自動シャットダウン（az vm auto-shutdown 相当）。Time は UTC の HHmm（1500 = JST 0000）。
function Set-VmAutoShutdown([string]$ResourceGroupName, [string]$VmName, [string]$Location, [string]$Time = '1500') {
    $vm = Get-AzVM -ResourceGroupName $ResourceGroupName -Name $VmName
    $props = @{
        status               = 'Enabled'
        taskType             = 'ComputeVmShutdownTask'
        dailyRecurrence      = @{ time = $Time }
        timeZoneId           = 'UTC'
        notificationSettings = @{ status = 'Disabled'; timeInMinutes = 30 }
        targetResourceId     = $vm.Id
    }
    $null = New-AzResource -ResourceType 'Microsoft.DevTestLab/schedules' `
        -ResourceName "shutdown-computevm-$VmName" `
        -ResourceGroupName $ResourceGroupName -Location $Location `
        -Properties $props -Force
    Say "  自動シャットダウンを設定しました (UTC $Time)" -Color DarkGray
}

function Get-CredentialIfNull([pscredential]$Credential, [string]$Message) {
    if ($Credential) { return $Credential }
    return (Get-Credential -Message $Message)
}

# 既存サブネットへ、パブリック IP なしの VM を作る（az vm create --public-ip-address "" 相当）。
function New-PrivateVM {
    param(
        [string]$ResourceGroupName, [string]$Location, [string]$VmName, [string]$VmSize, [string]$OS,
        [pscredential]$Credential, [string]$VnetName, [string]$SubnetName
    )
    $vnet = Get-AzVirtualNetwork -ResourceGroupName $ResourceGroupName -Name $VnetName
    $subnet = $vnet.Subnets | Where-Object { $_.Name -eq $SubnetName }
    if (-not $subnet) { throw "サブネット '$SubnetName' が VNet '$VnetName' にありません。" }

    $img = Get-VmImageSpec $OS
    $nic = New-AzNetworkInterface -Name "${VmName}VMNic" -ResourceGroupName $ResourceGroupName `
        -Location $Location -SubnetId $subnet.Id

    $cfg = New-AzVMConfig -VMName $VmName -VMSize $VmSize
    if ($img.IsLinux) {
        $cfg = Set-AzVMOperatingSystem -VM $cfg -Linux -ComputerName $VmName -Credential $Credential
    }
    else {
        $computerName = $VmName.Substring(0, [Math]::Min(15, $VmName.Length))   # Windows は 15 文字まで
        $cfg = Set-AzVMOperatingSystem -VM $cfg -Windows -ComputerName $computerName -Credential $Credential `
            -ProvisionVMAgent -EnableAutoUpdate
    }
    $cfg = Set-AzVMSourceImage -VM $cfg -PublisherName $img.Publisher -Offer $img.Offer -Skus $img.Sku -Version latest
    $cfg = Add-AzVMNetworkInterface -VM $cfg -Id $nic.Id

    Say "  VM '$VmName' を作成します（数分かかります）" -Color Cyan
    $null = New-AzVM -ResourceGroupName $ResourceGroupName -Location $Location -VM $cfg
}
