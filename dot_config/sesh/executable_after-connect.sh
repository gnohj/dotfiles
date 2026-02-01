#!/bin/bash
# Hook that runs after sesh connects to a session
# Creates a default pen emoji window with nvim if it's a new session

SESSION_NAME=$(tmux display-message -p '#{session_name}')
WINDOW_COUNT=$(tmux list-windows -t "$SESSION_NAME" -F '#{window_index}' | wc -l)

# If this is a new session with only one default window
if [ "$WINDOW_COUNT" -eq 1 ]; then
    FIRST_WINDOW_NAME=$(tmux list-windows -t "$SESSION_NAME" -F '#{window_name}' | head -1)
    
    # Check if it's a default shell window (usually named with shell emoji or default name)
    if [[ "$FIRST_WINDOW_NAME" == *"🐠"* ]] || [[ "$FIRST_WINDOW_NAME" == *"zsh"* ]] || [[ "$FIRST_WINDOW_NAME" == *"bash"* ]] || [[ "$FIRST_WINDOW_NAME" == *"fish"* ]]; then
        # Rename the window to pen emoji
        tmux rename-window -t "${SESSION_NAME}:0" "🖊️"
        # Start nvim
        tmux send-keys -t "${SESSION_NAME}:0" "nvim" Enter
    fi
fi