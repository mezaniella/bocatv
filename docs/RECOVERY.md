# Recovery

Nothing in this repository flashes, roots or deletes system files: packages are disabled or removed for
the user only, settings live in the user's profile, and the launcher is an ordinary app. A factory reset
undoes all of it. This page is the path back, from the lightest fix to that reset.

Set up these safety nets **before** the launcher handover:

- **A fixed ADB port.** With USB debugging on, most TVs listen on 5555, which never changes and needs
  no pairing. Check it: `Test-NetConnection <tv ip> -Port 5555` → `TcpTestSucceeded : True`.
- **The Wi-Fi network saved outside the setup wizard.** If the network was saved during the first setup
  it belongs to `com.google.android.tungsten.setupwraith`, and disabling that deletes it. Forget the
  network and join it again in Settings. `tools\windows\prepare-launcher.ps1` checks this.
- **Your model's recovery mode**, looked up but not tried (section 8).

## Never disable

| Package | Why |
|---|---|
| `com.mediatek.wwtv.tvcenter`, `com.mediatek.tvinput`, `com.mediatek.tv.service` (or your SoC's equivalents) | Live TV and HDMI inputs |
| The vendor's remote / key service | Remote buttons |
| `com.google.android.gms`, `com.google.android.gsf`, `com.android.vending` | Play Services and the Play Store, which keeps your apps updated |
| `com.google.android.webview`, `com.android.systemui`, `com.android.providers.*` | The system itself |
| `com.android.tv.settings` | Settings: your way back without ADB |
| The stock launcher | Only `launcher/build-and-install` disables it, after the new launcher owns Home |
| `com.google.android.tungsten.setupwraith` | Only after the Wi-Fi check above |

## 1. The launcher build fails

Nothing on the TV changed. Run `tools\windows\verify-environment.ps1`; set `JAVA_HOME` to a JDK 17 and
make sure `build-tools;34.0.0` and `platforms;android-34` are installed.

## 2. Home did not change, or a "Choose home app" picker appears

The TV works. Pick a launcher in the picker, then check who owns Home:

```
adb shell cmd package resolve-activity --brief -a android.intent.action.MAIN -c android.intent.category.HOME
```

Run the install script again.

## 3. Black screen, no Home, or a factory/test app on screen

The stock launcher is disabled and the new one does not start. With ADB:

```
adb connect <tv ip>:5555
adb shell pm enable --user 0 com.google.android.tvlauncher            # Android TV
adb shell pm enable --user 0 com.google.android.apps.tv.launcherx     # Google TV
adb shell pm enable --user 0 com.google.android.tvrecommendations
adb shell input keyevent KEYCODE_HOME
```

Without ADB: the remote's Settings (gear) button → Apps → See all → Show system apps → the stock home
→ Enable, then press Home. To remove the new launcher: `adb shell pm uninstall com.gathin.tvhome`.

## 4. Boot loop, or the setup wizard takes over Home

Enable the stock launcher as in 3, between reboots if needed. If the wizard keeps taking Home and the
Wi-Fi network is no longer the wizard's, disable it:
`adb shell pm disable-user --user 0 com.google.android.tungsten.setupwraith`
(`pm enable --user 0 ...` brings it back). No ADB and no Settings: go to 8.

## 5. The Wi-Fi network is gone

The wizard was disabled while it owned the network. Join it again in Settings → Network (or plug in a
cable). Wireless ADB needs the network back first.

## 6. ADB connection lost

- Try the fixed port: `adb connect <tv ip>:5555`.
- Turn debugging on again: Settings → Device Preferences → Developer options → USB debugging and/or
  wireless debugging. No Developer options? Settings → Device Preferences → About → press OK on
  *Build* seven times.
- Check the TV's IP in Settings → Network; it may have changed.
- `failed to connect` / error 10061: the port changed or debugging is off. `unauthorized`: accept the
  prompt on the TV.

The TV keeps working without ADB; ADB is only needed for changes.

## 7. Remote buttons stopped working (Input, YouTube, Netflix…)

Some keys were answered by the stock launcher. `launcher/build-and-install` has optional services for
them (`INPUT_KEY_SERVICE=1`, `HOME_KEY_SERVICE=1`, `app_keys`); see the README. Quick way back: 3.

## 8. Last resort: factory reset

Everything above is undone; installed apps, sign-ins and settings are lost.

- **From Settings:** Device Preferences → Reset.
- **From recovery mode**, when the TV is unusable. Common combinations on Android TV sets (check your
  model's manual first):
  1. Unplug the TV and wait 30 seconds.
  2. Hold the TV's own power button (with volume down if it has one; a single joystick-style button on
     many sets), not the remote's.
  3. Plug it in while holding, until the recovery menu appears (10-15 s).
  4. Move with volume or a short press, select with power or a long press: *Wipe data/factory reset* →
     *Yes* → *Reboot system now*.

## Other known effects

- Apps stop loading or the TV says "No internet": the ad-blocking Private DNS resolver is down.
  `adb shell settings put global private_dns_mode opportunistic`.
- Background-restricted apps open normally but no longer start at boot: that is the point. Undo one
  with `adb shell cmd appops set <package> RUN_ANY_IN_BACKGROUND default`.
- Screenshots of Live TV or streaming video come out black: protected video, expected.
- Avoid unplugging the TV or `adb reboot` right after a change: use `adb shell svc power reboot`.
