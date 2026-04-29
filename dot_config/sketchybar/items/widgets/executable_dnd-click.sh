#!/bin/bash
# Toggle macOS Do Not Disturb via Shortcuts based on current state.
# Expects two user-created Shortcuts:
#   FocusOn  — Set Focus → Turn On Do Not Disturb (until Turned Off)
#   FocusOff — Set Focus → Turn Off Do Not Disturb

export PATH="/run/current-system/sw/bin:/opt/homebrew/bin:/usr/bin:/bin:$PATH"

LOG="$HOME/.logs/sketchybar/dnd_click.log"
mkdir -p "$(dirname "$LOG")"
ts() { date '+%Y-%m-%d %H:%M:%S'; }

echo "[$(ts)] click fired" >>"$LOG"

# Single-instance lock (atomic mkdir; macOS doesn't ship `flock`). Stale locks
# older than 10 seconds are auto-cleared.
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

ASSERTIONS_FILE="$HOME/Library/DoNotDisturb/DB/Assertions.json"
state="off"
if [ -r "$ASSERTIONS_FILE" ]; then
  state=$(plutil -convert json -o - "$ASSERTIONS_FILE" 2>/dev/null \
    | jq -r '(.data[0].storeAssertionRecords // []) | if length > 0 then "on" else "off" end')
  state="${state:-off}"
fi

if [ "$state" = "on" ]; then
  TARGET_SHORTCUT="FocusOff"
else
  TARGET_SHORTCUT="FocusOn"
fi

echo "[$(ts)] state=$state, running $TARGET_SHORTCUT" >>"$LOG"

if ! shortcuts run "$TARGET_SHORTCUT" 2>>"$LOG"; then
  echo "[$(ts)] $TARGET_SHORTCUT failed (create FocusOn + FocusOff in Shortcuts.app)" >>"$LOG"
  sketchybar --trigger dnd_changed
  exit 0
fi

# Poll a few times so the icon settles to the new color promptly.
for _ in 1 2 3 4 5; do
  sleep 0.4
  sketchybar --trigger dnd_changed
done

echo "[$(ts)] click finished" >>"$LOG"
