"""herdr_agent_stores — where claude, pi and opencode keep their sessions, in one place.

Imported by herdr-pane-summary.py (which wants each session's TITLE) and by
herdr-agent-activity.py (which wants its last-activity TIME). Every one of them has to be
read off disk for something: pi and opencode put no usable session title in their OSC
terminal title, opencode keeps no transcript to tail at all, and claude's title is missing
from its OSC exactly when it never named the session. What the daemons share is not the
queries - those differ - but the FACTS about where those stores live and how they are keyed.
Those facts belong to the agents, not to either daemon, so they get one owner here.

Stdlib only, like both callers. Import it defensively:

    try:
        import herdr_agent_stores as stores
    except ImportError:
        stores = None

A missing module then costs only the on-disk enrichment instead of crash-looping a daemon
that still serves everything derived from the pane object - the daemons are supervised with
KeepAlive, so a hard import error would restart-loop and take working functionality down.
"""
import glob
import os

try:
    import sqlite3
except ImportError:  # a python built without the sqlite module: opencode reads degrade to None
    sqlite3 = None

# pi's config root, and opencode's SQLite store. Both honour the same env overrides the
# agents themselves do, so a relocated store keeps working.
PI_ROOT = os.environ.get("PI_CODING_AGENT_DIR") or os.path.expanduser("~/.pi/agent")
OPENCODE_DB = os.path.join(
    os.environ.get("XDG_DATA_HOME") or os.path.expanduser("~/.local/share"),
    "opencode", "opencode.db",
)
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
        for root in CLAUDE_ROOTS:
            direct = os.path.join(root, "projects", claude_project_slug(cwd), session_id + ".jsonl")
            if os.path.exists(direct):
                _claude_transcripts[session_id] = direct
                return direct
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


def pi_session_dir(cwd):
    """pi keys its session store by CWD, not pid: `/a/b` -> `sessions/--a-b--`."""
    return os.path.join(PI_ROOT, "sessions", "-%s--" % cwd.rstrip("/").replace("/", "-"))


def pi_newest_session(cwd):
    """Newest `.jsonl` transcript for `cwd`, or None.

    Only a fallback: pi's herdr integration reports the exact file as an `agent_session`
    path, so this is reached for a session that started before the extension loaded. Two pi
    panes sharing a directory get the same answer from it.
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


def opencode_query(sql, args):
    """One read-only query against opencode's store, or None on any failure.

    Read-only so it can never block or corrupt opencode's own writer, and short-timeout so
    a locked database costs a tick rather than wedging the caller.
    """
    if sqlite3 is None or not os.path.exists(OPENCODE_DB):
        return None
    try:
        conn = sqlite3.connect("file:%s?mode=ro" % OPENCODE_DB, uri=True, timeout=1)
        try:
            return conn.execute(sql, args).fetchall()
        finally:
            conn.close()
    except sqlite3.Error:
        return None


def opencode_by_session_or_cwd(column, session, cwd):
    """`column` for the pane's opencode session: exact by reported id, else newest for cwd.

    The cwd branch matches the longest project worktree that is a prefix of cwd, so a pane
    inside a subdirectory still resolves to its project.
    """
    session_id = session.get("value") if session.get("kind") == "id" else None
    if session_id:
        rows = opencode_query(
            "SELECT %s FROM session WHERE id = ? LIMIT 1;" % column, (session_id,)
        )
    elif cwd:
        rows = opencode_query(
            "SELECT s.%s FROM session s JOIN project p ON s.project_id = p.id "
            "WHERE p.worktree = ? OR ? LIKE p.worktree || '/%%' "
            "ORDER BY length(p.worktree) DESC, s.time_updated DESC LIMIT 1;" % column,
            (cwd, cwd),
        )
    else:
        return None
    return rows[0][0] if rows and rows[0][0] is not None else None
