#!/bin/bash
# Focus state comes from the click cache: the DoNotDisturb DB is TCC-walled from sketchybar, and Control Center's visibility pref is stuck at 1 since macOS 27.

export PATH="/run/current-system/sw/bin:/opt/homebrew/bin:/usr/bin:/bin:$PATH"

NAME="${NAME:-widgets.dnd}"
STATE_FILE="$HOME/.cache/sketchybar/dnd_state"

state="off"
[ -r "$STATE_FILE" ] && state="$(cat "$STATE_FILE" 2>/dev/null)"

if [ "$state" = "on" ]; then
  sketchybar --set "$NAME" drawing=off
else
  sketchybar --set "$NAME" drawing=on
fi
