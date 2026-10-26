<#
.SYNOPSIS
  Shows and sets what the TV does when nobody touches it: which screensaver, after how long, and when
  (if ever) it goes to sleep.
.DESCRIPTION
  Read-only by default: prints the current values. With -Apply it sets them and writes
  backup\reports\revert-screensaver-<date>.ps1.
  A common cause of a TV that keeps turning off: its screensaver app was disabled (the "ambient"
  com.google.android.backdrop is in most debloat lists) while screensaver_components still names it,
  so when the screensaver should start there is none and the screen goes off instead.
  - screensaver_components / screensaver_enabled: which screensaver, on or off
  - screen_off_timeout (system): idle time before the screensaver starts
  - sleep_timeout (secure): time before the TV goes to sleep; -1 never
  - attentive_timeout (secure): Android's "turn off when nobody is there" limit; -1 never
.EXAMPLE
  .\tools\windows\screensaver.ps1 -TvHost 192.168.1.50                                   # show
  .\tools\windows\screensaver.ps1 -TvHost 192.168.1.50 -Apply                            # clock after 10 min, sleep after 4 h
  .\tools\windows\screensaver.ps1 -TvHost 192.168.1.50 -Apply -StartAfterMinutes 5 -SleepAfterHours 0   # never sleep
#>
[CmdletBinding()]
param(
    [string]$TvHost,
    [string]$AdbPath,
    [string]$Component = 'com.gathin.tvhome/.ClockDream',
    [ValidateRange(1, 120)][int]$StartAfterMinutes = 10,
    [ValidateRange(0, 24)][int]$SleepAfterHours = 4,     # 0 = never
    [switch]$Apply
)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot 'AdbTools.psm1') -Force

$TvHost = Get-TvHost $TvHost
Initialize-Adb -Path $AdbPath
Connect-AdbDevice -Address $TvHost | Out-Null

$sleepMs = if ($SleepAfterHours -eq 0) { '-1' } else { [string]($SleepAfterHours * 3600000) }
$wanted = @(
    @{ Ns = 'secure'; Key = 'screensaver_components';         Value = $Component }
    @{ Ns = 'secure'; Key = 'screensaver_enabled';            Value = '1' }
    @{ Ns = 'secure'; Key = 'screensaver_activate_on_sleep';  Value = '1' }
    @{ Ns = 'system'; Key = 'screen_off_timeout';             Value = [string]($StartAfterMinutes * 60000) }
    @{ Ns = 'secure'; Key = 'sleep_timeout';                  Value = $sleepMs }
    @{ Ns = 'secure'; Key = 'attentive_timeout';              Value = $sleepMs }
)

function Format-Ms([string]$Value) {
    if ($Value -eq '-1') { return 'never' }
    if ($Value -match '^\d+$') { $m = [int64]$Value / 60000; return $(if ($m -ge 60) { '{0:0.#} h' -f ($m / 60) } else { "$m min" }) }
    return $Value
}

$pkg = ($Component -split '/')[0]
$installed = @(Get-AdbPackages) -contains $pkg
$disabled  = @(Get-AdbPackages -Flags '-d')
Write-Host "Screensaver app $pkg : $(if ($installed) { 'installed' } else { 'NOT INSTALLED' })" -ForegroundColor $(if ($installed) { 'Green' } else { 'Red' })
if (-not $installed) { throw "Install the launcher first (launcher\build-and-install.ps1)." }

$current = (Invoke-AdbShell -Command 'settings get secure screensaver_components').Text
$currentPkg = ($current -split '/')[0]
if ($current -and $current -ne 'null' -and $currentPkg -ne $pkg -and $disabled -contains $currentPkg) {
    Write-Host "The current screensaver ($current) is DISABLED: that is why the TV turns off instead." -ForegroundColor Yellow
}

$rows = [System.Collections.Generic.List[object]]::new()
$undo = [System.Collections.Generic.List[string]]::new()
foreach ($w in $wanted) {
    $now = (Invoke-AdbShell -Command "settings get $($w.Ns) $($w.Key)").Text
    $state = if ($now -eq $w.Value) { 'OK' } elseif ($Apply) { 'changed' } else { 'would change' }
    $show = if ($w.Key -like '*timeout') { { param($v) Format-Ms $v } } else { { param($v) $v } }
    $rows.Add([pscustomobject]@{ Setting = "$($w.Ns)/$($w.Key)"; Now = & $show $now; Wanted = & $show $w.Value; State = $state })
    if ($Apply -and $now -ne $w.Value) {
        # Quoted: the component name has a slash and a dot, safe, but keep the shell from splitting anything.
        Invoke-AdbShell -Command "settings put $($w.Ns) $($w.Key) '$($w.Value)'" | Out-Null
        if ($now -eq 'null') { $undo.Add("settings delete $($w.Ns) $($w.Key)") }
        else                 { $undo.Add("settings put $($w.Ns) $($w.Key) '$now'") }
    }
}
$rows | Format-Table -AutoSize -Wrap

if ($Apply -and $undo.Count) {
    $stamp  = Get-Date -Format 'yyyyMMdd-HHmmss'
    $revert = Join-Path (Get-ReportDir) ("revert-screensaver-$stamp" + '.ps1')
    $commands = ($undo | ForEach-Object { "    `"$_`"" }) -join ",`r`n"
    @"
<# Undoes what tools\windows\screensaver.ps1 applied at $stamp. Run this file with the TV address in -TvHost. #>
param([string]`$TvHost, [string]`$AdbPath)
Set-StrictMode -Version Latest
`$ErrorActionPreference = 'Stop'
Import-Module (Join-Path `$PSScriptRoot '..\..\tools\windows\AdbTools.psm1') -Force
Initialize-Adb -Path `$AdbPath
Connect-AdbDevice -Address (Get-TvHost `$TvHost) | Out-Null
foreach (`$c in @(
$commands
)) { Write-Host "`$c -> `$((Invoke-AdbShell -Command `$c -AllowFail).Text)" }
"@ | Set-Content -Path $revert -Encoding UTF8
    Write-Host "Revert script: $revert" -ForegroundColor Green
}
if (-not $Apply) { Write-Host 'Nothing changed. Add -Apply to set the values above.' -ForegroundColor Cyan }
else {
    Write-Host 'Done. Try it now from the TV: Settings > Device Preferences > Screen saver > Start now.' -ForegroundColor Green
}
