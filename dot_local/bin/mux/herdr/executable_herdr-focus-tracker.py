#!/usr/bin/env python3
"""herdr-focus-tracker — event-driven MRU tracker for herdr panes, tabs + workspaces.

herdr has native last_pane but it's GLOBAL (leaks across workspaces/tabs), and it has
NO last_tab / last_workspace, and its snapshot carries no focus history (feature req
herdrdev/herdr#1327 closed not-planned). BUT its socket API streams focus events
(events.subscribe), which `herdr api` doesn't expose. This daemon subscribes to
workspace/tab/pane .focused (+ .closed) and maintains true, correctly-SCOPED MRU that
the press-based hacks and native last_pane can't: previous-workspace, previous-tab per
workspace, and previous-pane per tab. It writes three state files the ctrl+b /
ctrl+space / ctrl+enter wrappers read:

  ~/.local/state/hack-herdr-last-workspace  -> workspace to jump back to
  ~/.local/state/hack-herdr-last-tab        -> previous tab IN the current workspace
  ~/.local/state/hack-herdr-last-pane       -> previous pane IN the current tab

It also keeps tab labels numbered by POSITION - see renumber_tabs below.

pane.focused carries no tab_id, so a focused pane is attributed to the current tab
(herdr emits tab.focused before pane.focused on a tab switch; within-tab pane switches
keep the tab) — that's what keeps ctrl+b isolated to the current tab.

Runs wherever the herdr SERVER runs (Mac-local, or the VPS for --remote), started/stopped
by the socket's existence: a Linux systemd .path unit (PathExists) and macOS launchd
KeepAlive PathState both run it only while ~/.config/herdr/herdr.sock exists. To make
that work the daemon EXITS when the socket is gone (herdr down), rather than spinning;
the supervisor restarts it when the socket returns. Stdlib only — no herdr binary, no PATH.
"""
import collections
import json
import os
import re
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
    "tab.created", "tab.moved", "tab.renamed",
]

NUMBERED_LABEL = re.compile(r"^(\d+)\.(.*)$", re.DOTALL)
AUTO_LABEL = re.compile(r"^\d+$")
DEFAULT_TAB_TEXT = "\U0001f41f"

# Firstmate owns its own tab and workspace labels and matches them by EXACT string,
# so renumbering them breaks it silently. Two real failures on 2026-08-09:
# its seeded-tab prune only fires when the label is still bare "1", and its task
# recovery selects tabs with label.startswith("fm-"). Renaming "1" to "1.<fish>" and
# "fm-web" to "1.fm-web" defeats both - spawns fail to converge and orphan discovery
# goes blind. So this pass leaves firstmate's tabs exactly as firstmate wrote them.
FIRSTMATE_TAB = re.compile(r"^fm-")
# Workspaces firstmate owns: its primary home, a secondmate home, and the disposable
# per-task projection ("└ <task> · p:<token>"). Inside these, an unlabeled tab is a
# seeded default firstmate is about to prune by exact label, so it must stay bare.
FIRSTMATE_WORKSPACE = re.compile(r"^(firstmate$|2ndmate-|└ )")

# Labels this daemon wrote and has not yet seen echoed back - see is_self_echo.
SELF_WRITES = collections.defaultdict(lambda: collections.deque(maxlen=8))

# Both kept in step with herdr-git-status.sh, the other writer of these two tokens - see
# paint_branch. TTL outlives a couple of that poller's missed passes, same as its own.
BRANCH_SOURCE = "gitmux"
BRANCH_TTL_MS = 38000

# herdr-pane-summary.py's source, shared for the same reason as BRANCH_SOURCE - see paint_panes.
SUMMARY_SOURCE = "auto-summary"

# Events that can move which pane is focused, and so need the accent re-slotted.
PANE_PAINT_EVENTS = {"workspace_focused", "tab_focused", "pane_focused", "pane_closed"}


def request(method, params):
    """One-shot socket RPC on its own connection; the subscribe stream stays read-only."""
    conn = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
    conn.settimeout(3)
    try:
        conn.connect(SOCK)
        conn.sendall((json.dumps({"id": "focus-tracker", "method": method, "params": params}) + "\n").encode())
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


def label_text(label, position):
    """Text of an EXISTING label: `<n>.rest` -> rest, anything else -> itself.

    A bare number counts as text UNLESS it equals the position the tab is getting - then
    it is herdr's own auto number and carries no meaning, so the tab falls back to the
    fish. "1000" at position 9 is a label the user typed; "9" at position 9 is not.
    """
    match = NUMBERED_LABEL.match(label)
    if match:
        return match.group(2).strip()
    label = label.strip()
    if AUTO_LABEL.match(label) and label == str(position):
        return ""
    return label


def typed_text(label):
    """Text of a label the user JUST TYPED, where bare digits are real text: "100" -> 100,
    "3.hi" -> hi (our own prefix, or their guess at one), "3." -> nothing -> fish."""
    match = NUMBERED_LABEL.match(label)
    return match.group(2).strip() if match else label.strip()


def is_self_echo(tab_id, label):
    """True, consuming the record, when this tab.renamed is one of OUR writes coming back.

    herdr emits tab.renamed for API renames too, so our own writes return looking exactly
    like a user rename, costing a pointless reconcile each. Dropping them also keeps this
    daemon from amplifying a herdr bug seen on 0.7.5: the server can get stuck emitting a
    phantom tab.renamed stream (~10/s, alternating two stale labels) for a tab whose stored
    label never changes. Reacting to those as input turns the phantom events into REAL
    renames and the tab visibly flickers - see the AUTO_LABEL guard in handle for the rest.
    """
    pending = SELF_WRITES.get(tab_id)
    if pending and label in pending:
        pending.remove(label)
        return True
    return False


def restore_firstmate_label(label):
    """The bare `fm-...` label firstmate wrote, or None when this is not its tab.

    Matches both the untouched form and one an earlier numbering pass already
    prefixed, so a tab renamed to "1.fm-web" is handed back as "fm-web".
    """
    match = NUMBERED_LABEL.match(label)
    text = match.group(2).strip() if match else label.strip()
    return text if FIRSTMATE_TAB.match(text) else None


def firstmate_workspace_ids():
    """Workspace ids firstmate owns, by label. Empty when the list cannot be read,
    which degrades to the previous behaviour rather than skipping everything."""
    reply = request("workspace.list", {})
    if not reply or "result" not in reply:
        return set()
    return {
        ws.get("workspace_id")
        for ws in reply["result"].get("workspaces", [])
        if FIRSTMATE_WORKSPACE.match((ws.get("label") or "").strip())
    }


def renumber_tabs(typed=None):
    """Give every named tab a `<position>.` prefix, and keep that number honest.

    prefix+1..9 is positional, and herdr auto-numbers only tabs with NO custom label -
    a label replaces the number outright (src/ui/tabs.rs tab_chrome_label). So a tab
    renamed to "notes" loses its number, and "3.🔨" keeps reading 3 after an earlier tab
    closes even though prefix+2 is what focuses it. Both are fixed here: rename to a bare
    word and the prefix is added, close a tab and the rest renumber. Everything after the
    dot is preserved.

    Every tab ends up as `<position>.<text>`, with a fish standing in when there is no
    text. That makes an unnamed tab a NAMED one, which stops herdr's own auto-numbering;
    fine, because this pass owns the number from then on and reconciles on connect as
    well as on events.

    `typed` carries what the user just entered at a rename prompt, keyed by tab id, where
    digits are always text: renaming to "100" at position 3 gives "3.100". Without that
    context a bare number is read by label_text, which only discards it when it matches
    the position (herdr's own auto number).
    """
    typed = typed or {}
    reply = request("tab.list", {})
    if not reply or "result" not in reply:
        return
    firstmate_spaces = firstmate_workspace_ids()
    by_workspace = {}
    for tab in reply["result"].get("tabs", []):
        by_workspace.setdefault(tab.get("workspace_id"), []).append(tab)
    for workspace_id, tabs in by_workspace.items():
        # Firstmate matches its own tab labels exactly, so numbering anything inside
        # its workspaces breaks its prune and its recovery. Leave the whole space alone.
        if workspace_id in firstmate_spaces:
            continue
        for position, tab in enumerate(tabs, start=1):
            label = tab.get("label") or ""
            # A firstmate task tab can also sit in an ordinary workspace. Leave it bare,
            # and undo a prefix an earlier pass added before this rule existed.
            bare = restore_firstmate_label(label)
            if bare is not None:
                if bare != label:
                    SELF_WRITES[tab["tab_id"]].append(bare)
                    request("tab.rename", {"tab_id": tab["tab_id"], "label": bare})
                continue
            text = typed.get(tab["tab_id"], label_text(label, position))
            desired = f"{position}.{text or DEFAULT_TAB_TEXT}"
            if desired != label:
                SELF_WRITES[tab["tab_id"]].append(desired)
                request("tab.rename", {"tab_id": tab["tab_id"], "label": desired})


def paint_branch():
    """Move the sidebar branch text between `$br` (dim) and `$br_on` (accent) by focus.

    herdr paints its BUILT-IN tokens differently on the active space and the rest - `branch`
    gets mauve when selected/active and overlay0 otherwise (src/ui/sidebar.rs::branch_style) -
    but a custom `$token` takes one flat inline `fg` and nothing else; fg_active/fg_inactive/
    fg_focused/dim_inactive/fg_dim are all TOML parse errors on 0.7.5 (skills/herdr-upgrade/
    watchlist.md item 2). Row 2 has to be custom, because the built-in can only render the
    branch verbatim and this sidebar wants the ticket key stripped off it. So the two-tone is
    rebuilt here: TWO tokens in that row, each a fixed color, exactly one ever holding the
    text. An empty token renders nothing at all - no stray " · " - so the row reads as one word.

    `source` MUST match the one herdr-git-status.sh reports with: a token can only be cleared
    by the source that set it, so a second source here would leave both halves lit at once.
    That poller writes the branch VALUE (and picks the same slot from `focused`, so its pass
    never undoes this); this pass only ever moves an existing value, which is why it needs no
    git and no herdr binary - `workspace.report_metadata` is a socket method like the rest.

    Reconciles every workspace rather than diffing the focus change: it is one `workspace.list`
    plus a write only where the slot is actually wrong (two, on a normal focus change), and it
    self-heals a workspace left mispainted while the daemon was down.
    """
    reply = request("workspace.list", {})
    if not reply or "result" not in reply:
        return
    for ws in reply["result"].get("workspaces", []):
        tokens = ws.get("tokens") or {}
        dim, lit = tokens.get("br") or "", tokens.get("br_on") or ""
        value = lit or dim
        if not value:
            continue
        want_lit = value if ws.get("focused") else ""
        want_dim = "" if ws.get("focused") else value
        if (dim, lit) == (want_dim, want_lit):
            continue
        request("workspace.report_metadata", {
            "seq": time.time_ns(),
            "source": BRANCH_SOURCE,
            "tokens": {"br": want_dim or None, "br_on": want_lit or None},
            "ttl_ms": BRANCH_TTL_MS,
            "workspace_id": ws["workspace_id"],
        })


def paint_panes():
    """Move each agent pane's summary between `$pn` (dim) and `$pn_on` (accent) by focus.

    paint_branch's problem and solution, one level down. The agents panel shows each pane's
    summary slug, and herdr gives that row no focus-varying color at all: the `text` theme
    token reaches only the ACTIVE entry's FIRST row (workspace + tab), never the summary line,
    and an inline `fg` on a custom token is unconditional. So the same two-slot trick applies -
    `$pn` holds the text in dim blue on every unfocused agent, `$pn_on` holds it in the accent
    on the focused one, and exactly one is ever non-empty.

    `source` MUST be herdr-pane-summary.py's: a token can only be cleared by the source that
    set it, so a second source here would light both slots at once. Writing `tokens` alone does
    NOT disturb the `title` that daemon set under the same source (verified live), which is why
    the pane border label survives this pass untouched.

    Reconciles every pane rather than diffing the focus change - one `pane.list` plus a write
    only where the slot is actually wrong (two, on a normal focus change) - and it self-heals a
    pane left mispainted while the daemon was down. Panes holding neither slot are skipped, so
    a pane that never earned a summary is never given one here.

    TWO pairs, two sources: `$pn` is herdr-pane-summary.py's, `$pbr` herdr-git-status.sh's. They
    cannot move in one call - a token is only clearable by the source that set it, so a single
    write would strand the other pair's dim half lit. `$pgit` carries a fixed color and needs none.
    """
    reply = request("pane.list", {})
    if not reply or "result" not in reply:
        return
    for pane in reply["result"].get("panes", []):
        tokens = pane.get("tokens") or {}
        focused = bool(pane.get("focused"))
        for source, dim_key, lit_key, ttl_ms in (
                (SUMMARY_SOURCE, "pn", "pn_on", None),
                (BRANCH_SOURCE, "pbr", "pbr_on", BRANCH_TTL_MS)):
            dim, lit = tokens.get(dim_key) or "", tokens.get(lit_key) or ""
            value = lit or dim
            if not value:
                continue
            want_lit = value if focused else ""
            want_dim = "" if focused else value
            if (dim, lit) == (want_dim, want_lit):
                continue
            payload = {
                "pane_id": pane["pane_id"],
                "seq": time.time_ns(),
                "source": source,
                "tokens": {dim_key: want_dim or None, lit_key: want_lit or None},
            }
            if ttl_ms:
                payload["ttl_ms"] = ttl_ms
            request("pane.report_metadata", payload)


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
    was_ws = mru.cur_ws
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
        renumber_tabs()
    elif event == "tab_renamed":
        # The event carries what the user typed, so "100" stays text instead of a number.
        tab_id, label = data.get("tab_id"), data.get("label") or ""
        if tab_id and is_self_echo(tab_id, label):
            return False
        # Only a BARE NUMBER needs the event's label; every other form reads off tab.list.
        text = typed_text(label)
        typed = {tab_id: text} if tab_id and AUTO_LABEL.match(text) else None
        renumber_tabs(typed)
        return False
    elif event in ("tab_created", "tab_moved"):
        renumber_tabs()
        return False
    elif event == "pane_closed":
        mru.close_pane(data.get("closed_pane_id") or data.get("pane_id"))
        # Closing a tab's last pane (prefix+x) takes the tab with it but emits ONLY
        # pane_closed - tab_closed fires just on the API path, so this is the one that
        # catches a tab closed from the UI.
        renumber_tabs()
    else:
        return False
    # Unlike the branch row, this one DOES track within-tab pane hops - that is the point of it.
    if event in PANE_PAINT_EVENTS:
        paint_panes()
    # Only when the ACTIVE space actually moved: within-tab pane hops fire constantly and
    # cannot change which space is lit. The two early `return False` paths above are all
    # tab-label events, which never move focus, so they need no repaint.
    if mru.cur_ws != was_ws:
        paint_branch()
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
    # Reconcile once per connect: events only cover drift from now on, so a tab closed
    # while the daemon was down (restart, `chezmoi apply`, herdr restart) stays wrong forever.
    renumber_tabs()
    # Same reason for the branch row: focus can move while this daemon is down, which leaves
    # the accent stuck on whichever space was lit at the time.
    paint_branch()
    paint_panes()
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
