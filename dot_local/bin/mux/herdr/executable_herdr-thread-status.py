#!/usr/bin/env python3
"""herdr-thread-status — feed each workspace's PR ($pr/$pr_on), CI ($ci), Jira status ($jira) and vault note ($sb) to the sidebar.

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
writer. The writer is the `sb-agent-refresh` skill, supervised by herdr-jira-status.service,
which reaches Jira through MCP inside a real Claude session — the one place those credentials
exist. $jira is therefore empty until that poller's first tick lands a status.

The vault note ($sb) is the second-brain half, ported from the retired tmux-dash badge row: a
lone 󰎞 when the workspace's ticket has a note. Where that note lives is the shared `vault-note`
resolver's call, not this poller's. It needs no network, so it sits outside the `gh` check below
and renders on a box with no gh at all, and where a thread file owns the workspace the path is
mirrored into its `vault_note` field — a cache for sb-ticket-log that nothing else ever wrote.

Slow on purpose. The `gh` call per workspace is a network round-trip and counts against the
API rate limit, so the default interval is minutes, not the seconds $git runs at. The call
failing (offline, not a gh repo, `gh auth` never run) leaves the PR fields UNTOUCHED, so a
transient error can never clobber good state.

CI rides on that ONE call, via the PR's statusCheckRollup. It used to be a second call to
`gh run list`, which reads the Actions REST endpoint, and GitHub rate-limits that endpoint
per-repo far below the core quota: a big monorepo 403s there while `gh api rate_limit` still
reports ~4900/5000 core remaining. That failure mode was invisible, since the PR half kept
succeeding, so `pr_last_checked` stayed fresh while `ci_status` silently froze at whatever
the last un-limited pass saw. The rollup is already scoped to the PR's head commit, so it
also needs none of the newest-headSha filtering the old query hand-rolled. Its entries are
CheckRun (status/conclusion) or the legacy StatusContext (state), so PR_JQ matches both
shapes. Cost: a branch with no open PR now shows no CI, since the rollup hangs off the PR.

Two zones, always both, `<approvals> · <ci>`. Approvals: – none, ◌ one, ● two or more. CI:
⧗ running, ✗ failure, ✓ success, – none. The vocabularies are disjoint so no glyph means two
things — ● is only ever approvals, ✓ only ever CI — and both sides always print, because
dropping the empty one left a lone glyph whose zone the reader had to guess. They are two
tokens ($pr, $ci) rather than one string so the " · " is herdr's own separator and stays dim,
and so each zone can carry its own fg. All single-cell and deliberately not emoji — a VS16
sequence measures one cell and draws two, stranding uncleared artifacts until a repaint.

The approvals zone is a PAIR of tokens, $pr and $pr_on, for the same reason $git/$git_on is:
a herdr token's inline fg is unconditional, so one token cannot render – / ◌ red and ● green.
Exactly one slot is ever populated — approval_slots() puts ● in $pr_on and the incomplete
glyphs in $pr — and an empty token emits no separator, so the zone still reads as one cell.

Runs wherever the herdr SERVER runs, so under `herdr --remote` it lives on the VPS and reads
that box's thread files and checkouts — the state is per-host and that is correct, since a
VPS workspace's PR belongs to the VPS checkout. Needs `gh` authenticated on whichever host
that is; without it the token simply never appears. Stdlib only, no jq (gh embeds its own).

  herdr-thread-status.py           daemon: refresh every $HERDR_THREAD_INTERVAL seconds
  herdr-thread-status.py --once    one pass over every open workspace, then exit
  herdr-thread-status.py --clear   drop all five tokens from every workspace, then exit
"""
import json
import os
import re
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
# $pr's green twin, lit only at 2+ approvals; see approval_slots().
ON_TOKEN = "pr_on"
CI_TOKEN = "ci"
THREADS_DIR = os.path.join(
    os.environ.get("XDG_STATE_HOME") or os.path.expanduser("~/.local/state"), "threads"
)
# Shared with tkrm's deferral path: both drop a thread-file copy here for herdr-sb-drain to freeze.
FINISH_QUEUE = os.path.join(
    os.environ.get("XDG_STATE_HOME") or os.path.expanduser("~/.local/state"),
    "sb-ticket-finish-pending",
)
# Same ticket-key shape treekanga's worktree_setup.sh matches, so both writers agree on the id.
TICKET_RE = re.compile(r"([A-Z]+-[0-9]+)")
# worktree_setup.sh derives tmux_session by stripping this prefix; mirrored so the two agree.
DEV_PREFIX = os.path.expanduser("~/Developer") + "/"

# Absolute path: a herdr daemon's PATH is whatever the server was launched with.
VAULT_NOTE = os.path.expanduser("~/.local/bin/vault-note")
# nf-md-note_text (tmux-dash's badge glyph); Material Design shares the sidebar's grid, nf-fa draws larger.
NOTE_GLYPH = "\U000f039e"

# Newest open PR -> "<url>\t<approved reviews>\t<ci state>", or "" for none.
PR_JQ = (
    '.[0] | if . == null then "" else .url + "\\t" '
    '+ ([.latestReviews[] | select(.state == "APPROVED")] | length | tostring) + "\\t" '
    '+ ((.statusCheckRollup // []) | if length == 0 then "" '
    'elif map(select(.status == "IN_PROGRESS" or .status == "QUEUED" '
    'or .state == "PENDING")) | length > 0 then "running" '
    'elif map(select(.conclusion == "FAILURE" or .conclusion == "TIMED_OUT" '
    'or .conclusion == "CANCELLED" or .state == "FAILURE" or .state == "ERROR")) '
    '| length > 0 then "failure" else "success" end) end'
)

# Disjoint vocabularies: ● is approvals-complete, ✓ is CI-green, never the reverse.
APPROVAL_GLYPH = {0: "–", 1: "◌"}  # 2+ -> ●, via approval_glyph()
FULL_GLYPH = "●"  # the one approval glyph that rides $pr_on, so it can be green
CI_GLYPH = {"running": "⧗", "failure": "✗", "success": "✓"}
NONE_GLYPH = "–"

# Jira workflow status, shortened to fit a 32-col sidebar. The canonical full name stays in
# the thread file and this is purely a display transform. Anything not listed falls through
# unchanged.
# Keys are matched lowercased; the spares are aliases for boards that name a step differently.
JIRA_SHORT = {
    "blocked": "blocked",
    "to do": "todo",
    "in dev": "dev",
    "in dev/dqa review": "dev rev",
    "in dev review": "dev rev",
    "in dqa review": "dev rev",
    "in qa": "qa",
    "in code review": "code rev",
    "code review": "code rev",
    "in review": "code rev",
    "stakeholder review": "stake",
    "product review": "stake",
    "ready to merge": "merge",
    "done": "done",
}


def out(args, cwd=None, timeout=20):
    """stdout of a command, or None if it failed — every caller treats None as "no data"."""
    try:
        done = subprocess.run(args, cwd=cwd, capture_output=True, text=True, timeout=timeout)
    except (OSError, subprocess.SubprocessError):
        return None
    return done.stdout.strip() if done.returncode == 0 else None


def workspace_cwds():
    """workspace_id -> cwd, from the lowest-id pane of each workspace. Same source as $git.

    Sorted, and it has to be: a workspace can hold panes in DIFFERENT worktrees, so an unsorted
    "first pane seen" is a coin flip over which thread file this resolves to - and that decides
    the $pr and $ci the space row shows. herdr-git-status.sh picks its baseline the same way.
    """
    raw = out([HERDR, "pane", "list"], timeout=6)
    if not raw:
        return {}
    try:
        panes = json.loads(raw).get("result", {}).get("panes", [])
    except ValueError:
        return {}
    found = {}
    for pane in sorted(panes, key=lambda p: (p.get("workspace_id") or "",
                                             p.get("pane_id") or "")):
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


def create_thread(cwd, branch):
    """Write the thread file a ticket workspace is missing, or (None, None) if it cannot.

    treekanga's worktree_setup.sh postScript is the original writer, but it only runs for a
    worktree born through treekanga. herdr's built-in new_worktree, lazygit's worktree UI and a
    bare `git worktree add` all produce a checkout with no thread file, leaving $jira and the
    cached $pr fields blank forever — so this reconciles from the workspace list the poller
    already walks instead of relying on the creation moment.

    Ticket-shaped branches only: an untracked branch gets no Jira badge anyway, so a file for it
    would just add a `branch` collision to thread_for(). Schema and the skip-if-exists rule are
    copied from worktree_setup.sh so the two writers cannot disagree, and O_EXCL makes losing a
    concurrent race against it a no-op rather than a clobber.
    """
    match = TICKET_RE.search(branch)
    if not match:
        return None, None
    path = os.path.join(THREADS_DIR, match.group(1) + ".json")
    url = out(["git", "-C", cwd, "config", "--get", "remote.origin.url"], timeout=4) or ""
    now = time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())
    data = {
        "id": match.group(1),
        "kind": "ticket",
        "repo": re.sub(r"\.git$", "", os.path.basename(url)) or None,
        "branch": branch,
        "worktree": cwd,
        "tmux_session": cwd[len(DEV_PREFIX):] if cwd.startswith(DEV_PREFIX) else cwd,
        "vault_note": None,
        "pr_url": None,
        "created_at": now,
        "last_seen_at": now,
    }
    try:
        os.makedirs(THREADS_DIR, exist_ok=True)
        with open(os.open(path, os.O_CREAT | os.O_EXCL | os.O_WRONLY, 0o644), "w") as handle:
            json.dump(data, handle, indent=2)
    except FileExistsError:
        return None, None  # already written (by us on a past pass, or by worktree_setup.sh)
    except OSError:
        return None, None
    return path, data


def fetch(branch, worktree):
    """(pr_url, approvals, ci_status, reached) from one gh call; None where it gave nothing."""
    pr = out(
        ["gh", "pr", "list", "--head", branch, "--state", "open",
         "--json", "url,latestReviews,statusCheckRollup", "--jq", PR_JQ],
        cwd=worktree,
    )
    if pr is None:
        return None, None, None, False
    if not pr:
        # "" = checked, no open PR (distinct from "not checked"), and no PR means no CI to show.
        return "", None, "", True
    parts = pr.split("\t")
    url = parts[0] or None
    approvals = int(parts[1]) if len(parts) > 1 and parts[1].isdigit() else None
    return url, approvals, parts[2] if len(parts) > 2 else "", True


def enqueue_finish(path, data, cwd):
    """A known PR left the open set — if it MERGED, queue the vault-note freeze for herdr-sb-drain.

    Costs one extra `gh` call only on the pass where the PR disappears, never per pass, so the
    rate-limit budget the module docstring guards is unaffected. Closed-without-merge is ignored:
    nothing shipped, so there is nothing to freeze.
    """
    old = data.get("pr_url")
    if not old or data.get("pr_merged_at"):
        return
    info = out(
        ["gh", "pr", "view", old, "--json", "state,mergedAt,mergeCommit",
         "--jq", '.state + "\t" + (.mergedAt // "") + "\t" + (.mergeCommit.oid // "")'],
        cwd=cwd,
    )
    if not info:
        return
    parts = info.split("\t")
    if parts[0] != "MERGED":
        return
    data["pr_merged_at"] = (parts[1] if len(parts) > 1 and parts[1]
                            else time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()))
    data["merge_commit"] = parts[2] if len(parts) > 2 and parts[2] else None
    ticket = os.path.basename(path)[:-len(".json")]
    try:
        os.makedirs(FINISH_QUEUE, exist_ok=True)
        # O_EXCL: never re-queue a freeze the drain is already working through.
        job = os.path.join(FINISH_QUEUE, ticket + ".json")
        with open(os.open(job, os.O_CREAT | os.O_EXCL | os.O_WRONLY, 0o644), "w") as handle:
            json.dump(data, handle, indent=2)
    except (FileExistsError, OSError):
        return


def persist(path, data, url, approvals, ci, note):
    """Atomic write-back of the status fields. tmp+rename so no reader sees half."""
    if url is not None:
        data["pr_url"] = url or None
        data["pr_approvals"] = approvals
    if ci is not None:
        data["ci_status"] = ci or None
    # Mirror, not append-only: a deleted or renamed note clears the field.
    data["vault_note"] = note or None
    if url is not None or ci is not None:
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
    return APPROVAL_GLYPH.get(n, FULL_GLYPH) if n < 2 else FULL_GLYPH


def approval_slots(approvals):
    """The ($pr, $pr_on) pair — ● goes to the green slot, – and ◌ to the red one.

    Never both: a token's inline fg is unconditional, so the only way one zone renders in two
    colours is two tokens with one populated. An empty token emits no separator either, so the
    pair still occupies a single cell no matter which half is lit.
    """
    glyph = approval_glyph(approvals)
    return ("", glyph) if glyph == FULL_GLYPH else (glyph, "")


def render(approvals, ci):
    """The ($pr, $pr_on, $ci) glyph triple, or all-empty for nothing worth a row.

    Separate tokens, not one string: the " · " between them is then herdr's own separator and
    takes the dim contextual colour, where a single token would paint its divider the token's fg.
    Each zone also gets its own inline fg that way, which one token could never do.
    Both zones render ALWAYS or neither does — a lone glyph left the reader guessing which zone
    survived, and an empty token drops its separator too.
    """
    if approvals is None and not ci:
        return "", "", ""
    return approval_slots(approvals) + (CI_GLYPH.get(ci or "", NONE_GLYPH),)


def vault_note(cwd):
    """Vault-relative path of this workspace's ticket note, or "" — the lookup is vault-note's."""
    return out([VAULT_NOTE, "--relative", cwd], timeout=6) or ""


def jira_short(status):
    """Jira status as the sidebar shows it, or "" when the thread carries none.

    Read-only, deliberately: `sb-agent-refresh` owns this field, so this renders whatever last
    landed in the thread file and never invents a value.
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

    A ticket workspace with no file gets one created here (see create_thread), so the "never
    written" case self-heals on the next pass instead of staying blank forever.
    """
    # No gh skips only the PR half: $jira and $sb are local reads and still render.
    have_gh = bool(out(["gh", "--version"], timeout=5))
    entries = thread_files()
    seq = str(time.time_ns())  # ns: monotonic, and above any manual probe seq
    for workspace, cwd in workspace_cwds().items():
        if not os.path.isdir(cwd):
            continue
        branch = out(["git", "-C", cwd, "branch", "--show-current"], timeout=4)
        if not branch:
            # not a git checkout / detached HEAD
            report(workspace, {"jira": "", "sb": "", TOKEN: "", ON_TOKEN: "", CI_TOKEN: ""}, seq)
            continue
        path, data = thread_for(cwd, branch, entries)
        if not path:
            # No match can also mean AMBIGUOUS, which is why create_thread() skips an existing filename.
            path, data = create_thread(cwd, branch)
            if path:
                entries.append((path, data))
        note = vault_note(cwd)
        url, approvals, ci, reached = fetch(branch, cwd) if have_gh else (None, None, None, False)
        # Must run BEFORE persist, which clears pr_url to None once the PR leaves the open set.
        if path and data and reached and url == "" and data.get("pr_url"):
            enqueue_finish(path, data, cwd)
        if path and (reached or note != (data.get("vault_note") or "")):
            persist(path, data, url, approvals, ci, note)
        if not reached:
            # Offline, or not a GitHub remote: fall back to whatever the thread file already
            # holds rather than blanking a badge because one pass could not reach GitHub.
            approvals = data.get("pr_approvals") if data else None
            ci = data.get("ci_status") if data else None
        pr_glyph, pr_on_glyph, ci_glyph = render(approvals, ci)
        report(workspace, {
            "jira": jira_short(data.get("jira_status") if data else None),
            "sb": NOTE_GLYPH if note else "",
            TOKEN: pr_glyph,
            ON_TOKEN: pr_on_glyph,
            CI_TOKEN: ci_glyph,
        }, seq)


def clear_all():
    seq = str(time.time_ns())
    for workspace in workspace_cwds():
        report(workspace, {"jira": "", "sb": "", TOKEN: "", ON_TOKEN: "", CI_TOKEN: ""}, seq)


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
