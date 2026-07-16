#!/bin/bash
# Refresh the dev-context widget icon + color from ~/.local/state/dev-context (local = laptop, vps = server).

export PATH="/run/current-system/sw/bin:/opt/homebrew/bin:$HOME/.local/bin:/usr/bin:/bin:$PATH"

source "$HOME/.config/sketchybar/config/colors.sh"

NAME="${NAME:-widgets.dev_context}"

# nf-md-laptop (local) / nf-md-server (vps). Swap if your font lacks them.
GLYPH_LOCAL="󰌢"
GLYPH_VPS="󰒋"

context="$(dev-context get 2>/dev/null || echo local)"

if [ "$context" = "vps" ]; then
  sketchybar --set "$NAME" icon="$GLYPH_VPS" icon.color="$BLUE"
else
  sketchybar --set "$NAME" icon="$GLYPH_LOCAL" icon.color="$GREY"
fi
