#!/bin/bash

# First parameter is empty string '', second is the actual working directory
WORKING_DIR="${2:-$HOME}"

# Create new tmux window with 3 vertical panes
# Name it with fish emoji so automatic rename applies
tmux new-window -n "🐠" -c "$WORKING_DIR" \; \
  split-window -h -c "$WORKING_DIR" \; \
  split-window -h -c "$WORKING_DIR" \; \
  select-layout even-horizontal \; \
  select-layout even-horizontal \; \
  send-keys -t 0 "clear" Enter \; \
  send-keys -t 1 "clear" Enter \; \
  send-keys -t 2 "clear" Enter \;

# Mark this new window as a fish window for automatic renaming
SESSION_NAME=$(tmux display-message -p '#{session_name}')
NEW_WINDOW_INDEX=$(tmux display-message -p '#{window_index}')
tmux set-option -w -t "${SESSION_NAME}:${NEW_WINDOW_INDEX}" "@original_window_type_${SESSION_NAME}_${NEW_WINDOW_INDEX}" "fish"

# Go back to previous window and start nvim in the correct directory
# Rename to pen emoji since we're starting nvim
tmux last-window
tmux rename-window "🖊️"
# Store that this is a pen window so it doesn't get renamed
SESSION_NAME=$(tmux display-message -p '#{session_name}')
WINDOW_INDEX=$(tmux display-message -p '#{window_index}')
tmux set-option -w "@original_window_type_${SESSION_NAME}_${WINDOW_INDEX}" "pen"
tmux send-keys "cd $WORKING_DIR" Enter
tmux send-keys "clear" Enter
tmux send-keys "n" Enter
