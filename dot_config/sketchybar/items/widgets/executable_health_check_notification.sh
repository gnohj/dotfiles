#!/bin/bash
# Health check: scan recent logs for errors and update sketchybar widget
# Only reports errors from the last 30 minutes
#
# Monitored (have timestamped monthly logs in ~/.logs/):
#   - github-auto-push  (~/.logs/git_autopush/autopush_YYYYMM.log)
#   - sketchybar         (~/.logs/sketchybar/*_YYYYMM.log)
#   - sketchybar-watchdog (~/.logs/sketchybar/watchdog_YYYYMM.log)
#   - sketchybar widgets  (~/.logs/sketchybar/pr_review_YYYYMM.log, dirty_repos_YYYYMM.log, etc.)
#
# NOT monitored (no timestamped logs, only launchagent.err.log which is noisy/append-only):
#   - skhd               (~/.logs/skhd/ — binary, no monthly logs)
#   - borders             (~/.logs/borders/ — binary, no monthly logs)
#   - log-cleanup         (~/.logs/cleanup/ — no monthly logs)
#   - kanata              (/var/log/ — runs as root, not in ~/.logs/)
#   - fitness-sync        (moved to Claude Desktop Cowork)
shopt -s nullglob

export PATH="/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:$PATH"

source "$HOME/.config/sketchybar/config/colors.sh"

NAME="${NAME:-widgets.health_check_notification}"

LOG_DIR="$HOME/.logs"
HEALTH_LOG="$LOG_DIR/health-check/health_$(date '+%Y%m').log"
mkdir -p "$LOG_DIR/health-check"

LOOKBACK_MIN=30
CUTOFF=$(date -v-${LOOKBACK_MIN}M '+%Y-%m-%d %H:%M:%S')

log_message() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$HEALTH_LOG"
}

# Collect recent errors from all log dirs
ERROR_SOURCES=()

scan_log() {
  local file="$1"
  local source="$2"
  [ ! -f "$file" ] && return

  while IFS= read -r line; do
    ts=$(echo "$line" | grep -oE '^\[?[0-9]{4}-[0-9]{2}-[0-9]{2} [0-9]{2}:[0-9]{2}:[0-9]{2}\]?' | tr -d '[]')
    [ -z "$ts" ] && continue
    if [[ "$ts" > "$CUTOFF" || "$ts" == "$CUTOFF" ]]; then
      ERROR_SOURCES+=("$source")
      return
    fi
  done < <(grep -E '\[ERROR\]|ERROR:|FATAL|FAIL[^_]' "$file" 2>/dev/null | grep -iv 'KEEP:.*error.log\|NOTIFY.*Error\|already focused\|non-zero')
}

# Scan all monthly logs (current month)
MONTH=$(date '+%Y%m')
for dir in "$LOG_DIR"/*/; do
  dir_name=$(basename "$dir")
  # Skip own logs to avoid self-triggering
  [[ "$dir_name" == "health-check" ]] && continue
  for f in "$dir"*"$MONTH"*.log; do
    [ -f "$f" ] 2>/dev/null && scan_log "$f" "$dir_name"
  done 2>/dev/null
  # Skip launchagent.err.log — these are append-only and noisy
  # Real errors are captured in timestamped monthly logs above
done

# Deduplicate sources
ERROR_SOURCES=($(printf '%s\n' "${ERROR_SOURCES[@]}" | sort -u))
ERROR_COUNT=${#ERROR_SOURCES[@]}

# Update sketchybar
if [ "$ERROR_COUNT" -eq 0 ]; then
  COLOR=$GREEN
  LABEL="􀆅"
  log_message "OK: No errors in last ${LOOKBACK_MIN}m"
else
  COLOR=$RED
  LABEL="$ERROR_COUNT"
  SOURCES=$(printf '%s\n' "${ERROR_SOURCES[@]}" | tr '\n' ',' | sed 's/,$//')
  log_message "WARN: $ERROR_COUNT service(s) with errors: $SOURCES"
fi

sketchybar --set "$NAME" \
  label="$LABEL" \
  label.color="$COLOR"
