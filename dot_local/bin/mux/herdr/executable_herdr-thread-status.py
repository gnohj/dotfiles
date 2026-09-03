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

Agent HOME workspaces opt OUT of all five (AGENT_HOME_RE): the captain's own `fm-personal` and
`fm-work` sesh sessions (one code root, two FM_HOMEs, so both are the same checkout), plus
firstmate's own `firstmate` home and every `2ndmate-<id>` secondmate home. A home sits on a
permanent branch of a read-only checkout, so approvals, CI, the vault note and Jira are all
permanently empty there, and herdr has no per-workspace row layout: the row is global, so the
only way it stops rendering as bare placeholders is for its tokens to carry no value. The five
are cleared rather than skipped, so a token set by an earlier pass (or by an older build of this
script) disappears instead of lingering at its stale glyph.

Their PROJECTED TASK WORKTREES are not homes and keep the whole row - those are the `└ <branch>`
children carrying a real ticket branch, which is exactly where the badge earns its place. The
match is on label SHAPE, never on the sidebar glyph, which is presentation and does change.

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
sys.path.insert(0, os.path.dirname(os.path.realpath(__file__)))
from herdr_label import indent_first, is_agent_home  # noqa: E402  (needs the path above)

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
JIRA_TOKEN = "jira"
SB_TOKEN = "sb"
# Row 3's token order in [ui.sidebar.spaces]; the indent rides whichever of them is lit first.
# Each zone has a DIM twin because herdr cannot dim a custom token by focus - an inline fg is unconditional - so the unfocused state is a second token, as $br/$br_on already do.
ROW3_ORDER =("pr", "pr_on", "pr_d", "ci", "ci_d", "sb", "sb_d", "jira", "jira_d")
# Zone -> (lit slot, lit slot for the green twin or None, dim slot). Shared with the focus tracker.
ROW3_ZONES = (("pr", "pr_on", "pr_d"), ("ci", None, "ci_d"), ("sb", None, "sb_d"), ("jira", None, "jira_d"))
# A `…/review` checkout is a POOL reused across PRs, so thread_for() matches on worktree and keeps labelling it with a long-shipped ticket.
REVIEW_POOL_LEAF = "review"
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
# Lowercase fallback for branches like `fm/web-ihrweb-24720-...`; tried only AFTER the strict pass, so every branch that resolves today keeps resolving to the same key.
TICKET_RE_LOOSE = re.compile(r"([A-Za-z]+-[0-9]+)")


def ticket_key(text):
    """The ticket in `text` as an UPPERCASE key, or None.

    Uppercase-first, so a branch carrying both a real key and a lowercase near-miss still picks
    the real one. The result is upper()ed either way: the key is the thread FILENAME, and a
    lowercase twin would sit beside the canonical file as a second record of one ticket.
    """
    match = TICKET_RE.search(text) or TICKET_RE_LOOSE.search(text)
    return match.group(1).upper() if match else None
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


def label_task_id(label):
    """The task id a fleet workspace label carries, or None.

    Labels look like `\u2514 web-ihrweb-24720-d2-archive-traffic \u00b7 p:sLXd...`: a tree glyph,
    the id, then a bullet-separated pane hint. Agent homes are filtered out before this.
    """
    text = label.split(" \u00b7 ")[0]
    text = text.strip().lstrip("\u2514\u251c\u2500\u2502 ").strip()
    return text or None


def worktree_branch_for(cwd, label):
    """(worktree, branch) for the checkout this workspace's task actually works in.

    A crewmate's shell can sit in the SHARED clone while its work lives in a task worktree - the
    shell reports `master`, which carries no ticket, so every badge on that row goes blank even
    though the task has a branch and a PR. `git worktree list` from the shared clone enumerates
    every sibling worktree, so the task's own branch is one cheap local call away.

    Deliberately narrow: it engages only when the current branch has no ticket, and only on an
    EXACT id match, so it can never relabel a workspace that already resolves.
    """
    task = label_task_id(label)
    if not task:
        return None, None
    raw = out(["git", "-C", cwd, "worktree", "list", "--porcelain"], timeout=6)
    if not raw:
        return None, None
    path = None
    for line in raw.splitlines():
        if line.startswith("worktree "):
            path = line[len("worktree "):].strip()
        elif line.startswith("branch ") and path:
            branch = line[len("branch "):].strip()
            short = branch[len("refs/heads/"):] if branch.startswith("refs/heads/") else branch
            if short == task or short.endswith("/" + task):
                return path, short
    return None, None


def workspace_labels():
    """workspace_id -> (label, focused). One call, because row 3 needs both.

    Focus decides the lit-or-dim slot; the focus TRACKER repaints on change, this only has to agree
    with it so a slow poll never drags a row back to the wrong slot - same contract as $br/$br_on.
    """
    raw = out([HERDR, "workspace", "list"], timeout=6)
    if not raw:
        return {}
    try:
        spaces = json.loads(raw).get("result", {}).get("workspaces", [])
    except ValueError:
        return {}
    return {w.get("workspace_id"): (w.get("label") or "", bool(w.get("focused")))
            for w in spaces if w.get("workspace_id")}


def row3_slots(values, focused):
    """Place each zone's value in its lit or dim slot; the other stays empty and emits no separator."""
    slots = {name: "" for name in ROW3_ORDER}
    for lit, lit_on, dim in ROW3_ZONES:
        value = values.get(lit_on) or values.get(lit) if lit_on else values.get(lit)
        if not value:
            continue
        if not focused:
            slots[dim] = value
        elif lit_on and value == values.get(lit_on):
            slots[lit_on] = value
        else:
            slots[lit] = value
    return slots


def blank_tokens():
    """All five tokens empty; report() turns each into a --clear-token, so nothing lingers."""
    return {name: "" for name in ROW3_ORDER}



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

    A worktree hit must ALSO still be on the thread's branch. Treehouse slots are recycled:
    `…/web-130256/1/web` carried IHRWEB-24272 until it merged, then got re-checked-out onto an
    unrelated backport branch, and nothing deletes the thread file unless the worktree is torn
    down through tkrm. The path alone therefore stayed a unique hit and handed the new branch
    the old ticket's `jira_status: Completed`. `branch` is written once at creation and never
    rewritten by persist(), so it is a reliable witness of which checkout the file describes.

    Ambiguity therefore resolves to no match rather than a guess: a wrong PR badge is worse
    than none. Filenames are never used — they are the ticket key for a ticket branch and a
    slug otherwise, so they key nothing reliably.
    """
    def only(matches):
        return matches[0] if len(matches) == 1 else (None, None)

    def here(entry):
        return (entry.get("worktree") or "").rstrip("/") == cwd

    hit = only([(p, d) for p, d in entries if here(d) and (not branch or d.get("branch") == branch)])
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
    key = ticket_key(branch)
    if not key:
        return None, None
    path = os.path.join(THREADS_DIR, key + ".json")
    url = out(["git", "-C", cwd, "config", "--get", "remote.origin.url"], timeout=4) or ""
    now = time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())
    data = {
        "id": key,
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
    # Siblings on ONE ticket fall back to a per-branch name; thread_for() keys on the worktree and branch FIELDS, never the filename, and `id` stays the bare key so Jira still resolves.
    for candidate in (path, os.path.join(THREADS_DIR, key + "__" + re.sub(r"[^A-Za-z0-9._-]", "-", branch) + ".json")):
        try:
            os.makedirs(THREADS_DIR, exist_ok=True)
            with open(os.open(candidate, os.O_CREAT | os.O_EXCL | os.O_WRONLY, 0o644), "w") as handle:
                json.dump(data, handle, indent=2)
        except FileExistsError:
            continue  # taken by us on a past pass, by worktree_setup.sh, or by a sibling branch
        except OSError:
            return None, None
        return candidate, data
    return None, None


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


def ticket_pr_fallback(key, worktree, entries):
    """(pr_url, approvals, ci_status) for the TICKET when this branch has no PR of its own.

    Several branches can feed one ticket's single PR - the three IHRWEB-24273 workspaces all
    contribute to one, and none of them carries a PR itself, so every badge on those rows stayed
    empty while the ticket's PR sat there with real review and CI state. The ticket is what the
    row is about, so the ticket's PR is the honest thing to show.

    Only ever a FALLBACK: a branch with its own PR keeps reporting that one, never the ticket's.
    """
    if not key:
        return None, None, None
    url = next((d.get("pr_url") for _, d in entries
                if d.get("id") == key and d.get("pr_url")), None)
    if not url:
        return None, None, None
    # PR_JQ starts at `.[0]` for `gh pr list`'s array, so `gh pr view`'s single object is wrapped rather than the filter duplicated.
    raw = out(["gh", "pr", "view", url, "--json",
               "url,latestReviews,statusCheckRollup", "--jq", "[.] | " + PR_JQ], cwd=worktree)
    if not raw:
        return None, None, None
    parts = raw.split("\t")
    approvals = int(parts[1]) if len(parts) > 1 and parts[1].isdigit() else None
    return parts[0] or None, approvals, parts[2] if len(parts) > 2 else ""


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
    # From the record's `id`, not the filename: a `<KEY>__<branch>.json` sibling would hand herdr-sb-drain a key no Jira ticket answers to.
    ticket = data.get("id") or os.path.basename(path)[:-len(".json")]
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
    labels = workspace_labels()
    seq = str(time.time_ns())  # ns: monotonic, and above any manual probe seq
    for workspace, cwd in workspace_cwds().items():
        label, focused = labels.get(workspace, ("", False))
        if is_agent_home(label):
            # Cleared, not skipped, so stale glyphs go rather than linger as placeholders.
            report(workspace, blank_tokens(), seq)
            continue
        if os.path.basename(cwd.rstrip("/")) == REVIEW_POOL_LEAF:
            # The branch row still renders - that one comes from the checkout itself and is true.
            report(workspace, blank_tokens(), seq)
            continue
        if not os.path.isdir(cwd):
            continue
        branch = out(["git", "-C", cwd, "branch", "--show-current"], timeout=4)
        if branch and not ticket_key(branch):
            # Shell parked in the shared clone: follow the task's own worktree instead.
            alt_cwd, alt_branch = worktree_branch_for(cwd, label)
            if alt_cwd and os.path.isdir(alt_cwd):
                cwd, branch = alt_cwd, alt_branch
        if not branch:
            # not a git checkout / detached HEAD
            report(workspace, blank_tokens(), seq)
            continue
        # A branch can carry no ticket at all (`fm/pr19552-increment`); the workspace label is the last source before giving up.
        key = ticket_key(branch) or ticket_key(label)
        path, data = thread_for(cwd, branch, entries)
        if not path:
            # No match can also mean AMBIGUOUS, which is why create_thread() skips an existing filename.
            path, data = create_thread(cwd, branch)
            if path:
                entries.append((path, data))
        if not data and not ticket_key(branch) and key:
            # Read-only: this row does not own that ticket's file, and persisting would let one workspace's PR overwrite another's.
            data = next((d for _, d in entries if d.get("id") == key), None)
            path = None
        note = vault_note(cwd)
        url, approvals, ci, reached = fetch(branch, cwd) if have_gh else (None, None, None, False)
        # Captured BEFORE the fallback: borrowing the ticket's still-open PR would suppress the vault-note freeze forever.
        own_pr_url = url
        if have_gh and reached and not url:
            # No PR on this branch - show the TICKET's PR rather than an empty row.
            alt_url, alt_approvals, alt_ci = ticket_pr_fallback(key, cwd, entries)
            if alt_url:
                url, approvals, ci = alt_url, alt_approvals, alt_ci
        # Must run BEFORE persist, which clears pr_url to None once the PR leaves the open set.
        if path and data and reached and own_pr_url == "" and data.get("pr_url"):
            enqueue_finish(path, data, cwd)
        if path and (reached or note != (data.get("vault_note") or "")):
            persist(path, data, url, approvals, ci, note)
        if not reached:
            # Offline, or not a GitHub remote: fall back to whatever the thread file already
            # holds rather than blanking a badge because one pass could not reach GitHub.
            approvals = data.get("pr_approvals") if data else None
            ci = data.get("ci_status") if data else None
        pr_glyph, pr_on_glyph, ci_glyph = render(approvals, ci)
        values = {
            JIRA_TOKEN: jira_short(data.get("jira_status") if data else None),
            SB_TOKEN: NOTE_GLYPH if note else "",
            TOKEN: pr_glyph,
            ON_TOKEN: pr_on_glyph,
            CI_TOKEN: ci_glyph,
        }
        report(workspace, indent_first(row3_slots(values, focused), label, ROW3_ORDER), seq)


def clear_all():
    seq = str(time.time_ns())
    for workspace in workspace_cwds():
        report(workspace, blank_tokens(), seq)


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
