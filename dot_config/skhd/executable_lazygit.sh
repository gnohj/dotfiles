#!/bin/bash

# Ensure Homebrew and bun are in PATH
export PATH="/opt/homebrew/bin:$HOME/.bun/bin:$HOME/Scripts:$PATH"

LAZYGIT_DIR_FILE="$HOME/.lazygit/newdir"
mkdir -p "$HOME/.lazygit"

# Remove old dir file before starting
rm -f "$LAZYGIT_DIR_FILE"

# Get current pane's directory (use tmux's pane_current_path directly)
/opt/homebrew/bin/tmux display-popup -E -w 90% -h 90% -d "#{pane_current_path}" -B "
  export PATH=\"/opt/homebrew/bin:$HOME/.bun/bin:$HOME/Scripts:\$PATH\"
  export LAZYGIT_NEW_DIR_FILE=\"$HOME/.lazygit/newdir\"
  /usr/bin/git rev-parse --is-inside-work-tree >/dev/null 2>&1 && HUSKY=0 LG_CONFIG_FILE=~/.config/lazygit/config.yml lazygit || exit 0
"

# After popup closes, cd the pane to the new directory if lazygit wrote one
if [ -f "$LAZYGIT_DIR_FILE" ]; then
  NEW_DIR=$(cat "$LAZYGIT_DIR_FILE")
  CURRENT_DIR=$(/opt/homebrew/bin/tmux display-message -p '#{pane_current_path}')
  rm -f "$LAZYGIT_DIR_FILE"
  # Only cd if directory actually changed (avoids cd'ing when not switching worktrees)
  if [ -n "$NEW_DIR" ] && [ "$NEW_DIR" != "$CURRENT_DIR" ]; then
    /opt/homebrew/bin/tmux send-keys "cd '$NEW_DIR'" Enter
  fi
fi
