#!/bin/bash
export PATH="/run/current-system/sw/bin:/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:$HOME/.cargo/bin:$PATH"

source "$HOME/.config/sketchybar/config/colors.sh"

NAME="${NAME:-widgets.dirty_repos_notification}"

LOG_DIR="$HOME/.logs/sketchybar"
mkdir -p "$LOG_DIR"
LOG_FILE="$LOG_DIR/dirty_repos_$(date '+%Y%m').log"

log_message() {
  local level="$1"
  local message="$2"
  local timestamp
  timestamp=$(date '+%Y-%m-%d %H:%M:%S')
  echo "[$timestamp] [$level] [DIRTY_REPOS] $message" >>"$LOG_FILE"
}

# Discovery + dirty/clean classification lives in ~/_bin/dirty-repo-status,
# shared with the `dirty()` zsh function so this widget and the shell
# helper can never drift on which repos they track.
DIRTY_NAMES=()
while IFS=$'\t' read -r status path; do
  [ "$status" = "dirty" ] && DIRTY_NAMES+=("$(basename "$path")")
done < <("$HOME/_bin/dirty-repo-status")

DIRTY_COUNT=${#DIRTY_NAMES[@]}

# Update sketchybar
if [ "$DIRTY_COUNT" -eq 0 ]; then
  COLOR=$GREEN
  LABEL="􀆅"
elif [ "$DIRTY_COUNT" -le 3 ]; then
  COLOR=$ORANGE
  LABEL="$DIRTY_COUNT"
else
  COLOR=$RED
  LABEL="$DIRTY_COUNT"
fi

sketchybar --set "$NAME" \
  label="$LABEL" \
  label.color="$COLOR"

if [ "$DIRTY_COUNT" -gt 0 ]; then
  log_message "INFO" "Dirty repos ($DIRTY_COUNT): ${DIRTY_NAMES[*]}"
else
  log_message "INFO" "All repos clean"
fi
