#!/bin/bash
export PATH="/run/current-system/sw/bin:/opt/homebrew/bin:/usr/local/bin:$PATH"

# Activate mise to get full shell integration
eval "$(mise activate bash)"

source "$HOME/.config/sketchybar/config/colors.sh"

LOG_DIR="$HOME/.logs/sketchybar"
mkdir -p "$LOG_DIR"
LOG_FILE="$LOG_DIR/mise_$(date '+%Y%m').log"

log_message() {
  local level="$1"
  local message="$2"
  local timestamp
  timestamp=$(date '+%Y-%m-%d %H:%M:%S')
  echo "[$timestamp] [$level] [MISE] $message" >>"$LOG_FILE"
}

# Timeout wrapper function (10 second timeout for mise operations)
run_with_timeout() {
  local timeout=10
  local cmd="$1"
  local tmpfile="/tmp/mise_notification_$$"

  # Run command in background and capture output
  (eval "$cmd" > "$tmpfile" 2>&1) &
  local pid=$!

  # Wait for command with timeout (0.1s intervals)
  local elapsed=0
  while kill -0 $pid 2>/dev/null; do
    if [ $elapsed -ge $((timeout * 10)) ]; then
      kill -9 $pid 2>/dev/null
      wait $pid 2>/dev/null
      rm -f "$tmpfile"
      log_message "WARN" "Command timed out after ${timeout}s"
      return 124  # timeout exit code
    fi
    sleep 0.1
    elapsed=$((elapsed + 1))
  done

  # Get command exit code and output
  wait $pid
  local exit_code=$?
  if [ -f "$tmpfile" ]; then
    cat "$tmpfile"
    rm -f "$tmpfile"
  fi
  return $exit_code
}

log_message "INFO" "Starting mise update check (Sender: $SENDER)"

# Check for outdated mise tools - aggregate from global + known project directories
# mise only checks configs in current directory tree, so we need to check each project
OUTDATED_LINES=""
TIMEOUT_OCCURRED=0

# Check global config
cd "$HOME" || exit 1
GLOBAL_OUT=$(run_with_timeout "command mise outdated 2>&1")
if [ $? -eq 124 ]; then
  TIMEOUT_OCCURRED=1
elif [[ ! "$GLOBAL_OUT" =~ "All tools are up to date" ]]; then
  OUTDATED_LINES+="$GLOBAL_OUT"$'\n'
fi

# Check known project directories (only if no timeout yet)
if [ $TIMEOUT_OCCURRED -eq 0 ]; then
  for PROJECT_DIR in "$HOME/Developer/inferno-monorepo"; do
    if [[ -d "$PROJECT_DIR" ]]; then
      cd "$PROJECT_DIR" || continue
      PROJECT_OUT=$(run_with_timeout "command mise outdated 2>&1")
      if [ $? -eq 124 ]; then
        TIMEOUT_OCCURRED=1
        break
      elif [[ ! "$PROJECT_OUT" =~ "All tools are up to date" ]]; then
        OUTDATED_LINES+="$PROJECT_OUT"$'\n'
      fi
    fi
  done
fi

OUTDATED_OUTPUT="$OUTDATED_LINES"

# Count outdated tools
if [ $TIMEOUT_OCCURRED -eq 1 ]; then
  # Timeout occurred - show "?" to indicate unknown state
  COUNT="?"
  log_message "WARN" "Using unknown state due to timeout"
elif [[ -z "$OUTDATED_OUTPUT" || "$OUTDATED_OUTPUT" =~ "All tools are up to date" ]]; then
  COUNT=0
else
  # Count non-empty lines (excluding header line that starts with "name" or "Tool")
  COUNT=$(echo "$OUTDATED_OUTPUT" | grep -v "^name" | grep -v "^Tool" | grep -v "^$" | wc -l | tr -d ' ')
fi

COLOR=$RED
case "$COUNT" in
"?")
  # Timeout - show gray/dim color to indicate unknown state
  COLOR=$GREY
  ;;
[3-5][0-9])
  COLOR=$RED
  ;;
[1-2][0-9])
  COLOR=$ORANGE
  ;;
[1-9])
  COLOR=$WHITE
  ;;
0)
  COLOR=$GREEN
  COUNT=􀆅
  ;;
esac

# Use BLUE for icon color instead of MAGENTA
sketchybar --set "$NAME" label="$COUNT" label.color="$COLOR" icon.color="$BLUE"

log_message "INFO" "Mise check completed - Count: $COUNT"
