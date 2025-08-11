#!/bin/bash
export PATH="/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin"

/opt/homebrew/bin/tmux run-shell '
  PANE_NVIM_CWD=$(/opt/homebrew/bin/tmux show-environment -t "#{pane_id}" NVIM_CWD_#{pane_id} 2>/dev/null | cut -d= -f2)
  PANE_CWD=$(/opt/homebrew/bin/tmux show-environment -t "#{pane_id}" PANE_CWD 2>/dev/null | cut -d= -f2)
  DIR="${PANE_NVIM_CWD:-${PANE_CWD:-#{pane_current_path}}}"
  /opt/homebrew/bin/tmux display-popup -E -w 90% -h 90% -d "$DIR" "
    /usr/bin/git rev-parse --is-inside-work-tree >/dev/null 2>&1 && LG_CONFIG_FILE=~/.config/lazygit/config.yml /opt/homebrew/bin/lazygit || exit 0
  "
'
