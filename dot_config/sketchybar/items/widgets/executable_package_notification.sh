#!/bin/bash
export PATH="/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:$HOME/.local/share/mise/shims:$PATH"
export HOMEBREW_NO_AUTO_UPDATE="1"

source "$HOME/.config/sketchybar/config/colors.sh"

# Fallback widget name if not set by sketchybar
NAME="${NAME:-widgets.package_notification}"

LOG_DIR="$HOME/.logs/sketchybar"
mkdir -p "$LOG_DIR"
LOG_FILE="$LOG_DIR/packages_$(date '+%Y%m').log"

log_message() {
  local level="$1"
  local message="$2"
  local timestamp
  timestamp=$(date '+%Y-%m-%d %H:%M:%S')
  echo "[$timestamp] [$level] [PACKAGES] $message" >>"$LOG_FILE"
}

# Timeout wrapper function (10 second timeout)
run_with_timeout() {
  local timeout=10
  local cmd="$1"
  local tmpfile="/tmp/package_notification_$$"

  # Run command in background and capture output (disable tracing)
  (set +x; eval "$cmd" > "$tmpfile" 2>&1) &
  local pid=$!

  # Wait for command with timeout (0.1s intervals)
  local elapsed=0
  while kill -0 $pid 2>/dev/null; do
    if [ $elapsed -ge $((timeout * 10)) ]; then
      kill -9 $pid 2>/dev/null
      wait $pid 2>/dev/null
      rm -f "$tmpfile"
      log_message "WARN" "Command timed out after ${timeout}s: $cmd"
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

# log_message "INFO" "Starting package update check (Sender: $SENDER)"

BREW_COUNT=0
MAS_COUNT=0
MISE_COUNT=0
TIMEOUT_OCCURRED=0

# Check Homebrew updates
# log_message "INFO" "Checking Homebrew..."
if [[ "$SENDER" == "package_update" ]]; then
  run_with_timeout "/opt/homebrew/bin/brew update >/dev/null 2>&1"
fi

# Run brew through zsh for proper environment
BREW_OUTPUT=$(zsh -c 'arch -arm64 /opt/homebrew/bin/brew outdated 2>/dev/null')

log_message "DEBUG" "Raw brew output: '$BREW_OUTPUT'"

if [[ -n "$BREW_OUTPUT" && "$BREW_OUTPUT" != "" ]]; then
  BREW_COUNT=$(echo "$BREW_OUTPUT" | grep -c '^[[:space:]]*[^[:space:]]')
  log_message "DEBUG" "Brew count: $BREW_COUNT"
fi

# Check Mac App Store updates - run through zsh for proper environment
MAS_OUTPUT=$(zsh -c 'mas outdated 2>/dev/null')

log_message "DEBUG" "Raw mas output: '$MAS_OUTPUT'"

if [[ -n "$MAS_OUTPUT" && "$MAS_OUTPUT" != "" ]]; then
  MAS_COUNT=$(echo "$MAS_OUTPUT" | grep -c '^[[:space:]]*[^[:space:]]')
  log_message "DEBUG" "MAS count: $MAS_COUNT"
fi

# Check mise updates - run through zsh for proper environment
MISE_OUTPUT=$(zsh -c 'mise outdated 2>/dev/null')

log_message "DEBUG" "Raw mise output: '$MISE_OUTPUT'"

if [[ -n "$MISE_OUTPUT" && "$MISE_OUTPUT" != "" ]]; then
  MISE_COUNT=$(echo "$MISE_OUTPUT" | grep -c '^[[:space:]]*[^[:space:]]')
  log_message "DEBUG" "Mise count: $MISE_COUNT"
fi

# Calculate total count
TOTAL_COUNT=$((BREW_COUNT + MAS_COUNT + MISE_COUNT))

# Determine color based on total count
COLOR=$RED
LABEL="$TOTAL_COUNT"

if [ $TIMEOUT_OCCURRED -eq 1 ]; then
  COLOR=$GREY
  LABEL="?"
elif [ $TOTAL_COUNT -eq 0 ]; then
  COLOR=$GREEN
  LABEL="􀆅"
elif [ $TOTAL_COUNT -le 9 ]; then
  COLOR=$WHITE
elif [ $TOTAL_COUNT -le 29 ]; then
  COLOR=$ORANGE
else
  COLOR=$RED
fi

# Update sketchybar with single combined count
sketchybar --set "$NAME" \
  label="$LABEL" \
  label.color="$COLOR" \
  icon.color="$MAGENTA"

log_message "INFO" "Package check completed - Total: $TOTAL_COUNT (Brew: $BREW_COUNT, MAS: $MAS_COUNT, Mise: $MISE_COUNT)"
