#!/bin/bash

# Monitor for display configuration changes and trigger sketchybar event
# This script runs in the background and checks for display changes every 2 seconds

DISPLAY_COUNT_FILE="/tmp/sketchybar_display_count"
LOG_DIR="$HOME/.logs/sketchybar"
LOG_FILE="$LOG_DIR/display-monitor_$(date +%Y%m).log"

# Ensure log directory exists
mkdir -p "$LOG_DIR"

# Logging function
log_message() {
  local level="$1"
  local message="$2"
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] [$level] [DISPLAY-MONITOR] $message" >> "$LOG_FILE"
}

# Function to get current display count
get_display_count() {
  # Count displays by resolution lines (more reliable)
  system_profiler SPDisplaysDataType | grep -c 'Resolution:'
}

# Initialize with current count
PREV_COUNT=$(get_display_count)
echo "$PREV_COUNT" > "$DISPLAY_COUNT_FILE"

log_message "INFO" "Display monitor started - initial count: $PREV_COUNT display(s)"

# Counter for periodic heartbeat logging (every 60 seconds / 30 loops)
LOOP_COUNT=0
HEARTBEAT_INTERVAL=30

# Monitor loop
while true; do
  sleep 2
  LOOP_COUNT=$((LOOP_COUNT + 1))

  CURRENT_COUNT=$(get_display_count)

  # Periodic heartbeat log (every 60 seconds)
  if [ $((LOOP_COUNT % HEARTBEAT_INTERVAL)) -eq 0 ]; then
    log_message "DEBUG" "Monitor heartbeat - current: $CURRENT_COUNT display(s), previous: $PREV_COUNT display(s)"
  fi

  # Check if display count changed
  if [ "$CURRENT_COUNT" != "$PREV_COUNT" ]; then
    log_message "WARN" "Display configuration changed: $PREV_COUNT -> $CURRENT_COUNT displays"

    # Update external monitor status file
    log_message "INFO" "Running check-external-monitor.sh to update detection file"
    bash "$(dirname "$0")/check-external-monitor.sh" > /dev/null 2>&1

    # Trigger sketchybar event
    log_message "INFO" "Triggering sketchybar display_change event"
    sketchybar --trigger display_change

    # Update stored count
    PREV_COUNT="$CURRENT_COUNT"
    echo "$CURRENT_COUNT" > "$DISPLAY_COUNT_FILE"

    log_message "INFO" "Display change handling complete"
  fi
done
