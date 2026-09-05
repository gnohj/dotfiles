#!/usr/bin/env bash
# Popup listing which of my PRs hold unresolved threads; a row opens that PR and closes the popup.
export PATH="/run/current-system/sw/bin:/opt/homebrew/bin:$HOME/.local/bin:/usr/bin:/bin:$PATH"

source "$HOME/.config/sketchybar/config/colors.sh"

NAME="${NAME:-widgets.pr_replies_notification}"
DATA_FILE="/tmp/sketchybar_pr_replies_data.json"
HEADER_FONT="MesloLGM Nerd Font:Bold:13.0"
OPT_INDENT=18

drawing="$(sketchybar --query "$NAME" 2>/dev/null | jq -r '.popup.drawing // "off"')"
if [ "$BUTTON" = "right" ] || [ "$drawing" = "on" ]; then
  sketchybar --set "$NAME" popup.drawing=off --remove "/${NAME}.opt\.*/"
  exit 0
fi

CLOSE="sketchybar --set $NAME popup.drawing=off --remove /${NAME}.opt\.*/"
"$HOME/.config/sketchybar/items/widgets/popup-close-others.sh" "$NAME"
args=(--remove "/${NAME}.opt\.*/")
i=0
add_row() { # label color click
  args+=(--add item "${NAME}.opt.$i" popup."$NAME"
    --set "${NAME}.opt.$i" label="$1" label.color="$2" label.padding_left="$OPT_INDENT" icon.drawing=off
    click_script="${3:-$CLOSE}")
  i=$((i + 1))
}
add_header() {
  if [ "$i" -eq 0 ]; then
    args+=(--add item "${NAME}.opt.$i" popup."$NAME"
      --set "${NAME}.opt.$i" icon="$1" icon.color="$GREY" icon.font="$HEADER_FONT" icon.width=368 icon.align=left
      icon.padding_left=12 icon.padding_right=0
      label="×" label.align=center label.width=40 label.padding_left=0 label.padding_right=0 label.color="$RED" label.font.size=22
      click_script="$CLOSE")
  else
    args+=(--add item "${NAME}.opt.$i" popup."$NAME"
      --set "${NAME}.opt.$i" label="$1" label.color="$GREY" label.font="$HEADER_FONT" icon.drawing=off)
  fi
  i=$((i + 1))
}

rows="$(cat "$DATA_FILE" 2>/dev/null)"
[ -n "$rows" ] || rows="[]"
total="$(printf '%s' "$rows" | jq '[.[].waiting] | add // 0')"

if [ "${total:-0}" -eq 0 ]; then
  add_header "NO THREADS WAITING ON YOU"
  add_row "every review conversation on your PRs is resolved" "$BLUE"
else
  add_header "AWAITING YOUR REPLY ($total thread$([ "$total" = 1 ] || echo s))"
  while IFS=$'\t' read -r repo number title waiting; do
    [ -n "$repo" ] || continue
    add_row "$repo#$number  ·  $waiting unresolved" "$WHITE" "open 'https://github.com/$repo/pull/$number/files'; $CLOSE"
    add_row "${title:0:70}" "$BLUE" "open 'https://github.com/$repo/pull/$number/files'; $CLOSE"
  done < <(printf '%s' "$rows" | jq -r '.[] | [.repo, .number, .title, .waiting] | @tsv')
fi

sketchybar "${args[@]}" --set "$NAME" popup.drawing=on
