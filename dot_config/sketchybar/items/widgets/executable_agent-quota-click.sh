#!/usr/bin/env bash
# Builds the agent-quota popover rows from the cache the widget script writes.

export PATH="/opt/homebrew/bin:$PATH"

source "$HOME/.config/sketchybar/config/colors.sh"

CACHE="$HOME/.logs/sketchybar/agent_quota.tsv"
NAME="${NAME:-agent_quota}"

# One monospace label per row: cross-item alignment clips at the popup edge, a single sized box does not.
ROW_FONT="SpaceMono Nerd Font:Regular:12.0"
ROW_WIDTH=400
row_fmt() { printf '%-16s %-21s %5s  %-7s' "$1" "$2" "$3" "$4"; }

# Refresh first so opening the popover never shows a poll that is up to 5 minutes old.
"$HOME/.config/sketchybar/items/widgets/agent-quota.sh" >/dev/null 2>&1

args=(--remove '/agent_quota\.row\..*/' --set "$NAME" popup.drawing=toggle)

args+=(--add item agent_quota.row.hdr "popup.$NAME"
  --set agent_quota.row.hdr
  icon.drawing=off
  label="$(row_fmt ACCOUNT WINDOW LEFT RESETS)"
  label.font="$ROW_FONT"
  label.width="$ROW_WIDTH"
  label.align=left
  label.color="$GREY")

i=0
while IFS=$'\t' read -r prov win pct reset; do
  [ -n "$prov" ] || continue

  if [ "$pct" -eq "$pct" ] 2>/dev/null; then
    shown="$pct%"
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

sketchybar -m "${args[@]}" >/dev/null
