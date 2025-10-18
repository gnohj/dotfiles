#!/bin/bash
export PATH="$HOME/.local/bin:/opt/homebrew/bin:/usr/local/bin:$PATH"

source "$HOME/.config/sketchybar/config/colors.sh"

LOG_DIR="$HOME/.logs/sketchybar"
mkdir -p "$LOG_DIR"
LOG_FILE="$LOG_DIR/mise_$(date '+%Y%m').log"

log_message() {
  local level="$1"
  local message="$2"
  local timestamp
  timestamp=$(date '+%Y-%m-%d %H:%M:%S')
  echo "[$timestamp] [$level] [MISE] $message" >>"$LOG_FILE"
}

log_message "INFO" "Starting mise update check (Sender: $SENDER)"

# Check for outdated mise tools - call mise binary directly to avoid shell wrapper
OUTDATED_OUTPUT="$($HOME/.local/bin/mise outdated 2>&1)"

# Count outdated tools
if [[ -z "$OUTDATED_OUTPUT" || "$OUTDATED_OUTPUT" =~ "All tools are up to date" ]]; then
  COUNT=0
else
  # Count non-empty lines (excluding header line that starts with "Tool")
  COUNT=$(echo "$OUTDATED_OUTPUT" | grep -v "^Tool" | grep -v "^$" | wc -l | tr -d ' ')
fi

COLOR=$RED
case "$COUNT" in
[3-5][0-9])
  COLOR=$RED
  ;;
[1-2][0-9])
  COLOR=$ORANGE
  ;;
[1-9])
  COLOR=$WHITE
  ;;
0)
  COLOR=$GREEN
  COUNT=􀆅
  ;;
esac

# Use BLUE for icon color instead of MAGENTA
sketchybar --set "$NAME" label="$COUNT" label.color="$COLOR" icon.color="$BLUE"

log_message "INFO" "Mise check completed - Count: $COUNT"
