#!/bin/bash

# Monitor for display configuration changes and trigger sketchybar event
# This script runs in the background and checks for display changes every 2 seconds

DISPLAY_COUNT_FILE="/tmp/sketchybar_display_count"
DISPLAY_HASH_FILE="/tmp/sketchybar_display_hash"
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

# Function to get display configuration hash
get_display_hash() {
  # Get a hash of the display configuration to detect any changes
  # This catches display name changes even when count stays the same
  # Includes display names and resolutions to detect switching between built-in and external
  system_profiler SPDisplaysDataType | grep -E '(Resolution:|Color LCD|Built-in|Liquid Retina|^\s+[A-Z])' | md5
}

# Initialize with current count and hash
PREV_COUNT=$(get_display_count)
PREV_HASH=$(get_display_hash)
echo "$PREV_COUNT" > "$DISPLAY_COUNT_FILE"
echo "$PREV_HASH" > "$DISPLAY_HASH_FILE"

log_message "INFO" "Display monitor started - initial count: $PREV_COUNT display(s), hash: $PREV_HASH"

# Counter for periodic heartbeat logging (every 60 seconds / 30 loops)
LOOP_COUNT=0
HEARTBEAT_INTERVAL=30

# Monitor loop
while true; do
  sleep 2
  LOOP_COUNT=$((LOOP_COUNT + 1))

  CURRENT_COUNT=$(get_display_count)
  CURRENT_HASH=$(get_display_hash)

  # Periodic heartbeat log (every 60 seconds)
  if [ $((LOOP_COUNT % HEARTBEAT_INTERVAL)) -eq 0 ]; then
    log_message "DEBUG" "Monitor heartbeat - current: $CURRENT_COUNT display(s), previous: $PREV_COUNT display(s)"
  fi

  # Check if display count OR configuration changed
  if [ "$CURRENT_COUNT" != "$PREV_COUNT" ] || [ "$CURRENT_HASH" != "$PREV_HASH" ]; then
    if [ "$CURRENT_COUNT" != "$PREV_COUNT" ]; then
      log_message "WARN" "Display count changed: $PREV_COUNT -> $CURRENT_COUNT displays"
    else
      log_message "WARN" "Display configuration changed (same count but different display)"
    fi

    # Update external monitor status file
    log_message "INFO" "Running check-external-monitor.sh to update detection file"
    bash "$(dirname "$0")/check-external-monitor.sh" > /dev/null 2>&1

    # Trigger sketchybar event
    log_message "INFO" "Triggering sketchybar display_change event"
    sketchybar --trigger display_change

    # Update stored count and hash
    PREV_COUNT="$CURRENT_COUNT"
    PREV_HASH="$CURRENT_HASH"
    echo "$CURRENT_COUNT" > "$DISPLAY_COUNT_FILE"
    echo "$PREV_HASH" > "$DISPLAY_HASH_FILE"

    log_message "INFO" "Display change handling complete"
  fi
done
