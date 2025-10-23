#!/bin/bash
export PATH="/opt/homebrew/bin:/usr/local/bin:$PATH"

source "$HOME/.config/sketchybar/config/colors.sh"

LOG_DIR="$HOME/.logs/sketchybar"
mkdir -p "$LOG_DIR"
LOG_FILE="$LOG_DIR/mas_$(date '+%Y%m').log"

log_message() {
  local level="$1"
  local message="$2"
  local timestamp
  timestamp=$(date '+%Y-%m-%d %H:%M:%S')
  echo "[$timestamp] [$level] [MAS] $message" >>"$LOG_FILE"
}

log_message "INFO" "Starting mas update check (Sender: $SENDER)"

# Get outdated App Store apps
OUTDATED_OUTPUT="$(/opt/homebrew/bin/mas outdated 2>&1)"

# Fix the COUNT calculation
if [[ -z "$OUTDATED_OUTPUT" || "$OUTDATED_OUTPUT" == "" ]]; then
  COUNT=0
else
  # Count non-empty lines
  COUNT=$(echo "$OUTDATED_OUTPUT" | grep -c '^[[:space:]]*[^[:space:]]')
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

sketchybar --set "$NAME" label="$COUNT" label.color="$COLOR" icon.color="$YELLOW"

log_message "INFO" "MAS check completed - Count: $COUNT"
