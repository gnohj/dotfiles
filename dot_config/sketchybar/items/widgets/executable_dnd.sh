#!/bin/bash
# Refresh the DnD widget icon color based on macOS Focus state.
# DnD is on when ~/Library/DoNotDisturb/DB/Assertions.json has any entries
# in data[0].storeAssertionRecords.

export PATH="/run/current-system/sw/bin:/opt/homebrew/bin:/usr/bin:/bin:$PATH"

source "$HOME/.config/sketchybar/config/colors.sh"

NAME="${NAME:-widgets.dnd}"
ASSERTIONS_FILE="$HOME/Library/DoNotDisturb/DB/Assertions.json"

# DnD is on when storeAssertionRecords has at least one active entry. macOS
# moves invalidated assertions out of this list, so a non-zero count IS the
# truth (don't compare timestamps — assertion+invalidation often share a ts).
state="off"
if [ -r "$ASSERTIONS_FILE" ]; then
  state=$(plutil -convert json -o - "$ASSERTIONS_FILE" 2>/dev/null \
    | jq -r '(.data[0].storeAssertionRecords // []) | if length > 0 then "on" else "off" end')
  state="${state:-off}"
fi

if [ "$state" = "on" ]; then
  sketchybar --set "$NAME" icon.color="$MAGENTA"
else
  sketchybar --set "$NAME" icon.color="$YELLOW"
fi
