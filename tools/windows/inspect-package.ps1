<#
.SYNOPSIS
  Why does a package come back or start on its own? State, last caller that changed it, boot receivers,
  background permissions, who started it. Read-only.
.DESCRIPTION
  Run it a couple of minutes after a reboot without opening the app, so the log still holds the start.
  'lastDisabledCaller' names the package that last enabled or disabled it: if a system service keeps
  enabling a disabled app, 'RemoveForUser' in optimize.ps1 is the way out.
.EXAMPLE
  .\tools\windows\inspect-package.ps1 -TvHost 192.168.1.50 -Package com.netflix.ninja
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)][ValidatePattern('^[A-Za-z0-9_.]+$')][string]$Package,
    [string]$TvHost,
    [string]$AdbPath
)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot 'AdbTools.psm1') -Force

$TvHost = Get-TvHost $TvHost
Initialize-Adb -Path $AdbPath
Connect-AdbDevice -Address $TvHost | Out-Null

$p = $Package
$checks = [ordered]@{
    'Disabled?'               = "pm list packages -d | grep -x 'package:$p' || echo 'not disabled'"
    'State and last caller'   = "dumpsys package $p | grep -E 'User 0:|enabled=|lastDisabledCaller|installed=|hidden=|stopped='"
    'Install and versions'    = "dumpsys package $p | grep -E 'codePath|versionName|installerPackageName|firstInstallTime|lastUpdateTime|pkgFlags' | sort -u"
    'Boot receivers'          = "dumpsys package $p | grep -iE 'BOOT_COMPLETED|LOCKED_BOOT|PACKAGE_REPLACED|MY_PACKAGE' | sort -u || echo '(none)'"
    'Background permissions'  = "cmd appops get $p RUN_ANY_IN_BACKGROUND; cmd appops get $p RUN_IN_BACKGROUND; am get-standby-bucket $p"
    'Running?'                = "ps -A -o PID,NAME | grep -F '$p' || echo '(not running)'"
    'Log: state changes'      = "logcat -d -b all 2>/dev/null | grep -F '$p' | grep -iE 'enable|disable|setEnabled|install|uninstall' | tail -n 30 || echo '(none)'"
    'Log: who started it'     = "logcat -d -b all 2>/dev/null | grep -E 'ActivityManager' | grep -F '$p' | grep -iE 'Start proc|bind|provider|broadcast|service' | tail -n 20 || echo '(none)'"
    'Bound by'                = "dumpsys activity processes $p | grep -iE 'adjType|adjSource|adjTarget|Connections|ProviderRecord|bound' | head -n 25"
}
$log = Join-Path (Get-ReportDir) ("inspect-$p-{0}.txt" -f (Get-Date -Format 'yyyyMMdd-HHmmss'))
foreach ($name in $checks.Keys) {
    $block = "`n=== $name ===`n$((Invoke-AdbShell -Command $checks[$name] -AllowFail).Text)"
    Write-Host $block
    $block | Add-Content $log -Encoding UTF8
}
Write-Host "`nSaved: $log" -ForegroundColor Green
