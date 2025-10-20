#!/bin/bash

# Debug logging
exec 2>/tmp/sesh-switcher-debug.log
set -x
date >> /tmp/sesh-switcher-called.log

# Ensure Homebrew is in PATH (for sesh)
export PATH="/opt/homebrew/bin:$PATH"

# Nix packages (fzf, fd, tmux) are in PATH via nix-daemon.sh

export TERM="xterm-256color"

source "$HOME/.config/colorscheme/active/active-colorscheme.sh"

# Build the color string properly
color_string="list-border:6,input-border:3,preview-border:4,header-bg:-1,header-border:6,bg+:${gnohj_color13},fg+:${gnohj_color02},hl+:${gnohj_color04},fg:${gnohj_color02},info:${gnohj_color09},prompt:${gnohj_color04},pointer:${gnohj_color04},marker:${gnohj_color04},header:${gnohj_color09}"

echo "About to run tmux command" >> /tmp/sesh-switcher-called.log

# Use tmux display-popup directly instead of run-shell (with no outer border)
tmux display-popup -E -w 28% -h 40% -b none "
  export PATH=\"/opt/homebrew/bin:\$PATH\"

  SELECTED=\$(sesh list --icons | fzf --no-border \
    --ansi \
    --list-border \
    --no-sort --prompt '⚡  ' \
    --header '(^a all) (^t tmux) (^g configs) (^x zoxide) (^d tmux kill) (^f find)' \
    --gutter=' ' \
    --color '${color_string}' \
    --input-border \
    --header-border \
    --bind 'tab:down,btab:up' \
    --bind 'ctrl-b:abort' \
    --bind 'ctrl-a:change-prompt(⚡  )+reload(sesh list --icons)' \
    --bind 'ctrl-t:change-prompt(  )+reload(sesh list -t --icons)' \
    --bind 'ctrl-g:change-prompt(⚙️  )+reload(sesh list -c --icons)' \
    --bind 'ctrl-x:change-prompt(📁  )+reload(sesh list -z --icons)' \
    --bind 'ctrl-f:change-prompt(🔎  )+reload(fd -H -d 2 -t d -E .Trash . ~)' \
    --bind 'ctrl-d:execute(tmux kill-session -t {2..})+change-prompt(⚡  )+reload(sesh list --icons)')

  [[ -z \"\$SELECTED\" ]] && exit 0
  sesh connect \"\$SELECTED\"
"

echo "Finished running tmux command" >> /tmp/sesh-switcher-called.log
