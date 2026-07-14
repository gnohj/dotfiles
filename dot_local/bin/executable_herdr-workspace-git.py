#!/usr/bin/env python3
"""herdr-workspace-git — append gitmux-style git symbols to each workspace's sidebar label.

herdr 0.7.3 has no plugin/render hook and no sidebar-format config: the workspace item is a
fixed layout whose only writable text field is the label (`workspace.rename`). herdr's own
API doesn't even expose git status (WorkspaceWorktreeInfo carries repo identity/paths only),
so the built-in badge can't be reformatted or extended. This daemon works within that by
recomputing git state itself and folding it into the label — so the sidebar shows branch +
gitmux symbols on the workspace's (only) line.

Symbols come from the SAME gitmux config as the tmux status line (~/.config/gitmux/gitmux.yml),
so the two stay visually identical. gitmux emits tmux `#[fg=...]` color codes; herdr labels are
plain text, so those are stripped and whitespace collapsed.

WHY poll (not events): git state changes on disk without any herdr event to subscribe to, so a
label driven by git MUST poll. ~2.5s is responsive enough for a sidebar and cheap (one gitmux
per workspace, each with a hard timeout so a huge repo can't stall the loop).

Base-label recovery: rename replaces the whole label, so to avoid accumulating segments
("web  main ●1  main ●1 …") we must recover the user's base name each pass. State file maps
workspace_id -> {base, rendered}: if the live label equals what we last wrote, the base is
intact; otherwise the user/herdr changed it and we adopt the live label as the new base
(stripping a trailing segment at the SEP marker as a belt-and-suspenders guard if state was lost).

On exit (herdr gone, or `stop`) it restores every label to its bare base, so a dead daemon
never leaves frozen stale git symbols in the sidebar.

Mirrors herdr-activity-tracker.py: raw $HERDR_SOCKET_PATH socket, single-instance flock, poll
loop with a reconnect grace window, lazy-start via `ensure` from the shell rc.
"""
import json
import os
import re
import socket
import subprocess
import sys
import time

# Minimal launchd/skhd PATH won't resolve gitmux (brew) or git (nix) — set one that does.
os.environ["PATH"] = (
    "/run/current-system/sw/bin:/opt/homebrew/bin:/usr/bin:/bin:" + os.environ.get("PATH", "")
)

STATE_DIR = os.path.join(
    os.environ.get("XDG_STATE_HOME", os.path.expanduser("~/.local/state")), "herdr"
)
STATE_FILE = os.path.join(STATE_DIR, "workspace-git-state.json")
PID_FILE = os.path.join(STATE_DIR, "workspace-git.pid")
LOG_FILE = os.path.join(STATE_DIR, "workspace-git.log")

GITMUX_CFG = os.path.expanduser("~/.config/gitmux/gitmux.yml")

POLL_INTERVAL = 2.5
RECONNECT_GRACE_SECONDS = 20
GITMUX_TIMEOUT = 1.5

# Divider between the base name and the git segment: a spaced middle dot. Reads as a clean
# separator in the sidebar and is a reliable split marker (the segment has whitespace collapsed
# to single spaces, and workspace base names effectively never contain " · "). herdr-sesh.sh
# strips this same divider when it reads the label, so keep the two in sync.
SEP = " · "
TMUX_STYLE = re.compile(r"#\[[^]]*\]")
NOISE_RE = re.compile("[" + chr(0xEA98) + chr(0x1F446) + chr(0x1F447) + r"]\s*\d*")  # stash + ahead/behind divergence -- not working-tree changes


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


# ------------------------------------------------------------------------- git rendering
def git_segment(cwd):
    """gitmux status symbols for `cwd` — tmux color codes stripped, whitespace collapsed, and
    the leading BRANCH token dropped (by request: symbols only, which also keeps the label
    short regardless of long worktree branch names). Empty string when cwd isn't a git repo
    (gitmux prints nothing), the repo is clean (only the branch prints, which we drop), or on
    timeout/error.

    Assumes the gitmux layout starts with `branch` (it does: [branch, divergence, stats, flags]
    in ~/.config/gitmux/gitmux.yml). The branch is a single whitespace-free token — glyph+name
    — so it's exactly the first space-delimited token; everything after it is the symbols."""
    if not cwd or not os.path.isdir(cwd):
        return ""
    try:
        out = subprocess.run(
            ["gitmux", "-cfg", GITMUX_CFG],
            cwd=cwd,
            capture_output=True,
            text=True,
            timeout=GITMUX_TIMEOUT,
        ).stdout
    except Exception:
        return ""
    seg = re.sub(r"\s+", " ", TMUX_STYLE.sub("", out)).strip()
    seg = seg.split(" ", 1)[1] if " " in seg else ""   # drop the leading branch token
    seg = NOISE_RE.sub("", seg)   # drop stash + ahead/behind divergence (not file changes)
    return re.sub(r"\s+", " ", seg).strip()


def base_of(ws_id, label, state):
    """Recover the user's base label (without our git segment) for this workspace."""
    entry = state.get(ws_id)
    if entry and entry.get("rendered") == label:
        return entry.get("base", label)
    # User/herdr changed the label (or we lost state). Adopt it as the new base, but strip a
    # trailing segment at SEP in case a prior render survived a state reset.
    return label.split(SEP, 1)[0].rstrip() if SEP in label else label


# ---------------------------------------------------------------------------- daemon core
def workspace_cwds():
    """Map workspace_id -> cwd. Prefer the focused pane's foreground cwd, else any pane's."""
    panes = (call({"id": "pl", "method": "pane.list", "params": {}}) or {}).get(
        "result", {}
    ).get("panes", [])
    focused, fallback = {}, {}
    for p in panes:
        ws = p.get("workspace_id")
        cwd = p.get("foreground_cwd") or p.get("cwd")
        if not ws or not cwd:
            continue
        fallback.setdefault(ws, cwd)
        if p.get("focused"):
            focused[ws] = cwd
    return {**fallback, **focused}


def poll_once(state, log=None):
    wss = (call({"id": "wl", "method": "workspace.list", "params": {}}) or {}).get(
        "result", {}
    ).get("workspaces", [])
    cwds = workspace_cwds()
    live_ids = set()
    for w in wss:
        ws_id = w.get("workspace_id")
        label = w.get("label", "")
        if not ws_id:
            continue
        live_ids.add(ws_id)
        base = base_of(ws_id, label, state)
        seg = git_segment(cwds.get(ws_id))
        target = f"{base}{SEP}{seg}" if seg else base
        if target != label:
            call(
                {
                    "id": "wr",
                    "method": "workspace.rename",
                    "params": {"workspace_id": ws_id, "label": target},
                }
            )
            if log:
                log(f"rename {ws_id}: {label!r} -> {target!r}")
        state[ws_id] = {"base": base, "rendered": target}
    for gone in [k for k in state if k not in live_ids]:  # forget closed workspaces
        del state[gone]
    save_state(state)


def restore_bases(state, log=None):
    """Rename every tracked workspace back to its bare base (best-effort; herdr may be gone)."""
    for ws_id, entry in list(state.items()):
        base = entry.get("base")
        if base and entry.get("rendered") != base:
            try:
                call(
                    {
                        "id": "wr",
                        "method": "workspace.rename",
                        "params": {"workspace_id": ws_id, "label": base},
                    }
                )
                if log:
                    log(f"restore {ws_id}: -> {base!r}")
            except Exception:
                pass


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
        logline("daemon exiting; restoring base labels + removing pidfile")
        try:
            restore_bases(load_state(), log=logline)
        except Exception:
            pass
        try:
            os.remove(PID_FILE)
        except OSError:
            pass
        os._exit(0)

    signal.signal(signal.SIGTERM, cleanup)
    signal.signal(signal.SIGINT, cleanup)

    logline("daemon started")
    state = load_state()
    down_since = None
    while True:
        try:
            poll_once(state, log=logline)
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
            os.kill(pid, 15)  # SIGTERM -> cleanup() restores labels + removes pidfile
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


def main():
    cmd = sys.argv[1] if len(sys.argv) > 1 else "ensure"
    if cmd == "daemon":
        run_daemon()
    elif cmd == "ensure":
        ensure_daemon()
    elif cmd == "once":  # single pass, for testing / manual refresh
        state = load_state()
        poll_once(state, log=lambda m: print(m))
    elif cmd == "stop":
        stop_daemon()
    else:
        sys.stderr.write(f"usage: {sys.argv[0]} [daemon|ensure|once|stop]\n")
        sys.exit(2)


if __name__ == "__main__":
    main()
