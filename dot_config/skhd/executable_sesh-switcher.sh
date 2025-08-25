#!/bin/bash
export PATH="/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin:$HOME/.local/bin"

export TERM="xterm-256color"

source "$HOME/.config/colorscheme/active/active-colorscheme.sh"

# Build the color string properly (no variable expansion inside the tmux command)
color_string="list-border:6,input-border:3,preview-border:4,header-bg:-1,header-border:6,bg+:${gnohj_color16},fg+:${gnohj_color14},hl+:${gnohj_color04},fg:${gnohj_color02},info:${gnohj_color09},prompt:${gnohj_color04},pointer:${gnohj_color04},marker:${gnohj_color04},header:${gnohj_color09}"

/opt/homebrew/bin/tmux run-shell "sesh connect \"\$(
  /opt/homebrew/bin/sesh list --icons | /opt/homebrew/bin/fzf-tmux -p 80%,70% --no-border \
    --ansi \
    --list-border \
    --no-sort --prompt '⚡  ' \
    --header '(^a all) (^t tmux) (^g configs) (^x zoxide) (^d tmux kill) (^f find)' \
    --color '${color_string}' \
    --input-border \
    --header-border \
    --bind 'tab:down,btab:up' \
    --bind 'ctrl-b:abort' \
    --bind 'ctrl-a:change-prompt(⚡  )+reload(/opt/homebrew/bin/sesh list --icons)' \
    --bind 'ctrl-t:change-prompt(  )+reload(/opt/homebrew/bin/sesh list -t --icons)' \
    --bind 'ctrl-g:change-prompt(⚙️  )+reload(/opt/homebrew/bin/sesh list -c --icons)' \
    --bind 'ctrl-x:change-prompt(📁  )+reload(/opt/homebrew/bin/sesh list -z --icons)' \
    --bind 'ctrl-f:change-prompt(🔎  )+reload(/opt/homebrew/bin/fd -H -d 2 -t d -E .Trash . ~)' \
    --bind 'ctrl-d:execute(/opt/homebrew/bin/tmux kill-session -t {2..})+change-prompt(⚡  )+reload(/opt/homebrew/bin/sesh list --icons)' \
    --preview-window 'right:55%' \
    --preview '/opt/homebrew/bin/sesh preview {}' \
)\""
