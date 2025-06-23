#!/bin/bash

WINDOW_NAME="${1:-dev}"
WORKING_DIR="${2:-$HOME}"

# Create new tmux window with 3 vertical panes
tmux new-window -c "$WORKING_DIR" -n "$WINDOW_NAME" \; \
  split-window -h -c "$WORKING_DIR" \; \
  split-window -h -c "$WORKING_DIR" \; \
  select-layout even-horizontal \; \
  select-layout even-horizontal \; \
  send-keys -t 0 "clear" Enter \; \
  send-keys -t 1 "clear" Enter \; \
  send-keys -t 2 "clear" Enter \;

# Go back and rename (separate commands)
tmux last-window
tmux rename-window "nvim"
tmux send-keys "cd $WORKING_DIR" Enter
tmux send-keys "clear" Enter
tmux send-keys "nvim" Enter
