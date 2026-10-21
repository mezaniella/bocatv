<#
  AdbTools.psm1 - adb access shared by the scripts in tools\windows.
  One job: find adb, connect to the TV and run commands on it. Nothing here knows about debloat
  lists or themes.
#>
Set-StrictMode -Version Latest

$script:AdbPath = $null
$script:Serial  = $null

function Find-Adb {
    <# adb.exe from -Path, PATH, ANDROID_HOME, ANDROID_SDK_ROOT or the usual SDK folders; $null if none. #>
    [CmdletBinding()]
    param([string]$Path)
    if ($Path) { if (Test-Path $Path) { return (Resolve-Path $Path).Path } else { return $null } }
    $cmd = Get-Command adb -ErrorAction SilentlyContinue
    if ($cmd) { return $cmd.Source }
    $roots = @($env:ANDROID_HOME, $env:ANDROID_SDK_ROOT, (Join-Path $env:LOCALAPPDATA 'Android\Sdk'),
               (Join-Path ${env:ProgramFiles(x86)} 'Android\android-sdk'), (Join-Path $env:ProgramFiles 'Android\android-sdk'))
    foreach ($root in $roots | Where-Object { $_ }) {
        $candidate = Join-Path $root 'platform-tools\adb.exe'
        if (Test-Path $candidate) { return $candidate }
    }
    return $null
}

function Get-TvHost {
    <# The TV address from -TvHost or $env:TV_HOST; throws when neither is set. #>
    [CmdletBinding()]
    param([string]$TvHost)
    if (-not $TvHost) { $TvHost = $env:TV_HOST }
    if (-not $TvHost) { throw 'Pass -TvHost <tv ip>[:port] or set $env:TV_HOST.' }
    return $TvHost
}

function Get-ReportDir {
    <# backup\reports at the repository root: git ignores backup\, so dumps with serials and names stay local. #>
    [CmdletBinding()]
    param()
    $dir = Join-Path (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent) 'backup\reports'
    New-Item -ItemType Directory -Force -Path $dir | Out-Null
    return $dir
}

function Invoke-AdbRaw {
    <# Runs adb. Windows PowerShell 5.1 turns a native command's stderr into errors, so success is the exit code. #>
    [CmdletBinding()]
    param([Parameter(Mandatory)][string[]]$Arguments, [switch]$AllowFail)
    $prev = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try {
        $out  = @(& $script:AdbPath @Arguments 2>&1 | ForEach-Object { "$_".Trim([char]0xFEFF) })
        $code = $LASTEXITCODE
    } finally {
        $ErrorActionPreference = $prev
    }
    if ($code -ne 0 -and -not $AllowFail) {
        throw "adb $($Arguments -join ' ') failed ($code): $($out -join ' ')"
    }
    [pscustomobject]@{ ExitCode = $code; Output = $out; Text = ($out -join "`n").Trim() }
}

function Initialize-Adb {
    [CmdletBinding()]
    param([string]$Path)
    $found = Find-Adb -Path $Path
    if (-not $found) { throw 'adb not found. Install Android platform-tools, add them to PATH or pass -AdbPath.' }
    $script:AdbPath = $found
    Invoke-AdbRaw -Arguments @('start-server') -AllowFail | Out-Null
}

function Connect-AdbDevice {
    <#
      Connects to host[:port] (5555 when no port is given: USB debugging's fixed network port).
      Also accepts a device that is already connected, by IP or by its wireless-debugging mDNS name,
      and the address wireless debugging announces over mDNS, since its port changes on every reboot.
    #>
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$Address, [int]$Retries = 3)
    if ($Address -notmatch ':\d+$') { $Address = "${Address}:5555" }
    $ip = ($Address -split ':')[0]

    for ($i = 1; $i -le $Retries; $i++) {
        foreach ($line in (Invoke-AdbRaw -Arguments @('devices') -AllowFail).Output) {
            if ($line -match '^(\S+)\s+device$' -and ($Matches[1] -like "$ip*" -or $Matches[1] -like 'adb-*')) {
                $script:Serial = $Matches[1]
                return $script:Serial
            }
        }
        $candidates = @($Address)
        foreach ($line in (Invoke-AdbRaw -Arguments @('mdns', 'services') -AllowFail).Output) {
            if ($line -match '_adb-tls-connect\._tcp\S*\s+(\d+\.\d+\.\d+\.\d+:\d+)' -and $Matches[1] -like "$ip`:*") {
                if ($candidates -notcontains $Matches[1]) { $candidates += $Matches[1] }
            }
        }
        foreach ($candidate in $candidates) {
            $r = Invoke-AdbRaw -Arguments @('connect', $candidate) -AllowFail
            if ($r.Text -match 'connected to|already connected') {
                $script:Serial = $candidate
                return $script:Serial
            }
        }
        Start-Sleep -Seconds 2
    }
    throw "Could not connect to $Address. Turn on USB debugging (port 5555) or pass the IP:port wireless debugging shows."
}

function Invoke-AdbShell {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$Command, [switch]$AllowFail)
    if (-not $script:Serial) { throw 'No device connected (Connect-AdbDevice).' }
    Invoke-AdbRaw -Arguments @('-s', $script:Serial, 'shell', $Command) -AllowFail:$AllowFail
}

function Get-AdbPackages {
    <# Package names from 'pm list packages', e.g. -Flags '-d' for disabled ones. #>
    [CmdletBinding()]
    param([string]$Flags = '')
    $r = Invoke-AdbShell -Command "pm list packages $Flags".Trim()
    @($r.Output | ForEach-Object { $_.Trim() } | Where-Object { $_ -like 'package:*' } | ForEach-Object { $_.Substring(8) })
}

function Restart-AdbDevice {
    <#
      An orderly reboot through PowerManager, so the framework writes appops and settings to disk first.
      'adb reboot' cuts power without that and can lose changes made seconds before.
    #>
    [CmdletBinding()]
    param()
    $r = Invoke-AdbShell -Command 'svc power reboot' -AllowFail
    if ($r.ExitCode -ne 0) {
        Invoke-AdbShell -Command 'cmd appops write-settings' -AllowFail | Out-Null
        Invoke-AdbRaw -Arguments @('-s', $script:Serial, 'reboot') -AllowFail | Out-Null
    }
}

Export-ModuleMember -Function Find-Adb, Get-TvHost, Get-ReportDir, Invoke-AdbRaw, Initialize-Adb, Connect-AdbDevice,
    Invoke-AdbShell, Get-AdbPackages, Restart-AdbDevice
