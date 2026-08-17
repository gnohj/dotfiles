#!/bin/bash
# gh is nix-provided, so /run/current-system/sw/bin has to lead: it is what let the old `zsh -c` wrapper (dropped below) find gh at all, via ~/.zshenv.
export PATH="/run/current-system/sw/bin:/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:$PATH"

source "$HOME/.config/sketchybar/config/colors.sh"

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

# REST search, not `gh search prs`: that command hard-503s from GitHub's search backend while this endpoint answers the identical query, so the badge sat hidden. Reshaped to that command's JSON, leaving the filters below untouched.
PR_ERR="$(mktemp)"
trap 'rm -f "$PR_ERR"' EXIT
PR_JSON="$(gh api -X GET search/issues \
  -f q='review-requested:@me state:open type:pr' \
  -f per_page=100 \
  --jq '[.items[] | {author: {login: .user.login}, number: .number, title: .title, repository: {nameWithOwner: (.repository_url | split("/repos/")[1])}}]' 2>"$PR_ERR")"
gh_status=$?

# A failed query is NOT "zero PRs". Leave the badge exactly as it was instead of hiding it — swallowing the error into a 0 is what made every GitHub hiccup look like an empty review queue.
if [ "$gh_status" -ne 0 ] || [ -z "$PR_JSON" ]; then
  log_message "ERROR" "PR query failed (exit $gh_status): $(tr -d '\n' <"$PR_ERR" | cut -c1-300)"
  exit 0
fi

if [[ "$PR_JSON" == "[]" ]]; then
  PR_COUNT=0
  echo "[]" > "$PR_DATA_FILE"
  log_message "INFO" "No PRs found requesting review"
else
  FILTERED_PRS=$(echo "$PR_JSON" | jq -c '[.[] | select(.author.login as $author | ["renovate","renovate[bot]","dependabot","dependabot[bot]","github-actions","github-actions[bot]","changesets","changesets[bot]","changeset-bot","changeset-bot[bot]","greenkeeper","greenkeeper[bot]","snyk-bot","imgbot","imgbot[bot]","codecov","codecov[bot]","allcontributors","allcontributors[bot]","semantic-release-bot","release-please","release-please[bot]"] | map(ascii_downcase) | index($author | ascii_downcase) | not)]')

  # Save filtered PRs with repo info for popup
  echo "$FILTERED_PRS" | jq -c '[.[] | {repo: .repository.nameWithOwner, number: .number, title: .title, author: .author.login}]' > "$PR_DATA_FILE"

  PR_COUNT=$(echo "$FILTERED_PRS" | jq 'length')
  log_message "INFO" "Found $PR_COUNT PRs (after filtering bots)"
fi

# Green check when the queue is empty, matching the errors and package badges. It used to hide instead, which made "nothing to review" indistinguishable from the broken query above.
if [ "$PR_COUNT" -eq 0 ]; then
  sketchybar --set "$NAME" drawing=on icon.color="$ICON_BLUE" label="􀆅" label.color="$GREEN"
  log_message "INFO" "No PRs awaiting review — green check shown"
  exit 0
fi

if [ "$PR_COUNT" -le 3 ]; then
  COLOR=$WHITE
elif [ "$PR_COUNT" -le 5 ]; then
  COLOR=$ORANGE
else
  COLOR=$RED
fi

# Update sketchybar (icon color set in lua, only update label here)
sketchybar --set "$NAME" \
  drawing=on \
  label="$PR_COUNT" \
  label.color="$COLOR"

log_message "INFO" "PR review check completed - Count: $PR_COUNT"
