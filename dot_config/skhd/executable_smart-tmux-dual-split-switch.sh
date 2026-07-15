#!/bin/bash

export PATH="/opt/homebrew/bin:$PATH"

eval "$(mise activate bash)" 2>/dev/null || true

CURRENT_PANE=$(tmux display-message -p '#{pane_id}')
WINDOW_INDEX=$(tmux display-message -p '#{window_index}')
PANE_COUNT=$(tmux list-panes | wc -l | tr -d ' ')

if [ "$PANE_COUNT" -eq 1 ]; then
  exit 0
fi

get_leftmost_pane() {
  tmux list-panes -F '#{pane_id} #{pane_left}' | sort -k2 -n | head -1 | awk '{print $1}'
}

get_rightmost_pane() {
  tmux list-panes -F '#{pane_id} #{pane_left}' | sort -k2 -n | tail -1 | awk '{print $1}'
}

LEFTMOST_PANE=$(get_leftmost_pane)
RIGHTMOST_PANE=$(get_rightmost_pane)

if [[ "$CURRENT_PANE" == "$LEFTMOST_PANE" ]]; then
  if [[ "$RIGHTMOST_PANE" != "$CURRENT_PANE" ]]; then
    tmux select-pane -t "$RIGHTMOST_PANE"
  fi
else
  tmux select-pane -t "$LEFTMOST_PANE"
fi
