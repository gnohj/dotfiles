#!/bin/bash
export PATH="/opt/homebrew/bin:/usr/local/bin:$PATH"
export HOMEBREW_NO_AUTO_UPDATE="1"

source "$HOME/.config/sketchybar/config/colors.sh"

# echo "Script triggered with NAME: $NAME" >>/tmp/brew_debug.log
# echo "Sender: $SENDER" >>/tmp/brew_debug.log

# Force brew to use full path and update first if triggered by event
if [[ "$SENDER" == "brew_update" ]]; then
  # echo "Event trigger detected - running brew update first" >>/tmp/brew_debug.log
  /opt/homebrew/bin/brew update >/dev/null 2>&1
fi

# Get outdated packages with full path
OUTDATED_OUTPUT="$(/opt/homebrew/bin/brew outdated 2>&1)"
# echo "brew outdated output: '$OUTDATED_OUTPUT'" >>/tmp/brew_debug.log

# Fix the COUNT calculation
if [[ -z "$OUTDATED_OUTPUT" || "$OUTDATED_OUTPUT" == "" ]]; then
  COUNT=0
else
  # Count non-empty lines
  COUNT=$(echo "$OUTDATED_OUTPUT" | grep -c '^[[:space:]]*[^[:space:]]')
fi

# echo "COUNT: $COUNT" >>/tmp/brew_debug.log

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

# echo "Setting: sketchybar --set $NAME label=$COUNT icon.color=$COLOR" >>/tmp/brew_debug.log
sketchybar --set $NAME label=$COUNT label.color=$COLOR icon.color=$MAGENTA
