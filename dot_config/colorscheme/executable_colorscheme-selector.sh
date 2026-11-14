#!/usr/bin/env bash
# shellcheck disable=SC1090,SC2154

# Usage: colorscheme-selector.sh [name-filter] [header] [prompt] | <wallpaper image>. Enter keeps, Esc reverts, Tab toggles live preview.

list="$HOME/.config/colorscheme/list"
active="$HOME/.config/colorscheme/active/active-colorscheme.sh"
setter="${COLORSCHEME_SET_SCRIPT:-$HOME/.config/zshrc/colorscheme-set.sh}"
state="${XDG_STATE_HOME:-$HOME/.local/state}/colorscheme"
lock="$state/lock"
gen="${THEME_GENERATOR:-$HOME/.local/bin/theme-from-wallpaper}"
new_row="+ new from wallpaper"
# ANSI indexes, not palette hexes, so the picker's own chrome follows the terminal as it repaints.
fzf_colors="bg+:8,fg+:7,hl+:4,fg:2,info:8,prompt:4,pointer:4,marker:4,header:8,border:6"

current() {
  local to
  to=$(readlink "$active" 2>/dev/null) && [ -f "$list/${to##*/}" ] && printf '%s' "${to##*/}"
}

pending() { want=$(cat "$state/want" 2>/dev/null) && [ -f "$list/$want" ] && [ "$want" != "$(current)" ]; }

# One worker at a time, always applying the newest request, so fast scrolling never lands an older theme last.
worker() {
  while pending && mkdir "$lock" 2>/dev/null; do
    while pending; do "$setter" --preview "$want" >/dev/null 2>&1 || rm -f "$state/want"; done
    rmdir "$lock"
  done
}

# Stop previewing and let an in-flight apply finish (5s cap, so a hung setter cannot hang the picker).
settle() {
  rm -f "$state/want"
  for _ in {1..100}; do
    [ -d "$lock" ] || break
    sleep 0.05
  done
}

revert() {
  settle
  local origin
  origin=$(cat "$state/origin" 2>/dev/null)
  [ -z "$origin" ] || [ "$origin" = "$(current)" ] || "$setter" --preview "$origin" >/dev/null 2>&1
}

# Kitty unicode placeholders are plain text cells, so fzf lays the image out like any line; returns 1 where the terminal cannot draw them.
thumb() {
  case "${TERM_PROGRAM:-}${KITTY_WINDOW_ID:+kitty}" in rex | ghostty | *kitty) ;; *) return 1 ;; esac
  [ "$3" -ge 3 ] && [ -f "$1" ] && command -v kitten >/dev/null 2>&1 || return 1
  # The last icat line is a bare reset with no newline, which makes fzf draw a scroll marker; fold it into the line before.
  kitten icat --clear --transfer-mode=stream --unicode-placeholder --stdin=no --align=left --place="${2}x${3}@0x0" "$1" 2>/dev/null | sed '$d' | sed $'$s/$/\e[m/'
}

preview() {
  [ -f "$list/$1" ] || return 0
  . "$list/$1"
  local live=OFF cols="${FZF_PREVIEW_COLUMNS:-60}" c
  # With no named theme to return to, Esc could not undo a preview, so nothing is previewed.
  if [ ! -e "$state/live-off" ] && [ -s "$state/origin" ]; then
    live=ON
    printf '%s' "$1" >"$state/want"
    # Own process group: fzf kills the preview's group on every cursor move, and a half-finished apply must not die with it.
    (
      set -m
      "$0" --worker &
    ) >/dev/null 2>&1
  fi

  local B C P T U H K F S Y N M R
  rgb() { printf -v "$1" '\e[%d;2;%d;%d;%dm' "$2" "0x${3:1:2}" "0x${3:3:2}" "0x${3:5:2}"; }
  rgb C 48 "$gnohj_color07"
  rgb T 38 "${gnohj_text:-$gnohj_color14}"
  rgb U 38 "$gnohj_color04"
  rgb H 38 "$gnohj_color14"
  rgb K 38 "$gnohj_color01"
  rgb F 38 "$gnohj_color03"
  rgb S 38 "$gnohj_color02"
  rgb Y 38 "$gnohj_color05"
  rgb N 38 "$gnohj_color15"
  rgb M 38 "$gnohj_color09"
  rgb R 38 "$gnohj_color11"

  # Padded to the pane width so a background fills the row; ASCII only, so ${#text} is the width in any locale.
  row() {
    local out="" n=0
    while [ $# -gt 0 ]; do
      out+="$1$2"
      n=$((n + ${#2}))
      shift 2
    done
    printf '%s%s%*s\e[0m\n' "$B" "$out" $((cols > n ? cols - n : 0)) ''
  }

  row "$H" " ${1%-colors.sh}"
  printf '%s ' "$B"
  for c in "$gnohj_color11" "$gnohj_color15" "$gnohj_color05" "$gnohj_color02" "$gnohj_color03" "$gnohj_color04" "$gnohj_color01" "$gnohj_color14"; do
    printf '\e[48;2;%d;%d;%dm    ' "0x${c:1:2}" "0x${c:3:2}" "0x${c:5:2}"
  done
  printf '%s%*s\e[0m\n' "$B" $((cols > 33 ? cols - 33 : 0)) ''
  printf '%s ' "$B"
  for c in "$gnohj_color07" "$gnohj_color17" "$gnohj_color16" "$gnohj_color13" "$gnohj_color08" "$gnohj_color09" "$gnohj_color24" "$gnohj_color06"; do
    printf '\e[38;2;%d;%d;%dm▀▀▀▀' "0x${c:1:2}" "0x${c:3:2}" "0x${c:5:2}"
  done
  printf '%s%*s\e[0m\n' "$B" $((cols > 33 ? cols - 33 : 0)) ''
  row "$T" ""
  row "$F" " ~/.local/share/chezmoi " "$K" "main " "$S" "\$ " "$T" "git status " "$M" "-sb"
  row "$T" ""
  P=$B B=$C
  row "$K" " fn " "$F" "apply" "$H" "(" "$U" "theme" "$H" ": " "$Y" "&Theme" "$H" ") -> " "$Y" "Result" "$H" "<()> {"
  row "$K" "   let " "$U" "bg " "$H" "= " "$U" "theme" "$H" "." "$F" "color" "$H" "(" "$S" '"background"' "$H" "); " "$M" "// lookup"
  row "$F" "   reload" "$H" "(" "$Y" "Surface" "$H" "::" "$U" "Ghostty" "$H" ", " "$N" "120" "$H" ")?;"
  row "$H" " }"
  B=$P
  row "$T" ""
  row "$S" " + foreground = ${gnohj_text:-$gnohj_color14}"
  row "$R" " - background = $gnohj_color10"
  row "$T" ""
  row "$M" " live $live  " "$M" "(tab toggles)"
  row "$M" " wallpaper  " "$T" "${wallpaper##*/}"

  thumb "$wallpaper" $((cols - 2)) $((${FZF_PREVIEW_LINES:-0} - 17))
}

case "${1:-}" in
--preview)
  preview "$2"
  exit 0
  ;;
--worker)
  worker
  exit 0
  ;;
--image)
  cols="${FZF_PREVIEW_COLUMNS:-40}" lines="${FZF_PREVIEW_LINES:-0}"
  # Folded here, not by fzf, so the image height stays exact.
  if [ -f "$2.caption" ]; then
    caption=$(fold -s -w "$((cols > 2 ? cols - 1 : 1))" "$2.caption")
    printf '\e[33m%s\e[m\n\n' "$caption"
    lines=$((lines - $(wc -l <<<"$caption") - 1))
  fi
  thumb "$2" "$cols" "$lines" || printf '%s\n' "$2"
  exit 0
  ;;
--toggle)
  if [ -e "$state/live-off" ]; then rm -f "$state/live-off"; else
    : >"$state/live-off"
    revert
  fi
  exit 0
  ;;
esac

if ! command -v fzf &>/dev/null; then
  echo "fzf is not installed. Please install it first."
  exit 1
fi

if [ -f "${1:-}" ]; then
  THEME_NEW=$("$gen" "$1") || exit 1
  export THEME_NEW
  set --
fi

shopt -s nullglob nocasematch
new="" first="" rest="" cur=$(current)
[ -f "$list/${THEME_NEW:-}" ] && new="$THEME_NEW"$'\t'"$THEME_NEW"$'\n'
for f in "$list"/*.sh; do
  n="${f##*/}"
  [ "$n" = "${THEME_NEW:-}" ] && continue
  case "$n" in *"${1:-}"*) ;; *) continue ;; esac
  # The active scheme leads so the cursor opens on it and nothing repaints until you move.
  if [ "$n" = "$cur" ]; then first="$n"$'\t'"$n  "$'\e[34m● active\e[m\n'; else rest+="$n"$'\t'"$n"$'\n'; fi
done
if [ -z "$new$first$rest" ]; then
  echo "No color scheme scripts found in $list."
  exit 1
fi

mkdir -p "$state"
rmdir "$lock" 2>/dev/null
rm -f "$state/want"
printf '%s' "$cur" >"$state/origin"
trap revert EXIT
trap 'exit 129' HUP INT TERM

# Open on the scheme below the new-theme row; with no active or new scheme, stay on that row so opening repaints nothing.
pos=2
[ -n "$new$first" ] || pos=1
sel=$(printf '%s\t%s\n%s' "$new_row" "$new_row" "$new$first$rest" |
  FZF_VIM_HEADER="${2:-Select a Color Scheme}" FZF_VIM_NORMAL_BINDS="tab:execute-silent($0 --toggle)+refresh-preview" \
    "$HOME/.local/bin/fzf-vim.sh" --prompt="${3:-Theme > }" \
    --color "$fzf_colors" \
    --ansi --delimiter '\t' --with-nth 2 --wrap --bind "load:pos($pos)" --preview "$0 --preview {1}" --preview-window 'right:55%:border-left')
rc=$?
sel="${sel%%$'\t'*}"
# fzf-vim.sh runs fzf with --no-clear, which leaves the terminal on the alternate screen; step off it so a shell prompt does not draw over the picker.
leave_screen() { printf '\e[?1049l' >/dev/tty 2>/dev/null; }
leave_screen

if [ "$rc" = 0 ] && [ "$sel" = "$new_row" ]; then
  revert
  trap - EXIT
  unset THEME_NEW
  printf 'Finding wallpapers on Unsplash...\n' >/dev/tty 2>/dev/null
  online=$("$gen" --online 2>"$state/online-error")
  note=$(head -n 1 "$state/online-error")
  [ -z "$online" ] || note="${note:-download rows are saved from Unsplash when picked}"
  img=$({
    [ -z "$online" ] || printf '%s\n' "$online"
    "$gen" --unused | while IFS= read -r path; do printf '%s\t%s\n' "${path##*/}" "$path"; done
  } | FZF_VIM_HEADER="New theme from a wallpaper${note:+$'\n'$note}" "$HOME/.local/bin/fzf-vim.sh" --prompt="Wallpaper > " \
    --color "$fzf_colors" --ansi --wrap --delimiter '\t' --with-nth 1 --preview "$0 --image {2}" --preview-window 'right:55%:border-left')
  rc=$?
  leave_screen
  [ "$rc" = 130 ] && exit 130
  img="${img#*$'\t'}"
  if [ -n "$img" ]; then
    THEME_NEW=$("$gen" "$img") && export THEME_NEW || {
      echo "Press any key."
      read -rsn1
    }
  fi
  exec "$0" "$@"
fi

if [ "$rc" = 0 ] && [ -f "$list/$sel" ]; then
  settle
  trap - EXIT
  "$setter" "$sel"
  exit
fi
exit "$rc"
