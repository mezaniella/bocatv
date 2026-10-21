<#
.SYNOPSIS
  After installing the launcher: who owns Home, what is disabled, memory and the biggest processes. Read-only.
.EXAMPLE
  .\tools\windows\verify-launcher.ps1 -TvHost 192.168.1.50
#>
[CmdletBinding()]
param([string]$TvHost, [string]$AdbPath)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot 'AdbTools.psm1') -Force

$TvHost = Get-TvHost $TvHost
Initialize-Adb -Path $AdbPath
Connect-AdbDevice -Address $TvHost | Out-Null

# Single quotes only inside the commands: Windows PowerShell 5.1 drops embedded double quotes from native arguments.
$checks = [ordered]@{
    'Home'                  = 'cmd package resolve-activity --brief -a android.intent.action.MAIN -c android.intent.category.HOME | tail -n 1'
    'Launcher version'      = "dumpsys package com.gathin.tvhome | grep -E 'versionName|lastUpdateTime' | head -n 2"
    'Disabled launchers'    = "pm list packages -d | grep -E 'tvlauncher|launcherx|tvrecommendations|setupwraith' || echo '(none)'"
    'Accessibility'         = 'settings get secure enabled_accessibility_services'
    'Launcher language'     = 'cmd locale get-app-locales com.gathin.tvhome'
    'RAM'                   = "dumpsys meminfo | grep -E 'Total RAM|Free RAM|Used RAM|ZRAM'"
    'Top processes'         = "dumpsys meminfo | sed -n '/Total PSS by process/,/Total PSS by OOM/p' | head -n 20"
}
$log = Join-Path (Get-ReportDir) ("verify-launcher-{0}.txt" -f (Get-Date -Format 'yyyyMMdd-HHmmss'))
foreach ($name in $checks.Keys) {
    $block = "`n=== $name ===`n$((Invoke-AdbShell -Command $checks[$name] -AllowFail).Text)"
    Write-Host $block
    $block | Add-Content $log -Encoding UTF8
}
Write-Host "`nSaved: $log" -ForegroundColor Green
