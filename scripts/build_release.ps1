<#
.SYNOPSIS
  对外分发用的 release 包（AOT 构建 + 签名检查）。

.DESCRIPTION
  给「发给别人试用」「上应用商店」用。相对 dev 包：Dart 代码 AOT 编译、去掉 JIT
  用的 kernel_blob 与调试符号，体积从一百多 MB 降到 60 出头。

  只产一个包，含全部 ABI（arm64-v8a / armeabi-v7a / x86_64），什么机器都能装。
  按 ABI 拆包能让每个包小一半多，但拆完就要回答「发哪个给谁」，而这个项目的分发
  就是把一个文件发出去 —— 省下的 40 MB 不值这份麻烦。

  签名：读 android/key.properties（该文件含密钥口令，在 .gitignore 里，不入库）。
  没有这个文件时 Gradle 回退到 debug 签名 —— 装机自测可以，但**不能上架**，也不能
  覆盖安装到装了正式版的手机上。本脚本会就此警告；-Force 跳过警告。首次生成密钥库
  见文末「怎么配签名」。

.PARAMETER Install
  构建成功后用 adb 装到设备。注意配了正式密钥后 release 与 dev 签名不同，机上装着
  dev 包时会安装失败，需要先卸载（会清掉训练数据）。

.PARAMETER Device
  adb 设备号。省略时自动选唯一在线设备。

.PARAMETER Obfuscate
  混淆 Dart 符号，调试符号另存到 build/symbols/<版本>/。上架前建议开；开了之后线上
  崩溃栈是乱码，必须留好这批符号文件才能还原。

.PARAMETER Force
  没配正式签名时也不警告直接构建。

.PARAMETER Clean
  构建前先 flutter clean。对外发的包建议带上，排除增量构建的脏产物。

.EXAMPLE
  powershell -File scripts/build_release.ps1
  powershell -File scripts/build_release.ps1 -Clean -Obfuscate

.NOTES
  怎么配签名（只做一次）：
    1. keytool -genkey -v -keystore %USERPROFILE%\traintrace-upload.jks `
         -keyalg RSA -keysize 2048 -validity 10000 -alias upload
    2. 新建 android/key.properties：
         storePassword=<口令>
         keyPassword=<口令>
         keyAlias=upload
         storeFile=C:/Users/<你>/traintrace-upload.jks
    3. 备份 .jks 与口令。密钥丢了就再也无法给已上架的应用发更新。
#>
param(
    [switch]$Install,
    [string]$Device,
    [switch]$Obfuscate,
    [switch]$Force,
    [switch]$Clean
)

$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path $PSScriptRoot -Parent
. (Join-Path $PSScriptRoot '_apk_common.ps1')

Push-Location $repoRoot
try {
    $version = Get-PubspecVersion $repoRoot

    # ---------- 签名检查 ----------
    # 放在构建之前：debug 签名的包发出去了才发现，收不回来。
    $keyProps = Join-Path $repoRoot 'android\key.properties'
    $signed = Test-Path $keyProps
    if (-not $signed) {
        Write-Host ''
        Write-Host 'WARN: 没有 android/key.properties，本次将用 debug 签名。' -ForegroundColor Yellow
        Write-Host '      debug 密钥是本机自动生成的，换台机器构建出的包签名就不一样：'
        Write-Host '      不能上架，也不能给用户做覆盖更新。仅供自己装机试跑。'
        Write-Host '      配置方法见 Get-Help scripts/build_release.ps1 -Full 的 NOTES。'
        if (-not $Force) {
            Write-Host ''
            $answer = Read-Host '仍要继续吗？(y/N)'
            if ($answer -ne 'y' -and $answer -ne 'Y') {
                Write-Host '已取消。'
                exit 1
            }
        }
    }

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

    $buildArgs = @('build', 'apk', '--release')
    if ($Obfuscate) {
        $symbols = Join-Path $repoRoot "build\symbols\$version"
        if (-not (Test-Path $symbols)) { New-Item -ItemType Directory -Path $symbols -Force | Out-Null }
        $buildArgs += @('--obfuscate', '--split-debug-info', $symbols)
    }

    $buildStart = Get-Date
    Write-Host "== flutter $($buildArgs -join ' ') （$version） ==" -ForegroundColor Cyan
    & flutter @buildArgs
    if ($LASTEXITCODE -ne 0) {
        Write-Host "FAIL: 构建失败（退出码 $LASTEXITCODE）" -ForegroundColor Red
        exit $LASTEXITCODE
    }

    $apk = Get-BuiltApk $repoRoot 'release' $buildStart
    $archived = Save-ApkArchive $repoRoot $apk 'release' $version
    Write-ApkSummary $archived

    Write-Host ''
    if ($signed) {
        Write-Host '签名：android/key.properties（正式）' -ForegroundColor Green
    }
    else {
        Write-Host '签名：debug（本机密钥，不可上架）' -ForegroundColor Yellow
    }
    if ($Obfuscate) {
        Write-Host "符号：build\symbols\$version（还原崩溃栈要用，别删）" -ForegroundColor Green
    }

    if ($Install) { Install-Apk $adb $deviceId $apk }
}
finally {
    Pop-Location
}
