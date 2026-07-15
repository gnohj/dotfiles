#!/bin/bash

export PATH="/opt/homebrew/bin:$HOME/.bun/bin:$HOME/Scripts:$PATH"

LAZYGIT_DIR_FILE="$HOME/.lazygit/newdir"
mkdir -p "$HOME/.lazygit"

rm -f "$LAZYGIT_DIR_FILE"

# Capture the host pane id BEFORE opening the popup. The popup runs in a
# new tmux pane, so $TMUX_PANE inside it would refer to the popup itself
# — not where nvim is running. Capturing here gives us the pane the
# user came from, which is keyed to that nvim's RPC socket
# (/tmp/nvim-<pane-num>.sock — see ~/.config/nvim/init.lua).
HOST_PANE=$(/opt/homebrew/bin/tmux display-message -p '#{pane_id}')
PANE_PATH=$(/opt/homebrew/bin/tmux display-message -p '#{pane_current_path}')

# Build config file list — append inferno overlay when in inferno-monorepo
LG_CFG="$HOME/.config/lazygit/config.yml"
if git -C "$PANE_PATH" remote get-url origin 2>/dev/null | grep -q "inferno-monorepo"; then
  LG_CFG="$LG_CFG,$HOME/.config/lazygit/inferno.yml"
fi

# Do not try to identify the popup as a pane and pass that id downstream
# — popups are overlays, not panes, and display-message returns the
# host pane. kill-pane on that nukes the user's working pane.
/opt/homebrew/bin/tmux display-popup -E -w 90% -h 90% -d "$PANE_PATH" -B "
  export PATH=\"/opt/homebrew/bin:$HOME/.bun/bin:$HOME/Scripts:\$PATH\"
  export LAZYGIT_NEW_DIR_FILE=\"$HOME/.lazygit/newdir\"
  export LAZYGIT_HOST_PANE=\"$HOST_PANE\"
  /usr/bin/git rev-parse --is-inside-work-tree >/dev/null 2>&1 && HUSKY=0 LG_CONFIG_FILE=\"$LG_CFG\" lazygit || exit 0
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
