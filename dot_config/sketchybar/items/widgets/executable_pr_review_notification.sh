#!/bin/bash
export PATH="/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:$PATH"

source "$HOME/.config/sketchybar/config/colors.sh"

# Fallback widget name if not set by sketchybar
NAME="${NAME:-widgets.pr_review_notification}"

LOG_DIR="$HOME/.logs/sketchybar"
mkdir -p "$LOG_DIR"
LOG_FILE="$LOG_DIR/pr_review_$(date '+%Y%m').log"

# Cache file for PR data (used by popup)
PR_DATA_FILE="/tmp/sketchybar_pr_review_data.json"

log_message() {
  local level="$1"
  local message="$2"
  local timestamp
  timestamp=$(date '+%Y-%m-%d %H:%M:%S')
  echo "[$timestamp] [$level] [PR_REVIEW] $message" >>"$LOG_FILE"
}

# Bot authors to filter out
BOT_AUTHORS=(
  "renovate"
  "renovate[bot]"
  "dependabot"
  "dependabot[bot]"
  "github-actions"
  "github-actions[bot]"
  "changesets"
  "changesets[bot]"
  "changeset-bot"
  "changeset-bot[bot]"
  "greenkeeper"
  "greenkeeper[bot]"
  "snyk-bot"
  "imgbot"
  "imgbot[bot]"
  "codecov"
  "codecov[bot]"
  "allcontributors"
  "allcontributors[bot]"
  "semantic-release-bot"
  "release-please"
  "release-please[bot]"
)

is_bot_author() {
  local author="$1"
  author_lower=$(echo "$author" | tr '[:upper:]' '[:lower:]')
  for bot in "${BOT_AUTHORS[@]}"; do
    if [[ "$author_lower" == "$bot" ]]; then
      return 0
    fi
  done
  return 1
}

# Query GitHub for PRs requesting my review (run through zsh for proper environment)
PR_JSON=$(zsh -c 'gh search prs --review-requested=@me --state=open --json author,number,title,repository 2>/dev/null')

if [[ -z "$PR_JSON" || "$PR_JSON" == "[]" ]]; then
  PR_COUNT=0
  echo "[]" > "$PR_DATA_FILE"
  log_message "INFO" "No PRs found requesting review"
else
  # Filter out bot authors and build filtered PR list
  FILTERED_PRS=$(echo "$PR_JSON" | jq -c '[.[] | select(.author.login as $author | ["renovate","renovate[bot]","dependabot","dependabot[bot]","github-actions","github-actions[bot]","changesets","changesets[bot]","changeset-bot","changeset-bot[bot]","greenkeeper","greenkeeper[bot]","snyk-bot","imgbot","imgbot[bot]","codecov","codecov[bot]","allcontributors","allcontributors[bot]","semantic-release-bot","release-please","release-please[bot]"] | map(ascii_downcase) | index($author | ascii_downcase) | not)]')

  # Save filtered PRs with repo info for popup
  echo "$FILTERED_PRS" | jq -c '[.[] | {repo: .repository.nameWithOwner, number: .number, title: .title, author: .author.login}]' > "$PR_DATA_FILE"

  PR_COUNT=$(echo "$FILTERED_PRS" | jq 'length')
  log_message "INFO" "Found $PR_COUNT PRs (after filtering bots)"
fi

# Determine color and label based on count
if [ "$PR_COUNT" -eq 0 ]; then
  COLOR=$GREEN
  LABEL="􀆅"
elif [ "$PR_COUNT" -le 3 ]; then
  COLOR=$WHITE
  LABEL="$PR_COUNT"
elif [ "$PR_COUNT" -le 5 ]; then
  COLOR=$ORANGE
  LABEL="$PR_COUNT"
else
  COLOR=$RED
  LABEL="$PR_COUNT"
fi

# Update sketchybar (icon color set in lua, only update label here)
sketchybar --set "$NAME" \
  label="$LABEL" \
  label.color="$COLOR"

log_message "INFO" "PR review check completed - Count: $PR_COUNT"
