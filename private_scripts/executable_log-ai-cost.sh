#!/bin/bash
# Log AI cost from claude -p JSON output
# Usage: echo "$CLAUDE_JSON_OUTPUT" | log-ai-cost.sh "subject"
#
# Appends to ~/.logs/ai-costs/YYYY-MM.log
# Format: [date] [subject] [model] [input_tokens] [output_tokens] [cost_usd] [duration_ms]

SUBJECT="${1:-unknown}"
LOG_DIR="$HOME/.logs/ai-costs"
mkdir -p "$LOG_DIR"
LOG_FILE="$LOG_DIR/$(date '+%Y-%m').log"

# Read JSON from stdin
JSON=$(cat)

# Parse fields from claude -p --output-format json
DATE=$(date '+%Y-%m-%d %H:%M:%S')
COST=$(echo "$JSON" | jq -r '.total_cost_usd // 0')
DURATION=$(echo "$JSON" | jq -r '.duration_ms // 0')
MODEL=$(echo "$JSON" | jq -r '.modelUsage | keys[0] // "unknown"')
INPUT=$(echo "$JSON" | jq -r '.modelUsage | to_entries[0].value.inputTokens // 0')
OUTPUT=$(echo "$JSON" | jq -r '.modelUsage | to_entries[0].value.outputTokens // 0')
CACHE_READ=$(echo "$JSON" | jq -r '.modelUsage | to_entries[0].value.cacheReadInputTokens // 0')
CACHE_CREATE=$(echo "$JSON" | jq -r '.modelUsage | to_entries[0].value.cacheCreationInputTokens // 0')
DURATION_SEC=$(echo "scale=1; $DURATION / 1000" | bc 2>/dev/null || echo "0")

# Write header if file is new
if [ ! -f "$LOG_FILE" ]; then
  echo "date|subject|model|input_tokens|output_tokens|cache_read|cache_create|cost_usd|duration_s" >> "$LOG_FILE"
fi

echo "$DATE|$SUBJECT|$MODEL|$INPUT|$OUTPUT|$CACHE_READ|$CACHE_CREATE|$COST|${DURATION_SEC}s" >> "$LOG_FILE"
