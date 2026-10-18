import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest


SCRIPT = Path(__file__).resolve().parents[1] / "dot_config/sketchybar/items/widgets/executable_bluetooth.sh"


class BluetoothPanelTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        colors = self.root / ".config/sketchybar/config/colors.sh"
        colors.parent.mkdir(parents=True)
        colors.write_text("ICON_BLUE=blue\nRED=red\nGREY=grey\n")
        self.probes = self.root / "probes"
        self.calls = self.root / "calls"
        self.fixture = self.root / "profile.json"
        self.data = {
            "SPBluetoothDataType": [{
                "controller_properties": {"controller_state": "attrib_on"},
                "device_connected": [{"Headphones": {
                    "device_address": "AA-BB-CC-DD-EE-FF", "device_minorType": "Headphones",
                    "device_batteryLevelLeft": "80%", "device_batteryLevelRight": "70%",
                }}],
                "device_not_connected": [{"Keyboard": {
                    "device_address": "11-22-33-44-55-66", "device_minorType": "Keyboard",
                }}],
            }],
        }
        self.fixture.write_text(json.dumps(self.data))
        mocks = self.root / "commands.sh"
        mocks.write_text("""
system_profiler() {
  printf 'profile\n' >> "$PROBE_LOG"
  if [ "${FAIL_PROFILE:-}" = 1 ]; then return 1; fi
  command cat "$PROFILE_JSON"
}
sketchybar() { printf '%s\n' "$*" >> "$CALL_LOG"; }
blueutil() {
  printf 'blueutil %s\n' "$*" >> "$CALL_LOG"
  if [ "$1" = -p ]; then
    local state=attrib_off
    [ "$2" = 1 ] && state=attrib_on
    jq --arg state "$state" '.SPBluetoothDataType[0].controller_properties.controller_state = $state' "$PROFILE_JSON" > "$PROFILE_JSON.next"
    mv "$PROFILE_JSON.next" "$PROFILE_JSON"
  fi
}
sleep() { :; }
""")
        self.env = {
            **os.environ, "HOME": str(self.root), "BASH_ENV": str(mocks),
            "PROBE_LOG": str(self.probes), "PROFILE_JSON": str(self.fixture), "CALL_LOG": str(self.calls),
        }

    def run_panel(self, action, *args):
        return subprocess.run(["bash", str(SCRIPT), action, *args], env=self.env,
                              capture_output=True, text=True, check=True, timeout=10)

    def assert_one_sample(self):
        self.assertEqual(self.probes.read_text().splitlines(), ["profile"])

    def test_list_uses_one_sample_and_preserves_devices_and_batteries(self):
        output = self.run_panel("list").stdout
        self.assertIn("power\ton\t\t\t\n", output)
        self.assertIn("connected\tHeadphones\tAA-BB-CC-DD-EE-FF\tHeadphones\t80/70%\n", output)
        self.assertIn("paired\tKeyboard\t11-22-33-44-55-66\tKeyboard\t\n", output)
        self.assert_one_sample()

    def test_scan_filter_reuses_the_sample(self):
        scan = self.root / ".cache/sketchybar/bluetooth_scan"
        scan.parent.mkdir(parents=True)
        scan.write_text("aa-bb-cc-dd-ee-ff\tHeadphones\n77-88-99-aa-bb-cc\tSpeaker\n")
        output = self.run_panel("list").stdout
        self.assertNotIn("available\tHeadphones", output)
        self.assertIn("available\tSpeaker\t77-88-99-aa-bb-cc\t\t\n", output)
        self.assert_one_sample()

    def test_icon_update_uses_one_sample(self):
        self.run_panel("update")
        self.assertIn("icon.color=blue", self.calls.read_text())
        self.assert_one_sample()

    def test_off_and_empty_connection_states_remain_distinct(self):
        self.data["SPBluetoothDataType"][0]["device_connected"] = []
        self.fixture.write_text(json.dumps(self.data))
        self.run_panel("update")
        self.assertIn("icon.color=grey", self.calls.read_text())
        self.data["SPBluetoothDataType"][0]["controller_properties"]["controller_state"] = "attrib_off"
        self.fixture.write_text(json.dumps(self.data))
        self.run_panel("update")
        self.assertIn("icon.color=red", self.calls.read_text())

    def test_toggle_resamples_after_changing_power(self):
        self.run_panel("toggle")
        calls = self.calls.read_text()
        self.assertIn("blueutil -p 0", calls)
        self.assertIn("icon.color=red", calls)
        self.assertIn("--trigger bluetooth_refresh", calls)
        self.assertEqual(self.probes.read_text().splitlines(), ["profile", "profile"])
        self.run_panel("toggle")
        self.assertIn("blueutil -p 1", self.calls.read_text())
        self.assertIn("icon.color=blue", self.calls.read_text())

    def test_connect_and_disconnect_keep_the_action_and_notification(self):
        self.run_panel("connect", "AA-BB-CC-DD-EE-FF")
        self.run_panel("disconnect", "AA-BB-CC-DD-EE-FF")
        calls = self.calls.read_text()
        self.assertIn("blueutil --connect AA-BB-CC-DD-EE-FF", calls)
        self.assertIn("blueutil --disconnect AA-BB-CC-DD-EE-FF", calls)
        self.assertEqual(calls.count("--trigger bluetooth_refresh"), 2)

    def test_invalid_device_address_does_not_run_actions(self):
        self.run_panel("connect", "$(touch should-not-exist)")
        self.assertFalse(self.calls.exists())
        self.assertFalse(self.probes.exists())

    def test_unavailable_profiler_keeps_off_fallback(self):
        self.env["FAIL_PROFILE"] = "1"
        output = self.run_panel("list").stdout
        self.assertIn("power\toff", output)
        self.assert_one_sample()


if __name__ == "__main__":
    unittest.main()
