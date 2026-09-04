<#
.SYNOPSIS
  TrainTrace Android 打包 / 装机脚本。

.DESCRIPTION
  一条命令走完「构建 APK → 归档到 build/apk → 装到真机」。

  Mode 与 Flutter 构建模式的对应：
    dev     → --debug   （默认。JIT + 调试横幅，装机后可断点，包最大）
    profile → --profile （AOT + 性能追踪，测卡顿用）
    release → --release （AOT，当前仍用 debug 签名，见 android/app/build.gradle.kts）

  归档命名带版本号与时间戳，便于把「用户手上那一版」和某次构建对上号；
  flutter 自己的产物在 build/app/outputs/flutter-apk/ 会被下次构建覆盖。

  真机验证（休息提醒、进程被杀恢复）只认这条路径 —— 模拟器不算，见 CLAUDE.md。

.PARAMETER Mode
  dev（默认）/ profile / release。

.PARAMETER Install
  构建成功后用 adb 装到设备（-r 保留数据覆盖安装）。

.PARAMETER Device
  adb 设备号。省略时自动选唯一在线设备；接了多台会报错并列出候选。

.PARAMETER Clean
  构建前先 flutter clean。只在产物疑似脏了（换分支、改 gradle、换 Flutter 版本）时用。

.PARAMETER SplitPerAbi
  按 ABI 拆包。装机时自动挑 arm64-v8a。dev 模式下 Flutter 不支持，会被忽略。

.EXAMPLE
  powershell -File scripts/build_apk.ps1 -Install
  powershell -File scripts/build_apk.ps1 -Mode release -SplitPerAbi -Install
#>
param(
    [ValidateSet('dev', 'profile', 'release')][string]$Mode = 'dev',
    [switch]$Install,
    [string]$Device,
    [switch]$Clean,
    [switch]$SplitPerAbi
)

$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path $PSScriptRoot -Parent
Push-Location $repoRoot
try {
    # ---------- 定位 adb ----------
    # PATH 里通常没有（本机就没有），所以按 环境变量 → local.properties → 默认安装位置 依次找。
    function Resolve-Adb {
        $cmd = Get-Command adb -ErrorAction SilentlyContinue
        if ($cmd) { return $cmd.Source }

        $roots = @()
        foreach ($v in @($env:ANDROID_HOME, $env:ANDROID_SDK_ROOT)) {
            if ($v) { $roots += $v }
        }
        $lp = Join-Path $repoRoot 'android\local.properties'
        if (Test-Path $lp) {
            foreach ($line in Get-Content $lp) {
                if ($line -match '^\s*sdk\.dir\s*=\s*(.+)$') {
                    # local.properties 里路径是转义过的（C:\Users\...）
                    $roots += $Matches[1].Trim().Replace('\', '\')
                }
            }
        }
        $roots += (Join-Path $env:LOCALAPPDATA 'Android\Sdk')

        foreach ($r in $roots) {
            $p = Join-Path $r 'platform-tools\adb.exe'
            if (Test-Path $p) { return $p }
        }
        return $null
    }

    # ---------- 选设备 ----------
    function Resolve-Device([string]$adb, [string]$wanted) {
        $online = @()
        foreach ($line in (& $adb devices)) {
            if ($line -match '^(\S+)\s+device$') { $online += $Matches[1] }
        }
        if ($wanted) {
            if ($online -contains $wanted) { return $wanted }
            throw "设备 $wanted 不在线。当前在线：$($online -join ', ')"
        }
        if ($online.Count -eq 1) { return $online[0] }
        if ($online.Count -eq 0) {
            throw '没有在线设备。检查数据线、手机上的 USB 调试授权弹窗，或先跑 adb devices。'
        }
        throw "接了多台设备，用 -Device 指定一台：$($online -join ', ')"
    }

    # ---------- 版本号 ----------
    $version = 'unknown'
    foreach ($line in (Get-Content (Join-Path $repoRoot 'pubspec.yaml'))) {
        if ($line -match '^version:\s*(\S+)') { $version = $Matches[1]; break }
    }

    $buildFlag = @{ dev = '--debug'; profile = '--profile'; release = '--release' }[$Mode]

    # Flutter 只对 profile/release 支持 --split-per-abi，debug 传了会直接报错。
    if ($SplitPerAbi -and $Mode -eq 'dev') {
        Write-Host 'NOTE: dev(debug) 模式不支持 --split-per-abi，已忽略。' -ForegroundColor Yellow
        $SplitPerAbi = $false
    }

    # 装机要先确认设备在场，别等构建完三分钟才发现线没插。
    $adb = $null
    $deviceId = $null
    if ($Install) {
        $adb = Resolve-Adb
        if (-not $adb) {
            throw '找不到 adb.exe。设置 ANDROID_HOME，或确认 Android SDK 里装了 platform-tools。'
        }
        $deviceId = Resolve-Device $adb $Device
        Write-Host "设备：$deviceId" -ForegroundColor Cyan
    }

    if ($Clean) {
        Write-Host '== flutter clean ==' -ForegroundColor Cyan
        flutter clean
        if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
    }

    # ---------- 构建 ----------
    Write-Host "== flutter build apk $buildFlag ($Mode $version) ==" -ForegroundColor Cyan
    $buildArgs = @('build', 'apk', $buildFlag)
    if ($SplitPerAbi) { $buildArgs += '--split-per-abi' }
    & flutter @buildArgs
    if ($LASTEXITCODE -ne 0) {
        Write-Host "FAIL: 构建失败（退出码 $LASTEXITCODE）" -ForegroundColor Red
        exit $LASTEXITCODE
    }

    # ---------- 归档 ----------
    $flutterType = @{ dev = 'debug'; profile = 'profile'; release = 'release' }[$Mode]
    $apkDir = Join-Path $repoRoot 'build\app\outputs\flutter-apk'
    $built = @(Get-ChildItem -Path $apkDir -Filter "app-*$flutterType.apk" -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -notlike '*.apk.sha1' })
    if ($built.Count -eq 0) {
        throw "构建报成功但 $apkDir 下没有 app-*$flutterType.apk，产物路径可能变了。"
    }

    $outDir = Join-Path $repoRoot 'build\apk'
    if (-not (Test-Path $outDir)) { New-Item -ItemType Directory -Path $outDir | Out-Null }
    $stamp = Get-Date -Format 'yyyyMMdd-HHmm'

    $archived = @()
    foreach ($f in $built) {
        # app-arm64-v8a-release.apk → arm64-v8a；app-debug.apk → 空
        $abi = $f.BaseName -replace '^app-', '' -replace "-?$flutterType$", ''
        $suffix = if ($abi) { "-$abi" } else { '' }
        $dest = Join-Path $outDir "traintrace-$Mode-$version$suffix-$stamp.apk"
        Copy-Item $f.FullName $dest -Force
        $archived += Get-Item $dest
    }

    Write-Host ''
    Write-Host 'OK: 构建完成' -ForegroundColor Green
    foreach ($a in $archived) {
        Write-Host ("  {0}  ({1:N1} MB)" -f $a.FullName, ($a.Length / 1MB))
    }

    # ---------- 装机 ----------
    if ($Install) {
        # 拆包时手机装 arm64-v8a 那个；单包时就它自己。
        $target = $built | Where-Object { $_.Name -like '*arm64-v8a*' } | Select-Object -First 1
        if (-not $target) { $target = $built[0] }

        Write-Host ''
        Write-Host "== adb install -r $($target.Name) → $deviceId ==" -ForegroundColor Cyan
        & $adb -s $deviceId install -r $target.FullName
        if ($LASTEXITCODE -ne 0) {
            Write-Host 'FAIL: 安装失败' -ForegroundColor Red
            Write-Host '常见原因：签名与机上已装版本不符（INSTALL_FAILED_UPDATE_INCOMPATIBLE）。'
            Write-Host "先卸载再装：adb -s $deviceId uninstall com.archinedai.traintrace"
            exit $LASTEXITCODE
        }
        Write-Host ''
        Write-Host "OK: 已装到 $deviceId" -ForegroundColor Green
    }
}
finally {
    Pop-Location
}
