#!/usr/bin/env python3
"""herdr-pane-summary — label each agent pane with a slug of its AI session title.

The herdr counterpart of tmux-dash's `auto_pane_rename` feature (src/state.rs
`apply_auto_summary` + `slugify`), which turns an un-renamed agent pane from an anonymous
`claude` into `implement-herdr-pane-rename`.

tmux-dash has to WORK for the title: map pane_pid -> ~/.claude/projects/<slug>/ -> newest
JSONL -> last `{"type":"ai-title"}`, with a whole-file re-scan when the 64 KB tail misses on
a resumed session. For claude and codex none of that layer is needed here, because herdr
parses their OSC title and hands it over on the pane object as `terminal_title_stripped`
(spinner glyph and all, pre-stripped) - the daemon is just title -> slug -> write.

pi and opencode DO set an OSC title, but never a session one: pi shows `π - <cwd basename>`
and opencode prefixes its own with `OC | `, so slugging those gives a name that is either
the directory or a wasted segment. For them the session store is authoritative instead
(`store_title` below), read from the same two sources tmux-dash uses - pi's first user
message and opencode's stored session title. The OSC title stays as the backstop for when
the store read misses. Where those stores live is owned by the sibling herdr_agent_stores
module, shared with herdr-agent-activity.py.

Write channel is `pane.report_metadata`, NOT `pane.rename`:
  * `pane.rename` sets `label`, herdr's deliberate-rename field. That is the user's, the
    same way tmux-dash's `@agent_name` outranks `@agent_summary` — a pane carrying a label
    is skipped entirely, so a hand-named pane is never clobbered.
  * `pane.report_metadata --source auto-summary --title <slug>` is the display-only channel
    and is scoped by `source`, so our record and any other reporter's stay independent.
Both render on the pane border.

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

Widths mirror tmux-dash: the slug is capped at `WORDS` hyphen-segments and then truncated
to the pane's real border budget with an ellipsis (crate::text::truncate), east-asian width
aware so a CJK title reserves its true cells.

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
except ImportError:  # sibling absent: pi/opencode degrade, claude and codex are unaffected
    stores = None

SOCK = os.environ.get("HERDR_SOCKET_PATH") or os.path.expanduser("~/.config/herdr/herdr.sock")

SOURCE = "auto-summary"
SUBSCRIPTIONS = ["pane.updated", "pane.created", "pane.closed"]

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

# Session-store reads for the agents that never put a title in their OSC title (see
# store_title). 64 KB mirrors tmux-dash's read_head. The TTL only smooths event bursts -
# a pi title is immutable and opencode re-titles rarely, so staleness is not a concern.
HEAD_BYTES = 64 * 1024
TITLE_TTL = int(os.environ.get("HERDR_SUMMARY_TITLE_TTL", "30"))
# opencode names a session `New session - <iso>` until its summarizer replaces it.
OPENCODE_PLACEHOLDER = "New session"
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
    """tmux-dash crate::text::truncate — fit `budget` cells, reserving one for the ellipsis."""
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


STORE_READERS = {"pi": pi_title, "opencode": opencode_title, "open_code": opencode_title}


def store_title(pane):
    """Title from the agent's own session store, for agents that set no OSC title.

    claude and codex title their OSC, so the pane object already carries the answer. pi and
    opencode never do, which is why their panes stayed anonymous here while tmux-dash renamed
    them. Same two sources tmux-dash reads (src/agents/pi.rs `first_user_title`,
    src/agents/opencode.rs `title`), but keyed better: herdr's pi/opencode integrations report
    the exact session via `pane.report_agent_session`, where tmux-dash can only guess by cwd
    and so collides between two panes in one directory. The cwd lookup stays as the fallback
    for a session whose integration has not reported yet.
    """
    agent = pane.get("agent")
    reader = STORE_READERS.get(agent)
    if reader is None:
        return None
    ref = pane.get("agent_session") or {}
    cwd = pane.get("cwd") or pane.get("foreground_cwd")
    # The agent belongs in the key: without it a pi and an opencode pane sharing a cwd both
    # fall back to the same (None, None, cwd) entry and inherit each other's title.
    key = (agent, ref.get("kind"), ref.get("value"), cwd)
    cached = _title_cache.get(key)
    now = time.monotonic()
    if cached and cached[1] > now:
        return cached[0]
    title = reader(ref, cwd)
    _title_cache[key] = (title, now + TITLE_TTL)
    return title


def desired(pane):
    """The slug this pane should carry, or None to leave it alone."""
    if not pane.get("agent"):
        return None
    # A deliberate `pane.rename` outranks us, exactly like tmux-dash's @agent_name.
    if (pane.get("label") or "").strip():
        return None
    # For a store-backed agent the store is authoritative, exactly as in tmux-dash, which
    # never consults their OSC title: whatever their terminal is showing is a placeholder or
    # the shell's own doing. The OSC title stays the backstop for when the store read misses.
    title = ""
    if pane.get("agent") in STORE_READERS:
        title = (store_title(pane) or "").strip()
    if not title:
        title = (pane.get("terminal_title_stripped") or "").strip()
    if not title or title.lower() in PLACEHOLDERS:
        return None
    return slugify(title, WORDS) or None


def apply(pane, cache, recheck_width=False):
    """Reconcile one pane. `cache` maps pane_id -> (raw slug, slug as written)."""
    pane_id = pane.get("pane_id")
    if not pane_id:
        return
    raw = desired(pane)
    if raw is None:
        # Retract a slug we previously wrote once the pane stops qualifying (hand-renamed).
        if cache.pop(pane_id, None) is not None:
            request("pane.report_metadata", {"pane_id": pane_id, "source": SOURCE, "clear_title": True})
        return
    previous = cache.get(pane_id)
    # Steady state costs nothing: an unchanged title skips even the width lookup.
    if previous and previous[0] == raw and not recheck_width:
        return
    slug = truncate(raw, budget_for(pane_id))
    if previous and previous[1] == slug:
        cache[pane_id] = (raw, slug)
        return
    result = request(
        "pane.report_metadata",
        {"pane_id": pane_id, "source": SOURCE, "title": slug, "seq": time.time_ns()},
    )
    if result is not None:
        cache[pane_id] = (raw, slug)


def sweep(cache):
    """Full reconcile, re-measuring widths — the backstop for panes that emit no events."""
    result = request("pane.list", {})
    for pane in (result or {}).get("panes", []):
        apply(pane, cache, recheck_width=True)


def clear_all():
    result = request("pane.list", {})
    for pane in (result or {}).get("panes", []):
        if pane.get("pane_id"):
            request(
                "pane.report_metadata",
                {"pane_id": pane["pane_id"], "source": SOURCE, "clear_title": True},
            )


def handle(msg, cache):
    event = msg.get("event")
    data = msg.get("data") or {}
    if event in ("pane_updated", "pane_created"):
        apply(data.get("pane") or {}, cache)
    elif event == "pane_closed":
        cache.pop(data.get("closed_pane_id") or data.get("pane_id"), None)


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
