#!/usr/bin/env bash
# shellcheck disable=SC1091
# shellcheck disable=SC2154

# Source the colorscheme file
source "$HOME/.config/colorscheme/active/active-colorscheme.sh"

# Color of the ACTIVE window, windows are opened with ctrl+b c
tmux set -g @catppuccin_window_current_color "$gnohj_color03"
tmux set -g @catppuccin_window_current_background "$gnohj_color10"

# Color of the rest of the windows that are not active
tmux set -g @catppuccin_window_default_color "$gnohj_color23"
tmux set -g @catppuccin_window_default_background "$gnohj_color10"

# The following 2 colors are for the lines that separate tmux splits
tmux set -g @catppuccin_pane_active_border_style "fg=$gnohj_color03"
tmux set -g @catppuccin_pane_border_style "fg=$gnohj_color03"

# This is the classic colored tmux bar that goes across the entire screen
# set -g @catppuccin_status_background "theme"
tmux set -g @catppuccin_status_background "default"

# tmux set -g @catppuccin_directory_icon "🤖"
# tmux set -g @catppuccin_directory_color "$gnohj_color04"

# default for catppuccin_session_color is #{?client_prefix,$thm_red,$thm_green}
# https://github.com/catppuccin/tmux/issues/140#issuecomment-1956204278
tmux set -g @catppuccin_session_color "#{?client_prefix,$gnohj_color06,$gnohj_color02}"

# This sets the color of the window text, #W shows the application name
tmux set -g @catppuccin_window_default_fill "number"
tmux set -g @catppuccin_window_default_text "#[fg=$gnohj_color14]#W"
tmux set -g @catppuccin_window_current_fill "number"
tmux set -g @catppuccin_window_current_text "#[fg=$gnohj_color14]#W"
#
# Second option shows a message when panes are syncronized
tmux set -g @catppuccin_window_current_text "#W#{?window_zoomed_flag,#[fg=$gnohj_color04] (    ),}#{?pane_synchronized,#[fg=$gnohj_color04] SYNCHRONIZED-PANES,}"

# https://github.com/catppuccin/tmux/blob/fe0d245e1c971789d87ab80f492a20709af91c91/catppuccin_tmux.conf#L308-L310
# set -wF mode-style "fg=$gnohj_color13,bg=$gnohj_color02"
tmux set -wF mode-style "fg=$gnohj_color02,bg=$gnohj_color13"
