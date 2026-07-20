#!/usr/bin/env bash
# Runaway-process detail popup: one informational row per current runaway (comm · pid · %core, then cwd) from ~/.local/state/runaway/current (written by runaway_notification.sh); any click closes it.
export PATH="/run/current-system/sw/bin:/opt/homebrew/bin:$HOME/.local/bin:/usr/bin:/bin:$PATH"

source "$HOME/.config/sketchybar/config/colors.sh"

NAME="${NAME:-widgets.runaway_notification}"
CURRENT="$HOME/.local/state/runaway/current"
HEADER_FONT="MesloLGM Nerd Font:Bold:13.0"
OPT_INDENT=18

# Fast path: right-click or a click while the popup is open just closes it.
drawing="$(sketchybar --query "$NAME" 2>/dev/null | jq -r '.popup.drawing // "off"')"
if [ "$BUTTON" = "right" ] || [ "$drawing" = "on" ]; then
  sketchybar --set "$NAME" popup.drawing=off --remove "/${NAME}.opt\.*/"
  exit 0
fi

CLOSE="sketchybar --set $NAME popup.drawing=off --remove /${NAME}.opt\.*/"
args=(--remove "/${NAME}.opt\.*/" --set "$NAME" popup.drawing=on)
i=0

add_row() { # label color
  args+=(--add item "${NAME}.opt.$i" popup."$NAME"
    --set "${NAME}.opt.$i" label="$1" label.color="$2" label.padding_left="$OPT_INDENT" icon.drawing=off
    click_script="$CLOSE")
  i=$((i + 1))
}
add_header() { # text
  args+=(--add item "${NAME}.opt.$i" popup."$NAME"
    --set "${NAME}.opt.$i" label="$1" label.color="$GREY" label.font="$HEADER_FONT" icon.drawing=off)
  i=$((i + 1))
}

if [ ! -s "$CURRENT" ]; then
  add_header "no runaways"
else
  add_header "RUNAWAY PROCESSES"
  while IFS='|' read -r pid pc comm cwd; do
    [ -z "$pid" ] && continue
    add_row "$comm  ·  pid $pid  ·  ${pc}% core" "$WHITE"
    add_row "$cwd" "$BLUE"
  done <"$CURRENT"
fi

sketchybar -m "${args[@]}" >/dev/null
