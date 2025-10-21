#!/bin/bash
export PATH="$HOME/.local/bin:/opt/homebrew/bin:/usr/local/bin:$PATH"

# Activate mise to get full shell integration
eval "$($HOME/.local/bin/mise activate bash)"

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

log_message "INFO" "Starting mise update check (Sender: $SENDER)"

# Check for outdated mise tools - aggregate from global + known project directories
# mise only checks configs in current directory tree, so we need to check each project
OUTDATED_LINES=""

# Check global config
cd "$HOME" || exit 1
GLOBAL_OUT="$(command mise outdated 2>&1)"
if [[ ! "$GLOBAL_OUT" =~ "All tools are up to date" ]]; then
  OUTDATED_LINES+="$GLOBAL_OUT"$'\n'
fi

# Check known project directories
for PROJECT_DIR in "$HOME/Developer/inferno-monorepo"; do
  if [[ -d "$PROJECT_DIR" ]]; then
    cd "$PROJECT_DIR" || continue
    PROJECT_OUT="$(command mise outdated 2>&1)"
    if [[ ! "$PROJECT_OUT" =~ "All tools are up to date" ]]; then
      OUTDATED_LINES+="$PROJECT_OUT"$'\n'
    fi
  fi
done

OUTDATED_OUTPUT="$OUTDATED_LINES"

# Count outdated tools
if [[ -z "$OUTDATED_OUTPUT" || "$OUTDATED_OUTPUT" =~ "All tools are up to date" ]]; then
  COUNT=0
else
  # Count non-empty lines (excluding header line that starts with "name" or "Tool")
  COUNT=$(echo "$OUTDATED_OUTPUT" | grep -v "^name" | grep -v "^Tool" | grep -v "^$" | wc -l | tr -d ' ')
fi

COLOR=$RED
case "$COUNT" in
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
