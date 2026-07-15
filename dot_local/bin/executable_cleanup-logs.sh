#!/bin/bash

# Cleans up old log files from ~/.logs; keeps current + previous month only.

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

CURRENT_MONTH=$(date '+%Y%m')
PREVIOUS_MONTH=$(date -v-1m '+%Y%m')

log_message "Keeping logs from: $PREVIOUS_MONTH and $CURRENT_MONTH"

DELETED_COUNT=0
KEPT_COUNT=0
TRUNCATED_COUNT=0

# Size cap catches runaway-growth bugs that the mtime check below
# can't (an actively-written log never ages out). Tail-truncates to
# keep the last 10 MB for inspection.
SIZE_CAP_BYTES=$((100 * 1024 * 1024))
SIZE_KEEP_BYTES=$((10  * 1024 * 1024))

while IFS= read -r -d '' logfile; do
  if [[ $(uname) == "Darwin" ]]; then
    SIZE=$(stat -f %z "$logfile" 2>/dev/null || echo 0)
  else
    SIZE=$(stat -c %s "$logfile" 2>/dev/null || echo 0)
  fi
  if [[ $SIZE -gt $SIZE_CAP_BYTES ]]; then
    TRUNCATED_COUNT=$((TRUNCATED_COUNT + 1))
    log_message "TRUNCATE: $logfile (${SIZE} bytes → last 10 MB)"
    TMP_FILE="${logfile}.cleanup.tmp"
    if tail -c "$SIZE_KEEP_BYTES" "$logfile" > "$TMP_FILE" 2>/dev/null; then
      mv -f "$TMP_FILE" "$logfile"
    else
      rm -f "$TMP_FILE"
      log_message "WARN: tail-truncate failed for $logfile — skipping"
    fi
    continue   # skip mtime/filename rules below
  fi

  if [[ "$logfile" =~ _([0-9]{6})\.log$ ]]; then
    FILE_MONTH="${BASH_REMATCH[1]}"

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

log_message "Cleanup complete: Deleted $DELETED_COUNT files, Truncated $TRUNCATED_COUNT files, Kept $KEPT_COUNT files"

# Clean up empty directories in ~/.logs
find "$LOG_DIR" -type d -empty -delete

log_message "Removed empty directories"

# Keep only current month's cleanup log
find "$CLEANUP_LOG_DIR" -type f -name "cleanup_*.log" ! -name "cleanup_${CURRENT_MONTH}.log" -delete

log_message "Log cleanup finished successfully"
