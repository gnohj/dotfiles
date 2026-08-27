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

  local args=(--remove '/mic\.pop\..*/')
  # Resolved, not toggled: opening must close every other popup in the same invocation to hold order.
  if [ "$mode" = toggle ]; then
    if [ "$(sketchybar --query "$NAME" | jq -r '.popup.drawing')" = "on" ]; then
      args+=(--set "$NAME" popup.drawing=off)
    else
      args+=(--set '/.*/' popup.drawing=off --set "$NAME" popup.drawing=on)
    fi
  fi

  args+=(--add slider mic.pop.slider popup."$NAME" "$POPUP_WIDTH"
    --set mic.pop.slider slider.percentage="$volume"
    slider.highlight_color="$GREEN"
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
