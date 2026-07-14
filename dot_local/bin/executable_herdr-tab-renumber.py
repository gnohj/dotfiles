#!/usr/bin/env python3
"""herdr-tab-renumber — tmux-style position renumbering for labeled herdr tabs.

herdr's tab `number` is a STABLE per-workspace creation counter — it never
renumbers on delete and there's no `renumber-windows` equivalent, so a
programmatic "<n>.<label>" prefix goes stale (delete `3.🔀` → `4.✨`/`5.…` keep
their numbers instead of shifting to 3/4). This daemon restores the tmux feel: on
every tab created / closed / moved it rewrites EVERY tab's label to its current
1-based POSITION in the tab bar, per workspace: "<n>.<rest>" and bare "<n>" are
re-set to the position, a non-numeric label X becomes "<pos>.X", and an empty tab
becomes just "<pos>". Renames emit `tab_renamed`, which is NOT subscribed, so
there is no feedback loop, and once every label is position-correct a re-run makes
no changes (no thrash).

Mirrors herdr-review-sweep.py: flock'd pidfile, grace-window exit, trailing-edge
debounce. Started eagerly from dot_zshrc when in a herdr pane (and also `ensure`d
from the tab-creating scripts), so it runs for every session/workspace — no
launchd. On startup it does one renumber pass to fix whatever is already open.
"""
import json
import os
import re
import shutil
import socket
import subprocess
import sys
import time

STATE_DIR = os.path.join(
    os.environ.get("XDG_STATE_HOME", os.path.expanduser("~/.local/state")), "herdr"
)
PID_FILE = os.path.join(STATE_DIR, "tab-renumber.pid")
LOG_FILE = os.path.join(STATE_DIR, "tab-renumber.log")

RECONNECT_GRACE_SECONDS = 20
SETTLE_SECONDS = 0.4  # trailing-edge: renumber once after a burst of tab events
# Safety net: renumber at least this often regardless of events. The event
# subscription is the fast path, but a tab_closed can slip through (startup gap
# before subscribe, brief disconnect, sleep/wake) and there's no other recovery
# — a missed event otherwise leaves a stale "<n>.<label>" until the next restart.
# renumber() is idempotent, so a no-change heartbeat pass is two reads, no renames.
HEARTBEAT_SECONDS = 10
# Optional leading "<n>" with an optional ".<rest>": captures the content after the
# number so it survives a renumber. "3.🐙"→rest "🐙"; bare "3"→rest ""; a
# non-numeric label falls through (no match) and keeps its whole text as rest.
NUM_RE = re.compile(r"^(\d+)(?:\.(.*))?$", re.DOTALL)


def herdr_bin():
    h = os.environ.get("HERDR_BIN_PATH")
    if h:
        return h
    return shutil.which("herdr") or "/run/current-system/sw/bin/herdr"


def sock_path():
    return os.environ.get(
        "HERDR_SOCKET_PATH", os.path.expanduser("~/.config/herdr/herdr.sock")
    )


def herdr_json(args):
    try:
        out = subprocess.run(
            [herdr_bin(), *args], capture_output=True, text=True, timeout=5
        )
        return json.loads(out.stdout or "null")
    except Exception:
        return None


def renumber():
    """Number EVERY tab by its 1-based bar position, per workspace.

    "<n>.<rest>" and bare "<n>" are re-set to the position; a non-numeric label X
    becomes "<pos>.X"; an empty tab becomes just "<pos>". Once every label is
    position-correct a re-run makes no changes, so there is no thrash.
    """
    wl = herdr_json(["workspace", "list"])
    for ws in ((wl or {}).get("result", {}) or {}).get("workspaces", []) or []:
        wid = ws.get("workspace_id")
        if not wid:
            continue
        tl = herdr_json(["tab", "list", "--workspace", wid])
        tabs = ((tl or {}).get("result", {}) or {}).get("tabs", []) or []
        for i, tab in enumerate(tabs, start=1):
            label = tab.get("label") or ""
            m = NUM_RE.match(label)
            rest = (m.group(2) or "") if m else label
            desired = ("%d.%s" % (i, rest)) if rest else str(i)
            if desired != label:
                tid = tab.get("tab_id")
                if tid:
                    subprocess.run(
                        [herdr_bin(), "tab", "rename", tid, desired],
                        stdout=subprocess.DEVNULL,
                        stderr=subprocess.DEVNULL,
                        timeout=5,
                    )


def run_daemon():
    import fcntl
    import signal

    os.makedirs(STATE_DIR, exist_ok=True)
    lock = open(PID_FILE, "a+")
    try:
        fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
    except OSError:
        return  # another daemon already owns the lock
    lock.seek(0)
    lock.truncate()
    lock.write(str(os.getpid()))
    lock.flush()

    log = open(LOG_FILE, "a")

    def logline(msg):
        log.write("%d %s\n" % (int(time.time()), msg))
        log.flush()

    def cleanup(*_):
        logline("daemon exiting; removing pidfile")
        try:
            os.remove(PID_FILE)
        except OSError:
            pass
        os._exit(0)

    signal.signal(signal.SIGTERM, cleanup)
    signal.signal(signal.SIGINT, cleanup)

    logline("daemon started")
    renumber()  # fix whatever is already open before we start listening
    last_pass = time.time()
    down_since = None
    while True:
        try:
            s = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
            s.settimeout(0.3)
            s.connect(sock_path())
            s.sendall(
                (
                    json.dumps(
                        {
                            "id": "sub",
                            "method": "events.subscribe",
                            "params": {
                                "subscriptions": [
                                    {"type": "tab.created"},
                                    {"type": "tab.closed"},
                                    {"type": "tab.moved"},
                                ]
                            },
                        }
                    )
                    + "\n"
                ).encode()
            )
            down_since = None
            buf = b""
            pending = None  # trailing-edge timer
            while True:
                try:
                    chunk = s.recv(4096)
                    if not chunk:
                        raise ConnectionError("herdr closed the event stream")
                    buf += chunk
                    while b"\n" in buf:
                        line, buf = buf.split(b"\n", 1)
                        if not line.strip():
                            continue
                        try:
                            msg = json.loads(line)
                        except ValueError:
                            continue
                        if msg.get("event") in (
                            "tab_created",
                            "tab_closed",
                            "tab_moved",
                        ):
                            pending = time.time() + SETTLE_SECONDS  # (re)arm
                except socket.timeout:
                    pass
                now = time.time()
                if pending is not None and now >= pending:
                    pending = None
                    renumber()
                    last_pass = now
                elif now - last_pass >= HEARTBEAT_SECONDS:
                    renumber()  # safety net for any event we didn't see
                    last_pass = now
        except Exception as e:
            now = time.time()
            if down_since is None:
                down_since = now
            elif now - down_since >= RECONNECT_GRACE_SECONDS:
                logline("herdr unreachable %ss (%s); exiting" % (RECONNECT_GRACE_SECONDS, e))
                cleanup()
            time.sleep(1.0)


def daemon_alive():
    try:
        with open(PID_FILE) as f:
            pid = int((f.read().strip() or "0"))
        if pid <= 0:
            return False
        os.kill(pid, 0)
        return True
    except Exception:
        return False


def ensure_daemon():
    if daemon_alive():
        return
    subprocess.Popen(
        [sys.executable, os.path.abspath(__file__), "daemon"],
        stdin=subprocess.DEVNULL,
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
        start_new_session=True,
    )


def stop_daemon():
    try:
        with open(PID_FILE) as f:
            pid = int((f.read().strip() or "0"))
        if pid > 0:
            os.kill(pid, 15)
    except Exception:
        pass


def main():
    cmd = sys.argv[1] if len(sys.argv) > 1 else "ensure"
    if cmd == "daemon":
        run_daemon()
    elif cmd == "ensure":
        ensure_daemon()
    elif cmd == "once":
        renumber()
    elif cmd == "stop":
        stop_daemon()
    else:
        sys.stderr.write("usage: %s [daemon|ensure|once|stop]\n" % sys.argv[0])
        sys.exit(2)


if __name__ == "__main__":
    main()
