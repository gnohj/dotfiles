#!/bin/bash
export PATH="/run/current-system/sw/bin:/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:$PATH"

source "$HOME/.config/sketchybar/config/colors.sh"

NAME="${NAME:-widgets.tailscale}"

# nf-fa-connectdevelop mesh glyph as raw UTF-8 bytes — macOS bash 3.2 has no $'\u'.
ICON=$'\xef\x88\x8e'

TS="$(command -v tailscale || echo '/Applications/Tailscale.app/Contents/MacOS/Tailscale')"

if [ ! -x "$TS" ]; then
  sketchybar --set "$NAME" drawing=off
  exit 0
fi

json="$("$TS" status --json 2>/dev/null)"
state="$(printf '%s' "$json" | jq -r '.BackendState // "NoState"' 2>/dev/null)"
exit_node="$(printf '%s' "$json" | jq -r 'first(.Peer[]? | select(.ExitNode==true) | .HostName) // ""' 2>/dev/null)"

case "$state" in
  Running)
    if [ -n "$exit_node" ]; then
      sketchybar --set "$NAME" drawing=on icon="$ICON" icon.color="$GREEN" \
        label="$exit_node" label.color="$GREEN" label.drawing=on
    else
      sketchybar --set "$NAME" drawing=on icon="$ICON" icon.color="$GREEN" label.drawing=off
    fi
    ;;
  Starting | Stopping)
    sketchybar --set "$NAME" drawing=on icon="$ICON" icon.color="$YELLOW" \
      label="…" label.color="$YELLOW" label.drawing=on ;;
  *)
    sketchybar --set "$NAME" drawing=on icon="$ICON" icon.color="$RED" label.drawing=off ;;
esac
