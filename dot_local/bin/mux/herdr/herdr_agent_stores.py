"""herdr_agent_stores — where pi and opencode keep their sessions, in one place.

Imported by herdr-pane-summary.py (which wants each session's TITLE) and by
herdr-agent-activity.py (which wants its last-activity TIME). Neither agent puts a usable
session title in its OSC terminal title, and opencode keeps no transcript to tail at all,
so both daemons have to read the agents' own stores. What they share is not the queries -
those differ - but the FACTS about where those stores live and how they are keyed. Those
facts belong to pi and opencode, not to either daemon, so they get one owner here.

The same two sources tmux-dash reads, in src/agents/pi.rs and src/agents/opencode.rs.

Stdlib only, like both callers. Import it defensively:

    try:
        import herdr_agent_stores as stores
    except ImportError:
        stores = None

A missing module then costs only pi/opencode enrichment instead of crash-looping a daemon
that otherwise still serves claude - the daemons are supervised with KeepAlive, so a hard
import error would restart-loop and take working functionality down with it.
"""
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


def pi_session_dir(cwd):
    """pi keys its session store by CWD, not pid: `/a/b` -> `sessions/--a-b--`."""
    return os.path.join(PI_ROOT, "sessions", "-%s--" % cwd.rstrip("/").replace("/", "-"))


def pi_newest_session(cwd):
    """Newest `.jsonl` transcript for `cwd`, or None.

    Only a fallback: pi's herdr integration reports the exact file as an `agent_session`
    path, so this is reached for a session that started before the extension loaded. It is
    also what tmux-dash has to rely on exclusively, which is why two pi panes sharing a
    directory get the same answer there.
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
    inside a subdirectory still resolves to its project - the same predicate tmux-dash uses.
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
