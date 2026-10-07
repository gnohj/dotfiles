import importlib.util
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import time
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[1]
SCRIPTS = ROOT / "dot_local/bin/mux/herdr"


def load_module(name, filename):
    spec = importlib.util.spec_from_file_location(name, SCRIPTS / filename)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


overlay = load_module("scrollback_overlay", "executable_herdr-scrollback-overlay.py")
balancer = load_module("balance_panes", "executable_herdr-balance-panes.py")
SOURCE_ROOT = {
    "type": "split", "direction": "right", "ratio": 0.65,
    "first": {"type": "pane", "pane_id": "source"},
    "second": {"type": "pane", "pane_id": "sibling"},
}
PANES = {
    "source": {"pane_id": "source", "tab_id": "original", "workspace_id": "workspace", "cwd": "/tmp", "title": "agent", "scroll": {"viewport_rows": 8}},
    "sibling": {"pane_id": "sibling", "tab_id": "original", "workspace_id": "workspace", "cwd": "/tmp", "title": "logs", "scroll": {"viewport_rows": 8}},
}
CREATED_ROOT = {
    "type": "split", "direction": "right", "ratio": 0.65,
    "first": {"type": "pane", "pane_id": "viewer"},
    "second": {"type": "pane", "pane_id": "frozen"},
}


class GeometryTests(unittest.TestCase):
    def test_source_context_wins_over_the_calling_pane(self):
        environment = {"HERDR_PANE_ID": "caller", "HERDR_PLUGIN_CONTEXT_JSON": '{"focused_pane_id":"source"}'}
        self.assertEqual(overlay.source_pane(environment), "source")
        environment["HERDR_PLUGIN_CONTEXT_JSON"] = '{"focused_pane":{"id":"source"}}'
        self.assertEqual(overlay.source_pane(environment), "source")
        environment["HERDR_PLUGIN_CONTEXT_JSON"] = "{}"
        self.assertEqual(overlay.source_pane(environment), "caller")

    def test_replays_ratios_labels_and_argv_without_original_processes(self):
        root = overlay.build_layout(SOURCE_ROOT, "source", PANES, Path("/tmp/a space;quoted/view.json"), "prompt")
        self.assertEqual(root["ratio"], 0.65)
        self.assertEqual(root["direction"], "right")
        self.assertEqual(root["first"]["label"], "agent")
        self.assertEqual(root["second"]["label"], "logs")
        self.assertEqual(root["first"]["command"][-3:], ["view", "/tmp/a space;quoted/view.json", "prompt"])
        self.assertEqual(root["second"]["command"][-3:], ["hold", "/tmp/a space;quoted/view.json", "sibling"])
        self.assertNotIn("pane_id", root["first"])
        self.assertEqual(overlay.viewer_pane(SOURCE_ROOT, CREATED_ROOT, "source"), "viewer")
        self.assertEqual(overlay.viewer_pane(SOURCE_ROOT, CREATED_ROOT, "sibling"), "frozen")

    def test_balance_does_not_resize_a_snapshot_layout(self):
        root = overlay.build_layout(SOURCE_ROOT, "source", PANES, Path("/tmp/view.json"), "bottom")
        self.assertTrue(balancer.is_scrollback_layout(root))
        with patch.object(balancer, "request", return_value={"layout": {"root": root}}) as rpc:
            balancer.balance("viewer-tab")
        rpc.assert_called_once_with("layout.export", {"tab_id": "viewer-tab"})
        self.assertFalse(balancer.is_scrollback_layout(SOURCE_ROOT))
        with patch.object(balancer, "runs_editor", return_value=False):
            self.assertEqual(balancer.plan(SOURCE_ROOT), [([], 0.5)])

    def test_ansi_preserves_colour_but_removes_clipboard_and_cursor_commands(self):
        text = "\x1b[31mred\x1b[0m\x1b]52;c;YXR0YWNr\x07\x1b[2J\x1b[10;10Htext\x1bPpayload\x1b\\\x00"
        self.assertEqual(overlay.safe_ansi(text), "\x1b[31mred\x1b[0mtext")


class LifecycleTests(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory(prefix="scrollback-test-", dir="/tmp")
        self.snapshot = Path(self.directory.name) / "view.json"
        self.calls = []
        self.fail_focus = False

    def tearDown(self):
        self.directory.cleanup()

    def rpc(self, method, params):
        self.calls.append((method, params))
        if method == "pane.get":
            return {"pane": PANES[params["pane_id"]]}
        if method == "layout.export":
            return {"layout": {"root": SOURCE_ROOT, "zoomed": True}}
        if method == "pane.read":
            return {"read": {"text": "\x1b[32mSIBLING\x1b[0m\n"}}
        if method == "layout.apply":
            self.assertNotIn("tab_id", params)
            return {"layout": {"tab_id": "viewer-tab", "root": CREATED_ROOT}}
        if method == "pane.focus" and self.fail_focus:
            raise RuntimeError("focus failed")
        return {}

    def test_launch_captures_the_source_screen_and_siblings(self):
        with patch.object(overlay, "request", self.rpc), patch.object(overlay.tempfile, "mkdtemp", return_value=self.directory.name), patch.dict(os.environ, {"HERDR_PANE_ID": "source", "HERDR_PLUGIN_CONTEXT_JSON": "{}"}):
            overlay.open_viewer("prompt")
        payload = json.loads(self.snapshot.read_text())
        self.assertEqual(payload["source_pane"], "source")
        self.assertEqual(payload["source_tab"], "original")
        self.assertEqual(payload["siblings"], {"sibling": "\x1b[32mSIBLING\x1b[0m\n"})
        viewport = self.snapshot.with_suffix(".ansi").read_text()
        self.assertEqual(viewport.splitlines(), ["\x1b[32mSIBLING\x1b[0m"] + [""] * 7)
        self.assertEqual({params["pane_id"] for method, params in self.calls if method == "pane.read"}, {"source", "sibling"})
        self.assertEqual(self.snapshot.stat().st_mode & 0o777, 0o600)
        self.assertTrue(self.snapshot.with_suffix(".ready").exists())
        self.assertIn(("pane.zoom", {"pane_id": "viewer", "mode": "on"}), self.calls)
        self.assertFalse(any(method in {"pane.split", "pane.send_text", "pane.send_keys", "pane.resize"} for method, _ in self.calls))

    def test_launch_failure_closes_only_the_new_tab(self):
        self.fail_focus = True
        with patch.object(overlay, "request", self.rpc), patch.object(overlay.tempfile, "mkdtemp", return_value=self.directory.name), patch.dict(os.environ, {"HERDR_PANE_ID": "source", "HERDR_PLUGIN_CONTEXT_JSON": "{}"}):
            with self.assertRaisesRegex(RuntimeError, "focus failed"):
                overlay.open_viewer("bottom")
        self.assertEqual(self.calls[-2:], [("tab.focus", {"tab_id": "original"}), ("tab.close", {"tab_id": "viewer-tab"})])
        self.assertFalse(self.snapshot.parent.exists())

    def test_viewer_uses_the_source_pane_and_cleans_up_after_nvim(self):
        self.snapshot.write_text(json.dumps({"source_pane": "source", "source_tab": "original", "viewport_rows": 8, "viewer_script": "/tmp/viewer.sh"}))
        self.snapshot.with_suffix(".ready").touch()
        with patch.object(overlay, "request", self.rpc), patch.dict(os.environ, {"HERDR_TAB_ID": "viewer-tab"}), patch.object(overlay.os, "get_terminal_size", return_value=os.terminal_size((80, 8))), patch.object(overlay.subprocess, "run", return_value=subprocess.CompletedProcess([], 0)) as run:
            self.assertEqual(overlay.run_viewer(self.snapshot, "prompt"), 0)
        self.assertEqual(run.call_args.args[0], ["/bin/bash", "/tmp/viewer.sh", "--jump"])
        self.assertEqual(run.call_args.kwargs["env"]["HERDR_SCROLLBACK_SOURCE_PANE"], "source")
        self.assertEqual(run.call_args.kwargs["env"]["HERDR_SCROLLBACK_VIEWPORT_FILE"], str(self.snapshot.with_suffix(".ansi")))
        self.assertEqual(run.call_args.kwargs["env"]["HERDR_SCROLLBACK_VIEWPORT_ROWS"], "8")
        self.assertEqual(self.calls, [("tab.focus", {"tab_id": "original"}), ("tab.close", {"tab_id": "viewer-tab"})])
        self.assertFalse(self.snapshot.parent.exists())

    def test_snapshot_cleanup_can_run_twice(self):
        self.snapshot.touch()
        self.snapshot.with_suffix(".ready").touch()
        self.snapshot.with_suffix(".ansi").touch()
        overlay.cleanup_files(self.snapshot)
        overlay.cleanup_files(self.snapshot)
        self.assertFalse(self.snapshot.parent.exists())

    def test_viewer_never_closes_its_original_tab(self):
        self.snapshot.write_text(json.dumps({"source_pane": "source", "source_tab": "original"}))
        with patch.dict(os.environ, {"HERDR_TAB_ID": "original"}):
            with self.assertRaisesRegex(ValueError, "refusing to replace"):
                overlay.run_viewer(self.snapshot, "bottom")
        self.assertTrue(self.snapshot.exists())
        self.assertEqual(self.calls, [])


class TranscriptTests(unittest.TestCase):
    def test_transcript_and_screen_fallback_read_the_source_not_the_viewer(self):
        for transcript_ok, jump, snapshot in ((True, False, False), (True, True, False), (False, False, False), (True, False, True), (True, True, True), (False, False, True)):
            with self.subTest(transcript_ok=transcript_ok, jump=jump, snapshot=snapshot), tempfile.TemporaryDirectory(prefix="scrollback-shell-", dir="/tmp") as temporary:
                home = Path(temporary)
                binaries = home / "bin"
                binaries.mkdir()
                helpers = home / ".local/bin/mux/herdr"
                helpers.mkdir(parents=True)
                herdr = binaries / "herdr"
                herdr.write_text("\n".join([
                    "#!/usr/bin/env python3", "import json,sys",
                    "if sys.argv[1:3] == ['pane','list']:",
                    " print(json.dumps({'result':{'panes':[{'pane_id':'viewer','focused':True,'agent':'nvim'}, {'pane_id':'source','focused':False,'agent':'pi','agent_session':{'kind':'id','value':'session-id'},'cwd':'/tmp'}]}}))",
                    "else:", " assert sys.argv[1:4] == ['pane','read','source']",
                    " print('SCREEN\\r\\n\\r\\n')", "",
                ]))
                transcript = helpers / "herdr-agent-transcript.py"
                transcript.write_text("#!/usr/bin/env bash\n" + ("printf 'TRANSCRIPT\\n'\n" if transcript_ok else "exit 1\n"))
                nvim = binaries / "nvim"
                nvim.write_text("\n".join([
                    "#!/usr/bin/env python3", "import json,os,sys", "from pathlib import Path",
                    "file=Path(sys.argv[3])",
                    "Path(os.environ['TEST_LOG']).write_text(json.dumps({'args':sys.argv[1:],'file':str(file),'text':file.read_text()}))", "",
                ]))
                for executable in (herdr, transcript, nvim):
                    executable.chmod(0o700)
                log = home / "result.json"
                viewport = home / "viewport ; $(touch injected).ansi"
                viewport.write_text("VISIBLE ANSWER\n\n────────\n❯ draft input\n────────\nccstatus: model · context · cost\n\n\n")
                environment = {
                    **os.environ, "HOME": str(home), "PATH": str(binaries) + os.pathsep + os.environ["PATH"],
                    "HERDR_BIN_PATH": str(herdr), "HERDR_SCROLLBACK_SOURCE_PANE": "source",
                    "HERDR_PANE_ID": "viewer", "HERDR_ACTIVE_PANE_ID": "wrong", "TEST_LOG": str(log),
                }
                if snapshot:
                    environment["HERDR_SCROLLBACK_VIEWPORT_FILE"] = str(viewport)
                else:
                    environment.pop("HERDR_SCROLLBACK_VIEWPORT_FILE", None)
                command = ["bash", str(SCRIPTS / "executable_herdr-scrollback.sh")]
                if jump:
                    command.append("--jump")
                subprocess.run(command, env=environment, cwd=home, check=True, capture_output=True, text=True)
                self.assertFalse((home / "injected").exists())
                recorded = json.loads(log.read_text())
                expected = "TRANSCRIPT\n" if transcript_ok else "SCREEN\n"
                if snapshot:
                    expected = (expected + "\n" if transcript_ok else "") + viewport.read_text()
                self.assertEqual(recorded["text"], expected)
                self.assertIn("jump = true", recorded["args"][-1]) if jump else self.assertNotIn("jump = true", recorded["args"][-1])
                self.assertFalse(Path(recorded["file"]).exists())

    @unittest.skipUnless(shutil.which("nvim"), "Neovim required")
    def test_large_ansi_history_keeps_the_full_snapshot_without_escape_text(self):
        with tempfile.TemporaryDirectory(prefix="scrollback-nvim-", dir="/tmp") as temporary:
            file = Path(temporary) / "history"
            viewport = ["VISIBLE ANSWER", "", "────────", "❯ draft input", "────────", "ccstatus: model · context · cost", "", ""]
            file.write_text("vim: set tabstop=1:\n" + "\x1b[31mHISTORY\x1b[0m\n" * 4999 + "\n".join(viewport) + "\n")
            init = ROOT / "dot_config/herdr/lib/scrollback-nvim-init.lua"
            expression = "lua HerdrScrollbackView(); assert(not vim.o.modeline); assert(vim.o.tabstop == 8); assert(vim.o.cmdheight == 0); assert(not vim.wo.wrap); assert(vim.fn.winsaveview().topline == 5001); for _, line in ipairs(vim.api.nvim_buf_get_lines(0, 0, -1, false)) do assert(not line:find(string.char(27), 1, true)) end"
            result = subprocess.run(["nvim", "--headless", "-u", str(init), str(file), "-c", expression, "-c", "qa!"], env={**os.environ, "HERDR_SCROLLBACK_VIEWPORT_ROWS": "8"}, capture_output=True, text=True, timeout=10)
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertNotIn("Error", result.stderr)

    @unittest.skipUnless(shutil.which("nvim"), "Neovim required")
    def test_bottom_and_last_prompt_navigation_survive(self):
        with tempfile.TemporaryDirectory(prefix="scrollback-nvim-", dir="/tmp") as temporary:
            file = Path(temporary) / "history"
            file.write_text("❯ first prompt\nfirst answer\n\n❯ last prompt\nlast answer\nlast line\n")
            init = ROOT / "dot_config/herdr/lib/scrollback-nvim-init.lua"
            for jump, expected in ((False, 6), (True, 4)):
                options = "{ jump = true }" if jump else "{}"
                expression = f"lua HerdrScrollbackView({options}); assert(vim.api.nvim_win_get_cursor(0)[1] == {expected})"
                result = subprocess.run(["nvim", "--headless", "-u", str(init), str(file), "-c", expression, "-c", "qa!"], capture_output=True, text=True, timeout=10)
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertNotIn("Error", result.stderr)


@unittest.skipUnless(os.environ.get("HERDR_SCROLLBACK_LIVE_TEST") == "1", "live test requires explicit opt-in")
class LiveViewerTests(unittest.TestCase):
    def test_geometry_source_processes_and_escape_cleanup(self):
        self.assertEqual(os.environ.get("HERDR_ENV"), "1")
        rpc = overlay.request
        original = rpc("pane.layout", {})["layout"]
        source_tab = viewer_tab = None
        temporary_views = []
        fixture = "\n".join([
            "import os, signal, time", "time.sleep(0.8)", "changes = 0",
            "def draw(*args):", " global changes", " if args: changes += 1",
            " width, height = os.get_terminal_size()",
            ' rows = [f"SIZE {width}x{height} RESIZES {changes}", "❯ first prompt", "first answer", "", "❯ last prompt", "last answer"]',
            ' rows += [""] * (height - len(rows) - 4) + ["─" * width, "❯ draft input", "ccstatus: model · context · cost", ""]',
            ' screen = "\\x1b[2J" + "".join(f"\\x1b[{i + 1};1H{row}" for i, row in enumerate(rows))',
            " os.write(1, screen.encode())", "signal.signal(signal.SIGWINCH, draw)",
            "draw()", "while True: signal.pause()",
        ])

        def visible(pane):
            rows = rpc("pane.get", {"pane_id": pane})["pane"]["scroll"]["viewport_rows"]
            return rpc("pane.read", {"pane_id": pane, "source": "visible", "format": "text", "lines": rows})["read"]["text"]

        try:
            created = rpc("layout.apply", {
                "workspace_id": original["workspace_id"], "tab_label": "scrollback-live-test", "focus": True,
                "root": {"type": "split", "direction": "right", "ratio": 0.5,
                         "first": {"type": "pane", "command": ["python3", "-c", fixture]},
                         "second": {"type": "pane", "command": ["python3", "-c", fixture]}},
            })["layout"]
            source_tab = created["tab_id"]
            target, sibling = created["root"]["second"]["pane_id"], created["root"]["first"]["pane_id"]
            rpc("pane.focus", {"pane_id": target})
            time.sleep(1.2)
            for mode, zoomed in (("bottom", False), ("prompt", False), ("bottom", True)):
                with self.subTest(mode=mode, zoomed=zoomed):
                    rpc("pane.zoom", {"pane_id": target, "mode": "on" if zoomed else "off"})
                    time.sleep(0.2)
                    baseline = rpc("pane.layout", {"pane_id": target})["layout"]
                    dimensions = {pane["pane_id"]: pane["rect"] for pane in baseline["panes"]}
                    before = {pane: visible(pane) for pane in (target, sibling)}
                    processes = {pane: rpc("pane.process_info", {"pane_id": pane})["process_info"]["foreground_process_group_id"] for pane in (target, sibling)}
                    applied = []

                    def record(method, params):
                        result = rpc(method, params)
                        if method == "layout.apply":
                            applied.append((params, result["layout"]))
                        return result

                    with patch.object(overlay, "request", record), patch.dict(os.environ, {
                        "HERDR_PANE_ID": target, "HERDR_PLUGIN_CONTEXT_JSON": "{}",
                        "HERDR_SCROLLBACK_INIT": str(ROOT / "dot_config/herdr/lib/scrollback-nvim-init.lua"),
                    }):
                        overlay.open_viewer(mode)
                    params, view = applied[0]
                    viewer_tab = view["tab_id"]
                    temporary_views.append((viewer_tab, Path(params["root"]["second"]["command"][3])))
                    viewer, frozen = view["root"]["second"]["pane_id"], view["root"]["first"]["pane_id"]
                    time.sleep(0.7)
                    view_layout = rpc("pane.layout", {"pane_id": viewer})["layout"]
                    self.assertEqual(view_layout["zoomed"], baseline["zoomed"])
                    view_dimensions = {pane["pane_id"]: pane["rect"] for pane in view_layout["panes"]}
                    self.assertEqual(view_dimensions[viewer], dimensions[target])
                    if mode == "bottom":
                        self.assertEqual(visible(viewer).splitlines(), before[target].splitlines())
                    if not zoomed:
                        self.assertEqual(view_dimensions[frozen], dimensions[sibling])
                        self.assertEqual(visible(frozen).splitlines(), before[sibling].splitlines())
                    for pane in (target, sibling):
                        self.assertEqual(visible(pane), before[pane])
                        self.assertEqual(rpc("pane.process_info", {"pane_id": pane})["process_info"]["foreground_process_group_id"], processes[pane])
                    info = rpc("pane.process_info", {"pane_id": viewer})["process_info"]
                    self.assertTrue(any("nvim" in process.get("argv0", "") or "nvim" in process.get("name", "") for process in info["foreground_processes"]))
                    snapshot = Path(params["root"]["second"]["command"][3])
                    rpc("pane.send_keys", {"pane_id": viewer, "keys": ["esc"]})
                    deadline = time.monotonic() + 5
                    while viewer_tab in {tab["tab_id"] for tab in rpc("tab.list", {})["tabs"]}:
                        self.assertLess(time.monotonic(), deadline, "viewer did not close")
                        time.sleep(0.05)
                    viewer_tab = None
                    self.assertFalse(snapshot.parent.exists())
                    self.assertEqual(rpc("pane.layout", {})["layout"]["tab_id"], source_tab)
                    print(f"Live {mode}, zoom={zoomed}: geometry, source PTYs, Neovim and Escape cleanup passed")
        finally:
            remaining = {tab["tab_id"] for tab in rpc("tab.list", {})["tabs"]}
            for tab_id, snapshot in temporary_views:
                if tab_id in remaining:
                    rpc("tab.close", {"tab_id": tab_id})
                overlay.cleanup_files(snapshot)
            rpc("tab.focus", {"tab_id": original["tab_id"]})
            if source_tab:
                rpc("tab.close", {"tab_id": source_tab})


if __name__ == "__main__":
    unittest.main()
