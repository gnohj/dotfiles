import json
from pathlib import Path
import subprocess
import unittest


ROOT = Path(__file__).resolve().parents[1]
TEMPLATE = ROOT / "dot_config/ghostty/config.tmpl"


def render(hostname, os_name, release_id="", devbox_host="dev-box"):
    data = {
        "chezmoi": {
            "hostname": hostname,
            "os": os_name,
            "osRelease": {"id": release_id},
        },
        "devbox_host": devbox_host,
    }
    result = subprocess.run(
        ["chezmoi", "--source", str(ROOT), "--override-data", json.dumps(data),
         "execute-template", "--file", str(TEMPLATE)],
        capture_output=True, text=True, check=True, timeout=10,
    )
    settings = {}
    for line in result.stdout.splitlines():
        if line.startswith("#") or "=" not in line:
            continue
        key, value = line.split("=", 1)
        settings.setdefault(key.strip(), []).append(value.strip())
    return settings


class GhosttyConfigTests(unittest.TestCase):
    def test_devbox_disables_shaders_and_keeps_omarchy_theme(self):
        settings = render("dev-box", "linux", "omarchy")
        self.assertEqual(settings["custom-shader"], [""])
        self.assertEqual(settings["custom-shader-animation"], ["false"])
        self.assertEqual(settings["config-file"], ['?"~/.local/state/omarchy/current/theme/ghostty.conf"'])

    def test_mac_keeps_focused_shaders(self):
        settings = render("macbook", "darwin")
        self.assertEqual(settings["custom-shader"], ["./shaders/bloom025.glsl", "./shaders/cursor_smear_fade.glsl"])
        self.assertEqual(settings["custom-shader-animation"], ["true"])
        self.assertEqual(settings["config-file"], ["ghostty-theme"])

    def test_other_linux_hosts_are_unchanged(self):
        settings = render("laptop", "linux", "arch")
        self.assertEqual(settings["custom-shader"], ["./shaders/bloom025.glsl", "./shaders/cursor_smear_fade.glsl"])
        self.assertEqual(settings["custom-shader-animation"], ["true"])

    def test_devbox_policy_follows_configured_hostname(self):
        settings = render("replacement-box", "linux", "omarchy", "replacement-box")
        self.assertEqual(settings["custom-shader"], [""])
        self.assertEqual(settings["custom-shader-animation"], ["false"])


if __name__ == "__main__":
    unittest.main()
