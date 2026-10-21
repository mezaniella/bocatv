<#
.SYNOPSIS
  Read-only snapshot of an Android TV over adb: properties, packages, memory, storage, processes, settings.
.DESCRIPTION
  Changes nothing on the TV. Writes one text file per query to backup\reports\<date-time>\ at the
  repository root (git ignores backup\: these files hold serials and device names).
  Run it before and after a debloat to compare memory.
.EXAMPLE
  .\tools\windows\diagnose.ps1 -TvHost 192.168.1.50
  .\tools\windows\diagnose.ps1 -TvHost 192.168.1.50:<port> -PairAddress 192.168.1.50:<pair port> -PairCode <code>
#>
[CmdletBinding()]
param(
    [string]$TvHost,        # IP or IP:port; no port means 5555 (USB debugging)
    [string]$PairAddress,   # wireless debugging, first time only: the IP:port of "Pair with code"
    [string]$PairCode,
    [string]$AdbPath
)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot 'AdbTools.psm1') -Force

$TvHost = Get-TvHost $TvHost
Initialize-Adb -Path $AdbPath
if ($PairAddress -and $PairCode) {
    Write-Host "Pairing with $PairAddress ..."
    (Invoke-AdbRaw -Arguments @('pair', $PairAddress, $PairCode) -AllowFail).Text | Write-Host
}
$serial = Connect-AdbDevice -Address $TvHost
Write-Host "Connected: $serial" -ForegroundColor Green

$outDir = Join-Path (Get-ReportDir) (Get-Date -Format 'yyyyMMdd-HHmmss')
New-Item -ItemType Directory -Force -Path $outDir | Out-Null

$queries = [ordered]@{
    'props.txt'              = 'getprop'
    'packages-all.txt'       = 'pm list packages -f'
    'packages-system.txt'    = 'pm list packages -s'
    'packages-thirdparty.txt'= 'pm list packages -3'
    'packages-disabled.txt'  = 'pm list packages -d'
    'memory.txt'             = 'dumpsys meminfo'
    'storage.txt'            = 'df -h'
    'processes.txt'          = 'ps -A -o PID,RSS,NAME'
    'settings-global.txt'    = 'settings list global'
    'settings-secure.txt'    = 'settings list secure'
    'settings-system.txt'    = 'settings list system'
}
foreach ($name in $queries.Keys) {
    Write-Host "  -> $name"
    $r = Invoke-AdbShell -Command $queries[$name] -AllowFail
    $r.Output | Out-File -FilePath (Join-Path $outDir $name) -Encoding utf8
}

$model   = (Invoke-AdbShell -Command 'getprop ro.product.model').Text
$android = (Invoke-AdbShell -Command 'getprop ro.build.version.release').Text
$total   = @(Get-Content (Join-Path $outDir 'packages-all.txt')).Count
$ram     = (Get-Content (Join-Path $outDir 'memory.txt') | Select-String -Pattern 'Total RAM|Free RAM|Used RAM' |
            ForEach-Object { $_.Line.Trim() }) -join "`n"
Write-Host ""
Write-Host "Model: $model | Android: $android | Packages: $total" -ForegroundColor Green
Write-Host $ram
Write-Host "Report: $outDir" -ForegroundColor Green
