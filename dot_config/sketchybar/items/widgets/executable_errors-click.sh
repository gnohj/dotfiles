#!/usr/bin/env bash
# errors popup: SERVICE ERRORS + orphan buckets from ~/.local/state/errors/current; any row click closes it.
export PATH="/run/current-system/sw/bin:/opt/homebrew/bin:$HOME/.local/bin:/usr/bin:/bin:$PATH"

source "$HOME/.config/sketchybar/config/colors.sh"

NAME="${NAME:-widgets.errors_notification}"
CURRENT="$HOME/.local/state/errors/current"
HEADER_FONT="MesloLGM Nerd Font:Bold:13.0"
OPT_INDENT=18

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
add_header() {
  args+=(--add item "${NAME}.opt.$i" popup."$NAME"
    --set "${NAME}.opt.$i" label="$1" label.color="$GREY" label.font="$HEADER_FONT" icon.drawing=off)
  i=$((i + 1))
}

emit_bucket() { # cat title
  local want="$1" title="$2" line ct pid pc comm cwd printed=0
  while IFS='|' read -r ct pid pc comm cwd; do
    [ "$ct" = "$want" ] || continue
    [ "$printed" = 0 ] && { add_header "$title"; printed=1; }
    add_row "$comm  ·  pid $pid  ·  ${pc}% core" "$WHITE"
    add_row "$cwd" "$BLUE"
  done <"$CURRENT"
}

if [ ! -s "$CURRENT" ]; then
  add_header "✓ all clear"
else
  printed=0
  while IFS='|' read -r ct src; do
    [ "$ct" = error ] || continue
    [ "$printed" = 0 ] && { add_header "SERVICE ERRORS"; printed=1; }
    add_row "$src" "$RED"
  done <"$CURRENT"
  emit_bucket fff "FFF-ORPHANS (each pins an fff LMDB slot)"
  emit_bucket treehouse "TREEHOUSE-ORPHANS"
  emit_bucket cpu "CPU-ORPHANS"
fi

sketchybar -m "${args[@]}" >/dev/null
