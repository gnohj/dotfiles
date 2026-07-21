#!/bin/bash

# C-g run-shell job: LAZYGIT_HOST_PANE (#{pane_id}, lazygit's edit-in-nvim RPC target) and PANE_PATH are injected fork-free via run-shell format expansion; the only spawn here is display-popup, all detection runs in the fast popup pty.

export PATH="/opt/homebrew/bin:/run/current-system/sw/bin:$HOME/.bun/bin:$HOME/.local/bin:$HOME/Scripts:$PATH"

tmux display-popup -E -w 90% -h 90% -d "$PANE_PATH" -B "
  export PATH=\"/opt/homebrew/bin:/run/current-system/sw/bin:$HOME/.bun/bin:$HOME/.local/bin:$HOME/Scripts:\$PATH\"
  export LAZYGIT_NEW_DIR_FILE=\"$HOME/.lazygit/newdir\"
  export LAZYGIT_HOST_PANE=\"$LAZYGIT_HOST_PANE\"
  mkdir -p \"$HOME/.lazygit\"; rm -f \"$HOME/.lazygit/newdir\"
  LG_CFG=\"$HOME/.config/lazygit/config.yml\"
  git remote get-url origin 2>/dev/null | grep -q inferno-monorepo && LG_CFG=\"\$LG_CFG,$HOME/.config/lazygit/inferno.yml\"
  /usr/bin/git rev-parse --is-inside-work-tree >/dev/null 2>&1 && HUSKY=0 LG_CONFIG_FILE=\"\$LG_CFG\" lazygit
  if [ -f \"$HOME/.lazygit/newdir\" ]; then
    NEW_DIR=\$(cat \"$HOME/.lazygit/newdir\"); rm -f \"$HOME/.lazygit/newdir\"
    [ -n \"\$NEW_DIR\" ] && [ \"\$NEW_DIR\" != \"$PANE_PATH\" ] && tmux send-keys -t \"$LAZYGIT_HOST_PANE\" \"cd '\$NEW_DIR'\" Enter
  fi
"

# Always exit 0: a non-zero run-shell job gets dumped into a copy-mode pager, and the popup's last test (-f newdir) is false whenever lazygit quits without a worktree switch.
exit 0
