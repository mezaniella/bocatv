<#
.SYNOPSIS
  Disables bloat and telemetry, restricts background apps and tunes settings, with a revert script.
.DESCRIPTION
  A dry run by default: prints what it would do and changes nothing. With -Apply it makes the changes
  and writes backup\reports\revert-<date-time>.ps1, which undoes exactly what was changed (except
  'Uninstall', which only the Play Store can undo).
  Packages are disabled with 'pm disable-user', never uninstalled, so Settings > Apps can bring any
  of them back too.
  The list comes from local\optimize.psd1 when it exists, tools\windows\optimize.example.psd1 otherwise.
.EXAMPLE
  .\tools\windows\optimize.ps1 -TvHost 192.168.1.50                       # dry run
  .\tools\windows\optimize.ps1 -TvHost 192.168.1.50 -Apply                # Base group only
  .\tools\windows\optimize.ps1 -TvHost 192.168.1.50 -Apply -Include All -Optimize -Reboot
#>
[CmdletBinding()]
param(
    [string]$TvHost,
    [string]$Config,
    [string]$AdbPath,
    [switch]$Apply,
    # Optional groups from the config's Packages (comma-separated works with powershell -File), or All.
    [string[]]$Include = @(),
    [switch]$Optimize,   # recompile apps (bg-dexopt-job), 5-20 minutes
    [switch]$Reboot
)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot 'AdbTools.psm1') -Force

$repo = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
if (-not $Config) {
    $local = Join-Path $repo 'local\optimize.psd1'
    $Config = if (Test-Path $local) { $local } else { Join-Path $PSScriptRoot 'optimize.example.psd1' }
}
$cfg = Import-PowerShellDataFile $Config
function Get-List([string]$Key) { if ($cfg.ContainsKey($Key)) { @($cfg[$Key]) } else { @() } }

$optional = @($cfg.Packages.Keys | Where-Object { $_ -ne 'Base' })
$Include = @($Include | ForEach-Object { $_ -split ',' } | ForEach-Object { $_.Trim() } | Where-Object { $_ })
if ($Include -contains 'All') { $Include = $optional }
$unknown = @($Include | Where-Object { $optional -notcontains $_ })
if ($unknown.Count) { throw "Unknown group(s): $($unknown -join ', '). Groups: $($optional -join ', '), All" }

$stamp   = Get-Date -Format 'yyyyMMdd-HHmmss'
$results = [System.Collections.Generic.List[object]]::new()
$undo    = [System.Collections.Generic.List[string]]::new()
function Add-Result([string]$Kind, [string]$Target, [string]$State, [string]$Detail = '') {
    $results.Add([pscustomobject]@{ Kind = $Kind; Target = $Target; State = $State; Detail = $Detail })
}

$TvHost = Get-TvHost $TvHost
Initialize-Adb -Path $AdbPath
$serial = Connect-AdbDevice -Address $TvHost
$mode = if ($Apply) { 'APPLY' } else { 'DRY RUN (nothing changes; add -Apply)' }
Write-Host "Connected to $serial | Config: $Config | Mode: $mode" -ForegroundColor Cyan

$installed = [System.Collections.Generic.HashSet[string]]::new([string[]](Get-AdbPackages))
$disabled  = [System.Collections.Generic.HashSet[string]]::new([string[]](Get-AdbPackages -Flags '-d'))

# --- Disable ----------------------------------------------------------------------------------
foreach ($group in (@('Base') + $Include | Select-Object -Unique)) {
    foreach ($pkg in @($cfg.Packages[$group])) {
        $kind = "Disable/$group"
        if (-not $installed.Contains($pkg)) { Add-Result $kind $pkg 'Not installed'; continue }
        if ($disabled.Contains($pkg))       { Add-Result $kind $pkg 'Already disabled'; continue }
        if (-not $Apply)                    { Add-Result $kind $pkg 'Would disable'; continue }
        $r = Invoke-AdbShell -Command "pm disable-user --user 0 $pkg" -AllowFail
        if ($r.ExitCode -eq 0 -and $r.Text -match 'disabled') {
            Add-Result $kind $pkg 'Disabled'
            $undo.Add("pm enable --user 0 $pkg")
        } else {
            Add-Result $kind $pkg 'Refused' $r.Text
        }
    }
}

# --- Uninstall (not reversible by script) -----------------------------------------------------
foreach ($pkg in Get-List 'Uninstall') {
    if (-not $installed.Contains($pkg)) { Add-Result 'Uninstall' $pkg 'Not installed'; continue }
    if (-not $Apply)                    { Add-Result 'Uninstall' $pkg 'Would uninstall'; continue }
    $r = Invoke-AdbShell -Command "pm uninstall $pkg" -AllowFail
    Add-Result 'Uninstall' $pkg $(if ($r.Text -match 'Success') { 'Uninstalled' } else { 'Failed' }) $r.Text
}

# --- Remove for user 0 (reversible) -----------------------------------------------------------
foreach ($pkg in Get-List 'RemoveForUser') {
    if (-not $installed.Contains($pkg)) { Add-Result 'RemoveForUser' $pkg 'Already removed / not installed'; continue }
    if (-not $Apply)                    { Add-Result 'RemoveForUser' $pkg 'Would remove for user 0'; continue }
    Invoke-AdbShell -Command "am force-stop $pkg" -AllowFail | Out-Null
    $r = Invoke-AdbShell -Command "pm uninstall --user 0 $pkg" -AllowFail
    if ($r.Text -match 'Success') {
        Add-Result 'RemoveForUser' $pkg 'Removed'
        $undo.Add("cmd package install-existing --user 0 $pkg")
    } else {
        Add-Result 'RemoveForUser' $pkg 'Failed' $r.Text
    }
}

# --- No background work (appops, reversible) --------------------------------------------------
$bgOps = @('RUN_ANY_IN_BACKGROUND', 'RUN_IN_BACKGROUND')
$noBackground = Get-List 'NoBackground'
foreach ($pkg in $noBackground) {
    if (-not $installed.Contains($pkg)) { Add-Result 'NoBackground' $pkg 'Not installed'; continue }
    $current = (Invoke-AdbShell -Command "cmd appops get $pkg RUN_ANY_IN_BACKGROUND" -AllowFail).Text
    if ($current -match 'RUN_ANY_IN_BACKGROUND:\s*ignore') { Add-Result 'NoBackground' $pkg 'Already restricted'; continue }
    if (-not $Apply) { Add-Result 'NoBackground' $pkg 'Would restrict'; continue }
    $ok = $true
    foreach ($op in $bgOps) {
        $r = Invoke-AdbShell -Command "cmd appops set $pkg $op ignore" -AllowFail
        if ($r.ExitCode -ne 0) { $ok = $false; Add-Result 'NoBackground' "$pkg/$op" 'Failed' $r.Text }
        else { $undo.Add("cmd appops set $pkg $op default") }
    }
    Invoke-AdbShell -Command "am force-stop $pkg" -AllowFail | Out-Null
    if ($ok) { Add-Result 'NoBackground' $pkg 'Restricted' 'Runs only when opened' }
}
# AppOps reach disk with a delay: write them now so a reboot or a power cut does not lose them.
if ($Apply -and $noBackground.Count) {
    $r = Invoke-AdbShell -Command 'cmd appops write-settings' -AllowFail
    Add-Result 'NoBackground' 'appops write-settings' $(if ($r.ExitCode -eq 0) { 'Saved' } else { 'Failed' }) $r.Text
}

# --- Settings ---------------------------------------------------------------------------------
foreach ($s in Get-List 'Settings') {
    $target  = "$($s.Ns)/$($s.Key)"
    $current = (Invoke-AdbShell -Command "settings get $($s.Ns) $($s.Key)").Text
    if ($current -eq $s.Value) { Add-Result 'Setting' $target 'Already set' $s.Why; continue }
    if (-not $Apply)           { Add-Result 'Setting' $target "Would change $current -> $($s.Value)" $s.Why; continue }
    Invoke-AdbShell -Command "settings put $($s.Ns) $($s.Key) $($s.Value)" | Out-Null
    Add-Result 'Setting' $target "$current -> $($s.Value)" $s.Why
    if ($current -eq 'null') { $undo.Add("settings delete $($s.Ns) $($s.Key)") }
    else                     { $undo.Add("settings put $($s.Ns) $($s.Key) $current") }
}

# --- Maintenance ------------------------------------------------------------------------------
if ($Apply) {
    $r = Invoke-AdbShell -Command 'pm trim-caches 999G' -AllowFail
    Add-Result 'Maintenance' 'trim-caches' $(if ($r.ExitCode -eq 0) { 'OK' } else { 'Failed' }) $r.Text
    if ($Optimize) {
        Write-Host 'Recompiling apps (5-20 minutes, keep the TV on)...' -ForegroundColor Yellow
        $r = Invoke-AdbShell -Command 'cmd package bg-dexopt-job' -AllowFail
        Add-Result 'Maintenance' 'bg-dexopt-job' $(if ($r.ExitCode -eq 0) { 'OK' } else { 'Failed' }) $r.Text
    }
}

# --- Revert script ----------------------------------------------------------------------------
$reports = Get-ReportDir
if ($Apply -and $undo.Count) {
    $revert = Join-Path $reports "revert-$stamp.ps1"
    $commands = ($undo | ForEach-Object { "    '$_'" }) -join ",`r`n"
    @"
<# Undoes what tools\windows\optimize.ps1 changed at $stamp. Usage: .\revert-$stamp.ps1 -TvHost <tv ip> #>
param([string]`$TvHost, [string]`$AdbPath)
Set-StrictMode -Version Latest
`$ErrorActionPreference = 'Stop'
Import-Module (Join-Path `$PSScriptRoot '..\..\tools\windows\AdbTools.psm1') -Force
`$TvHost = Get-TvHost `$TvHost
Initialize-Adb -Path `$AdbPath
Connect-AdbDevice -Address `$TvHost | Out-Null
`$commands = @(
$commands
)
foreach (`$c in `$commands) {
    `$r = Invoke-AdbShell -Command `$c -AllowFail
    Write-Host "`$c -> `$(`$r.Text)"
}
Write-Host 'Reverted. Restart the TV.' -ForegroundColor Green
"@ | Set-Content -Path $revert -Encoding UTF8
    Write-Host "Revert script: $revert" -ForegroundColor Green
}

$csv = Join-Path $reports "optimize-$stamp.csv"
$results | Export-Csv -Path $csv -NoTypeInformation -Encoding UTF8
$results | Format-Table -AutoSize -Wrap
Write-Host "Details: $csv"

if ($Apply -and $Reboot) {
    Write-Host 'Rebooting the TV...' -ForegroundColor Yellow
    Restart-AdbDevice
}
