"""herdr_agent_stores — where claude, pi, opencode, codex and hermes keep their sessions, in one place.

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
import json
import os
import re
import subprocess

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
CODEX_HOME = os.environ.get("CODEX_HOME") or os.path.expanduser("~/.codex")
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


def _tail_lines(path, tail):
    try:
        with open(path, "rb") as f:
            f.seek(0, os.SEEK_END)
            f.seek(max(0, f.tell() - tail))
            return f.read().decode("utf-8", "replace").splitlines()
    except OSError:
        return None


def _last_entry_of_type(path, kind):
    """Newest JSONL entry of `kind` anywhere in the file, for records written too rarely to trust the tail to hold one."""
    try:
        with open(path, "rb") as f:
            data = f.read()
    except OSError:
        return {}
    hit = data.rfind(b'"type":"%s"' % kind.encode())
    if hit < 0:
        return {}
    end = data.find(b"\n", hit)
    try:
        return json.loads(data[data.rfind(b"\n", 0, hit) + 1:end if end >= 0 else None])
    except ValueError:
        return {}


MODEL_SWITCH_RE = re.compile(r"<local-command-stdout>Set model to (?:\x1b\[[0-9;]*m|`)?([A-Za-z]+) (\d+(?:\.\d+)*)")
SWITCH_EFFORT_RE = re.compile(r" with (\w+) effort")


def _model_switch(entry):
    """(model, effort) a claude `/model` confirmation set, (None, None) for any other entry."""
    message = entry.get("message")
    content = message.get("content") if isinstance(message, dict) else None
    if entry.get("type") != "user" or not isinstance(content, str):
        return None, None
    switch = MODEL_SWITCH_RE.search(content)
    if not switch:
        return None, None
    effort = SWITCH_EFFORT_RE.search(content)
    return f"claude-{switch.group(1).lower()}-{switch.group(2).replace('.', '-')}", effort and effort.group(1)


def last_model_effort(path, tail=262144):
    """(model, effort) of the newest claude/pi reply or claude `/model` switch; claude stamps effort per reply, pi logs thinking_level_change."""
    lines = _tail_lines(path, tail)
    if lines is None:
        return None, None
    model = effort = None
    is_pi = False
    awaiting_effort = False
    for line in reversed(lines):
        try:
            entry = json.loads(line)
        except ValueError:
            continue
        if not isinstance(entry, dict) or entry.get("isSidechain"):
            continue
        kind = entry.get("type")
        is_pi = is_pi or kind in ("message", "model_change", "thinking_level_change")
        if kind == "thinking_level_change" and effort is None:
            effort = entry.get("thinkingLevel")
        if model is None and kind == "model_change":
            model = entry.get("modelId")
        if model is None:
            model, switch_effort = _model_switch(entry)
            if model:
                effort = effort or switch_effort
                awaiting_effort = effort is None
                continue
        message = entry.get("message")
        if isinstance(message, dict) and message.get("role") == "assistant":
            candidate = message.get("model")
            if isinstance(candidate, str) and candidate and not candidate.startswith("<"):
                model = model or candidate
                effort = effort or entry.get("effort")
                awaiting_effort = False
        if model and not awaiting_effort and (effort or not is_pi):
            break
    if is_pi and effort is None:
        effort = _last_entry_of_type(path, "thinking_level_change").get("thinkingLevel")
    return model, effort


# hermes runs in rootless Docker, whose volume the host user cannot read, so its state.db is queried in place.
HERMES_CONTAINER = os.environ.get("HERMES_CONTAINER") or "hermes-agent-hermes-1"
# A null reasoning_config is sent as hermes's own default, medium (agent/chat_completion_helpers.py).
_HERMES_MODEL_SQL = """
import json, sqlite3
row = sqlite3.connect('file:/opt/data/state.db?mode=ro', uri=True).execute(
    "select u.model, s.model_config from session_model_usage u join sessions s on s.id = u.session_id"
    " where s.source = 'cli' and u.task = '' order by u.last_seen desc limit 1").fetchone()
if row:
    try:
        rc = json.loads(row[1] or '{}').get('reasoning_config')
    except ValueError:
        rc = None
    effort = 'medium' if rc is None else (rc.get('effort') or '') if rc.get('enabled', True) else 'none'
    print(row[0] + '\\t' + effort)
"""


def hermes_model_effort(timeout=3):
    """(model, effort) of hermes's newest CLI turn; side tasks (titles, approvals, reviews) are excluded."""
    env = dict(os.environ)
    if os.uname().sysname == "Linux":
        env["DOCKER_HOST"] = env.get("HERMES_DOCKER_HOST") or env.get("DOCKER_HOST") or \
            "unix://%s/docker.sock" % (env.get("XDG_RUNTIME_DIR") or "/run/user/%d" % os.getuid())
    try:
        result = subprocess.run(["docker", "exec", HERMES_CONTAINER, "python3", "-c", _HERMES_MODEL_SQL],
                                capture_output=True, text=True, timeout=timeout, env=env)
    except (OSError, subprocess.SubprocessError):
        return None, None
    parts = result.stdout.strip().split("\t") if result.returncode == 0 else []
    return (parts[0] or None, parts[1] or None) if len(parts) == 2 else (None, None)


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

    The cwd branch prefers the session's own directory (a non-git session's worktree is "/"), then the longest worktree prefix.
    """
    session_id = session.get("value") if session.get("kind") == "id" else None
    if session_id:
        rows = opencode_query(
            "SELECT %s FROM session WHERE id = ? LIMIT 1;" % column, (session_id,)
        )
    elif cwd:
        rows = opencode_query(
            "SELECT s.%s FROM session s JOIN project p ON s.project_id = p.id "
            "WHERE s.directory = ? OR p.worktree = ? OR ? LIKE p.worktree || '/%%' "
            "ORDER BY s.directory = ? DESC, length(p.worktree) DESC, s.time_updated DESC LIMIT 1;" % column,
            (cwd, cwd, cwd, cwd),
        )
    else:
        return None
    return rows[0][0] if rows and rows[0][0] is not None else None


def opencode_model_effort(session, cwd):
    """(model, variant) of the newest assistant message in the pane's opencode session; no variant is the model default."""
    session_id = opencode_by_session_or_cwd("id", session, cwd)
    rows = opencode_query(
        "SELECT json_extract(data, '$.modelID'), json_extract(data, '$.variant') FROM message "
        "WHERE session_id = ? AND json_extract(data, '$.role') = 'assistant' "
        "ORDER BY time_created DESC LIMIT 1;",
        (session_id,),
    ) if session_id else None
    return tuple(rows[0]) if rows else (None, None)


def codex_rollout(session, cwd, scan=40):
    """codex's rollout file for the pane: by reported thread id, else the newest whose session_meta cwd matches."""
    if session.get("kind") == "path":
        return session.get("value")
    root = os.path.join(CODEX_HOME, "sessions")
    if session.get("kind") == "id" and session.get("value"):
        if not re.fullmatch(r"[0-9A-Za-z-]+", session["value"]):
            return None
        hits = glob.glob(os.path.join(root, "*", "*", "*", "rollout-*-%s.jsonl" % session["value"]))
        return max(hits, key=os.path.getmtime) if hits else None
    if not cwd:
        return None
    recent = sorted(glob.glob(os.path.join(root, "*", "*", "*", "rollout-*.jsonl")), reverse=True)[:scan]
    for path in recent:
        try:
            with open(path) as f:
                meta = json.loads(f.readline()).get("payload") or {}
        except (OSError, ValueError):
            continue
        if (meta.get("cwd") or "").rstrip("/") == cwd:
            return path
    return None


def codex_default_effort(model):
    """What codex sends when a turn names no effort: config.toml's model_reasoning_effort, else the model's catalogue default."""
    try:
        with open(os.path.join(CODEX_HOME, "config.toml")) as f:
            match = re.search(r'^model_reasoning_effort\s*=\s*"([^"]+)"', f.read(), re.M)
        if match:
            return match.group(1)
    except OSError:
        pass
    try:
        with open(os.path.join(CODEX_HOME, "models_cache.json")) as f:
            catalogue = json.load(f)
    except (OSError, ValueError):
        return None
    for entry in catalogue.get("models", []) if isinstance(catalogue, dict) else []:
        if entry.get("slug") == model:
            return entry.get("default_reasoning_level")
    return None


def codex_model_effort(path, tail=262144):
    """(model, effort) from the newest turn_context in a codex rollout."""
    payload = None
    for line in reversed(_tail_lines(path, tail) or []):
        if '"turn_context"' in line:
            try:
                payload = json.loads(line).get("payload")
                break
            except ValueError:
                continue
    payload = payload or _last_entry_of_type(path, "turn_context").get("payload") or {}
    model = payload.get("model")
    if not model:
        return None, None
    settings = (payload.get("collaboration_mode") or {}).get("settings") or {}
    return model, payload.get("effort") or settings.get("reasoning_effort") or codex_default_effort(model)
