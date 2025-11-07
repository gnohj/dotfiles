#!/bin/bash
export PATH="/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:$HOME/.local/share/mise/shims:$PATH"
export HOMEBREW_NO_AUTO_UPDATE="1"

source "$HOME/.config/sketchybar/config/colors.sh"

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

log_message "INFO" "Starting package update check (Sender: $SENDER)"

BREW_COUNT=0
MAS_COUNT=0
MISE_COUNT=0
TIMEOUT_OCCURRED=0

# Check Homebrew updates
log_message "INFO" "Checking Homebrew..."
if [[ "$SENDER" == "package_update" ]]; then
  run_with_timeout "/opt/homebrew/bin/brew update >/dev/null 2>&1"
fi

BREW_OUTPUT=$(run_with_timeout "/opt/homebrew/bin/brew outdated 2>&1")
BREW_EXIT_CODE=$?

if [ $BREW_EXIT_CODE -eq 124 ]; then
  TIMEOUT_OCCURRED=1
  log_message "WARN" "Brew check timed out"
elif [[ -n "$BREW_OUTPUT" && "$BREW_OUTPUT" != "" ]]; then
  BREW_COUNT=$(echo "$BREW_OUTPUT" | grep -c '^[[:space:]]*[^[:space:]]')
fi
log_message "INFO" "Brew outdated: $BREW_COUNT"

# Check Mac App Store updates
log_message "INFO" "Checking Mac App Store..."
MAS_OUTPUT=$(run_with_timeout "/opt/homebrew/bin/mas outdated 2>/dev/null")
MAS_EXIT_CODE=$?

if [ $MAS_EXIT_CODE -eq 124 ]; then
  TIMEOUT_OCCURRED=1
  log_message "WARN" "MAS check timed out"
elif [[ -n "$MAS_OUTPUT" && "$MAS_OUTPUT" != "" ]]; then
  MAS_COUNT=$(echo "$MAS_OUTPUT" | grep -c '^[[:space:]]*[^[:space:]]')
fi
log_message "INFO" "MAS outdated: $MAS_COUNT"

# Check mise updates
log_message "INFO" "Checking mise..."
MISE_OUTDATED=""

# Check global mise config
if [ -f "$HOME/.config/mise/config.toml" ]; then
  GLOBAL_CHECK=$(run_with_timeout "cd $HOME && mise outdated 2>/dev/null")
  if [ $? -eq 124 ]; then
    TIMEOUT_OCCURRED=1
    log_message "WARN" "Mise global check timed out"
  elif [[ -n "$GLOBAL_CHECK" ]]; then
    MISE_OUTDATED="$MISE_OUTDATED$GLOBAL_CHECK"
  fi
fi

# Check known project directories for mise configs
for PROJECT_DIR in "$HOME/gnohj-monorepo" "$HOME/second-brain"; do
  if [ -f "$PROJECT_DIR/.mise.toml" ] || [ -f "$PROJECT_DIR/.tool-versions" ]; then
    PROJECT_CHECK=$(run_with_timeout "cd $PROJECT_DIR && mise outdated 2>/dev/null")
    if [ $? -eq 124 ]; then
      TIMEOUT_OCCURRED=1
      log_message "WARN" "Mise check timed out for $PROJECT_DIR"
    elif [[ -n "$PROJECT_CHECK" ]]; then
      MISE_OUTDATED="$MISE_OUTDATED$PROJECT_CHECK"
    fi
  fi
done

if [[ -n "$MISE_OUTDATED" ]]; then
  MISE_COUNT=$(echo "$MISE_OUTDATED" | grep -c '^[[:space:]]*[^[:space:]]')
fi
log_message "INFO" "Mise outdated: $MISE_COUNT"

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
