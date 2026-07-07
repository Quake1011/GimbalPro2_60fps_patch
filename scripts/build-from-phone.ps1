[CmdletBinding()]
param(
    [string]$Package = "com.jxrobot.android.smoothcam",
    [string]$WorkDir = (Join-Path (Resolve-Path (Join-Path $PSScriptRoot "..")).Path "work"),
    [Parameter(Mandatory = $true)]
    [string]$Apktool,
    [Parameter(Mandatory = $true)]
    [string]$SignerJar,
    [switch]$Install,
    [switch]$ForceUninstall,
    [switch]$SkipUiText
)

$ErrorActionPreference = "Stop"

function Invoke-Checked {
    param(
        [Parameter(Mandatory = $true)][string]$FilePath,
        [Parameter(Mandatory = $true)][string[]]$Arguments
    )

    & $FilePath @Arguments
    if ($LASTEXITCODE -ne 0) {
        throw "Command failed ($LASTEXITCODE): $FilePath $($Arguments -join ' ')"
    }
}

function Get-ApkInstallList {
    param([Parameter(Mandatory = $true)][string]$Directory)

    $base = Join-Path $Directory "base.apk"
    if (-not (Test-Path -LiteralPath $base)) {
        throw "Signed base.apk not found: $base"
    }

    $splits = Get-ChildItem -LiteralPath $Directory -Filter "split_*.apk" | Sort-Object Name
    return @($base) + @($splits | ForEach-Object { $_.FullName })
}

if (-not (Get-Command adb -ErrorAction SilentlyContinue)) {
    throw "adb not found in PATH."
}

if (-not (Test-Path -LiteralPath $Apktool)) {
    throw "apktool not found: $Apktool"
}

if (-not (Test-Path -LiteralPath $SignerJar)) {
    throw "Signer jar not found: $SignerJar"
}

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$patchScript = Join-Path $PSScriptRoot "patch-decompiled.ps1"
$workRoot = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($WorkDir)
$originalDir = Join-Path $workRoot "original_from_phone"
$decodedDir = Join-Path $workRoot "base_src"
$unsignedBase = Join-Path $workRoot "base_60fps_unsigned.apk"
$signedDir = Join-Path $workRoot "signed"

New-Item -ItemType Directory -Force -Path $workRoot, $originalDir, $signedDir | Out-Null

Write-Host "Pulling installed APK set for $Package..."
$remotePaths = adb shell pm path $Package |
    ForEach-Object { $_.Trim() } |
    Where-Object { $_ -like "package:*" } |
    ForEach-Object { $_ -replace '^package:', '' }

if (-not $remotePaths -or $remotePaths.Count -eq 0) {
    throw "Package is not installed or adb cannot read paths: $Package"
}

foreach ($remotePath in $remotePaths) {
    $fileName = Split-Path $remotePath -Leaf
    $target = Join-Path $originalDir $fileName
    Invoke-Checked -FilePath "adb" -Arguments @("pull", $remotePath, $target)
}

$baseApk = Join-Path $originalDir "base.apk"
if (-not (Test-Path -LiteralPath $baseApk)) {
    throw "base.apk was not pulled from device."
}

Write-Host "Decoding base.apk with raw resources..."
Invoke-Checked -FilePath $Apktool -Arguments @("d", "-r", $baseApk, "-o", $decodedDir, "-f")

Write-Host "Applying 60 fps patch..."
$patchArgs = @("-ExecutionPolicy", "Bypass", "-File", $patchScript, "-ApktoolProject", $decodedDir)
if ($SkipUiText) {
    $patchArgs += "-SkipUiText"
}
Invoke-Checked -FilePath "powershell" -Arguments $patchArgs

Write-Host "Building patched base.apk..."
Invoke-Checked -FilePath $Apktool -Arguments @("b", $decodedDir, "-o", $unsignedBase)

Write-Host "Preparing split APK set for signing..."
Remove-Item -LiteralPath $signedDir -Recurse -Force -ErrorAction SilentlyContinue
New-Item -ItemType Directory -Force -Path $signedDir | Out-Null

Copy-Item -LiteralPath $unsignedBase -Destination (Join-Path $signedDir "base.apk") -Force
Get-ChildItem -LiteralPath $originalDir -Filter "split_*.apk" |
    ForEach-Object { Copy-Item -LiteralPath $_.FullName -Destination (Join-Path $signedDir $_.Name) -Force }

Write-Host "Signing APK set..."
Invoke-Checked -FilePath "java" -Arguments @("-jar", $SignerJar, "--apks", $signedDir, "--overwrite", "--allowResign")

$apkInstallList = Get-ApkInstallList -Directory $signedDir
Write-Host "Signed APK set:"
$apkInstallList | ForEach-Object { Write-Host "  $_" }

if ($Install) {
    Write-Host "Installing APK set..."
    & adb @(@("install-multiple", "-r", "--no-incremental") + $apkInstallList)
    $installExit = $LASTEXITCODE

    if ($installExit -ne 0 -and $ForceUninstall) {
        Write-Host "Update failed. Uninstalling $Package and retrying because -ForceUninstall was provided..."
        Invoke-Checked -FilePath "adb" -Arguments @("uninstall", $Package)
        Invoke-Checked -FilePath "adb" -Arguments (@("install-multiple", "--no-incremental") + $apkInstallList)
    } elseif ($installExit -ne 0) {
        throw "Install failed. If this is a signature mismatch, rerun with -ForceUninstall."
    }
}

Write-Host "Done. Local output: $signedDir"
