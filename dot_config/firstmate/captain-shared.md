# Captain preferences - shared across every firstmate home

This file is read by EVERY firstmate home on this machine, and pushed down to every second mate.

It is NOT a channel between homes. Nothing here is addressed to a particular home, and no home may put something here aimed at another. If a rule needs an audience, it does not belong here.

## The admission test - read this before adding anything

Does the rule name a repo, a ticket system, a branch convention, a deploy target, or a workflow that only one domain has?

- **YES** - it does not belong here. It stays in that home's own `data/captain.md`.
- **NO, it describes the captain themselves** - it belongs here, and every home obeys all of it.

Two rules that keep this working:

- **Keep this file SHORT.** Propagation requires the captain's own `chezmoi apply`, and that control is only real while the diff stays short enough to actually read. A long file turns their approval into a rubber stamp.
- **The default is NOT shared.** A rule earns its way in; it does not land here because it seemed generally useful.

Nothing enforces any of this mechanically. The guard is this header, the versioned diff, and the captain's apply.

<!-- rules begin below this line -->

## Anything visual goes to the captain's desktop, never to a localhost URL

The captain works from a MacBook against a headless Linux VPS, so `127.0.0.1` on this box reaches nothing they can see.
Never hand them a loopback URL, and never hand them an SSH tunnel command as the answer.

Two steps, both required:

1. Expose it on the tailnet with `tailscale serve`, tailnet-only, never `tailscale funnel`.
2. Push it with `to-desktop open <https-url>`, which lands the open on whichever machine they are sitting at.

`~/.local/bin/to-desktop` is the captain's own helper and the single owner of that routing: `to-desktop open|clip|notify|media`, transported over an ssh forced-command, kitty rc, or OSC 52 depending on what is live, and it validates that only http(s) may cross.
`~/.local/bin/desktop-open` is the `$BROWSER`-shaped wrapper around it.
Reach for these by default for any page, report, diagram, or review surface - do not make the captain open it by hand, and do not conclude a tunnel is required without first checking the tool's own options.

Related: `~/Developer/agents/shared/skills/preview/` is the established pattern for a plain static page, and its `preview.sh` already does the tailnet half.
Use it for static HTML; use Lavish when the captain should be able to answer or annotate.

**Tear it down when the review is finished.** Serving something is not free: a forgotten server holds a port and an orphaned tailnet route keeps pointing at nothing.
When the captain ends the session, or the work the surface existed for is done, stop the server AND remove the route you added - both halves, in that order.
Remove only routes you added; verify the captain's own entries are still intact.

Detecting "finished" needs care: an explicit end signal is definitive, but the absence of one proves nothing, because the captain's last piece of feedback looks identical to feedback they intend to follow up.
So tear down on EITHER an explicit end OR the completion of the work the surface existed for, and never wait for both.
Silence is not a signal. If it is genuinely ambiguous, ask once rather than leaving a server running for days or closing a review the captain was still using.

## Every artifact uses the Silk theme

**Always, no exceptions.** With DaisyUI that is `<html data-theme="silk">`.

Do NOT use Lavish's recommended `luxury` default, and do not pick a theme because the content "calls for it" - the tool's own guidance explicitly invites both and is overridden here.
The captain settled this on 2026-08-09: it began as light Nord earlier the same day and they changed it to Silk within the hour, so Silk is the live value and Nord is superseded rather than an alternative.
They restated it as "should always be silk", so treat it as a hard default rather than a stylistic suggestion, and apply it to existing artifacts too, not only new ones.
Build with semantic tokens (`bg-base-100`, `bg-base-200`, `text-base-content`, `badge-*`, `btn-*`, `var(--color-*)`) so the theme is one attribute and never a per-element repaint.

Silk exists only from DaisyUI 5. On a v4 project raise it rather than silently substituting another theme.
A hand-rolled page with its own CSS has no `silk` to set; make it light by building it light, not by adding the attribute.

## Every artifact carries reader-relative change markers

Requested by the captain on 2026-08-10, after rejecting a weaker first attempt.

The captain re-reads a review page many times while it evolves, and needs to see at a glance what moved since they last looked.

Do NOT build this as "what changed in this update".
That boundary is the agent's, and it is fiction: an agent edits incrementally and republishes several times per conversation, so the same strip claims something different every few minutes.
The captain identified the flaw themselves and proposed the fix.

Build it keyed on what the READER has seen, with these rules - every one of them earned by getting it wrong first on 2026-08-10:

- **No browser storage. It is structurally unavailable.** Lavish serves the artifact in an iframe with `sandbox="allow-scripts allow-forms allow-popups allow-downloads"` - no `allow-same-origin` - which makes it an opaque origin where `localStorage`, `sessionStorage` and cookies all throw. Verified against the installed package: every iframe sandbox it defines omits `allow-same-origin`, so this is structural rather than one session's configuration. Do not write storage code with a silent try/catch; it will appear to work and then forget.
- **Read-state therefore has two sources, and the durable one is the page source.** Keep a `read` flag per block in the one array at the top of the page script; the agent sets it once the captain has seen that round, which is the only thing that survives a reload. In-session viewport tracking layers on top of it and is a bonus, not the mechanism.
- **Give each markable block a stable `id` and a version.** Bump the version when its content changes. That plus clearing `read` is the whole authoring burden.
- **Never encode the KIND in colour.** Green, amber and red already mean things inside an artifact by content - a green card is good news, not a new card. Give markers their own channel nothing else uses (a striped rail in the margin works) and let a WORD carry the kind: `ADDED`, `CHANGED`, `REMOVED`. One colour for all three, deliberately.
- **Mark the end element that actually changed** - that paragraph, that list, that table row - never a wrapper, a card, or a heading. A wrapper says "something in here"; the captain asked for "this". A run of adjacent marks shares one word and one continuous rail so precision does not become noise.
- **Marks dim, they never vanish**, and the layout rules must apply in BOTH states. Scoping padding to the unread state makes the text jump sideways as the reader scrolls past, which reads as a glitch rather than a transition.
- **Dim the LABELS only - never the prose.** The rail and the word fade; the body text stays at full contrast. Fading text the captain is still reading is the same mistake as making a marker vanish mid-read, just quieter. Stated 2026-08-10.
- **Dwell about 2.5 seconds** before counting a block as read. One second fires while scrolling through something rather than reading it.
- **Every control works in-page with no reload and no storage.** "Show changes again" and "mark all read" flip a local override and re-render. A reload-based reset is defeated by the source-level `read` flag and does nothing at all. Clear injected badges before re-rendering or repeated clicks stack duplicates, and resolve the nearest button on click so a hit on the label still registers.
- A strip at the top titled "Not read yet" with a LIVE count lists only unread blocks, each linking to its block. Decrement it as blocks are read and collapse it when the last one goes; rendering it once at load leaves a stale number.

## Lavish review surfaces break silently in four ways

Each of these was learned the hard way, and none of them announces itself.

- **Never open the captain's live review session in a browser on this box.** It becomes a second client, the captain starts getting `409 Conflict`, and their messages stop sending. Inspect the captured results on disk instead.
- **No Mermaid diagrams in a Lavish artifact.** Lavish converts them into a whiteboard whose channel is rejected cross-origin, and everything the captain views is cross-origin, so it renders as a blank slab. Build flows from plain HTML and CSS, or inline SVG for a diagram that needs real edges. Same root cause as the storage rule above: the artifact frame is an opaque origin.
- **Give the captain a reply, or they watch a spinner forever.** The review page expects the agent to answer through its own reply channel; answering only in terminal chat leaves the page saying `Working...` indefinitely.
- **One poll per artifact, enforced before every reply.** Each `lavish-axi poll ... --agent-reply` starts a NEW long-poll and does not retire the previous one, so replying N times leaves N pollers racing on one session. They drain feedback destructively, so the symptoms are indirect and confusing: submissions that vanish, polls returning `waiting` with no content, and finally `This artifact load is no longer current` with the page refusing to render. Observed 2026-08-10 at twelve concurrent polls on one page. Before every reply, stop any existing poll for that exact artifact path, then start one - never rely on remembering, and never widen the match beyond that artifact or you kill another page's channel. A `pkill -f` whose pattern appears in your own command line kills your own shell; match on `/proc/<pid>/cmdline` and skip shell processes instead. Nothing is lost when a poll is killed; Lavish queues feedback independently.

## Always close a message with a colour-coded status block

Requested by the captain on 2026-08-09.
They value the habit of ending on what is still open or waiting; the colours make it scannable instead of something they have to read for.

End every captain-facing message with the open items, one per line, each led by a colour that encodes how much of their attention it wants:

- 🔴 anything that needs them: broken, failed, blocked, or waiting on their decision or approval
- 🟡 open or waiting on something external, but nothing they must act on now
- 🟢 done, landed, verified, nothing needed

Three levels, not four.
The captain collapsed broken, blocked and needs-your-decision into 🔴 on 2026-08-09 and removed 🟠 entirely: from their side those are one thing, because all three mean the message is waiting on them.
Do not reintroduce an intermediate colour to express degrees of urgency inside 🔴; if several 🔴 lines exist, order them so the one that actually blocks is first.

This collapse also retired an earlier conflict.
An earlier rule required a single bold `🔴 NEEDS YOU - <ask>` line, whose 🔴 meant "needs you" and which disagreed with a four-level scheme where decisions were 🟠.
With the collapse, 🔴 means the same thing in both, so the status block simply subsumes that rule: keep one line per open item, keep the always-close 🟢, and let the leading 🔴 carry the ask that the marked line used to.
Never emit both closers.

Lead with the strongest colour present so the top line is the most urgent thing.
When nothing at all is open, still close with one 🟢 line saying so - the absence of a status block reads as an oversight rather than as "all clear".
Use the colours inline elsewhere in a message too when a specific finding deserves the same weight, but never so often that they stop meaning anything.

This is presentation only.
It never replaces the escalation rules in `AGENTS.md` section 9: a 🔴 line does not make an unsafe action safe, and a 🟢 line must be an outcome that was actually verified.
Markdown carries no colour primitive and raw ANSI escapes either render literally or get stripped, so the emoji is what survives every renderer the captain reads through.
Do not attempt ANSI colour.

## Arm the review-comment loop on every PR firstmate opens

Approved by the captain on 2026-08-10.
Firstmate watches its own PRs for merge but nothing watches them for review threads, so bot and human comments sit unanswered.

Right after `bin/fm-pr-check.sh <id> <pr-url>`, also run `~/Developer/agents/shared/skills/fm-pr-comments/gen-check.sh <id> <pr-number> <owner/repo>`.
That replaces the task's watcher check with a stateless review-thread poll and registers it.

On the resulting wake, load the `fm-pr-comments` skill.
It owns the whole procedure; the two things never to get wrong are that you STEER THE EXISTING WORKER rather than spawning, leasing or relaunching anything, and that the worker rebases onto the moved branch before committing, because a bot lands base-branch merges onto PR branches while the worktree sits idle.

The check is stateless and self-clearing, and goes silent on a merged PR by itself, so nothing needs disarming.

## Merge approval belongs to the captain

Every project runs with autonomy off.
No home merges its own work and none treats a green pipeline as permission.
Report the outcome with the full PR URL and wait.

## Second mate status replies use the plain form

Reply on the parent status channel as:

```
<verb>: corr=<id> <note>
```

An interim measure while the shipped `bin/fm-secondmate-report.sh` emits a bracketed form the classifier cannot read, which makes a mate's blocker or decision invisible to its parent.
Retire this only after confirming the installed `bin/fm-classify-lib.sh` parses the bracketed form.

This is the weakest entry in this file: it matters only in a home that has second mates, and it is a workaround for a shipped bug rather than a preference. It is here because it names no repo, ticket system, branch convention or deploy target - it fails the exclusion test rather than passing the inclusion one. Retire it at the first opportunity rather than letting it set a precedent.
