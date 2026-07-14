#!/usr/bin/env python3
"""herdr-pane-tracker — a true per-workspace "last pane" toggle for herdr.

herdr's native last_pane is GLOBAL (bounces to the last-focused pane across
workspaces and tabs), and its only workspace-scoped option is cycle_pane_next, which
cycles rather than toggles. This gives the missing piece: a real A<->B bounce to the
previously focused pane, scoped to the current workspace so it never crosses into
another one.

It has no native equivalent because herdr exposes no "focus a pane by id" CLI and no
focus-history query. Both are reachable over the raw socket API though:
  - pane.focus {pane_id}            -> focus any pane (agent or not) by id
  - events.subscribe pane.focused   -> real-time focus event stream

Design:
  * `daemon` subscribes to pane.focused and keeps, per workspace, {cur, prev} pane
    ids in a small JSON state file. Only real focus CHANGES shift prev (repeated
    same-pane events are ignored), so prev is always the genuinely previous pane.
    Single-instance via an flock on the pidfile; auto-reconnects if herdr restarts.
  * `toggle` (bound to prefix+b via a type="shell" keybinding) lazy-starts the daemon
    if needed, then focuses the current workspace's `prev` pane. Because focusing prev
    emits its own focus event, the daemon swaps cur/prev and the next press bounces
    back — a clean two-pane toggle, no cycling, never leaving the workspace.

Buckets are keyed by workspace_id (HERDR_WORKSPACE_ID at press time), so a jump can
only ever target a pane in the same workspace.
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
STATE_FILE = os.path.join(STATE_DIR, "last-pane-state.json")
PID_FILE = os.path.join(STATE_DIR, "pane-tracker.pid")
LOG_FILE = os.path.join(STATE_DIR, "pane-tracker.log")


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
# When herdr dies the event socket stops accepting connections; rather than linger as
# an orphan, the daemon keeps retrying only for a short grace window (covers a
# reload-config blip) and then exits and removes its pidfile. So it lives exactly as
# long as herdr does, with no external cleanup needed.
RECONNECT_GRACE_SECONDS = 20


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

    # Exit cleanly on SIGTERM/SIGINT (e.g. `pane-tracker stop`) — release the lock and
    # remove the pidfile so a later `ensure` starts fresh.
    signal.signal(signal.SIGTERM, cleanup)
    signal.signal(signal.SIGINT, cleanup)

    logline("daemon started")
    down_since = None  # timestamp of first failure in the current outage
    while True:
        try:
            s = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
            s.settimeout(None)
            s.connect(sock_path())
            s.sendall(
                (
                    json.dumps(
                        {
                            "id": "sub",
                            "method": "events.subscribe",
                            "params": {"subscriptions": [{"type": "pane.focused"}]},
                        }
                    )
                    + "\n"
                ).encode()
            )
            down_since = None  # connected — reset the outage clock
            state = load_state()
            buf = b""
            while True:
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
                    if msg.get("event") != "pane_focused":
                        continue
                    data = msg.get("data", {})
                    ws, pane = data.get("workspace_id"), data.get("pane_id")
                    if not ws or not pane:
                        continue
                    entry = state.get(ws) or {"cur": None, "prev": None}
                    # Only shift prev on a genuine change; ignore repeat events.
                    if pane != entry.get("cur"):
                        entry["prev"] = entry.get("cur")
                        entry["cur"] = pane
                        state[ws] = entry
                        save_state(state)
        except Exception as e:
            now = time.time()
            if down_since is None:
                down_since = now
            elif now - down_since >= RECONNECT_GRACE_SECONDS:
                logline(f"herdr unreachable {RECONNECT_GRACE_SECONDS}s ({e}); exiting")
                cleanup()
            time.sleep(1.0)


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
    # Detached, its own session, so it outlives this key-press shell.
    subprocess.Popen(
        [sys.executable, os.path.abspath(__file__), "daemon"],
        stdin=subprocess.DEVNULL,
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
        start_new_session=True,
    )


# ---------------------------------------------------------------------------- toggle
def focused_pane_and_ws():
    resp = call({"id": "pl", "method": "pane.list", "params": {}})
    panes = (resp or {}).get("result", {}).get("panes", [])
    for p in panes:
        if p.get("focused"):
            return p.get("pane_id"), p.get("workspace_id"), panes
    return None, None, panes


def run_toggle():
    ensure_daemon()
    cur_pane, cur_ws, panes = focused_pane_and_ws()
    ws = os.environ.get("HERDR_WORKSPACE_ID") or cur_ws
    if not ws:
        return
    entry = load_state().get(ws)
    prev = entry and entry.get("prev")
    if not prev or prev == cur_pane:
        return  # no history yet (daemon just started), or already there — no-op
    # Only jump if prev still exists AND is genuinely in this workspace.
    if not any(p.get("pane_id") == prev and p.get("workspace_id") == ws for p in panes):
        return
    call({"id": "focus", "method": "pane.focus", "params": {"pane_id": prev}})


def main():
    cmd = sys.argv[1] if len(sys.argv) > 1 else "toggle"
    if cmd == "daemon":
        run_daemon()
    elif cmd == "toggle":
        run_toggle()
    elif cmd == "ensure":
        ensure_daemon()
    elif cmd == "stop":
        stop_daemon()
    else:
        sys.stderr.write(f"usage: {sys.argv[0]} [daemon|toggle|ensure|stop]\n")
        sys.exit(2)


if __name__ == "__main__":
    main()
