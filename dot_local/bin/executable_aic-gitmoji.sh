#!/usr/bin/env bash
# Generate gitmoji-prefixed commit messages from staged changes via `claude -p` (subscription OAuth, 1M context).

set -uo pipefail
# ~/.local/bin MUST precede the mise shims: `claude` there is the wrapper that injects the account's CLAUDE_CODE_OAUTH_TOKEN, and the shim reaches the raw CLI, which has no login.
export PATH="${HOMEBREW_PREFIX:-/opt/homebrew}/bin:$HOME/.bun/bin:$HOME/.local/bin:$HOME/.local/share/mise/shims:/usr/bin:/bin:$PATH"
[ "$(uname)" = Linux ] && PATH="/home/linuxbrew/.linuxbrew/bin:$PATH"

if git diff --cached --quiet 2>/dev/null; then
  echo "no staged changes"
  exit 0
fi

# Map a conventional-commit type to its gitmoji prefix.
emojify() {
  while IFS= read -r line; do
    case "$line" in
      feat*) echo "✨ $line" ;;
      fix*) echo "🐛 $line" ;;
      docs*) echo "📝 $line" ;;
      style*) echo "💄 $line" ;;
      refactor*) echo "♻️ $line" ;;
      perf*) echo "⚡ $line" ;;
      test*) echo "✅ $line" ;;
      build*) echo "📦 $line" ;;
      ci*) echo "👷 $line" ;;
      chore*) echo "🔧 $line" ;;
      *) echo "$line" ;;
    esac
  done
}

if ! command -v claude >/dev/null 2>&1; then
  echo "claude is not on PATH"
  exit 0
fi

DIFF_STAT=$(git diff --cached --stat 2>/dev/null)
FULL_DIFF=$(git diff --cached 2>/dev/null)

PROMPT=$(cat <<EOF
Generate 5 candidate git commit messages for these staged changes.

Output rules:
- One candidate per line. Nothing else — no commentary, no bullets, no numbering.
- Each line: \`<conventional-commit-type>(<scope>): <description>\` where type is one of
  feat, fix, docs, style, refactor, perf, test, build, ci, chore.
- Description: imperative mood, lowercase, no period at the end, ≤ 72 chars.
- Scope is optional. If the change is across many areas, omit it.
- Vary the candidates slightly so I have real options to pick from.
- DO NOT include the gitmoji emoji — the wrapper adds that.

=== git diff --cached --stat ===
$DIFF_STAT

=== git diff --cached ===
$FULL_DIFF
EOF
)

# MAX_THINKING_TOKENS=0: haiku otherwise burns ~900 thinking tokens before 5 short lines, turning a 2s call into 10s.
RAW=$(MAX_THINKING_TOKENS=0 claude --dangerously-skip-permissions --model haiku -p "$PROMPT" 2>/dev/null) || true
OUT=$(printf '%s\n' "$RAW" | grep -E '^[a-z]+(\([^)]+\))?:' | head -10)

# Claude's own "Not logged in · Please run /login" would otherwise reach lazygit as a commit-message candidate.
if [ -z "$OUT" ]; then
  case "$RAW" in
    *"Not logged in"*|*"/login"*) echo "claude is not logged in - run: claude auth login" ;;
    *) echo "claude returned no usable candidates" ;;
  esac
  exit 0
fi

printf '%s\n' "$OUT" | emojify
