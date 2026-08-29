#!/bin/bash
# Close every popup except the one being opened. Single source of truth for the owner list, called
# from both the Lua widgets (via lib/popup.lua) and the shell click scripts, so the two cannot drift.
#
#   popup-close-others.sh <item-name-to-keep>
#
# Named, not matched: sketchybar's regex takes no alternation, and `/.*/` would touch every bar item.

export PATH="/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:$PATH"

SELF="${1:-}"

OWNERS="
widgets.wifi
widgets.bluetooth
widgets.battery
widgets.schedules
widgets.volume.bracket
mic
agent_quota
widgets.errors_notification
widgets.cpu
widgets.memory
widgets.disk
"

args=()
for owner in $OWNERS; do
  [ "$owner" = "$SELF" ] && continue
  args+=(--set "$owner" popup.drawing=off)
done

[ ${#args[@]} -gt 0 ] && sketchybar -m "${args[@]}" >/dev/null 2>&1

exit 0
