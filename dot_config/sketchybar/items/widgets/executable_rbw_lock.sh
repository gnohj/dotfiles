#!/bin/bash
# Toggle the rbw (Bitwarden) vault-lock indicator.
# `rbw unlocked` exits 0 when the vault is unlocked, non-zero when it is locked
# or the agent isn't running. The glyph carries the state and the colour never changes, so the widget stays visible in both states rather than only when locked.

export PATH="/run/current-system/sw/bin:/opt/homebrew/bin:/usr/bin:/bin:$PATH"

source "$HOME/.config/sketchybar/config/colors.sh"

NAME="${NAME:-widgets.rbw_lock}"

# SF Symbols lock.fill / lock.open.fill (mirror config/icons.lua lock.locked / lock.unlocked).
ICON_LOCKED="􀎡"
ICON_UNLOCKED="􀎥"

# ICON_BLUE, not BLUE: BLUE is the palette's aqua (color03) and predates the real blue (color04).
if rbw unlocked >/dev/null 2>&1; then
  sketchybar --set "$NAME" drawing=on icon="$ICON_UNLOCKED" icon.color="$ICON_BLUE"
else
  sketchybar --set "$NAME" drawing=on icon="$ICON_LOCKED" icon.color="$ICON_BLUE"
fi
