#!/usr/bin/env python3
"""herdr-thread-status — feed each workspace's PR/CI state ($pr) and Jira status ($jira) to the sidebar.

herdr knows nothing about GitHub, so the signs come from `gh` and are pushed back in as a
custom metadata token, exactly like $git (working-tree signs), $sys (host stats) and $act
(agent age). Every workspace on a branch gets a badge — the token needs only a checkout.

Separately, and only where a thread file under ~/.local/state/threads/ unambiguously owns
the workspace, this poller is also the WRITER of record for `pr_url` / `pr_approvals` /
`ci_status` / `pr_last_checked` — the fields the sidebar and split card read. One fetcher,
no disagreement. A workspace with no thread file still gets its badge; it just caches
nothing.

The previous fetcher only ran for live tmux sessions whose thread_kind was "ticket", so
working in herdr left the cache permanently cold. Anything reading those files benefits
from the poller running here instead.

Jira is RENDERED but never fetched. The same thread file carries `jira_status`, so the
$jira token is filled from it (shortened by the table below), but nothing here
writes that field: it needs Jira credentials this daemon does not have. Read-only, never a
writer. The skill that used to populate it
is gone, so until there is a token-based source, $jira shows whatever last landed in the
file and is empty for most workspaces. That gap is upstream of this poller, not in it.

Slow on purpose. Two `gh` calls per workspace are network round-trips and count against the
API rate limit, so the default interval is minutes, not the seconds $git runs at. Both calls
failing (offline, not a gh repo, `gh auth` never run) leaves the thread file UNTOUCHED, so a
transient error can never clobber good state.

Two zones, always both, `<approvals> │ <ci>`. Approvals: – none, ◌ one, ● two or more. CI:
⧗ running, ✗ failure, ✓ success, – none. The vocabularies are disjoint so no glyph means two
things — ● is only ever approvals, ✓ only ever CI — and both sides always print, because
dropping the empty one left a lone glyph whose zone the reader had to guess. Colouring the
zones apart is not an option: a metadata token carries a single inline fg. All single-cell and deliberately not emoji — a VS16
sequence measures one cell and draws two, stranding uncleared artifacts until a repaint.

Runs wherever the herdr SERVER runs, so under `herdr --remote` it lives on the VPS and reads
that box's thread files and checkouts — the state is per-host and that is correct, since a
VPS workspace's PR belongs to the VPS checkout. Needs `gh` authenticated on whichever host
that is; without it the token simply never appears. Stdlib only, no jq (gh embeds its own).

  herdr-thread-status.py           daemon: refresh every $HERDR_THREAD_INTERVAL seconds
  herdr-thread-status.py --once    one pass over every open workspace, then exit
  herdr-thread-status.py --clear   drop both tokens from every workspace, then exit
"""
import json
import os
import subprocess
import sys
import time

sys.dont_write_bytecode = True  # no __pycache__ in the deployed scripts dir

SOCK = os.environ.get("HERDR_SOCKET_PATH") or os.path.expanduser("~/.config/herdr/herdr.sock")
HERDR = os.environ.get("HERDR_BIN_PATH", "herdr")
# Minutes, not seconds: every pass is 2 network calls per workspace against a rate limit.
INTERVAL = int(os.environ.get("HERDR_THREAD_INTERVAL", "180"))
TTL_MS = (INTERVAL + 120) * 1000  # outlive a couple of missed passes
SOURCE = "thread-status"
TOKEN = "pr"
THREADS_DIR = os.path.join(
    os.environ.get("XDG_STATE_HOME") or os.path.expanduser("~/.local/state"), "threads"
)

# Vault-note discovery for the $sb token.
# PR: newest open PR for the branch -> "<url>\t<approved review count>", or "" for none.
PR_JQ = (
    '.[0] | if . == null then "" else .url + "\\t" '
    '+ ([.latestReviews[] | select(.state == "APPROVED")] | length | tostring) end'
)
# CI: only the runs for the NEWEST headSha — an older green sha must never mask a red one.
CI_JQ = (
    '(map(.headSha) | first) as $sha | map(select(.headSha == $sha)) '
    '| if length == 0 then empty '
    'elif map(select(.status == "in_progress" or .status == "queued")) | length > 0 then "running" '
    'elif map(select(.conclusion == "failure" or .conclusion == "timed_out" '
    'or .conclusion == "cancelled")) | length > 0 then "failure" else "success" end'
)

# Disjoint vocabularies: ● is approvals-complete, ✓ is CI-green, never the reverse.
APPROVAL_GLYPH = {0: "–", 1: "◌"}  # 2+ -> ●, via approval_glyph()
CI_GLYPH = {"running": "⧗", "failure": "✗", "success": "✓"}
NONE_GLYPH = "–"

# Jira workflow status, shortened to fit a 26-col sidebar. The canonical full name stays in
# the thread file and this is purely a display transform. Anything not listed falls through
# unchanged.
JIRA_SHORT = {
    "in dev review": "In Dev Rev",
    "in code review": "In Code Rev",
    "code review": "In Code Rev",
    "in review": "In Code Rev",
    "stakeholder review": "Stakeholder Rev",
    "product review": "Stakeholder Rev",
    "ready to merge": "Merge",
}


def out(args, cwd=None, timeout=20):
    """stdout of a command, or None if it failed — every caller treats None as "no data"."""
    try:
        done = subprocess.run(args, cwd=cwd, capture_output=True, text=True, timeout=timeout)
    except (OSError, subprocess.SubprocessError):
        return None
    return done.stdout.strip() if done.returncode == 0 else None


def workspace_cwds():
    """workspace_id -> cwd, from the first pane of each workspace. Same source as $git."""
    raw = out([HERDR, "pane", "list"], timeout=6)
    if not raw:
        return {}
    try:
        panes = json.loads(raw).get("result", {}).get("panes", [])
    except ValueError:
        return {}
    found = {}
    for pane in panes:
        ws = pane.get("workspace_id")
        cwd = (pane.get("foreground_cwd") or pane.get("cwd") or "").rstrip("/")
        if ws and cwd and ws not in found:
            found[ws] = cwd
    return found


def thread_files():
    """Every thread file, parsed. Small (one per worktree), so a full read per pass is fine."""
    entries = []
    try:
        names = os.listdir(THREADS_DIR)
    except OSError:
        return entries
    for name in names:
        if not name.endswith(".json"):
            continue
        path = os.path.join(THREADS_DIR, name)
        try:
            with open(path) as handle:
                entries.append((path, json.load(handle)))
        except (OSError, ValueError):
            continue
    return entries


def thread_for(cwd, branch, entries):
    """The thread file for a workspace, or (None, None) when it cannot be pinned down.

    Worktree first, branch second, and BOTH require a unique hit. Neither field is a key on
    its own, which is the whole reason for the uniqueness rule:

      * branch collides constantly — `main` and `master` each appear on several threads, as
        do shared feature branches. Taking the first match labelled every ordinary repo with
        some unrelated ticket's CI.
      * worktree collides for the review pool, where a batch of threads all sit in the one
        `…/review` checkout.

    Ambiguity therefore resolves to no match rather than a guess: a wrong PR badge is worse
    than none. Filenames are never used — they are the ticket key for a ticket branch and a
    slug otherwise, so they key nothing reliably.
    """
    def only(matches):
        return matches[0] if len(matches) == 1 else (None, None)

    hit = only([(p, d) for p, d in entries if (d.get("worktree") or "").rstrip("/") == cwd])
    if hit[0] or not branch:
        return hit
    return only([(p, d) for p, d in entries if d.get("branch") == branch])


def fetch(branch, worktree):
    """(pr_url, approvals, ci_status) from gh, each None when its call gave nothing."""
    pr = out(
        ["gh", "pr", "list", "--head", branch, "--state", "open",
         "--json", "url,latestReviews", "--jq", PR_JQ],
        cwd=worktree,
    )
    ci = out(
        ["gh", "run", "list", "--branch", branch, "--limit", "20",
         "--json", "headSha,status,conclusion", "--jq", CI_JQ],
        cwd=worktree,
    )
    url, approvals = None, None
    if pr is not None:
        if pr:
            parts = pr.split("\t", 1)
            url = parts[0] or None
            if len(parts) > 1 and parts[1].isdigit():
                approvals = int(parts[1])
        else:
            url, approvals = "", None  # "" = checked, no open PR (distinct from "not checked")
    return url, approvals, ci, (pr is not None or ci is not None)


def persist(path, data, url, approvals, ci):
    """Atomic write-back of the status fields. tmp+rename so no reader sees half."""
    if url is not None:
        data["pr_url"] = url or None
        data["pr_approvals"] = approvals
    if ci is not None:
        data["ci_status"] = ci or None
    data["pr_last_checked"] = time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())
    tmp = path + ".tmp"
    try:
        with open(tmp, "w") as handle:
            json.dump(data, handle, indent=2)
        os.replace(tmp, path)
    except OSError:
        try:
            os.unlink(tmp)
        except OSError:
            pass


def approval_glyph(approvals):
    """– none, ◌ one, ● two or more. Capping at 2 keeps it a state, not a counter."""
    n = approvals or 0
    return APPROVAL_GLYPH.get(n, "●") if n < 2 else "●"


def render(approvals, ci):
    """The $pr token, or "" for nothing worth a row.

    One string with one colour: a metadata token carries a single inline fg, so the approval and
    CI zones cannot be coloured apart. Both zones therefore render
    ALWAYS, divider included — dropping the empty side made a lone glyph ambiguous, since the
    reader could not tell which zone survived.
    """
    if approvals is None and not ci:
        return ""
    return "%s │ %s" % (approval_glyph(approvals), CI_GLYPH.get(ci or "", NONE_GLYPH))


def jira_short(status):
    """Jira status as the sidebar shows it, or "" when the thread carries none.

    Read-only, deliberately: nothing writes `jira_status` any more (the skill that did is
    gone), so this renders whatever last landed in the thread file and never invents a value.
    """
    text = (status or "").strip()
    return JIRA_SHORT.get(text.lower(), text)


def report(workspace, tokens, seq):
    """Push this source's tokens; each empty value clears its token rather than blanking."""
    base = [HERDR, "workspace", "report-metadata", workspace, "--source", SOURCE, "--seq", seq]
    args = []
    for name, value in tokens.items():
        args += ["--token", name + "=" + value] if value else ["--clear-token", name]
    if any(tokens.values()):
        args = ["--ttl-ms", str(TTL_MS)] + args
    subprocess.run(base + args, capture_output=True)


def refresh_once():
    """One pass: fetch per workspace, persist only where a thread file owns that workspace.

    Fetching is deliberately NOT conditional on a thread file existing. The two concerns are
    separate: the $pr token wants the state of whatever branch this workspace is on, while
    the thread file is a cache other tools read. Tying them together meant the workspace that
    most wants the badge — a ticket worktree whose thread file was never written, or was
    cleaned up — showed nothing at all. So every git workspace gets a badge, and the
    write-back happens only when a thread file unambiguously matches.
    """
    if not out(["gh", "--version"], timeout=5):
        return  # gh missing or unauthenticated env: leave every token untouched this pass
    entries = thread_files()
    seq = str(time.time_ns())  # ns: monotonic, and above any manual probe seq
    for workspace, cwd in workspace_cwds().items():
        if not os.path.isdir(cwd):
            continue
        branch = out(["git", "-C", cwd, "branch", "--show-current"], timeout=4)
        if not branch:
            report(workspace, {"jira": "", TOKEN: ""}, seq)  # not a git checkout / detached HEAD
            continue
        path, data = thread_for(cwd, branch, entries)
        url, approvals, ci, reached = fetch(branch, cwd)
        if reached and path:
            persist(path, data, url, approvals, ci)
        elif not reached:
            # Offline, or not a GitHub remote: fall back to whatever the thread file already
            # holds rather than blanking a badge because one pass could not reach GitHub.
            approvals = data.get("pr_approvals") if data else None
            ci = data.get("ci_status") if data else None
        report(workspace, {
            "jira": jira_short(data.get("jira_status") if data else None),
            TOKEN: render(approvals, ci),
        }, seq)


def clear_all():
    seq = str(time.time_ns())
    for workspace in workspace_cwds():
        report(workspace, {"jira": "", TOKEN: ""}, seq)


def main():
    if "--clear" in sys.argv:
        clear_all()
        return
    if "--once" in sys.argv:
        refresh_once()
        return
    while True:
        # Exit when the socket is gone (herdr down) so the supervisor restarts us when it
        # returns, instead of polling a dead socket.
        if not os.path.exists(SOCK):
            return
        refresh_once()
        time.sleep(INTERVAL)


if __name__ == "__main__":
    main()
