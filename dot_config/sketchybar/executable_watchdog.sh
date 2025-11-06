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
# Timeout after 5 seconds if frozen
if timeout 5 /opt/homebrew/bin/sketchybar --query bar &>/dev/null; then
  log_message "$LOG_PREFIX sketchybar is healthy"
  exit 0
else
  log_message "$LOG_PREFIX sketchybar is unresponsive, killing it"
  pkill -9 sketchybar
  log_message "$LOG_PREFIX Killed sketchybar, LaunchAgent will restart it"
  exit 0
fi
