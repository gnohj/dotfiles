#!/bin/bash
# Check if HP Z27n external monitor is connected
# Write result to file for Lua to read (sbar.exec doesn't work reliably)

STATUS_FILE="/tmp/sketchybar_external_monitor"
LOG_DIR="$HOME/.logs/sketchybar"
LOG_FILE="$LOG_DIR/display-detection_$(date +%Y%m).log"

# Ensure log directory exists
mkdir -p "$LOG_DIR"

# Logging function
log_message() {
    local level="$1"
    local message="$2"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [$level] [MONITOR-DETECT] $message" >> "$LOG_FILE"
}

log_message "INFO" "Starting external monitor detection"

# Get display information for debugging
DISPLAY_INFO=$(system_profiler SPDisplaysDataType 2>&1)
RESOLUTION_COUNT=$(echo "$DISPLAY_INFO" | grep -c 'Resolution:')

log_message "DEBUG" "Found $RESOLUTION_COUNT display(s) with resolution"

# Check for HP Z27n specifically
if echo "$DISPLAY_INFO" | grep -q 'HP Z27n'; then
    log_message "INFO" "HP Z27n external monitor detected"
    echo "1" > "$STATUS_FILE"
    RESULT="1 (HP Z27n detected)"
elif [ "$RESOLUTION_COUNT" -gt 1 ]; then
    log_message "INFO" "Multiple displays detected (${RESOLUTION_COUNT} resolutions)"
    echo "1" > "$STATUS_FILE"
    RESULT="1 (multiple displays)"
else
    log_message "INFO" "No external monitor detected (built-in display only)"
    echo "0" > "$STATUS_FILE"
    RESULT="0 (laptop only)"
fi

log_message "INFO" "Detection complete: $RESULT"

# Also output to stdout for direct calls
cat "$STATUS_FILE"
