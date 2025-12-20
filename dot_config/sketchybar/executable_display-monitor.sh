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

# macOS-compatible timeout function (since 'timeout' command doesn't exist on macOS)
run_with_timeout() {
  local timeout_seconds="$1"
  shift
  local output_file=$(mktemp)

  # Run command in background
  "$@" > "$output_file" 2>/dev/null &
  local pid=$!

  # Wait for timeout or completion
  local count=0
  while kill -0 "$pid" 2>/dev/null; do
    sleep 0.5
    count=$((count + 1))
    if [ "$count" -ge $((timeout_seconds * 2)) ]; then
      kill -9 "$pid" 2>/dev/null
      wait "$pid" 2>/dev/null
      rm -f "$output_file"
      return 1
    fi
  done

  wait "$pid"
  local exit_code=$?
  cat "$output_file"
  rm -f "$output_file"
  return $exit_code
}

# Function to get current display count
get_display_count() {
  # Count displays by resolution lines (more reliable)
  # Add 3 second timeout to prevent hanging
  local result
  result=$(run_with_timeout 3 system_profiler SPDisplaysDataType)
  if [ $? -eq 0 ] && [ -n "$result" ]; then
    echo "$result" | grep -c 'Resolution:'
  else
    echo "0"
  fi
}

# Function to get display configuration hash
get_display_hash() {
  # Get a hash of the display configuration to detect any changes
  # This catches display name changes even when count stays the same
  # Includes display names and resolutions to detect switching between built-in and external
  # Add 3 second timeout to prevent hanging
  local result
  result=$(run_with_timeout 3 system_profiler SPDisplaysDataType)
  if [ $? -eq 0 ] && [ -n "$result" ]; then
    echo "$result" | grep -E '(Resolution:|Color LCD|Built-in|Liquid Retina|^\s+[A-Z])' | md5
  else
    echo "timeout"
  fi
}

# Initialize with current count and hash
PREV_COUNT=$(get_display_count)
PREV_HASH=$(get_display_hash)
echo "$PREV_COUNT" > "$DISPLAY_COUNT_FILE"
echo "$PREV_HASH" > "$DISPLAY_HASH_FILE"

log_message "INFO" "Display monitor started - initial count: $PREV_COUNT display(s), hash: $PREV_HASH"

# Counter for periodic heartbeat logging (every 60 seconds / 12 loops at 5s interval)
LOOP_COUNT=0
HEARTBEAT_INTERVAL=12

# Monitor loop - check every 5 seconds to reduce system_profiler load
while true; do
  sleep 5
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
    log_message "INFO" "Triggering sketchybar monitor_display_change event"
    sketchybar --trigger monitor_display_change

    # Update stored count and hash
    PREV_COUNT="$CURRENT_COUNT"
    PREV_HASH="$CURRENT_HASH"
    echo "$CURRENT_COUNT" > "$DISPLAY_COUNT_FILE"
    echo "$PREV_HASH" > "$DISPLAY_HASH_FILE"

    log_message "INFO" "Display change handling complete"
  fi
done
