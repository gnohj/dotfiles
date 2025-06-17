#!/usr/bin/env bash
# shellcheck disable=SC1091,SC2154

source "$HOME/.config/colorscheme/active/active-colorscheme.sh"

# Path to the directory containing color scheme scripts
COLORSCHEME_DIR=~/.config/colorscheme/list
# Path to the colorscheme-set.sh script
COLORSCHEME_SET_SCRIPT=~/.config/zshrc/colorscheme-set.sh

# Ensure fzf is installed
if ! command -v fzf &>/dev/null; then
  echo "fzf is not installed. Please install it first."
  exit 1
fi

# List available color scheme file names
# shellcheck disable=SC2207
schemes=($(find "$COLORSCHEME_DIR" -name "*.sh" -print0 | xargs -0 -n 1 basename))

# Check if any color scheme files were found
if [ ${#schemes[@]} -eq 0 ]; then
  echo "No color scheme scripts found in $COLORSCHEME_DIR."
  exit 1
fi

# Use fzf to select a scheme with matching colors
selected_scheme=$(printf "%s\n" "${schemes[@]}" | fzf \
  --height=40% \
  --reverse \
  --header="Select a Color Scheme" \
  --prompt="Theme > " \
  --color "bg+:$gnohj_color16,fg+:$gnohj_color14,hl+:$gnohj_color04,fg:$gnohj_color02,info:$gnohj_color09,prompt:$gnohj_color04,pointer:$gnohj_color04,marker:$gnohj_color04,header:$gnohj_color09")

# Check if a selection was made
if [ -z "$selected_scheme" ]; then
  echo "No color scheme selected."
  exit 0
fi

# Apply the selected color scheme
"$COLORSCHEME_SET_SCRIPT" "$selected_scheme"

# Reload tmux configuration again - this is a workaround to get colors updated in sesh
"$HOME/.config/tmux/set_tmux_colors.sh"
tmux source-file ~/.config/tmux/tmux.conf
echo "Tmux colors set and tmux configuration reloaded for sesh."
