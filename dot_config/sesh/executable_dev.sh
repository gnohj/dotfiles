#!/bin/bash

# First parameter is empty string '', second is the actual working directory
WORKING_DIR="${2:-$HOME}"

# Create new tmux window with 3 vertical panes
# Don't set a name - let automatic-rename handle it
tmux new-window -c "$WORKING_DIR" \; \
  split-window -h -c "$WORKING_DIR" \; \
  split-window -h -c "$WORKING_DIR" \; \
  select-layout even-horizontal \; \
  select-layout even-horizontal \; \
  send-keys -t 0 "clear" Enter \; \
  send-keys -t 1 "clear" Enter \; \
  send-keys -t 2 "clear" Enter \;

# Go back to previous window and start nvim in the correct directory
# Don't rename - let automatic-rename handle it based on the command
tmux last-window
tmux send-keys "cd $WORKING_DIR" Enter
tmux send-keys "clear" Enter
tmux send-keys "nvim" Enter
