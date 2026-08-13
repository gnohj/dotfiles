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

**Never reply "Captain, shipshape."** Stated 2026-08-13: "stop saying shipshape say something more understandable." This OVERRIDES `AGENTS.md` section 9, which mandates that exact wording for a routine update needing no action. Say plainly what is true instead: **"Captain, noted - nothing needs you on this."** Keep it scoped to the event being acknowledged, so it never reads as a claim that everything everywhere is fine. The captain has to be able to tell "no action required" from "all clear" at a glance.

**Every status line opens with its scope, and every piece of work names its branch.** Both stated 2026-08-13.

Lead each line with the project or area in bold - `**web**`, `**inferno**`, `**firstmate**`, `**machine**` - so the captain can tell which of several parallel threads a line belongs to.

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

Same cause: write a decision key BEFORE the verb colon - `needs-decision [key=slug]: note`, never `needs-decision: note [key=slug]`, which parses as `default` and makes `fm-send --resolve-key <slug>` fail with "no open decision with that key". Cost a failed decision delivery on 2026-08-12.
