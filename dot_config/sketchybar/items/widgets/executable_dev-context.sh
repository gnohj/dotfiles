#!/bin/bash
# Repaint the dev-context widget from the selected token: local=laptop/red, ssh=server/purple, tailscale=mesh/purple.

export PATH="/run/current-system/sw/bin:/opt/homebrew/bin:$HOME/.local/bin:/usr/bin:/bin:$PATH"

source "$HOME/.config/sketchybar/config/colors.sh"

NAME="${NAME:-widgets.dev_context}"

GLYPH_LOCAL="󰌢" # nf-md-laptop
GLYPH_SSH="󰒋"   # nf-md-server
GLYPH_TS="󰛳"    # nf-md-web

kind="$(dev-context kind 2>/dev/null || echo local)"
target="$(dev-context target 2>/dev/null || echo '')"

# Local = red (not pointed anywhere remote); connected (ssh/tailscale) = purple.
case "$kind" in
  ssh)
    sketchybar --set "$NAME" icon="$GLYPH_SSH" icon.color="$MAGENTA" \
      label="$target" label.color="$MAGENTA" label.drawing=on ;;
  tailscale)
    sketchybar --set "$NAME" icon="$GLYPH_TS" icon.color="$MAGENTA" \
      label="$target" label.color="$MAGENTA" label.drawing=on ;;
  *)
    sketchybar --set "$NAME" icon="$GLYPH_LOCAL" icon.color="$RED" label.drawing=off ;;
esac
