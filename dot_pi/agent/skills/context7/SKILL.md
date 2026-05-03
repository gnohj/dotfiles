---
name: context7
description: Fetch up-to-date documentation for libraries, frameworks, SDKs, APIs, CLI tools, and cloud services via the context7.com docs index. Use whenever the user asks about a library/framework/API (React, Next.js, Prisma, Tailwind, Django, gh CLI, etc.) — even well-known ones — since training data may be stale. Skip for refactoring, business logic debugging, or general programming concepts.
---

# context7

Pi-only equivalent of the context7 MCP server. Hits context7.com's HTTP API via a bundled bash script.

## When to use

- User asks about a library/framework/SDK/API/CLI tool/cloud service.
- User mentions setup, config, version migration, or library-specific debugging.
- You're about to recommend syntax or APIs from training data — verify first.

## How to invoke

The skill ships with `context7.sh` next to this file. Run it via the **Bash** tool — never inline the URL yourself.

### 1. Resolve a library name to an ID

```bash
~/.pi/agent/skills/context7/context7.sh search <library-name>
```

Returns JSON `{ results: [{ id, title, description, trustScore, ... }, ...] }`. Pick the result with the highest `trustScore` and most relevant `title`/`description`. The `id` looks like `/reactjs/react.dev` or `/vercel/next.js`.

### 2. Fetch docs for a library

```bash
~/.pi/agent/skills/context7/context7.sh docs <library-id> <natural-language-query>
```

Returns JSON `{ codeSnippets: [...], infoSnippets: [...] }`. Quote the query if it contains spaces.

## Examples

```bash
# Find the Next.js library ID
~/.pi/agent/skills/context7/context7.sh search "next.js"

# Ask a question about it
~/.pi/agent/skills/context7/context7.sh docs /vercel/next.js "how do I set up middleware for auth"
```

## Notes

- Free tier — no API key required. Set `CONTEXT7_API_KEY` env var for higher rate limits if you have one.
- Use **detailed natural-language queries** for best results — "how to implement X" beats "X".
- If `search` returns multiple matches, prefer official sources (`/reactjs/...`, `/vercel/...`, `/facebook/...`) over mirrors.
