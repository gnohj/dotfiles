#!/usr/bin/env bash
# Generate gitmoji-prefixed commit messages from staged changes.
#
# Hybrid backend: small diffs go through `aic` (GitHub Models gpt-4o,
# fast), big diffs fall through to `claude -p` (1M context, slower but
# uncapped). Threshold is in characters since gpt-4o through GitHub
# Models caps at 8000 tokens (~32K chars) per request — we cut over
# below that to leave headroom for the system prompt + JSON envelope.

set -uo pipefail
export PATH="${HOMEBREW_PREFIX:-/opt/homebrew}/bin:/home/linuxbrew/.linuxbrew/bin:$HOME/.local/share/mise/shims:$HOME/.local/bin:/usr/bin:/bin:$PATH"

# Anything bigger than this character count routes to claude. ~28K chars
# stays comfortably under the 8000-token cap (~32K chars / 4-chars-per-
# token rule of thumb plus envelope overhead).
DIFF_CHAR_THRESHOLD=28000

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

DIFF_SIZE=$(git diff --cached 2>/dev/null | wc -c | tr -d ' ')

if [ "$DIFF_SIZE" -le "$DIFF_CHAR_THRESHOLD" ] && command -v aic >/dev/null 2>&1; then
  # Fast path — original aic / gpt-4o flow.
  aic generate "$@" 2>&1 | emojify
  exit 0
fi

# Slow path — claude -p (subscription OAuth, 1M context, no per-call
# token cap). Output: 5 candidates, one per line, gitmoji-prefixed.
if ! command -v claude >/dev/null 2>&1; then
  echo "diff too large for aic ($DIFF_SIZE chars > $DIFF_CHAR_THRESHOLD), and claude is not on PATH"
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

RAW=$(claude --dangerously-skip-permissions --model haiku -p "$PROMPT" 2>/dev/null) || true

printf '%s\n' "$RAW" | grep -E '^[a-z]+(\([^)]+\))?:' | head -10 | emojify
