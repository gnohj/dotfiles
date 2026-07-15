#!/usr/bin/env bash
# Generate plain (no conventional-commit prefix, no gitmoji) commit
# messages from staged changes.
#
# Hybrid backend: small diffs use direct GitHub Models gpt-4o (fast,
# capped at 8000 tokens per request); big diffs fall through to
# `claude -p` (1M context, slower but uncapped).

set -uo pipefail
export PATH="${HOMEBREW_PREFIX:-/opt/homebrew}/bin:/home/linuxbrew/.linuxbrew/bin:$HOME/.local/share/mise/shims:$HOME/.local/bin:/usr/bin:/bin:$PATH"

DIFF_CHAR_THRESHOLD=28000

if git diff --cached --quiet 2>/dev/null; then
  echo "no staged changes"
  exit 0
fi

DIFF_STAT=$(git diff --cached --stat 2>/dev/null)
FULL_DIFF=$(git diff --cached 2>/dev/null)
DIFF_SIZE=$(printf '%s' "$FULL_DIFF" | wc -c | tr -d ' ')

# Fast path — direct GitHub Models gpt-4o call (matches the previous
# implementation byte-for-byte).
if [ "$DIFF_SIZE" -le "$DIFF_CHAR_THRESHOLD" ]; then
  TOKEN=$(gh auth token 2>/dev/null)
  if [ -n "$TOKEN" ]; then
    read -r -d '' SHORT_PROMPT << 'EOF'
Generate 5 brief, plain commit messages for these changes. Rules:
- NO conventional commit prefixes (no feat:, fix:, chore:, etc.)
- NO emojis
- Keep it simple and descriptive like: "updated header styles", "fixed login button alignment", "added user validation"
- Use lowercase
- Be brief (under 50 chars if possible)
- Each message on its own line, nothing else

Changes:
EOF
    RESPONSE=$(curl -s "https://models.inference.ai.azure.com/chat/completions" \
      -H "Content-Type: application/json" \
      -H "Authorization: Bearer $TOKEN" \
      -d "$(jq -n \
        --arg prompt "$SHORT_PROMPT" \
        --arg diff "$FULL_DIFF" \
        '{
          model: "gpt-4o",
          messages: [
            {role: "system", content: "You generate brief, plain git commit messages. No emojis. No conventional commit prefixes. Just simple descriptions."},
            {role: "user", content: ($prompt + "\n\n" + $diff)}
          ],
          max_tokens: 256,
          temperature: 0.7
        }')" 2>/dev/null)
    OUT=$(echo "$RESPONSE" | jq -r '.choices[0].message.content // empty' 2>/dev/null | grep -v '^$' | head -5)
    if [ -n "$OUT" ]; then
      printf '%s\n' "$OUT"
      exit 0
    fi
    # If gpt-4o errored (413, etc.) fall through to claude path below.
  fi
fi

# Slow path — claude -p (subscription OAuth, 1M context).
if ! command -v claude >/dev/null 2>&1; then
  echo "diff too large for gpt-4o, and claude is not on PATH"
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

RAW=$(claude --dangerously-skip-permissions --model haiku -p "$PROMPT" 2>/dev/null) || true

printf '%s\n' "$RAW" \
  | grep -v '^$' \
  | grep -vE '^[a-z]+(\([^)]+\))?:' \
  | head -5
