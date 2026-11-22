<#
.SYNOPSIS
    課金の状況（過去 30 日 / 先月 / 当月の実績と予測）を表示する（読み取り専用）。

.DESCRIPTION
    Cost Management API で、現在のサブスクリプションの請求額（税引前）を調べる。
      1. 過去 30 日の実績
      2. 先月の請求額
      3. 当月の実績と、月末までの予測（予実）。先月との比較も出す。
         予測が取れない場合（利用開始直後など）は、日割りの単純な見込みで代用する。
      4. 予算（Budget）が設定されていれば、その使用状況
    -TopServices を指定すると、各期間のサービス別の上位も表示する。
    何も変更しない。必要な権限: 「Cost Management 閲覧者」または、所有者 / 閲覧者。

    ※ コストの反映には、数時間〜1 日ほど遅れる。新しいサブスクリプションでは、データがまだ無いことがある。
    ※ Cost Management の API は、短時間に呼ぶと 429 になる。その場合は自動で待って再試行する。

.PARAMETER TopServices
    サービス別の上位を、この件数だけ表示する（0 で表示しない）。

.PARAMETER SubscriptionId
    対象のサブスクリプション。省略すると、現在のもの。

.EXAMPLE
    .\Show-Billing.ps1
    .\Show-Billing.ps1 -TopServices 5
#>
[CmdletBinding()]
param(
    [ValidateRange(0, 50)][int]$TopServices = 5,
    [string]$SubscriptionId
)
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'Monitor.Common.ps1')
$ctx = Assert-AzLogin
if (-not $SubscriptionId) { $SubscriptionId = $ctx.Subscription.Id }
Say ("対象サブスクリプション: {0} ({1})" -f $ctx.Subscription.Name, $SubscriptionId) -Color DarkGray

$today = [datetime]::UtcNow.Date
$monthStart = [datetime]::new($today.Year, $today.Month, 1)
$monthEnd = $monthStart.AddMonths(1).AddDays(-1)
$lastStart = $monthStart.AddMonths(-1)
$lastEnd = $monthStart.AddDays(-1)
$d30Start = $today.AddDays(-30)
$byService = $TopServices -gt 0

function Show-Top($Result, [int]$N) {
    if ($N -le 0 -or $Result.Services.Count -eq 0) { return }
    $Result.Services | Select-Object -First $N | ForEach-Object {
        Say ("      {0,-44} {1,16}" -f $_.Name, (Format-Money $_.Cost $Result.Currency)) -Color DarkGray
    }
}

# ------------------------------------------------------------------ 1. 過去 30 日
$r30 = Get-CostForPeriod $SubscriptionId $d30Start $today -ByService:$byService
# ------------------------------------------------------------------ 2. 先月
$rLast = Get-CostForPeriod $SubscriptionId $lastStart $lastEnd -ByService:$byService
# ------------------------------------------------------------------ 3. 当月（実績 + 予測）
$rMonth = Get-CostForPeriod $SubscriptionId $monthStart $today -ByService:$byService

$forecastTotal = $null; $forecastNote = ''
try {
    $body = @{
        type = 'ActualCost'; timeframe = 'Custom'
        timePeriod = @{ from = $monthStart.ToString('yyyy-MM-ddT00:00:00Z'); to = $monthEnd.ToString('yyyy-MM-ddT23:59:59Z') }
        dataset = @{ granularity = 'Daily'; aggregation = @{ totalCost = @{ name = 'PreTaxCost'; function = 'Sum' } } }
        includeActualCost = $true; includeFreshPartialCost = $false
    }
    $rows = @(ConvertFrom-CostRows (Invoke-CostApi $SubscriptionId 'forecast' $body))
    if ($rows.Count -gt 0 -and @($rows | Where-Object { $_.CostStatus -eq 'Forecast' }).Count -gt 0) {
        $forecastTotal = [double]($rows | Measure-Object PreTaxCost -Sum).Sum
        $forecastNote = 'Azure の予測'
    }
}
catch { Say ("  予測 API を使えませんでした: {0}" -f $_.Exception.Message) -Color DarkGray }

if ($null -eq $forecastTotal) {
    $elapsed = [Math]::Max(1, ($today - $monthStart).Days + 1)
    $forecastTotal = $rMonth.Total / $elapsed * $monthEnd.Day
    $forecastNote = "日割りの見込み（{0} 日分の実績 ÷ {0} × {1} 日）" -f $elapsed, $monthEnd.Day
}

$cur = @($r30.Currency, $rLast.Currency, $rMonth.Currency) | Where-Object { $_ } | Select-Object -First 1

# ------------------------------------------------------------------ 表示
Say ''
Say ("過去 30 日   ({0:yyyy-MM-dd} 〜 {1:yyyy-MM-dd})" -f $d30Start, $today) -Color Cyan
Say ("    実績 : {0}" -f (Format-Money $r30.Total $cur)) -Color White
Show-Top $r30 $TopServices

Say ''
Say ("先月        ({0:yyyy-MM-dd} 〜 {1:yyyy-MM-dd})" -f $lastStart, $lastEnd) -Color Cyan
Say ("    請求額 : {0}" -f (Format-Money $rLast.Total $cur)) -Color White
Show-Top $rLast $TopServices

Say ''
Say ("当月        ({0:yyyy-MM-dd} 〜 {1:yyyy-MM-dd}、{2} 日経過 / {3} 日)" -f $monthStart, $monthEnd, (($today - $monthStart).Days + 1), $monthEnd.Day) -Color Cyan
Say ("    実績（今日まで） : {0}" -f (Format-Money $rMonth.Total $cur)) -Color White
Say ("    月末の予測       : {0}   [{1}]" -f (Format-Money $forecastTotal $cur), $forecastNote) -Color White
Show-Top $rMonth $TopServices

Say ''
Say '予実（当月の見込み と 先月）' -Color Cyan
$diff = $forecastTotal - $rLast.Total
$color = if ($diff -gt 0) { 'Yellow' } else { 'Green' }
$pct = if ($rLast.Total -gt 0) { ' ({0:+0.0;-0.0}%)' -f ($diff / $rLast.Total * 100) } else { '' }
Say ("    先月                 : {0}" -f (Format-Money $rLast.Total $cur))
Say ("    当月の見込み         : {0}" -f (Format-Money $forecastTotal $cur))
Say ("    差（見込み - 先月）  : {0}{1}" -f (Format-Money $diff $cur), $pct) -Color $color

# ------------------------------------------------------------------ 4. 予算
Say ''
Say '予算（Budget）' -Color Cyan
try {
    $r = Invoke-AzRestMethod -Method GET -Path "/subscriptions/$SubscriptionId/providers/Microsoft.Consumption/budgets?api-version=2023-05-01"
    $budgets = if ($r.StatusCode -lt 300) { @(($r.Content | ConvertFrom-Json).value) } else { @() }
    if ($budgets.Count -eq 0) {
        Say '    予算は設定されていません。Azure Portal の「コストの管理」→「予算」で、月額の予算とアラートを作っておくと安心です。' -Color DarkGray
    }
    else {
        foreach ($b in $budgets) {
            $amount = [double]$b.properties.amount
            $spent = [double]$b.properties.currentSpend.amount
            $rate = if ($amount -gt 0) { $spent / $amount * 100 } else { 0 }
            $fRate = if ($amount -gt 0 -and $b.properties.timeGrain -eq 'Monthly') { $forecastTotal / $amount * 100 } else { $null }
            $c = if ($rate -ge 100) { 'Red' } elseif ($rate -ge 80) { 'Yellow' } else { 'Green' }
            Say ("    {0} ({1}): 予算 {2} / 使用 {3} ({4:N1}%)" -f $b.name, $b.properties.timeGrain, (Format-Money $amount $cur), (Format-Money $spent $cur), $rate) -Color $c
            if ($null -ne $fRate) { Say ("        月末の予測では予算の {0:N1}%" -f $fRate) -Color DarkGray }
        }
    }
}
catch { Say ("    取得できません: {0}" -f $_.Exception.Message) -Color DarkGray }

Say ''
Say '※ 税引前の金額です。反映に数時間〜1 日の遅れがあります。' -Color DarkGray
Say '完了。' -Color Green
