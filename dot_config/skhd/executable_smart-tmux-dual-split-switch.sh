#!/bin/bash

# Ensure mise is activated and tools are in PATH
eval "$(~/.local/bin/mise activate bash)"

# Get current pane info
CURRENT_PANE=$(tmux display-message -p '#{pane_id}')
CURRENT_CMD=$(tmux display-message -p '#{pane_current_command}')
WINDOW_INDEX=$(tmux display-message -p '#{window_index}')
PANE_COUNT=$(tmux list-panes | wc -l | tr -d ' ')

# If only one pane, do nothing
if [ "$PANE_COUNT" -eq 1 ]; then
  exit 0
fi

# Check if we're in Neovim
if [[ "$CURRENT_CMD" == "nvim" ]]; then
  # Store current pane as the Neovim pane for this window
  tmux set-environment "NVIM_PANE_${WINDOW_INDEX}" "$CURRENT_PANE"
  # Move to the other pane (assumes 2 panes for simplicity)
  tmux select-pane -t :.+
else
  # We're not in Neovim, try to go back to the Neovim pane
  NVIM_PANE=$(tmux show-environment "NVIM_PANE_${WINDOW_INDEX}" 2>/dev/null | cut -d= -f2)

  if [ -n "$NVIM_PANE" ]; then
    # Check if the Neovim pane still exists and has nvim running
    PANE_CMD=$(tmux display-message -t "$NVIM_PANE" -p '#{pane_current_command}' 2>/dev/null)
    if [[ "$PANE_CMD" == "nvim" ]]; then
      tmux select-pane -t "$NVIM_PANE"
    else
      # Neovim is no longer running, just switch panes normally
      tmux select-pane -t :.+
    fi
  else
    # No stored Neovim pane, just switch normally
    tmux select-pane -t :.+
  fi
fi
