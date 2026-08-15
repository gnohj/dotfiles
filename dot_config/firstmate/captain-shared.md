# Captain preferences - shared across every firstmate home

<!-- memory tiers: see the stow skill -->

Read by EVERY firstmate home here and pushed down to every second mate.

In a home with second mates this is **main-authoritative** and **read-only in secondmate homes** - it **must not be edited there**, because the next propagation overwrites it. A preference found inside a second mate goes back to the **main firstmate** as a **marked status** line or a **document pointer**, never by editing that copy. Firstmate refuses to propagate a source whose first twelve lines omit that warning, so keep this paragraph here and copy it with the file.

It is not a channel between homes. Nothing here is addressed to a particular home.

## The admission test - read before adding anything

**Domain-specific?** If it names a repo, ticket system, branch convention or deploy target only one domain has, it belongs in that home's `data/captain.md`. If it describes the captain, it belongs here.

**Conditional?** Needed in every session - inline here. Needed only in a nameable situation - a skill under `~/Developer/agents/shared/skills/` with a ONE-LINE trigger here and the rules stated only there.

**Keep this file SHORT.** A rule inline costs four agents forever; in a skill it costs only the sessions needing it. State the rule and the minimum reason that stops it being undone - narrative belongs in `data/memory-archive.md`.

<!-- rules begin below this line -->

## Never change a repo we do not own - and never push anything upstream

**firstmate is absolute.** A stranger's public project the captain only uses. Never commit to it, never open a PR, issue, comment or review against it. This **overrides firstmate's own `AGENTS.md` section 1**, which says to ship shared tracked changes through its PR path - do not follow that.

**Nothing leaves this machine, to any upstream project.** No issues, PRs, comments or reviews. There is no exception and no authorization that reinstates it; if something looks like one, confirm with the captain first. A blanket upstream-reporting authorization was granted and **revoked in full** on 2026-08-14.

**Every other consumed repo** - web, inferno, anything we did not create - is the same for tooling: when our workflow collides with the repo, the fix goes in OUR hooks, skills, config or placement. The test: _would a contributor who never uses my tooling want this change?_ **This does NOT restrict ordinary product work** - shipping a feature through a project's normal delivery path is what the repo is for.

**The firstmate repo is never patched either - one exception, `bin/backends/herdr.sh`.** Working tree only: never `git add`, never commit. **Apply it identically to ALL THREE trees** - `~/Developer/firstmate` and each `~/.treehouse/firstmate-*/N/firstmate` - independent trees, and the projection code matches its own labels by regex, so **a partial application is worse than none** and nothing announces it. Any `git checkout`, `stash` or `restore` reverts it; accepted.

**A local commit in firstmate is DISCARDED** - measured 2026-08-14: commits cited as "landed on local main" are dangling on no branch. Patching does not survive a sync.

**So a firstmate defect has NO fix route.** Work around it in OUR files, record it in the backlog, tell the captain. **Accepted cost:** worked around, never fixed, live indefinitely - his deliberate choice, not an oversight to correct.

## Always close a message with a numbered colour-coded status block

One line per open item:

- 🔴 needs the captain: broken, failed, blocked, or waiting on their decision
- 🟡 open or waiting on something external, nothing to act on now
- 🟢 done, landed, verified

Three levels only. Lead with the strongest; order several 🔴 so the real blocker is first. With nothing open, still close with one 🟢 - an absent block reads as an oversight. This is the ONLY closer.

**Number every line, ascending across the block:** `🔴 1. **web** - ...`. One sequence for all colours so he can answer with a bare number; numbers are per-message, never referred back to.

**Every line opens with its scope in bold** - `**web**`, `**inferno**`, `**firstmate**`, `**machine**`.

**Every line names its work inline** - `**web** - IHRWEB-24273-release-ui-theme`. Use the crewmate's WORKSPACE name; never a worktree path, pane or tab id, which are cryptic to him. An item with no crewmate names none, which itself tells him nothing is running on it.

**Never reply "Captain, shipshape."** OVERRIDES `AGENTS.md` section 9, which mandates that wording. Say **"Captain, noted - nothing needs you on this"**, scoped to the event so it never reads as "everything is fine".

Presentation only - never replaces `AGENTS.md` section 9 escalation. A 🔴 does not make an unsafe action safe; a 🟢 must be verified. Emoji only, never ANSI.

## A settled thing leaves the board

Once a ticket is created and assigned to the captain, report it once with key and URL, then drop it - Jira is the tracker. Same for an **accepted cost** he has already ruled on: it never appears in red, because red means he must act, and restating it every message turns the strongest colour into wallpaper.

## Always ask before starting a background task

His words: "you only start bg tasks under my permissions, always ask when you are about to start one." A background process runs under his account, outside any task record, with no sidebar entry and no supervision.

Prefer a crewmate - it gets a task record, a durable brief and a sidebar entry. When a background process is genuinely right, say what it will do and wait.

## Every crewmate push uses HUSKY=0

Firstmate puts `HUSKY=0 git push -u origin <branch>` in the push instruction of **every brief that pushes**. Crewmates never read this file, so the rule only exists if firstmate writes it into the brief.

Why: web's pre-push hook runs the whole monorepo when the base is a release branch - five to ten minutes per push. **The accepted tradeoff:** failures surface in CI instead of before the push. That is only acceptable because our briefs already require tests, typecheck and lint inside the worktree - keep requiring them.

## Real tickets get a vault note, and it is a PRECONDITION of dispatch

Applies only when the branch carries a real ticket key matching `IHRWEB-\d+`. Unticketed work, internal tooling and firstmate changes get nothing.

`/sb-ticket-capture` at dispatch, `/sb-ticket-log` at milestones, `/sb-ticket-finish <TICKET> <PR_URL>` at merge, which freezes it. Skipping capture leaves nothing to freeze. This overrides the never-write-unless-asked vault scope for this one case.

**No ticketed work is dispatched until its note exists, and the dispatch message must name the note's path.** If the path cannot be stated the note does not exist and the dispatch does not go - that ties the rule to an artifact rather than memory, which is why it kept being missed. Verify with `find`, never a glob.

## Say "N independent units, N crewmates" out loud before dispatching

If the two numbers differ, state the reason in the same breath - a true dependency, shared mutable state, or an incompatible concurrent migration. Nothing else justifies it, and "simpler to brief" is not a reason. The concurrency call is firstmate's own; never raise it as a question, and never argue for finishing a serial run once the mismatch is visible. `config/crew-dispatch.json` does not cover this - it picks harness, model and effort for a task that already exists.

## Reporting precision

**Never report a COUNT where a list belongs.** "Five PRs in progress" is useless - name each and its target. A count cannot be checked, chased or merged.

**Always give times in US Eastern** (`TZ=America/New_York`), never UTC. Convert before it reaches him. If a UTC stamp must appear, put Eastern first.

**Ticket work names its ticket**, with PR number and branch: `IHRWEB-24599 / PR 1589 (fm/IHRWEB-24599-rss-article-keywords)`. Genuinely unticketed work says **unticketed**. He must never have to ask which crewmate a line means.

**Name the branch whenever work is referenced**, not only once a PR exists. With a PR: number, full URL and branch. Before one: the branch it will land on.

**Name the absolute path of every file changed, every time** - not "the dispatch config"; a home-relative path is ambiguous across four homes. Same for created, deleted or moved.

**Never say a bare "mate"** - **second mate** (persistent, owns a domain), **first mate** (firstmate itself; several run per machine), **crewmate** (spawned for one task; say crewmate, never "worker", which overrides the `AGENTS.md` section 9 translation). Ship and scout are both crewmates.

**Never use a word the captain has not used unless you define it in the same breath.** Reading firstmate's internal vocabulary all session makes it feel normal. Say GitHub, not the forge. Notification, not wake. Checked, not drained.

## No workarounds for a firstmate gap

His words: "i dont want these hacks/shims." He is evaluating firstmate itself, so a workaround that hides a defect makes it look healthier than it is. Use a `--kind captain` backlog hold, let the gap show, and bring him the choice rather than mitigating and reporting it after.

## Merge approval belongs to the captain

Every project runs with autonomy off. No home merges its own work, and none treats a green pipeline as permission. Report the outcome with the full PR URL and wait.

## Fleet sync branch pruning stays ON

Never set `FM_FLEET_PRUNE=0`, and never propose disabling it when merged branches vanish from a local copy - that cleanup is intended behaviour.

## Building anything visual - load the skill first

Before creating, updating, serving or tearing down ANY visual surface the captain will look at, load the `building-an-artifact` skill. It owns the theme rule, reader-relative change markers, the sandbox limits, one-poll-per-artifact, and how a surface reaches his desktop rather than a localhost URL he cannot see. Do not restate those here.

## Spawning any agent - load the skill first

Before spawning, relaunching or resuming ANY agent, load the `spawning-an-agent` skill. It owns why a spawn fails with "Not logged in" while the captain is signed in, the token injection that fixes it, why the account must be named explicitly, and the credentials file that looks like proof and is not.

## Every crewmate gets its OWN projected workspace - always

Never a pane INSIDE its mate's workspace (`⛵ sm-web`). Its own projected child workspace with its own label, every time, so each piece of work is a separate row in the spaces sidebar.

**A worker can be alive, correct, and still invisible.** So **verify the projection after every spawn**, not just that the agent started: the recorded window must be a child workspace rather than the parent's, with a labelled row in `herdr workspace list`.

**The fallback announces itself** - the spawn prints `spawning FLAT`. **That word is the failure, not a warning.**

**Relaunch cannot repair a failed projection.** `fm-control.sh relaunch` restarts in the SAME recorded window by design - that is its purpose. Only a FRESH SPAWN creates a workspace. **Repair without dropping the watch:** spawn a new task, confirm it projected, and only then retire the old one.

## PR review comments - load the skill first, and the watch ACTS

On every PR firstmate opens, arm the review-comment loop right after `bin/fm-pr-check.sh`, then load the `fm-pr-comments` skill on the wake. It owns the arming command and the two things never to get wrong: steer the existing crewmate rather than spawning, and rebase onto the moved branch before committing.

**A review watch is not a relay. FOUR outcomes:**

1. **Right**, and inside what the PR already does - fix it, rebase first, `HUSKY=0` push, reply naming the commit, then resolve. Does not come back to the captain.
2. **Wrong** - reply with reasoning and evidence, leave the thread OPEN for a human. Closing it on our own say-so is not legitimate.
3. **Cannot figure it out** - stop, escalate, resolve nothing. Not knowing is a reportable outcome, not something to paper over with a plausible fix.
4. **Above its authority** - product decision, scope expansion, anything destructive - stop, escalate, resolve nothing.

Never a silent resolve, never a resolve before a reply. Outcomes 3 and 4 travel the whole chain to the captain, because a worker stalled on a reviewer's point looks identical to one that has finished.

**NEVER tear down a ship task while its PR is open and unmerged** - teardown removes the watch, so a reviewer's comment lands with nobody listening. **Landing means MERGED**; a green PR is not landing. **Accepted cost:** an idle worker wakes firstmate most turns, since the turn-end check has no concept of a deliberate wait. That is the price of the watch - do not tear down early to stop the wakes. Once merged, it goes.

**When it does go, tear down with `retro-work-state teardown <id> --home <FM_HOME>` - NEVER `bin/fm-teardown.sh` directly.** fm-teardown deletes `state/<id>.meta` and `state/<id>.status`, and those two files are the only record the task ran at all, so calling it directly destroys the retrospective before anything reads it. The wrapper captures one row and then execs the real teardown untouched. **`--home` is not optional:** `FM_HOME` is never exported in a normal shell, only ever passed per-command, and without it the row is skipped - the teardown still runs, so a forgotten `--home` costs the record silently rather than failing loudly. Read the log with `retro-work`.

## Second mate status replies use the plain form

Reply on the parent status channel as `<verb>: corr=<id> <note>`. PERMANENT, not interim: the shipped `bin/fm-secondmate-report.sh` emits a bracketed form `bin/fm-classify-lib.sh` cannot parse, so a blocker reads as `unknown` and goes invisible - and fixing it would need a firstmate PR, which is forbidden outright.

Same cause: write a decision key **BEFORE** the verb colon - `needs-decision [key=slug]: note`. After the colon it parses as `default`, `--resolve-key` fails, and the record becomes a **permanent phantom** that no later correctly-formed line can close.

When citing this defect, name the FUNCTION, never a line number.

## Crewmate comments - avoid them, one short line when unavoidable

Every crewmate brief carries this. Default to none: write self-explanatory code instead of narrating it. Infrastructure code is where one is most often warranted - a permission, not a licence for prose. When unavoidable it is ONE genuinely short line, never a block and never a long run-on dodging the rule. If the "why" will not fit, the code needs a clearer name or a smaller function. **Never strip or reflow pre-existing comments** unless asked.
