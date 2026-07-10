#!/bin/bash
export PATH="$HOME/.local/bin:/run/current-system/sw/bin:/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:$HOME/.cargo/bin:$PATH"

source "$HOME/.config/sketchybar/config/colors.sh"

NAME="${NAME:-widgets.tmux_dash_notification}"

# Check if tmux-dash is available
if ! command -v tmux-dash &>/dev/null; then
  sketchybar --set "$NAME" drawing=off
  exit 0
fi

# Check if tmux is running
if ! tmux list-sessions &>/dev/null 2>&1; then
  sketchybar --set "$NAME" drawing=off
  exit 0
fi

# Get agent data from tmux-dash
DASH_JSON=$(tmux-dash json 2>/dev/null)

if [[ -z "$DASH_JSON" || "$DASH_JSON" == "null" ]]; then
  sketchybar --set "$NAME" drawing=off
  exit 0
fi

TOTAL=$(echo "$DASH_JSON" | jq '.sessions | length')
WORKING=$(echo "$DASH_JSON" | jq '[.sessions[] | select(.status == "Working")] | length')
INPUT=$(echo "$DASH_JSON" | jq '[.sessions[] | select(.status == "Input")] | length')
IDLE=$(echo "$DASH_JSON" | jq '[.sessions[] | select(.status == "Idle")] | length')

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
