#!/usr/bin/env python3
import importlib.util
import json
import shutil
import subprocess
import time
import unittest
from pathlib import Path

spec = importlib.util.spec_from_file_location(
    "mux_tests", Path(__file__).with_name("test-mux.py")
)
mux_tests = importlib.util.module_from_spec(spec)
spec.loader.exec_module(mux_tests)
ROOT = mux_tests.ROOT


class ReviewLeaseTests(unittest.TestCase):
    stub = mux_tests.MuxTests.stub
    run_script = mux_tests.MuxTests.run_script
    run_mux = mux_tests.MuxTests.run_mux

    def setUp(self):
        mux_tests.MuxTests.setUp(self)
        self.stub(
            "herdr",
            """
if args == ["status", "server"]:
    print("status: stopped" if os.getenv("TEST_ALL_DOWN") else "status: running")
elif args == ["session", "list"]:
    print("NAME STATUS SOCKET" if os.getenv("TEST_ALL_DOWN") else "NAME STATUS SOCKET\\ndefault running /stub/default\\nother running /stub/other")
elif args == ["workspace", "list"]:
    print(json.dumps({"result": {"workspaces": [{"workspace_id": "ws"}]}}))
elif args[:2] == ["tab", "list"]:
    if os.getenv("TEST_FAIL") == "herdr": sys.exit(1)
    print(json.dumps({"result": {"tabs": [{"tab_id": "tab", "label": "🤖 #123"}] if os.getenv("TEST_TAB") == "herdr" and os.getenv("HERDR_SOCKET_PATH") == "/stub/other" else []}}))
elif args == ["pane", "list"]:
    print(json.dumps({"result": {"panes": [] if os.getenv("TEST_EMPTY_PANES") else [{"cwd": os.getenv("TEST_CWD") if os.getenv("TEST_PANE") == "herdr" else "/unrelated"}]}}))
else:
    sys.exit("unexpected herdr argv: " + repr(args))
""",
        )
        self.stub(
            "rex",
            """
assert args.pop(0) == "--autostart=false", args
if args == ["server", "status"]:
    sys.exit(4 if os.getenv("TEST_REX_DOWN") or os.getenv("TEST_ALL_DOWN") else 0)
elif args == ["ls", "--json"]:
    print(json.dumps({"sessions": [{"session_id": "session:one"}, {"session_id": "session:two"}]}))
elif args[:2] == ["window", "ls"]:
    if os.getenv("TEST_FAIL") == "rex": sys.exit(1)
    if os.getenv("TEST_MALFORMED"): print("{}"); sys.exit(0)
    print(json.dumps({"windows": [{"window_id": "window:review", "label": "🤖 #123"}] if os.getenv("TEST_TAB") == "rex" and args[3] == "session:two" else []}))
elif args[:2] == ["block", "ls"]:
    print(json.dumps({"blocks": [{"block_id": "block:one"}]}))
elif args[:2] == ["block", "call"]:
    if os.getenv("TEST_FAIL") == "process": sys.exit(1)
    print(json.dumps({"foreground": {"cwd": os.getenv("TEST_CWD")}} if os.getenv("TEST_PANE") == "rex" else {}))
else:
    sys.exit("unexpected Rex argv: " + repr(args))
""",
        )
        self.stub(
            "tmux",
            """
if args == ["ls"]:
    sys.exit(1 if os.getenv("TEST_ALL_DOWN") else 0)
elif args[0] == "list-windows":
    if os.getenv("TEST_FAIL") == "tmux": sys.exit(1)
    if os.getenv("TEST_TAB") == "tmux": print("@1\\t🤖 #123")
elif args[0] == "list-panes":
    if os.getenv("TEST_PANE") == "tmux": print(os.getenv("TEST_CWD"))
else:
    sys.exit("unexpected tmux argv: " + repr(args))
""",
        )
        self.stub(
            "treehouse",
            """
assert args[0] == "return", args
with open(os.path.join(os.environ["HOME"], "returns"), "a") as log:
    log.write(json.dumps(args) + "\\n")
""",
        )
        for name in ["mac-notify", "chrome-headed-bg"]:
            self.stub(name, "pass\n")
        self.stub("lsof", "pass\n")
        self.stub("setsid", "os.execvp(args[0], args)\n")
        self.leases = self.home / ".local/state/gh-review-worktrees"
        self.leases.mkdir(parents=True)
        self.wt = self.home / "pool/123"
        self.wt.mkdir(parents=True)
        self.record = self.leases / "123"
        self.record.write_text(str(self.wt))
        self.env |= {
            "MUX": str(
                self.stub(
                    "mux-command",
                    f'os.execv("/bin/bash", ["bash", {str(self.mux)!r}, *args])\n',
                )
            ),
            "GH_REVIEW_SWEEP_GRACE": "0",
            "TEST_CWD": str(self.wt / "nested"),
        }
        pool = self.home / ".treehouse/pool/treehouse-state.json"
        pool.parent.mkdir(parents=True)
        pool.write_text(
            json.dumps(
                {
                    "worktrees": [
                        {
                            "leased": True,
                            "lease_holder": "review-123",
                            "path": str(self.wt),
                        }
                    ]
                }
            )
        )

    def cleanup_command(self, command="reclaim", **env):
        return self.run_script(
            "dot_config/gh-dash/executable_review-worktree.sh", command, "123", **env
        )

    def run_function(self, relative, function, end, invocation, **env):
        source = (ROOT / relative).read_text()
        script = source[source.index(function + "() {") : source.index(end)]
        return subprocess.run(
            [
                shutil.which("zsh") if function == "treehouse-orphans" else "/bin/bash",
                "-f" if function == "treehouse-orphans" else "-s",
            ],
            input=script + "\n" + invocation,
            env=self.env | env,
            capture_output=True,
            text=True,
            check=False,
        )

    def test_treehouse_orphans_uses_union_and_refuses_failed_probes(self):
        for state in [{"TEST_TAB": "rex"}, {"TEST_PANE": "rex"}, {"TEST_FAIL": "rex"}]:
            with self.subTest(state=state):
                result = self.run_function(
                    "dot_config/zshrc/dot_zshrc",
                    "treehouse-orphans",
                    "# Housekeeping companion to treehouse-orphans",
                    "treehouse-orphans -r",
                    **state,
                )
                self.assertEqual(
                    result.returncode, 1 if state.get("TEST_FAIL") else 0, result.stderr
                )
                self.assertFalse((self.home / "returns").exists())

    def test_wtrm_refuses_busy_or_unknown_union(self):
        for state in [
            {"TEST_TAB": "rex"},
            {"TEST_PANE": "herdr"},
            {"TEST_PANE": "rex"},
            {"TEST_PANE": "tmux"},
            {"TEST_FAIL": "rex"},
            {},
        ]:
            with self.subTest(state=state):
                result = self.run_function(
                    "dot_local/bin/worktree/executable_wtrm",
                    "worktree_available",
                    "delete_one() {",
                    'worktree_available "$HOME/pool/123"',
                    **state,
                )
                self.assertEqual(result.returncode, 1 if state else 0, result.stderr)
                self.assertFalse((self.home / "returns").exists())

    def test_stopped_multiplexers_contribute_nothing(self):
        for query in ["tabs", "pane-cwds"]:
            result = self.run_mux(query, "--all-muxes", TEST_ALL_DOWN="1")
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertEqual(result.stdout, "")

    def test_successful_empty_listings_are_not_errors(self):
        for query in ["tabs", "pane-cwds"]:
            result = self.run_mux(query, "--all-muxes", TEST_EMPTY_PANES="1")
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertEqual(result.stdout, "")

    def test_union_preserves_review_on_each_mux(self):
        for mux in ["herdr", "rex", "tmux"]:
            with self.subTest(mux=mux):
                result = self.cleanup_command(TEST_TAB=mux)
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertTrue(self.record.exists())
                self.assertFalse((self.home / "returns").exists())

    def test_release_refuses_visible_review(self):
        result = self.cleanup_command("release", TEST_TAB="rex")
        self.assertNotEqual(result.returncode, 0)
        self.assertTrue(self.record.exists())
        self.assertFalse((self.home / "returns").exists())

    def test_release_refuses_unknown_or_occupied_panes(self):
        for state in [{"TEST_FAIL": "rex"}, {"TEST_PANE": "rex"}]:
            with self.subTest(state=state):
                result = self.cleanup_command("release", **state)
                self.assertNotEqual(result.returncode, 0)
                self.assertTrue(self.record.exists())
                self.assertFalse((self.home / "returns").exists())

    def test_failed_listing_keeps_every_lease(self):
        second = self.leases / "456"
        second.write_text(str(self.wt))
        for failed in ["herdr", "rex", "tmux", "process"]:
            with self.subTest(failed=failed):
                result = self.cleanup_command(TEST_FAIL=failed)
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertTrue(self.record.exists())
                self.assertTrue(second.exists())
                self.assertFalse((self.home / "returns").exists())

    def test_malformed_listing_keeps_lease(self):
        self.cleanup_command(TEST_MALFORMED="1")
        self.assertTrue(self.record.exists())
        self.assertFalse((self.home / "returns").exists())

    def test_all_empty_releases(self):
        result = self.cleanup_command(TEST_EMPTY_PANES="1")
        self.assertEqual(result.returncode, 0, result.stderr)
        for _ in range(500):
            if not self.record.exists():
                break
            time.sleep(0.01)
        self.assertFalse(self.record.exists())
        self.assertTrue((self.home / "returns").exists())

    def test_pane_on_each_mux_preserves_lease(self):
        for mux in ["herdr", "rex", "tmux"]:
            with self.subTest(mux=mux):
                self.cleanup_command(TEST_PANE=mux)
                self.assertTrue(self.record.exists())
                self.assertFalse((self.home / "returns").exists())

    def test_orphan_lease_preserved_by_review_tab(self):
        self.record.unlink()
        self.cleanup_command(TEST_TAB="rex")
        self.assertFalse((self.home / "returns").exists())


if __name__ == "__main__":
    unittest.main()
