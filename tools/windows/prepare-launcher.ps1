<#
.SYNOPSIS
  Gets this PC ready for launcher\build-and-install.ps1 and runs the safety checks. Changes nothing on the TV.
.DESCRIPTION
  1) JAVA_HOME and ANDROID_HOME, for this session and the user (permanent).
  2) launcher\local.properties with the SDK path, so Gradle finds an SDK outside %LOCALAPPDATA%.
  3) tools\venv with the repository's Python requirements.
  4) A connection test with tools\tv.py on port 5555 (USB debugging), the client the install script uses.
  5) Checks: who saved the Wi-Fi network (the setup wizard, setupwraith, would take it along if disabled)
     and which launcher owns Home now.
.EXAMPLE
  .\tools\windows\prepare-launcher.ps1 -TvHost 192.168.1.50
#>
[CmdletBinding()]
param(
    [string]$TvHost,
    [string]$JavaHome,
    [string]$AndroidSdk
)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot 'AdbTools.psm1') -Force

$repo = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
$py   = Join-Path $repo 'tools\venv\Scripts\python.exe'
$tv   = Join-Path $repo 'tools\tv.py'
$TvHost = (Get-TvHost $TvHost) -replace ':\d+$', ''   # tv.py always uses port 5555

function Invoke-Native([string]$Exe, [string[]]$Arguments) {
    $prev = $ErrorActionPreference; $ErrorActionPreference = 'Continue'
    try {
        $out  = @(& $Exe @Arguments 2>&1 | ForEach-Object { "$_" })
        $code = $LASTEXITCODE
    } finally { $ErrorActionPreference = $prev }
    [pscustomobject]@{ Code = $code; Text = ($out -join "`n").Trim() }
}
function Invoke-Tv([string]$Command) { Invoke-Native $py @('-I', $tv, $Command) }

# --- 0) Find the JDK and the SDK -------------------------------------------------------------
if (-not $JavaHome) {
    $JavaHome = @($env:JAVA_HOME) + @(Get-Item "$env:ProgramFiles\Java\jdk-17*", "$env:ProgramFiles\Microsoft\jdk-17*",
        "$env:ProgramFiles\Eclipse Adoptium\jdk-17*", "$env:ProgramFiles\Android\Android Studio\jbr" -ErrorAction SilentlyContinue |
        ForEach-Object FullName) | Where-Object { $_ -and (Test-Path (Join-Path $_ 'bin\java.exe')) } | Select-Object -First 1
}
if (-not $JavaHome) { throw 'No JDK 17 found: winget install --id Microsoft.OpenJDK.17 -e, or pass -JavaHome.' }
if (-not $AndroidSdk) {
    $adb = Find-Adb
    if ($adb) { $AndroidSdk = Split-Path (Split-Path $adb -Parent) -Parent }
}
if (-not $AndroidSdk -or -not (Test-Path $AndroidSdk)) { throw 'No Android SDK found: pass -AndroidSdk.' }
foreach ($need in 'build-tools\34.0.0', 'platforms\android-34') {
    if (-not (Test-Path (Join-Path $AndroidSdk $need))) {
        throw "Missing $need in $AndroidSdk. Run (as administrator if the SDK is under Program Files): sdkmanager `"$($need -replace '\\', ';')`""
    }
}

# --- 1) Environment variables ----------------------------------------------------------------
Write-Host '1) JAVA_HOME / ANDROID_HOME' -ForegroundColor Cyan
$env:JAVA_HOME = $JavaHome
$env:ANDROID_HOME = $AndroidSdk
[Environment]::SetEnvironmentVariable('JAVA_HOME', $JavaHome, 'User')
[Environment]::SetEnvironmentVariable('ANDROID_HOME', $AndroidSdk, 'User')
Write-Host "   $JavaHome | $AndroidSdk"

# --- 2) local.properties (git ignores it) ----------------------------------------------------
Write-Host '2) launcher\local.properties' -ForegroundColor Cyan
"sdk.dir=$(($AndroidSdk -replace '\\', '\\') -replace ':', '\:')" |
    Out-File -Encoding ascii (Join-Path $repo 'launcher\local.properties')

# --- 3) Python environment -------------------------------------------------------------------
Write-Host '3) tools\venv' -ForegroundColor Cyan
if (-not (Test-Path $py)) {
    $r = Invoke-Native 'python' @('-m', 'venv', (Join-Path $repo 'tools\venv'))
    if ($r.Code -ne 0) { throw "python -m venv failed: $($r.Text)" }
}
$r = Invoke-Native $py @('-m', 'pip', 'install', '-q', '-r', (Join-Path $repo 'tools\requirements.txt'))
if ($r.Code -ne 0) { throw "pip install failed: $($r.Text)" }

# --- 4) Connection on 5555 -------------------------------------------------------------------
$env:TV_HOST = $TvHost
Write-Host "4) Connecting to $TvHost`:5555 (accept 'Allow USB debugging?' on the TV if it asks)" -ForegroundColor Cyan
$r = Invoke-Tv '--probe'
if ($r.Code -ne 0) { Write-Host $r.Text -ForegroundColor Red; throw 'No connection: turn on USB debugging (Developer options) and try again.' }
Write-Host "   $($r.Text)" -ForegroundColor Green

# --- 5) Safety checks ------------------------------------------------------------------------
Write-Host '5) Safety checks' -ForegroundColor Cyan
$wifi  = (Invoke-Tv "dumpsys wifi | grep -o 'cname=[^ ]*' | sort -u").Text
$homeA = ((Invoke-Tv 'cmd package resolve-activity --brief -a android.intent.action.MAIN -c android.intent.category.HOME').Text -split "`n" | Select-Object -Last 1).Trim()
$wifiOk = $wifi -notmatch 'setupwraith'
Write-Host ("   Wi-Fi saved by: {0} -> {1}" -f ($wifi -replace "`n", ', '),
    $(if ($wifiOk) { 'OK' } else { 'the setup wizard: forget and re-join the network in Settings first' })) -ForegroundColor $(if ($wifiOk) { 'Green' } else { 'Red' })
Write-Host "   Home now: $homeA"
Write-Host ''
$next = 'Ready: run launcher\build-and-install.ps1 with the same TV address.'
if ($wifiOk) { Write-Host $next -ForegroundColor Green }
else         { Write-Host 'Not yet: fix what is marked above.' -ForegroundColor Red }
