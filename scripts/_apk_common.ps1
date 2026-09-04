<#
.SYNOPSIS
  build_dev.ps1 / build_release.ps1 共用的构建装机零件。

.DESCRIPTION
  自身不做任何事，只定义函数，由两个入口脚本 dot-source：

      . (Join-Path $PSScriptRoot '_apk_common.ps1')

  两个入口脚本的差别只在构建参数与签名要求，找 adb、选设备、归档、装机这些
  重复了就会两边漂移，收在这里。
#>

# adb 通常不在 PATH 上（本机就没有）。按 环境变量 → local.properties 的 sdk.dir
# → 默认安装位置 依次找，别让脚本依赖某台机器的环境配置。
function Resolve-Adb([string]$repoRoot) {
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
                # local.properties 是 Java properties 格式，路径里的反斜杠是转义过的
                # （sdk.dir=C:\\Users\\...），要还原成单个才是真路径。
                $roots += $Matches[1].Trim().Replace('\\', '\')
            }
        }
    }
    if ($env:LOCALAPPDATA) { $roots += "$env:LOCALAPPDATA\Android\Sdk" }

    # 这里用字符串拼接而不是 Join-Path：候选路径来自环境变量和 local.properties，
    # 可能指向不存在的盘符，Join-Path 遇到就抛异常 —— 脚本开了 ErrorActionPreference
    # = Stop，那样会让「某个候选路径不对」升级成整个构建中止。Test-Path 则只返回 false。
    foreach ($r in $roots) {
        $p = "$r\platform-tools\adb.exe"
        if (Test-Path $p) { return $p }
    }
    throw '找不到 adb.exe。设置 ANDROID_HOME，或确认 Android SDK 里装了 platform-tools。'
}

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

function Get-PubspecVersion([string]$repoRoot) {
    foreach ($line in (Get-Content (Join-Path $repoRoot 'pubspec.yaml'))) {
        if ($line -match '^version:\s*(\S+)') { return $Matches[1] }
    }
    return 'unknown'
}

# 找 flutter 刚产出的 APK。$flutterType 是 debug / profile / release。
function Get-BuiltApk([string]$repoRoot, [string]$flutterType) {
    $apkDir = Join-Path $repoRoot 'build\app\outputs\flutter-apk'
    $built = @(Get-ChildItem -Path $apkDir -Filter "app-*$flutterType.apk" -ErrorAction SilentlyContinue)
    if ($built.Count -eq 0) {
        throw "构建报成功但 $apkDir 下没有 app-*$flutterType.apk，产物路径可能变了。"
    }
    return $built
}

# 另存一份带版本号与时间戳的副本：flutter 自己那份会被下次构建覆盖，
# 出问题时没法把「手上那一版」对回某次构建。
function Save-ApkArchive([string]$repoRoot, $built, [string]$flutterType, [string]$label, [string]$version) {
    $outDir = Join-Path $repoRoot 'build\apk'
    if (-not (Test-Path $outDir)) { New-Item -ItemType Directory -Path $outDir | Out-Null }
    $stamp = Get-Date -Format 'yyyyMMdd-HHmm'

    $archived = @()
    foreach ($f in $built) {
        # app-arm64-v8a-release.apk → arm64-v8a；app-debug.apk → 空
        $abi = $f.BaseName -replace '^app-', '' -replace "-?$flutterType$", ''
        $suffix = if ($abi) { "-$abi" } else { '' }
        $dest = Join-Path $outDir "traintrace-$label-$version$suffix-$stamp.apk"
        Copy-Item $f.FullName $dest -Force
        $archived += Get-Item $dest
    }
    return $archived
}

function Write-ApkSummary($archived) {
    Write-Host ''
    Write-Host 'OK: 构建完成' -ForegroundColor Green
    foreach ($a in $archived) {
        Write-Host ("  {0}  ({1:N1} MB)" -f $a.FullName, ($a.Length / 1MB))
    }
}

# 拆包时装 arm64-v8a 那个（近年的 Android 手机都是 arm64），单包时就它自己。
function Install-Apk([string]$adb, [string]$deviceId, $built) {
    $target = $built | Where-Object { $_.Name -like '*arm64-v8a*' } | Select-Object -First 1
    if (-not $target) { $target = $built[0] }

    Write-Host ''
    Write-Host "== adb install -r $($target.Name) → $deviceId ==" -ForegroundColor Cyan
    & $adb -s $deviceId install -r $target.FullName
    if ($LASTEXITCODE -ne 0) {
        Write-Host 'FAIL: 安装失败' -ForegroundColor Red
        Write-Host '常见原因：签名与机上已装版本不符（INSTALL_FAILED_UPDATE_INCOMPATIBLE）。'
        Write-Host "dev 包与 release 包签名不同时会撞上，先卸载再装（会清掉训练数据）："
        Write-Host "  adb -s $deviceId uninstall com.archinedai.traintrace"
        exit $LASTEXITCODE
    }
    Write-Host ''
    Write-Host "OK: 已装到 $deviceId" -ForegroundColor Green
}
