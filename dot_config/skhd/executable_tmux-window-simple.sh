#!/bin/bash

# Ensure mise is activated and tools are in PATH
eval "$(mise activate bash)"

EMOJI="$1"
TYPE="$2"
CMD="$3"
CLOSE_ON_EXIT="${4:-false}" # Default to false (keep window open)

# Get session name
SESSION=$(tmux display-message -p '#{session_name}')

# Check if window exists by trying to select it
if tmux select-window -t "${SESSION}:${EMOJI}" 2>/dev/null; then
  # Window exists and we switched to it
  exit 0
else
  # Window doesn't exist, create it
  if [[ -n "$CMD" ]]; then
    if [[ "$CLOSE_ON_EXIT" == "true" ]]; then
      # Run command and close window when it exits
      # Use bash -c with eval to properly expand environment variables and tildes
      tmux new-window -n "$EMOJI" -c "#{pane_current_path}" "bash -l -c \"$CMD\""
    else
      # Run command in a login shell so window doesn't close when command exits
      # Use -l flag to ensure it's a login shell that sources all configs
      tmux new-window -n "$EMOJI" -c "#{pane_current_path}" "${SHELL:-/bin/zsh} -l -c '$CMD; exec ${SHELL:-/bin/zsh} -l'"
    fi
  else
    tmux new-window -n "$EMOJI" -c "#{pane_current_path}"
  fi

  # Mark window type
  IDX=$(tmux display-message -p '#{window_index}')
  tmux set-option -w "@original_window_type_${SESSION}_${IDX}" "$TYPE"
fi
