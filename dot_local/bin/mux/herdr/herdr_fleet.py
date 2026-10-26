"""Fleet label text (kind glyph, PR number, model) for the herdr sidebar and Rex; herdr can't read reported tokens back."""
import glob
import os
import re

try:
    import herdr_agent_stores as stores
except ImportError:
    stores = None

KIND_MARK = {"scout": "\U0001f52d", "ship": "⛵"}
PR_NUMBER_RE = re.compile(r"/pull/([0-9]+)")
VENDOR_WORDS = {"claude", "gpt"}
EFFORT_SHORT = {"minimal": "min", "low": "low", "medium": "med", "high": "hi", "xhigh": "xhi", "max": "max"}


def short_model(model):
    """claude-opus-5-5 -> opus5.5, gpt-6-luna -> luna6; a dated snapshot suffix is dropped."""
    parts = [p for p in model.rsplit("/", 1)[-1].split("-") if p]
    words = [p for p in parts if not p[0].isdigit()]
    name = "".join(w for w in words if w.lower() not in VENDOR_WORDS) or "".join(words)
    return name + ".".join(p for p in parts if p[0].isdigit() and len(p) < 8)


def model_label(model, effort):
    """opus5.5 hi: the short model, then the effort it runs at; off/none shows no effort at all."""
    effort = (effort or "").strip().lower()
    shown = "" if effort in ("", "off", "none", "default") else EFFORT_SHORT.get(effort, effort)
    return " ".join(filter(None, (short_model(model), shown))) if model else ""


def pr_number(url):
    """`#<number>` from the PR url firstmate records once a ship task opens one, or "" before that."""
    match = PR_NUMBER_RE.search(url or "")
    return "#" + match.group(1) if match else ""


def read_meta(path):
    """One firstmate task .meta file as a dict, or None when it is unreadable."""
    try:
        with open(path) as f:
            return dict(line.rstrip("\n").split("=", 1) for line in f if "=" in line)
    except (OSError, ValueError):
        return None


def task_metas(home_glob="~/.local/share/firstmate*"):
    """(task, meta) for every task recorded under the matching firstmate homes."""
    for path in glob.glob(os.path.expanduser(home_glob) + "/state/*.meta"):
        meta = read_meta(path)
        if meta is not None:
            yield os.path.basename(path)[:-len(".meta")], meta


def task_badge(meta, *tail):
    """⛵ #1697 · sol6.1 med: the task's kind glyph, then its PR number, model and any `tail` parts where known."""
    kind = meta.get("kind", "")
    if kind not in KIND_MARK:
        return ""
    parts = (pr_number(meta.get("pr")), model_label(meta.get("model", ""), meta.get("effort"))) + tail
    return KIND_MARK[kind] + " " + " · ".join(filter(None, parts))


def agent_model_effort(a):
    """(model, effort) of one `agent list` entry's newest reply, (None, None) where its store is unreadable."""
    if stores is None:
        return None, None
    agent = a.get("agent")
    cwd, session = (a.get("cwd") or "").rstrip("/"), a.get("agent_session") or {}
    if agent == "hermes":
        return stores.hermes_model_effort()
    if agent == "codex":
        path = stores.codex_rollout(session, cwd)
        return stores.codex_model_effort(path) if path else (None, None)
    if session.get("kind") == "path":
        path = session.get("value")
    elif agent == "claude":
        path = stores.claude_transcript(session.get("value"), cwd) or stores.claude_newest_session(cwd)
    elif agent == "pi":
        path = stores.pi_newest_session(cwd)
    else:
        path = None
    return stores.last_model_effort(path) if path else (None, None)
