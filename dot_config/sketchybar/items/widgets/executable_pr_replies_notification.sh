#!/bin/bash
# Unresolved review threads on MY open PRs - the "someone asked and is waiting on me" count.
# GraphQL, not search: GitHub's search index carries no qualifier for review threads, so
# review:changes_requested is the closest it gets and misses every question asked without one.
export PATH="/run/current-system/sw/bin:/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:$PATH"

source "$HOME/.config/sketchybar/config/colors.sh"

NAME="${NAME:-widgets.pr_replies_notification}"
ME="${GITHUB_LOGIN:-gnohj}"
DATA_FILE="/tmp/sketchybar_pr_replies_data.json"

LOG_DIR="$HOME/.logs/sketchybar"
mkdir -p "$LOG_DIR"
LOG_FILE="$LOG_DIR/pr_replies_$(date '+%Y%m').log"
log() { printf '[%s] [%s] [PR_REPLIES] %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$1" "$2" >>"$LOG_FILE"; }

ERR="$(mktemp)"
trap 'rm -f "$ERR"' EXIT

# isOutdated threads hang off code that no longer exists, so they are noise rather than a question.
JSON="$(gh api graphql -f query='
{ search(query:"is:pr is:open author:@me archived:false", type:ISSUE, first:30) {
    nodes { ... on PullRequest {
      number title isDraft repository { nameWithOwner }
      reviewThreads(first:100) { nodes {
        isResolved isOutdated
        comments(first:1) { nodes { author { login } } } } } } } } }' 2>"$ERR")"
status=$?

# A failed query is NOT zero: leave the badge as it was rather than turning an outage into "all clear".
if [ "$status" -ne 0 ] || [ -z "$JSON" ]; then
  log ERROR "graphql failed (exit $status): $(tr -d '\n' <"$ERR" | cut -c1-300)"
  exit 0
fi

ROWS="$(printf '%s' "$JSON" | jq -c --arg me "$ME" '
  [ .data.search.nodes[] | select(.isDraft | not)
    | { repo: .repository.nameWithOwner, number: .number, title: .title,
        waiting: ([ .reviewThreads.nodes[]
                    | select(.isResolved == false and .isOutdated == false)
                    | .comments.nodes[0].author.login
                    | select(. != $me) ] | length) }
    | select(.waiting > 0) ]' 2>/dev/null)"
[ -n "$ROWS" ] || ROWS="[]"
printf '%s' "$ROWS" >"$DATA_FILE"

COUNT="$(printf '%s' "$ROWS" | jq '[.[].waiting] | add // 0')"
PRS="$(printf '%s' "$ROWS" | jq 'length')"

if [ "${COUNT:-0}" -eq 0 ]; then
  sketchybar --set "$NAME" drawing=on icon.color="$ICON_BLUE" label="􀆅" label.color="$GREEN"
  log INFO "no unresolved threads awaiting a reply"
  exit 0
fi

if [ "$COUNT" -le 3 ]; then COLOR=$WHITE
elif [ "$COUNT" -le 8 ]; then COLOR=$ORANGE
else COLOR=$RED; fi

sketchybar --set "$NAME" drawing=on label="$COUNT" label.color="$COLOR"
log INFO "$COUNT thread(s) across $PRS PR(s) awaiting a reply"
