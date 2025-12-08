#!/bin/bash

# Ensure Homebrew and bun are in PATH
export PATH="/opt/homebrew/bin:$HOME/.bun/bin:$HOME/Scripts:$PATH"

# Get current pane's directory (use tmux's pane_current_path directly)
/opt/homebrew/bin/tmux display-popup -E -w 90% -h 90% -d "#{pane_current_path}" -B "
  export PATH=\"/opt/homebrew/bin:$HOME/.bun/bin:$HOME/Scripts:\$PATH\"
  /usr/bin/git rev-parse --is-inside-work-tree >/dev/null 2>&1 && HUSKY=0 LG_CONFIG_FILE=~/.config/lazygit/config.yml lazygit || exit 0
"
