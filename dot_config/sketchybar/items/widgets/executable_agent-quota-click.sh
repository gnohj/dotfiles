#!/usr/bin/env bash
# Builds the agent-quota popover rows from the cache the widget script writes.

export PATH="/opt/homebrew/bin:$PATH"

source "$HOME/.config/sketchybar/config/colors.sh"

CACHE="$HOME/.logs/sketchybar/agent_quota.tsv"
NAME="${NAME:-agent_quota}"

# One monospace label per row: cross-item alignment clips at the popup edge, a single sized box does not.
ROW_FONT="SpaceMono Nerd Font:Regular:12.0"
# 50 columns of SpaceMono 12; widest cells are "Spark session" and Copilot's credit count.
ROW_WIDTH=385
row_fmt() { printf '%-15s %-13s %12s  %-6s' "$1" "$2" "$3" "$4"; }

args=(--remove '/agent_quota\.row\..*/')
if [ "$(sketchybar --query "$NAME" | jq -r '.popup.drawing')" = "on" ]; then
  sketchybar --set "$NAME" popup.drawing=off
  exit 0
fi
"$HOME/.config/sketchybar/items/widgets/popup-close-others.sh" "$NAME"

args+=(--add item agent_quota.row.hdr "popup.$NAME"
  --set agent_quota.row.hdr
  icon="$(row_fmt ACCOUNT WINDOW "USED %" RESETS)"
  icon.font="$ROW_FONT"
  icon.width=$((ROW_WIDTH - 12))
  icon.align=left
  icon.padding_left=12 icon.padding_right=0
  icon.color="$GREY"
  label="×" label.align=center label.width=40 label.padding_left=0 label.padding_right=0 label.color="$RED" label.font.size=22
  click_script="sketchybar --set $NAME popup.drawing=off")

i=0
while IFS=$'\t' read -r prov win pct reset; do
  [ -n "$prov" ] || continue

  if [ "$pct" -eq "$pct" ] 2>/dev/null; then
    # Cache stores remaining, which the colour thresholds below want; the column shows its inverse.
    shown="$((100 - pct))%"
    if [ "$pct" -le 15 ]; then
      COLOR="$RED"
    elif [ "$pct" -le 35 ]; then
      COLOR="$ORANGE"
    elif [ "$pct" -le 60 ]; then
      COLOR="$YELLOW"
    else
      COLOR="$GREEN"
    fi
  else
    shown="$pct"
    COLOR="$GREY"
  fi

  args+=(--add item "agent_quota.row.$i" "popup.$NAME"
    --set "agent_quota.row.$i"
    icon.drawing=off
    label="$(row_fmt "$prov" "$win" "$shown" "$reset")"
    label.font="$ROW_FONT"
    label.width="$ROW_WIDTH"
    label.align=left
    label.color="$COLOR")
  i=$((i + 1))
done <"$CACHE"

if [ "$i" -eq 0 ]; then
  args+=(--add item agent_quota.row.0 "popup.$NAME"
    --set agent_quota.row.0
    icon.drawing=off
    label="$(row_fmt "no quota data" "" "" "")"
    label.font="$ROW_FONT"
    label.width="$ROW_WIDTH"
    label.align=left
    label.color="$GREY")
fi

args+=(--set "$NAME" popup.drawing=on)
sketchybar -m "${args[@]}" >/dev/null
