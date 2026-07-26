#!/usr/bin/env python3
"""herdr-balance-panes — re-even a herdr tab's splits whenever a pane is created or closed.

This is the herdr counterpart of ~/.config/tmux/lib/smart-split-layout.sh, which tmux runs
via `run-shell` on the split binds. herdr can't chain a script onto a keybinding at all —
split_vertical / split_horizontal are single built-in actions with no hook — so the same
behavior has to come off the socket instead: subscribe to pane.created / pane.closed and
rewrite the affected tab's ratios with layout.set_split_ratio.

Rules, kept in step with smart-split-layout.sh:
  * pure single axis only — a tab mixing right- and down-splits is left alone, so nested
    splits stay local to the pane they were made in
  * two panes side by side with nvim on the left -> 75/25; the editor wants the room
  * otherwise every leaf ends up the same size: each split's ratio is
    leaves(first) / leaves(node), which is what turns a right-leaning chain of splits into
    equal columns

herdr's layout is a binary TREE, not tmux's flat row, so "even" is this per-node weighting
rather than one even-horizontal call. layout.set_split_ratio addresses a node by a path of
booleans from the tab root (false = first child, true = second); [] is the root split.

We deliberately do NOT listen to layout.updated even though it covers more: it also fires
on every manual nudge, so a daemon watching it would fight `prefix+r` resize mode. Reacting
to create/close only mirrors tmux's post-split / post-kill rebalance and leaves hand-tuned
sizes alone. set_split_ratio itself only emits layout.updated, so there is no feedback loop.

pane.closed carries no tab_id, so pane -> tab is seeded from pane.list on connect and kept
current from the events themselves.

Runs wherever the herdr SERVER runs (Mac-local, or the VPS for --remote), started and
stopped by the socket's existence: a Linux systemd .path unit (PathExists) and macOS
launchd KeepAlive PathState, exactly like herdr-focus-tracker. The daemon EXITS when the
socket is gone rather than spinning; the supervisor restarts it when the socket returns.
Stdlib only — no herdr binary, no PATH.

`--once [tab_id]` balances a single tab and exits (defaults to the focused tab), so the
same rules are available on a keybinding.
"""
import json
import os
import socket
import sys
import time

SOCK = os.environ.get("HERDR_SOCKET_PATH") or os.path.expanduser("~/.config/herdr/herdr.sock")

SUBSCRIPTIONS = ["pane.created", "pane.closed", "pane.moved"]

EDITORS = {"nvim", "vim"}
MAIN_PANE_RATIO = 0.75
# herdr stores ratios as f32, so a round-tripped 0.5 comes back as 0.50000001-ish.
EPSILON = 1e-3


def request(method, params):
    """One-shot socket RPC on its own connection; the subscribe stream stays read-only."""
    conn = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
    conn.settimeout(3)
    try:
        conn.connect(SOCK)
        conn.sendall((json.dumps({"id": "balance-panes", "method": method, "params": params}) + "\n").encode())
        buf = b""
        while b"\n" not in buf:
            chunk = conn.recv(65536)
            if not chunk:
                return None
            buf += chunk
        reply = json.loads(buf.split(b"\n")[0])
        return reply.get("result")
    except (OSError, ConnectionError, ValueError):
        return None
    finally:
        conn.close()


def leaves(node):
    if node.get("type") != "split":
        return 1
    return leaves(node["first"]) + leaves(node["second"])


def directions(node, seen):
    """Every split direction in the subtree, so a mixed-axis tab can be skipped."""
    if node.get("type") != "split":
        return seen
    seen.add(node.get("direction"))
    directions(node["first"], seen)
    directions(node["second"], seen)
    return seen


def even_ratios(node, path, out):
    """(path, ratio) for every split, weighted by leaf count so all leaves come out equal."""
    if node.get("type") != "split":
        return out
    out.append((path, leaves(node["first"]) / leaves(node)))
    even_ratios(node["first"], path + [False], out)
    even_ratios(node["second"], path + [True], out)
    return out


def leftmost_pane(node):
    while node.get("type") == "split":
        node = node["first"]
    return node.get("pane_id")


def runs_editor(pane_id):
    """True when the pane's FOREGROUND process is nvim/vim.

    The process list is the whole tree under the shell (an agent drags its MCP servers
    along), so this matches on foreground_process_group_id — herdr's equivalent of tmux's
    #{pane_current_command} — instead of scanning every entry.
    """
    result = request("pane.process_info", {"pane_id": pane_id})
    if not result:
        return False
    info = result.get("process_info") or {}
    leader = info.get("foreground_process_group_id")
    for process in info.get("foreground_processes", []):
        if process.get("pid") != leader:
            continue
        name = (process.get("argv0") or process.get("name") or "").rsplit("/", 1)[-1]
        return name.removesuffix(".exe") in EDITORS
    return False


def plan(root):
    """Desired (path, ratio) list for a tab root, or [] when the tab is left alone."""
    if root.get("type") != "split":
        return []
    if len(directions(root, set())) > 1:
        return []
    # Single side-by-side pair with the editor on the left keeps a big main pane.
    if leaves(root) == 2 and root.get("direction") == "right" and runs_editor(leftmost_pane(root)):
        return [([], MAIN_PANE_RATIO)]
    return even_ratios(root, [], [])


def node_at(root, path):
    node = root
    for step in path:
        node = node["second" if step else "first"]
    return node


def balance(tab_id):
    result = request("layout.export", {"tab_id": tab_id})
    if not result:
        return
    root = (result.get("layout") or {}).get("root") or {}
    for path, ratio in plan(root):
        # Skip no-ops so an already-even tab costs one export and no writes.
        if abs((node_at(root, path).get("ratio") or 0.0) - ratio) < EPSILON:
            continue
        request("layout.set_split_ratio", {"tab_id": tab_id, "path": path, "ratio": ratio})


class Tabs:
    """pane -> tab, because pane.closed reports only the pane id and workspace."""

    def __init__(self):
        self.of_pane = {}

    def reload(self):
        result = request("pane.list", {})
        if not result:
            return
        self.of_pane = {p["pane_id"]: p.get("tab_id") for p in result.get("panes", []) if p.get("pane_id")}

    def created(self, pane):
        pane_id, tab_id = pane.get("pane_id"), pane.get("tab_id")
        if pane_id:
            self.of_pane[pane_id] = tab_id
        return [tab_id]

    def closed(self, pane_id):
        return [self.of_pane.pop(pane_id, None)]

    def moved(self, pane_id):
        # A move restructures both the source and the destination tab.
        before = self.of_pane.get(pane_id)
        self.reload()
        return [before, self.of_pane.get(pane_id)]


def handle(tabs, msg):
    event = msg.get("event")
    data = msg.get("data") or {}
    if event == "pane_created":
        return tabs.created(data.get("pane") or {})
    if event == "pane_closed":
        return tabs.closed(data.get("closed_pane_id") or data.get("pane_id"))
    if event == "pane_moved":
        return tabs.moved(data.get("pane_id"))
    return []


def session(tabs):
    conn = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
    conn.connect(SOCK)
    req = {
        "id": "balance-panes",
        "method": "events.subscribe",
        "params": {"subscriptions": [{"type": t} for t in SUBSCRIPTIONS]},
    }
    conn.sendall((json.dumps(req) + "\n").encode())
    tabs.reload()
    with conn.makefile("rb") as stream:
        for raw in stream:
            raw = raw.strip()
            if not raw:
                continue
            try:
                msg = json.loads(raw)
            except ValueError:
                continue
            for tab_id in dict.fromkeys(t for t in handle(tabs, msg) if t):
                balance(tab_id)


def once(tab_id):
    if not tab_id:
        result = request("pane.current", {})
        tab_id = ((result or {}).get("pane") or {}).get("tab_id")
    if tab_id:
        balance(tab_id)


def main():
    if "--once" in sys.argv:
        rest = [a for a in sys.argv[sys.argv.index("--once") + 1:] if not a.startswith("-")]
        once(rest[0] if rest else None)
        return
    tabs = Tabs()
    while True:
        try:
            session(tabs)
        except (OSError, ConnectionError):
            pass
        # The session ended (EOF or error). If the socket is gone, herdr is down — exit
        # cleanly so the supervisor restarts us when the socket returns, instead of
        # spinning against a dead server.
        if not os.path.exists(SOCK):
            return
        time.sleep(1)  # socket still there — a transient drop; reconnect shortly


if __name__ == "__main__":
    main()
