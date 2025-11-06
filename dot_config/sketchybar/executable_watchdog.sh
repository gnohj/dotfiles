#!/bin/bash

# SketchyBar Watchdog
# Checks if sketchybar is responsive and restarts if frozen

# Configure logging
LOG_DIR="$HOME/.logs/sketchybar"
mkdir -p "$LOG_DIR"
LOG_FILE="$LOG_DIR/watchdog_$(date '+%Y%m').log"

log_message() {
  local message="$1"
  local timestamp
  timestamp=$(date '+%Y-%m-%d %H:%M:%S')
  echo "[$timestamp] $message" | tee -a "$LOG_FILE"
}

LOG_PREFIX="[SketchyBar Watchdog]"

# Check if sketchybar process exists
if ! pgrep -x sketchybar >/dev/null; then
  log_message "$LOG_PREFIX sketchybar is not running, LaunchAgent should restart it"
  exit 0
fi

# Try to query sketchybar to see if it's responsive
# Run query in background and kill if it takes too long
/opt/homebrew/bin/sketchybar --query bar &>/dev/null &
QUERY_PID=$!

# Wait up to 5 seconds for the query to complete
for i in {1..50}; do
  if ! kill -0 $QUERY_PID 2>/dev/null; then
    # Process finished
    wait $QUERY_PID
    if [ $? -eq 0 ]; then
      log_message "$LOG_PREFIX sketchybar is healthy"
      exit 0
    else
      log_message "$LOG_PREFIX sketchybar query failed, but process is running"
      exit 0
    fi
  fi
  sleep 0.1
done

# Timeout - query is still running after 5 seconds
log_message "$LOG_PREFIX sketchybar is unresponsive (timeout), killing it"
kill -9 $QUERY_PID 2>/dev/null
pkill -9 sketchybar
log_message "$LOG_PREFIX Killed sketchybar, LaunchAgent will restart it"
exit 0
