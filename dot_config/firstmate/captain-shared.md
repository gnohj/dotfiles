# Captain preferences - shared across every firstmate home

<!-- memory tiers: see the stow skill -->

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

The test before opening any such PR: _would a contributor who never uses my tooling want this change?_ If no, it belongs on our side. Genuine defects are reported upstream and worked around meanwhile, never patched locally.

## Always close a message with a colour-coded status block

End every captain-facing message with the open items, one per line:

- 🔴 anything that needs them: broken, failed, blocked, or waiting on their decision or approval
- 🟡 open or waiting on something external, but nothing they must act on now
- 🟢 done, landed, verified, nothing needed

Three levels, not four - 🟠 was removed on 2026-08-09 because broken, blocked and needs-your-decision are one thing from the captain's side. Do not reintroduce an intermediate colour; order several 🔴 lines so the one that actually blocks is first.

Lead with the strongest colour present. When nothing is open, still close with one 🟢 line - an absent block reads as an oversight, not as "all clear". Use the colours inline when a finding deserves the same weight, but never so often they stop meaning anything.

This is the ONLY closer; an earlier single bold `🔴 NEEDS YOU` rule was retired into it. Never emit both.

Presentation only: it never replaces the escalation rules in `AGENTS.md` section 9. A 🔴 line does not make an unsafe action safe, and a 🟢 line must be an outcome that was actually verified. Emoji is what survives every renderer - never attempt ANSI colour.

## Never say a bare "mate" - name which one

"Mate" alone is ambiguous: it can mean a second mate, a crewmate, or the other first mate. Always say which, and name it:

- **second mate** - a persistent firstmate owning a domain, with its own home and charter. Name it: "the web second mate", never "the mate".
- **first mate** - firstmate itself. More than one runs per machine, so say "the work first mate" or "the personal first mate", never "the other home".
- **crewmate** - spawned for one task. Say "crewmate", never "worker" - the captain corrected this on 2026-08-12 and it overrides the `crewmate -> worker` translation in `AGENTS.md` section 9. **Ship** and **scout** are both crewmates rather than peers of one: a ship crewmate delivers a project change, a scout crewmate delivers a report and never a PR. Say "scout" only to narrow which kind.

Asked for on 2026-08-12 after a whole session of "the mate" that only meant the web second mate.

## No workarounds for a firstmate gap

The captain's words: "i dont want these hacks/shims." They are evaluating firstmate itself, so a workaround that hides a defect makes the system look healthier than it is - which is worse than the friction it removes.

Do not paper over a gap with a local technique. Use a `--kind captain` backlog hold for durable tracking, let the gap show, and bring the captain the choice rather than applying a mitigation and reporting it afterward.

## Merge approval belongs to the captain

Every project runs with autonomy off. No home merges its own work and none treats a green pipeline as permission. Report the outcome with the full PR URL and wait.

## Anything visual reaches the captain's desktop, never a localhost URL

The captain works from a MacBook against a headless Linux VPS, so `127.0.0.1` here reaches nothing they can see. Never hand them a loopback URL or an SSH tunnel command.

Expose it tailnet-only with `tailscale serve` - never `funnel` - then push it with `to-desktop open <https-url>`. `~/.local/bin/to-desktop` owns that routing and validates that only http(s) may cross; `desktop-open` is its `$BROWSER`-shaped wrapper. Use `~/Developer/agents/shared/skills/preview/` for a plain static page, and Lavish when the captain should answer or annotate.

**Tear it down when finished** - stop the server AND remove only the routes you added, verifying the captain's own entries survive. Tear down on an explicit end OR on completion of the work the surface existed for, never on silence. If genuinely ambiguous, ask once.

## Building an artifact

**DaisyUI `light` / `dark`, with a toggle** - `<html data-theme="light">` plus a control offering both. Never pick a theme because the content "calls for it"; the tool's guidance invites that and is overridden here. Build with semantic tokens so the theme is one attribute.

**Why not a named theme.** `daisyui.css` bundles ONLY `light` and `dark`; every other theme (silk, luxury, dim...) lives in a separate `themes.css`. A `data-theme` naming a theme that is not loaded matches no rule and falls back to `light` through `:root` - so the page renders a perfectly reasonable light theme while silently ignoring the one asked for. This is not hypothetical: the previous "silk always" rule was being satisfied in markup and discarded in output. The two bundled themes make that failure impossible and drop a stylesheet. A hand-rolled page with its own CSS has no theme to set: make it light by building it light.

**Reader-relative change markers, keyed on what the READER has seen** - never "what changed in this update", which is fiction because an agent republishes several times per conversation. Per-block `id` and version in one array at the top of the page script, with a `read` flag the agent sets once the captain has seen that round. **There is no browser storage**: the artifact iframe is an opaque origin, so `localStorage`, `sessionStorage` and cookies all throw - the page source is the only durable read-state. Never encode the KIND in colour; give markers their own channel and let a WORD carry it (`ADDED`, `CHANGED`, `REMOVED`). Mark the end element that changed, never a wrapper. Marks DIM, never vanish, and dim the labels only - never the prose. Dwell ~2.5s before counting a block read. Every control works in-page with no reload. A top strip titled "Not read yet" carries a LIVE count that decrements and collapses.

**The artifact iframe is sandboxed without `allow-same-origin`, which is one root cause behind most of the list below.** Lavish serves its chrome at `/session/:key` and embeds the artifact at `/artifact/:key` under `sandbox="allow-scripts allow-forms allow-popups allow-downloads"`. No `allow-same-origin` means the artifact's origin is `null`, so: `localStorage`, `sessionStorage` and cookies all throw; `fetch()` of a sibling file fails as cross-origin with no CORS headers, so **load local data with a classic `<script src>`, never `fetch`**; the page cannot call out to anything, so it can never check its own freshness; and Mermaid's whiteboard handoff does not activate (Mermaid itself renders fine; only the Excalidraw conversion is absent, and the cause is unconfirmed). `window.lavish.*` works only because it `postMessage`s to the parent chrome frame, which owns a real origin and makes the HTTP call. A CDN like `esm.sh` still works, because it sends CORS headers - which makes it a misleading test of whether local loading works.

**The agent is never pushed to; it pulls.** `lavish-axi poll` is a blocking `GET /api/poll` whose stdout landing in the transcript IS the delivery mechanism. There is no socket, no pane, and no knowledge of the multiplexer anywhere in the server. That is why the poll must stay in the foreground, why a dead poll is silence rather than an error, and why nothing can wake an agent that has stopped polling. Queued feedback survives regardless, since the queue lives in the server process.

**A write into the artifact directory reloads the page.** The server watches those files and pushes a reload over SSE, so editing `data.js` alone is enough - re-opening the artifact is not required. Anything the reviewer holds in page memory dies with that reload, and there is no storage to restore it from, so never write into a live artifact directory to say something. `--agent-reply` touches no watched file and is the safe channel.

**The three paragraphs above are duplicated on purpose in `shared/skills/review-lavish/SKILL.md`.** They serve different readers - this file reaches every home for any artifact, that skill travels to people who never see this file - so neither can drop them. They are one set of facts in two places: **change one, check the other**, or they will drift into disagreeing about the same behaviour. **Compare the facts, never the strings** - the two copies are deliberately worded for their different readers, so an exact-phrase grep reports drift that is not there and invites "fixing" a non-existent problem. Everything else here is preference (the light/dark theme, change markers, the tailnet route) and belongs only here.

**Four ways a Lavish surface breaks silently:** never open the captain's live session in a browser here (it becomes a second client and their messages start failing with `409`); Mermaid itself renders fine here - verified with mermaid@11 rendering into a plain container inside the artifact iframe - so the older "no Mermaid" rule is withdrawn; what remains unconfirmed is only the `.mermaid` whiteboard conversion, and an unrendered block cannot convert, so check `mermaid.run()` actually ran before blaming the feature; always reply through Lavish's own channel or the captain watches a spinner forever; and **one poll per artifact**, stopped before every reply, because concurrent polls drain feedback destructively and end with the page refusing to render. Match on `/proc/<pid>/cmdline` when stopping one - a `pkill -f` pattern that appears in your own command line kills your own shell.

## Arm the review-comment loop on every PR firstmate opens

Right after `bin/fm-pr-check.sh <id> <pr-url>`, also run `~/Developer/agents/shared/skills/fm-pr-comments/gen-check.sh <id> <pr-number> <owner/repo>`. That replaces the task's watcher check with a stateless review-thread poll.

On the resulting wake, load the `fm-pr-comments` skill - it owns the procedure. Two things never to get wrong: STEER THE EXISTING WORKER rather than spawning anything, and make it rebase onto the moved branch before committing, because bots land base-branch merges while a worktree sits idle. The check is self-clearing and goes silent on a merged PR.

## Second mate status replies use the plain form

Reply on the parent status channel as `<verb>: corr=<id> <note>`.

An interim measure while the shipped `bin/fm-secondmate-report.sh` emits a bracketed form the classifier cannot read, making a mate's blocker invisible to its parent. Retire it once `bin/fm-classify-lib.sh` parses the bracketed form - it is the weakest entry here, passing only by failing the exclusion test rather than describing the captain.
