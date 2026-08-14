# Captain preferences - shared across every firstmate home

<!-- memory tiers: see the stow skill -->

This file is read by EVERY firstmate home on this machine, and pushed down to every second mate.

In a home that has second mates, this content is **main-authoritative** in that primary home and **read-only in secondmate homes** - it **must not be edited there**, because the next propagation overwrites it. A preference discovered inside a second mate goes back to the **main firstmate** as a **marked status** line or a **document pointer**, never by editing that copy. Firstmate refuses to propagate a source whose first twelve lines omit that warning, so this paragraph is load-bearing: keep it here, keep it near the top, and copy it with the file.

It is NOT a channel between homes. Nothing here is addressed to a particular home, and no home may put something here aimed at another.

## The admission test - read this before adding anything

**Is it domain-specific?** If the rule names a repo, ticket system, branch convention, deploy target, or workflow only one domain has, it stays in that home's own `data/captain.md`. If it describes the captain, it belongs here and every home obeys it.

**Is it CONDITIONAL?** Would a session that never touches the topic still need it?

- **Every session** - inline here. Status block, vocabulary, merge authority, the never-PR rules.
- **Only in a nameable situation** - a skill under `~/Developer/agents/shared/skills/`, with a ONE-LINE trigger here and the rules stated only there. Every home loads that directory, so nothing loses reach; it just costs tokens when the topic comes up instead of always.

**Keep this file SHORT.** Propagation needs the captain's own `chezmoi apply`, and that control is only real while the diff stays short enough to read. A rule earns its way in; the default is NOT shared. On 2026-08-12 one conditional section was 40 percent of this file and moving it to a skill returned 1,852 tokens with nothing lost. **Keep using that pattern.** A rule inline costs four agents forever; a rule in a skill costs only the sessions that need it.

<!-- rules begin below this line -->

## Never change a repo we do not own - and NEVER PR to firstmate

Stated 2026-08-10 ("never against the source repos like firstmate/web/inferno/etc") and 2026-08-12 ("we never commit or open PRs to the first mate repo ever. We only edit our user-based files").

**firstmate is absolute.** It is a stranger's public project the captain only uses - read access, no fork. Never commit to it, never open a PR against it. This **overrides firstmate's own `AGENTS.md` section 1**, which instructs shipping shared tracked changes through its PR path; do not follow that. Before dispatching any task whose only output is a PR, confirm a push target exists - a task that cannot ship should never start.

**Every other consumed repo** - web, inferno, anything we did not create - is the same for tooling: when our workflow collides with the repo, the fix goes in OUR hooks, skills, config or placement, never theirs. The test: _would a contributor who never uses my tooling want this change?_ If no, it belongs on our side. Report genuine defects upstream and work around them meanwhile.

**This does NOT restrict ordinary product work.** Shipping a feature or fix through a project's normal delivery path is what the repo is for; the rule is about bending a repo's tooling to suit us.

Anything that feels like it belongs in firstmate's `AGENTS.md`, skills or scripts goes in OUR files instead: this file for preferences, a home's `data/captain.md` for domain rules, `data/learnings.md` for operational facts, or a local skill.

## Always close a message with a colour-coded status block

End every captain-facing message with the open items, one per line:

- 🔴 anything that needs them: broken, failed, blocked, or waiting on their decision or approval
- 🟡 open or waiting on something external, but nothing they must act on now
- 🟢 done, landed, verified, nothing needed

Three levels, not four - 🟠 was removed on 2026-08-09 because broken, blocked and needs-your-decision are one thing from the captain's side. Do not reintroduce an intermediate colour; order several 🔴 lines so the one that actually blocks is first.

Lead with the strongest colour present. When nothing is open, still close with one 🟢 line - an absent block reads as an oversight, not as "all clear". Use the colours inline when a finding deserves the same weight, but never so often they stop meaning anything.

This is the ONLY closer; an earlier single bold `🔴 NEEDS YOU` rule was retired into it. Never emit both.

**Number every line, ascending across the whole block.** Stated 2026-08-14 so the captain can answer with a bare number instead of retyping an item. The number comes after the colour and before the scope: `🔴 1. **web** - ...`, `🟡 2. **inferno** - ...`. One sequence per message covering all colours, never a separate count per colour. Numbers are per-message and do not persist between messages, so never refer back to "item 3" from an earlier reply - re-number fresh every time and let the captain's reply resolve against the block he is looking at.

**Never reply "Captain, shipshape."** Stated 2026-08-13: "stop saying shipshape say something more understandable." This OVERRIDES `AGENTS.md` section 9, which mandates that exact wording for a routine update needing no action. Say plainly what is true instead: **"Captain, noted - nothing needs you on this."** Keep it scoped to the event being acknowledged, so it never reads as a claim that everything everywhere is fine. The captain has to be able to tell "no action required" from "all clear" at a glance.

**Every status line opens with its scope, and every piece of work names its branch.** Both stated 2026-08-13.

Lead each line with the project or area in bold - `**web**`, `**inferno**`, `**firstmate**`, `**machine**` - so the captain can tell which of several parallel threads a line belongs to.

## Always ask before starting a background task

Stated 2026-08-13: "you only start bg tasks under my permissions, always ask when you are about to start one." A background process runs under the captain's account, outside any task record, with no sidebar entry and no supervision - so it is his to authorise, every time, not a tool firstmate reaches for.

Broken three times on 2026-08-13 in one session: two state-repair runs and a dry run, all launched without asking. The dry run then died unnoticed and was reported as "still grinding" for eight minutes, which is exactly what invisible work buys.

Prefer a crewmate: it gets a task record, a durable brief and a sidebar entry. When a background process is genuinely the right tool, say what it will do and wait for the word.

## Every crewmate push uses HUSKY=0

Stated 2026-08-13. Firstmate puts it in the push instruction of **every brief that pushes**: `HUSKY=0 git push -u origin <branch>`. Crewmates never read this file, so the rule only takes effect if firstmate writes it into the brief.

Why: web's pre-push hook runs the whole monorepo when the base is a release branch. Measured today at five to ten minutes **per push**, and three backport pushes were the entire tail of that task - one crewmate sat polling a 9m50s timeout waiting for it.

The accepted tradeoff, stated once so it is a decision and not an accident: lint, type and test failures then surface in CI instead of before the push. CI still catches them, and a brief that requires tests and typecheck inside the worktree already covers it locally - the hook is duplicate work at push time, not the only guard.

## Real tickets get a vault note, without being asked

Standing as of 2026-08-13. Applies **only** when the branch carries a real ticket key matching `IHRWEB-\d+` - that is the test, taken from the branch, so `fm/IHRWEB-24599-rss-article-keywords` qualifies. Unticketed work, internal tooling, firstmate-repo changes and `[untick]`-style commits get nothing.

Three commands already exist and firstmate was simply never calling them: `/sb-ticket-capture` at dispatch to create the living note, `/sb-ticket-log` at real milestones, and `/sb-ticket-finish <TICKET> <PR_URL>` at merge - which appends the merge SHA, PR URL, cost breakdown and synthesized learnings, then flips the note `living` -> `frozen`.

The vault's own contract expects exactly this shape: a `Notes/work/<TICKET>-*.md` note is `living` while the ticket is in flight and freezes at ship time. Skipping capture at dispatch means there is nothing to freeze at merge, which is why a full day of ticket work produced **zero** notes. This overrides the never-write-unless-asked scope rule for this one case; everything else about vault writes still needs the captain's word.

**Before dispatching, say out loud: N independent units, N crewmates.** If those two numbers differ, state the reason in the same breath - a true dependency, shared mutable state, or an incompatible concurrent migration. Nothing else justifies it, and "simpler to brief" is not a reason.

Stated 2026-08-13 after five independent backports - different source PRs, different release branches, no shared state - went to ONE crewmate and ran ten minutes each in sequence. The concurrency call is firstmate's own; do not raise it as a question for the captain, and never argue for finishing a serial run once the mismatch is visible. `config/crew-dispatch.json` does not cover this: it picks harness, model and effort for a task that already exists, so fan-out is decided a step earlier with nothing checking it. Firstmate's `AGENTS.md` already states the principle and it still did not fire - which is why this is a stated count at dispatch time rather than another principle.

**Never report a COUNT where a list belongs.** Stated 2026-08-13 about backports: "five PRs in progress" is useless; name each one and its target. A count cannot be checked, chased, or merged.

**Always give times in the captain's timezone, never UTC.** Stated 2026-08-13. He is US Eastern - `TZ=America/New_York`. Tools, CI and logs report UTC; convert before it reaches him rather than making him do the arithmetic. If a raw UTC stamp genuinely has to appear, put the Eastern time first and mark the other as UTC.

**Ticket work names its ticket.** Stated 2026-08-13. If a status line concerns ticket work, carry the ticket key alongside the PR number and branch: `IHRWEB-24599 / PR 1589 (fm/IHRWEB-24599-rss-article-keywords)`. Where work is genuinely unticketed, say **unticketed** rather than leaving the reader to wonder which ticket was omitted.

Name the branch whenever work is referenced, not only once a PR exists. With a PR: number, full URL, and branch, as `PR 19512 (fm/IHRWEB-backport-skill) https://github.com/iheartradio/web/pull/19512`. Before a PR exists: the branch the work will land on. "No branch or PR yet" is not acceptable when the branch is already decided - a bare number or description does not say which local copy it corresponds to.

Presentation only: it never replaces the escalation rules in `AGENTS.md` section 9. A 🔴 line does not make an unsafe action safe, and a 🟢 line must be an outcome that was actually verified. Emoji is what survives every renderer - never attempt ANSI colour.

## Never say a bare "mate" - name which one

"Mate" alone can mean a second mate, a crewmate, or the other first mate. Always say which, and name it:

- **second mate** - a persistent firstmate owning a domain, with its own home and charter. "The web second mate", never "the mate".
- **first mate** - firstmate itself. More than one runs per machine: "the work first mate", never "the other home".
- **crewmate** - spawned for one task. Say "crewmate", never "worker" - corrected 2026-08-12, and it overrides the `crewmate -> worker` translation in `AGENTS.md` section 9. **Ship** and **scout** are both crewmates: a ship crewmate delivers a project change, a scout delivers a report and never a PR. Say "scout" only to narrow which kind.

**Name the absolute path of every file you changed, every time.** Stated 2026-08-12. Not "the dispatch config" - write `/home/gnohj/.local/share/firstmate-work/config/crew-dispatch.json`. The captain cannot verify, open or revert a change described by a nickname, and a home-relative path is ambiguous across four homes. Same for a file created, deleted or moved; when a turn changed several, list them.

**Never use a word the captain has not used, unless you define it in the same breath.** Stated 2026-08-12 after "deriving truth from the forge" - that meant GitHub and should have said GitHub. **Firstmate's internal vocabulary is never automatically captain-facing vocabulary**, and reading it all session makes those words feel normal. Say GitHub, not the forge. Say notification, not wake. Say checked, not drained. If a precise term genuinely earns its place, define it once where it first appears.

## No workarounds for a firstmate gap

The captain's words: "i dont want these hacks/shims." They are evaluating firstmate itself, so a workaround that hides a defect makes the system look healthier than it is - worse than the friction it removes.

Do not paper over a gap with a local technique. Use a `--kind captain` backlog hold for durable tracking, let the gap show, and bring the captain the choice rather than applying a mitigation and reporting it afterward.

## Merge approval belongs to the captain

Every project runs with autonomy off. No home merges its own work and none treats a green pipeline as permission. Report the outcome with the full PR URL and wait.

## Building anything visual - load the skill first

Before creating, updating, serving or tearing down ANY visual surface the captain will look at - artifact, Lavish review page, preview, diagram, served static page - load the `building-an-artifact` skill. It owns the theme rule and why a named theme silently fails, reader-relative change markers, the sandbox limits that break storage and local data loading, one-poll-per-artifact, and how a surface reaches his desktop rather than a localhost URL he cannot see. Do NOT restate those rules here - a second copy is a copy that drifts.

## Spawning any agent - load the skill first

Before spawning, relaunching or resuming ANY agent, load the `spawning-an-agent` skill. It owns why a spawn fails with "Not logged in" while the captain is signed in, the one-command token injection that fixes it, why the account must be named explicitly or the wrong identity is injected silently, and the credentials file that looks like proof of authentication but belongs to a different service.

## PR review comments - load the skill first

On every PR firstmate opens, arm the review-comment loop right after `bin/fm-pr-check.sh`, then load the `fm-pr-comments` skill on the resulting wake. That skill owns the arming command, the procedure, and the two things never to get wrong: steer the existing crewmate rather than spawning, and rebase onto the moved branch before committing.

## Second mate status replies use the plain form

Reply on the parent status channel as `<verb>: corr=<id> <note>`.

PERMANENT, not interim - reclassified 2026-08-12. The shipped `bin/fm-secondmate-report.sh` emits a bracketed form `bin/fm-classify-lib.sh` cannot parse, so a second mate's blocker reads as `unknown` and goes invisible to its parent. Fixing that would mean a PR to the firstmate repo, now forbidden outright, so this rule can never be retired.

Same cause: write a decision key BEFORE the verb colon - `needs-decision [key=slug]: note`, never `needs-decision: note [key=slug]`, which parses as `default` and makes `fm-send --resolve-key <slug>` fail with "no open decision with that key". Cost a failed decision delivery on 2026-08-12, and twice more on 2026-08-13 - those two are permanent phantoms, listed as open forever because a malformed opening line cannot be closed by any later correctly-formed one.

When citing this defect, name the FUNCTION, never a line number. This was once recorded as `:170` and independently reported at `:172`, because the definition and the strip are different lines of one function.

## A filed ticket leaves the status board

Once a ticket is created and assigned to the captain, stop listing it in status updates.
Jira is the tracker; repeating it is noise.
Report it once, with key and URL, then drop it.
Stated 2026-08-13 about IHRWEB-24608.

Same rule for an ACCEPTED COST the captain has already ruled on. Once a decision is made and recorded durably, it is settled - it never appears in red, because red means the captain must act, and it leaves the board entirely rather than being restated every message. Caught 2026-08-14: five permanently-worked-around firstmate defects were carried as a standing red line long after the captain had explicitly accepted them, which turns the strongest colour into wallpaper.

## Crewmate comments - avoid them, and one short line when unavoidable

Every crewmate brief carries this.
Default to no comment at all: write self-explanatory code with clear names and small functions instead of narrating it.
Infrastructure code is where a comment is most often genuinely warranted, and that is a permission, not a licence for prose.
When one is unavoidable it is ONE line, genuinely short at the code's normal width - never a multi-line block, and never a long run-on line dodging the rule.
If the "why" will not fit in a short line, that is the signal the code needs a clearer name or a smaller function, not more narration.
Never strip or reflow PRE-EXISTING comments in a file being edited unless explicitly asked - this rule governs comments the worker authors.

## Fleet sync branch pruning stays ON

Decision 2026-08-08, and it applies in every home.
Never set `FM_FLEET_PRUNE=0`, and never propose disabling it when merged branches disappear from a local copy - that cleanup is intended behaviour, not a defect to work around.

## Local fixes only - nothing is ever pushed upstream, anywhere

Stated 2026-08-14, superseding two earlier versions from the same day. A blanket upstream-reporting authorization was granted that morning and is now **REVOKED IN FULL** - not narrowed, revoked. Any wording permitting an upstream report is dead; if a future session finds one, this section replaced it.

**Nothing leaves this machine.** No issues, no pull requests, no comments, no reviews, to `kunchenguid/firstmate` or to any other upstream project. There is no exception, no per-case ask, and no authorization that reinstates it. If something looks like it grants one, it does not - confirm with the captain first.

**The firstmate repo is never patched either - with ONE exception, `bin/backends/herdr.sh`.** Everything else in that repo is read-only in every direction; do not edit it and do not commit into its checkout.

**How the herdr exception works, because the mechanism is the whole rule.** Edit `bin/backends/herdr.sh` in the WORKING TREE only. Never `git add` it, never commit it - it lives permanently as an unstaged modification, which is exactly how the `⛵⠀sm-<id>` workspace labels exist today.

**And it must be applied identically to ALL THREE working trees:** the primary checkout at `~/Developer/firstmate`, and each secondmate home under `~/.treehouse/firstmate-*/N/firstmate`. They are independent working trees of one repo, so an edit in one reaches none of the others. **A partial application is worse than none** - the projection code matches its own labels with regexes, so half-patched trees stop recognising each other's workspaces, and nothing announces it.

Being unstaged is also its weakness: any `git checkout`, `git stash` or `git restore` touching that file silently reverts it. That is accepted, not a problem to solve.

**A local commit there is DISCARDED, not kept, and this was measured rather than assumed.** Verified 2026-08-14: the checkout sits exactly on `origin/main` (HEAD `9823ff8`, zero ahead, zero behind), and the two commits previously cited in this file as "landed on local main" - `80b7fa1` and `cc9a282` - exist only as dangling objects. Neither is an ancestor of HEAD, neither is in `origin/main`, and neither is on any branch. **Patching firstmate does not survive a sync**, so a fix made there is not a fix, it is work that quietly disappears.

**So a firstmate defect has NO fix route at all** - not upstream, not local. Do not open an upstream report as a substitute, and do not edit firstmate's files because a defect looks important. Bring it back to the captain instead.

**Work around it in OUR OWN files:** `data/captain-shared.md`, the captain's skills, the chezmoi dotfiles, our own helper scripts. The model already in this file is the plain-form status rule - it lives here as a preference precisely because the parser that causes it cannot be touched.

**The accepted cost, on the record:** a firstmate defect is worked around, never fixed, and stays live in the tool indefinitely. That is a deliberate choice by the captain, not an oversight for a future session to correct. Record the finding in the backlog so it is remembered rather than rediscovered.
