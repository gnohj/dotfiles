#!/bin/bash

export PATH="/opt/homebrew/bin:$HOME/.bun/bin:$HOME/Scripts:$PATH"

LG_CFG="$HOME/.config/lazygit/config.yml"
PANE_PATH=$(/opt/homebrew/bin/tmux display-message -p '#{pane_current_path}')
if git -C "$PANE_PATH" remote get-url origin 2>/dev/null | grep -q "inferno-monorepo"; then
  LG_CFG="$LG_CFG,$HOME/.config/lazygit/inferno.yml"
fi

~/.config/skhd/tmux-window-simple.sh 🌳 lazygit "HUSKY=0 LG_CONFIG_FILE=\"$LG_CFG\" lazygit" true
