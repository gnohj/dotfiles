#!/bin/bash
# Wrapper script to properly set up sessions from sesh

SESSION_NAME="$1"
SESSION_PATH="${2:-$HOME}"
STARTUP_CMD="${3:-}"

# Create or attach to session
if ! tmux has-session -t "$SESSION_NAME" 2>/dev/null; then
  # Create new session
  if [[ "$SESSION_NAME" == *"config"* ]] || [[ -n "$STARTUP_CMD" && "$STARTUP_CMD" == *"nvim"* ]]; then
    # For config or nvim sessions, use pen emoji
    tmux new-session -d -s "$SESSION_NAME" -c "$SESSION_PATH" -n "🖊️"
    tmux set-option -w -t "${SESSION_NAME}:0" "@original_window_type_${SESSION_NAME}_0" "pen"

    # Run the startup command if provided
    if [[ -n "$STARTUP_CMD" ]]; then
      tmux send-keys -t "$SESSION_NAME:0" "$STARTUP_CMD" Enter
    else
      tmux send-keys -t "$SESSION_NAME:0" "n" Enter
    fi
  else
    # For other sessions, use fish emoji for shell
    tmux new-session -d -s "$SESSION_NAME" -c "$SESSION_PATH" -n "🐠"
    tmux set-option -w -t "${SESSION_NAME}:0" "@original_window_type_${SESSION_NAME}_0" "fish"

    # Run the startup command if provided
    if [[ -n "$STARTUP_CMD" ]]; then
      tmux send-keys -t "$SESSION_NAME:0" "$STARTUP_CMD" Enter
    fi
  fi
fi

# Attach to the session
tmux switch-client -t "$SESSION_NAME" 2>/dev/null || tmux attach-session -t "$SESSION_NAME"

