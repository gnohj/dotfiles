# Jira ticket conventions (consumed by `~/.local/bin/worktree-bug`)

This file is read verbatim into the claude prompt that classifies a clipboard payload and (if it represents a reproducible bug) creates a Jira ticket. It is **gitignored** — swapping employers = rewrite this file, no script changes.

"DRY RUN MODE: do not call createJiraIssue; output the ticket payload you would have created instead, then output TICKET_URL=DRY_RUN and stop." — claude will obey that.

> **Note for the human reader (not the AI):** the _company_ file (`jira-prompt-company.md`) is what's actually gitignored — this scaffold is committed. `worktree-bug` concatenates `jira-prompt.md + jira-prompt-company.md` at runtime and feeds the combined text to claude as a single prompt. Anything below referring to "the company-specific detail section" is satisfied by the appended company file.

---

## Issue type

- `Bug` — for reproducible bug reports only.
- Do NOT create Story / Epic / Spike from this flow. If the clipboard isn't a reproducible bug, output `NOT_BUG: <one-line reason>` and exit without writing to Jira.

## MCP tool

Use `mcp__claude_ai_Atlassian_Rovo__createJiraIssue`. Pull `cloudId`, `projectKey`, `issueTypeName`, the custom-field IDs, and the repo / component inference table from the **Company-specific detail** section appended at the bottom of this prompt.

Always-passed arguments (regardless of company):

- `summary`: one-line title, ≤80 chars, no trailing period
- `description`: markdown body (concise — 1–3 short paragraphs)
- `additionalFields`: per the custom-field map in the detail section.

If a field can't be confidently inferred from the clipboard, OMIT it rather than fabricating content.

## If the clipboard is a Slack thread URL

If the clipboard payload (text section) looks like a Slack thread URL — pattern `https://*.slack.com/archives/<channel-id>/p<ts>` — the URL alone is opaque (no message body). **Before classifying**, hydrate it:

1. Call `mcp__unblocked__context_get_urls` with the Slack URL. Unblocked indexes Slack threads and returns the message body, channel, who said what, and surrounding thread.
2. Treat the fetched content as the actual "report" for classification. The bare URL is just a pointer — don't classify based on it.
3. **If the fetched thread already references a Jira ticket URL** (e.g. someone pasted a link to an existing ticket in the discussion), treat that as authoritative: output `NOT_BUG: appears to already be tracked at <existing-ticket-key>` and stop. Don't file a duplicate.
4. Otherwise proceed with the codebase investigation + ticket creation flow below, using the fetched thread content as your source.

The same hydrate-first pattern applies to other indexed sources Unblocked supports — GitHub PRs, Linear issues, Notion docs, Confluence pages — though Slack is the common case here. For arbitrary text payloads (no URL, or URLs Unblocked doesn't index), skip this step and go straight to classification.

## Pre-ticket: light codebase investigation (do this BEFORE `createJiraIssue`)

Once classified as a reproducible bug — and only then — spend ~15–45s doing a light scan of the inferred repo so the ticket carries technical signal. The deeper bug-fix workflow (named in the detail section) runs the full investigation later, after the worktree exists; this step just front-loads enough signal to make the ticket useful.

1. **Resolve the repo dir** using the inference table from the company-specific detail section. If the dir doesn't exist or you can't confidently pick one, **skip the rest of this step** — don't fabricate a repo.

2. **Extract 3–5 distinctive search terms** from the clipboard payload. Prefer:
   - Component / class / function / hook names that appear verbatim in the report
   - Visible error strings or thrown exception messages
   - File paths or URL paths that appear verbatim in screenshots / logs
   - Test IDs (e.g. `data-test="..."`) Avoid generic words ("button", "page", "error") — they grep-blast.

3. **Grep with ripgrep** (the user has `rg` installed). Use the Bash tool, not the Grep tool, so we can chain `git log` after. Cap to ≤5 hits per term:

   ```
   rg --max-count 5 -nH -t ts -t tsx -t js -t jsx -t scss -t css <term> ~/Developer/<repo>
   ```

   Aggregate the most promising file paths (deduplicated). Keep the **top 3** suspect files.

4. **Recent-commit check on the top suspect.** Don't `git blame` whole files — narrow to a range:

   ```
   git -C ~/Developer/<repo> log --oneline -10 -- <suspect-file>
   ```

   …or, if a specific line range stands out from the grep:

   ```
   git -C ~/Developer/<repo> log -L <start>,<end>:<suspect-file>
   ```

   If the most recent change to the suspect file is < 6 months old AND aligns with the bug behavior, flag it as a possible regression introducer. Otherwise note "no recent regression identified".

5. **CSS / layout bugs** — also list the relevant viewport edge cases briefly (wide/short, narrow/tall, fixed-vs-fluid constraint flips). One line each is enough; the deep CSS audit happens later in the bug-fix workflow skill.

6. **Bake findings into the Technical Notes custom field** (ID per the detail section) when calling `createJiraIssue`. Use this shape (placeholders are filled with real values from your investigation):

   ```markdown
   ## Suspect files

   - `<repo-relative path>:<line-range>` — <one-line why-this-is-suspect>
   - `<repo-relative path>:<line-range>`

   ## Recent commits

   - `<sha> (<age>, <author>)`: <commit subject>
   - `<sha> (<age>, <author>)`: <commit subject>

   ## Possible regression

   - `<sha>` looks aligned with the timing of the report — investigate first.
   - (or: "no recent regression identified")

   ## Captured from

   - clipboard via worktree-bug on <YYYY-MM-DD>
   ```

   Keep it terse — this is a hint for whoever picks up the ticket, not a full investigation.

## After ticket creation

Once the Jira ticket is created, output exactly one line on its own:

```
TICKET_URL=<full ticket URL using the site URL prefix from the detail section>
```

Then immediately invoke `/worktree <that same URL> --yes`.

The `/worktree` skill will pick up the URL, hit the same Atlassian MCP to read the new ticket, infer repo/folder/slug, and spawn the worktree.

## Final output: proposed approach (after `/worktree` completes successfully)

After `/worktree` finishes — **on success only** — print one final block before exiting. The runner captures it into the vault inbox note so the user has a one-glance summary of what was filed, what to look at, and what to try first when they enter the worktree.

```
PROPOSED_APPROACH:
- Suspect: <file:line range, from the codebase investigation>
- Likely cause: <one sentence — your best read on the root cause>
- Recommended fix: <one sentence — what you'd try first>
- Risk: <regression scope, related code paths, or "low" if isolated>
- Next step: open the worktree and invoke the bug-fix workflow skill named in the detail section — it will do the deep regression analysis, write a failing test, and dispatch to your PR-creation skill.
```

Keep each line ≤ 120 chars. If a field is unknown, write `(unclear from clipboard alone — needs codebase walkthrough)`.

## If NOT a reproducible bug

Output exactly one line and stop:

```
NOT_BUG: <short reason — e.g. "feature request, no repro steps", "vague — needs more context", "Slack thread is opinion / not actionable">
```

Do NOT write to Jira. Do NOT call `/worktree`.

---

## Company-specific detail

(The contents of `jira-prompt-company.md` are appended below at runtime by `worktree-bug`. If you're reading this scaffold directly without running through the script, the section below will be empty — see the sibling company file.)
