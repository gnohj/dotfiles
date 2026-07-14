#!/usr/bin/env python3
"""herdr-review-sweep — auto-release treehouse PR-review worktree slots under herdr.

The tmux setup returns a leased review worktree the moment its PR has no windows
left, via a `window-unlinked` hook that runs `review-worktree.sh sweep`
(agentic.conf). herdr has no such hook, but it emits close events over the raw
socket API (events.subscribe tab.closed / workspace.closed). This daemon is the
herdr counterpart: it subscribes to those events and runs `review-worktree.sh
sweep` whenever a tab/workspace closes, so closing a PR's review tabs returns its
pool slot with no `R` press — full parity with tmux.

Design mirrors herdr-pane-tracker.py:
  * `daemon` subscribes to tab.closed + workspace.closed. On any close it kicks a
    DEBOUNCED, backgrounded `review-worktree.sh sweep` (sweep itself re-checks all
    leases against open tabs, so it's edge-triggered but level-correct). Single
    instance via an flock'd pidfile; auto-reconnects across a herdr reload and
    exits after a short grace window when herdr is truly gone (no orphan).
  * `ensure` lazy-starts the daemon — called by `review-worktree.sh acquire` so
    the daemon runs exactly while review leases exist, no launchd needed.
  * `stop` terminates it.
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
PID_FILE = os.path.join(STATE_DIR, "review-sweep.pid")
LOG_FILE = os.path.join(STATE_DIR, "review-sweep.log")
SWEEP_SH = os.path.expanduser("~/.config/gh-dash/review-worktree.sh")
LEASE_DIR = os.path.join(
    os.environ.get("XDG_STATE_HOME", os.path.expanduser("~/.local/state")),
    "gh-review-worktrees",
)

RECONNECT_GRACE_SECONDS = 20
# Trailing-edge debounce: after a close event, wait for the burst to settle, then
# sweep ONCE. Closing several review tabs in quick succession must END in a sweep
# that sees the FINAL (empty) pane set — a leading-edge debounce sweeps on the
# FIRST close (panes still present → keeps the lease) and skips the last, leaking
# the slot. That is the exact bug this replaces.
SETTLE_SECONDS = 0.6
# Periodic backstop: even if a close event is ever missed (daemon restart, herdr
# reload blip), re-check leases this often so a leak self-heals within a minute.
PERIODIC_SWEEP_SECONDS = 60


def sock_path():
    return os.environ.get(
        "HERDR_SOCKET_PATH", os.path.expanduser("~/.config/herdr/herdr.sock")
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

    def leases_exist():
        try:
            return bool(os.listdir(LEASE_DIR))
        except OSError:
            return False

    def kick_sweep():
        # Backgrounded so the event loop keeps reading; sweep re-checks occupancy
        # from scratch (worktree cwd of every open pane), so it is level-correct.
        subprocess.Popen(
            ["bash", SWEEP_SH, "sweep"],
            stdin=subprocess.DEVNULL,
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
            start_new_session=True,
        )

    logline("daemon started")
    down_since = None
    last_periodic = time.time()
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
                                    {"type": "tab.closed"},
                                    {"type": "workspace.closed"},
                                ]
                            },
                        }
                    )
                    + "\n"
                ).encode()
            )
            down_since = None
            buf = b""
            pending = None  # trailing-edge timer: sweep once the burst settles
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
                        if msg.get("event") in ("tab_closed", "workspace_closed"):
                            pending = time.time() + SETTLE_SECONDS  # (re)arm
                except socket.timeout:
                    pass  # idle tick — fall through to the timers below
                now = time.time()
                if pending is not None and now >= pending:
                    pending = None
                    kick_sweep()
                elif now - last_periodic >= PERIODIC_SWEEP_SECONDS:
                    last_periodic = now
                    if leases_exist():
                        kick_sweep()
        except Exception as e:
            now = time.time()
            if down_since is None:
                down_since = now
            elif now - down_since >= RECONNECT_GRACE_SECONDS:
                logline(f"herdr unreachable {RECONNECT_GRACE_SECONDS}s ({e}); exiting")
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
    elif cmd == "stop":
        stop_daemon()
    else:
        sys.stderr.write(f"usage: {sys.argv[0]} [daemon|ensure|stop]\n")
        sys.exit(2)


if __name__ == "__main__":
    main()
