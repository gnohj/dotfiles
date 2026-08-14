#!/usr/bin/env python3
"""herdr-pane-summary — label each agent pane with a slug of its AI session title.

Turns an un-renamed agent pane from an anonymous `claude` into
`implement-herdr-pane-rename`.

For claude and codex the OSC title is the fast path: herdr parses it and hands it over on the
pane object as `terminal_title_stripped` (spinner glyph and all, pre-stripped), so the daemon
is just title -> slug -> write, live to the cell.

claude's OSC title is only as good as its `ai-title`, though, and one is not guaranteed. A
session opened straight into a slash command never gets named at all, so its title stays the
literal `Claude Code` for the whole session and the pane would sit anonymous forever. That is
what `transcript_title` is for: when the OSC title is still a PLACEHOLDER, read the session's
own JSONL and take the last `{"type":"ai-title"}`, else the slash command the session opened
with (argument first: `/hunk-review 19426` -> `19426-hunk-review`), else its first user prompt.
It is a FALLBACK, not an override - the moment claude names itself the OSC title wins again, so
the pane converges on the real summary.

pi and opencode DO set an OSC title, but never a session one: pi shows `π - <cwd basename>`
and opencode prefixes its own with `OC | `, so slugging those gives a name that is either
the directory or a wasted segment. For them the session store is authoritative instead and
their OSC title is never consulted (`STORE_READERS` below), read from two sources - pi's
first user message and opencode's stored session title.

Where every one of those stores lives is owned by the sibling herdr_agent_stores module,
shared with herdr-agent-activity.py.

Write channel is `pane.report_metadata`, NOT `pane.rename`:
  * `pane.rename` sets `label`, herdr's deliberate-rename field. That is the user's, the
    field — a pane carrying a label is skipped entirely, so a hand-named pane is never
    clobbered.
  * `pane.report_metadata --source auto-summary --title <slug>` is the display-only channel
    and is scoped by `source`, so our record and any other reporter's stay independent.
Both render on the pane border.

The same write also fills a `$pn`/`$pn_on` custom token pair, which is what the AGENTS-panel
row renders (the built-in `pane` token cannot change color by focus). herdr-focus-tracker.py
::paint_panes moves the text between the two slots so the selected agent's name reads in the
accent color. `title` and `tokens` are independent per source - verified live: a tokens-only
report_metadata under `auto-summary` leaves the title standing - so paint_panes can re-slot
without carrying the title, and the border label is unaffected either way.

Event-driven: `pane.updated` carries the whole pane object (title, label, agent) and fires
when the pane's terminal changes — ~6 events in 18s across five busy agents. Our own write
emits one more `pane.updated`, which re-enters as a no-op because the slug is unchanged; that
is the loop terminator, so writes stay one-per-title-change.

`pane.updated` is driven by TERMINAL activity, though, so an idle pane emits nothing and a
change that isn't the terminal's doing is not delivered on its own — most visibly, renaming
an idle pane by hand fires no event, so our slug would sit there un-retracted until that
agent next did something. RECONCILE_SECS is the backstop: the event read carries that
timeout, and each expiry re-sweeps every pane. Cheap (one pane.list plus one pane.layout per
agent pane per tick) and it also re-fits labels after a resize, which likewise emits nothing.

The slug is capped at `WORDS` hyphen-segments and then truncated to the pane's real border
budget with an ellipsis, east-asian width aware so a CJK title reserves its true cells.

Runs wherever the herdr SERVER runs (Mac-local, or the VPS under --remote), started and
stopped by the socket's existence: a Linux systemd .path unit (PathExists) and macOS launchd
KeepAlive PathState, exactly like herdr-focus-tracker and herdr-balance-panes. The daemon
EXITS when the socket is gone rather than spinning. Stdlib only — no herdr binary, no PATH.

  herdr-pane-summary.py           daemon: label panes as their titles change
  herdr-pane-summary.py --once    one pass over every open pane, then exit
  herdr-pane-summary.py --clear   remove every label this source wrote, then exit
"""
import json
import os
import socket
import sys
import time
import unicodedata

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
try:
    import herdr_agent_stores as stores
except ImportError:  # sibling absent: on-disk titles degrade, an OSC-titled session still works
    stores = None

SOCK = os.environ.get("HERDR_SOCKET_PATH") or os.path.expanduser("~/.config/herdr/herdr.sock")

from herdr_label import row_indent

SOURCE = "auto-summary"
# Agent rows indent under the workspace TEXT; only a CUSTOM token can hold the pad (herdr owns state_text and agent), which is why the row leads with $act.
_WS_LABELS = {}
_TAB_POS = {}

def ws_indent(workspace_id, fetch):
    """Blank cells for a pane's rows, from its workspace label. Cached per pass - one extra call.

    A MISS refetches rather than falling back to "". SUBSCRIPTIONS carries no workspace event, so a
    workspace opened between sweeps is absent from a cache filled on an earlier pass, and the
    pane_created that follows it would otherwise pad the new workspace's rows with nothing - which
    is how a fresh agent row sat flush left while every older one lined up under its label.
    """
    if not _WS_LABELS or workspace_id not in _WS_LABELS:
        reply = fetch("workspace.list", {})
        for ws in ((reply or {}).get("result") or reply or {}).get("workspaces", []) or []:
            _WS_LABELS[ws.get("workspace_id")] = ws.get("label") or ""
        # Pin a genuinely unknown id so a pane whose workspace is gone cannot refetch on every event.
        _WS_LABELS.setdefault(workspace_id, "")
    return row_indent(_WS_LABELS.get(workspace_id, ""))


def tab_prefix(tab_id, fetch):
    """`<n>.` for the pane's tab, matching the number its LABEL carries; "" when unknown.

    Position within the workspace, never the tab's own `number` - that is a creation counter
    which climbs as tabs close, so a lone tab can report 15 and a tab labelled "2.state" can
    report 4. herdr-focus-tracker.py numbers labels off the same enumeration, so the two agree
    everywhere it numbers; inside a firstmate workspace it leaves labels bare on purpose, and
    the row still carries the position because that is what selects the tab.
    """
    if not _TAB_POS:
        reply = fetch("tab.list", {})
        by_workspace = {}
        for tab in ((reply or {}).get("result") or reply or {}).get("tabs", []) or []:
            by_workspace.setdefault(tab.get("workspace_id"), []).append(tab.get("tab_id"))
        for ids in by_workspace.values():
            for position, tid in enumerate(ids, start=1):
                _TAB_POS[tid] = position
    position = _TAB_POS.get(tab_id)
    return f"{position}." if position else ""

SUBSCRIPTIONS = ["pane.updated", "pane.created", "pane.closed",
                 "tab.created", "tab.closed", "tab.moved"]
# These renumber every tab after the one that moved, so a prefix shifts with no pane event of its own; tab.renamed is absent because the prefix reads tab ORDER, not the label.
TAB_ORDER_EVENTS = {"tab_created", "tab_closed", "tab_moved"}

WORDS = int(os.environ.get("HERDR_SUMMARY_WORDS", "4"))
RECONCILE_SECS = int(os.environ.get("HERDR_SUMMARY_RECONCILE", "45"))
# Border decoration around the label: two corners, the leading gap, and breathing room.
BORDER_RESERVE = 6
MIN_BUDGET = 12
FALLBACK_BUDGET = 36

# Connectives dropped only when a hard WORDS-cut leaves one dangling at the END, so we get
# `implement-herdr-pane` rather than `implement-herdr-pane-with`. Interior ones stay.
TRAILING_STOPWORDS = {"a", "an", "and", "at", "for", "in", "of", "on", "or", "the", "to", "with"}

# The agent's pre-summary placeholder title. Claude shows this until the session has enough
# context to name itself; naming a pane from it would label every fresh pane identically.
PLACEHOLDERS = {"claude code", "claude", "codex", "opencode", "pi"}

# On-disk title reads for the agents the OSC title fails (see lookup_title); 64 KB window.
HEAD_BYTES = 64 * 1024
TITLE_TTL = int(os.environ.get("HERDR_SUMMARY_TITLE_TTL", "30"))
# A miss expires sooner: it is usually a new session whose first prompt has yet to hit disk.
TITLE_MISS_TTL = int(os.environ.get("HERDR_SUMMARY_TITLE_MISS_TTL", "5"))
# opencode names a session `New session - <iso>` until its summarizer replaces it.
OPENCODE_PLACEHOLDER = "New session"
# claude wraps a slash-command turn in these: `<command-name>/tidy-commit</command-name>` -> `tidy-commit`.
CLAUDE_COMMAND_OPEN = "<command-name>"
CLAUDE_COMMAND_CLOSE = "</command-name>"
CLAUDE_ARGS_OPEN = "<command-args>"
CLAUDE_ARGS_CLOSE = "</command-args>"
_title_cache = {}


def request(method, params):
    """One-shot socket RPC on its own connection; the subscribe stream stays read-only."""
    conn = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
    conn.settimeout(3)
    try:
        conn.connect(SOCK)
        conn.sendall((json.dumps({"id": "pane-summary", "method": method, "params": params}) + "\n").encode())
        buf = b""
        while b"\n" not in buf:
            chunk = conn.recv(65536)
            if not chunk:
                return None
            buf += chunk
        return json.loads(buf.split(b"\n")[0]).get("result")
    except (OSError, ConnectionError, ValueError):
        return None
    finally:
        conn.close()


def dwidth(text):
    """Display cells, counting east-asian wide/fullwidth glyphs as two."""
    return sum(2 if unicodedata.east_asian_width(ch) in ("W", "F") else 1 for ch in text)


def truncate(text, budget):
    """Fit `budget` cells, reserving one for the ellipsis."""
    if dwidth(text) <= budget:
        return text
    out, used = "", 0
    for ch in text:
        w = dwidth(ch)
        if used + w > budget - 1:
            break
        out, used = out + ch, used + w
    return out + "…"


def slugify(title, words):
    """Lowercase hyphen-slug of the first `words` alphanumeric segments of `title`.

    Splitting on every non-alphanumeric char folds spaces, slashes and existing hyphens into
    clean segments, so `/sb-ticket-capture` survives as `sb-ticket-capture`.
    """
    segments = []
    current = ""
    for ch in title.lower():
        if ch.isalnum():
            current += ch
            continue
        if current:
            segments.append(current)
            current = ""
        if len(segments) >= words:
            break
    if current and len(segments) < words:
        segments.append(current)
    segments = segments[:words]
    while len(segments) > 1 and segments[-1] in TRAILING_STOPWORDS:
        segments.pop()
    return "-".join(segments)


def budget_for(pane_id):
    """The pane's border width budget, from its real rect; a sane default when unavailable."""
    result = request("pane.layout", {"pane_id": pane_id})
    for pane in ((result or {}).get("layout") or {}).get("panes", []):
        if pane.get("pane_id") == pane_id:
            width = (pane.get("rect") or {}).get("width") or 0
            return max(MIN_BUDGET, width - BORDER_RESERVE)
    return FALLBACK_BUDGET


def edge_windows(path):
    """The file's first and last HEAD_BYTES, decoded - one read when it fits in one window.

    Both ends are needed because the transcript answers two different questions from two
    different places: the newest `ai-title` is at the end, the opening prompt at the start.
    """
    try:
        with open(path, "rb") as handle:
            head = handle.read(HEAD_BYTES)
            size = os.fstat(handle.fileno()).st_size
            if size <= HEAD_BYTES:
                tail = head
            else:
                handle.seek(max(HEAD_BYTES, size - HEAD_BYTES))
                tail = handle.read()
    except OSError:
        return "", ""
    return head.decode("utf-8", "replace"), tail.decode("utf-8", "replace")


def prompt_text(entry):
    """A transcript entry's user-typed text, or "" for anything that is not a real prompt.

    `isMeta` covers the body a slash command expands into and `isSidechain` a subagent's
    turns; a content list of tool_result blocks is the transcript's own plumbing. Naming a
    pane from any of those would read as the harness talking to itself.
    """
    if entry.get("type") != "user" or entry.get("isMeta") or entry.get("isSidechain"):
        return ""
    content = (entry.get("message") or {}).get("content")
    if isinstance(content, str):
        return content.strip()
    if isinstance(content, list):
        parts = [p.get("text", "") for p in content if isinstance(p, dict) and p.get("type") == "text"]
        return " ".join(parts).strip()
    return ""


def tagged(text, open_tag, close_tag):
    """The text between one pair of tags, or None when the pair is not both present."""
    start = text.find(open_tag)
    if start == -1:
        return None
    end = text.find(close_tag, start)
    if end == -1:
        return None
    return text[start + len(open_tag):end].strip()


def command_title(text):
    """A slash-command turn as `<args> <command>`: `/hunk-review 19426 pane=x` -> `19426 /hunk-review`.

    The argument LEADS because it is the distinguishing half: four panes each running
    /hunk-review differ only by their PR number, and a WORDS cut keeps whatever came first.
    Only positional args count - `pane=w1Y:p22` and `--flag` are plumbing the user did not
    type to describe the work.
    """
    name = tagged(text, CLAUDE_COMMAND_OPEN, CLAUDE_COMMAND_CLOSE)
    if not name:
        return None
    args = tagged(text, CLAUDE_ARGS_OPEN, CLAUDE_ARGS_CLOSE) or ""
    positional = [a for a in args.split() if "=" not in a and not a.startswith("-")]
    return " ".join(positional + [name])


def claude_transcript_title(ref, cwd):
    """Title for a claude session that never made it into the OSC title.

    Newest `ai-title` first, since that is the same string the OSC would have carried. Failing
    that the session was never named - the slash-command case - and the opening turn is the
    best description of it: the command's own name, or the first prompt when it was typed.
    """
    if ref.get("kind") == "path":
        path = ref.get("value")
    elif ref.get("kind") == "id" and stores:
        path = stores.claude_transcript(ref.get("value"), cwd)
    else:
        path = None
    if not path:
        return None
    head, tail = edge_windows(path)
    for line in reversed(tail.splitlines()):
        try:
            entry = json.loads(line)
        except ValueError:
            continue
        if entry.get("type") == "ai-title" and (entry.get("aiTitle") or "").strip():
            return entry["aiTitle"].strip()
    for line in head.splitlines():
        try:
            entry = json.loads(line)
        except ValueError:
            continue
        text = prompt_text(entry)
        if not text:
            continue
        if CLAUDE_COMMAND_OPEN not in text:
            return text
        return command_title(text) or text
    return None


def pi_first_user_title(path):
    """First user message in a pi transcript — pi emits no LLM title, so this is the signal."""
    try:
        with open(path, "rb") as handle:
            head = handle.read(HEAD_BYTES).decode("utf-8", "replace")
    except OSError:
        return None
    for line in head.splitlines():
        try:
            value = json.loads(line)
        except ValueError:
            continue
        message = value.get("message") or {} if value.get("type") == "message" else {}
        if message.get("role") != "user":
            continue
        content = message.get("content")
        if isinstance(content, str):
            text = content
        elif isinstance(content, list):
            text = " ".join(p.get("text", "") for p in content if isinstance(p, dict) and p.get("text"))
        else:
            text = ""
        if text.strip():
            return text.strip()
    return None


def pi_title(ref, cwd):
    path = ref.get("value") if ref.get("kind") == "path" else None
    if not path and cwd and stores:
        path = stores.pi_newest_session(cwd)
    return pi_first_user_title(path) if path else None


def opencode_title(ref, cwd):
    if not stores:
        return None
    title = (stores.opencode_by_session_or_cwd("title", ref, cwd) or "").strip()
    return None if title.startswith(OPENCODE_PLACEHOLDER) else (title or None)


# Authoritative for agents that never title their OSC, so their terminal title is not consulted.
STORE_READERS = {"pi": pi_title, "opencode": opencode_title, "open_code": opencode_title}
# Consulted only once the OSC title has proved useless, so a titled session pays nothing.
TRANSCRIPT_READERS = {"claude": claude_transcript_title}


def lookup_title(pane, readers):
    """Title from the agent's own on-disk record, TTL-cached per session.

    Keyed precisely: herdr's agent integrations report the exact session via
    `pane.report_agent_session`, so two panes in one directory never collide. The cwd stays
    in the key as the fallback for a session whose integration has not reported yet - and so
    does the agent, without which a pi and an opencode pane sharing a cwd would both land on
    the same (None, None, cwd) entry and inherit each other's title.
    """
    reader = readers.get(pane.get("agent"))
    if reader is None:
        return None
    ref = pane.get("agent_session") or {}
    cwd = pane.get("cwd") or pane.get("foreground_cwd")
    key = (pane.get("agent"), ref.get("kind"), ref.get("value"), cwd)
    cached = _title_cache.get(key)
    now = time.monotonic()
    if cached and cached[1] > now:
        return cached[0]
    title = reader(ref, cwd)
    _title_cache[key] = (title, now + (TITLE_TTL if title else TITLE_MISS_TTL))
    return title


def desired(pane):
    """The slug this pane should carry, or None to leave it alone."""
    if not pane.get("agent"):
        return None
    # A deliberate `pane.rename` outranks us.
    if (pane.get("label") or "").strip():
        return None
    title = (lookup_title(pane, STORE_READERS) or "").strip()
    if not title:
        title = (pane.get("terminal_title_stripped") or "").strip()
    # Only now, with no usable OSC title, is the transcript worth opening.
    if not title or title.lower() in PLACEHOLDERS:
        title = (lookup_title(pane, TRANSCRIPT_READERS) or "").strip()
    if not title or title.lower() in PLACEHOLDERS:
        return None
    return slugify(title, WORDS) or None


def apply(pane, cache, recheck_width=False):
    """Reconcile one pane. `cache` maps pane_id -> (raw slug, slug as written, lit, tab, pad).

    The slug goes out THREE ways in one write: `title` (the pane border, and herdr's built-in
    `pane` sidebar token) plus the `$pn`/`$pn_on` token pair the agents-panel row reads. The
    pair exists because a custom `$token` takes one flat inline `fg` and cannot vary by focus,
    so the two-tone is rebuilt by hand exactly as row 2 of the spaces panel does it for the
    branch - see herdr-focus-tracker.py::paint_panes. Exactly one slot ever holds the text;
    an empty token renders nothing, not even a separator.

    `lit` is part of the cache key so a pane whose slot is wrong gets rewritten on the next
    sweep. Slot correctness is really paint_panes' job - it repaints on every focus event -
    but this pane object's `focused` can be stale, and without `lit` in the key the unchanged
    slug would short-circuit the write and leave the mis-slot standing until the title changed.

    `pad` is in the key for the same reason, and it is why the sweep resolves a wrong pad at all:
    a row written with the wrong indent has an unchanged slug/lit/tab, so it used to return here
    before ws_indent was ever consulted and kept its bad indent for the life of the pane.
    """
    pane_id = pane.get("pane_id")
    if not pane_id:
        return
    raw = desired(pane)
    if raw is None:
        # Retract a slug we previously wrote once the pane stops qualifying (hand-renamed).
        if cache.pop(pane_id, None) is not None:
            request("pane.report_metadata", {
                "clear_title": True,
                "pane_id": pane_id,
                "source": SOURCE,
                "tokens": {"pn": None, "pn_on": None},
            })
        return
    lit = bool(pane.get("focused"))
    previous = cache.get(pane_id)
    # In the cache key so a renumbered tab rewrites the row - the slug alone would not have moved.
    tab = tab_prefix(pane.get("tab_id"), lambda m, p: request(m, p))
    # Steady state costs nothing: an unchanged title skips even the width lookup.
    if previous and previous[0] == raw and previous[2] == lit and previous[3] == tab and not recheck_width:
        return
    slug = truncate(raw, budget_for(pane_id))
    # Before the short-circuit below, not after: a stale pad is invisible in slug/lit/tab.
    pad = ws_indent(pane.get("workspace_id"), lambda m, p: request(m, p))
    if previous and previous[1] == slug and previous[2] == lit and previous[3] == tab and previous[4] == pad:
        cache[pane_id] = (raw, slug, lit, tab, pad)
        return
    row = pad + tab + slug
    result = request(
        "pane.report_metadata",
        {
            "pane_id": pane_id,
            "seq": time.time_ns(),
            "source": SOURCE,
            "title": slug,
            # Title stays bare - that is the pane BORDER label, which sits in the tab it names.
            "tokens": {"pn": None if lit else row, "pn_on": row if lit else None},
        },
    )
    if result is not None:
        cache[pane_id] = (raw, slug, lit, tab, pad)


def sweep(cache):
    """Full reconcile, re-measuring widths — the backstop for panes that emit no events."""
    _WS_LABELS.clear()  # labels can change between sweeps; the pad follows the glyph
    _TAB_POS.clear()    # and tabs open/close between sweeps, which reshuffles every position after them
    result = request("pane.list", {})
    for pane in (result or {}).get("panes", []):
        apply(pane, cache, recheck_width=True)


def clear_all():
    result = request("pane.list", {})
    for pane in (result or {}).get("panes", []):
        if pane.get("pane_id"):
            request(
                "pane.report_metadata",
                {
                    "clear_title": True,
                    "pane_id": pane["pane_id"],
                    "source": SOURCE,
                    "tokens": {"pn": None, "pn_on": None},
                },
            )


def handle(msg, cache):
    event = msg.get("event")
    data = msg.get("data") or {}
    if event in ("pane_updated", "pane_created"):
        apply(data.get("pane") or {}, cache)
    elif event == "pane_closed":
        cache.pop(data.get("closed_pane_id") or data.get("pane_id"), None)
    elif event in TAB_ORDER_EVENTS:
        # Re-apply every pane: the prefix is in the cache key, so only a moved number rewrites.
        _TAB_POS.clear()
        result = request("pane.list", {})
        for pane in (result or {}).get("panes", []):
            apply(pane, cache)


def session(cache):
    conn = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
    # Doubles as the reconcile tick: a read that expires means nothing happened, so sweep.
    conn.settimeout(RECONCILE_SECS)
    conn.connect(SOCK)
    req = {
        "id": "pane-summary",
        "method": "events.subscribe",
        "params": {"subscriptions": [{"type": t} for t in SUBSCRIPTIONS]},
    }
    conn.sendall((json.dumps(req) + "\n").encode())
    # Panes that were already titled before we connected get named on this pass.
    sweep(cache)
    buf = b""
    try:
        while True:
            try:
                chunk = conn.recv(65536)
            # socket.timeout, not TimeoutError: only an alias for it from Python 3.10 on,
            # and the Mac's /usr/bin/python3 is older than the VPS's.
            except socket.timeout:
                sweep(cache)
                continue
            if not chunk:
                return
            buf += chunk
            while b"\n" in buf:
                line, buf = buf.split(b"\n", 1)
                line = line.strip()
                if not line:
                    continue
                try:
                    msg = json.loads(line)
                except ValueError:
                    continue
                handle(msg, cache)
    finally:
        conn.close()


def main():
    if "--clear" in sys.argv:
        clear_all()
        return
    if "--once" in sys.argv:
        sweep({})
        return
    cache = {}
    while True:
        try:
            session(cache)
        except (OSError, ConnectionError):
            pass
        # Session ended. A missing socket means herdr is down — exit cleanly so the
        # supervisor restarts us when it returns, instead of spinning against a dead server.
        if not os.path.exists(SOCK):
            return
        cache.clear()
        time.sleep(1)


if __name__ == "__main__":
    main()
