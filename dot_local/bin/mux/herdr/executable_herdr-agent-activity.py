#!/usr/bin/env python3
"""herdr-agent-activity — feed each agent pane's last-activity age to the sidebar $act token.

herdr's agent states are fully native — `agent_status` is a first-class enum
(idle/working/blocked/done/unknown), detected by the manifest rules in
~/.local/state/herdr/agent-detection/, rendered by the built-in `state_icon` /
`state_text` sidebar tokens, streamed as `pane_agent_status_changed`, and waited on by
`herdr agent wait --until`. None of that needs re-implementing; the sidebar rows in
dot_config/herdr/config.toml just have to ask for it.

What herdr has NO notion of is TIME. There is no timestamp on the snapshot and none on
any event (verified against the full `herdr api schema` — the only ordering signal is
`state_change_seq`, a monotonic counter). So "idle · 12m ago" has to be computed here and
pushed back in, which `pane.report_metadata` allows: a $act custom token per pane.

The age is the last `timestamp` entry in the agent's session JSONL — NOT the file mtime,
which gets touched without new turns. herdr makes that cheap: the snapshot hands over
`agent_session.value` (the session id) directly, so no process-subtree walk is needed to
find which forked worker owns the session file.

claude, pi and opencode — every agent that records its own wall-clock time, which is the
bar for appearing here. pi stamps its transcript with the same ISO `timestamp` key claude
uses, so it shares the tail reader; opencode keeps no transcript at all and its age comes
from `session.time_updated` in its SQLite store (epoch ms). Any other agent gets the token
CLEARED rather than a guess: the only signal
left would be event-arrival time, which is blind on cold start and would show every agent
as brand new after a restart — see report_all.

Polls on a wall clock rather than riding the event stream, because the age has to advance
with no events at all: a pane sitting idle for 5m must tick 1m → 2m → … on its own. Every
push carries a TTL as a dead-man's switch, so a crashed poller leaves stale ages on screen
for seconds rather than forever.

Runs wherever the herdr SERVER runs (Mac-local, or the VPS for --remote), started/stopped
by the socket's existence: a Linux systemd .path unit (PathExists) and macOS launchd
KeepAlive PathState both run it only while ~/.config/herdr/herdr.sock exists. To make that
work the daemon EXITS when the socket is gone (herdr down), rather than spinning; the
supervisor restarts it when the socket returns. Stdlib only — no herdr binary, no PATH,
no jq — so systemd's minimal env and a bare VPS python3 are enough.


  herdr-agent-activity.py           daemon: refresh every $HERDR_ACTIVITY_INTERVAL seconds
  herdr-agent-activity.py --once    one pass over every agent, then exit (smoke test)
"""
import calendar
import json
import os
import socket
import sys
import time

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
try:
    import herdr_agent_stores as stores
except ImportError:  # sibling absent: every on-disk age degrades; a path-kind session still works
    stores = None

SOCK = os.environ.get("HERDR_SOCKET_PATH") or os.path.expanduser("~/.config/herdr/herdr.sock")
INTERVAL = int(os.environ.get("HERDR_ACTIVITY_INTERVAL", "20"))
TTL_MS = (INTERVAL + 30) * 1000  # outlive a couple of missed passes
from herdr_label import row_indent

SOURCE = "agent-activity"
# Agent rows indent under the workspace TEXT; only a CUSTOM token can hold the pad (herdr owns state_text and agent), which is why the row leads with $act.
_WS_LABELS = {}

def _load_ws_labels(fetch):
    """Fill the per-pass label cache. One workspace.list call, feeding the agent-row pad."""
    if not _WS_LABELS:
        reply = fetch("workspace.list", {})
        for ws in ((reply or {}).get("result") or reply or {}).get("workspaces", []) or []:
            _WS_LABELS[ws.get("workspace_id")] = ws.get("label") or ""


def ws_indent(workspace_id, fetch):
    """Blank cells for a pane's rows, from its workspace label. Cached per pass - one extra call."""
    _load_ws_labels(fetch)
    return row_indent(_WS_LABELS.get(workspace_id, ""))

TOKEN = "act"

# Raw epochs for herdr-last-active-agent.sh (prefix+'). The sidebar token is a FORMATTED
# string ("8m ago") and so can't be sorted; the recency jump needs the numbers. Written
# server-side by this daemon and read server-side by that script, so the pair stays
# --remote-safe the same way the $git poller is.
STATE_DIR = os.path.join(
    os.environ.get("XDG_STATE_HOME") or os.path.expanduser("~/.local/state"), "herdr"
)
ACTIVITY_STATE = os.path.join(STATE_DIR, "agent-activity.json")

TAIL_BYTES = 65536


def rpc(method, params):
    """One-shot socket RPC on its own connection. Returns None on any failure — every
    caller treats a miss as "skip this pass", so a herdr restart mid-tick is harmless."""
    conn = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
    conn.settimeout(3)
    try:
        conn.connect(SOCK)
        conn.sendall((json.dumps({"id": SOURCE, "method": method, "params": params}) + "\n").encode())
        buf = b""
        while b"\n" not in buf:
            chunk = conn.recv(65536)
            if not chunk:
                return None
            buf += chunk
        return json.loads(buf.split(b"\n")[0])
    except (OSError, ConnectionError, ValueError):
        return None
    finally:
        conn.close()


def last_timestamp(path):
    """Epoch seconds of the newest `timestamp` in the transcript's tail. Reads a fixed
    window off the end, so the first line is usually a fragment — unparseable lines are
    skipped, which is also what drops the tool-result blobs that carry no timestamp."""
    try:
        size = os.path.getsize(path)
        with open(path, "rb") as f:
            if size > TAIL_BYTES:
                f.seek(size - TAIL_BYTES)
            tail = f.read()
    except OSError:
        return None
    for raw in reversed(tail.splitlines()):
        if not raw.strip():
            continue
        try:
            stamp = json.loads(raw).get("timestamp")
        except ValueError:
            continue
        if not stamp:
            continue
        try:
            parsed = time.strptime(stamp[:19], "%Y-%m-%dT%H:%M:%S")
        except ValueError:
            continue
        return calendar.timegm(parsed)  # transcripts stamp UTC (trailing Z); timegm, not mktime — DST
    return None


def opencode_activity(session, cwd):
    """Last-activity epoch for an opencode session, from `session.time_updated` (epoch ms).

    opencode keeps no transcript file to tail - its store is SQLite - so this is the one
    agent whose age is a query rather than a JSONL tail.
    """
    if not stores:
        return None
    updated = stores.opencode_by_session_or_cwd("time_updated", session, cwd)
    return int(updated) // 1000 if updated is not None else None


def format_age(then_epoch, now):
    """Compact age. Past a day it becomes a date, which doubles as the stale marker."""
    secs = max(0, int(now - then_epoch))
    if secs < 60:
        return "< 1m"
    if secs < 3600:
        return f"{secs // 60}m ago"
    if secs < 86400:
        return f"{secs // 3600}h ago"
    return time.strftime("%b %d", time.localtime(then_epoch))


def write_state(epochs):
    """Atomic pane_id -> epoch dump, so a reader can never catch a half-written file."""
    try:
        os.makedirs(STATE_DIR, exist_ok=True)
        tmp = f"{ACTIVITY_STATE}.tmp"
        with open(tmp, "w") as f:
            json.dump({"panes": epochs}, f)
        os.replace(tmp, ACTIVITY_STATE)
    except OSError:
        pass


def report_all():
    reply = rpc("session.snapshot", {})
    if not reply or "result" not in reply:
        return
    now = time.time()
    seq = time.time_ns()  # ns: monotonic, and above any manual probe seq
    epochs = {}
    _WS_LABELS.clear()  # labels can change between passes; the pad follows the glyph
    for agent in reply["result"].get("snapshot", {}).get("agents", []):
        pane_id = agent.get("pane_id")
        if not pane_id:
            continue
        value = None
        session = agent.get("agent_session") or {}
        cwd = (agent.get("cwd") or "").rstrip("/")
        kind = agent.get("agent")
        # An agent with no timestamped store falls through to a clear, so switching a pane
        # from claude to one of those drops the stale age rather than freezing it.
        path, stamp = None, None
        if kind == "claude":
            if session.get("kind") == "path":
                path = session.get("value")
            elif session.get("kind") == "id" and stores:
                path = stores.claude_transcript(session.get("value"), cwd)
        elif kind == "pi":
            # pi stamps every transcript entry with the same ISO `timestamp` key claude uses,
            # so the tail reader applies unchanged; only finding the file differs.
            path = session.get("value") if session.get("kind") == "path" else None
            if not path and cwd:
                path = stores.pi_newest_session(cwd) if stores else None
        elif kind in ("opencode", "open_code"):
            stamp = opencode_activity(session, cwd)
        if path and os.path.exists(path):
            stamp = last_timestamp(path)
        if stamp:
            value = format_age(stamp, now)
            epochs[pane_id] = stamp
        tokens = {TOKEN: (ws_indent(agent.get("workspace_id"), rpc) + value) if value else value}  # null clears — herdr has no clear_tokens field
        rpc("pane.report_metadata", {
            "pane_id": pane_id,
            "source": SOURCE,
            "seq": seq,
            "ttl_ms": TTL_MS,
            "tokens": tokens,
        })
    write_state(epochs)


def main():
    # --once: one pass, then exit — the smoke test for a fresh box (and the same flag the
    # sibling herdr daemons carry), since the loop below never returns on its own.
    if "--once" in sys.argv:
        report_all()
        return
    while True:
        # Exit when the socket is gone (herdr down) so the supervisor restarts us when it
        # returns, instead of polling a dead socket.
        if not os.path.exists(SOCK):
            return
        report_all()
        time.sleep(INTERVAL)


if __name__ == "__main__":
    main()
