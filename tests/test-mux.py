#!/usr/bin/env python3
import json
import shutil
import subprocess
import tempfile
import time
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


class MuxTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory(prefix="mux-test-")
        self.addCleanup(self.tmp.cleanup)
        self.home = Path(self.tmp.name)
        self.bin = self.home / ".local/bin"
        self.bin.mkdir(parents=True)
        shutil.copytree(ROOT / "dot_local/bin/mux/shared", self.bin / "mux/shared")
        self.mux = ROOT / "dot_local/bin/mux/executable_mux"
        self.env = {
            "HOME": str(self.home),
            "PATH": f"{self.bin}:/usr/bin:/bin",
            "SHELL": "/bin/bash",
            "LC_ALL": "C.UTF-8",
        }
        self.stub(
            "rex",
            """
assert args.pop(0) == "--autostart=false", args
if args == ["server", "status"]:
    sys.exit(0 if os.getenv("TEST_REX") else 4)
elif args[:2] == ["window", "new"]:
    if os.getenv("TEST_NEW_FAIL"):
        sys.exit(1)
    print(json.dumps({} if os.getenv("TEST_NO_BLOCK") else {"session_id": "session:origin", "window_id": "window:new", "block_ids": ["block:new"]}))
elif args[:2] == ["session", "inspect"]:
    print(json.dumps({"label": "review"}))
elif args == ["client", "ls", "--json"]:
    print(json.dumps({"clients": [] if os.getenv("TEST_NO_CLIENT") else [
        {"client_id": "client:old", "info": {"kind": "app"}, "connection_state": "connected", "connected_at": 1},
        {"client_id": "client:new", "info": {"kind": "app"}, "connection_state": "connected", "connected_at": 2},
        {"client_id": "client:gone", "info": {"kind": "app"}, "connection_state": "disconnected", "connected_at": 3}]}))
elif args[:2] == ["block", "call"] or args[:1] == ["-C"]:
    pass
else:
    sys.exit("unexpected Rex argv: " + repr(args))
""",
        )
        for name in ["jq", "lua"]:
            real = shutil.which(name)
            if real:
                (self.bin / name).symlink_to(real)

    def stub(self, name, body):
        path = self.bin / name
        path.write_text(
            f"#!{shutil.which('python3')}\nimport json, os, sys\nargs = sys.argv[1:]\nwith open(os.path.join(os.environ['HOME'], 'argv.jsonl'), 'a') as log:\n    log.write(json.dumps([os.path.basename(sys.argv[0]), args]) + '\\n')\n"
            + body
        )
        path.chmod(0o755)
        return path

    def run_mux(self, *args, **env):
        return subprocess.run(
            ["/bin/bash", str(self.mux), *args],
            env=self.env | env,
            text=True,
            capture_output=True,
            check=False,
        )

    def test_detection_matrix(self):
        cases = [
            ({"TERM_PROGRAM": "rex", "REX_BLOCK": "b"}, "rex"),
            ({"REX_BLOCK": "b"}, "none"),
            ({"TERM_PROGRAM": "rex"}, "none"),
            ({"MUX_FORCE_KIND": "rex"}, "rex"),
            ({"TEST_REX": "1"}, "rex"),
            ({}, "none"),
        ]
        for env, expected in cases:
            with self.subTest(env=env):
                result = self.run_mux("kind", **env)
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertEqual(result.stdout.strip(), expected)

    def test_rex_bin_dir_without_path_binary(self):
        rex_dir = self.home / "rex-bundle"
        rex_dir.mkdir()
        (self.bin / "rex").rename(rex_dir / "rex")
        result = self.run_mux("kind", REX_BIN_DIR=str(rex_dir), TEST_REX="1")
        self.assertEqual(result.stdout.strip(), "rex")

    def recorded(self, name="rex"):
        return [
            args
            for tool, args in map(
                json.loads, (self.home / "argv.jsonl").read_text().splitlines()
            )
            if tool == name
        ]

    def test_rex_window_options(self):
        cases = [
            ([], []),
            (["--keep-open"], ["--keep-open"]),
            (["--no-focus"], ["--focus=false"]),
            (["--focus", "--no-focus"], ["--focus=false"]),
        ]
        for options, expected in cases:
            with self.subTest(options=options):
                (self.home / "argv.jsonl").write_text("")
                result = self.run_mux(
                    "window",
                    *options,
                    "--print-pane",
                    "Review",
                    "/a path",
                    "echo 'ok'",
                    MUX_FORCE_KIND="rex",
                    REX_SESSION="session:origin",
                )
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertEqual(result.stdout, "block:new\n")
                calls = self.recorded()
                self.assertEqual(
                    calls[0],
                    [
                        "--autostart=false",
                        "window",
                        "new",
                        "-s",
                        "session:origin",
                        "Review",
                        "-c",
                        "/a path",
                        *expected,
                        "--shell=none",
                        "--json",
                        "--",
                        "env",
                        "SKIP_FETCH=1",
                        "/bin/bash",
                        "-lic",
                        "echo 'ok'",
                    ],
                )
                self.assertEqual(
                    calls[1],
                    [
                        "--autostart=false",
                        "block",
                        "call",
                        "-s",
                        "session:origin",
                        "-b",
                        "block:new",
                        "resize",
                        '{"columns":200,"rows":50}',
                    ],
                )
                if "--no-focus" in options:
                    self.assertEqual(len(calls), 2)
                    continue
                self.assertEqual(len(calls), 4)
                self.assertEqual(
                    calls[-1],
                    [
                        "--autostart=false",
                        "-C",
                        "client:new",
                        "do",
                        "session.select",
                        "session_id=session:origin",
                        "window_id=window:new",
                    ],
                )

    def test_rex_window_env_and_workspace_and_focus(self):
        result = self.run_mux(
            "window",
            "--workspace",
            "session:target",
            "--env",
            "A=b c",
            "--env",
            "B=it's $literal;*",
            "--focus",
            "Review",
            "~/a path",
            "echo ok",
            MUX_FORCE_KIND="rex",
            REX_SESSION="session:origin",
        )
        self.assertEqual(result.returncode, 0, result.stderr)
        calls = self.recorded()
        self.assertEqual(
            calls[0],
            [
                "--autostart=false",
                "window",
                "new",
                "-s",
                "session:target",
                "Review",
                "-c",
                str(self.home / "a path"),
                "--shell=none",
                "--json",
                "--",
                "env",
                "SKIP_FETCH=1",
                "A=b c",
                "B=it's $literal;*",
                "/bin/bash",
                "-lic",
                "echo ok",
            ],
        )
        self.assertEqual(
            calls[-1],
            [
                "--autostart=false",
                "-C",
                "client:new",
                "do",
                "session.select",
                "session_id=session:target",
                "window_id=window:new",
            ],
        )

    def test_rex_session_label(self):
        result = self.run_mux(
            "session-label", MUX_FORCE_KIND="rex", REX_SESSION="session:origin"
        )
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(result.stdout, "review\n")
        self.assertEqual(
            self.recorded(),
            [["--autostart=false", "session", "inspect", "session:origin", "--json"]],
        )

    def test_rex_window_failures(self):
        for env in [
            {"TEST_NEW_FAIL": "1"},
            {"TEST_NO_BLOCK": "1"},
            {"TEST_NO_CLIENT": "1"},
        ]:
            with self.subTest(env=env):
                result = self.run_mux(
                    "window",
                    "--focus",
                    "Review",
                    "/tmp",
                    "true",
                    MUX_FORCE_KIND="rex",
                    REX_SESSION="session:origin",
                    **env,
                )
                self.assertNotEqual(result.returncode, 0)

    def install_reviews(self):
        config = self.home / ".config/gh-dash"
        config.mkdir(parents=True)
        shutil.copy(ROOT / "dot_config/gh-dash/review-mux.sh", config / "review-mux.sh")
        (self.home / ".config/devbox-host").write_text("devbox\n")
        shutil.copy(self.mux, self.bin / "mux/mux")
        self.stub(
            "rex",
            """
assert args.pop(0) == "--autostart=false", args
if os.getenv("TEST_REX_DOWN"):
    sys.exit(4)
if args == ["ls", "--json"]:
    print(json.dumps({"sessions": [{"session_id": "session:web", "label": "web/review"}, {"session_id": "session:inferno", "label": "inferno/review"}]}))
elif args[:2] == ["window", "ls"]:
    print(json.dumps({"windows": [{"window_id": "window:review", "label": "🤖 #123"}] if os.getenv("TEST_EXISTING") else []}))
else:
    sys.exit("unexpected Rex argv: " + repr(args))
""",
        )
        self.stub("uname", 'print(os.getenv("TEST_PLATFORM", "Linux"))\n')
        self.stub(
            "ssh",
            """
import subprocess
index = args.index("-s")
script = sys.stdin.read()
with open(os.path.join(os.environ["HOME"], "remote.sh"), "w") as out:
    out.write(script)
sys.exit(subprocess.run(["/bin/bash", "-s", *args[index + 1:]], input=script, text=True, env=dict(os.environ, TEST_PLATFORM="Linux")).returncode)
""",
        )
        self.stub(
            "setsid",
            """
assert args.pop(0) == "-f", args
os.execvp(args[0], args)
""",
        )
        self.stub("nohup", "os.execvp(args[0], args)\n")
        self.stub(
            "record-review",
            """
with open(os.path.join(os.environ["HOME"], "opened.json"), "w") as out:
    json.dump({"argv": args, "env": dict(os.environ)}, out)
""",
        )
        launcher = config / "review-open.sh"
        launcher.write_text('#!/bin/bash\nexec "$HOME/.local/bin/record-review" "$@"\n')
        launcher.chmod(0o755)
        self.stub(
            "gh",
            """
if args == ["api", "user", "--jq", ".login"]:
    print("captain")
elif args[:2] == ["search", "prs"]:
    print(json.dumps([{ "number": 123, "title": "Fix bug", "url": "https://github.com/iheartradio/web/pull/123", "repository": {"nameWithOwner": "iheartradio/web"}}] if args[args.index("--repo") + 1] == "iheartradio/web" else []))
elif args[:2] == ["pr", "view"]:
    print(json.dumps({"reviews": [], "title": "Fix bug", "baseRefName": "main", "headRefName": "fix"}))
else:
    sys.exit("unexpected gh argv: " + repr(args))
""",
        )
        for name in ["mac-notify", "review-worktree", "review-dispatch"]:
            self.stub(name, "pass\n")
        (config / "review-filter-bots.sh").write_text("#!/bin/bash\nexec /bin/cat\n")
        (config / "review-filter-bots.sh").chmod(0o755)
        self.env |= {
            "GH_AUTO_REVIEW_WORKTREE": str(self.bin / "review-worktree"),
            "GH_AUTO_REVIEW_DISPATCH": str(self.bin / "review-dispatch"),
            "GH_AUTO_REVIEW_MODE": "full",
        }

    def run_script(self, path, *args, **env):
        return subprocess.run(
            ["/bin/bash", str(ROOT / path), *args],
            env=self.env | env,
            capture_output=True,
            text=True,
            check=False,
        )

    def opened(self):
        path = self.home / "opened.json"
        for _ in range(100):
            try:
                return json.loads(path.read_text())
            except (FileNotFoundError, json.JSONDecodeError):
                time.sleep(0.01)
        self.fail("review-open was not called")

    def review_log(self):
        return (self.home / ".local/state/gh-review-open.log").read_text()

    def assert_unpinned(self, env):
        for name in ["MUX_FORCE_KIND", "REX_SESSION"]:
            self.assertNotIn(name, env)

    def adopt(self, **env):
        result = subprocess.run(
            [
                "/bin/bash",
                "-c",
                '. "$HOME/.config/gh-dash/review-mux.sh"; review_mux_adopt "$1"; env',
                "_",
                str(self.home / "Developer/web/review"),
            ],
            env=self.env | env,
            capture_output=True,
            text=True,
            check=False,
        )
        self.assertEqual(result.returncode, 0, result.stderr)
        lines = result.stdout.splitlines()
        return dict(line.split("=", 1) for line in lines if "=" in line)

    def test_review_adopt_places_the_review(self):
        self.install_reviews()
        inherited = {"REX_SESSION": "session:pane"}
        env = self.adopt(**inherited)
        self.assertEqual(env["MUX_FORCE_KIND"], "rex")
        self.assertEqual(env["REX_SESSION"], "session:web")
        env = self.adopt(**inherited, TEST_REX_DOWN="1")
        self.assertNotIn("MUX_FORCE_KIND", env)
        self.assertEqual(env["REX_SESSION"], "session:pane")
        env = self.adopt(**inherited, REVIEW_PLACED="1")
        self.assertNotIn("MUX_FORCE_KIND", env)
        self.assertEqual(env["REX_SESSION"], "session:pane")

    def test_review_devbox_remote_fallback(self):
        self.install_reviews()
        result = self.run_script(
            "dot_config/gh-dash/executable_review-devbox.sh",
            "full",
            "123",
            "iheartradio/web",
            TEST_PLATFORM="Darwin",
        )
        self.assertEqual(result.returncode, 0, self.review_log())
        opened = self.opened()
        self.assertEqual(
            opened["argv"],
            [
                "full",
                "123",
                "iheartradio/web",
                str(self.home / "Developer/web/review"),
            ],
        )
        self.assert_unpinned(opened["env"])
        self.assertIn("in workspace session:web", self.review_log())
        self.assertTrue(self.recorded("ssh"))

    def test_review_devbox_missing_target(self):
        self.install_reviews()
        result = self.run_script(
            "dot_config/gh-dash/executable_review-devbox.sh",
            "full",
            "123",
            "iheartradio/web",
            TEST_REX_DOWN="1",
        )
        self.assertNotEqual(result.returncode, 0)
        self.assertFalse((self.home / "opened.json").exists())

    def test_auto_review_rex_local_and_remote(self):
        self.install_reviews()
        for platform in ["Linux", "Darwin"]:
            with self.subTest(platform=platform):
                result = self.run_script(
                    "dot_config/gh-dash/executable_auto-review.sh",
                    TEST_PLATFORM=platform,
                )
                self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
                opened = self.opened()
                self.assertEqual(opened["env"]["MUX_FORCE_KIND"], "rex")
                self.assertEqual(opened["env"]["REX_SESSION"], "session:web")
                (self.home / "opened.json").unlink()
        result = self.run_script(
            "dot_config/gh-dash/executable_auto-review.sh", TEST_EXISTING="1"
        )
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertIn("review tabs are already open", result.stdout)
        self.assertFalse((self.home / "opened.json").exists())

    def test_review_resume_rex_and_duplicate_guard(self):
        self.install_reviews()
        artifact = self.home / ".local/state/gh-review-lavish/123/review.html"
        artifact.parent.mkdir(parents=True)
        artifact.write_text("review")
        result = self.run_script(
            "dot_local/bin/executable_review-lavish-resume",
            "123",
            "iheartradio/web",
        )
        self.assertEqual(result.returncode, 0, result.stderr)
        opened = self.opened()
        self.assertEqual(opened["argv"][0], "resume")
        self.assertEqual(opened["env"]["MUX_FORCE_KIND"], "rex")
        self.assertEqual(opened["env"]["REX_SESSION"], "session:web")
        (self.home / "opened.json").unlink()
        result = self.run_script(
            "dot_local/bin/executable_review-lavish-resume",
            "123",
            "iheartradio/web",
            TEST_EXISTING="1",
        )
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("already has a review tab", result.stderr)
        self.assertFalse((self.home / "opened.json").exists())

    def test_nvim_detection_mirror(self):
        lua = shutil.which("lua")
        if not lua:
            self.skipTest("lua unavailable")
        script = """
local path = arg[1]
local cases = {
  {{TERM_PROGRAM="rex", REX_BLOCK="b"}, "rex"},
  {{REX_BLOCK="b"}, nil},
  {{MUX_FORCE_KIND="rex"}, "rex"},
}
for _, case in ipairs(cases) do
  vim = {env=case[1], fn={system=function() return "none" end, expand=function(s) return s end}, v={shell_error=0}, trim=function(s) return s end}
  local mux = dofile(path)
  assert(mux.kind() == case[2], "unexpected kind: " .. tostring(mux.kind()))
end
"""
        result = subprocess.run(
            [lua, "-", str(ROOT / "dot_config/nvim/lua/config/mux.lua")],
            input=script,
            text=True,
            capture_output=True,
            env=self.env,
            check=False,
        )
        self.assertEqual(result.returncode, 0, result.stderr)


if __name__ == "__main__":
    unittest.main()
