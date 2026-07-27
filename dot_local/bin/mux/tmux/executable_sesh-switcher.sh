#!/bin/bash

. "$HOME/.local/bin/mux/shared/mux-env.sh"

# Nix packages (fzf, fd, tmux) are in PATH via nix-daemon.sh

export TERM="xterm-256color"

# The picker UI lives in the shared body script so the hotkey and the status-line
# click stay identical; here we just place the popup on the current server.
tmux display-popup -E -w 28% -h 40% -b none "$HOME/.config/tmux/sesh-popup.sh"
