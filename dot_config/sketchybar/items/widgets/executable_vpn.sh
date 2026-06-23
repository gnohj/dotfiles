#!/bin/bash
# Refresh the VPN widget from the Private Internet Access CLI (piactl).
#   piactl get connectionstate  -> Connected | Connecting | Disconnected | ...
#   piactl get region           -> region id, e.g. "ca-toronto", "us-chicago"
#
# Color = connection state (green connected, yellow transitioning, red exposed),
# label = exit country code derived from the region id's prefix.

export PATH="/run/current-system/sw/bin:/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:$PATH"

source "$HOME/.config/sketchybar/config/colors.sh"

NAME="${NAME:-widgets.vpn}"

# Nerd Font shield glyphs (mirror config/icons.lua vpn.on / vpn.off)
ICON_ON="󰦝"
ICON_OFF="󰦞"

PIACTL="$(command -v piactl || echo '/Applications/Private Internet Access.app/Contents/MacOS/piactl')"

if [ ! -x "$PIACTL" ]; then
  sketchybar --set "$NAME" icon="$ICON_OFF" icon.color="$GREY" \
    label="n/a" label.color="$GREY"
  exit 0
fi

state="$("$PIACTL" get connectionstate 2>/dev/null)"
region="$("$PIACTL" get region 2>/dev/null)"

# Country code = region prefix before the first - or _, uppercased (ca-toronto -> CA)
code="$(printf '%s' "$region" | sed -E 's/[-_].*//' | tr '[:lower:]' '[:upper:]')"
[ -z "$code" ] && code="??"

case "$state" in
  Connected)
    sketchybar --set "$NAME" icon="$ICON_ON" icon.color="$GREEN" \
      label="$code" label.color="$GREEN" ;;
  Connecting | Disconnecting | DisconnectingToReconnect | Interrupting | StillNeedsRetry)
    sketchybar --set "$NAME" icon="$ICON_OFF" icon.color="$YELLOW" \
      label="…" label.color="$YELLOW" ;;
  *)
    # Disconnected / Interrupted / unknown -> not protected, show selected region.
    sketchybar --set "$NAME" icon="$ICON_OFF" icon.color="$RED" \
      label="$code" label.color="$RED" ;;
esac
