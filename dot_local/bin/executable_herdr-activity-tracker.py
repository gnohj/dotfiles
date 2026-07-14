#!/usr/bin/env python3
"""herdr-activity-tracker — "jump to the last emitted notification" for herdr.

herdr's built-in open_notification_target (bound to a key) is supposed to focus the
pane behind the most recent toast, but in herdr 0.7.3 it doesn't resolve a target and
silently no-ops (confirmed dead on both prefix+' and prefix+o). There is also no socket
method to drive it. This fills the gap: a tiny daemon that remembers which agent most
recently emitted a notification — blocked (needs input) OR finished (working -> idle) —
and a `jump` command that focuses it.

WHY a poll instead of an event stream: herdr's pane.agent_status_changed subscription is
PER-PANE (it requires a pane_id), so there is no single global "any agent changed" event
to listen on — an event-driven version would have to add/remove a subscription per pane
as panes come and go. A ~0.75s poll of `agent.list` is simpler and plenty responsive for
a jump you press seconds after the toast.

What counts as a "notification" (mirrors what herdr actually toasts):
  * a transition INTO `blocked` (needs-attention), or
  * a transition `working` -> `idle`/`done` (finished),
  * AND only when the pane's workspace is NOT the currently focused one — i.e. a
    background workspace, which is exactly when herdr emits a background toast. A pane
    that blocks/finishes in the workspace you're already looking at didn't ping you, so
    it must not clobber a real background notification.

Design (mirrors herdr-pane-tracker.py):
  * `daemon` polls agent.list + workspace.list, tracks each pane's previous status, and
    writes {pane_id, workspace_id} of the latest background notification to a JSON state
    file. Single-instance via an flock on the pidfile; exits (and removes the pidfile)
    once herdr has been unreachable for a short grace window, so it lives exactly as long
    as herdr does.
  * `jump` (bound to prefix+' via a type="shell" keybinding) lazy-starts the daemon if
    needed, then focuses the recorded pane via pane.focus (the only by-id focus, reachable
    only over the raw socket). Cold-start caveat: a notification that fired BEFORE the
    daemon was ever started can't be recorded — start it eagerly from the shell rc (see
    the HERDR_WORKSPACE_ID guard in dot_zshrc) so it's up before the first toast.
"""
import json
import os
import socket
import subprocess
import sys
import time

STATE_DIR = os.path.join(
    os.environ.get("XDG_STATE_HOME", os.path.expanduser("~/.local/state")), "herdr"
)
STATE_FILE = os.path.join(STATE_DIR, "last-activity-state.json")
PID_FILE = os.path.join(STATE_DIR, "activity-tracker.pid")
LOG_FILE = os.path.join(STATE_DIR, "activity-tracker.log")

POLL_INTERVAL = 0.75
RECONNECT_GRACE_SECONDS = 20


def sock_path():
    return os.environ.get(
        "HERDR_SOCKET_PATH", os.path.expanduser("~/.config/herdr/herdr.sock")
    )


def call(obj, timeout=2.0):
    """One request/response round-trip (herdr closes the connection after replying)."""
    s = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
    s.settimeout(timeout)
    s.connect(sock_path())
    s.sendall((json.dumps(obj) + "\n").encode())
    buf = b""
    try:
        while b"\n" not in buf and len(buf) < 1 << 20:
            chunk = s.recv(4096)
            if not chunk:
                break
            buf += chunk
    except socket.timeout:
        pass
    finally:
        s.close()
    if not buf.strip():
        return None
    return json.loads(buf.split(b"\n", 1)[0])


def load_state():
    try:
        with open(STATE_FILE) as f:
            return json.load(f)
    except Exception:
        return {}


def save_state(state):
    os.makedirs(STATE_DIR, exist_ok=True)
    tmp = STATE_FILE + ".tmp"
    with open(tmp, "w") as f:
        json.dump(state, f)
    os.replace(tmp, STATE_FILE)  # atomic


# ---------------------------------------------------------------------------- daemon
def poll_once(prev, first, log=None):
    """Poll agent statuses once; record the latest background notification. Returns the
    updated `prev` status map. On the first poll we only seed the baseline (no synthetic
    notifications for statuses that were already there before the daemon started)."""
    agents = (call({"id": "al", "method": "agent.list", "params": {}}) or {}).get(
        "result", {}
    ).get("agents", [])
    wss = (call({"id": "wl", "method": "workspace.list", "params": {}}) or {}).get(
        "result", {}
    ).get("workspaces", [])
    focused_ws = next((w.get("workspace_id") for w in wss if w.get("focused")), None)

    for a in agents:
        pane = a.get("pane_id")
        ws = a.get("workspace_id")
        st = a.get("agent_status")
        if not pane:
            continue
        old = prev.get(pane)
        prev[pane] = st
        if first or old == st:
            continue
        newly_blocked = st == "blocked" and old != "blocked"
        finished = st in ("idle", "done") and old == "working"
        if not (newly_blocked or finished):
            continue
        # Only a background workspace actually emits a toast: a pane that blocks/finishes
        # in the workspace you're already viewing didn't ping you, so it must not clobber
        # a real background notification. If we can't tell which workspace is focused, fail
        # open and record it. Log only actual records (per-turn idle<->working churn would
        # otherwise bloat the log across a long session).
        if focused_ws is not None and ws == focused_ws:
            continue
        if log:
            log(f"record {pane} {ws} {old}->{st} (focused={focused_ws})")
        save_state({"pane_id": pane, "workspace_id": ws})
    return prev


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
        log.write(f"{int(time.time())} {msg}\n")
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
    prev = {}
    first = True
    down_since = None
    while True:
        try:
            prev = poll_once(prev, first, log=logline)
            first = False
            down_since = None
        except Exception as e:
            now = time.time()
            if down_since is None:
                down_since = now
            elif now - down_since >= RECONNECT_GRACE_SECONDS:
                logline(f"herdr unreachable {RECONNECT_GRACE_SECONDS}s ({e}); exiting")
                cleanup()
        time.sleep(POLL_INTERVAL)


def stop_daemon():
    try:
        with open(PID_FILE) as f:
            pid = int((f.read().strip() or "0"))
        if pid > 0:
            os.kill(pid, 15)  # SIGTERM -> cleanup() removes the pidfile
    except Exception:
        pass


def daemon_alive():
    try:
        with open(PID_FILE) as f:
            pid = int((f.read().strip() or "0"))
        if pid <= 0:
            return False
        os.kill(pid, 0)  # probe; raises if dead
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


# ------------------------------------------------------------------------------ jump
def run_jump():
    ensure_daemon()
    last = load_state()
    pane = last.get("pane_id")
    if not pane:
        return  # nothing recorded yet (daemon just started, or no notifications)
    resp = call({"id": "pl", "method": "pane.list", "params": {}})
    panes = (resp or {}).get("result", {}).get("panes", [])
    if not any(p.get("pane_id") == pane for p in panes):
        return  # the notifying pane is gone
    call({"id": "focus", "method": "pane.focus", "params": {"pane_id": pane}})


def main():
    cmd = sys.argv[1] if len(sys.argv) > 1 else "jump"
    if cmd == "daemon":
        run_daemon()
    elif cmd == "jump":
        run_jump()
    elif cmd == "ensure":
        ensure_daemon()
    elif cmd == "stop":
        stop_daemon()
    else:
        sys.stderr.write(f"usage: {sys.argv[0]} [daemon|jump|ensure|stop]\n")
        sys.exit(2)


if __name__ == "__main__":
    main()
