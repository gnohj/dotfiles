#!/bin/bash
# Focus state via Control Center's pref — the DoNotDisturb DB is TCC-walled from sketchybar. Needs the Focus menu-bar item on "Show When Active".

export PATH="/run/current-system/sw/bin:/opt/homebrew/bin:/usr/bin:/bin:$PATH"

source "$HOME/.config/sketchybar/config/colors.sh"

NAME="${NAME:-widgets.dnd}"
CACHE_DIR="$HOME/.cache/sketchybar"
STATE_FILE="$CACHE_DIR/dnd_state"
CLICK_TS="$CACHE_DIR/dnd_click_ts"
mkdir -p "$CACHE_DIR"

read_cache() {
  local s="off"
  [ -r "$STATE_FILE" ] && s="$(cat "$STATE_FILE" 2>/dev/null)"
  printf '%s' "${s:-off}"
}

# Just after a click, trust the click cache until Control Center's pref catches up (avoids a flicker).
if [ -n "$(find "$CLICK_TS" -newermt '-8 seconds' 2>/dev/null)" ]; then
  state="$(read_cache)"
else
  val="$(defaults read com.apple.controlcenter "NSStatusItem Visible FocusModes" 2>/dev/null)"
  case "$val" in
    1) state="on" ;;
    0) state="off" ;;
    *) state="$(read_cache)" ;;
  esac
  echo "$state" >"$STATE_FILE"
fi

if [ "$state" = "on" ]; then
  sketchybar --set "$NAME" icon.color="$MAGENTA"
else
  sketchybar --set "$NAME" icon.color="$YELLOW"
fi
