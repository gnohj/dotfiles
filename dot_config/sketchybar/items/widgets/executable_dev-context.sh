#!/bin/bash
# Repaint the dev-context widget from the selected token, glyph + color only (the box name lives in the picker's SESSION section): local=laptop/green, ssh=server/purple, tailscale=mesh/purple.

export PATH="/run/current-system/sw/bin:/opt/homebrew/bin:$HOME/.local/bin:/usr/bin:/bin:$PATH"

source "$HOME/.config/sketchybar/config/colors.sh"

NAME="${NAME:-widgets.dev_context}"

GLYPH_LOCAL="󰌢" # nf-md-laptop
GLYPH_SSH="󰒋"   # nf-md-server
GLYPH_TS="󰛳"    # nf-md-web

kind="$(dev-context kind 2>/dev/null || echo local)"

# Local = green (home base); pointed at any remote box = purple.
case "$kind" in
  ssh)
    sketchybar --set "$NAME" icon="$GLYPH_SSH" icon.color="$MAGENTA" label.drawing=off ;;
  tailscale)
    sketchybar --set "$NAME" icon="$GLYPH_TS" icon.color="$MAGENTA" label.drawing=off ;;
  *)
    sketchybar --set "$NAME" icon="$GLYPH_LOCAL" icon.color="$GREEN" label.drawing=off ;;
esac
