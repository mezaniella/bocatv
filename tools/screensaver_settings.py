"""Turn a theme's "screensaver" section into the Android settings commands that apply it.

    python tools/screensaver_settings.py <theme>/config.json

Prints one shell line for tools/tv.py, or nothing when the theme has no "screensaver" section. Used by
tools/theme.sh and tools/theme.ps1, so both apply a theme's screensaver the same way:

    "screensaver": { "start_after_minutes": 10, "sleep_after_hours": 4 }

- the launcher's clock (com.gathin.tvhome/.ClockDream) becomes the TV's screensaver, dressed in the
  theme's colours;
- start_after_minutes (1-120, default 10): idle time before it starts;
- sleep_after_hours (0-24, default 4): idle time before the TV goes to sleep; 0 never.

A launcher cannot change these settings itself (they need WRITE_SECURE_SETTINGS), which is why the push
script applies them over ADB. tools/windows/screensaver.ps1 shows the current values and can undo them.
"""
import json
import sys

COMPONENT = "com.gathin.tvhome/.ClockDream"


def bounded(section, key, default, low, high):
    value = section.get(key, default)
    if isinstance(value, bool) or not isinstance(value, int) or not low <= value <= high:
        sys.exit(f'screensaver.{key} must be a whole number from {low} to {high}, got {value!r}')
    return value


def commands(config):
    section = config.get("screensaver")
    if section is None or section is False:
        return ""
    if section is True:
        section = {}
    if not isinstance(section, dict):
        sys.exit('"screensaver" must be an object, e.g. {"start_after_minutes": 10, "sleep_after_hours": 4}')
    start_ms = bounded(section, "start_after_minutes", 10, 1, 120) * 60_000
    hours = bounded(section, "sleep_after_hours", 4, 0, 24)
    sleep_ms = -1 if hours == 0 else hours * 3_600_000
    return "; ".join([
        f"settings put secure screensaver_components {COMPONENT}",
        "settings put secure screensaver_enabled 1",
        "settings put secure screensaver_activate_on_sleep 1",
        f"settings put system screen_off_timeout {start_ms}",
        f"settings put secure sleep_timeout {sleep_ms}",
        f"settings put secure attentive_timeout {sleep_ms}",
    ])


def main():
    if len(sys.argv) != 2:
        sys.exit(__doc__.strip().split("\n\n")[1])
    with open(sys.argv[1], encoding="utf-8") as f:
        print(commands(json.load(f)))


if __name__ == "__main__":
    main()
