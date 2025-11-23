#!/bin/bash
# Check if any external monitor is connected
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

# Check for external monitors:
# 1. Multiple displays (dual display mode)
# 2. Single display that's NOT "Color LCD" or "Built-in" (clamshell with external)
if [ "$RESOLUTION_COUNT" -gt 1 ]; then
    log_message "INFO" "Multiple displays detected (${RESOLUTION_COUNT} resolutions)"
    echo "1" > "$STATUS_FILE"
    RESULT="1 (multiple displays)"
elif [ "$RESOLUTION_COUNT" -eq 1 ]; then
    # Single display - check if it's external or built-in
    if echo "$DISPLAY_INFO" | grep -q -E '(Color LCD|Built-in|Liquid Retina)'; then
        log_message "INFO" "No external monitor detected (built-in display only)"
        echo "0" > "$STATUS_FILE"
        RESULT="0 (laptop only)"
    else
        # Single display that's not built-in = clamshell mode with external
        # Extract the display name (it's the line right before Resolution: with more indentation)
        MONITOR_NAME=$(echo "$DISPLAY_INFO" | grep -B1 'Resolution:' | head -1 | sed 's/^[[:space:]]*//' | sed 's/:.*//')
        log_message "INFO" "External monitor detected in clamshell mode: $MONITOR_NAME"
        echo "1" > "$STATUS_FILE"
        RESULT="1 (external: $MONITOR_NAME)"
    fi
else
    log_message "WARN" "No displays found with resolution"
    echo "0" > "$STATUS_FILE"
    RESULT="0 (no displays)"
fi

log_message "INFO" "Detection complete: $RESULT"

# Also output to stdout for direct calls
cat "$STATUS_FILE"
