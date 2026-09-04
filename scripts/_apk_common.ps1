<#
.SYNOPSIS
  build_dev.ps1 / build_release.ps1 共用的构建装机零件。

.DESCRIPTION
  自身不做任何事，只定义函数，由两个入口脚本 dot-source：

      . (Join-Path $PSScriptRoot '_apk_common.ps1')

  两个入口脚本的差别只在构建参数与签名要求，找 adb、选设备、归档、装机这些
  重复了就会两边漂移，收在这里。

  两种包都只产一个 APK 文件（dev 是 app-debug.apk，release 是含全部 ABI 的
  app-release.apk），所以这里一律按单文件处理。
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
#
# 要求文件是 $since 之后写的：flutter 不清理 flutter-apk 目录，构建万一没真正产出
# APK，同名的旧产物就会顶上来被归档、被装机，全程不报任何错。
function Get-BuiltApk([string]$repoRoot, [string]$flutterType, [datetime]$since) {
    $apk = Join-Path $repoRoot "build\app\outputs\flutter-apk\app-$flutterType.apk"
    if (-not (Test-Path $apk)) {
        throw "构建报成功但没有 $apk，产物路径可能变了。"
    }
    $f = Get-Item $apk
    # 减 5 秒容一下文件时间戳精度。
    if ($f.LastWriteTime -lt $since.AddSeconds(-5)) {
        throw "$apk 是本次构建之前的旧产物（$($f.LastWriteTime)）。构建没真正产出 APK，先跑 -Clean 再试。"
    }
    return $f
}

# 另存一份带版本号与时间戳的副本：flutter 自己那份会被下次构建覆盖，
# 出问题时没法把「手上那一版」对回某次构建。
function Save-ApkArchive([string]$repoRoot, $apk, [string]$label, [string]$version) {
    $outDir = Join-Path $repoRoot 'build\apk'
    if (-not (Test-Path $outDir)) { New-Item -ItemType Directory -Path $outDir | Out-Null }
    $stamp = Get-Date -Format 'yyyyMMdd-HHmm'
    $dest = Join-Path $outDir "traintrace-$label-$version-$stamp.apk"
    Copy-Item $apk.FullName $dest -Force
    return (Get-Item $dest)
}

function Write-ApkSummary($archived) {
    Write-Host ''
    Write-Host 'OK: 构建完成' -ForegroundColor Green
    Write-Host ("  {0}  ({1:N1} MB)" -f $archived.FullName, ($archived.Length / 1MB))
}

function Install-Apk([string]$adb, [string]$deviceId, $apk) {
    Write-Host ''
    Write-Host "== adb install -r $($apk.Name) → $deviceId ==" -ForegroundColor Cyan
    & $adb -s $deviceId install -r $apk.FullName
    if ($LASTEXITCODE -ne 0) {
        Write-Host 'FAIL: 安装失败' -ForegroundColor Red
        Write-Host '常见原因：签名与机上已装版本不符（INSTALL_FAILED_UPDATE_INCOMPATIBLE）。'
        Write-Host 'dev 包与配了正式密钥的 release 包签名不同，互相覆盖不了，先卸载再装（会清掉训练数据）：'
        Write-Host "  adb -s $deviceId uninstall com.archinedai.traintrace"
        exit $LASTEXITCODE
    }
    Write-Host ''
    Write-Host "OK: 已装到 $deviceId" -ForegroundColor Green
}
