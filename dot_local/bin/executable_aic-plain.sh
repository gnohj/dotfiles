#!/usr/bin/env bash
# Generate plain (no conventional-commit prefix, no gitmoji) commit messages from staged changes via `claude -p`.

set -uo pipefail
export PATH="${HOMEBREW_PREFIX:-/opt/homebrew}/bin:$HOME/.bun/bin:$HOME/.local/bin:$HOME/.local/share/mise/shims:/usr/bin:/bin:$PATH"

# Absolute path like the zsh `claude` function: homebrew's bin and mise's node bin both carry an unwrapped CLI that wins a bare-name lookup and has no login.
CLAUDE_BIN="$HOME/.local/bin/claude"
[ -x "$CLAUDE_BIN" ] || CLAUDE_BIN="$(command -v claude 2>/dev/null)"

if git diff --cached --quiet 2>/dev/null; then
  echo "no staged changes"
  exit 0
fi

DIFF_STAT=$(git diff --cached --stat 2>/dev/null)
FULL_DIFF=$(git diff --cached 2>/dev/null)

if [ -z "$CLAUDE_BIN" ] || [ ! -x "$CLAUDE_BIN" ]; then
  echo "claude is not on PATH"
  exit 0
fi

PROMPT=$(cat <<EOF
Generate 5 brief, plain git commit messages for these staged changes.

Output rules:
- One candidate per line. Nothing else — no commentary, no bullets, no numbering.
- NO conventional-commit prefixes (no feat:, fix:, chore:, etc.).
- NO emojis.
- Lowercase, descriptive, ≤ 50 chars (e.g. "updated header styles", "fixed login button alignment").
- Vary the candidates so I have real options.

=== git diff --cached --stat ===
$DIFF_STAT

=== git diff --cached ===
$FULL_DIFF
EOF
)

# MAX_THINKING_TOKENS=0: haiku otherwise burns ~900 thinking tokens before 5 short lines, turning a 2s call into 10s.
# Empty setting-sources + empty mcp-config: booting 5 MCP servers and the hook suite costs ~3.3s and ~11k tokens that a one-shot diff read never uses.
RAW=$(MAX_THINKING_TOKENS=0 "$CLAUDE_BIN" --dangerously-skip-permissions --setting-sources '' --strict-mcp-config --mcp-config '{"mcpServers":{}}' --model haiku -p "$PROMPT" 2>/dev/null) || true

# This filter only drops prefixed lines, so claude's "Not logged in · Please run /login" would sail through into lazygit.
case "$RAW" in
  *"Not logged in"*|*"/login"*) echo "claude is not logged in - run: claude auth login"; exit 0 ;;
esac

OUT=$(printf '%s\n' "$RAW" \
  | grep -v '^$' \
  | grep -vE '^\s*```' \
  | grep -vE '^[a-z]+(\([^)]+\))?:' \
  | head -5)

[ -n "$OUT" ] || { echo "claude returned no usable candidates"; exit 0; }

printf '%s\n' "$OUT"
