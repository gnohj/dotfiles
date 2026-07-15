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

run_with_timeout() {
  local timeout=5
  local cmd="$1"
  local tmpfile="/tmp/mas_notification_$$"

  (eval "$cmd" > "$tmpfile" 2>&1) &
  local pid=$!

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

  wait $pid
  local exit_code=$?
  if [ -f "$tmpfile" ]; then
    cat "$tmpfile"
    rm -f "$tmpfile"
  fi
  return $exit_code
}

log_message "INFO" "Starting mas update check (Sender: $SENDER)"

OUTDATED_OUTPUT=$(run_with_timeout "/opt/homebrew/bin/mas outdated 2>/dev/null")
MAS_EXIT_CODE=$?

if [ $MAS_EXIT_CODE -eq 124 ]; then
  # Timeout occurred - show "?" to indicate unknown state
  COUNT="?"
  log_message "WARN" "Using unknown state due to timeout"
elif [[ -z "$OUTDATED_OUTPUT" || "$OUTDATED_OUTPUT" == "" ]]; then
  COUNT=0
else
  # Count non-empty lines that don't contain "Error"
  COUNT=$(echo "$OUTDATED_OUTPUT" | grep -v "Error" | grep -c '^[[:space:]]*[^[:space:]]')
fi

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

sketchybar --set "$NAME" label="$COUNT" label.color="$COLOR" icon.color="$YELLOW"

log_message "INFO" "MAS check completed - Count: $COUNT"
