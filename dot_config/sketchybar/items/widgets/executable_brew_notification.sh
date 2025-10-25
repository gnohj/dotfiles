#!/bin/bash
export PATH="/opt/homebrew/bin:/usr/local/bin:$PATH"
export HOMEBREW_NO_AUTO_UPDATE="1"

source "$HOME/.config/sketchybar/config/colors.sh"

# echo "Script triggered with NAME: $NAME" >>/tmp/brew_debug.log
# echo "Sender: $SENDER" >>/tmp/brew_debug.log

LOG_DIR="$HOME/.logs/sketchybar"
mkdir -p "$LOG_DIR"
LOG_FILE="$LOG_DIR/brew_$(date '+%Y%m').log"

log_message() {
  local level="$1"
  local message="$2"
  local timestamp
  timestamp=$(date '+%Y-%m-%d %H:%M:%S')
  echo "[$timestamp] [$level] [BREW] $message" >>"$LOG_FILE"
}

# Timeout wrapper function (10 second timeout for brew operations)
run_with_timeout() {
  local timeout=10
  local cmd="$1"
  local tmpfile="/tmp/brew_notification_$$"

  # Run command in background and capture output
  (eval "$cmd" > "$tmpfile" 2>&1) &
  local pid=$!

  # Wait for command with timeout (0.1s intervals)
  local elapsed=0
  while kill -0 $pid 2>/dev/null; do
    if [ $elapsed -ge $((timeout * 10)) ]; then
      kill -9 $pid 2>/dev/null
      wait $pid 2>/dev/null
      rm -f "$tmpfile"
      log_message "WARN" "Command timed out after ${timeout}s"
      return 124  # timeout exit code
    fi
    sleep 0.1
    elapsed=$((elapsed + 1))
  done

  # Get command exit code and output
  wait $pid
  local exit_code=$?
  if [ -f "$tmpfile" ]; then
    cat "$tmpfile"
    rm -f "$tmpfile"
  fi
  return $exit_code
}

log_message "INFO" "Starting brew update check (Sender: $SENDER)"

# Force brew to use full path and update first if triggered by event
if [[ "$SENDER" == "brew_update" ]]; then
  # echo "Event trigger detected - running brew update first" >>/tmp/brew_debug.log
  run_with_timeout "/opt/homebrew/bin/brew update >/dev/null 2>&1"
fi

# Get outdated packages with timeout
OUTDATED_OUTPUT=$(run_with_timeout "/opt/homebrew/bin/brew outdated 2>&1")
BREW_EXIT_CODE=$?
# echo "brew outdated output: '$OUTDATED_OUTPUT'" >>/tmp/brew_debug.log

# Handle timeout case
if [ $BREW_EXIT_CODE -eq 124 ]; then
  # Timeout occurred - show "?" to indicate unknown state
  COUNT="?"
  log_message "WARN" "Using unknown state due to timeout"
elif [[ -z "$OUTDATED_OUTPUT" || "$OUTDATED_OUTPUT" == "" ]]; then
  # No output - no updates
  COUNT=0
else
  # Count non-empty lines
  COUNT=$(echo "$OUTDATED_OUTPUT" | grep -c '^[[:space:]]*[^[:space:]]')
fi

# echo "COUNT: $COUNT" >>/tmp/brew_debug.log

COLOR=$RED
case "$COUNT" in
"?")
  # Timeout - show gray/dim color to indicate unknown state
  COLOR=$GREY
  ;;
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

# echo "Setting: sketchybar --set $NAME label=$COUNT icon.color=$COLOR" >>/tmp/brew_debug.log
sketchybar --set "$NAME" label="$COUNT" label.color="$COLOR" icon.color="$MAGENTA"

log_message "INFO" "Brew check completed - Count: $COUNT"
