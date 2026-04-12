#!/bin/bash
export PATH="$HOME/.cargo/bin:/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:$PATH"

source "$HOME/.config/sketchybar/config/colors.sh"

NAME="${NAME:-widgets.recon_notification}"

# Check if recon is available
if ! command -v recon &>/dev/null; then
  sketchybar --set "$NAME" drawing=off
  exit 0
fi

# Check if tmux is running
if ! tmux list-sessions &>/dev/null 2>&1; then
  sketchybar --set "$NAME" drawing=off
  exit 0
fi

# Get agent data from recon
RECON_JSON=$(recon json 2>/dev/null)

if [[ -z "$RECON_JSON" || "$RECON_JSON" == "null" ]]; then
  sketchybar --set "$NAME" drawing=off
  exit 0
fi

TOTAL=$(echo "$RECON_JSON" | jq '.sessions | length')
WORKING=$(echo "$RECON_JSON" | jq '[.sessions[] | select(.status == "Working")] | length')
INPUT=$(echo "$RECON_JSON" | jq '[.sessions[] | select(.status == "Input")] | length')
IDLE=$(echo "$RECON_JSON" | jq '[.sessions[] | select(.status == "Idle")] | length')

# Hide if no agents
if [ "$TOTAL" -eq 0 ]; then
  sketchybar --set "$NAME" drawing=off
  exit 0
fi

# Show widget
sketchybar --set "$NAME" drawing=on

# Icon color priority: Input (red) > Working (green) > Idle (grey)
if [ "$INPUT" -gt 0 ]; then
  ICON_COLOR=$RED
elif [ "$WORKING" -gt 0 ]; then
  ICON_COLOR=$GREEN
else
  ICON_COLOR=$GREY
fi

sketchybar --set "$NAME" \
  label="$TOTAL" \
  label.color="$WHITE" \
  icon.color="$ICON_COLOR"
