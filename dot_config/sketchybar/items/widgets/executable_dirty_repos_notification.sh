#!/bin/bash
export PATH="$HOME/.local/bin:/run/current-system/sw/bin:/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:$HOME/.cargo/bin:$PATH"

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

# Dirty repos come from `tmux-dash json --dirty` (the git-source dirty list),
# shared with the `dirty()` zsh function so this widget and the shell helper
# can never drift on which repos they track.
DIRTY_NAMES=()
while IFS= read -r name; do
  [ -n "$name" ] && DIRTY_NAMES+=("$name")
done < <(tmux-dash json --dirty 2>/dev/null | jq -r '.repos[].name')

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
