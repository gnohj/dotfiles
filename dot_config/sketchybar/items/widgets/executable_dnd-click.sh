#!/bin/bash
# Toggle Focus via the FocusOn/FocusOff Shortcuts. Cache decides direction because the DoNotDisturb DB is TCC-walled from sketchybar.

export PATH="/run/current-system/sw/bin:/opt/homebrew/bin:/usr/bin:/bin:$PATH"

source "$HOME/.config/sketchybar/config/colors.sh"

NAME="${NAME:-widgets.dnd}"
STATE_FILE="$HOME/.cache/sketchybar/dnd_state"
mkdir -p "$(dirname "$STATE_FILE")"

LOG="$HOME/.logs/sketchybar/dnd_click.log"
mkdir -p "$(dirname "$LOG")"
ts() { date '+%Y-%m-%d %H:%M:%S'; }

echo "[$(ts)] click fired" >>"$LOG"

# Single-instance lock (atomic mkdir; macOS has no flock). Stale locks >10s auto-clear.
LOCK="/tmp/sketchybar-dnd-click.lock"
if ! mkdir "$LOCK" 2>/dev/null; then
  if [ -z "$(find "$LOCK" -newermt '-10 seconds' 2>/dev/null)" ]; then
    rmdir "$LOCK" 2>/dev/null
    mkdir "$LOCK" 2>/dev/null || { echo "[$(ts)] click ignored — lock contention" >>"$LOG"; exit 0; }
  else
    echo "[$(ts)] click ignored — toggle already in flight" >>"$LOG"
    exit 0
  fi
fi
trap 'rmdir "$LOCK" 2>/dev/null' EXIT

state="off"
[ -r "$STATE_FILE" ] && state="$(cat "$STATE_FILE" 2>/dev/null)"
state="${state:-off}"

if [ "$state" = "on" ]; then
  TARGET_SHORTCUT="FocusOff"
  new_state="off"
  new_color="$YELLOW"
else
  TARGET_SHORTCUT="FocusOn"
  new_state="on"
  new_color="$MAGENTA"
fi

echo "[$(ts)] state=$state, running $TARGET_SHORTCUT" >>"$LOG"

if ! shortcuts run "$TARGET_SHORTCUT" 2>>"$LOG"; then
  echo "[$(ts)] $TARGET_SHORTCUT failed (create FocusOn + FocusOff in Shortcuts.app)" >>"$LOG"
  exit 0
fi

# Marker makes dnd.sh trust this cache briefly while Control Center's pref catches up.
echo "$new_state" >"$STATE_FILE"
touch "$(dirname "$STATE_FILE")/dnd_click_ts"
sketchybar --set "$NAME" icon.color="$new_color"

echo "[$(ts)] click finished — now $new_state" >>"$LOG"
