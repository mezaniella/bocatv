<#
.SYNOPSIS
  Checks this PC can build the launcher: JDK 17+, Android SDK platform 34, build-tools 34.0.0, Python, Git.
  Read-only; needs no TV.
#>
[CmdletBinding()]
param([string]$SdkRoot)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Continue'

$results = [System.Collections.Generic.List[object]]::new()
function Add-Check([string]$Item, [bool]$Ok, [string]$Detail) {
    $results.Add([pscustomobject]@{ Item = $Item; State = $(if ($Ok) { 'OK' } else { 'MISSING' }); Detail = $Detail })
}

function Get-JavaMajor([string]$JavaExe) {
    $out = (& $JavaExe -version 2>&1 | ForEach-Object { "$_" }) -join ' '
    if ($out -match 'version "(\d+)(\.(\d+))?') {
        $major = [int]$Matches[1]
        if ($major -eq 1 -and $Matches[3]) { $major = [int]$Matches[3] }   # 1.8 style
        return $major
    }
    return 0
}

# --- JDK -------------------------------------------------------------------------------------
$javas = [System.Collections.Generic.List[string]]::new()
$cmd = Get-Command java -ErrorAction SilentlyContinue
if ($cmd) { $javas.Add($cmd.Source) }
if ($env:JAVA_HOME) { $javas.Add((Join-Path $env:JAVA_HOME 'bin\java.exe')) }
foreach ($pattern in @("$env:ProgramFiles\Android\Android Studio\jbr\bin\java.exe",
                       "$env:ProgramFiles\Eclipse Adoptium\*\bin\java.exe",
                       "$env:ProgramFiles\Java\*\bin\java.exe",
                       "$env:ProgramFiles\Microsoft\jdk-*\bin\java.exe",
                       "$env:ProgramFiles\Zulu\*\bin\java.exe",
                       "$env:LOCALAPPDATA\Programs\Android Studio\jbr\bin\java.exe")) {
    Get-Item $pattern -ErrorAction SilentlyContinue | ForEach-Object { $javas.Add($_.FullName) }
}
$jdk17 = $null
foreach ($java in ($javas | Where-Object { Test-Path $_ } | Select-Object -Unique)) {
    $major = Get-JavaMajor $java
    Write-Host ("Java: {0} -> {1}" -f $java, $major)
    if (-not $jdk17 -and $major -ge 17) { $jdk17 = $java }
}
Add-Check 'JDK 17+' ([bool]$jdk17) $(if ($jdk17) { $jdk17 } else { 'winget install --id Microsoft.OpenJDK.17 -e' })
Add-Check 'JAVA_HOME' ([bool]$env:JAVA_HOME) $(if ($env:JAVA_HOME) { $env:JAVA_HOME } else { 'not set' })

# --- Android SDK -----------------------------------------------------------------------------
$sdks = @($SdkRoot, $env:ANDROID_HOME, $env:ANDROID_SDK_ROOT, "$env:LOCALAPPDATA\Android\Sdk",
          "${env:ProgramFiles(x86)}\Android\android-sdk", "$env:ProgramFiles\Android\android-sdk") |
        Where-Object { $_ -and (Test-Path $_) } | Select-Object -Unique
foreach ($sdk in $sdks) {
    $platforms = @(Get-ChildItem (Join-Path $sdk 'platforms') -Directory -ErrorAction SilentlyContinue | ForEach-Object Name)
    $buildTools = @(Get-ChildItem (Join-Path $sdk 'build-tools') -Directory -ErrorAction SilentlyContinue | ForEach-Object Name)
    $sdkmanager = @(Get-ChildItem (Join-Path $sdk 'cmdline-tools') -Recurse -Filter 'sdkmanager.bat' -ErrorAction SilentlyContinue)
    Add-Check "platform android-34 ($sdk)" ($platforms -contains 'android-34') ("installed: " + ($platforms -join ', '))
    Add-Check "build-tools 34.0.0 ($sdk)" ($buildTools -contains '34.0.0') ("installed: " + ($buildTools -join ', '))
    Add-Check "sdkmanager ($sdk)" ($sdkmanager.Count -gt 0) $(if ($sdkmanager.Count) { $sdkmanager[0].FullName } else { 'no cmdline-tools' })
}
if (-not $sdks) { Add-Check 'Android SDK' $false 'not found; set ANDROID_HOME or pass -SdkRoot' }
Add-Check 'ANDROID_HOME' ([bool]$env:ANDROID_HOME) $(if ($env:ANDROID_HOME) { $env:ANDROID_HOME } else { 'not set (launcher\local.properties also works)' })

# --- Python and Git --------------------------------------------------------------------------
foreach ($tool in 'python', 'git') {
    $c = Get-Command $tool -ErrorAction SilentlyContinue
    $version = if ($c) { ((& $c.Source --version 2>&1) -join ' ') } else { 'not installed' }
    if ($tool -eq 'python' -and $version -match 'Microsoft Store') { $c = $null }
    Add-Check $tool ([bool]$c) $version
}

$results | Format-Table -AutoSize -Wrap
