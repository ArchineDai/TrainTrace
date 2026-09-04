<#
.SYNOPSIS
  ARB 漏 key 检测（zh 模板 + en 译文）。逻辑照搬 weluck 的 scripts/check_l10n.ps1。

.DESCRIPTION
  `flutter gen-l10n` 对缺失 key 只发 warning 不报错，缺的 key 静默回落到模板
  （中文）—— 英文用户会在某个按钮上看到一句中文，而 analyze / test 全绿。
  本脚本把它变成红灯。

  用基线棘轮而不是"必须清零"：若某天有存量欠债清不完，恒红的门禁无法启用。
  只在超出基线时失败，存量数量照旧打印但不阻断；补完译文后跑 -Update 收紧
  基线，只降不升。当前基线为空（零欠债）：任何 locale 漏一个 key 就 exit 1。

.PARAMETER Update
  用当前实际缺失数覆写基线。只在补完翻译后使用（数字应当下降）。

.EXAMPLE
  pwsh scripts/check_l10n.ps1
  pwsh scripts/check_l10n.ps1 -Update
#>
param([switch]$Update)

$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path $PSScriptRoot -Parent
Push-Location $repoRoot
try {
    $report = Join-Path $repoRoot 'l10n_untranslated.json'
    $baselineFile = Join-Path $PSScriptRoot 'l10n_baseline.json'

    # 先删旧报告：gen-l10n 失败时不会覆写它，留着会让上一次的结果冒充本次的。
    if (Test-Path $report) { Remove-Item $report -Force }

    # gen-l10n 把缺失清单写到 l10n.yaml 里配的 untranslated-messages-file。
    # 缺 key 时它退出码为 0，但 ARB 语法错、key 不是合法 Dart 标识符这类问题会
    # 让它非零退出 —— 那种情况必须红，绝不能因为"没有产出报告"就当成没有缺失。
    flutter gen-l10n | Out-Null
    if ($LASTEXITCODE -ne 0) {
        Write-Host "FAIL: flutter gen-l10n 执行失败（退出码 $LASTEXITCODE）" -ForegroundColor Red
        Write-Host '先修好 ARB 本身，再谈漏翻检测。'
        exit 1
    }

    if (-not (Test-Path $report)) {
        Write-Host 'OK: 各语言 key 齐平（gen-l10n 未产出缺失清单）' -ForegroundColor Green
        exit 0
    }

    $actual = @{}
    (Get-Content $report -Raw | ConvertFrom-Json).PSObject.Properties |
        ForEach-Object { $actual[$_.Name] = $_.Value.Count }

    if ($Update) {
        $out = [ordered]@{}
        $actual.Keys | Sort-Object | ForEach-Object { $out[$_] = $actual[$_] }
        $out | ConvertTo-Json | Set-Content $baselineFile -Encoding utf8
        Write-Host "基线已更新 -> $baselineFile" -ForegroundColor Cyan
        $out.GetEnumerator() | ForEach-Object { "  $($_.Key): $($_.Value)" }
        exit 0
    }

    $baseline = @{}
    if (Test-Path $baselineFile) {
        $parsed = Get-Content $baselineFile -Raw | ConvertFrom-Json
        if ($null -ne $parsed) {
            $parsed.PSObject.Properties | ForEach-Object { $baseline[$_.Name] = $_.Value }
        }
    }

    $regressed = @()
    foreach ($locale in ($actual.Keys | Sort-Object)) {
        $now = $actual[$locale]
        $was = if ($baseline.ContainsKey($locale)) { $baseline[$locale] } else { 0 }
        if ($now -gt $was) {
            $regressed += "  $locale : 缺 $now 个 key，基线 $was（新欠 $($now - $was) 个）"
        }
    }

    if ($regressed.Count -gt 0) {
        Write-Host 'FAIL: 有新的漏翻 key' -ForegroundColor Red
        $regressed | ForEach-Object { Write-Host $_ -ForegroundColor Red }
        Write-Host ''
        Write-Host '新增文案要同步全部 ARB（zh 模板 + en），走 /add-text。'
        Write-Host "缺失明细见 $report"
        exit 1
    }

    $total = ($actual.Values | Measure-Object -Sum).Sum
    if ($total -gt 0) {
        Write-Host "OK: 无新增漏翻（存量欠债 $total 个 key）" -ForegroundColor Yellow
        $actual.GetEnumerator() | Sort-Object Key | ForEach-Object {
            "  $($_.Key): $($_.Value)"
        }
        Write-Host '补完译文后跑 -Update 收紧基线。'
    } else {
        Write-Host 'OK: 各语言 key 齐平' -ForegroundColor Green
    }
    exit 0
}
finally {
    Pop-Location
}
