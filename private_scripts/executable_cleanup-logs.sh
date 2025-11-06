#!/bin/bash

# Log Cleanup Script
# Cleans up old log files from ~/.logs directory
# Keeps logs from current month and previous month only

LOG_DIR="$HOME/.logs"
CLEANUP_LOG_DIR="$LOG_DIR/cleanup"
mkdir -p "$CLEANUP_LOG_DIR"
CLEANUP_LOG="$CLEANUP_LOG_DIR/cleanup_$(date '+%Y%m').log"

log_message() {
  local message="$1"
  local timestamp
  timestamp=$(date '+%Y-%m-%d %H:%M:%S')
  echo "[$timestamp] $message" | tee -a "$CLEANUP_LOG"
}

log_message "Starting log cleanup..."

# Get current month and previous month in YYYYMM format
CURRENT_MONTH=$(date '+%Y%m')
PREVIOUS_MONTH=$(date -v-1m '+%Y%m')

log_message "Keeping logs from: $PREVIOUS_MONTH and $CURRENT_MONTH"

# Find all log files with YYYYMM pattern that are older than previous month
# This will match files like: spotify_202501.log, autopush_202501.log, etc.
DELETED_COUNT=0
KEPT_COUNT=0

# Find all .log files in ~/.logs recursively
while IFS= read -r -d '' logfile; do
  # Extract YYYYMM pattern from filename if it exists
  if [[ "$logfile" =~ _([0-9]{6})\.log$ ]]; then
    FILE_MONTH="${BASH_REMATCH[1]}"

    # Keep if it's current month or previous month
    if [[ "$FILE_MONTH" == "$CURRENT_MONTH" || "$FILE_MONTH" == "$PREVIOUS_MONTH" ]]; then
      KEPT_COUNT=$((KEPT_COUNT + 1))
      log_message "KEEP: $logfile (month: $FILE_MONTH)"
    else
      DELETED_COUNT=$((DELETED_COUNT + 1))
      log_message "DELETE: $logfile (month: $FILE_MONTH)"
      rm -f "$logfile"
    fi
  else
    # For non-dated log files, check modification time
    # Delete if older than 60 days
    if [[ $(uname) == "Darwin" ]]; then
      # macOS find syntax
      DAYS_OLD=$(( ($(date +%s) - $(stat -f %m "$logfile")) / 86400 ))
    else
      # Linux find syntax
      DAYS_OLD=$(( ($(date +%s) - $(stat -c %Y "$logfile")) / 86400 ))
    fi

    if [[ $DAYS_OLD -gt 60 ]]; then
      DELETED_COUNT=$((DELETED_COUNT + 1))
      log_message "DELETE: $logfile (${DAYS_OLD} days old)"
      rm -f "$logfile"
    else
      KEPT_COUNT=$((KEPT_COUNT + 1))
      log_message "KEEP: $logfile (${DAYS_OLD} days old)"
    fi
  fi
done < <(find "$LOG_DIR" -type f -name "*.log" -print0)

log_message "Cleanup complete: Deleted $DELETED_COUNT files, Kept $KEPT_COUNT files"

# Clean up empty directories in ~/.logs
find "$LOG_DIR" -type d -empty -delete

log_message "Removed empty directories"

# Keep only current month's cleanup log
find "$CLEANUP_LOG_DIR" -type f -name "cleanup_*.log" ! -name "cleanup_${CURRENT_MONTH}.log" -delete

log_message "Log cleanup finished successfully"
