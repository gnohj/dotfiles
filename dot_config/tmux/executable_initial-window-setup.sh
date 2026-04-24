#!/bin/bash
# Rename the first window of a new session to the fish emoji
# Only renames if the window still has the default name (zsh/bash/etc)
CURRENT_NAME=$(tmux display-message -p '#{window_name}')
if echo "$CURRENT_NAME" | grep -qE '^(zsh|bash|fish|.*bin/zsh.*|.*bin/bash.*)$'; then
  tmux rename-window "🐠"
fi
