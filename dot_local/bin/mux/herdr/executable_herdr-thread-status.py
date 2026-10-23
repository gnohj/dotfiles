#!/usr/bin/env python3
"""herdr-thread-status — keep each ticket workspace's thread file current with its PR, CI and vault note.

herdr knows nothing about GitHub, so this poller walks the open workspaces, asks `gh` about the
branch each one is on, and, only where a thread file under ~/.local/state/threads/ unambiguously
owns the workspace, is the WRITER of record for `pr_url` / `ci_status` / `pr_last_checked` /
`vault_note`. One fetcher, no disagreement. ticket-band, sb-ticket-log and the freeze queue read
those fields; nothing here renders in the sidebar any more, since a crewmate's PR number now rides
row 2 from its firstmate meta (herdr-git-status.sh).

Jira is never touched: `jira_status` needs credentials this daemon does not have, so its writer
is the `sb-agent-refresh` skill, supervised by herdr-jira-status.service.

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

Agent HOME workspaces are skipped (AGENT_HOME_RE): the captain's own `fm` sesh session, plus
firstmate's own `firstmate` home and every `2ndmate-<id>` secondmate home. A home sits on a
permanent branch of a read-only checkout, so it has no PR, CI or vault note to record. Their
PROJECTED TASK WORKTREES are not homes - those are the `└ <branch>` children carrying a real
ticket branch. The match is on label SHAPE, never on the sidebar glyph, which is presentation.

Runs wherever the herdr SERVER runs, so under `herdr --remote` it lives on the VPS and reads
that box's thread files and checkouts — the state is per-host and that is correct, since a
VPS workspace's PR belongs to the VPS checkout. Needs `gh` authenticated on whichever host
that is. Stdlib only, no jq (gh embeds its own).

  herdr-thread-status.py           daemon: refresh every $HERDR_THREAD_INTERVAL seconds
  herdr-thread-status.py --once    one pass over every open workspace, then exit
"""
import json
import os
import re
import subprocess
import sys
import time

sys.dont_write_bytecode = True  # no __pycache__ in the deployed scripts dir
sys.path.insert(0, os.path.dirname(os.path.realpath(__file__)))
from herdr_label import is_agent_home  # noqa: E402  (needs the path above)

SOCK = os.environ.get("HERDR_SOCKET_PATH") or os.path.expanduser("~/.config/herdr/herdr.sock")
HERDR = os.environ.get("HERDR_BIN_PATH", "herdr")
# Minutes, not seconds: every pass is a network call per workspace against a rate limit.
INTERVAL = int(os.environ.get("HERDR_THREAD_INTERVAL", "180"))
# A `…/review` checkout is a POOL reused across PRs, so thread_for() matches on worktree and keeps labelling it with a long-shipped ticket.
REVIEW_POOL_LEAF = "review"
THREADS_DIR = os.path.join(
    os.environ.get("XDG_STATE_HOME") or os.path.expanduser("~/.local/state"), "threads"
)
# Shared with wtrm's deferral path: both drop a thread-file copy here for herdr-sb-drain to freeze.
FINISH_QUEUE = os.path.join(
    os.environ.get("XDG_STATE_HOME") or os.path.expanduser("~/.local/state"),
    "sb-ticket-finish-pending",
)
# Same ticket-key shape wt-setup matches, so both writers agree on the id.
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
# wt-setup derives tmux_session by stripping this prefix; mirrored so the two agree.
DEV_PREFIX = os.path.expanduser("~/Developer") + "/"

# Absolute path: a herdr daemon's PATH is whatever the server was launched with.
VAULT_NOTE = os.path.expanduser("~/.local/bin/vault-note")

# Newest open PR -> "<url>\t<ci state>", or "" for none.
PR_JQ = (
    '.[0] | if . == null then "" else .url + "\\t" '
    '+ ((.statusCheckRollup // []) | if length == 0 then "" '
    'elif map(select(.status == "IN_PROGRESS" or .status == "QUEUED" '
    'or .state == "PENDING")) | length > 0 then "running" '
    'elif map(select(.conclusion == "FAILURE" or .conclusion == "TIMED_OUT" '
    'or .conclusion == "CANCELLED" or .state == "FAILURE" or .state == "ERROR")) '
    '| length > 0 then "failure" else "success" end) end'
)


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
    the PR this records. herdr-git-status.sh picks its baseline the same way.
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
            # Case-insensitive: task id and branch need not agree on the ticket's case.
            if short.lower() == task.lower() or short.lower().endswith("/" + task.lower()):
                return path, short
    return None, None


def detached_branch(cwd, label):
    """The branch a detached HEAD sits on (firstmate crewmates check out their PR tip detached), preferring the task's own."""
    def refs(match):
        names = []
        for prefix, strip in (("refs/heads", 2), ("refs/remotes", 3)):
            raw = out(["git", "-C", cwd, "for-each-ref", match, "HEAD",
                       "--format=%(refname:lstrip=" + str(strip) + ")", prefix], timeout=4) or ""
            names += [n for n in raw.splitlines() if n and n != "HEAD" and n not in names]
        return names

    key = ticket_key(label)
    names = refs("--points-at")
    if names:
        return next((n for n in names if key and ticket_key(n) == key), names[0])
    # The PR branch moved past this checkout; only the task's own branch counts, or master would claim every merged HEAD.
    return next((n for n in refs("--contains") if key and ticket_key(n) == key), "")


def workspace_labels():
    """workspace_id -> label, which decides agent homes and names a fleet task's own branch."""
    raw = out([HERDR, "workspace", "list"], timeout=6)
    if not raw:
        return {}
    try:
        spaces = json.loads(raw).get("result", {}).get("workspaces", [])
    except ValueError:
        return {}
    return {w.get("workspace_id"): w.get("label") or "" for w in spaces if w.get("workspace_id")}


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
    `…/web-130256/1/web` carried IHRWEB-12344 until it merged, then got re-checked-out onto an
    unrelated backport branch, and nothing deletes the thread file unless the worktree is torn
    down through wtrm. The path alone therefore stayed a unique hit and handed the new branch
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

    wt-setup is the original writer, but it only runs for a
    worktree born through wt-add. herdr's built-in new_worktree, lazygit's worktree UI and a
    bare `git worktree add` all produce a checkout with no thread file, leaving jira_status and
    the cached PR fields blank forever — so this reconciles from the workspace list the poller
    already walks instead of relying on the creation moment.

    Ticket-shaped branches only: an untracked branch has no Jira ticket anyway, so a file for it
    would just add a `branch` collision to thread_for(). Schema and the skip-if-exists rule are
    copied from wt-setup so the two writers cannot disagree, and O_EXCL makes losing a
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
            continue  # taken by us on a past pass, by wt-setup, or by a sibling branch
        except OSError:
            return None, None
        return candidate, data
    return None, None


def fetch(branch, worktree):
    """(pr_url, ci_status, reached) from one gh call; None where it gave nothing."""
    pr = out(
        ["gh", "pr", "list", "--head", branch, "--state", "open",
         "--json", "url,statusCheckRollup", "--jq", PR_JQ],
        cwd=worktree,
    )
    if pr is None:
        return None, None, False
    if not pr:
        # "" = checked, no open PR (distinct from "not checked"), and no PR means no CI to show.
        return "", "", True
    parts = pr.split("\t")
    return parts[0] or None, parts[1] if len(parts) > 1 else "", True


def ticket_pr_fallback(key, worktree, entries):
    """(pr_url, ci_status) for the TICKET when this branch has no PR of its own.

    Several branches can feed one ticket's single PR - the three IHRWEB-12345 workspaces all
    contribute to one, and none of them carries a PR itself, so their records stayed empty while
    the ticket's PR sat there with real CI state. The ticket is what the workspace is about, so
    the ticket's PR is the honest thing to record.

    Only ever a FALLBACK: a branch with its own PR keeps reporting that one, never the ticket's.
    """
    if not key:
        return None, None
    url = next((d.get("pr_url") for _, d in entries
                if d.get("id") == key and d.get("pr_url")), None)
    if not url:
        return None, None
    # PR_JQ starts at `.[0]` for `gh pr list`'s array, so `gh pr view`'s single object is wrapped rather than the filter duplicated.
    raw = out(["gh", "pr", "view", url, "--json",
               "url,statusCheckRollup", "--jq", "[.] | " + PR_JQ], cwd=worktree)
    if not raw:
        return None, None
    parts = raw.split("\t")
    return parts[0] or None, parts[1] if len(parts) > 1 else ""


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


def persist(path, data, url, ci, note):
    """Atomic write-back of the status fields. tmp+rename so no reader sees half."""
    data.pop("pr_approvals", None)
    if url is not None:
        data["pr_url"] = url or None
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


def vault_note(cwd):
    """Vault-relative path of this workspace's ticket note, or "" — the lookup is vault-note's."""
    return out([VAULT_NOTE, "--relative", cwd], timeout=6) or ""


def refresh_once():
    """One pass: fetch per workspace, persist only where a thread file owns that workspace.

    A ticket workspace with no file gets one created here (see create_thread), so the "never
    written" case self-heals on the next pass instead of staying blank forever.
    """
    # No gh skips only the PR half: the vault note is a local lookup and still persists.
    have_gh = bool(out(["gh", "--version"], timeout=5))
    entries = thread_files()
    labels = workspace_labels()
    for workspace, cwd in workspace_cwds().items():
        label = labels.get(workspace, "")
        if is_agent_home(label) or os.path.basename(cwd.rstrip("/")) == REVIEW_POOL_LEAF:
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
            branch = detached_branch(cwd, label)
        if not branch:
            continue
        # A branch can carry no ticket at all (`fm/pr19552-increment`); the workspace label is the last source before giving up.
        key = ticket_key(branch) or ticket_key(label)
        path, data = thread_for(cwd, branch, entries)
        if not path:
            # No match can also mean AMBIGUOUS, which is why create_thread() skips an existing filename.
            path, data = create_thread(cwd, branch)
            if path:
                entries.append((path, data))
        if not path:
            continue
        note = vault_note(cwd)
        url, ci, reached = fetch(branch, cwd) if have_gh else (None, None, False)
        # Captured BEFORE the fallback: borrowing the ticket's still-open PR would suppress the vault-note freeze forever.
        own_pr_url = url
        if reached and not url:
            # No PR on this branch - record the TICKET's PR rather than none.
            alt_url, alt_ci = ticket_pr_fallback(key, cwd, entries)
            if alt_url:
                url, ci = alt_url, alt_ci
        # Must run BEFORE persist, which clears pr_url to None once the PR leaves the open set.
        if reached and own_pr_url == "" and data.get("pr_url"):
            enqueue_finish(path, data, cwd)
        if reached or note != (data.get("vault_note") or ""):
            persist(path, data, url, ci, note)


def main():
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
