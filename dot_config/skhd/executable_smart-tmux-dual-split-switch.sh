#!/bin/bash

# Ensure Homebrew is in PATH (for tmux)
export PATH="/opt/homebrew/bin:$PATH"

# Ensure mise is activated and tools are in PATH
eval "$(mise activate bash)" 2>/dev/null || true

# Get current pane info
CURRENT_PANE=$(tmux display-message -p '#{pane_id}')
WINDOW_INDEX=$(tmux display-message -p '#{window_index}')
PANE_COUNT=$(tmux list-panes | wc -l | tr -d ' ')

# If only one pane, do nothing
if [ "$PANE_COUNT" -eq 1 ]; then
  exit 0
fi

# Function to get the leftmost (first) pane ID
get_leftmost_pane() {
  tmux list-panes -F '#{pane_id} #{pane_left}' | sort -k2 -n | head -1 | awk '{print $1}'
}

# Function to get the rightmost (last) pane ID
get_rightmost_pane() {
  tmux list-panes -F '#{pane_id} #{pane_left}' | sort -k2 -n | tail -1 | awk '{print $1}'
}

# Get the leftmost and rightmost panes
LEFTMOST_PANE=$(get_leftmost_pane)
RIGHTMOST_PANE=$(get_rightmost_pane)

# Check if we're in the leftmost pane
if [[ "$CURRENT_PANE" == "$LEFTMOST_PANE" ]]; then
  # From leftmost pane, jump to the rightmost pane
  if [[ "$RIGHTMOST_PANE" != "$CURRENT_PANE" ]]; then
    tmux select-pane -t "$RIGHTMOST_PANE"
  fi
else
  # From any other pane, always go back to the leftmost pane
  tmux select-pane -t "$LEFTMOST_PANE"
fi
