# Captain preferences - shared across every firstmate home

This file is read by EVERY firstmate home on this machine, and pushed down to every second mate.

In a home that has second mates, this content is **main-authoritative** in that primary home and **read-only in secondmate homes** - it **must not be edited there**, because the next propagation overwrites it. A preference discovered inside a second mate goes back to the **main firstmate** as a **marked status** line or a **document pointer**, never by editing that copy. Firstmate refuses to propagate a source whose first twelve lines omit that warning, so this paragraph is load-bearing: keep it here, keep it near the top, and copy it with the file.

It is NOT a channel between homes. Nothing here is addressed to a particular home, and no home may put something here aimed at another.

## The admission test - read this before adding anything

Does the rule name a repo, a ticket system, a branch convention, a deploy target, or a workflow that only one domain has?

- **YES** - it stays in that home's own `data/captain.md`.
- **NO, it describes the captain** - it belongs here, and every home obeys all of it.

**Keep this file SHORT.** Propagation needs the captain's own `chezmoi apply`, and that control is only real while the diff stays short enough to read. The default is NOT shared: a rule earns its way in. Nothing enforces this mechanically - the guard is this header, the versioned diff, and the captain's apply.

<!-- rules begin below this line -->

## Never modify a source repo to suit our workflow

Stated 2026-08-10: "never against the source repos like firstmate/web/inferno/etc".

When our tooling collides with a repo we consume, the fix goes in OUR hooks, skills, config or placement - never into that repo. This covers firstmate, web, inferno, and any repo we did not create for this purpose.

**This does NOT restrict ordinary product work.** Shipping a feature or fix through the project's normal delivery path is what the repo is for. The rule is about editing a repo's tooling, config or conventions so OUR workflow fits more comfortably.

Why: those repos are shared or owned by someone else. A change serving one person's pipeline is clutter to every other contributor, and a local patch forks the environment invisibly. A patched firstmate checkout also cannot cleanly take upstream updates - `/updatefirstmate` fast-forwards, so local edits turn every update into a merge.

The test before opening any such PR: *would a contributor who never uses my tooling want this change?* If no, it belongs on our side. Genuine defects are reported upstream and worked around meanwhile, never patched locally.

## Always close a message with a colour-coded status block

End every captain-facing message with the open items, one per line:

- 🔴 anything that needs them: broken, failed, blocked, or waiting on their decision or approval
- 🟡 open or waiting on something external, but nothing they must act on now
- 🟢 done, landed, verified, nothing needed

Three levels, not four - 🟠 was removed on 2026-08-09 because broken, blocked and needs-your-decision are one thing from the captain's side. Do not reintroduce an intermediate colour; order several 🔴 lines so the one that actually blocks is first.

Lead with the strongest colour present. When nothing is open, still close with one 🟢 line - an absent block reads as an oversight, not as "all clear". Use the colours inline when a finding deserves the same weight, but never so often they stop meaning anything.

This is the ONLY closer; an earlier single bold `🔴 NEEDS YOU` rule was retired into it. Never emit both.

Presentation only: it never replaces the escalation rules in `AGENTS.md` section 9. A 🔴 line does not make an unsafe action safe, and a 🟢 line must be an outcome that was actually verified. Emoji is what survives every renderer - never attempt ANSI colour.

## Merge approval belongs to the captain

Every project runs with autonomy off. No home merges its own work and none treats a green pipeline as permission. Report the outcome with the full PR URL and wait.

## Anything visual reaches the captain's desktop, never a localhost URL

The captain works from a MacBook against a headless Linux VPS, so `127.0.0.1` here reaches nothing they can see. Never hand them a loopback URL or an SSH tunnel command.

Expose it tailnet-only with `tailscale serve` - never `funnel` - then push it with `to-desktop open <https-url>`. `~/.local/bin/to-desktop` owns that routing and validates that only http(s) may cross; `desktop-open` is its `$BROWSER`-shaped wrapper. Use `~/Developer/agents/shared/skills/preview/` for a plain static page, and Lavish when the captain should answer or annotate.

**Tear it down when finished** - stop the server AND remove only the routes you added, verifying the captain's own entries survive. Tear down on an explicit end OR on completion of the work the surface existed for, never on silence. If genuinely ambiguous, ask once.

## Building an artifact

**Silk theme, always, no exceptions** - `<html data-theme="silk">`. Never Lavish's `luxury` default, and never a theme because the content "calls for it"; the tool's guidance invites both and is overridden here. Build with semantic tokens so the theme is one attribute. Silk exists only from DaisyUI 5 - on a v4 project, raise it rather than substituting. A hand-rolled page with its own CSS has no `silk` to set: make it light by building it light.

**Reader-relative change markers, keyed on what the READER has seen** - never "what changed in this update", which is fiction because an agent republishes several times per conversation. Per-block `id` and version in one array at the top of the page script, with a `read` flag the agent sets once the captain has seen that round. **There is no browser storage**: the artifact iframe is an opaque origin, so `localStorage`, `sessionStorage` and cookies all throw - the page source is the only durable read-state. Never encode the KIND in colour; give markers their own channel and let a WORD carry it (`ADDED`, `CHANGED`, `REMOVED`). Mark the end element that changed, never a wrapper. Marks DIM, never vanish, and dim the labels only - never the prose. Dwell ~2.5s before counting a block read. Every control works in-page with no reload. A top strip titled "Not read yet" carries a LIVE count that decrements and collapses.

**Four ways a Lavish surface breaks silently:** never open the captain's live session in a browser here (it becomes a second client and their messages start failing with `409`); no Mermaid diagrams (they become a whiteboard rejected cross-origin - same opaque-origin cause as the storage rule - so use plain HTML/CSS or inline SVG); always reply through Lavish's own channel or the captain watches a spinner forever; and **one poll per artifact**, stopped before every reply, because concurrent polls drain feedback destructively and end with the page refusing to render. Match on `/proc/<pid>/cmdline` when stopping one - a `pkill -f` pattern that appears in your own command line kills your own shell.

## Arm the review-comment loop on every PR firstmate opens

Right after `bin/fm-pr-check.sh <id> <pr-url>`, also run `~/Developer/agents/shared/skills/fm-pr-comments/gen-check.sh <id> <pr-number> <owner/repo>`. That replaces the task's watcher check with a stateless review-thread poll.

On the resulting wake, load the `fm-pr-comments` skill - it owns the procedure. Two things never to get wrong: STEER THE EXISTING WORKER rather than spawning anything, and make it rebase onto the moved branch before committing, because bots land base-branch merges while a worktree sits idle. The check is self-clearing and goes silent on a merged PR.

## Second mate status replies use the plain form

Reply on the parent status channel as `<verb>: corr=<id> <note>`.

An interim measure while the shipped `bin/fm-secondmate-report.sh` emits a bracketed form the classifier cannot read, making a mate's blocker invisible to its parent. Retire it once `bin/fm-classify-lib.sh` parses the bracketed form - it is the weakest entry here, passing only by failing the exclusion test rather than describing the captain.
