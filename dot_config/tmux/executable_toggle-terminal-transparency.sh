#!/usr/bin/env bash

~/.config/tmux/toggle-ghostty-transparency.sh
~/.config/tmux/toggle-kitty-transparency.sh

# Only show message if we're in a tmux session
if [ -n "$TMUX" ]; then
  tmux display-message "Terminal transparency toggled for Ghostty and Kitty"
fi
