#!/usr/bin/env bash

~/.config/tmux/toggle-ghostty-transparency.sh
~/.config/tmux/toggle-wezterm-transparency.sh

# Only show message if we're in a tmux session
if [ -n "$TMUX" ]; then
  tmux display-message "Terminal transparency toggled for both Ghostty and WezTerm"
fi
