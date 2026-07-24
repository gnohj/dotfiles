#!/usr/bin/env python3
"""herdr-focus-tracker — event-driven MRU tracker for herdr panes, tabs + workspaces.

herdr has native last_pane but it's GLOBAL (leaks across workspaces/tabs), and it has
NO last_tab / last_workspace, and its snapshot carries no focus history (feature req
ogulcancelik/herdr#1327 closed not-planned). BUT its socket API streams focus events
(events.subscribe), which `herdr api` doesn't expose. This daemon subscribes to
workspace/tab/pane .focused (+ .closed) and maintains true, correctly-SCOPED MRU that
the press-based hacks and native last_pane can't: previous-workspace, previous-tab per
workspace, and previous-pane per tab. It writes three state files the ctrl+b /
ctrl+space / ctrl+enter wrappers read:

  ~/.local/state/hack-herdr-last-workspace  -> workspace to jump back to
  ~/.local/state/hack-herdr-last-tab        -> previous tab IN the current workspace
  ~/.local/state/hack-herdr-last-pane       -> previous pane IN the current tab

pane.focused carries no tab_id, so a focused pane is attributed to the current tab
(herdr emits tab.focused before pane.focused on a tab switch; within-tab pane switches
keep the tab) — that's what keeps ctrl+b isolated to the current tab.

Runs wherever the herdr SERVER runs (Mac-local, or the VPS for --remote), started/stopped
by the socket's existence: a Linux systemd .path unit (PathExists) and macOS launchd
KeepAlive PathState both run it only while ~/.config/herdr/herdr.sock exists. To make
that work the daemon EXITS when the socket is gone (herdr down), rather than spinning;
the supervisor restarts it when the socket returns. Stdlib only — no herdr binary, no PATH.
"""
import json
import os
import socket
import time

SOCK = os.environ.get("HERDR_SOCKET_PATH") or os.path.expanduser("~/.config/herdr/herdr.sock")
STATE_DIR = os.environ.get("XDG_STATE_HOME") or os.path.expanduser("~/.local/state")
LAST_WS = os.path.join(STATE_DIR, "hack-herdr-last-workspace")
LAST_TAB = os.path.join(STATE_DIR, "hack-herdr-last-tab")
LAST_PANE = os.path.join(STATE_DIR, "hack-herdr-last-pane")

SUBSCRIPTIONS = [
    "workspace.focused", "tab.focused", "pane.focused",
    "workspace.closed", "tab.closed", "pane.closed",
]


def write_atomic(path, value):
    tmp = f"{path}.tmp"
    with open(tmp, "w") as f:
        f.write(value or "")
    os.replace(tmp, path)


class MRU:
    def __init__(self):
        self.cur_ws = None
        self.prev_ws = None
        self.cur_tab = None
        self.tab_cur = {}    # ws  -> current tab
        self.tab_prev = {}   # ws  -> previous tab in that ws
        self.pane_cur = {}   # tab -> current pane
        self.pane_prev = {}  # tab -> previous pane in that tab

    def focus_ws(self, ws):
        if not ws or ws == self.cur_ws:
            return
        if self.cur_ws is not None:
            self.prev_ws = self.cur_ws
        self.cur_ws = ws

    def focus_tab(self, ws, tab):
        if not tab:
            return
        self.cur_tab = tab
        if not ws or self.tab_cur.get(ws) == tab:
            return
        if ws in self.tab_cur:
            self.tab_prev[ws] = self.tab_cur[ws]
        self.tab_cur[ws] = tab

    def focus_pane(self, pane):
        tab = self.cur_tab
        if not tab or not pane or self.pane_cur.get(tab) == pane:
            return
        if tab in self.pane_cur:
            self.pane_prev[tab] = self.pane_cur[tab]
        self.pane_cur[tab] = pane

    def close_ws(self, ws):
        self.tab_cur.pop(ws, None)
        self.tab_prev.pop(ws, None)
        if self.prev_ws == ws:
            self.prev_ws = None
        if self.cur_ws == ws:
            self.cur_ws = None

    def close_tab(self, tab):
        self.pane_cur.pop(tab, None)
        self.pane_prev.pop(tab, None)
        for ws in list(self.tab_cur):
            if self.tab_cur.get(ws) == tab:
                del self.tab_cur[ws]
        for ws in list(self.tab_prev):
            if self.tab_prev.get(ws) == tab:
                del self.tab_prev[ws]

    def close_pane(self, pane):
        for tab in list(self.pane_cur):
            if self.pane_cur.get(tab) == pane:
                del self.pane_cur[tab]
        for tab in list(self.pane_prev):
            if self.pane_prev.get(tab) == pane:
                del self.pane_prev[tab]

    def flush(self):
        write_atomic(LAST_WS, self.prev_ws or "")
        write_atomic(LAST_TAB, self.tab_prev.get(self.cur_ws, "") if self.cur_ws else "")
        write_atomic(LAST_PANE, self.pane_prev.get(self.cur_tab, "") if self.cur_tab else "")


def handle(mru, msg):
    event = msg.get("event")
    data = msg.get("data") or {}
    if event == "workspace_focused":
        mru.focus_ws(data.get("workspace_id"))
    elif event == "tab_focused":
        ws = data.get("workspace_id")
        mru.focus_ws(ws)
        mru.focus_tab(ws, data.get("tab_id"))
    elif event == "pane_focused":
        mru.focus_ws(data.get("workspace_id"))
        mru.focus_pane(data.get("pane_id"))
    elif event == "workspace_closed":
        mru.close_ws(data.get("closed_workspace_id") or data.get("workspace_id"))
    elif event == "tab_closed":
        mru.close_tab(data.get("closed_tab_id") or data.get("tab_id"))
    elif event == "pane_closed":
        mru.close_pane(data.get("closed_pane_id") or data.get("pane_id"))
    else:
        return False
    return True


def session(mru):
    conn = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
    conn.connect(SOCK)
    req = {
        "id": "focus-tracker",
        "method": "events.subscribe",
        "params": {"subscriptions": [{"type": t} for t in SUBSCRIPTIONS]},
    }
    conn.sendall((json.dumps(req) + "\n").encode())
    with conn.makefile("rb") as stream:
        for raw in stream:
            raw = raw.strip()
            if not raw:
                continue
            try:
                msg = json.loads(raw)
            except ValueError:
                continue
            if handle(mru, msg):
                mru.flush()


def main():
    os.makedirs(STATE_DIR, exist_ok=True)
    mru = MRU()
    while True:
        try:
            session(mru)
        except (OSError, ConnectionError):
            pass
        # The session ended (EOF or error). If the socket is gone, herdr is down —
        # exit cleanly so the supervisor (systemd .path / launchd PathState) restarts
        # us when the socket returns, instead of spinning against a dead server.
        if not os.path.exists(SOCK):
            return
        time.sleep(1)  # socket still there — a transient drop; reconnect shortly


if __name__ == "__main__":
    main()
