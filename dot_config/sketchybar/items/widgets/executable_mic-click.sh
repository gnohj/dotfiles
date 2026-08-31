#!/usr/bin/env bash
# Left click opens the input panel (level slider + device list); right click opens Sound settings.
#
#   mic-click.sh            # button-driven, from the widget's click_script
#   mic-click.sh rebuild    # repaint the panel in place, for the rows' own click_scripts

export PATH="/opt/homebrew/bin:$PATH"

source "$HOME/.config/sketchybar/config/colors.sh"

NAME="${NAME:-mic}"
WIDGETS="$HOME/.config/sketchybar/items/widgets"
POPUP_WIDTH=200

# One `sketchybar -m` applies its args in order, so the leading --remove spares the rows added after it.
render_panel() {
  command -v SwitchAudioSource >/dev/null || exit 0

  local mode="$1" current volume counter=0 color
  current="$(SwitchAudioSource -t input -c)"
  volume="$(osascript -e 'input volume of (get volume settings)')"
  case "$volume" in '' | *[!0-9]*) volume=0 ;; esac

  local args=(--remove '/mic\.pop\..*/') open=0
  if [ "$mode" = toggle ]; then
    if [ "$(sketchybar --query "$NAME" | jq -r '.popup.drawing')" = "on" ]; then
      sketchybar --set "$NAME" popup.drawing=off
      return
    fi
    "$WIDGETS/popup-close-others.sh" "$NAME"
    open=1
  fi

  local on=off
  [ "$volume" -gt 0 ] && on=on
  args+=(--add item mic.pop.header popup."$NAME"
    --set mic.pop.header
    icon="$([ "$on" = on ] && printf '\xef\x84\xb0' || printf '\xef\x84\xb1')  Input"
    icon.align=left icon.width=$((POPUP_WIDTH - 52)) icon.padding_left=12 icon.padding_right=0
    icon.color="$([ "$on" = on ] && echo "$ICON_BLUE" || echo "$GREY")" icon.font.style=Bold
    label="×" label.align=center label.width=40 label.padding_left=0 label.padding_right=0 label.font.size=22 label.color="$RED"
    click_script="sketchybar --set $NAME popup.drawing=off")

  args+=(--add item mic.pop.toggle popup."$NAME"
    --set mic.pop.toggle icon="Input enabled" icon.align=left icon.width=$((POPUP_WIDTH * 8 / 10))
    icon.color="$([ "$on" = on ] && echo "$WHITE" || echo "$GREY")"
    label="$([ "$on" = on ] && printf '\xf3\xb0\x94\xa1' || printf '\xf3\xb0\x94\xa2')"
    label.align=right label.width=$((POPUP_WIDTH * 2 / 10)) label.font.size=18
    label.color="$([ "$on" = on ] && echo "$GREEN" || echo "$GREY")"
    click_script="$WIDGETS/mic.sh mute-toggle && NAME=$NAME $WIDGETS/mic-click.sh rebuild")

  args+=(--add slider mic.pop.slider popup."$NAME" "$POPUP_WIDTH"
    --set mic.pop.slider slider.percentage="$volume"
    click_script="osascript -e \"set volume input volume \$PERCENTAGE\" && $WIDGETS/mic.sh render")

  # Rows repaint the panel instead of recolouring by regex: a backslash in a click_script breaks `--query` JSON.
  while IFS= read -r device; do
    color=$GREY
    [ "$device" = "$current" ] && color=$MAGENTA
    args+=(--add item mic.pop.device.$counter popup."$NAME"
      --set mic.pop.device.$counter label="$device" label.color="$color"
      click_script="SwitchAudioSource -t input -s $(printf '%q' "$device") && $WIDGETS/mic.sh render && NAME=$NAME $WIDGETS/mic-click.sh rebuild")
    counter=$((counter + 1))
  done <<<"$(SwitchAudioSource -a -t input)"

  [ "$open" = 1 ] && args+=(--set "$NAME" popup.drawing=on)
  sketchybar -m "${args[@]}" >/dev/null
}

case "${1:-}" in
  rebuild) render_panel keep ;;
  *)
    if [ "$BUTTON" = "right" ]; then
      open "x-apple.systempreferences:com.apple.Sound-Settings.extension"
    else
      render_panel toggle
    fi
    ;;
esac
