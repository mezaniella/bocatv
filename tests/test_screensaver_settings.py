"""tools/screensaver_settings.py: a theme's "screensaver" section to Android settings commands.

Run from the repository root: python3 -m unittest discover -s tests -v
"""
import json
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SCRIPT = ROOT / "tools" / "screensaver_settings.py"


def run(config):
    with tempfile.TemporaryDirectory() as tmp:
        path = Path(tmp) / "config.json"
        path.write_text(json.dumps(config), encoding="utf-8")
        return subprocess.run([sys.executable, "-I", str(SCRIPT), str(path)], capture_output=True, text=True)


def settings(stdout):
    """{'secure/screensaver_enabled': '1', ...} from the printed command line."""
    out = {}
    for command in stdout.strip().split("; "):
        _, _, namespace, key, value = command.split(" ")
        out[f"{namespace}/{key}"] = value
    return out


class ScreensaverSettingsTest(unittest.TestCase):
    def test_no_section_changes_nothing(self):
        for config in ({}, {"screensaver": False}, {"columns": 5}):
            with self.subTest(config=config):
                r = run(config)
                self.assertEqual(r.returncode, 0, r.stderr)
                self.assertEqual(r.stdout.strip(), "")

    def test_values(self):
        r = run({"screensaver": {"start_after_minutes": 10, "sleep_after_hours": 4}})
        self.assertEqual(r.returncode, 0, r.stderr)
        self.assertEqual(settings(r.stdout), {
            "secure/screensaver_components": "com.gathin.tvhome/.ClockDream",
            "secure/screensaver_enabled": "1",
            "secure/screensaver_activate_on_sleep": "1",
            "system/screen_off_timeout": "600000",
            "secure/sleep_timeout": "14400000",
            "secure/attentive_timeout": "14400000",
        })

    def test_true_uses_defaults_and_zero_hours_means_never(self):
        self.assertEqual(settings(run({"screensaver": True}).stdout)["system/screen_off_timeout"], "600000")
        never = settings(run({"screensaver": {"sleep_after_hours": 0}}).stdout)
        self.assertEqual(never["secure/sleep_timeout"], "-1")
        self.assertEqual(never["secure/attentive_timeout"], "-1")

    def test_bad_values_are_refused(self):
        for section in ("yes", {"start_after_minutes": 0}, {"start_after_minutes": 121},
                        {"sleep_after_hours": 25}, {"sleep_after_hours": True}, {"sleep_after_hours": 1.5}):
            with self.subTest(section=section):
                r = run({"screensaver": section})
                self.assertNotEqual(r.returncode, 0)
                self.assertEqual(r.stdout.strip(), "")

    def test_boca_theme_sets_its_screensaver(self):
        config = json.loads((ROOT / "themes" / "boca" / "config.json").read_text(encoding="utf-8"))
        self.assertIn("screensaver", config)
        r = subprocess.run([sys.executable, "-I", str(SCRIPT), str(ROOT / "themes" / "boca" / "config.json")],
                           capture_output=True, text=True)
        self.assertEqual(r.returncode, 0, r.stderr)
        self.assertIn("com.gathin.tvhome/.ClockDream", r.stdout)


if __name__ == "__main__":
    unittest.main()
