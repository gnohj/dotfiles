#!/bin/bash

# Ensure mise is activated and tools are in PATH
eval "$(mise activate bash)"

tmux run-shell '
  PANE_NVIM_CWD=$(tmux show-environment -t "#{pane_id}" NVIM_CWD_#{pane_id} 2>/dev/null | cut -d= -f2)
  PANE_CWD=$(tmux show-environment -t "#{pane_id}" PANE_CWD 2>/dev/null | cut -d= -f2)
  DIR="${PANE_NVIM_CWD:-${PANE_CWD:-#{pane_current_path}}}"
  tmux display-popup -E -w 90% -h 90% -d "$DIR" -B "
    eval \"\$(mise activate bash)\" && /usr/bin/git rev-parse --is-inside-work-tree >/dev/null 2>&1 && HUSKY=0 LG_CONFIG_FILE=~/.config/lazygit/config.yml lazygit || exit 0
  "
'
