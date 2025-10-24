#!/bin/bash

# Ensure mise is activated and tools are in PATH
eval "$(mise activate bash)"

# Get the number of panes in the current window
PANE_COUNT=$(tmux list-panes | wc -l | tr -d ' ')

if [ "$PANE_COUNT" -eq 1 ]; then
  # Single pane - create split on the right side
  tmux split-window -h -c "#{pane_current_path}"
  # Make the left pane (Neovim) take up most of the space
  tmux resize-pane -t 0 -x 78%
else
  # Multiple panes exist - use default split behavior
  tmux split-window -h -c "#{pane_current_path}"
fi

# Store the current Neovim buffer info if we're in Neovim
# This allows us to return to the same buffer position
CURRENT_CMD=$(tmux display-message -p '#{pane_current_command}')
if [[ "$CURRENT_CMD" == "nvim" ]]; then
  # Set an environment variable to track which pane has Neovim
  tmux set-environment "NVIM_PANE_#{window_index}" "#{pane_id}"
fi
