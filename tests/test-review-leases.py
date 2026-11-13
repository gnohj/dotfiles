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
        self.wt = self.home / "pool/123"
        self.wt.mkdir(parents=True)
        config = self.home / ".config/gh-dash"
        config.mkdir(parents=True)
        worktree = config / "review-worktree.sh"
        shutil.copy(ROOT / "dot_config/gh-dash/executable_review-worktree.sh", worktree)
        worktree.chmod(0o755)
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
        self.lease("123")

    def lease(self, *prs):
        pool = self.home / ".treehouse/pool/treehouse-state.json"
        pool.parent.mkdir(parents=True, exist_ok=True)
        pool.write_text(
            json.dumps(
                {
                    "worktrees": [
                        {
                            "leased": True,
                            "lease_holder": f"review-{pr}",
                            "path": str(self.wt),
                        }
                        for pr in prs
                    ]
                }
            )
        )

    def returned(self):
        path = self.home / "returns"
        for _ in range(500):
            if path.exists():
                return [json.loads(line) for line in path.read_text().splitlines()]
            time.sleep(0.01)
        return []

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
            {"TEST_PANE": "rex"},
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

    def test_review_tab_preserves_lease(self):
        result = self.cleanup_command(TEST_TAB="rex")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertFalse((self.home / "returns").exists())

    def test_explicit_release_returns_despite_open_tab(self):
        result = self.cleanup_command("release", TEST_TAB="rex")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(
            self.returned(),
            [["return", str(self.wt), "--force", "--if-lease-holder", "review-123"]],
        )

    def test_occupied_or_unknown_panes_preserve_lease(self):
        for state in [{"TEST_FAIL": "rex"}, {"TEST_PANE": "rex"}]:
            with self.subTest(state=state):
                result = self.cleanup_command(**state)
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertFalse((self.home / "returns").exists())

    def test_failed_listing_keeps_every_lease(self):
        self.lease("123", "456")
        for failed in ["rex", "process"]:
            with self.subTest(failed=failed):
                result = self.cleanup_command(TEST_FAIL=failed)
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertFalse((self.home / "returns").exists())

    def test_malformed_listing_keeps_lease(self):
        self.cleanup_command(TEST_MALFORMED="1")
        self.assertFalse((self.home / "returns").exists())

    def test_all_empty_releases(self):
        result = self.cleanup_command(TEST_EMPTY_PANES="1")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(
            self.returned(),
            [["return", str(self.wt), "--force", "--if-lease-holder", "review-123"]],
        )


if __name__ == "__main__":
    unittest.main()
