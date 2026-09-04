<#
.SYNOPSIS
  日常真机自测用的 dev 包（debug 构建 + 装机）。

.DESCRIPTION
  给「改一行代码，上手机看一眼」用。带调试横幅、可断点、可热重载后再装。
  要给别人试用或上架，用 scripts/build_release.ps1。

  默认只打 arm64-v8a。debug 包的体积大头是 libflutter.so（三个 ABI 各 33~40 MB）
  和 kernel_blob.bin（JIT 用的未优化 Dart 代码，一百多 MB，debug 模式没法去掉）。
  只留手机实际用得上的那个 ABI 能省掉 70 MB 左右；剩下的体积是 debug 的固有代价，
  嫌大就用 release 包（十几 MB）。

  真机验证（休息提醒、进程被杀恢复）只认这条路径 —— 模拟器不算，见 CLAUDE.md。

.PARAMETER Install
  构建成功后用 adb 装到设备（-r 覆盖安装，保留库里的训练数据）。

.PARAMETER Device
  adb 设备号。省略时自动选唯一在线设备；接了多台会报错并列出候选。

.PARAMETER Profile
  改用 profile 构建：AOT + 性能追踪，测卡顿 / 掉帧用。不能热重载。

.PARAMETER AllAbi
  打全部 ABI。只有要装到 x86_64 模拟器或老的 32 位机器时才需要。

.PARAMETER Clean
  构建前先 flutter clean。只在产物疑似脏了（换分支、改 gradle、换 Flutter 版本）时用。

.EXAMPLE
  powershell -File scripts/build_dev.ps1 -Install
  powershell -File scripts/build_dev.ps1 -Profile -Install
#>
param(
    [switch]$Install,
    [string]$Device,
    [Alias('Profile')][switch]$ProfileMode,
    [switch]$AllAbi,
    [switch]$Clean
)

$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path $PSScriptRoot -Parent
. (Join-Path $PSScriptRoot '_apk_common.ps1')

Push-Location $repoRoot
try {
    $flutterType = if ($ProfileMode) { 'profile' } else { 'debug' }
    $label = if ($ProfileMode) { 'profile' } else { 'dev' }
    $version = Get-PubspecVersion $repoRoot

    # 装机要先确认设备在场，别等构建完几分钟才发现线没插。
    $adb = $null
    $deviceId = $null
    if ($Install) {
        $adb = Resolve-Adb $repoRoot
        $deviceId = Resolve-Device $adb $Device
        Write-Host "设备：$deviceId" -ForegroundColor Cyan
    }

    if ($Clean) {
        Write-Host '== flutter clean ==' -ForegroundColor Cyan
        flutter clean
        if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
    }

    $buildArgs = @('build', 'apk', "--$flutterType")
    if (-not $AllAbi) { $buildArgs += @('--target-platform', 'android-arm64') }

    $buildStart = Get-Date
    Write-Host "== flutter $($buildArgs -join ' ') ==" -ForegroundColor Cyan
    & flutter @buildArgs
    if ($LASTEXITCODE -ne 0) {
        Write-Host "FAIL: 构建失败（退出码 $LASTEXITCODE）" -ForegroundColor Red
        exit $LASTEXITCODE
    }

    $apk = Get-BuiltApk $repoRoot $flutterType $buildStart
    $archived = Save-ApkArchive $repoRoot $apk $label $version
    Write-ApkSummary $archived

    if ($Install) { Install-Apk $adb $deviceId $apk }
}
finally {
    Pop-Location
}
