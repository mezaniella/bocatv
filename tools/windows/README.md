# Windows tools

PowerShell scripts (Windows PowerShell 5.1 or PowerShell 7) for diagnosing, debloating and checking an
Android TV / Google TV over ADB, and for getting a PC ready to build the launcher. Run them from the
repository root:

```
powershell -ExecutionPolicy Bypass -File tools\windows\<script>.ps1 -TvHost <tv ip>
```

- **`-TvHost`** is the TV's IP, optionally with a port. Without a port the scripts use 5555, the fixed
  port USB debugging opens on most TVs; with wireless debugging pass the IP:port it shows (that port
  changes on every reboot). `$env:TV_HOST` works instead of `-TvHost`.
- **adb** is found on PATH, in `ANDROID_HOME` / `ANDROID_SDK_ROOT`, `%LOCALAPPDATA%\Android\Sdk` or
  `Program Files\Android\android-sdk`; `-AdbPath` overrides it.
- **Everything they write** goes to `backup\reports\` at the repository root. Git ignores `backup\`:
  those files hold serial numbers, device names and the TV's settings.
- Read-only scripts change nothing on the TV. `optimize.ps1` changes nothing without `-Apply`.

| Script | Changes the TV? | What it does |
|---|---|---|
| `diagnose.ps1` | No | Properties, all/system/third-party/disabled packages, memory, storage, processes and settings, one file each. Pairs first with `-PairAddress` and `-PairCode` (wireless debugging, Android 11+). Run it before and after a debloat to compare. |
| `optimize.ps1` | With `-Apply` | Disables packages (`pm disable-user`), uninstalls your own apps, removes stubborn system apps for user 0, stops streaming apps from running in the background, applies settings (animations at 0.5x, no crash reports, no background scans, optional ad-blocking Private DNS), trims caches, optionally recompiles apps (`-Optimize`) and reboots in an orderly way (`-Reboot`). Writes `revert-<date>.ps1` that undoes all of it except uninstalls. |
| `optimize.example.psd1` | — | The list `optimize.ps1` uses: copy it to `local\optimize.psd1` (ignored by git) and add your TV's vendor packages from `examples\<tv>\debloat.txt`. |
| `inspect-package.ps1` | No | Why an app keeps coming back or starting: state and `lastDisabledCaller`, boot receivers, background permissions, log lines for state changes and starts, who binds it. |
| `verify-environment.ps1` | No (no TV) | JDK 17+, Android SDK platform 34, build-tools 34.0.0, sdkmanager, Python, Git. |
| `prepare-launcher.ps1` | No | Sets `JAVA_HOME` / `ANDROID_HOME`, writes `launcher\local.properties`, creates `tools\venv`, tests `tools\tv.py` on port 5555 and checks the Wi-Fi network was not saved by the setup wizard before `launcher\build-and-install.ps1`. |
| `screensaver.ps1` | With `-Apply` | What the TV does when idle: sets the launcher's clock as screensaver, when it starts (`-StartAfterMinutes`, 10) and when the TV sleeps (`-SleepAfterHours`, 4; 0 never). Read-only without `-Apply`; writes a revert script. Fixes a TV that turns off instead of showing a screensaver because the old one (`com.google.android.backdrop`) was disabled. |
| `verify-launcher.ps1` | No | After installing: who owns Home, disabled launchers, accessibility services, the launcher's language, RAM and the biggest processes. |
| `AdbTools.psm1` | — | The module the others share: finds adb, connects (also through wireless debugging's mDNS), runs commands. |

## A typical run

```
tools\windows\diagnose.ps1 -TvHost 192.168.1.50                                  # 1. baseline
mkdir local -Force; copy tools\windows\optimize.example.psd1 local\optimize.psd1                     # 2. your list
tools\windows\optimize.ps1 -TvHost 192.168.1.50                                  # 3. dry run, read the table
tools\windows\optimize.ps1 -TvHost 192.168.1.50 -Apply -Include All -Reboot      # 4. apply
tools\windows\diagnose.ps1 -TvHost 192.168.1.50                                  # 5. compare memory
```

Then, for the launcher: `verify-environment.ps1`, `prepare-launcher.ps1`, `launcher\build-and-install.ps1`,
`verify-launcher.ps1`.

## Things learned on the way

- **Windows PowerShell 5.1 turns adb's stderr into errors** ("daemon not running; starting now"), which
  stops a script running with `$ErrorActionPreference = 'Stop'`. The module decides by exit code.
- **`powershell -File` passes `-Include A,B` as one string.** `optimize.ps1` splits it itself.
- **Embedded double quotes are dropped** from native arguments in 5.1: commands sent to the TV use
  single quotes inside.
- **AppOps are written to disk with a delay.** `optimize.ps1` forces `cmd appops write-settings`, and
  reboots with `svc power reboot` rather than `adb reboot`, so background restrictions survive.
- **Some vendor services re-enable apps** after a disable (look at `lastDisabledCaller` with
  `inspect-package.ps1`). `RemoveForUser` (`pm uninstall --user 0`) survives that and is still undone by
  `cmd package install-existing`.
- **Free RAM barely moves after a debloat**: Linux fills free memory with cache. Compare *Used RAM* and
  the *ZRAM* swap in use instead; on a 1 GB TV the swap is what makes it feel slow.
- **Close debugging when done**: Developer options → USB debugging and wireless debugging off. Port 5555
  gives a shell to anyone on the network. `Test-NetConnection <tv ip> -Port 5555` must then fail.
