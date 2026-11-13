"""agent_stores - where claude and pi keep their sessions, in one place.

Imported by agent-transcript.py, which renders a claude or pi session transcript for the
rex-scrollback viewer. Agents redraw a full screen and keep no scrollback, so their history
has to be read off disk; the FACTS about where those stores live and how they are keyed
belong to the agents, so they get one owner here.

Stdlib only, like its caller.
"""
import glob
import json
import os

# pi's config root honours the same env override pi itself does, so a relocated store keeps working.
PI_ROOT = os.environ.get("PI_CODING_AGENT_DIR") or os.path.expanduser("~/.pi/agent")
# Both claude config roots (the VPS has only ~/.claude); a missing root just never matches.
CLAUDE_ROOTS = [os.path.expanduser("~/.claude"), os.path.expanduser("~/.claude-work")]

_claude_transcripts = {}  # session id -> resolved transcript path


def claude_project_slug(cwd):
    """claude's transcript directory name for a cwd: every /, . and _ becomes a dash,
    so /home/gnohj/.local/share/chezmoi -> -home-gnohj--local-share-chezmoi."""
    return cwd.replace("/", "-").replace(".", "-").replace("_", "-")


def claude_transcript(session_id, cwd):
    """Transcript path for a claude session id, cached. The cwd-derived slug is the fast path
    (one stat per root); a session that has since changed directory won't be there, so fall
    back to a scan for that id across every project dir and take the newest."""
    if not session_id:
        return None
    cached = _claude_transcripts.get(session_id)
    if cached and os.path.exists(cached):
        return cached
    if cwd:
        direct = [os.path.join(root, "projects", claude_project_slug(cwd), session_id + ".jsonl") for root in CLAUDE_ROOTS]
        live = [p for p in direct if os.path.exists(p)]
        if live:
            newest = max(live, key=os.path.getmtime)
            _claude_transcripts[session_id] = newest
            return newest
    best = None
    for root in CLAUDE_ROOTS:
        for candidate in glob.glob(os.path.join(root, "projects", "*", session_id + ".jsonl")):
            try:
                mtime = os.path.getmtime(candidate)
            except OSError:
                continue
            if best is None or mtime > best[0]:
                best = (mtime, candidate)
    if best:
        _claude_transcripts[session_id] = best[1]
        return best[1]
    return None


def claude_session_for_pid(pid):
    """Session id a running claude process records in <root>/sessions/<pid>.json, so panes sharing a cwd each get their own."""
    for root in CLAUDE_ROOTS:
        try:
            with open(os.path.join(root, "sessions", f"{int(pid)}.json")) as f:
                session = json.load(f).get("sessionId")
        except (OSError, ValueError):
            continue
        if session:
            return session
    return None


def claude_newest_session(cwd):
    """Newest claude transcript for `cwd` across both roots, for a pane that reported no session id."""
    best, best_mtime = None, -1.0
    for root in CLAUDE_ROOTS:
        for path in glob.glob(os.path.join(root, "projects", claude_project_slug(cwd), "*.jsonl")):
            try:
                mtime = os.path.getmtime(path)
            except OSError:
                continue
            if mtime > best_mtime:
                best, best_mtime = path, mtime
    return best


def pi_session_dir(cwd):
    """pi keys its session store by CWD, not pid: `/a/b` -> `sessions/--a-b--`."""
    return os.path.join(PI_ROOT, "sessions", "-%s--" % cwd.rstrip("/").replace("/", "-"))


def pi_newest_session(cwd):
    """Newest `.jsonl` transcript for `cwd`, or None.

    Only a fallback for a caller that cannot name the exact session file. Two pi panes
    sharing a directory get the same answer from it.
    """
    try:
        names = os.listdir(pi_session_dir(cwd))
    except OSError:
        return None
    directory = pi_session_dir(cwd)
    best, best_mtime = None, -1.0
    for name in names:
        if not name.endswith(".jsonl"):
            continue
        path = os.path.join(directory, name)
        try:
            mtime = os.stat(path).st_mtime
        except OSError:
            continue
        if mtime > best_mtime:
            best, best_mtime = path, mtime
    return best
