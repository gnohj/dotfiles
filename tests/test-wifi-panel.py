import os
from pathlib import Path
import subprocess
import tempfile
import time
import unittest


SCRIPT = Path(__file__).resolve().parents[1] / "dot_config/sketchybar/items/widgets/executable_wifi-panel.sh"


class WifiPanelTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        colors = self.root / ".config/sketchybar/config/colors.sh"
        colors.parent.mkdir(parents=True)
        colors.write_text("")
        self.probes = self.root / "probes"
        self.cache = self.root / "cache/sketchybar/wifi_panel"
        self.lock = Path(str(self.cache) + ".lock")
        mocks = self.root / "commands.sh"
        mocks.write_text("""
ping() {
  printf 'ping\n' >> "$PROBE_LOG"
  printf '3 packets transmitted, 3 packets received, 0.0%% packet loss\nround-trip min/avg/max/stddev = 1.0/2.0/3.0/0.1 ms\n'
}
system_profiler() {
  printf 'profiler\n' >> "$PROBE_LOG"
  sleep "${PROBE_DELAY:-0}"
  printf 'Current Network Information:\nChannel: 36 (5GHz, 80MHz)\nSignal / Noise: -50 dBm / -90 dBm\nOther Local Networks:\n'
}
ifconfig() { printf 'ether aa:bb:cc:dd:ee:ff\n'; }
sudo() { return 1; }
netstat() { printf 'Name Mtu Network Address Ipkts Ierrs Ibytes Opkts Oerrs Obytes\nen0 1500 link addr 1 0 4096 1 0 2048\n'; }
networksetup() {
  case "$1" in
    -getairportpower) printf 'Wi-Fi Power (en0): On\n' ;;
    -getdnsservers) printf '1.1.1.1\n1.0.0.1\n' ;;
    -listpreferredwirelessnetworks) printf 'Preferred networks on en0:\n  Home\n' ;;
    *) return 1 ;;
  esac
}
ipconfig() { printf '192.168.1.10\n'; }
route() { printf 'gateway: 192.168.1.1\n'; }
""")
        self.env = {
            **os.environ,
            "HOME": str(self.root),
            "XDG_CACHE_HOME": str(self.root / "cache"),
            "BASH_ENV": str(mocks),
            "PROBE_LOG": str(self.probes),
        }

    def run_panel(self, action):
        return subprocess.run(["bash", str(SCRIPT), action], env=self.env,
                              capture_output=True, text=True, check=True, timeout=10)

    def probe_lines(self):
        return self.probes.read_text().splitlines() if self.probes.exists() else []

    def test_list_never_runs_diagnostics(self):
        output = self.run_panel("list").stdout
        self.assertIn("power\ton\t", output)
        self.assertEqual(self.probe_lines(), [])

    def test_fresh_cache_skips_diagnostics(self):
        self.run_panel("sample")
        original = self.cache.read_text()
        self.run_panel("sample")
        self.assertEqual(self.cache.read_text(), original)
        self.assertEqual(self.probe_lines(), ["ping", "profiler"])
        self.assertFalse(self.lock.exists())

    def test_stale_cache_samples_again(self):
        self.run_panel("sample")
        lines = self.cache.read_text().splitlines()
        lines[0] = f"sampled_at={int(time.time()) - 21}"
        self.cache.write_text("\n".join(lines) + "\n")
        self.run_panel("sample")
        self.assertEqual(self.probe_lines(), ["ping", "profiler", "ping", "profiler"])

    def test_concurrent_samples_do_not_overlap(self):
        self.env["PROBE_DELAY"] = "1"
        with subprocess.Popen(["bash", str(SCRIPT), "sample"], env=self.env,
                              stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True) as first:
            deadline = time.monotonic() + 5
            while "profiler" not in self.probe_lines() and time.monotonic() < deadline:
                time.sleep(0.01)
            self.assertIn("profiler", self.probe_lines())
            self.run_panel("sample")
            _, errors = first.communicate(timeout=10)
            self.assertEqual(first.returncode, 0, errors)
        self.assertEqual(self.probe_lines(), ["ping", "profiler"])
        self.assertFalse(self.lock.exists())

    def test_stale_lock_is_recovered(self):
        self.lock.mkdir(parents=True)
        old = time.time() - 180
        os.utime(self.lock, (old, old))
        self.run_panel("sample")
        self.assertEqual(self.probe_lines(), ["ping", "profiler"])
        self.assertFalse(self.lock.exists())


if __name__ == "__main__":
    unittest.main()
