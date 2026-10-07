import importlib.util
import io
import json
import os
from pathlib import Path
import socket
import socketserver
import subprocess
import tempfile
import threading
import time
import unittest
from unittest.mock import patch

SOURCE = Path(__file__).resolve().parents[1] / "dot_local/bin/mux/herdr/executable_herdr-pluck.py"
spec = importlib.util.spec_from_file_location("herdr_pluck", SOURCE)
pluck = importlib.util.module_from_spec(spec)
spec.loader.exec_module(pluck)


def layout():
    rect = {"x": 4, "y": 2, "width": 80, "height": 10}
    return {
        "area": rect.copy(),
        "focused_pane_id": "w1:p1",
        "panes": [{"focused": True, "pane_id": "w1:p1", "rect": rect.copy()}],
        "splits": [],
        "tab_id": "w1:t1",
        "workspace_id": "w1",
        "zoomed": False,
    }


class FakeHandler(socketserver.StreamRequestHandler):
    def handle(self):
        message = json.loads(self.rfile.readline())
        self.server.requests.append(message)
        method = message["method"]
        if method == "pane.layout":
            response = {"result": {"type": "pane_layout", "layout": self.server.layout}}
        elif method == "pane.get":
            response = {"result": {"type": "pane_info", "pane": {"scroll": {"viewport_rows": 8}}}}
        elif method == "pane.read":
            response = {"result": {"type": "pane_read", "read": {"text": self.server.text}}}
        elif method == "layout.apply":
            command = message["params"]["root"]["command"]
            path = Path(command[command.index("--snapshot") + 1])
            self.server.snapshots.append(json.loads(path.read_text()))
            self.server.snapshot_paths.append(path)
            response = {"error": {"code": "test_stop", "message": "stop before creating a real tab"}}
        else:
            response = {"error": {"code": "test_error", "message": "unknown test method"}}
        self.wfile.write((json.dumps({"id": message["id"], **response}) + "\n").encode())


class FakeHerdr(socketserver.UnixStreamServer):
    def __init__(self, path):
        self.layout = layout()
        self.requests = []
        self.snapshots = []
        self.snapshot_paths = []
        self.wrapped_url = "https://example.com/" + "a" * 57
        self.rows = ["top", "", self.wrapped_url, "/continued", "", "middle", "", "bottom"]
        self.text = "\n".join(self.rows) + "\n"
        super().__init__(path, FakeHandler)


class LayoutTests(unittest.TestCase):
    def test_always_bordered_single_pane_uses_actual_content_size(self):
        original = layout()
        corrected = pluck.content_layout(original, 8)
        self.assertEqual(corrected["area"], {"x": 5, "y": 3, "width": 78, "height": 8})
        self.assertEqual(corrected["panes"][0]["rect"], corrected["area"])
        self.assertEqual(original, layout())
        self.assertEqual(corrected["area"]["width"] - 1, 77)

    def test_unframed_single_pane_is_unchanged(self):
        original = layout()
        self.assertIs(pluck.content_layout(original, 10), original)

    def test_split_panes_are_unchanged(self):
        original = layout()
        original["panes"].append({"focused": False, "pane_id": "w1:p2", "rect": original["area"].copy()})
        self.assertIs(pluck.content_layout(original, 8), original)

    def test_zoomed_single_pane_uses_full_area(self):
        original = layout()
        original["zoomed"] = True
        original["panes"][0]["rect"]["height"] = 5
        corrected = pluck.content_layout(original, 8)
        self.assertEqual(corrected["area"]["height"], 8)
        self.assertEqual(corrected["panes"][0]["rect"], corrected["area"])

    def test_unsupported_or_racing_geometry_fails_closed(self):
        for height in (0, 5, 9, 11):
            with self.subTest(height=height), self.assertRaises(ValueError):
                pluck.content_layout(layout(), height)

    def test_invalid_message_framing_is_rejected(self):
        for raw in (b"{}", b"[]\n", b"{broken}\n", b" " * (pluck.MAX_MESSAGE_BYTES + 1)):
            with self.subTest(raw=raw[:20]), self.assertRaises(ValueError):
                pluck.read_message(io.BytesIO(raw))


class LauncherTests(unittest.TestCase):
    def test_changed_plugin_version_is_not_launched(self):
        plugin = {"plugin_id": pluck.PLUGIN_ID, "version": "0.4.0", "enabled": True}
        with patch.object(pluck, "result", return_value={"plugins": [plugin]}), patch.dict(os.environ, {
            "HERDR_SOCKET_PATH": "/tmp/unused.sock",
        }), patch("sys.argv", [str(SOURCE)]), patch.object(pluck, "open_picker") as launch:
            with self.assertRaisesRegex(RuntimeError, "Pluck version changed"):
                pluck.main()
            launch.assert_not_called()

    def test_disabled_plugin_is_not_launched(self):
        plugin = {"plugin_id": pluck.PLUGIN_ID, "version": "0.3.1", "enabled": False}
        with patch.object(pluck, "result", return_value={"plugins": [plugin]}), patch.dict(os.environ, {
            "HERDR_SOCKET_PATH": "/tmp/unused.sock",
        }), patch("sys.argv", [str(SOURCE)]), patch.object(pluck, "open_picker") as launch:
            with self.assertRaisesRegex(RuntimeError, "install and enable"):
                pluck.main()
            launch.assert_not_called()


class ProxyTests(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory(prefix="pluck-test-", dir="/tmp")
        self.upstream_path = str(Path(self.directory.name) / "upstream.sock")
        self.upstream = FakeHerdr(self.upstream_path)
        self.thread = threading.Thread(target=self.upstream.serve_forever, kwargs={"poll_interval": 0.01})
        self.thread.start()
        self.proxy_path = str(Path(self.directory.name) / "proxy.sock")
        self.proxy = pluck.PluckServer(self.proxy_path, self.upstream_path)

    def tearDown(self):
        self.proxy.server_close()
        self.upstream.shutdown()
        self.thread.join()
        self.upstream.server_close()
        self.directory.cleanup()

    def test_only_layout_response_is_adjusted(self):
        message = {"id": "client:123", "method": "pane.layout", "params": {"pane_id": "w1:p1"}}
        response = self.proxy.relay(message)
        self.assertEqual(response["id"], message["id"])
        self.assertEqual(response["result"]["layout"]["area"]["height"], 8)
        self.assertEqual(self.upstream.requests[0], message)
        self.assertEqual(self.upstream.requests[1]["params"], {"pane_id": "w1:p1"})
        self.assertEqual(self.upstream.layout, layout())
        read = {"id": "read", "method": "pane.read", "params": {"pane_id": "w1:p1", "source": "visible", "lines": 8}}
        response = self.proxy.relay(read)
        self.assertEqual(response["result"]["read"]["text"], self.upstream.text)
        self.assertEqual(self.upstream.requests[-1], read)

    def test_api_errors_are_forwarded_unchanged(self):
        response = self.proxy.relay({"id": "focus", "method": "pane.focus", "params": {}})
        self.assertEqual(response, {"id": "focus", "error": {"code": "test_error", "message": "unknown test method"}})

    def test_non_launch_methods_are_not_forwarded(self):
        for method in ("server.stop", "pane.send_text", "$(touch /tmp/pluck-injected)"):
            with self.subTest(method=method), self.assertRaises(ValueError):
                self.proxy.relay({"id": "bad", "method": method, "params": {}})
        self.assertEqual(self.upstream.requests, [])

    def test_proxy_socket_is_private(self):
        self.assertEqual(Path(self.proxy_path).stat().st_mode & 0o777, 0o600)

    def test_malformed_peer_gets_an_error_without_forwarding(self):
        thread = threading.Thread(target=self.proxy.handle_request)
        thread.start()
        with socket.socket(socket.AF_UNIX) as connection:
            connection.connect(self.proxy_path)
            connection.sendall(b"[]\n")
            response = json.loads(connection.makefile("rb").readline())
        thread.join(timeout=2)
        self.assertEqual(response["error"]["code"], "pluck_viewport_error")
        self.assertEqual(self.upstream.requests, [])

    @unittest.skipUnless(os.environ.get("HERDR_PLUCK_TEST_BINARY"), "set HERDR_PLUCK_TEST_BINARY for installed-picker regression")
    def test_installed_picker_baseline_and_corrected_snapshot(self):
        binary = Path(os.environ["HERDR_PLUCK_TEST_BINARY"])
        environment = {
            **os.environ,
            "HERDR_SOCKET_PATH": self.upstream_path,
            "HERDR_PANE_ID": "w1:p1",
            "HERDR_PLUGIN_CONTEXT_JSON": "{}",
        }
        original = subprocess.run([str(binary), "open"], env=environment, capture_output=True, timeout=10)
        self.assertNotEqual(original.returncode, 0)
        baseline = self.upstream.snapshots[-1]["source"]
        self.assertEqual((baseline["target_content_width"], baseline["target_content_height"]), (79, 10))
        outcome = pluck.open_picker(self.upstream_path, binary, environment)
        self.assertNotEqual(outcome, 0)
        corrected = self.upstream.snapshots[-1]["source"]
        self.assertEqual((corrected["target_content_width"], corrected["target_content_height"]), (77, 8))
        self.assertEqual(corrected["visible_viewport"]["rows"], self.upstream.rows)
        self.assertIn(self.upstream.wrapped_url + "/continued", corrected["visible_viewport"]["logical_lines"])
        self.assertEqual(corrected["target_pane_id"], "w1:p1")
        self.assertEqual(self.upstream.snapshots[-1]["session"]["return_tab_id"], "w1:t1")
        self.assertTrue(all(not path.exists() for path in self.upstream.snapshot_paths))
        self.assertFalse(any(request["method"] in {"tab.focus", "tab.close"} for request in self.upstream.requests))


@unittest.skipUnless(os.environ.get("HERDR_PLUCK_LIVE_TEST") == "1", "live test requires explicit opt-in")
class LivePickerTests(unittest.TestCase):
    def test_visible_rows_and_escape_cleanup(self):
        self.assertEqual(os.environ.get("HERDR_ENV"), "1")
        socket_path = os.environ["HERDR_SOCKET_PATH"]

        def rpc(method, params):
            return pluck.result(socket_path, method, params)

        focused = rpc("pane.layout", {})["layout"]
        source_tab = picker_tab = None
        applied = []
        fixture = "\n".join([
            "import os, signal, time",
            "time.sleep(0.8)",
            "width, height = os.get_terminal_size()",
            'rows = ["TOP-STAYS-HERE"] + [""] * (height - 2) + ["BOTTOM-STAYS-HERE"]',
            'rows[2] = "https://example.com/pluck-viewport"',
            'screen = "\\x1b[2J" + "".join(f"\\x1b[{i + 1};1H{row}" for i, row in enumerate(rows))',
            "os.write(1, screen.encode())",
            "signal.pause()",
        ])
        try:
            created = rpc("layout.apply", {
                "workspace_id": focused["workspace_id"],
                "tab_label": "pluck-viewport-test",
                "focus": True,
                "root": {"type": "pane", "command": ["python3", "-c", fixture]},
            })["layout"]
            source_tab = created["tab_id"]
            source_pane = created["root"]["pane_id"]
            rpc("pane.focus", {"pane_id": source_pane})
            time.sleep(1.2)

            def visible(pane_id):
                rows = rpc("pane.get", {"pane_id": pane_id})["pane"]["scroll"]["viewport_rows"]
                text = rpc("pane.read", {
                    "pane_id": pane_id, "source": "visible", "lines": rows,
                    "format": "text", "strip_ansi": True,
                })["read"]["text"]
                return text.splitlines()

            before = visible(source_pane)
            self.assertEqual(before[0], "TOP-STAYS-HERE")
            self.assertEqual(before[-1], "BOTTOM-STAYS-HERE")
            original_relay = pluck.PluckServer.relay

            def capture_relay(server, message):
                response = original_relay(server, message)
                if message["method"] == "layout.apply" and "result" in response:
                    applied.append(response["result"]["layout"])
                return response

            with patch.object(pluck.PluckServer, "relay", capture_relay), patch.dict(os.environ, {
                "HERDR_PANE_ID": source_pane, "HERDR_TAB_ID": source_tab,
                "HERDR_PLUGIN_CONTEXT_JSON": "{}",
            }), patch("sys.argv", [str(SOURCE)]):
                self.assertEqual(pluck.main(), 0)
            self.assertEqual(len(applied), 1)
            picker_tab = applied[0]["tab_id"]
            picker_pane = applied[0]["root"]["pane_id"]
            time.sleep(0.5)
            after = visible(picker_pane)
            self.assertEqual(len(before), len(after))
            self.assertEqual([i for i, (a, b) in enumerate(zip(before, after)) if a != b], [2])
            self.assertEqual(after[2][1:], before[2][1:])
            self.assertEqual(after[0], "TOP-STAYS-HERE")
            self.assertEqual(after[-1], "BOTTOM-STAYS-HERE")
            print(f"Live viewport: {len(after)} rows preserved; only the URL hint changed row 3")
            rpc("pane.send_keys", {"pane_id": picker_pane, "keys": ["esc"]})
            time.sleep(0.4)
            self.assertNotIn(picker_tab, {tab["tab_id"] for tab in rpc("tab.list", {})["tabs"]})
            picker_tab = None
            self.assertEqual(rpc("pane.layout", {})["layout"]["tab_id"], source_tab)
        finally:
            if not picker_tab and applied:
                picker_tab = applied[0]["tab_id"]
            tabs = {tab["tab_id"] for tab in rpc("tab.list", {})["tabs"]}
            if picker_tab in tabs:
                rpc("tab.close", {"tab_id": picker_tab})
            rpc("tab.focus", {"tab_id": focused["tab_id"]})
            if source_tab:
                rpc("tab.close", {"tab_id": source_tab})


if __name__ == "__main__":
    unittest.main()
