#!/bin/bash

export PATH="/opt/homebrew/bin:$PATH"

EMOJI="$1"
TYPE="$2" # reserved positional (was a window-type flag nothing read; callers still pass it)
CMD="$3"
CLOSE_ON_EXIT="${4:-false}"

SESSION=$(tmux display-message -p '#{session_name}')

if tmux select-window -t "${SESSION}:${EMOJI}" 2>/dev/null; then
  exit 0
else
  if [[ -n "$CMD" ]]; then
    if [[ "$CLOSE_ON_EXIT" == "true" ]]; then
      tmux new-window -n "$EMOJI" -c "#{pane_current_path}" "bash -l -c \"$CMD\""
    else
      # Login shell (-l) so the window stays open after the command exits
      tmux new-window -n "$EMOJI" -c "#{pane_current_path}" "${SHELL:-/bin/zsh} -l -c '$CMD; exec ${SHELL:-/bin/zsh} -l'"
    fi
  else
    tmux new-window -n "$EMOJI" -c "#{pane_current_path}"
  fi
fi
